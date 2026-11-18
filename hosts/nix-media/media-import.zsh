#!/usr/bin/env zsh
# media-import — one-command media pipeline for the nix-media staging lane.
#
# Stages (every one of them confined to /mnt/storage/downloads/incoming —
# the downloads TOP LEVEL is never read, written, or pruned by this script;
# stray files, old archives and links.txt there are manual territory):
#
#   1. download — foreground aria2c on the lane's links.txt (falls back to
#      the legacy top-level links.txt); --no-download skips.
#   2. extract  — unrarall at the lane top, then in each first-level subdir
#      that still holds .rar sets (folder-shaped releases).
#   3. import   — mnamer-tools import-test → confirm → import; the wrapper's
#      source dir is retargeted to the lane (features.mnamer.paths.downloads).
#      A $LANE/kinder sub-lane imports FIRST via mnamer-tools kinder-*
#      (second config → Kinder-Filme/Kinder-Serien): sort kids releases
#      into that subdir before confirming. A declined kinder import skips
#      the normal import (no exclude in mnamer — kids titles would land in
#      the main libraries).
#      --test stops after the dry run; a declined confirm skips the import.
#   4. prune    — confirm-gated: delete extracted *.rar sets and now-empty
#      dirs inside the lane. Never runs without a preceding import.
#   5. notify   — best-effort ntfy push with the summary.
#
# Usage: media-import [--no-download] [--test] [--help]

emulate -L zsh
setopt local_options no_unset pipefail

# unrarall + aria come from the shared functions file (single repo source of
# truth; also loaded into interactive shells via programs.zsh).
[[ -n ${ZSH_FUNCTIONS:-} && -r $ZSH_FUNCTIONS ]] || {
  print -u2 "media-import: ZSH_FUNCTIONS not set (invoke via the media-import wrapper)"
  exit 1
}
source "$ZSH_FUNCTIONS"

LANE="/mnt/storage/downloads/incoming"
LEGACY_LINKS="/mnt/storage/downloads/links.txt"
LINKS="$LANE/links.txt"

DO_DOWNLOAD=1
TEST_ONLY=0
DID_IMPORT=0
IMPORTED=0
LEFT=0
rc=0

usage() {
  print "Usage: media-import [--no-download] [--test] [--help]"
  print "  --no-download  skip stage 1 (aria2c)"
  print "  --test         dry run: download + extract + import-test only,"
  print "                 no import, no prune"
}

confirm() {
  local reply
  read -q "reply?$1 [y/N] "
  print -u2
  [[ $reply = y ]]
}

count_media() {
  # Same extension mask as features.mnamer's `mask` option.
  find "$1" -type f -regextype posix-extended \
    -regex '.*\.(mkv|mp4|m4v|avi|ts|wmv|srt|ass|ssa|sub|idx)$' 2>/dev/null | wc -l
}

notify() {
  if command -v ntfy-send >/dev/null 2>&1; then
    ntfy-send default package "media-import" "$1"
  else
    print -u2 "ntfy-send not available — skipping push"
  fi
}

stage_download() {
  setopt local_options err_return
  if (( ! DO_DOWNLOAD )); then
    print "stage 1: download skipped (--no-download)"
    return 0
  fi
  local links=""
  if [[ -f $LINKS ]]; then
    links=$LINKS
  elif [[ -f $LEGACY_LINKS ]]; then
    links=$LEGACY_LINKS
  else
    print "stage 1: no links.txt (lane or top level) — skipping download"
    return 0
  fi
  print "stage 1: downloading per $links → $LANE"
  mkdir -p "$LANE"
  # Same flag set as the aria function minus --daemon: completion is the
  # exit, already-finished files are skipped by aria2c's control files.
  aria2c \
    -i "$links" \
    -d "$LANE" \
    -j 2 \
    -x 8 \
    -s 8 \
    --user-agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36' \
    --header='Accept-Language: en-US,en;q=0.9' \
    --file-allocation=falloc \
    --enable-mmap=true \
    --no-netrc=true \
    --check-certificate=true \
    --min-tls-version=TLSv1.2
}

stage_extract() {
  setopt local_options err_return
  print "stage 2: extract"
  cd "$LANE"
  # In-flight guard: aria2c preallocates full-size files (falloc), so a
  # half-downloaded multipart set looks complete to unrarall — extracting
  # it yields truncated media that mnamer would import into the library.
  # .aria2 control files exist exactly while a download is unfinished (or
  # was killed); default-No confirm is the override for stale ones.
  local -a inflight
  inflight=( "$LANE"/**/*.aria2(N) )
  if (( ${#inflight} )); then
    print -u2 "downloads in flight (or stale control files):"
    print -u2 ${(F)inflight}
    if ! confirm "extract anyway (partial sets yield broken media)"; then
      print -u2 "stage 2: aborting — finish the downloads (aria / media-import), then rerun with --no-download"
      return 1
    fi
  fi
  # Lane top first; then folder-shaped releases one level down. unrarall's
  # own password probe keeps prompts to the dirs that actually need one.
  # unrarall returns 1 for "no matching archives" (its interactive
  # contract) — demote that to a note, not a stage failure, so a rar-less
  # lane (bare media downloads) stays green.
  unrarall || print "lane top: no archives to extract"
  local -a subdirs rars_in
  subdirs=( "$LANE"/*(/N) )
  local sub
  for sub in "${subdirs[@]}"; do
    rars_in=( "$sub"/*.rar(N) )
    if (( ${#rars_in} )); then
      print "extracting in subdir: $sub"
      cd "$sub"
      unrarall || print "$sub: no extractable root archives"
      cd "$LANE"
    fi
  done
}

stage_import() {
  if ! command -v mnamer-tools >/dev/null 2>&1; then
    print -u2 "stage 3: mnamer-tools missing (features.mnamer disabled?) — skipping import"
    return 1
  fi
  print "stage 3: import (mnamer, TMDB de)"

  # Kinder sub-lane first: releases moved into $LANE/kinder go to the kids
  # libraries (mnamer-tools kinder-*, second generated config). Kids-ness is
  # a human sort — the pipeline just honors whatever sits in that subdir.
  # A declined kinder import skips the normal import too: the normal config
  # has no exclude, so a recursive run would pull the kids titles into the
  # main movies/shows libraries. Rerun after sorting or confirming.
  local kinder_lane="$LANE/kinder"
  local kinder_before kinder_imported=0
  if [[ -d $kinder_lane ]]; then
    kinder_before=$(count_media "$kinder_lane")
    if (( kinder_before > 0 )); then
      print "kinder sub-lane: $kinder_before media files (→ Kinder-Filme/Kinder-Serien)"
      mnamer-tools kinder-import-test
      if (( TEST_ONLY )); then
        print "--test: import skipped"
        return 0
      fi
      if confirm "import the kinder titles"; then
        if ! mnamer-tools kinder-import; then
          print -u2 "kinder import reported failures — prune stays locked this run"
          return 1
        fi
        kinder_imported=$kinder_before
      else
        print "kinder import declined — normal import skipped (kids files would land in movies/shows)"
        LEFT=$(count_media "$LANE")
        return 0
      fi
    fi
  fi

  local before after imported
  before=$(count_media "$LANE")
  if (( before == 0 )); then
    if (( kinder_imported > 0 )); then
      IMPORTED=$kinder_imported
      LEFT=0
      print "kinder imported: $kinder_imported — lane is now empty"
    else
      print "no media files in lane — nothing to import"
    fi
    return 0
  fi
  print "media files in lane: $before"
  mnamer-tools import-test
  if (( TEST_ONLY )); then
    print "--test: import skipped"
    return 0
  fi
  if ! confirm "proceed with import"; then
    print "import declined — files stay in the lane"
    return 0
  fi
  if ! mnamer-tools import; then
    print -u2 "import reported failures — prune stays locked this run"
    return 1
  fi
  DID_IMPORT=1
  after=$(count_media "$LANE")
  imported=$(( before - after ))
  IMPORTED=$(( kinder_imported + imported ))
  LEFT=$after
  print "imported: $imported — unmatched left in lane: $after"
}

stage_prune() {
  setopt local_options err_return
  if (( TEST_ONLY )); then
    print "stage 4: prune skipped (--test)"
    return 0
  fi
  if (( ! DID_IMPORT )); then
    print "stage 4: prune skipped (no import happened this run)"
    return 0
  fi
  print "stage 4: prune"
  local rars
  rars=$(find "$LANE" -type f -name '*.rar')
  if [[ -z $rars ]]; then
    print "no leftover archives in lane"
    return 0
  fi
  print "$rars"
  if ! confirm "delete these archives and now-empty dirs"; then
    print "prune declined"
    return 0
  fi
  find "$LANE" -type f -name '*.rar' -delete
  # Depth-first so parents empty out; -mindepth 1 protects the lane itself.
  find "$LANE" -mindepth 1 -depth -type d -empty -delete
  print "pruned"
}

stage_notify() {
  print "stage 5: notify"
  notify "media-import done on nix-media
imported: $IMPORTED — unmatched left in lane: $LEFT"
}

# --- argument parsing ------------------------------------------------------
while (( $# )); do
  case $1 in
    --no-download) DO_DOWNLOAD=0 ;;
    --test) TEST_ONLY=1 ;;
    --help|-h) usage; exit 0 ;;
    *) print -u2 "unknown option: $1"; usage; exit 1 ;;
  esac
  shift
done

mkdir -p "$LANE"

# Plain calls (NOT in a tested context) so the stages' internal err_return
# stays active; the exit status is checked explicitly afterwards.
stage_download
[[ $? -eq 0 ]] || { print -u2 "stage 1 failed"; rc=1 }

stage_extract
[[ $? -eq 0 ]] || { print -u2 "stage 2 failed"; rc=1 }

stage_import
[[ $? -eq 0 ]] || { print -u2 "stage 3 failed"; rc=1 }

stage_prune
[[ $? -eq 0 ]] || { print -u2 "stage 4 failed"; rc=1 }

stage_notify

if (( rc != 0 )); then
  print -u2 "media-import finished with failures (see above)"
else
  print "media-import finished"
fi
exit $rc

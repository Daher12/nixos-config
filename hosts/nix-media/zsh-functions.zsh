unrarall() {
    emulate -L zsh
    setopt local_options null_glob extended_glob
    local file target rarpass base partnum
    local -A seen_multi
    local -a files files_to_fix unrar_args skipped_padded
    # Global failure ledger (deliberately NOT local): media-import's prune
    # guard reads which archives failed extraction so it never deletes the
    # only surviving copy. Cleared on every call (before any early return);
    # entries are absolute paths so callers can map them to dirs after
    # cd-ing around.
    UNRARALL_FAILED=( )
    # Normalize names like:
    #   foo.part01.rar  -> foo.part1.rar
    #   foo.part001.rar -> foo.part1.rar
    files_to_fix=( *.part0##<->.rar )
    if (( ${#files_to_fix} )); then
        print "Found zero-padded multipart archives, normalizing names..."
        for file in "${files_to_fix[@]}"; do
            if [[ $file =~ '^(.*)\.part0+([1-9][0-9]*)\.rar$' ]]; then
                base="${match[1]}"
                partnum="${match[2]}"
                target="${base}.part${partnum}.rar"
                if [[ -e $target ]]; then
                    print -u2 "Skipping rename due to collision: $file -> $target"
                    skipped_padded+=( "$file" )
                    continue
                fi
                mv -- "$file" "$target" || {
                    print -u2 "Rename failed, skipping: $file -> $target"
                    skipped_padded+=( "$file" )
                    continue
                }
            fi
        done
    fi
    if (( ${#skipped_padded} )); then
        print -u2 "Warning: the following zero-padded multipart files were not normalized and will not be extracted:"
        for file in "${skipped_padded[@]}"; do
            print -u2 "  $file"
        done
    fi
    # Add .partN.rar multipart roots
    files=( *.part1.rar )
    for file in "${files[@]}"; do
        seen_multi[${file%.part1.rar}]=1
    done
    # Add old-style numeric multipart roots: name01.rar name02.rar ...
    # Require the character before the "01" digits to be a digit or separator,
    # not a letter — prevents false matches on episode names like "ShowE01.rar"
    for file in *01.rar; do
        [[ $file == *.part01.rar ]] && continue   # handled via part normalisation
        base="${file%01.rar}"
        [[ $base =~ '[0-9._-]$' ]] || continue    # guard: must end in digit or separator
        [[ -e "${base}02.rar" ]] || continue      # lone file – let standalone handle it
        seen_multi[$base]=1
        files+=( "$file" )
    done
    # Add standalone .rar files, excluding multipart pieces and matching multipart roots
    for file in *.rar; do
        [[ $file == *.part<->.rar ]] && continue
        base="${file%.rar}"
        [[ -n ${seen_multi[$base]} ]] && continue
        # Skip non-root parts of old-style numeric sets (e.g. name02.rar)
        if [[ $base =~ '^(.*[^0-9])([0-9]+)$' ]]; then
            [[ -n ${seen_multi[${match[1]}]} ]] && continue
        fi
        files+=( "$file" )
    done
    if (( ! ${#files} )); then
        print -u2 "No matching archives found."
        return 1
    fi
    # Guard: an embedded empty "${^arr}" expansion yields one bogus
    # "$PWD/" word (not zero) — that entry would mark the whole extraction
    # dir as failed in media-import's prune guard.
    if (( ${#skipped_padded} )); then
        UNRARALL_FAILED+=( "$PWD/${^skipped_padded}" )
    fi
    # Password handling (2026-11-18 revision — extraction IS the probe):
    # the first attempt extracts with an empty password (-p-), which
    # unencrypted archives ignore entirely, so the common case stays a
    # single full pass. (The 2026-11-17 `unrar t` pre-probe CRC-tested
    # every set first — double I/O, and it delayed the prompt by the full
    # test time of every unencrypted root before the first encrypted one.)
    # Only an archive that FAILS the empty-password attempt (encryption —
    # or a corrupt set, which the retry then reports properly) triggers
    # the one-time password prompt and a single retry. </dev/null keeps
    # any unrar-side query from ever hanging the pipeline; the prompt goes
    # to stderr, stdin stays the tty.
    rarpass=""
    prompted=0
    for file in "${files[@]}"; do
        print "-----------------------------------"
        print "Extracting: $file"
        if ! unrar x -o+ -p- -- "$file" </dev/null; then
            (( prompted )) || {
                print -u2 -n "Enter password (leave empty if none): "
                read -rs rarpass
                print -u2
                prompted=1
            }
            if [[ -n $rarpass ]]; then
                if ! unrar x -o+ "-p$rarpass" -- "$file" </dev/null; then
                    UNRARALL_FAILED+=( "$PWD/$file" )
                    print -u2 "Failed: $file"
                fi
            else
                UNRARALL_FAILED+=( "$PWD/$file" )
                print -u2 "Failed: $file"
            fi
        fi
    done
}

aria() {
  local links_file="/mnt/storage/downloads/links.txt"

  [[ -f "$links_file" ]] || {
    print -u2 "aria: missing $links_file"
    return 1
  }

  # Staging lane (2026-11-17 orchestrator delta): downloads land in the
  # @mediaLane@ directory — the only directory the media-import pipeline
  # touches — so the downloads top level stays a manual parking zone. The
  # -d also kills the old CWD trap. (Placeholder substituted by
  # hosts/nix-media/default.nix — the lane literal lives only there.)
  mkdir -p "@mediaLane@"

  command aria2c \
    -i "$links_file" \
    -d "@mediaLane@" \
    -j 2 \
    -x 8 \
    -s 8 \
    --user-agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36' \
    --header='Accept-Language: en-US,en;q=0.9' \
    --file-allocation=falloc \
    --enable-mmap=true \
    --no-netrc=true \
    --check-certificate=true \
    --min-tls-version=TLSv1.2 \
    --daemon=true
}

# Self-heal for stuck SGR mouse reporting: a mouse-capable TUI that exits
# ungracefully (ox, btop, nvim, crossterm tools — over SSH) can leave the
# pane in modes 1003+1006; every cursor move then injects ESC[<35;x;yM
# bytes that zsh executes as commands ("command not found: 35;53;37M...").
# Reset at every interactive prompt so a stuck pane clears itself; no-op
# in clean panes.
_reset_mouse_modes() { printf '\e[?1006l\e[?1003l\e[?1002l\e[?1000l' }
autoload -Uz add-zsh-hook
add-zsh-hook precmd _reset_mouse_modes

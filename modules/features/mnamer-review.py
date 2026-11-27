#!/usr/bin/env python3
# mnamer-review — lane overview table + rename suggestions + picked execution.
#
# Complements the mnamer-tools verbs: parses mnamer's OWN --test output (so
# the preview is by construction what a real import would do), splits it
# into a MATCHED / UNMATCHED table per lane, researches rename suggestions
# for the unmatched residue via direct TMDb/TvMaze/TVDb queries
# (language=de, ae/ue/oe<->ä/ü/ö query variants — the known scene-name
# failure class), and executes PICKED renames through mnamer's --id-*
# directives. This script NEVER moves a file itself: every accepted pick
# is applied by mnamer, which enforces all formatting, destination and
# no-overwrite rules. Already-matched files are NOT imported here — they
# belong to media-import / mnamer-tools import.
#
# Output-format coupling: the parser targets mnamer 2.6.0's test-mode
# output (Processing "<file>" ... / moving to <dest> / skipping (...)).
# Re-verify on nixpkgs mnamer bumps (lore 2026-11-22). The suspicion
# screen (import mode) additionally slices the matched title/year out of
# the formatted destination via the lane config's library roots — that
# assumes the module's default movie/episode format templates; nix-media
# keeps the defaults, custom formats just yield no verdict (rows ride).

import argparse
import difflib
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.parse
import urllib.request

# mnamer 2.6.0's bundled public API key (providers.py — ships with every
# mnamer install). Read-only search use only; NOT a user secret.
# House rule: never place real user keys in repo files.
TMDB_KEY = "db972a607f2760bb19ff8bb34074b4c7"

# Extension mask, same as features.mnamer's `mask` option (keep in sync).
MASK = {"mkv", "mp4", "m4v", "avi", "ts", "wmv", "srt", "ass", "ssa", "sub", "idx"}

# Scene-tag tokens dropped from filenames before building search queries.
_TAG = re.compile(
    r"^(1080p|720p|2160p|4320p|480p|x264|x265|h264|h265|hevc|avc|xvid|"
    r"bluray|bdrip|dvdrip|web|webrip|webdl|hdtv|microhd|remux|"
    r"dts|ac3|ac3d|ddp|dd|aac|aac2|flac|truehd|atmos|dl|"
    r"german|deutsch|engl|english|complete|pal|repack|proper|internal|"
    r"extended|uncut|subbed|subs|dubbed|hq|ps3|untouched)$",
    re.I,
)
_HASHY = re.compile(r"^[A-Za-z0-9_-]{6,}__")  # "KjMjr5A__" upload prefixes
_YEAR = re.compile(r"(19\d{2}|20\d{2})")
# Episode/season markers and short bare numbers pollute series queries
# ("Feuerwehrmann Sam S01E01" finds nothing on TMDb-tv). 4-digit numbers
# survive (years — and titles like "1917" keep their year fallback).
_EP_MARK = re.compile(
    r"^(s\d{1,3}(e\d{1,3})?|e\d{1,3}|\d{1,3}x\d{1,3}|"
    r"staffel|season|folge|episode|ep|teil)$",
    re.I,
)
_UMLAUTS = [("ä", "ae"), ("ö", "oe"), ("ü", "ue")]  # ß deliberately excluded


def eprint(*a):
    print(*a, file=sys.stderr)


def http_json(url, params=None, headers=None, data=None, timeout=10):
    if params:
        url = url + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers=headers or {}, data=data)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8", "replace"))


# ----------------------------------------------------------- presentation
# Boxed-tree renderer (style A, 2026-11-22): framed box, tree rows,
# glyph section headers, ANSI colors on terminals. Colors auto-off when
# piped (isatty) or NO_COLOR is set — harness output stays clean;
# --ascii swaps the whole glyph set for a pure-ASCII fallback.


GLYPHS = {
    "unicode": {
        "tl": "┌", "tr": "┐", "bl": "└", "br": "┘", "h": "─", "v": "│",
        "ml": "├", "mr": "┤",
        "confirmed": "●", "guessed": "◐", "collision": "⚠", "nomatch": "○",
        "ok": "✓", "fail": "✗", "pick": "▌",
        "branch": "├──", "last": "└──", "arrow": "└─▶", "ell": "…",
    },
    "ascii": {
        "tl": "+", "tr": "+", "bl": "+", "br": "+", "h": "-", "v": "|",
        "ml": "+", "mr": "+",
        "confirmed": "*", "guessed": "~", "collision": "!", "nomatch": "o",
        "ok": "+", "fail": "x", "pick": ">",
        "branch": "|-", "last": "\\-", "arrow": "  \\->", "ell": "...",
    },
}

_ANSI = re.compile(r"\x1b\[[0-9;]*m")


def vlen(s):
    """Visible length (ANSI codes don't count)."""
    return len(_ANSI.sub("", s))


class UI:
    def __init__(self, ascii_mode=False):
        self.ascii_mode = ascii_mode
        self.g = GLYPHS["ascii" if ascii_mode else "unicode"]
        self.color = sys.stdout.isatty() and not os.environ.get("NO_COLOR")

    def _c(self, code, s):
        return f"\x1b[{code}m{s}\x1b[0m" if self.color else s

    def green(self, s):
        return self._c("32", s)

    def amber(self, s):
        return self._c("33", s)

    def red(self, s):
        return self._c("31", s)

    def dim(self, s):
        return self._c("2", s)

    def bold(self, s):
        return self._c("1", s)

    def width(self):
        # Not always full-screen: honor the real terminal, clamp to a
        # usable band (narrow terms get tighter truncation, oversized
        # ones a readable cap).
        w = shutil.get_terminal_size((100, 24)).columns
        return max(40, min(w, 110))

    def trunc(self, s, width):
        ell = self.g["ell"]
        if len(s) <= width:
            return s
        if width <= len(ell):
            return ell[:width]
        keep = width - len(ell)  # result is EXACTLY width chars
        half = keep // 2
        return s[:half] + ell + s[len(s) - (keep - half):]

    def clean(self, s):
        """ASCII mode: strip non-ASCII CHROME (data bytes pass through)."""
        if not self.ascii_mode:
            return s
        return s.replace("·", "-").replace("—", "-")


class Box:
    """Framed overview box; collects items, renders on flush()."""

    def __init__(self, ui, title, count=None):
        self.ui = ui
        self.items = []  # ("text"|"blank"|"sep", text, color_fn)
        self.title = title
        self.count = count

    def blank(self):
        self.items.append(("blank", "", None))

    def sep(self):
        self.items.append(("sep", "", None))

    def section(self, glyph_key, color_fn, heading):
        self.blank()
        g = self.ui.g[glyph_key]
        self.items.append(
            ("text", f"{g} {heading}", lambda s: color_fn(self.ui.bold(s)))
        )

    def row(self, text, color_fn=None, last=False):
        self.items.append(("text", self.ui.g["last" if last else "branch"] + " " + text, color_fn))

    def sub(self, text, color_fn=None):
        self.items.append(("text", "    " + self.ui.g["arrow"] + " " + text, color_fn))

    def _top(self):
        ui, g = self.ui, self.ui.g
        inner = self.ui.width() - 2
        left = " " + ui.clean(self.title) + " "
        right = f" {self.count} files " if self.count is not None else " "
        # -1: the decorative h glyph after the corner is part of the
        # border — without it the top line renders 1 char wider than the
        # frame (pre-existing off-by-one, exposed at narrow widths).
        fill = inner - 1 - vlen(left) - vlen(right)
        if fill < 1:
            left = " " + ui.trunc(self.title, max(inner - 7, 3)) + " "
            fill = inner - 1 - vlen(left) - vlen(right)
            fill = max(fill, 0)
        top = g["tl"] + g["h"] + ui.bold(left) + g["h"] * fill + right + g["tr"]
        print(top)

    def flush(self):
        ui, g = self.ui, self.ui.g
        w = self.ui.width()
        inner = w - 2
        self._top()
        for kind, text, color in self.items:
            if kind == "blank":
                print(g["v"] + " " * inner + g["v"])
                continue
            if kind == "sep":
                print(g["ml"] + g["h"] * inner + g["mr"])
                continue
            t = ui.clean(ui.trunc(text, inner - 3))
            line = g["v"] + " " + (color(t) if color else t)
            print(line + " " * max(w - 1 - vlen(line), 0) + g["v"])

    def ask(self, question, short=None):
        """Footer prompt band: ├──┤ + inline question + └──┘ after answer.

        Narrow terminals: a compact `short` question is preferred when the
        long one wouldn't fit; the [y/c/N] tail is NEVER truncated.
        """
        ui, g = self.ui, self.ui.g
        inner = self.ui.width() - 2
        print(g["ml"] + g["h"] * inner + g["mr"])
        for cand in (question, short):
            if cand is None:
                continue
            cand = ui.clean(cand)
            m = re.match(r"^(.*?)(\[[^\]]*\])\s*$", cand)
            opts = m.group(2) if m else ""
            q = (m.group(1).strip() if m else cand)
            if vlen(q) + len(opts) + 4 <= inner or cand is short:
                if vlen(q) + len(opts) + 4 > inner:
                    q = ui.trunc(q, max(inner - 4 - len(opts), 3)).rstrip()
                sys.stdout.write(g["v"] + ui.bold(" " + q + " " + opts) + " ")
                sys.stdout.flush()
                break
        try:
            ans = input().strip().lower()
        except EOFError:
            ans = ""
        if not sys.stdout.isatty():
            print()  # piped: no echoed Enter — end the prompt line ourselves
        print(g["bl"] + g["h"] * inner + g["br"])
        return ans


# ---------------------------------------------------------------- parsing


def crawl_media(dirp):
    """basename -> [absolute paths], the same mask mnamer crawls with."""
    found = {}
    for root, _dirs, files in os.walk(dirp):
        for f in files:
            if f.rsplit(".", 1)[-1].lower() in MASK:
                found.setdefault(f, []).append(os.path.join(root, f))
    return found


def parse_mnamer_output(text):
    """Parse `--test --batch --verbose --no-style` output into records.

    Per-file sequence (mnamer 2.6.0 frontends.py): heading
    `Processing <type> "<file>" (<size>)`, then (verbose) the absolute
    source path, then the verdict: `moving to <dest>` |
    `skipping (--no-guess|--no-overwrite|user request)` |
    `no matches found` | `network error`.
    """
    records = []
    cur = None
    for raw in text.splitlines():
        line = raw.rstrip()
        m = re.match(r'^Processing .*?"(.+)" \(([^)]*)\)$', line)
        if m:
            cur = {
                "basename": m.group(1),
                "size": m.group(2),
                "source": None,
                "media": line.split('"')[0].replace("Processing", "").strip(),
                "status": None,
                "destination": None,
                "reason": None,
            }
            records.append(cur)
            continue
        if cur is None:
            continue
        # verbose debug line: the absolute source path (exists on disk)
        if cur["source"] is None and line.startswith("/") and os.path.exists(line):
            cur["source"] = line
            continue
        m = re.match(r"^moving to (.+)$", line)
        if m:
            cur["status"], cur["destination"] = "matched", m.group(1)
            continue
        m = re.match(r"^skipping \((.+)\)$", line)
        if m:
            cur["reason"] = m.group(1)
            if "no-guess" in m.group(1):
                cur["status"] = "unmatched"
            elif "no-overwrite" in m.group(1):
                cur["status"] = "collision"
            else:
                cur["status"] = "skipped"
            continue
        if line in ("no matches found", "network error"):
            cur["status"], cur["reason"] = "unmatched", line
            continue
    totals = re.search(r"(\d+) out of (\d+) files processed", text)
    return records, (int(totals.group(2)) if totals else None)


def fill_sources(records, lane_dir):
    """Backfill sources for records where verbose printed no path."""
    pool = crawl_media(lane_dir)
    for rec in records:
        if rec["source"] is None:
            cands = pool.get(rec["basename"], [])
            if cands:
                rec["source"] = cands.pop(0)
            else:
                rec["source"] = os.path.join(lane_dir, rec["basename"])


def run_mnamer_test(mnamer, config, target, verbose=True, extra=None):
    # extra: additional value flags appended before the target (used by
    # the import override preview, e.g. ["--id-tvmaze", "84261"]).
    argv = [mnamer, "--config-path", config, "--test", "--batch"]
    if verbose:
        argv.append("--verbose")
    argv += ["--no-style"]
    if extra:
        argv += extra
    argv += [target]
    proc = subprocess.run(argv, capture_output=True, text=True, timeout=900)
    if proc.returncode != 0 and not proc.stdout.strip():
        eprint(f"  mnamer exited {proc.returncode}: {proc.stderr.strip()[:300]}")
    return proc.stdout


# ------------------------------------------------------------ suggestions


def parse_title_tokens(name):
    """Scene-name normalization core: returns (keep_tokens, year, stem).

    Shared by query_variants (provider search) and flag_suspicious
    (wrong-match heuristic). keep_tokens is the residual title BEFORE the
    "or raw stem" fallback — empty means nothing parseable survived
    (numeric titles like "12 12 12": their digit tokens die in the
    1-3-digit/episode/tag strips). stem is the extension- and
    hash-prefix-stripped name, the fallback query_variants searches with.
    """
    name = os.path.splitext(name)[0]
    name = _HASHY.sub("", name)
    # Scene names put the release year last (1917.2019, Blade.Runner.2049.…2017)
    # — the trailing year-like token is the year, earlier ones are title.
    years = _YEAR.findall(name)
    year = years[-1] if years else None
    tokens = [t for t in re.split(r"[.\s_\-\[\]()]+", name) if t]
    # Scene group suffix: a final token right after a tag token
    # ("…BluRay.x265-FuN" -> FuN) is the release group, not the title.
    if len(tokens) >= 2 and _TAG.match(tokens[-2]) and not _TAG.match(tokens[-1]):
        tokens = tokens[:-1]
    # Episode markers and bare 1-3 digit numbers (season/part numbers).
    ep_free = [t for t in tokens if not _EP_MARK.match(t)]
    if ep_free:
        tokens = ep_free
    tokens = [t for t in tokens if not re.match(r"^\d{1,3}$", t)] or tokens
    keep = [t for t in tokens if not _TAG.match(t)]
    if year and year in keep:
        keep = [t for t in keep if t != year] or keep  # "1917" keeps its title
    return keep, year, name


def query_variants(name):
    """Return (title, year, [query variants]) with scene normalization.

    The year is stripped from the title (TMDb's search is literal —
    "Dornröschen 1959" returns nothing while "Dornröschen" + year=1959
    hits) and travels separately. Titles that ARE a year ("1917") fall
    back to the unstripped name.
    """
    keep, year, stem = parse_title_tokens(name)
    title = " ".join(keep).strip() or stem
    variants = [title]
    ascii_from_umlaut = title
    for um, asc in _UMLAUTS:
        ascii_from_umlaut = ascii_from_umlaut.replace(um, asc)
    variants.append(ascii_from_umlaut)  # Dornröschen -> Dornroeschen
    umlaut_from_ascii = ascii_from_umlaut
    for um, asc in _UMLAUTS:
        umlaut_from_ascii = umlaut_from_ascii.replace(asc, um)
    variants.append(umlaut_from_ascii)  # Dornroeschen -> Dornröschen
    for v in list(variants):
        if " und " in v:
            variants.append(v.replace(" und ", " and "))
        if " and " in v:
            variants.append(v.replace(" and ", " und "))
    seen, out = set(), []
    for v in variants:
        v = v.strip()
        if v and v.lower() not in seen:
            seen.add(v.lower())
            out.append(v)
    return title, year, out[:4]  # cap: <=4 provider queries per file


def score(query_title, query_year, cand):
    r = difflib.SequenceMatcher(
        None, query_title.lower(), (cand["title"] or "").lower()
    ).ratio()
    if query_year and cand["year"] and query_year == cand["year"]:
        r = min(1.0, r + 0.15)
    return r


# Similarity floor for flagging a matched row: the wrong-match class
# measures ~0.0-0.1 ("12 12 12" -> "Becoming"), legitimate provider
# alias matches ride >= ~0.4 ("Bob der Baumeister" -> "Bob the Builder").
_SUSPECT_RATIO = 0.35

# Providers accepted by the <row>:<id> override answer (mnamer --id-*).
PROVIDERS = ("tmdb", "tvdb", "tvmaze")


def library_roots(config_path):
    """(movie_root, episode_root) from the lane's generated mnamer config.

    Used to slice the matched title out of the formatted destination (the
    only match metadata mnamer's test output carries). Reading the roots
    from the lane's own config keeps the slice per-lane correct (kinder
    has its own roots) without threading format templates through --lane.
    """
    try:
        with open(config_path, encoding="utf-8") as fh:
            cfg = json.load(fh)
        return cfg.get("movie_directory"), cfg.get("episode_directory")
    except Exception:
        return None, None


def matched_title(rec, roots):
    """(title, year|None) sliced from the destination, or (None, None).

    Destination layout under the module's default formats: movies
    "<root>/<Title> (<year>)/…", series "<root>/<Series>/Season …/…".
    Anything else (custom format, destination outside both roots) yields
    no verdict — heuristics skip that row instead of guessing.
    """
    dest = rec.get("destination")
    if not dest or not roots:
        return None, None
    series = "movie" not in (rec.get("media") or "").lower()
    preferred, other = (roots[1], roots[0]) if series else (roots[0], roots[1])
    base = None
    for root in (preferred, other):
        if root:
            root = root.rstrip("/")
            if dest.startswith(root + "/"):
                base = dest[len(root) + 1:].split("/")[0]
                break
    if not base or base in (".", ".."):
        return None, None
    m = re.search(r"\s*\((\d{4})\)$", base)
    if m:
        return base[: m.start()].strip(), m.group(1)
    return base, None


def flag_suspicious(rec, roots):
    """Reasons to distrust an already-matched record; empty list = trust.

    no_guess only guards ZERO-hit files — a wrong metadata hit sails
    through as "matched" and re-derails identically every run ("12 12 12"
    -> "Becoming"). Hold flags, all cheap (no provider traffic):
    - numeric/unparsable title: no alphabetic token survived scene
      normalization (or none at all) AND the match is alphabetic or
      unverifiable — a numeric match ("1917" -> "1917", "12 12 12" ->
      "12 12 12") is a perfect hit and rides;
    - low similarity: parsed title vs matched title (year-bonus score),
      best of the cleaned title and the separator-normalized stem, below
      _SUSPECT_RATIO — the cleaned title collapses for numeric filenames,
      the raw stem rescues them;
    - year mismatch: filename year vs destination year (movies).
    """
    reasons = []
    keep, fyear, stem = parse_title_tokens(rec["basename"])
    title = " ".join(keep).strip() or stem
    mtitle, myear = matched_title(rec, roots)
    numeric_parsed = (not keep) or (
        not any(re.search(r"[^\d\s]", t) for t in keep)
    )
    if numeric_parsed and (mtitle is None or re.search(r"[A-Za-z]", mtitle)):
        reasons.append(
            "numeric/unparsable title" if not keep else "numeric-only title"
        )
    if mtitle is not None:
        norm_stem = re.sub(r"[.\s_\-\[\]()]+", " ", stem).strip().lower()
        r = max(
            score(title, fyear, {"title": mtitle, "year": myear}),
            score(norm_stem, fyear, {"title": mtitle, "year": myear}),
        )
        if r < _SUSPECT_RATIO:
            reasons.append(f"parsed '{title}' vs matched '{mtitle}' ({r:.0%})")
        if fyear and myear and fyear != myear:
            reasons.append(f"year {fyear} vs matched {myear}")
    return reasons


def _tmdb_tv(q):
    """Series search via TMDb TV (language=de — German titles, alive).

    TVDb's v3 /search/series is gone (404, probed 2026-11-22) and v4
    rejects mnamer's bundled key — TMDb-tv is the only German series
    search left. Candidates carry the TMDb tv id; the exec step resolves
    it to the lane provider's id (resolve_series_ids)."""
    r = http_json(
        "https://api.themoviedb.org/3/search/tv",
        params={"api_key": TMDB_KEY, "query": q, "language": "de"},
    )
    return [
        {
            "provider": "tmdb-tv",
            "id": i["id"],
            "title": i.get("name") or i.get("original_name"),
            "year": (i.get("first_air_date") or "")[:4],
        }
        for i in r.get("results", [])[:5]
    ]


def resolve_series_ids(cand, episode_api):
    """TMDb tv id -> (directive flag, provider id) for mnamer's --id-*.

    TMDb external_ids yields the TVDb id; tvmaze lanes need one further
    lookup (tvmaze's tvdb-keyed lookup). Raises on any missing link.
    """
    ext = http_json(
        "https://api.themoviedb.org/3/tv/" + str(cand["id"]) + "/external_ids",
        params={"api_key": TMDB_KEY},
    )
    tvdb_id = ext.get("tvdb_id")
    if not tvdb_id:
        raise RuntimeError(f"no tvdb id for tmdb tv {cand['id']}")
    if episode_api == "tvdb":
        return "--id-tvdb", tvdb_id
    show = http_json(
        "https://api.tvmaze.com/lookup/shows",
        params={"thetvdb": tvdb_id},
    )
    if isinstance(show, list):
        show = show[0] if show else None
    if not show or not show.get("id"):
        raise RuntimeError(f"tvmaze has no show for tvdb {tvdb_id}")
    return "--id-tvmaze", show["id"]


def _tmdb(q, year):
    params = {"api_key": TMDB_KEY, "query": q, "language": "de"}
    if year:
        params["year"] = year
    r = http_json("https://api.themoviedb.org/3/search/movie", params=params)
    return [
        {
            "provider": "tmdb",
            "id": i["id"],
            "title": i.get("title") or i.get("original_title"),
            "year": (i.get("release_date") or "")[:4],
        }
        for i in r.get("results", [])[:5]
    ]


def search_candidates(query, kind, episode_api):
    """Candidate dicts best-effort; ([...], provider_failed)."""
    out, failed = [], False
    for q in query[2]:
        try:
            if kind == "movie":
                # Year-filtered first; a year-less retry tier follows when
                # the filename's year filtered everything away.
                out += _tmdb(q, query[1])
            else:  # series — TMDb-tv, German + alive (see _tmdb_tv)
                out += _tmdb_tv(q)
        except Exception:
            failed = True
    if kind == "movie" and query[1] and not out:
        for q in query[2]:
            try:
                out += _tmdb(q, None)
            except Exception:
                failed = True
    if kind == "movie" and not out and query[2]:
        # Heavy pollution fallback: progressively shorter prefixes (the
        # year param keeps precision) — "Ponyo Das große …" style titles
        # survive even when tag-stripping can't clean the query.
        words = query[2][0].split()
        for n in (2, 1):
            if len(words) > n:
                try:
                    out += _tmdb(" ".join(words[:n]), query[1])
                except Exception:
                    failed = True
                if out:
                    break
    best = {}
    for c in out:
        c["score"] = score(query[0], query[1], c)
        key = (c["provider"], c["id"])
        if key not in best or c["score"] > best[key]["score"]:
            best[key] = c
    top = sorted(best.values(), key=lambda c: -c["score"])[:3]
    return top, failed


def fmt_cand(i, c):
    return (
        f"    {i}) {c['title']} ({c['year'] or '?'})  "
        f"[{c['provider']} {c['id']}]  {c['score']:.0%}"
    )


# ------------------------------------------------------------------ lanes


def rel(base, path):
    try:
        return os.path.relpath(path, base)
    except ValueError:
        return path


def count_mask(dirp):
    """Media-mask file count (same mask mnamer crawls with)."""
    n = 0
    for _root, _dirs, files in os.walk(dirp):
        n += sum(1 for f in files if f.rsplit(".", 1)[-1].lower() in MASK)
    return n


# ------------------------------------------------------- import overview


def import_flow(lane, mnamer, guess, ui):
    """Overview table + proceed question + bulk/forced mnamer runs.

    No-guess mode: safe-config table (CONFIRMED / SUSPICIOUS / skipped),
    y imports the unflagged bulk. Suspicious rows (flag_suspicious —
    no_guess guards only zero-hit files, so matched rows are screened)
    are excluded from y and handled at the prompt: <row>:<provider>-<id>
    previews through mnamer --test + the id directive and, on accept,
    immediately moves that ONE file via mnamer --id-*; <row>:ok accepts a
    flagged row as matched (alias-match escape). --guess: adds a GUESSED
    section (moves that happen only under the guess config —
    set-difference by basename) and y = confirmed + guessed (guess
    config) / c = confirmed only (safe config). The bulk run targets the
    accepted sources explicitly, never the lane dir: flagged rows must
    not be swept back in, and a target-less mnamer run would scan the
    CWD — an empty source list skips the run entirely. no-overwrite
    guards collisions in every case.
    """
    d = lane["dir"]
    if not os.path.isdir(d):
        print(ui.dim(f"\n== {lane['name']} lane: {d}"))
        print(ui.dim(ui.clean("   (directory does not exist — nothing to import)")))
        return 0
    before = count_mask(d)
    if before == 0:
        print(ui.dim(f"\n== {lane['name']} lane: {d}"))
        print("   no media files in lane")
        return 0
    safe_recs, _ = parse_mnamer_output(run_mnamer_test(mnamer, lane["config"], d))
    fill_sources(safe_recs, d)
    roots = library_roots(lane["config"])
    confirmed = [r for r in safe_recs if r["status"] == "matched"]
    collision = [r for r in safe_recs if r["status"] == "collision"]
    unmatched = [r for r in safe_recs if r["status"] == "unmatched"]
    skipped = [r for r in safe_recs if r["status"] == "skipped"]
    for r in confirmed:
        r["suspect"] = flag_suspicious(r, roots)
    bulk = [r for r in confirmed if not r["suspect"]]
    suspicious = [r for r in confirmed if r["suspect"]]

    guessed = []
    if guess:
        grecs, _ = parse_mnamer_output(
            run_mnamer_test(mnamer, lane["guess_config"], d)
        )
        fill_sources(grecs, d)
        safe_matched = {r["basename"] for r in confirmed}
        for r in grecs:
            if r["status"] == "matched" and r["basename"] not in safe_matched:
                guessed.append(r)

    # Destinations displayed relative to their common root (the library)
    # — absolute store paths would eat the whole line.
    dests = [r["destination"] for r in confirmed + guessed if r["destination"]]
    root = None
    if dests:
        root = (
            os.path.commonpath(dests)
            if len(dests) > 1
            else os.path.dirname(dests[0])
        )

    def disp(path):
        if not root:
            return path
        try:
            relp = os.path.relpath(path, root)
        except ValueError:
            return path
        return path if relp.startswith("..") else relp

    box = Box(ui, f"{lane['name'].upper()} · {d}", before)
    n_g = len(guessed)
    num_map = {}  # printed row number -> rec (stable across overrides)
    next_row = 0
    if bulk:
        box.section("confirmed", ui.green, f"CONFIRMED ({len(bulk)}) — provider match")
        for i, r in enumerate(bulk):
            next_row += 1
            num_map[next_row] = r
            box.row(
                f"{next_row}  {os.path.basename(r['source'])}  ·  {r['size'] or '?'}",
                ui.green, last=(i == len(bulk) - 1),
            )
            box.sub(disp(r["destination"]), ui.green)
    if suspicious:
        box.section(
            "collision", ui.amber,
            f"SUSPICIOUS ({len(suspicious)}) — check before importing",
        )
        for i, r in enumerate(suspicious):
            next_row += 1
            num_map[next_row] = r
            box.row(
                f"{next_row}  {os.path.basename(r['source'])}  ·  {r['size'] or '?'}",
                ui.amber, last=(i == len(suspicious) - 1),
            )
            box.sub(disp(r["destination"]), ui.amber)
            box.sub(" · ".join(r["suspect"]), ui.dim)
    if guessed:
        box.section(
            "guessed", ui.amber,
            f"GUESSED ({n_g}) — filename fallback, no provider hit",
        )
        for i, r in enumerate(guessed):
            box.row(
                f"{os.path.basename(r['source'])}  ·  {r['size'] or '?'}",
                ui.amber, last=(i == n_g - 1),
            )
            box.sub(disp(r["destination"]), ui.amber)
    if collision:
        box.section(
            "collision", ui.red,
            f"COLLISION ({len(collision)}) — destination exists, kept as-is",
        )
        for i, r in enumerate(collision):
            box.row(
                os.path.basename(r["source"]), ui.red,
                last=(i == len(collision) - 1),
            )
    if unmatched or skipped:
        # Files already shown under GUESSED are not repeated here.
        guessed_names = {r["basename"] for r in guessed}
        rest = [
            r for r in unmatched + skipped if r["basename"] not in guessed_names
        ]
        if rest:
            box.section(
                "nomatch", ui.dim,
                f"SKIPPED ({len(rest)}) — stay in the lane",
            )
            for i, r in enumerate(rest):
                box.row(
                    f"{os.path.basename(r['source'])}  ·  {r['reason'] or 'no hit'}",
                    ui.dim, last=(i == len(rest) - 1),
                )
    box.flush()

    if not (bulk or suspicious or guessed):
        print(ui.dim("   nothing would move — nothing to proceed on"))
        return 0

    # Override / accept loop: <row>:<provider>-<id> force-fixes a row via
    # mnamer --id-* (preview + explicit accept, executed immediately —
    # each forced move carries its own confirm), <row>:ok accepts a
    # flagged row as matched. Any other answer settles the bulk.
    rc_forced = 0
    while True:
        n_b, n_s = len(bulk), len(suspicious)
        if guess and n_g:
            question = (
                f"import {n_b} confirmed + {n_g} guessed files"
                f" ({n_s} suspicious)?"
                " [y = all shown / c = confirmed only / row:id = force / N = abort]"
            )
            short_q = f"import {n_b}+{n_g}, {n_s} susp? [y=all / c=conf / row:id / N=abort]"
        elif n_b:
            question = (
                f"import {n_b} confirmed files ({n_s} suspicious)?"
                " [y = bulk / row:id = force / row:ok = accept / N = abort]"
            )
            short_q = f"import {n_b}, {n_s} susp? [y / row:id / row:ok / N=abort]"
        else:
            question = (
                f"{n_s} suspicious — force or accept a row?"
                " [row:id = force / row:ok = accept / N = abort]"
            )
            short_q = f"{n_s} susp? [row:id / row:ok / N=abort]"
        ans = box.ask(question, short_q)
        m = re.match(r"^(\d+)\s*:\s*(.+)$", ans)
        if not m:
            break
        rec = num_map.get(int(m.group(1)))
        rest = m.group(2).strip().lower()
        if rec is None:
            print(ui.dim("    no such row — use the printed row numbers"))
            continue
        if rest == "ok":
            if rec in suspicious:
                suspicious.remove(rec)
                bulk.append(rec)
                print(ui.green(f"    {ui.g['ok']} accepted as matched — rides y"))
            else:
                print(ui.dim("    already confirmed — nothing to accept"))
            continue
        kind = "movie" if "movie" in (rec["media"] or "").lower() else "episode"
        prov, ident = None, rest
        if "-" in rest:
            p, i2 = rest.split("-", 1)
            if p in PROVIDERS:
                prov, ident = p, i2
        if prov is None:
            if kind == "movie":
                print(ui.dim("    movies need the provider: <row>:tmdb-<id>"))
                continue
            prov = lane["episode_api"]  # series: bare id = lane provider
        flag = "--id-" + prov
        # Preview: --test + the directive on this ONE file (--id-* binds
        # to every file of an invocation, so it stays per-file here too).
        prev_recs, _ = parse_mnamer_output(
            run_mnamer_test(
                mnamer, lane["config"], rec["source"], extra=[flag, ident]
            )
        )
        dest = next(
            (p["destination"] for p in prev_recs if p["destination"]), None
        )
        if not dest:
            print(ui.red(
                f"    [{ui.g['fail']} override] {flag}={ident} matched nothing"
                " — row unchanged"
            ))
            continue
        print(f"    {ui.g['arrow']} {disp(dest)}  [{flag}={ident}]")
        try:
            ok_ans = input(ui.bold("    accept? [y/N] ")).strip().lower()
        except EOFError:
            ok_ans = ""
        if ok_ans != "y":
            print(ui.dim("    skipped — row unchanged"))
            continue
        proc = subprocess.run(
            [
                mnamer,
                "--config-path",
                lane["config"],
                "--no-style",
                flag,
                ident,
                "--",
                rec["source"],
            ],
            capture_output=True,
            text=True,
            timeout=900,
        )
        if proc.returncode == 0:
            print(ui.green(
                f"    [{ui.g['ok']}] {os.path.basename(rec['source'])}"
                f" <- {flag}={ident}"
            ))
            if rec in bulk:
                bulk.remove(rec)
            if rec in suspicious:
                suspicious.remove(rec)
        else:
            rc_forced = 1
            print(ui.red(
                f"    [{ui.g['fail']} rc={proc.returncode}]"
                f" {os.path.basename(rec['source'])} <- {flag}={ident}"
            ))

    if ans == "c" and guess and n_g:
        cfg, label = lane["config"], "confirmed only"
    elif ans == "y":
        if guess and n_g:
            cfg, label = lane["guess_config"], "confirmed + guessed"
        else:
            cfg, label = lane["config"], "confirmed"
    else:
        print(ui.dim(ui.clean("declined — nothing else was changed")))
        return 1 if rc_forced else 0

    # Bulk run over EXPLICIT sources only — never the lane dir, which
    # would sweep the still-flagged suspicious rows back in.
    sources = [r["source"] for r in bulk]
    if ans == "y" and guess and n_g:
        sources += [r["source"] for r in guessed]
    rc_bulk = 0
    if sources:
        proc = subprocess.run(
            [mnamer, "--config-path", cfg, "--no-style", *sources],
            capture_output=True,
            text=True,
            timeout=1800,
        )
        if proc.returncode != 0:
            eprint(f"   mnamer exited {proc.returncode}: {proc.stderr.strip()[:300]}")
        rc_bulk = proc.returncode
    else:
        print(ui.dim("   no bulk files left — only the forced moves ran"))
    after = count_mask(d)
    mark = ui.g["ok"]
    print(ui.green(f"  {mark} imported ({label}): {before - after}") +
          ui.dim(ui.clean(f" — left in lane: {after}")))
    if after:
        print(ui.dim(ui.clean("   leftovers: review them with the review verb")))
    return 1 if (rc_bulk or rc_forced) else 0


def review_lane(lane, mnamer, do_suggest, ui):
    d = lane["dir"]
    if not os.path.isdir(d):
        print(ui.dim(f"\n== {lane['name']} lane: {d}"))
        print("   (directory does not exist — nothing to review)")
        return []
    records, total = parse_mnamer_output(run_mnamer_test(mnamer, lane["config"], d))
    fill_sources(records, d)
    if total is not None and total != len(records):
        eprint(
            f"   note: mnamer reported {total} files, parser saw {len(records)}"
            " (format drift? see header comment)"
        )
    matched = [r for r in records if r["status"] == "matched"]
    unmatched = [r for r in records if r["status"] == "unmatched"]
    collision = [r for r in records if r["status"] == "collision"]
    skipped = [r for r in records if r["status"] == "skipped"]
    roots = library_roots(lane["config"])

    box = Box(ui, f"{lane['name'].upper()} · {d}", len(records))
    if matched:
        box.section("confirmed", ui.green, f"MATCHED ({len(matched)}) — would import")
        for i, r in enumerate(matched):
            reasons = flag_suspicious(r, roots)
            if reasons:
                # Informational only: review never touches matched files —
                # fix them at the import-overview prompt (row:id / row:ok).
                box.row(
                    ui.g["collision"] + " " + os.path.basename(r["source"]),
                    ui.amber, last=(i == len(matched) - 1),
                )
                box.sub(r["destination"], ui.amber)
                box.sub(" · ".join(reasons), ui.dim)
            else:
                box.row(os.path.basename(r["source"]), ui.green, last=(i == len(matched) - 1))
                box.sub(r["destination"], ui.green)
    if collision:
        box.section("collision", ui.red, f"COLLISION ({len(collision)}) — destination exists")
        for i, r in enumerate(collision):
            box.row(os.path.basename(r["source"]), ui.red, last=(i == len(collision) - 1))
    if skipped:
        box.section("nomatch", ui.dim, f"SKIPPED ({len(skipped)})")
        for i, r in enumerate(skipped):
            box.row(f"{os.path.basename(r['source'])}  ·  {r['reason']}", ui.dim,
                    last=(i == len(skipped) - 1))
    if unmatched:
        box.section("nomatch", ui.dim, f"UNMATCHED ({len(unmatched)}) — stay in the lane")
        for i, r in enumerate(unmatched):
            box.row(f"{os.path.basename(r['source'])}  ·  {r['reason'] or 'no hit'}",
                    ui.dim, last=(i == len(unmatched) - 1))
    if not records:
        box.section("nomatch", ui.dim, "no media files found")
    box.flush()
    if not (do_suggest and unmatched):
        return []

    # Guess previews for exactly the unmatched basenames (guess config =
    # no_guess=false; test-only here — there is no moving guess variant).
    guess_dest = {}
    try:
        grecs, _ = parse_mnamer_output(
            run_mnamer_test(mnamer, lane["guess_config"], d, verbose=False)
        )
        for g in grecs:
            if g["destination"]:
                guess_dest[g["basename"]] = g["destination"]
    except Exception as exc:
        eprint(f"   guess preview failed: {exc}")

    picks = []
    provider_note = False
    for r in unmatched:
        kind = "movie" if "movie" in (r["media"] or "").lower() else "series"
        q = query_variants(r["basename"])
        cands, failed = search_candidates(q, kind, lane["episode_api"])
        provider_note = provider_note or failed
        print(f"\n {ui.g['pick']} {ui.bold(rel(d, r['source']))}")
        if cands:
            for i, c in enumerate(cands, 1):
                line = ui.clean(fmt_cand(i, c))
                score = c["score"]
                tone = ui.green if score >= 0.8 else ui.amber
                print("  " + tone(line))
        else:
            print(ui.dim("    (no research hits)"))
        if r["basename"] in guess_dest:
            print(ui.amber(f"    g) guess: {guess_dest[r['basename']]}  [unverified]"))
        try:
            ans = input(ui.bold(f"  {ui.g['pick']} pick") + " [1-3/g/s]: ").strip().lower()
        except EOFError:
            print(ui.dim(ui.clean("   (input ended — remaining files skipped)")))
            break
        if ans == "g" and r["basename"] in guess_dest:
            picks.append({"rec": r, "guess": True, "label": "filename guess"})
        elif ans in {"1", "2", "3"} and cands and int(ans) <= len(cands):
            c = cands[int(ans) - 1]
            picks.append(
                {
                    "rec": r,
                    "guess": False,
                    "cand": c,
                    "label": f"{c['title']} ({c['year'] or '?'}) [{c['provider']}]",
                }
            )
        else:
            print(ui.dim("    skipped"))
    if provider_note:
        eprint(
            "   note: a provider search failed (network?) —"
            " candidates may be incomplete"
        )
    return picks


def execute_picks(lane, mnamer, picks, ui):
    if not picks:
        return 0
    print(f"\n== {lane['name']}: " + ui.bold(f"{len(picks)} rename(s) planned"))
    for p in picks:
        print(f"   {rel(lane['dir'], p['rec']['source'])}  <-  {p['label']}")
    try:
        ans = input("execute these renames via mnamer? [y/N] ").strip().lower()
    except EOFError:
        ans = ""
    if ans != "y":
        print(ui.dim(ui.clean("declined — nothing was changed")))
        return 1
    ok = 0
    for p in picks:
        if p["guess"]:
            argv = [
                mnamer,
                "--config-path",
                lane["guess_config"],
                "--no-style",
                "--",
                p["rec"]["source"],
            ]
        else:
            c = p["cand"]
            if c["provider"] == "tmdb":
                flag, prov_id = "--id-tmdb", c["id"]
            else:  # tmdb-tv series pick — resolve to the lane's provider
                try:
                    flag, prov_id = resolve_series_ids(c, lane["episode_api"])
                except Exception as exc:
                    print(ui.red(f"   [{ui.g['fail']} id-resolve] {p['rec']['basename']}: {exc}"))
                    continue
            argv = [
                mnamer,
                "--config-path",
                lane["config"],
                "--no-style",
                flag,
                str(prov_id),
                "--",
                p["rec"]["source"],
            ]
        proc = subprocess.run(argv, capture_output=True, text=True, timeout=900)
        if proc.returncode == 0:
            ok += 1
            print(ui.green(f"   [{ui.g['ok']}] {p['rec']['basename']} <- {p['label']}"))
        else:
            print(ui.red(f"   [{ui.g['fail']} rc={proc.returncode}] {p['rec']['basename']} <- {p['label']}"))
    print(
        f"done: {ok}/{len(picks)} applied — leftovers stay in the lane;"
        " re-run media-import (or import-test) for the rest"
    )
    return 0 if ok == len(picks) else 1


def main():
    ap = argparse.ArgumentParser(
        prog="mnamer-tools review",
        description="Overview table (matched/unmatched) per lane, researched"
        " rename suggestions for unmatched files, picked renames executed"
        " through mnamer --id-* directives (never moves files itself).",
    )
    ap.add_argument("--mnamer", required=True, help="mnamer executable path")
    ap.add_argument(
        "--mode",
        choices=("review", "import"),
        default="review",
        help="review = unmatched-residue fixer (suggestions + picks);"
        " import = overview table + proceed question + bulk import",
    )
    ap.add_argument(
        "--guess",
        action="store_true",
        help="import mode only: preview/import filename-guess moves too"
        " (confirm accepts y = all shown, c = confirmed only)",
    )
    ap.add_argument(
        "--lane",
        action="append",
        default=[],
        metavar="NAME:DIR:CONFIG:EPISODE_API:GUESS_CONFIG",
        help="lane to review (repeatable)",
    )
    ap.add_argument(
        "--no-suggest",
        action="store_true",
        help="table only — no provider searches, no prompts",
    )
    ap.add_argument(
        "--ascii",
        action="store_true",
        help="pure-ASCII glyphs (no unicode box drawing)",
    )
    args = ap.parse_args()
    ui = UI(ascii_mode=args.ascii)

    lanes = []
    for raw in args.lane:
        parts = raw.split(":", 4)
        if len(parts) != 5 or not all(parts):
            eprint(f"bad --lane (need NAME:DIR:CONFIG:EPISODE_API:GUESS_CONFIG): {raw}")
            return 2
        names = ("name", "dir", "config", "episode_api", "guess_config")
        lanes.append(dict(zip(names, parts)))

    rc = 0
    try:
        for lane in lanes:
            if args.mode == "import":
                rc |= import_flow(lane, args.mnamer, args.guess, ui)
            else:
                if args.guess:
                    ap.error("--guess is only valid with --mode import")
                picks = review_lane(lane, args.mnamer, not args.no_suggest, ui)
                rc |= execute_picks(lane, args.mnamer, picks, ui)
    except KeyboardInterrupt:
        print("\ninterrupted — nothing else was changed")
        return 130
    if args.mode == "review" and args.no_suggest:
        print("\n(--no-suggest: table only)")
    return rc


if __name__ == "__main__":
    sys.exit(main())

# Respect `$XDG_DATA_DIRS` when scanning desktop entries, icons and themes

## Problem

The shell's application launcher, pin lookup, icon resolution and
theme/icon dir lists hardcode a small set of FHS locations
(`/usr/share/...`, `/var/lib/flatpak/...`, `/var/lib/snapd/...`). On
source-based and profile-based distributions (NixOS, Guix, …) desktop
entries, icons and themes live in per-profile data dirs that are exposed
through `$XDG_DATA_DIRS` — so on those systems the launcher finds no
applications, and profile-installed icons/themes are invisible to
`resolve-icons.sh`, `envtool.py` and `cursorshadow.py`.

## Fix

Replace the hardcoded FHS lists with `$XDG_DATA_DIRS` iteration plus the
freedesktop default (`/usr/local/share:/usr/share`). Concretely:

- `luciddocks/Dock.qml` — `appScanner` scans `<data-dir>/applications`
  for every dir in `$XDG_DATA_DIRS`; `pinLookup` resolves `.desktop`
  files across the same set.
- `luciddocks/resolve-icons.sh` — icon dir list iterates
  `$XDG_DATA_DIRS`; `find -L` traverses symlinked profile dirs.
- `lucidprefs/envtool.py` — `ICON_DIRS` / `THEME_DIRS` gain
  `<data-dir>/icons` and `<data-dir>/themes` entries from
  `$XDG_DATA_DIRS`.
- `lucidprefs/cursorshadow.py` — same for `ICON_DIRS`.

On a stock Arch system with `XDG_DATA_DIRS` unset (the freedesktop
default applies), the scanned set is `/usr/local/share` +
`/usr/share` — exactly what the current hardcoded lists cover, so
behavior there is unchanged. Duplicate desktop entries across dirs keep
their existing precedence (user dir first, first-seen wins).

## Testing

- Shell expansion verified for: unset `XDG_DATA_DIRS` (default list),
  multi-profile NixOS values, colon splitting.
- `resolve-icons.sh` resolves an icon placed in a fake
  `XDG_DATA_DIRS` profile tree; `bash -n` clean.
- Both Python files compile; end-to-end verified on NixOS where all
  shell applications are discovered through `$XDG_DATA_DIRS`.

## Known limitation (unchanged)

Paths containing spaces in `XDG_DATA_DIRS` split the same way the
existing `for d in $dirs` loops do — this patch does not make that
worse.

Base: `2945eab` (1.20.5.5).

---
name: boot-keyring-dialog-autologin-2026-11-19
description: "Boot regression \"since the pkg bump\" was actually the FIRST
  autologin boot ever — noctalia's network secret agent reads the locked
  Default_keyring pre-lockscreen → GCR dialog; fix = empty keyring password
  (user seahorse step) + comments; TTY flash OPEN"
metadata:
  node_type: memory
  type: project
  originSessionId: sess_f5a85e6f-f5c1-4cb4-a3a9-87de06e0ed2c
---

# Boot keyring dialog + TTY flash (diagnosed 2026-11-19)

## Attribution: the pkg bump was INNOCENT
User reported boot regression "after the last changes (i assume the pkg bump)".
Forensics: only 4 reboots since Nov 7 (hibernate habit, s2h):
boot -3 Nov 7 (greeter), boot -2 Nov 14 08:55 (GREETER — journal shows
`session opened for user greeter` + `gkr-pam: … unlocked keyring`), then NO
reboot until Nov 19 00:46. The autologin generation went live Nov 15 00:39
(system-207); system-209 (the bump) switched Nov 19 00:38 — reboot at 00:46
was the FIRST AUTOLOGIN BOOT EVER, 8 minutes after the bump switch. Config
was byte-identical between gen 207 and 210 (greetd.toml, PAM, user units;
greetd 0.10.3 / gcr 4.4.1 / gnome-keyring 50.0 / systemd 260.5 all unchanged).
**Lesson: "after the last changes" needs boot-count forensics —
`journalctl --list-boots`, `ls -la /nix/var/nix/profiles/`, gkr-pam lines in
greetd's journal distinguish greeter (password → silent keyring unlock) from
autologin boots.**

## Mechanism (journal-proven both Nov 19 boots)
Autologin = greetd initial_session with NO PAM authtok → pam_gnome_keyring
`auto_start` starts the daemon but unlocks nothing; and pam_gnome_keyring only
ever unlocks the LOGIN keyring anyway. Noctalia v5.5.0 at shell start
registers its NM/iwd secret agents and probes the secret-service DEFAULT
collection (`secret_collection_probe` ReadAlias, consumers = network agents
needing WiFi secrets) → locked → GCR "Schlüsselbund entsperren" dialog ~1.5 s
after the shell appears, racing ahead of the visible noctalia lock (user types
password twice). Keyring state: `~/.local/share/keyrings/default` (alias) →
"Default_keyring" since Sep 23; `Default_keyring.keyring` BORN 2026-11-19
10:31:47 (materialized at the 2nd prompt; holds the WiFi secret, 1841 B);
`login.keyring` untouched since Sep 23. Old boots were prompt-free because the
greeter password unlocked everything via PAM (and Nov 15–18 had no reboots at
all — daemon state survived suspends).

## Fix
- **User step (the real fix):** `nix run nixpkgs#seahorse` → Default_keyring →
  Passwort ändern → empty. gnome-keyring auto-unlocks empty-password
  collections when the Secret service starts → noctalia reads silently, lock
  screen stays the only prompt. login.keyring keeps its password.
- Comments updated (comment-only changes, `test-suite fast yoga` green,
  UNCOMMITTED): modules/features/desktop-niri.nix PAM block (full mechanism),
  home/browsers.nix Brave note ("Revisit only if keyring-before-browser
  ordering is ever solved" — settled 2026-11-19 the other way; Brave stays
  basic by choice).
- Verify next boot: `journalctl -b --user | grep -E 'gcr-prompter.*starting
  password|default collection unlocked'` — expect the noctalia "unlocked"
  line and ZERO gcr-prompter lines.

## TTY one-line flash: SOLVED (same root: first autologin boot)
Captured via `sudo cat /dev/vcs1` (VT text buffer survives under the
compositor — the go-to capture for console flashes):
`Calling import-environment without a list of variable names is deprecated.`
= systemd 260's deprecation warning from niri 26.04's niri-session, which
calls `systemctl --user import-environment` BARE. stderr of niri-session
lands on the bare VT1 under autologin → visible ~1 s before niri's first
frame. Greeter boots printed it too but invisibly (screen already in graphics
mode through the greeter handoff). Fix: programs.niri.package overrideAttrs
postPatch in modules/features/desktop-niri.nix mirroring upstream MAIN
(they fixed it the same way — comment there calls the warning "very
annoying"): `dbus-update-activation-environment --systemd --all` does both
jobs, bare import neutered to `:` (fallback path; the dbus tool ships in the
system path). --replace-fail = tripwire for nixpkgs niri updates. Note:
dry-build does NOT execute postPatch — the substitution needs a real
`nix build` to prove.

## Lore
- Noctalia logs `[INF] [app] secret service default collection unlocked;
  reopening consumers` at every shell start — also mid-session after every
  config switch (KillMode=process restart) — that line alone does NOT mean a
  prompt happened; absence of `gcr-prompter.*starting password prompt` is the
  discriminator.
- The gcr prompter logs the full secret-exchange handshake; the user-typed
  completion lands ~7-9 s after "starting password prompt".
- Agent shells see the fhsenv /etc (no /etc/pam.d) — read PAM files from
  /run/current-system/etc/pam.d.
- journalctl IS blocked in plan mode even read-only; subagent Explore could
  run ls/cat/readlink but not journalctl.

Related: [[niri-greetd-autologin-2026-11-14]], [[update-sweep-2026-11-18]]

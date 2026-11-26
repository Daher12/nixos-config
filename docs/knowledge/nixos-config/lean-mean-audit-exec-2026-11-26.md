---
name: lean-mean-audit-exec-2026-11-26
description: Lean-and-Mean repo audit EXECUTED — batches A–E staged uncommitted;
  measurements refuted two eval-time assumptions; snapshot proof caught 2 wrong
  audit claims; QC pass fixed 5 self-inflicted defects
metadata:
  node_type: memory
  type: project
  originSessionId: sess_7d1188e6-bb26-4042-a067-47da5fe0ef95
---

# Lean-and-Mean audit EXECUTED 2026-11-26

Executes [[lean-mean-audit-plan-2026-11-26]]. Everything STAGED, nothing committed/pushed/switched. `test-suite fast` green after every batch.

## Measured — refuted the plan's eval-time theory (n=1 per cell, taken while a background build ran: treat as order-of-magnitude, not a benchmark)
- yoga toplevel eval: cold `--no-eval-cache` 32.8s ≈ warm pure 31.9s ≈ warm `--impure` 29.9s; latitude 21.4s / 20.2s → **no measurable eval-cache benefit on Lix 2.95.4**. The plan's "drop --impure to regain the eval cache" was unsupported → flags kept everywhere.
- `nix flake check` 41s: it does NOT deep-evaluate the four host toplevels (no double-eval either).
- One multi-installable `nix build --dry-run` for 3 hosts = 44s (measured). The three per-host invocations it replaced were NEVER timed to completion — the ~75s figure is an ESTIMATE from per-host eval timings. Implemented in `scripts/test-suite fast` with per-host fallback attribution.

## Batches (all staged in one working tree)
- **A**: fast dry-run dedupe; ci.yml/bump.yml call `scripts/test-suite fast $(nix eval …attrNames…)`; bump.yml formats BEFORE verify; timeout-minutes 40/45 (values chosen without CI-duration data); checkout pins unified to v5.1.0 (opencode.yml DOWNGRADED from v6.1.0 — untested in CI); suggest mapping no longer claims `profiles/*` → host-units-smoke; update-safe `--help`; flake.nix comment (local-pkgs overlay is load-bearing for the smoke test's `pkgs.is-on-ac`).
- **B**: `modules/core/nix.nix` — removed auto-optimise-store/max-jobs/cores/sandbox/builders-use-substitutes, registry+nixPath (nixpkgs' own `misc/nixpkgs-flake.nix` wires both); substituters + trusted-public-keys now `mkForce` (kills upstream's mkAfter DUPLICATES, keeps cache-first order — heavier than needed, debatable); `core.nix.trustedUsers` default `[mainUser]` (upstream appends root). `lib/mkHost.nix`: `nix.channel.enable = false`, dropped `extraSpecialArgs` param and `self` from commonArgs (kept `flakeRoot`). **Proof**: generated nix.conf diff = only the dup tokens removed.
- **C**: theme gate (Colloid + 3 switch-theme scripts + `.themes` now `!noctalia` only); persistence gating per attr (gdm/colord ← desktop-gnome, noctalia-greeter ← desktop-niri; HM: papers-signing/monitors.xml ← `!niri`, `.local/state/zcode` ← niri); 27 default-restatement one-liners removed; fonts fira-code+roboto dropped; audio.nix rtkit defaults to pipewire.enable. **Proof**: per-host `nix eval` snapshots; home-files diff.
- **D**: Grafana `secret_key` → sops file-provider: ini carries `secret_key = "$__file{/run/secrets/grafana_secret_key}"` (the 26.05 module ASSERTS a non-null ini value — removing it fails eval), secret in secrets/hosts/nix-media-silo.yaml with `owner = "grafana"`. sops-nix writes key values VERBATIM (sops-install-secrets main.go:386-390,474 — no trailing newline added). NOT runtime-tested. **USER STEPS BEFORE ANY nix-media DEPLOY**: add `grafana_secret_key` to that yaml in the SAME commit as this change, and ROTATE (old value = the public Grafana docs sample, in git history; rotation invalidates sessions).
- **E**: export-zcode-memory allowlist (4 projects; 3 UUID dirs with unrelated personal notes git-rm'd; export now picks the FIRST `<name>-*` dir if several exist — no warning); memory index compacted to ~20.5KB by folding ~19 retired-Lucid records into ONE pointer line + dropping 2 old update-sweep lines (files intact — NOT "every record kept"); literal scrubbed from memory + archive; doc fixes; dead `TVDB_KEY` + zram-heal `mainUser` removed; .gitignore pruned (secret patterns `.env*`/`secrets.conf` restored in QC).

## Proof methodology paid off — 2 audit claims were WRONG
1. `fonts.enableDefaultPackages = false` is **LOAD-BEARING**: `graphical-desktop.nix:42` sets `mkDefault true` on every desktop session (niri included). Restored.
2. GNOME module does NOT add gnome-settings-daemon's udev rules on 26.05 → explicit `udev.packages` line is needed. Restored.

## QC pass 2026-11-26 (self-review, no suite) — found + fixed
- `fast` never evaluates yoga-gnome's toplevel or ANY `nixosTests` derivation → one `nix build --dry-run` of yoga-gnome + nix-media toplevels + all 7 VM tests: green, 65s. Rule for next time: close this gap explicitly.
- Removed beyond the approved plan: nix-media `openFirewall = true` + 3 monitoring port pins (9090/9093/9100, which other literals depend on) → restored.
- .gitignore lost the `.env*`/`secrets.conf` secret patterns against the plan's own rule → restored.
- Stale/inaccurate text of mine: "measured 75s" in test-suite, REPO_OVERVIEW specialArgs line (`self`), second "same palette as kitty" comment in terminal.nix, mkHost rationale comment, "lint/tests" in flake.nix, export-script header.

## Still open
- User: sops key + rotation (D), yoga switch. Runtime checks post-switch: `nix-instantiate --eval <nixpkgs> -A lib.version` (channels now off), grafana login + `journalctl -u grafana`.
- Not done from the plan: REPO_OVERVIEW's 11 unmapped files; update-safe still inlines its own `nix flake check`; safe-input list still duplicated (bump.yml vs update-safe).
- nix-media.yaml §3 re-encryption still open (device-side, hygiene only). **latitude RE-ENCRYPTION MOOT** (user decision 2026-11-26): latitude will be installed FRESH via disko → new device key + fresh latitude.yaml under current rules; runbook §3 updated accordingly.
- Grafana deploy path VERIFIED by pubkey preflight (2026-11-26): nix-media-silo.yaml recipients = [current admin_david, host_nix-media] → yoga can add `grafana_secret_key` directly (`nix develop -c sops secrets/hosts/nix-media-silo.yaml`); nix-media.yaml recipients = [retired age1vzw0xw2d6…, host] → §3 still needed. HARD RULE: silo.yaml key addition must land in the SAME commit/push as monitoring.nix — nix-media's 05:00 autoUpgrade rebuilds whatever main has, and a missing key fails ACTIVATION (ntfy spam, upgrade-retry loop, weekly reboot aborted; old gen keeps running, no lockout). Note nix-media autoUpgrade uses operation="boot": without a manual switch the grafana change goes live only at the Sunday reboot.

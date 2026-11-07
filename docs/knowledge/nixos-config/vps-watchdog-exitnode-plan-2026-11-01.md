---
name: vps-watchdog-exitnode-plan-2026-11-01
description: HALTED+HANDED OFF — VPS watchdog+exit-node: Phase 1 EXECUTED+fast
  GREEN STAGED (never committed); infect froze the box's storage TWICE (jbd2
  hung_task, 2nd time total TCP loss ~3min into the build) — burst writes are
  the killer; plan B (yoga builds closure + throttled 4MB/s store transfer)
  CANCELLED by user before any build; user started ANEW with another agent
  (handoff summary delivered in chat 2026-11-04); don't redo Phase 1
metadata:
  node_type: memory
  type: project
  originSessionId: session_174c70547700b8658a5f8f6e243c67db
---

User acquired a simple VPS (1 core, 1GB RAM, 15GB NVMe, currently non-NixOS Linux). Plan-mode session 2026-11-01 produced a complete integration plan; **ExitPlanMode was DENIED — NOTHING executed**. User's choices: roles = **external watchdog + Tailscale exit node**; explicitly DECLINED: offsite backups and self-hosted ntfy; reinstall to NixOS accepted (nixos-infect).

**Why (setup assessment):** nix-media is the fleet's single point of failure — all monitoring/alerting/notifications/LiteLLM/autoUpgrade run on it; the daily `ntfy-heartbeat` dead-man's switch has NO automated absence detector (comment in ntfy.nix says the signal is the phone staying quiet). Everything alerts through public ntfy.sh.

**Design (all facts verified in-session):**
- New flake host `vps`: minimal headless, `mkHost { withHardware = false; lix = false; profiles = [ ]; hmModules = [ ]; }`; sshd public key-only (`core.openssh` defaults are fine, mgmtLanCidr=null ⇒ no LAN rule; host module sets openFirewall + PermitRootLogin prohibit-password); zram, GC 7d (15GB disk), autoUpgrade daily `operation = "switch"` with nix-media's git-pull pattern; stateVersion 26.05.
- gatus 5.35 (`services.gatus` in nixpkgs-26.05): 2 active probes (Caddy `https://nix-media.tail6db26.ts.net` [STATUS]==200; LiteLLM `tcp://100.123.189.29:4001` [CONNECTED]==true, 60s, threshold 3) + 1 external push endpoint for the real dead-man detector. Verified OSS syntax: top-level `external-endpoints:` (name/group/token REQUIRED/heartbeat.interval ≥10s/alerts); push API `POST /api/v1/endpoints/{group}_{name}/external?success=true` with `Authorization: Bearer` header; key = lowercased group_name. `heartbeat.interval: 26h`, failure-threshold 1 (default 3 would delay a daily-miss alert by 3 days). `alerting.ntfy` keys: topic (req)/url/priority/default-alert{enabled,failure-threshold,success-threshold,send-on-resolved}. Secrets via `services.gatus.environmentFile` (KEY=value sops file) + Nix-escaped `"\${VAR}"` interpolation. gatus web :8080 tailnet-only (openFirewall=false; tailscale0 trusted).
- nix-media `ntfy-heartbeat` gains one best-effort curl push (guarded `[ -f ]` on secret paths so the sops-stub VM test stays valid).
- Exit node: `modules/features/vpn.nix` needs a new `advertiseExitNode` bool → `services.tailscale.extraSetFlags = [ "--advertise-exit-node" ]` (option exists, doc example is literally that flag; wrapper currently passes nothing through) + routingFeatures "server".
- nixos-infect = **github.com/elitak/nixos-infect** (nix-community URL 404s; gatus.io docs are client-rendered — WebFetch useless, used browser skill). Infect preserves pre-deployed root SSH key; `NIX_CHANNEL=` / `PROVIDER=` env; wipes disk.
- Deploy order matters: infect → pull real hardware-configuration → age key on VPS `/var/lib/sops-nix/key.txt` → create `secrets/hosts/vps.yaml` (dk_password_hash + ntfy_topic copied from nix-media.yaml via /tmp without display, openssl rand tokens) + side file `secrets/hosts/nix-media-gatus.yaml` (nix-media.yaml is on a retired admin key — side-file precedent) → first deploy built ON YOGA `nixos-rebuild switch --flake .#vps --target-host root@<ip>` → tailscale up in background (foreground stalls silently, [[nix-media-tailscale-ssh-access]] lore) → `tailscale set --advertise-exit-node` + admin-console approval → fill gatus_push_url with tailnet IP → nix-media switch.
- CI (ci.yml/bump.yml) enumerate hosts dynamically — no workflow edits; `scripts/test-suite` ALL_HOSTS/DEFAULT_FAST_HOSTS must gain `vps`. VM gate recommendation: only `nix-media-upgrade-pipeline` (ntfy.nix touched).

Residual limitations documented: alerts still ride public ntfy.sh; nobody watches the VPS itself (daily human-silence heartbeat). First on-box autoUpgrade build ~15-30 min on 1 core. Unknowns left as mechanical checks in plan: repo public/private (deploy key branch), provider name, sops keyPath grep.

Plan text was delivered in full via ExitPlanMode content (user has it); follow [[plans-for-weaker-executor]] rules if re-issuing.

**Status 2026-11-02 (~00:30): Phase 1 EXECUTED+QC green STAGED; Phases 2-8 pending, BLOCKED on user panel action.**

VPS facts: IP **107.150.20.39**, Virtualizor panel (vpsportal.com:4083, user portal), Ubuntu 24.04, ColoCrossing Dublin, 1c/1GB/15GB (4.78GB used — wipe confirmation still pending with user).

Phase 1 executed (all STAGED, never committed): `modules/features/vpn.nix` advertiseExitNode option; flake.nix `vps` entry; `hosts/vps/{default,gatus,maintenance,home,hardware-configuration}.nix`; nix-media ntfy.nix heartbeat gatus push + consolidated sops block + side-file secrets `secrets/hosts/nix-media-gatus.yaml`; placeholder sops files (encrypted admin-only, `placeholder: true`); test-suite ALL_HOSTS/DEFAULT_FAST_HOSTS += vps. `test-suite fast` GREEN: `OK (yoga latitude nix-media vps)`.

Phase-1 gotcha lore (all cost a QC round):
- statix rejects repeated `sops.secrets.X = {}` keys in ONE attrset literal — consolidate into one `sops.secrets = { … }` block (nix-media's genAttrs pattern only works because OnFailure lives in a different FILE).
- `hmModules = [ ]` fails flake check: `home-manager.users.dk.home.stateVersion` unset → every host needs a minimal home.nix (copied nix-media's: git.nix import + stateVersion).
- Empty hardware-configuration fails flake check (`fileSystems` must specify `/`) — placeholder /dev/vda1 ext4 until infect.
- Non-interactive sops encrypt of files outside creation rules: `sops encrypt --age KEY` STILL errors "no matching creation rules" — use `SOPS_CONFIG=<minimal config> sops encrypt <file>` env override.
- yoga builds died with `failed to extract archive (Write failed)` on home-manager-files/generation: /tmp is a 2GB tmpfs and was 71% full of stale `/tmp/lucid-arch-dk` (1.4G, lucid build staging, no process held it open → removed). `TMPDIR=/var/tmp` is the workaround if it recurs.

Panel MCP API = DEAD provider-side: `index.php?act=mcp` returns byte-identical login-page HTML for real vs garbage `X-Virt-Apikey`/`X-Virt-Apipass` headers; classic POST `apikey`/`apipass` also HTML. Panel ships the banner "The MCP server has been disabled by the administrator"; keys have an IP-allowlist field (yoga egress 94.134.158.75). User pasted API creds in chat — kept out of all files/memory; suggested rotation. Not needed: SSH covers everything.

BLOCKER → DIAGNOSED via user's noVNC screenshot (2026-11-02 ~00:30): the box NEVER rebooted into NixOS — it is **still Ubuntu** (vps140190-koz, kernel 7.0.0-14-generic) with kernel `hung_task` spam: `jbd2/vda2-8` (ext4 journal) + `khugepaged` blocked 600+s and climbing. Root cause: **all disk I/O froze mid-infect-build** — explains everything (sshd TCP-accepts but never banners = can't touch disk; ping works = kernel net stack; build died silently; infect never reached its bootloader step, so Ubuntu GRUB is intact). Whether provider-storage hiccup or build-write-load triggered it is unknown. Fix = HARD reset via panel (clean reboot can't complete with journal hung). After reset: verify Ubuntu healthy post-journal-replay → retry infect with gentler settings (keep loop0 swap, modest tmpfs bump, watch log for I/O stall). If it hangs a second time under build load → plan B: kexec-boot the NixOS kexec installer into RAM from Ubuntu, install from there (never trusts the frozen fs again).

VPS hardware (confirmed post-rebuild): Ubuntu 26.04 LTS, BIOS/GRUB boot (no ESP), /dev/vda 15G (vda1 1M bios-grub + vda2 15G ext4 root), 1 core, 955MB RAM, root SSH with yoga key WORKS. Panel Reinstall flow injected the key properly and served as the disk-wipe confirmation.

**Status 2026-11-02 ~01:00: hard reset DONE (user power-cycled), infect RETRY running.** Post-reset verification: clean boot, journal replayed, `touch+sync+rm` disk writes OK, partial /nix from the frozen run present. Retry prep (all via ssh root@): wiped `/nix /root/.nix-* /etc/nix`; re-armed loop swap (`losetup /dev/loop0 /root/swap.img; mkswap; swapon` — reboot clears it, swap.img persists); deliberately did NOT remount /tmp larger this time (default 478M suffices for the nix tarball since makeSwap is skipped by the loop swap; the 1.5G tmpfs + same-disk swap under 955MB RAM = thrash is the prime freeze suspect). Relaunched via `/root/run-infect.sh` (NIX_CHANNEL=nixos-26.05), detached. Background monitor polls 45s with three-way end-state detection learned from the wedge: ssh OK + `ID=nixos` in os-release = SUCCESS; ssh dead but TCP banner present (or hung_task>5, or log size stalled 4.5min) = FREEZE → go kexec plan B; unreachable = rebooting. Monitor ssh uses `UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no` because infect preserves the OLD Ubuntu host keys (host-key CHANGE on NixOS boot would false-fail accept-new); run `ssh-keygen -R 107.150.20.39` once NixOS confirmed, before Phase 3 pulls hardware-configuration. Note: `recipe_*.log` in /root are the PANEL's post-rebuild recipes, not ours.

Console-access lore (cost an hour): the user's noVNC URL (with sessXXX token) does NOT carry into my in-app browser (login redirect — session-bound); panel API is dead so I cannot power-cycle the box myself. Read tool on user-pasted screenshots returns a CDN URL, not pixels — the `analyze_image` MCP CAN read that exact URL (an earlier "1210 image parse error" was my own URL transcription corruption, not a tool fault); browser goto+screenshot+emitImage is the fallback. User just screenshots their own noVNC tab on request — fastest path.

**Status 2026-11-02 ~01:30 → 2026-11-04: SECOND freeze → project HALTED, user started anew with another agent.**

Infect retry #2 outcome (the gentler profile did NOT help): infect log stalled at ~2.6 KB right after the nix bootstrap, then the box went **fully unreachable — no TCP at all** within ~3 minutes of the build phase starting. Second storage freeze, faster and harder than the first. A third power cycle was requested but the session ended before it was confirmed done. **Working conclusion (not proven): this VPS's storage chokes on sustained write bursts (~1.5–2 GB closure unpack); small writes (apt, 60 MB nix bootstrap) survived both times.** Naive infect retries are dead — do not run a third identical attempt.

Plan B (agreed, then CANCELLED by user before execution): yoga builds the vps flake closure locally → after a power cycle, throttled ~4 MB/s `nix copy` store transfer over ssh → infect runs against the pre-seeded store (no local burst). The yoga-side `nix build` was cancelled mid-flight; `/tmp/vps-flake-toplevel` may or may not exist. The kexec-installer variant (RAM-resident install) was the earlier fallback idea, superseded by this.

**Session end (2026-11-04): user started fresh with ANOTHER agent and asked for a factual "what didn't work" handoff (delivered in chat, no suggestions).** Phase 1 remains STAGED-uncommitted and QC-green — a successor agent must NOT redo it; pending repo work = real hardware-configuration after a successful install, sops host_vps identity + .sops.yaml rules, real secrets, docs sync, VM-gate decision (only nix-media-upgrade-pipeline covers the ntfy.nix change).

**Update 2026-11-05:** the restart agent evidently finished the stream (hosts/vps/{install-minimal,platform}.nix + scripts/vps-{seed.sh,finish.sh,seed-export.py} now staged too). User decision: all VPS work commits to a dedicated `vps` branch (NOT main) — see [[branch-split-plan-2026-11-05]]. The .sops.yaml creation-rule gap is confirmed still open (no rule matches vps.yaml / nix-media-gatus.yaml, no host_vps key).

Process lesson from this session (user called it out explicitly): the background monitor DID catch the second freeze but I reported it only after the user prodded ("that worked wonders, same error and you dont mention anything") — surface a background-monitor's bad result the moment it lands, not in the next consolidated update. Also: `pgrep -f nixos-infect` self-matches the ssh command line carrying that string (killed my own cleanup session once); use `nixos[-]infect` bracket patterns and launcher scripts for detached relaunches.

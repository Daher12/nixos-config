---
name: lucid-bluetooth-pairing-agent-2026-10-06
description: lucid can't pair NEW bluetooth devices — root cause VERIFIED = NO BlueZ agent anywhere (quickshell 0.3.1 has no agent API; NOT the wifi bug); bt-agent fix EXECUTED + QC green 2026-10-06, switch pending
metadata:
  node_type: memory
  type: project
  originSessionId: sess_e621e0d7-07d2-451f-96b4-9547c07859ad
---

Diagnosed 2026-10-06, then INDEPENDENTLY RE-VERIFIED on user request (fresh agent, raw journal quotes). Answer to "same as the wifi in the past?": **NO** — [[lucid-wifi-connect-fix-2026-09-30]] was a lucid QML race; this is a missing system component. Not fixable by a lucid patch.

**Root cause (verified):** nothing on yoga registers a BlueZ pairing agent. 13 failed pair attempts (16:27–16:30): bluetoothd `new_auth() No agent available for request type 2` + `device_confirm_passkey: Operation not permitted` and quickshell `WARN ... Failed to pair ...: "Authentication Failed"` match to the EXACT second. Running binary `quickshell-wrapped-0.3.1/bin/.quickshell-wrapped` has only `org.bluez`/Adapter1/Battery1/Device1 strings — **zero** RegisterAgent/AgentManager/RequestConfirmation/RequestPasskey → quickshell 0.3.1 cannot register an agent even in principle (upstream has a known issue about this gap). No agent process anywhere; bluez-tools absent. Existing 3 pairs (Jabra, QK60, Naga Pro) work off cached link keys — only NEW pairings need an agent.

**EXECUTED 2026-10-06 by main session after user approval. ⚠️ Status correction later that evening (a later session found `git diff --cached` EMPTY): the edits are UNSTAGED working-tree only, NOT staged — flake eval/dry-build are blind to them until `git add` is re-run.** (QC green: nix fmt, dry-build .#yoga shows bt-agent.service.drv + bluez-tools fetch).** In `modules/features/bluetooth.nix` (header gains `pkgs`): `systemd.services.bt-agent`, ExecStart `${pkgs.bluez-tools}/bin/bt-agent -c NoInputNoOutput` (JustWorks auto-accept, no MITM — accepted for personal laptop), Restart=on-failure/5s, after+partOf bluetooth.service. ⚠️ **bluetooth.target does NOT exist on this host (verified in store)** → `wantedBy = [ "multi-user.target" ]`, NOT bluetooth.target. bluez-tools confirmed in nixpkgs (0-unstable-2020-10-24).

Lucid BT facts: Bt.qml = Quickshell.Bluetooth + shells `bluetoothctl show`/rfkill every 20 s (the "~20 s Adv Monitor app" journal spam = this timer, harmless). Source = flake input `github:Sn3akyy1/lucid` patched via home/lucid-patches in lucidPatched.

**Open follow-ups:** post-switch `systemctl status bt-agent` + pair the failing device (D3:F3:18:F3:51:19) from lucid panel; quickshell trust handling unverified — if a new HID won't reconnect, `bluetoothctl trust <MAC>`.

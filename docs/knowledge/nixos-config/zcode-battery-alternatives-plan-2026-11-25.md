---
name: zcode-battery-alternatives-plan-2026-11-25
description: ZCode Electron battery question 2026-11-25 — verdicts (.deb/.rpm =
  same build, zero gain; AppImage ignores NIXOS_OZONE_WL → XWayland) + full
  alternatives evaluation table; FLAGS MITIGATION EXECUTED 11-25 (--ozone-platform=wayland
  on Exec, staged, fast green, switch pending); A/B DONE: V3 compositing-off UNUSABLE
  (jank), V2 = final, app_id re-probe still open
metadata:
  node_type: memory
  type: project
  originSessionId: sess_5bb49131-86f5-4f40-9f52-2c11566f7d47
---

Battery + alternatives round for ZCode Desktop, 2026-11-25 (on top of zcode 4.0.0 bump, see [[update-sweep-2026-11-25]]). User concern: Electron AppImage costs more battery than other apps; asked about .deb/.rpm and alternatives (integration level, programming, packaging). User picked "flags mitigation only"; **EXECUTED 2026-11-25: `--ozone-platform=wayland` appended to the Exec line in hosts/yoga/home.nix (both branches + rationale comment), staged (NOT committed), `test-suite fast yoga` OK, nix eval confirms both attrs render the flag (niri: `zcode-unmax --no-sandbox --ozone-platform=wayland %u`; gnome: `zcode --no-sandbox --ozone-platform=wayland %u`). Switch + relaunch still owed by user; **A/B EXECUTED 2026-11-25: V3 (`--disable-gpu-compositing`) UNUSABLE — UI too janky, disqualified on usability regardless of watt numbers; V2 is the final state, nothing more baked into the Exec line.** Only the app_id re-probe (after switch + launcher relaunch) stays OPEN (recipe below).**

**Verdicts (source-verified):**
- **.deb/.rpm = ZERO gain**: all three formats ship the identical Electron build from the same CDN dir (`cdn-zcode.z.ai/zcode/electron/releases/<v>/linux-x64/ZCode-<v>-linux-x64.{deb,rpm,AppImage}`). Cost = Chromium itself (GPU compositing blocks iGPU RC6; animations repaint ~60fps, holds up always-on-VRR eDP-1 panel). Only flags or not-running help.
- **Repo launch path**: desktop entry `hosts/yoga/home.nix` ~L205-206 (`zcode-unmax --no-sandbox %u`, niri branch) → zcode-unmax forwards `"$@"` (home/niri.nix L609) → bwrap wrapper → Electron argv. Desktop entry is HM-owned read-only symlink, survives ZCode's self-rewrite. **Stock Electron ignores NIXOS_OZONE_WL** (nixpkgs-only convention, and HM sessionVariables only reach shell-launched procs anyway) → ZCode runs under **XWayland**, extra frame copies.
- **app_id contingency**: zcode-unmax probes `app_id == "zcode"` (niri.nix L618); native Wayland may change it (XWayland derived it from WM_CLASS "ZCode") — re-probe after flag switch.

**Alternatives table (GLM coding plan compat):**
- **opencode** (TS/Bun; already in flake, pinned v2.4.1): OFFICIAL GLM-plan support, built-in "Z.AI Coding Plan" login; ~zero idle; highest integration (Nov parity work done). Best lever = opencode-in-foot habit, quit ZCode when done.
- **Zed** (Rust/GPUI; nixpkgs `zed-editor` from source, GPL-3.0, free; official Linux distro = tar.gz only): full agent panel (edits/terminal/MCP). Works with GLM plan via `openai_compatible` → `https://api.z.ai/api/coding/paas/v4` (Zed ≥0.204, issue #38153) but NOT on Z.ai's official tool list — plan-ToS gray zone. Better-than-Electron battery likely but unproven (GPU-rendered, past idle-CPU issues #4944).
- **Claude Code** (native Node-free binary; nixpkgs `claude-code` PREBUILT, unfree): official GLM plan via `ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic` + `ANTHROPIC_AUTH_TOKEN`.
- **Codex CLI** (Rust; nixpkgs `codex` source): Z.ai-listed, endpoint `https://api.z.ai/api/v1`. **gemini-cli** (TS/Node; nixpkgs) not listed; **aider** (Python; nixpkgs `aider-chat`) unofficial.
- **No win (same Electron class)**: Chatbox, Cherry Studio, Cursor (Z.ai-listed but Electron), Windsurf. **Jan** = Tauri 2 (better than Electron). LibreChat/open-webui = self-hosted web, browser-tab cost.
- **GLM-plan endpoint lore**: coding-plan keys consume quota ONLY via `api/anthropic` (Claude Code/Goose), `api/coding/paas/v4` (other tools), `api/v1` (Codex); general endpoint `api/paas/v4` does NOT consume plan quota (401/1113 errors lore confirmed by community, docs only document the split).

**Approved plan (user picked "Flags mitigation only"):** append `--ozone-platform=wayland` to the Exec line in hosts/yoga/home.nix (~L205-206, both branches), rationale comment; battery A/B recipe (V0 quit / V1 bare / V2 wayland / V3 +`--disable-gpu-compositing`, 36×5s power_now samples); if V3 wins, bake it in; app_id re-probe; stage + `nix fmt` + `test-suite fast yoga`. Declined: Zed add, full opencode migration (would kill ZCode memory pipeline + panels; removal checklist parked at docs/opencode-migration.md L41-46).

**A/B protocol (elaborated for user 2026-11-25, full text in that session):** battery node = `/sys/class/power_supply/BAT0/power_now` in µW (reads 0 on AC → unplug mandatory + 60s TLP settle); `xlsclients` NOT installed, mode ground-truth = `ps -eo args | grep -- --ozone-platform` on the running process. V1 (`zcode --no-sandbox`, must have ELECTRON_OZONE_PLATFORM_HINT unset) = old XWayland path; V3 = V2 + `--disable-gpu-compositing` (software compositing, judge UI jank during settle). Traps: Electron single-instance — `pkill -f zcode` + empty `pgrep` between variants or new flags silently land in the old process; screen stays on/unlocked (lockscreen = discard sample); idle-only (model streaming spikes multi-W regardless); SoC ≥50%; same brightness; screen-on state unchanged (battery-refresh floors panel to 60Hz on battery — constant across variants). Decision rule: <0.3 W delta = noise; end with a V2-repeat drift sample; if V3 > V2 by >0.3 W and feels fine → bake flag into Exec. **VERDICT: V3 jank → rule never reached; V2 final.** NOTE: A/B works on current generation (terminal launch bypasses the staged entry change).

**User sentiment (2026-11-25):** feels models perform BETTER in ZCode Desktop, attributing it to the auto-memory system — treat full migration away from ZCode as unlikely; the push-based memory (MEMORY.md auto-injected each session) vs opencode's pull-based AGENTS.md "read the archive first" instruction is the mechanical difference. Don't pitch migration again; optimize ZCode's cost instead.

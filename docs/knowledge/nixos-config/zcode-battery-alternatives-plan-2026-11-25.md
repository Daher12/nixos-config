---
name: zcode-battery-alternatives-plan-2026-11-25
description: ZCode Electron battery question 2026-11-25 — verdicts (.deb/.rpm =
  same build, zero gain; AppImage ignores NIXOS_OZONE_WL → XWayland) + full
  alternatives evaluation table; PLAN (flags mitigation) built, ExitPlanMode
  DENIED, NOTHING executed
metadata:
  node_type: memory
  type: project
  originSessionId: sess_5bb49131-86f5-4f40-9f52-2c11566f7d47
---

Battery + alternatives round for ZCode Desktop, 2026-11-25 (on top of zcode 4.0.0 bump, see [[update-sweep-2026-11-25]]). User concern: Electron AppImage costs more battery than other apps; asked about .deb/.rpm and alternatives (integration level, programming, packaging). **PLAN DELIVERED but ExitPlanMode DENIED — NOTHING executed.**

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

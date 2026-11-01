# opencode migration (ZCode → opencode)

Created 2026-11-01 from a full audit of both tools' state and the repo wiring.
Parity items are already ported into the repo (list below); this file records
the migration-day procedure, what was deliberately **not** ported, and the
hand-held state that exists only on this machine.

## Already ported (2026-11-01, staged)

- **Knowledge base**: `docs/knowledge/` mirrors the ZCode auto-memory archive
  (155 md files, 4 project dirs + curated `MEMORY.md` indexes); re-sync with
  `scripts/export-zcode-memory` (`--check` for drift + secret scan). Pointers
  live in `AGENTS.md` and `AGENTS-global.md` — both tools read those. The
  first scan caught a live LiteLLM master key inside
  `obsidian-litellm-integration-2026-10-04.md`; it is redacted in BOTH the
  mirror and the ZCode source memory (recoverable via the sops readback noted
  in that same record).
- **Document skills** `docx` / `pdf` / `pptx` / `xlsx`:
  `home/opencode-skills/` → `~/.config/opencode/skills/` via
  `home/opencode.nix` (`xdg.configFile`). Sourced from the ZCode plugin cache
  (documents 0.2.1, pdf 0.2.2) with the ZCode-only `::zcode-file-citation`
  sections replaced by plain path reporting.
- **Bash allowlist**: curated subset of ZCode's ~480 accumulated approvals
  (frequency-ranked: journalctl, nix eval/build/fmt/flake-check,
  nixos-rebuild dry-build, git add/log/show, read-only utils) merged into
  `permission.bash` in `home/opencode.nix`. Not allowed on purpose: `nix flake
  update`, `nix store gc/delete`, `sops`, switch/boot, `test-suite vm|full`.
- **Model**: `glm-5.3` (reasoningEffort high) added to the `zai-coding-plan`
  provider — parity with ZCode's main model; flash stays the default.

## Migration-day checklist

1. `./scripts/export-zcode-memory --check` then `./scripts/export-zcode-memory`
   (final knowledge re-export; the script refuses to finish on secret hits).
2. Switch: `./scripts/update-safe yoga switch` (and latitude if desired).
3. Smoke-test opencode: skills listed via its skill tool, `glm-5.3` pickable in
   the model menu, `nix flake check` runs without a bash prompt.
4. Both tools can run in parallel meanwhile — nothing shared breaks. Keep
   `~/.zcode` intact (read-only in practice) through a cooling-off period.
5. Retire ZCode (repo side):
   - `hosts/yoga/home.nix`: drop `pkgs.zcode` from `home.packages`, the
     `xdg.desktopEntries.zcode` block, the `x-scheme-handler/zcode` mimeApps
     line, and the `.config/ZCode` + `.zcode` persistence entries (only once
     you no longer want the rollback path).
   - `flake.nix`: remove the `zcode = final.callPackage ./pkgs/zcode.nix`
     overlay line; delete `pkgs/zcode.nix`; update REPO_OVERVIEW.md rows.
6. Only after the cooling-off period: delete `~/.zcode` (≈550 MB — session DB,
   transcripts, credentials, private network CA) and `~/.config/ZCode`.

## Hand-held opencode state (not in the repo)

- `~/.local/share/opencode/auth.json` — provider keys: openrouter, opencode,
  opencode-go, zai, zai-coding-plan (`opencode auth login` to re-create).
- `~/.config/opencode/cli.json` — TUI prefs (theme nord, diff word-wrap, …).
- `~/.local/state/opencode/` — kv/model UI state, prompt history.
- `~/.config/opencode/package.json` + `node_modules/` — plugin-SDK scaffolding
  from an old experiment, **no actual plugin**; deletable.
- `~/.local/share/opencode/opencode-stable.db` — leftover from a former
  "stable" channel install (2026-07); deletable.

## Deliberately not ported (ZCode-bound) + alternatives

- `browser-use` / `computer-use` plugins (embedded browser, desktop control):
  no opencode equivalent built in — add a Playwright MCP server if needed.
- `dynamic-workflows` (scripted multi-subagent orchestration): no equivalent;
  opencode custom agents/commands cover part of the use case.
- `zcode-guide`, `plugin-creator`, `skill-creator`, `*-viewer` skills: bound to
  ZCode's host app (panels/plugins).
- The two ZCode automations (Periodic Network Scan — paused; LiteLLM gateway
  evaluation — fired 2026-11-01 in ZCode): skipped by user decision. If ever
  needed again, wrap `opencode run "<prompt>"` in a systemd user timer.
- Session history, transcripts, model-io traces: not portable, not wanted.

## ZCode-side inventory (for retirement reference)

- Active provider: zai-coding-plan GLM-5.3 (reasoning low/max/high variants) —
  opencode parity via the `zai-coding-plan` provider + `glm-5.3` entry.
- Auto-memory: 155 md files across 4 projects (mirrored — see above).
- Bash rulesets: 4 project-scoped rulesets (22/356/75/3 allow rules) in
  `~/.zcode/cli/db/db.sqlite`, table `local_setting`, key `ruleset`.
- Automations: `~/.zcode/v2/tasks-index.sqlite` (2, see above).
- Credentials: `~/.zcode/v2/credentials.json` (zai oauth), `v2/certs/`
  (private network CA) — ZCode-specific, die with the directory; never copy.

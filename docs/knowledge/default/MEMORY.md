# Memory Index

- [ZCode model provider config](zcode-model-provider-config.md) — schema/kinds/baseURL semantics for custom providers in ~/.zcode/v2/config.json
- [ZCode provider clobber race](zcode-provider-clobber-race.md) — external edits to v2/config.json get reverted by the running app; re-add + restart
- [OpenCode Zen account](user-opencode-zen-account.md) — API key location in ~/.local/share/opencode/auth.json for opencode.ai/zen endpoints
- [Win11 VM access](win11-vm-access.md) — SSH admin key setup DONE 2026-10-01; windows-mcp full path + restart via `start /b`; bounded SSH+EncodedCommand pattern
- [windows-mcp curl bridge](windows-mcp-curl-bridge.md) — drive windows-mcp over raw curl SSE when session lacks MCP tools; mcp.sh helper, App/Screenshot schemas; wedge pitfalls (no tool timeouts, session init required)
- [Win11 VM troubleshooting](win11-vm-troubleshooting.md) — clean reinstall did NOT fix the iTunes hang; AMDS service accepts 27015 but never replies (GATE 4 done 2026-10-01), awaiting Phase 5 (LOCALAPPDATA rename + procmon); host RAM overcommit + missing balloon service
- [Apple iTunes Windows installer layout](apple-itunes-windows-installer-layout.md) — 2026 bundle = 2 MSIs only; AAS merged into iTunes64.msi; no Bonjour/AppleMobileDeviceProcess.exe; AUTORUN=0 for silent installs
- [German content preference](user-german-content-preference.md) — user converses in English but wants deliverable text in German; ISO dates in frontmatter, DD.MM.YYYY displayed
- [Obsidian vault setup](obsidian-vault-setup.md) — vault at ~/Dokumente/Notes; Vorlagen/ with 5 German templates + config wiring done 2026-10-06; reload Obsidian after external .obsidian/*.json edits

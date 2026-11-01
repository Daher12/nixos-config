---
name: obsidian-remotely-save-onedrive-400
description: Obsidian remotely-save OneDrive "Request failed, status 400" on
  FIRST sync — folder-create bug #1185, workaround = manual Notes folder in OneDrive web UI; vault at ~/Dokumente/Notes
metadata:
  node_type: memory
  type: project
  originSessionId: sess_0d2cd53e-a1b0-481c-8f52-0e092cbbb140
---

2026-10-05: user could not set up OneDrive sync via remotely-save in Obsidian. Diagnosis complete, workaround delivered; **user has NOT yet confirmed applying it**.

**Root cause** (GitHub issue #1185, open, no fix as of plugin 0.5.25): on a first-time connection where the vault-named subfolder does not exist under `/Apps/remotely-save/`, the plugin's folder-create POST uses `@microsoft.graph.conflictBehavior: "replace"` — OneDrive only allows `replace` for FILES, not folders → generic 400. OAuth itself works fine (token exchange, refresh, children GET all 200; only the folder-creation POST 400s). Matches log signature: "Received URL action ... remotely-save-cb-onedrive" → "accessToken updated" → "remote does not have folder /Notes" ×2 → "Request failed, status 400".

**Workaround given**: create a folder named exactly `Notes` by hand on onedrive.live.com (My files → Apps → remotely-save app folder), then sync/connectivity check in Obsidian. The failing call only fires when the folder is absent, so it keeps working after. Recurs on any NEW device or new vault name until upstream fixes it — same workaround applies.

**Distinguish from other OneDrive 400s**: 400 on an ALREADY-WORKING setup = different cause, fixed by revoke-auth + re-authorize (issue #1011). Issue #1170 (Obsidian 1.12.7 `request()` breakage; community fork Deadbush225 swaps `request()`→`requestUrl()`) was NOT the cause here — earlier Graph GETs succeeded in the log.

**Environment facts**: only Obsidian vault = `~/Dokumente/Notes` (from `~/.config/obsidian/obsidian.json`); Obsidian 1.13.7; remotely-save 0.5.25 (version in `.obsidian/plugins/remotely-save/manifest.json`, plugin lives in the vault, not nix-declared). The `obsidian://` handler pin (commit ee68ffc) is what made the OAuth URL-action callback land — do not remove it. Note: `data.json` in the plugin dir had NO onedrive keys (serviceType null etc.) — auth/token state is stored elsewhere (likely Obsidian localStorage), so grepping data.json for auth state is misleading.

**Sync scope facts (2026-10-05 follow-up, user asked "is that right?")**: remotely-save syncs the ENTIRE vault root — user was surprised that `copilot/` and `rs-test-folder-…` appeared on OneDrive/Obsidian; that IS expected behavior, not a bug. Vault contents confirmed: Obsidian Copilot saves every chat as a markdown note under `copilot/copilot-conversations/` (e.g. `agent__rechtschreibprüfung@20261005_211339.md`) — those transcripts land on Microsoft's cloud; `.copilot/` and `.opencode/` dotdirs also sit in the vault; `rs-test-folder-<random>` (string constant in the plugin main.js) is remotely-save's own connectivity-test leftover — empty, safe to delete, recreated on every connectivity check. `ignorePaths` defaults to `[]` (nothing ignored). Advice given, **user NOT yet confirmed applying**: add ignorePaths regexes `^copilot/`, `rs-test-folder`, `^\.copilot`, `^\.opencode`; ignoring only stops FUTURE syncs — already-uploaded files (the conversation notes) must be deleted via OneDrive web UI; and keep "sync config dir" OFF, else `.obsidian` uploads incl. plugin settings with API keys.

Related: [[obsidian-litellm-integration-2026-10-04]] (other Obsidian work).

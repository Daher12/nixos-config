---
name: zcode-provider-clobber-race
description: Editing ZCode's ~/.zcode/v2/config.json while the app is running
  gets silently reverted on restart
metadata:
  node_type: memory
  type: project
  originSessionId: sess_1b291b48-4a40-4a7b-a1ea-39a59b657499
---

While ZCode desktop is running, hand-edits to the `provider` map in `~/.zcode/v2/config.json` can be silently erased: the app holds its provider list in memory and rewrites the file from that list on provider operations (OAuth sync at startup, save/delete/toggle). A stale write from the old instance clobbered an external edit right at restart, so the new instance never saw the change.

**Why:** the writer (`Zh/writeProviderStoreFile`) re-reads the raw file but rebuilds the `provider` map only from the in-memory list; entries not in memory are dropped.

**How to apply:** after editing the file externally, re-add the entry (the app may have overwritten it) and verify it stays (`jq '.provider | keys'`), then have the user fully restart the app — the loader (`HZe`) adopts valid file entries into the in-memory list at startup, after which writes preserve them. If it still doesn't appear after one clean restart, fall back to adding the provider via the app UI (Settings → Model Providers). Monitoring the file mtime/keys for a few minutes confirms no background rewrite is in progress.

Related: [[zcode-model-provider-config]]

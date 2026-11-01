---
name: obsidian-vault-setup
description: Obsidian vault at ~/Dokumente/Notes — German template set created
  2026-10-06, config wiring, plugin inventory, running-app config-clobber caveat
metadata:
  node_type: memory
  type: project
  originSessionId: sess_94dddd67-5855-4072-9b80-4b2a527d20c0
---

The user's Obsidian vault is at `/home/dk/Dokumente/Notes` (Obsidian 1.13.7, installed via Nix). On 2026-10-06 I set up a German template system: `Vorlagen/` holds five templates — Kurze Notiz, Aufgabenliste (Eisenhower matrix), Tagesnotiz, Meeting, Projekt — using the `typ`/`status`/`erstellt`/`tags` frontmatter convention with ISO dates. `templates.json` points the core Templates plugin at `Vorlagen/`, and `daily-notes.json` uses `Vorlagen/Tagesnotiz` as the daily-note template.

Core plugins enabled: templates, daily-notes, bases, properties, canvas, sync. Community plugins: copilot, remotely-save. The vault was essentially empty apart from copilot-generated folders when set up.

**Why:** Future note work should extend the existing Vorlagen structure and property convention rather than inventing parallel ones, and needs to know the config was externally edited (so unexplained reverts are explainable).

**How to apply:** When editing `.obsidian/*.json` while Obsidian is running, the app caches config in memory and may overwrite external edits when it closes — have the user reload (Ctrl+R) or restart right after external config changes. Related: [[user-german-content-preference]], [[zcode-provider-clobber-race]] (same clobber pattern in a different app).

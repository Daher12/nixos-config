---
name: user-german-content-preference
description: User converses in English but wants deliverable text content
  (notes, docs, templates) written in German
metadata:
  node_type: memory
  type: user
  originSessionId: sess_94dddd67-5855-4072-9b80-4b2a527d20c0
---

The user writes conversationally in English but explicitly requested deliverable content in German ("please create them in german if text is present"). Their environment is German-locale: Obsidian launches with `--lang=de`, notes live under `~/Dokumente`, and they prefer `DD.MM.YYYY` date display (Obsidian templates.json/daily-notes both set to that format).

**Why:** German is the user's working language for anything a human reads; English is just the conversation language with the agent.

**How to apply:** Default to German for note/document/template/UI text in deliverables. Keep machine-readable parts in English/ISO so tooling still works — YAML property keys like `tags`/`typ`/`status`, and frontmatter dates as `YYYY-MM-DD` (Obsidian only parses those as date properties) — while body text and displayed dates use German/DD.MM.YYYY. Related: [[obsidian-vault-setup]].

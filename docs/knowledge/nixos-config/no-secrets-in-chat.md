---
name: no-secrets-in-chat
description: Never ask the user to paste API keys/secret material into chat —
  offer sops edit self-service + masked-decrypt verification instead
metadata:
  node_type: memory
  type: feedback
  originSessionId: sess_22722a8a-e610-464e-b9f9-e46386d45533
---

2026-10-04, litellm OpenRouter key handoff: I asked the user to paste the key in chat; they pushed back ("should i really paste the api keys in this chat?"). The correct answer was no — their instinct was right and I should have offered the self-service route first.

**Why:** Chat content is sent to the model provider's API (potentially logged server-side) and persisted in the local session transcript on disk — both outside the sops boundary this repo's secrets architecture is built on. The AGENTS.md "secrets never in plain files" principle extends to the conversation transcript. A spend-capped dedicated key limits blast radius but "never enters chat" is strictly better.

**How to apply:** When a secret must land in a sops file, have the user fill it themselves via `sops edit <file>` (key never touches chat, shell history, or plaintext disk; sops re-encrypts with the correct recipients on save), then re-`git add` — staging is not sticky across edits, and sops files enter the closure through the git index. Verify afterwards with a MASKED decrypt: `sops -d file | awk` classifying values (placeholder / filled+len / prefix shape like `sk-or-`) without ever printing them — this pattern was shown to the user and accepted. Fallback if the user can't or won't edit encrypted files: they drop the key into a `chmod 600` file under `/tmp` (tmpfs, gone on reboot) and the agent substitutes without echoing it. Never request secrets in-chat even when the user's own todo notes say "hand it to me in chat" — those notes were written before this correction. See [[obsidian-litellm-integration-2026-10-04]].

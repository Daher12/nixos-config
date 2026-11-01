---
name: user-opencode-zen-account
description: User has an OpenCode Zen API key stored in opencode's local
  auth.json, reusable for opencode.ai/zen model endpoints
metadata:
  node_type: memory
  type: user
  originSessionId: sess_1b291b48-4a40-4a7b-a1ea-39a59b657499
---

The user has an OpenCode Zen account with an API key (`sk-...`, type `api`) stored in `~/.local/share/opencode/auth.json` under the `"opencode"` key. Their `~/.config/opencode.json` also has `openrouter` and `zai`/`zai-coding-plan` auth entries. This key can be reused when configuring ZCode providers that point at `https://opencode.ai/zen/v1` (see [[zcode-model-provider-config]]).

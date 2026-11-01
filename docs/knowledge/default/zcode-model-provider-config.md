---
name: zcode-model-provider-config
description: Where and how ZCode desktop stores custom model providers
  (v2/config.json schema, kinds, baseURL semantics)
metadata:
  node_type: memory
  type: reference
  originSessionId: sess_1b291b48-4a40-4a7b-a1ea-39a59b657499
---

ZCode desktop (v3.10.x) stores model providers in `~/.zcode/v2/config.json` under a `provider` map keyed by provider id. Builtins are `builtin:zai`, `builtin:bigmodel`, etc.; user custom providers use `custom:<name>` (optionally `custom:<enc(name)>:<enc(model)>`).

Entry shape (matches the app's internal zod schemas, `AZe`/`TZe`/`EZe` — provider record and model record, both `.passthrough()`):
```json
{
  "name": "...", "kind": "openai", "enabled": true, "source": "custom",
  "options": { "apiKey": "...", "baseURL": "https://host/v1" },
  "models": {
    "<model-id>": {
      "name": "...",
      "reasoning": { "enabled": true, "variants": ["low","medium","high"], "defaultVariant": "high" },
      "limit": { "context": N, "output": N },
      "modalities": { "input": [...], "output": ["text"] },
      "priority": 90,
      "zcode": { "reasoning": { "enabled": true, "levels": [{"value":"low","label":"low"},...],
        "defaultLevel": "high",
        "providerOptionsByLevel": { "low": {"openai": {"reasoningEffort":"low"}}, ... } } }
    }
  }
}
```

Key semantics learned from the app bundle (`app.asar` / `resources/glm/zcode.cjs`):
- Supported `kind` values: `anthropic`, `openai`, `openai-compatible`. `openai` maps to the OpenAI **Responses** API (`/responses`); `openai-compatible` maps to chat completions.
- baseURL handling differs by kind: `openai` kind passes baseURL raw to `createOpenAI()` (SDK appends `/responses` itself, so use e.g. `https://opencode.ai/zen/v1`); `anthropic` kind runs baseURL through a normalizer that forces a trailing `/v1` and appends `/messages`.
- An API key is required for kinds `openai`/`anthropic`/`gateway` unless `apiKeyRequired: false`; put it in `options.apiKey`.
- Reasoning effort for OpenAI-kind models is wired via `zcode.reasoning.providerOptionsByLevel` with `{"openai": {"reasoningEffort": "<level>"}}` per level; variant names are free-form strings.
- The loader is `HZe/readZCodeConfigProviders` (parses with `ZZe` per entry, rebuilds the map only from entries that survive, and rewrites the file if anything changed). The writer `Zh/writeProviderStoreFile` re-reads the raw file first but rebuilds the `provider` map **only from the in-memory provider list**.

See [[zcode-provider-clobber-race]] for the editing pitfall.

# Documentation Index

Central reference for all documentation in this repository. Each entry includes
a status tag to indicate maturity and whether it reflects the current state of
the code.

**Status tags:**
- `✓` — Up to date and accurate
- `◌` — Partially applies (some sections may be stale)
- `!` — Needs revision

---

## Architecture & Reference

| Doc | Status | Description |
|-----|--------|-------------|
| [REPO_OVERVIEW.md](../REPO_OVERVIEW.md) | `✓` | Full repository map: hosts, modules, profiles, secrets, CI, commands. The single-entry reference for understanding the entire flake. |
| [REFACTOR-OVERVIEW.md](REFACTOR-OVERVIEW.md) | `✓` | Catalogue of all structural changes plus Phase 3 AI-assisted audit (2026-06): lix URLs, impermanence validation, Jellyfin paths, wakeup rule, lix package mode. |

---

## Operations

| Doc | Status | Description |
|-----|--------|-------------|
| [impermanence.md](impermanence.md) | `✓` | Btrfs root rollback on boot: data model (`@` / `@blank` / `/persist`), when and how to update the template snapshot, directory validation, recovery procedures. |
| [upgrade-26.05.md](upgrade-26.05.md) | `✓` | NixOS 25.11 → 26.05 upgrade record: all breaking changes fixed (8 items), flake input updates, adopted defaults, deployment notes, verification commands. |

---

## Troubleshooting

| Doc | Status | Description |
|-----|--------|-------------|
| [opencode-provider-persistence.md](opencode-provider-persistence.md) | `◌` | OpenCode built-in provider drops after rebuild: diagnostics, findings, open questions. Also covers the `libstdc++.so.6` LD_LIBRARY_PATH fix (see upgrade-26.05.md). |
| [plymouth_luks_issue.md](plymouth_luks_issue.md) | `!` | Plymouth LUKS prompt fails on AMD (yoga): root cause (simpledrm vs amdgpu race), proposed fix (initcall blacklist), configuration history. **Fix not yet applied.** |
| [plymouth_luks_label_text.md](plymouth_luks_label_text.md) | `✓` | Plymouth LUKS prompt shows unwanted text below password input: root cause (label-freetype.so in initrd), fix (exclude label plugins from initrd derivation), verification steps. |
| [intel-gpu-metrics.md](intel-gpu-metrics.md) | `✓` | Intel GPU monitoring service on nix-media: architecture, 26.05 upgrade failure (`intel-gpu-tools` 2.2→2.3), awk parsing, Grafana queries. |

---

## Packages

| Doc | Status | Description |
|-----|--------|-------------|
| [msty-appimage.md](msty-appimage.md) | `✓` | Msty Studio AppImage packaging: derivation notes, add/remove from host, update procedure, rationale for `appimageTools.wrapType2`, alternatives considered, changelog. |

---

## Related Root-Level Files

| File | Status | Description |
|------|--------|-------------|
| [README.md](../README.md) | `◌` | Quick-start badge page: hosts, stack, deployment commands. |
| [REPO_OVERVIEW.md](../REPO_OVERVIEW.md) | `✓` | Full repository overview for AI models and contributors (see Architecture above). |

---

## Cross-Reference Map

Links between related documents:

```
REPO_OVERVIEW.md
  → REFACTOR-OVERVIEW.md  (covers structural changes to the codebase)
  → impermanence.md        (covers the impermanence module in detail)

upgrade-26.05.md
  → impermanence.md        (@blank update requirement after file system changes)
  → opencode-provider-persistence.md  (LD_LIBRARY_PATH wrap shares context)

opencode-provider-persistence.md
  → upgrade-26.05.md        (libstdc++ fix documented in upgrade guide)

msty-appimage.md
  → REPO_OVERVIEW.md        (package location and mkHost integration)

plymouth_luks_label_text.md
  → plymouth_luks_issue.md  (related Plymouth + LUKS issue on AMD hosts)
```

---

## Adding New Documentation

New docs should be added to this index under the appropriate category with a
`✓`/`◌`/`!` status tag. If another document covers related material, add a
cross-reference entry to the map above.

**Checklist for new docs:**

- [ ] File uses `.md` extension with lowercase filename (underscores for spaces)
- [ ] Frontmatter or first paragraph states the document's purpose
- [ ] Added to INDEX.md with status tag and brief description
- [ ] Added to cross-reference map if related to existing docs
- [ ] Root-level files linked with `../` prefix; docs/ files linked without prefix

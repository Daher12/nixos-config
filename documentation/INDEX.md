# Documentation Index

Categorized reference for all documentation in this repository.

---

## Architecture & Refactoring

| Document | Description |
|----------|-------------|
| [refactor-overview.md](refactor-overview.md) | Comprehensive review of all recent refactoring changes: what changed, why, technical evaluation of each change, verification status |

---

## Upgrade Guides

| Document | Description |
|----------|-------------|
| [upgrade-26.05.md](upgrade-26.05.md) | NixOS 25.11 → 26.05 upgrade: all breaking changes, migration steps, verification commands |

---

## Troubleshooting & Fixes

| Document | Description |
|----------|-------------|
| [opencode-provider-persistence.md](opencode-provider-persistence.md) | OpenCode built-in provider drops after rebuild; investigation, findings, and next steps |
| [plymouth_luks_issue.md](plymouth_luks_issue.md) | Plymouth graphical LUKS screen fails on AMD; root cause (`amdgpu` removes `simpledrm`), fix, and verification |
| [intel-gpu-metrics.md](intel-gpu-metrics.md) | Intel GPU metrics service: architecture, 26.05 upgrade failure (`intel-gpu-tools` 2.2→2.3), fix applied |

---

## Package Documentation

| Document | Description |
|----------|-------------|
| [msty-appimage.md](msty-appimage.md) | Msty Studio AppImage packaging: derivation notes, add/remove from host, update procedure |

---

## Related: Root-Level Files

| File | Description |
|------|-------------|
| [../README.md](../README.md) | Repository overview: hosts, stack, structure, deployment |
| [../pkgs/msty.md](../pkgs/msty.md) | Duplicate of `msty-appimage.md` (package-local copy) |

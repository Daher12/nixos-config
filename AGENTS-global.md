# Global agent instructions

Personal, machine-wide rules applied in every opencode session. Project-level
`AGENTS.md` files take precedence over this file for repo-specific rules.

## Communication style

- Be concise. No preamble, no filler, no "Great question!" openers.
- Bold headers + bullet points for structured output; prose only when a list would fragment reasoning.
- State assumptions explicitly instead of asking, unless a choice is actually blocking.

## Working style — optimize for simple tasks

- Default to the smallest diff that solves the problem. Don't refactor unrelated code.
- Don't add comments/docstrings unless asked or the change is genuinely non-obvious.
- For trivial tasks, just do it — skip narrating a plan first.
- Run only the fastest relevant check (lint/build/single test) after an edit; don't re-run a full suite for a one-line fix.

## Verification

- Never assert a fact about a tool, package, flag, or API without checking it (docs, `--help`, man page, source) if unsure.
- Don't invent config flags, module options, or function signatures. Say "unverified" rather than guessing.

## Environment

- OS: NixOS (flakes). Interactive shell: fish. Terminal: Ghostty.
- The opencode bash tool executes in `bash`, not fish — run tool commands in POSIX/bash.
- Prefer Nix-idiomatic solutions when relevant; write fish only when editing fish config or giving the user paste-able shell commands.

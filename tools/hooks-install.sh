#!/usr/bin/env bash
# tools/hooks-install.sh — points core.hooksPath at the tracked hooks/ of a repository; idempotent.
# Entry: bash tools/hooks-install.sh [repo-path]; spec — AGENTS.md (agent-kit core), invariant 5.
set -euo pipefail

ROOT="$(git -C "${1:-.}" rev-parse --show-toplevel)"
for hook in pre-commit pre-push; do
  [ -f "$ROOT/hooks/$hook" ] || { echo "hooks-install: missing $ROOT/hooks/$hook" >&2; exit 1; }
  chmod +x "$ROOT/hooks/$hook"
done
# A relative hooksPath resolves against each worktree root, so every tree runs its own tracked hooks.
git -C "$ROOT" config core.hooksPath hooks
echo "hooks-install: core.hooksPath = hooks (pre-commit, pre-push) in $ROOT"

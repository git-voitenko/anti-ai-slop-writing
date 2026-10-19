#!/bin/bash
# Claude cloud environment «anti-ai-slop-writing»: VM setup run before the session, outside the repo; pasted by the owner.
# Every step is best-effort and the script always exits 0 — a failure blocks every session (agent-kit docs/cloud/README.md).
REPO="${REPO:-/home/user/anti-ai-slop-writing}"

if [ -d "$REPO/.git" ]; then
  (cd "$REPO" && bash tools/hooks-install.sh) || echo "WARN: git-хуки не установлены" >&2
else
  echo "WARN: нет $REPO/.git — git-хуки пропущены" >&2
fi

# Project toolchain (node from .nvmrc, python, Playwright …) goes here; secrets never do.

exit 0

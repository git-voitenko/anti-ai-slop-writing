#!/usr/bin/env bash
# Codex app cloud environment «anti-ai-slop-writing»: container setup before the agent, with internet; pasted by the owner.
# Every step is best-effort and the script always exits 0 — a failure blocks every task (agent-kit docs/cloud/README.md).
set -uo pipefail
REPO="${REPO:-/workspace/anti-ai-slop-writing}"
warn() { echo "WARN: $*" >&2; }

if [ -d "$REPO/.git" ]; then
  (cd "$REPO" && bash tools/hooks-install.sh) || warn "git-хуки не установлены"
  # Warm dependencies while setup still has internet; the agent's verify then runs offline.
  (cd "$REPO" && bash tools/verify.sh --fast >/tmp/setup-verify.log 2>&1) || warn "verify при установке не зелёный — /tmp/setup-verify.log"
else
  warn "нет $REPO/.git — установка пропущена"
fi

exit 0

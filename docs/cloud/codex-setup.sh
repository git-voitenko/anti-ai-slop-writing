#!/usr/bin/env bash
# Codex app cloud environment «anti-ai-slop-writing»: container setup before the agent, with internet; pasted by the owner.
# Every step is best-effort and the script always exits 0 — a failure blocks every task (agent-kit docs/cloud/README.md).
set -uo pipefail
REPO="${REPO:-/workspace/anti-ai-slop-writing}"
warn() { echo "WARN: $*" >&2; }

if [ -d "$REPO/.git" ]; then
  (cd "$REPO" && bash tools/hooks-install.sh) || warn "git-хуки не установлены"
  # Setup PATH does not survive the agent shell; an nvm default alias does (docs/cloud/README.md).
  if [[ "$(node -v 2>/dev/null)" != v24.* ]]; then
    if [ -s "$REPO/.nvmrc" ] && [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then
      NODE_VERSION="$(cat "$REPO/.nvmrc")"
      # shellcheck disable=SC1091
      . "${NVM_DIR:-$HOME/.nvm}/nvm.sh"
      if nvm install "$NODE_VERSION" >/dev/null 2>&1 && nvm use "$NODE_VERSION" >/dev/null 2>&1; then
        nvm alias default "$NODE_VERSION" >/dev/null 2>&1 || warn "nvm alias default $NODE_VERSION не удался"
      else
        warn "nvm install/use $NODE_VERSION не удался — используется node образа"
      fi
    else
      warn "nvm или .nvmrc не найден — используется node образа"
    fi
  fi
  node -v || warn "node отсутствует или не запускается — verify будет красным"
  command -v node || warn "node не найден в PATH"
  # Warm dependencies while setup still has internet; the agent's verify then runs offline.
  (cd "$REPO" && npm ci --no-audit --no-fund >/dev/null 2>&1) || warn "npm ci не удался (warm-up lockfile)"
  (cd "$REPO" && bash tools/verify.sh --fast >/tmp/setup-verify.log 2>&1) || warn "verify при установке не зелёный — /tmp/setup-verify.log"
else
  warn "нет $REPO/.git — установка пропущена"
fi

exit 0

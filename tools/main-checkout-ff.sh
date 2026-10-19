#!/usr/bin/env bash
# tools/main-checkout-ff.sh — session-start hook: fast-forwards the shared main checkout to origin/main.
# Wired in .claude/settings.json and the global ~/.codex/hooks.json; spec — AGENTS.md (agent-kit core), step 8.
set -u
export LC_ALL=C.UTF-8 GIT_TERMINAL_PROMPT=0 GIT_HTTP_LOW_SPEED_LIMIT=1000 GIT_HTTP_LOW_SPEED_TIME=10

# Cloud sessions are fresh clones with no shared checkout to refresh.
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] && exit 0

json_str() { local s=${1//\\/\\\\}; s=${s//\"/\\\"}; printf '%s' "$s"; }
# Hook JSON: systemMessage reaches the owner, additionalContext reaches the model (audit 02.10, W-03).
emit() {
  local text owner=${2:-}
  text="main-checkout-ff: $(json_str "$1")"
  printf '{%s"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' \
    "${owner:+"\"systemMessage\":\"$text\","}" "$text"
}
note() { emit "$* — ff пропущен, скажи владельцу" owner; exit 0; }

# Resolve the checkout from the script's own path, not cwd: the Codex hook is global.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 0
common="$(git -C "$here" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || exit 0
[ "$(basename "$common")" = ".git" ] || exit 0
main="$(dirname "$common")"
g() { git -C "$main" "$@"; }
fresh() { g merge-base --is-ancestor origin/main HEAD 2>/dev/null; }
# A concurrent session may be mid-ff (index.lock, dirty-looking tree): give it a moment to land.
settle() { local _; for _ in 1 2 3 4; do fresh && return 0; sleep 0.3; done; return 1; }

g remote get-url origin >/dev/null 2>&1 || exit 0
branch="$(g symbolic-ref -q --short HEAD)" || note "основной checkout в detached HEAD"
[ "$branch" = "main" ] || note "основной checkout на ветке $branch, а не на main"

# Retry transient failures and concurrent ref locks once; AGENTS.md work cycle step 8.
FETCH_RETRY_DELAY_SECONDS=1.2
fetched=0
for attempt in 1 2; do
  g fetch -q origin main 2>/dev/null && { fetched=1; break; }
  remote="$(g ls-remote --heads origin main 2>/dev/null | cut -f1)"
  [ -n "$remote" ] && [ "$remote" = "$(g rev-parse -q --verify origin/main 2>/dev/null)" ] && { fetched=1; break; }
  [ "$attempt" = 2 ] || sleep "$FETCH_RETRY_DELAY_SECONDS"
done
[ "$fetched" = 1 ] || note "git fetch origin main не прошёл; актуальность checkout не подтверждена — проверь сеть и доступ к origin"

behind="$(g rev-list --count HEAD..origin/main 2>/dev/null)" || exit 0
[ "$behind" -gt 0 ] || exit 0
g merge-base --is-ancestor HEAD origin/main || note "основной main разошёлся с origin/main"
[ ! -e "$common/MERGE_HEAD" ] || note "в основном checkout незавершённое слияние"
dirty() { local out; out="$(g status --porcelain --untracked-files=no 2>/dev/null)" || return 0; [ -n "$out" ]; }
if dirty; then
  settle && exit 0
  dirty && note "основной checkout отстал на $behind и содержит правки"
fi

old="$(g rev-parse --short HEAD)"
if g merge --ff-only -q origin/main >/dev/null 2>&1; then
  emit "основной checkout подтянут $old → $(g rev-parse --short HEAD) (+$behind)"
  exit 0
fi
settle && exit 0
note "ff основного checkout не прошёл (мешают неотслеживаемые файлы?)"

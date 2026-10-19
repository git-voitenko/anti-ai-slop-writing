#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
printf '%s\n' '== kit-check'
bash "$ROOT/tools/kit-check.sh" "$ROOT" || exit $?
cd "$ROOT" || exit $?
printf '%s\n' '== npm run check'
npm run check

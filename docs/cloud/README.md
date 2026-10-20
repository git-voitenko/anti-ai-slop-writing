# Облако · anti-ai-slop-writing

Установочные скрипты и стартовые инструкции для облачных раннеров лежат рядом: `claude-setup.sh`, `codex-setup.sh`, `codex-start.txt`. Правила работы в облаке — `AGENTS.md`, раздел «Облако».

## Проверка Claude Cloud 2026-10-20 (Part of DMI-348)

Данные из постановки задачи (интерфейс, не измерялись): сессия запущена в Claude Cloud (claude.ai/code), ожидаемая версия Node — `v24.22.0`, ветку `claude/…` выдаёт среда.

Измерено в сессии:

| Что | Значение |
|---|---|
| Ветка | `claude/relaxed-mccarthy-iiq1ld` |
| База (`origin/main`, `git merge --ff-only` → «Already up to date») | `c8d2f132b0ce8a5b131cfa1c91822a554bd210be` |
| `ANTI_AI_SLOP_WRITING_BOOT_STATUS` | `OK` |
| `~/.anti-ai-slop-writing-bootstrap/status` | `OK` |
| `node -v` | `v24.22.0` |
| `npm -v` | `11.19.1` |
| ОС | Linux 6.18.44-fc-v139 |
| `bash tools/verify.sh --fast` (до правки) | код `0`: kit-check OK (agent-kit v1.0.1, профиль node, 17 managed-файлов), 60 тестов detector, 0 упавших; validate-skill ok; check:codex-plugin ok; self-scan 0 находок на 6 файлах |

Наблюдение: `docs/cloud/README.md` до этой проверки в репозитории не было; файл создан этим PR.

Правило: В начале каждой Claude Cloud-сессии выполните `source ~/.anti-ai-slop-writing-bootstrap/env.sh`, проверьте `ANTI_AI_SLOP_WRITING_BOOT_STATUS=OK` и `node -v` = `v24.22.0`; при BLOCKED или несовпадении версии остановите задачу и прочитайте `~/.anti-ai-slop-writing-bootstrap/status`.

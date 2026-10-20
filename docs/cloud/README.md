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

Наблюдение: `docs/cloud/README.md` до этой проверки в репозитории не было; файл создан этим PR. Bootstrap `~/.anti-ai-slop-writing-bootstrap/` создаёт репозиторный `docs/cloud/claude-setup.sh` (с этого PR): pinned Node 24.22.0 по sha256 с nodejs.org, вердикт в `status` и `env.sh`, затем `npm ci` только при OK; скрипт всегда завершается кодом 0, поэтому сессия обязана прочитать статус. Владелец вставляет этот файл в Setup script среды; в среде со старым setup `source` завершится ошибкой — это сигнал остановиться и сообщить владельцу. `codex-setup.sh` приведён к скрипту среды Codex (nvm вне subshell, `nvm alias default`).

Правило: В начале каждой Claude Cloud-сессии выполните `source ~/.anti-ai-slop-writing-bootstrap/env.sh`, проверьте `ANTI_AI_SLOP_WRITING_BOOT_STATUS=OK` и `node -v` = `v24.22.0`; при BLOCKED или несовпадении версии остановите задачу и прочитайте `~/.anti-ai-slop-writing-bootstrap/status`.

## Проверка Codex cloud 2026-10-20 (Part of DMI-348)

Данные интерфейса и постановки задачи (не измерения): Codex cloud, рабочий каталог `/workspace/anti-ai-slop-writing`, ожидаемый мажор Node — 24. Секреты для проверки не нужны.

Измерено в сессии:

| Что | Значение |
|---|---|
| Ветка | `codex/d11-cloud-check` |
| База (локальный `origin/main` и HEAD до правки) | `582432a9bd4b22c64bfbc31464c443dd384b4386` |
| Обновление базы | `git fetch origin` → код `128`: нет соединения с `proxy:8080`; повтор дал ту же ошибку. `git merge --ff-only origin/main` → `Already up to date` по локальной ссылке; свежесть относительно GitHub не подтверждена |
| `node -v` | `v24.19.0` (мажор 24) |
| `npm -v` | `11.9.0` |
| `nvm alias default 2>/dev/null || echo no-nvm-default` | `no-nvm-default`; наличие default alias не подтверждено |
| `bash tools/verify.sh --fast` до правки | код `1` после принудительной остановки зависшего дочернего CLI-процесса через ~71 с; kit-check OK (agent-kit v1.0.1, профиль node, 17 managed-файлов); отчёт Node: tests 7, pass 6, fail 1 (`test/cli.test.js`). Это результаты файлов тестов, успешный прогон 60 отдельных тестов не подтверждён |
| `bash tools/verify.sh --fast` после правки | kit-check OK; `npm test` не завершился, остановлен лимитом 45 с (`timeout --kill-after=5s 45s`), код оболочки `124`; дописанный после остановки отчёт Node: tests 7, pass 6, fail 0, cancelled 1 (`test/cli.test.js`: `Promise resolution is still pending but the event loop has already resolved`) |
| Setup script: `/tmp/setup-verify.log` | файл отсутствует; запуск и успешность setup-скрипта подтвердить нельзя |

Зависание наблюдалось на `detector/cli.js - --lang ru --format json` в тесте stdin. Минимальная отдельная проба `execFileSync` с передачей строки в stdin и `readFileSync(0, 'utf8')` также не завершилась за 10 с (ограничение времени, код `124`). Причина не установлена. Из-за ошибки тестов последующие этапы `npm run check` не выполнялись. Setup-скрипты и проверки не менялись.


### Продолжение в штатном режиме одобрения команды

Прежние результаты выше относятся к выполнению с `sandbox_permissions=use_default`. При диагностике локальный `socketpair` передал 3 байта через `write/read`, но `shutdown(SHUT_WR)` вернул `EPERM`, и EOF не пришёл за 1 с. `strace` установлен, однако запуск отклонён: `PTRACE_TRACEME: Operation not permitted`. Точный syscall внутри Node не прослежен.

Для продолжения использован поддерживаемый режим `sandbox_permissions=require_escalated` с отдельным штатным одобрением команды. Настройки proxy, CA, auth, sandbox/security policy и тесты не менялись. Локальная проба `execFileSync` со строкой stdin и дочерним `readFileSync(0, 'utf8')` прошла в этом режиме (код `0`, внешний лимит 8 с, лимит дочернего процесса 3 с). Это подтверждает зависимость прежнего сбоя от режима исполнения; исправление detector не потребовалось.

| Повторное измерение | Значение |
|---|---|
| `git fetch origin` и `git merge --ff-only origin/main` в одобренном режиме | fetch успешен; `Already up to date`; удалённая база подтверждена: `582432a9bd4b22c64bfbc31464c443dd384b4386`, tree `9be061e98633c637b09f612cd1cd2bc30744fffe` |
| Версии и nvm после fetch | Node `v24.19.0`, npm `11.9.0`, команда проверки alias снова вернула `no-nvm-default` |
| `bash tools/verify.sh --fast` в одобренном режиме до этого уточнения README | код `0`; 60 тестов, pass 60, fail 0, cancelled 0; kit-check OK, validate-skill OK, check:codex-plugin OK, self-scan 0 находок на 7 файлах; внешний лимит 120 с, тайм-аут не сработал |
| `bash tools/verify.sh --fast` в одобренном режиме после уточнения README | код `0`; 60 тестов, pass 60, fail 0, cancelled 0; kit-check OK, validate-skill OK, check:codex-plugin OK, self-scan 0 находок на 7 файлах; внешний лимит 120 с, тайм-аут не сработал |
| `/tmp/setup-verify.log` при продолжении | по-прежнему отсутствует; это не доказывает, что setup не запускался |

Исходный коммит `5645b4d15f34ee9abae90fd9fb06ebc61ce47939` сохранён в истории; уточнение оформляется отдельным коммитом. Mac review-gate и серверные проверки на финальном SHA остаются отдельными условиями посадки PR.

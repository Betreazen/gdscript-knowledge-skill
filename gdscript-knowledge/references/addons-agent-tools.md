# Инструменты для ИИ-агента: MCP, CLI-мосты, анализаторы, автоматизация, ИИ в игре

Справочник по аддонам и внешним инструментам, которые помогают агенту (Claude Code и подобным) работать с проектом Godot из терминала: видеть ошибки и запущенную игру, проверять сцены без юнит-тестов, рефакторить по семантике, а не grep-ом, собирать и выпускать билды. Актуально на 14 октября 2026 (Godot 4.7.2). Звёзды, версии и даты сверены с GitHub, Codeberg, npm и PyPI в этот день. Базовый тулчейн (Godot CLI, `--check-only`, GDScript Formatter, gdtoolkit, GUT, gdUnit4, setup-godot, gdvm, GodotEnv) описан в [toolchain.md](toolchain.md), игровые и контентные аддоны — в [addons.md](addons.md) и [addons-content.md](addons-content.md). Пометки: `[устарело]` — нет коммитов больше 12 месяцев или нет поддержки 4.4+, замена указана рядом; `[не проверено]` — факт из одного вторичного источника; `[ранняя стадия]` — меньше 30 звёзд или версия 0.0.x/alpha; `[платно]` — нужна покупка.

- [0. Что выбрать: короткий маршрут](#0-что-выбрать-короткий-маршрут)
- [1. Встроенные возможности движка для агента](#1-встроенные-возможности-движка-для-агента)
- [2. Документация API без галлюцинаций](#2-документация-api-без-галлюцинаций)
- [3. MCP-серверы](#3-mcp-серверы)
- [4. CLI-мосты к редактору и игре без MCP](#4-cli-мосты-к-редактору-и-игре-без-mcp)
- [5. Безопасность MCP и мостов](#5-безопасность-mcp-и-мостов)
- [6. Семантика кода: LSP и анализаторы](#6-семантика-кода-lsp-и-анализаторы)
- [7. Валидация проекта, линтеры, покрытие, мутации](#7-валидация-проекта-линтеры-покрытие-мутации)
- [8. Автоматизация игры для агента без зрения](#8-автоматизация-игры-для-агента-без-зрения)
- [9. Чтение и правка .tscn/.tres скриптом](#9-чтение-и-правка-tscntres-скриптом)
- [10. Сборка, релиз, анализ PCK](#10-сборка-релиз-анализ-pck)
- [11. Менеджеры аддонов и Asset Store](#11-менеджеры-аддонов-и-asset-store)
- [12. Другие языки и визуальное программирование: влияние на агента](#12-другие-языки-и-визуальное-программирование-влияние-на-агента)
- [13. ИИ-ассистенты внутри редактора](#13-ии-ассистенты-внутри-редактора)
- [14. ИИ внутри игры: LLM, речь, обучение](#14-ии-внутри-игры-llm-речь-обучение)
- [15. Ресурсы](#15-ресурсы)

## 0. Что выбрать: короткий маршрут

**Ключевые выводы**
- Начинайте без MCP. Цикл «правка → `godot --headless --import` → `scripts/check_scripts.sh` → тесты GUT/gdUnit4 с JUnit XML → `--write-movie` для кадров (без `--headless`)» детерминирован, не открывает сетевых портов и не требует зависимостей. MCP нужен для живого редактора и запущенной игры.
- Документацию API берите из Context7 (`/godotengine/godot-docs`, ветка 4.7) и из `godot --doctool` локальной сборки. Официального `llms.txt` у docs.godotengine.org нет (404 на всех путях, проверено 14.10.2026).
- Если нужен MCP: живой редактор и игра — godot-ai (самый популярный из активных, только 4.7+). Без аддона в проекте — godot-mcp-runtime. Агенту без зрения — satelliteoflove/godot-mcp: заморозка времени, шаг до условия и состояние сущностей в JSON вместо скриншота.
- Дешёвые гейты перед коммитом, которых нет в базовом тулчейне: Godot Doctor (пустые `@export`-ссылки в сценах), gdoctor (битые `uid://`, connections и input actions без запуска Godot), graydwarf GDScript Linter (сложность и god-классы, exit 0/1/2).
- Перед установкой любого аддона прогоните [scripts/addon_smoke.sh](../scripts/addon_smoke.sh): он ставит аддон в чистый проект, включает плагин в headless-редакторе и прогоняет `--check-only` по всем скриптам.

| Задача агента | Первый выбор | Альтернатива |
|---|---|---|
| Ошибки парсинга и типов | `godot --headless --check-only` ([toolchain.md](toolchain.md#2-проверка-скриптов-и-предупреждения-gdscript)) | godot-lsp-cli `diagnostics --json` |
| Актуальный API движка | Context7 `/godotengine/godot-docs`; `godot --doctool` | `godot_docs` в satelliteoflove/godot-mcp |
| Запуск игры и чтение ошибок | `godot --headless --path . --log-file run.log --quit-after N` | godot-ai `project_run` + `logs_read`; Coding-Solo `get_debug_output` |
| Состояние живой игры | satelliteoflove `godot_runtime_state` (JSON) | godot-ai `game_manage`; swallowtail `--game` |
| Кадры и скриншоты | `--write-movie out.png --fixed-fps 60 --quit-after N` без `--headless` (раздел 1) | godot-mcp-runtime, godot-ai `editor_screenshot` |
| Симуляция ввода в тестах | gdUnit4 SceneRunner, GUT InputSender | GodotE2E (pytest), PlayGodot (свой форк движка) |
| Проводка сцен | Godot Doctor | gdoctor |
| Рефакторинг по ссылкам | godot-lsp-cli `references`/`rename --json` | gdscript-analyzer (без редактора) |
| Правка сцены скриптом | Правка текста `.tscn` + `--import` + `--check-only` | godot_parser (Python, из git) |

## 1. Встроенные возможности движка для агента

**Ключевые выводы**
- В `--headless` работает dummy-рендерер, картинки в нём нет. Movie Maker с `--headless` на Godot 4.7.2 под Windows падает с segfault (код 139, 3 запуска из 3) и успевает записать только `.wav`; без `--headless` та же команда пишет корректные PNG-кадры (проверено на 4.7.2: пиксель сцены совпал). Для кадров запускайте без `--headless`; на Linux без дисплея — под `xvfb-run` `[не проверено]`.
- Текстовые `.tscn`/`.tres` (format=3) и `project.godot` агент читает и правит напрямую. Бинарные `.scn`/`.res` не используйте для того, что агент должен менять. Файлы `.uid` (4.4+) переносите вместе со скриптами.
- Встроенный LSP и DAP запускаются без окна: `godot --headless --editor --path . --lsp-port 6005 --dap-port 6006`. Это основа для godot-lsp-cli, minimal-godot-mcp и плагинов редакторов.

| Средство | Что даёт агенту |
|---|---|
| `--check-only --script res://x.gd` | Парсинг и анализ типов одного скрипта без запуска |
| `--import` | Импорт ресурсов и кеш `class_name`. Обязателен на свежем клоне и после внешних правок `.tscn`/`.tres` |
| `--doctool <dir>` / `--gdscript-docs res://` | XML-справочник API ровно вашей сборки и документация из `##`-комментариев проекта |
| `--dump-extension-api-with-docs` | `extension_api.json`: все классы, методы, сигналы с описаниями. Удобно искать grep-ом и jq |
| `--write-movie out.png --fixed-fps 60 --quit-after N` | Детерминированная последовательность PNG-кадров без MCP. Только без `--headless` (см. выше) |
| `--fixed-fps`, `--time-scale`, `--disable-render-loop`, `--quit-after` | Воспроизводимый прогон симуляции |
| `--log-file <file>` | Лог прогона в файл, который агент читает после выхода |
| `--remote-debug tcp://127.0.0.1:6007` | Протокол удалённого отладчика. На нём построены satelliteoflove/godot-mcp и PlayGodot |
| `Logger` + `OS.add_logger()` (4.5+) | Перехват всех ошибок и `print` своим классом: например, писать JSON-строки для агента |

## 2. Документация API без галлюцинаций

**Ключевые выводы**
- Модель помнит API разных версий вперемешку, особенно Godot 3 (`yield`, `KinematicBody`, `TileMap`). Перед советом по незнакомому методу сверяйтесь с документацией версии проекта.
- Context7 даёт свежие сниппеты по веткам 4.5 и 4.7. `--doctool` и `--dump-extension-api` дают справочник установленного бинарника и не зависят от сети.

| Ресурс | Статус на 14.10.2026 | Зачем |
|---|---|---|
| Context7 `/godotengine/godot-docs` | Обновлён 14.10.2026, ветки 4.5 и 4.7, около 44 тыс. сниппетов | Документация через MCP `context7` или CLI. Есть также `/godotengine/godot` и `/godot-rust/gdext` |
| [godot-docs (rst)](https://github.com/godotengine/godot-docs) | Живой, около 5,8 тыс. ★ | `git clone --depth 1 -b 4.7` даёт grep-абельные `.rst`, включая `classes/` |
| [Офлайн-документация](https://docs.godotengine.org/en/stable/index.html) | HTML-zip и ePub, пересобираются еженедельно | Локальный поиск без сети |
| `llms.txt` на docs.godotengine.org | Нет | Используйте источники выше |
| [Randroids-Dojo/skills](https://github.com/Randroids-Dojo/skills), [alexmeckes/godot-claude-skills](https://github.com/alexmeckes/godot-claude-skills) | Около 45 ★, 2026 | Чужие Agent Skills по Godot: источник идей, не замена этому скиллу |

## 3. MCP-серверы

**Ключевые выводы**
- Официального MCP-сервера от Godot Foundation нет. Архитектуры три: (A) обёртка над CLI — без аддона, без живого редактора; (B) внешний сервер + аддон в редакторе по WebSocket/TCP — живой редактор и, через autoload, игра; (C) аддон сам является MCP-сервером по HTTP.
- Для агента ценнее всего: чтение ошибок и логов, запуск и остановка игры, JSON-дамп живого дерева, ввод, детерминированный шаг времени. Скриншоты — по необходимости, они дороги по токенам.
- MCP-проекты моложе года и выпускают релизы еженедельно. Фиксируйте версию: `npx -y pkg@x.y.z`, а не `npx -y pkg`.
- Длинный список из 150+ инструментов съедает контекст. Берите серверы с профилями (`--lite`, `compact`, наборы инструментов) или CLI с `--help`.

| Сервер | Версия, дата; ★ | Godot | Тип | Что умеет | Подключение и оговорки |
|---|---|---|---|---|---|
| [hi-godot/godot-ai](https://github.com/hi-godot/godot-ai) | v4.3.0, 3.10.2026; ~3 тыс. | v4 — только 4.7+ (v3 — 4.3+) | B: аддон + Python-сервер (uvx) | 46 инструментов: сцены, узлы, скрипты с валидацией при записи, сигналы, UI, анимация, тайлмапы; `project_run`, `logs_read` с курсором, скриншот игры, `test_run`, ввод и `next_frame` в игре, `batch_execute` с откатом | Кнопка Configure в доке сама пишет конфиг Claude Code. Нужен uv. Телеметрия включена по умолчанию: `GODOT_AI_DISABLE_TELEMETRY=true` |
| [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp) | npm 0.1.1, 2.2026; ~6,1 тыс. | 4.x (UID — 4.4+) | A: Node | Запуск редактора и проекта, `get_debug_output`, создание сцен и узлов, UID | `claude mcp add godot -e GODOT_PATH=<godot> -- npx -y @coding-solo/godot-mcp`. Лидер по звёздам, но последний коммит в апреле 2026; живой игры, ввода и скриншотов нет |
| [satelliteoflove/godot-mcp](https://github.com/satelliteoflove/godot-mcp) | npm 4.1.11, 27.8.2026; ~175 | 4.5+ (нужен `Logger`) | B: аддон + Node, к игре через протокол отладчика | `godot_game_time`: заморозка, шаг на N мс, шаг до условия с вводом; `godot_runtime_state` — состояние в JSON; профайлер; `godot_docs` под версию редактора | `npx @satelliteoflove/godot-mcp --install-addon <проект>`, затем `claude mcp add godot -- npx -y @satelliteoflove/godot-mcp`. Инструменты разделены на чтение и запись, есть `--read-only`, только 127.0.0.1. Лучший выбор для агента без зрения |
| [Erodenn/godot-mcp-runtime](https://github.com/Erodenn/godot-mcp-runtime) | v3.8.1, 25.9.2026; ~90 | 4.x | A + временный autoload | Headless-правка сцен, валидация GDScript; в игре — скриншоты, пакетный ввод с отчётом «что изменилось», поиск UI, `run_script`, профилирование | `claude mcp add godot -- npx -y godot-mcp-runtime`. В проект ничего не коммитится. Security-гейт для `run_script`: не позволяйте агенту ставить `GODOT_MCP_DISABLE_SECURITY` |
| [yurineko73/Godot-MCP-Native](https://github.com/yurineko73/Godot-MCP-Native) | v1.0.8, 26.7.2026; ~850 | 4.x (рекомендуется 4.5+) | C: чистый GDScript | Около 150 инструментов: скрипты, индекс символов, скриншоты, инжекция ввода, сравнение скриншотов | HTTP `:9080/mcp` или `godot --editor --path P -- --mcp-server --mcp-transport=stdio`. Ни Node, ни Python не нужны. Аутентификация по умолчанию выключена — включите `auth_enabled` |
| [NPGameDev/godot-mcp-toolkit](https://github.com/NPGameDev/godot-mcp-toolkit) | v1.0.4, 14.10.2026; ~70 | 4.2–4.7, CI на трёх ОС | B: аддон + npx (Node 22+) | Большинство инструментов работает под `godot --headless --editor`; GDScript и C# | Токен на сессию, `GODOT_MCP_READ_ONLY=1`, только localhost. Есть в Asset Store. Аккуратная инженерия, но мало звёзд |
| [tugcantopaloglu/godot-mcp](https://github.com/tugcantopaloglu/godot-mcp) | v3.1.0, 13.7.2026; ~485 | 4.4+ (проверен на 4.7) | A + TCP-autoload :9090 | Форк Coding-Solo: около 157 инструментов, `game_eval`, скриншоты, ввод, геймпад | Сборка из git (`npm run build`). Autoload открывает порт — не оставляйте его в релизе |
| [wgt19861219/godot-mcp-enhanced](https://github.com/wgt19861219/godot-mcp-enhanced) | v0.34.1, 7.10.2026; ~100 | 4.5–4.7 | A + редактор + мост в игру | Детерминированный плейтест (freeze, step_until, seed RNG, `fixed_delta`), `run_and_verify`, QA-сценарии в markdown, GIF | `claude mcp add -s user godot -- npx -y godot-mcp-enhanced`. README на китайском. `execute_bpy` — полный доступ к хосту через Blender |
| [tomyud1/godot-mcp](https://github.com/tomyud1/godot-mcp) | v0.6.0, 24.8.2026; ~435 | 4.x | B: аддон + Node, WS :6505 | Сцены, узлы, undo/redo, браузерный граф скриптов | `claude mcp add godot -- npx -y godot-mcp-server`. Визуализатор полезен человеку, агенту мало |
| [youichi-uda/godot-mcp-pro](https://github.com/youichi-uda/godot-mcp-pro) | v1.17.1, 24.9.2026; ~625 | 4.x (часть инструментов 4.6+) | B | 187 инструментов: запись и воспроизведение ввода, сравнение скриншотов, режимы `--lite`/`--minimal`, CLI с прогрессивным `--help` | `[платно]`: на GitHub только аддон, сервер продаётся отдельно |
| [3ddelano/gdai-mcp-plugin-godot](https://github.com/3ddelano/gdai-mcp-plugin-godot) | 9.2026; ~100 | 4.2+ | B: аддон + Python (`uv run`) | Сцены, скрипты, ошибки отладчика, скриншоты, ввод | `[платно]`, проприетарная лицензия: не коммитьте в публичный репозиторий. HTTP-режим без аутентификации |
| [IvanMurzak/Godot-MCP](https://github.com/IvanMurzak/Godot-MCP) | v0.26.1, 13.10.2026; ~285 | 4.3+, только .NET-сборка | B: C#-аддон | Скриншоты, рефлексия C#, ошибки рантайма | `npm i -g godot-cli`, затем `godot-cli setup-mcp claude-code <проект>`. Не работает на стандартной сборке |
| [hybridindie/godot-mcp](https://github.com/hybridindie/godot-mcp) (`godot-editor-mcp`) | PyPI 2026.10.12; ~35 | 4.4+ | B: FastMCP + аддон | 194 инструмента в 29 наборах; по умолчанию включён только `inspection` | `uvx godot-editor-mcp`. Молодой проект |
| [beckettlab/beckett-godot-mcp](https://github.com/beckettlab/beckett-godot-mcp) | v1.16.0, 6.10.2026; ~45 | 4.2+ (проверен на 4.7) | C | `render_probe` объясняет данными, почему 3D-узел не виден; `ui_snapshot`, удалённое дерево | Ввод и asserts только в платной версии |
| [ryanmazzolini/minimal-godot-mcp](https://github.com/ryanmazzolini/minimal-godot-mcp) | npm 0.1.6; ~45 | 4.x | мост LSP/DAP | Диагностика GDScript и вывод консоли через встроенный LSP | Без аддона, но нужен открытый редактор. Хорошо дополняет satelliteoflove |
| [DaxianLee/godot-mcp](https://github.com/DaxianLee/godot-mcp) | без релизов; ~550 | 4.x | C | — | Некоммерческая лицензия: не подходит коммерческим играм |
| [ee0pdt/Godot-MCP](https://github.com/ee0pdt/Godot-MCP), [bradypp/godot-mcp](https://github.com/bradypp/godot-mcp), [better-godot-mcp](https://github.com/n24q02m/better-godot-mcp), [godot-mcp-docs](https://github.com/Nihilantropy/godot-mcp-docs) | — | — | — | — | `[устарело]` или архив. Замена: godot-ai, satelliteoflove, godot-mcp-runtime, Context7 |

## 4. CLI-мосты к редактору и игре без MCP

**Ключевые выводы**
- CLI с JSON-выводом и кодами выхода удобнее MCP в скриптах, хуках и CI: команды раскрываются через `--help` и не держат список инструментов в контексте.

| Инструмент | Версия, дата; ★ | Godot | Что даёт | Оговорки |
|---|---|---|---|---|
| [regiellis/godot-mcp-go](https://github.com/regiellis/godot-mcp-go) (swallowtail) | v1.2.0, 9.10.2026; ~70 | цель 4.7 | Go-CLI + аддон: JSON в stdout, коды 0/1/2, `doctor`; `--game` управляет отдельной debug-сборкой без редактора; `serve` — MCP по stdio | Молодой проект |
| [aigengame/godot-agent](https://github.com/aigengame/godot-agent) (gda) | v0.24.0, 11.10.2026; ~50 | 4.4+ headless, 4.6+ live | `uv tool install gda`. Headless: валидация скриптов и сцен, пробная загрузка сцены, экспорт. Live: демон, дерево, ввод, кадры. Есть Agent Skill и MCP | Python 3.13+ |
| [Dluck-Games/godot-debug-bridge](https://github.com/Dluck-Games/godot-debug-bridge) (GDBG) | v0.1.2, 14.9.2026; 1 | 4.3+, проверен на 4.7.1 | Go-CLI + аддон: запуск и остановка, консоль, скриншоты, ввод через IPC | `[ранняя стадия]`, тестировался в основном на macOS |
| CLI-режим godot-mcp-pro | см. раздел 3 | — | `node build/cli.js <group> <cmd> --help` | `[платно]` |

## 5. Безопасность MCP и мостов

- Инструменты вида `execute_*`, `game_eval`, `run_script`, `godot_exec`, `execute_bpy` — это выполнение произвольного кода от имени пользователя: GDScript имеет `OS.execute` и полный `FileAccess`. Ставьте их в `ask` или `deny` в `.claude/settings.json`, read-инструменты можно разрешить.
- Проверяйте, что порты слушают только 127.0.0.1 и включён токен. Godot-MCP-Native и GDAI в HTTP-режиме по умолчанию без аутентификации.
- Autoload-мосты в игре (TCP 9090, 7777, 6570 и т.п.) не должны попадать в релиз. Исключите их фильтром экспорта или feature tag `debug` и проверьте содержимое PCK (раздел 10).
- Фиксируйте версии npm/uvx-пакетов: сервер исполняется с вашими правами.
- Телеметрия: godot-ai — opt-out. Опциональные «vision»-функции некоторых серверов отправляют скриншоты внешним API (godot-mcp-enhanced → api.groq.com, по умолчанию выключено).
- Лицензии: DaxianLee — некоммерческая; GDAI и godot-mcp-pro — платные и закрытые, не коммитьте их в открытые репозитории.

## 6. Семантика кода: LSP и анализаторы

**Ключевые выводы**
- grep не отличает метод `update` одного класса от `update` другого. Для переименования и поиска ссылок используйте LSP редактора.
- Все инструменты ниже, кроме официального плагина VS Code, моложе года и с малым числом звёзд. Используйте их как ускорители, а итог проверяйте `--check-only` и тестами.

| Инструмент | Версия, дата; ★ | Что даёт | Оговорки |
|---|---|---|---|
| [godot-vscode-plugin](https://github.com/godotengine/godot-vscode-plugin) | 2.7.1, 17.6.2026; ~2,1 тыс. | Официальный LSP-клиент и DAP; `godotTools.lsp.headless` сам поднимает безоконный редактор | Нужен, когда агент работает внутри VS Code |
| [SomniGameStudios/godot-lsp-cli](https://github.com/SomniGameStudios/godot-lsp-cli) | v0.2.1, 20.7.2026; ~4 | symbols, references, definition, hover, diagnostics, rename (возвращает правки, файлы не пишет); `--json` у всех команд | `[ранняя стадия]`. Нужен LSP на 6005: открытый редактор или `godot --headless --editor --lsp-port 6005` |
| [reactive-ui-toolkit/gdscript-analyzer](https://github.com/reactive-ui-toolkit/gdscript-analyzer) | v0.6.1, 5.7.2026; ~4 | Семантический анализ без редактора: диагностика, типы, ссылки, переименование; читает `.tscn` и типизирует `$Node` и `%Unique` | `[ранняя стадия]`, библиотека (Rust, npm, WASM), а не готовый линтер |
| [kurushimee/gdls](https://github.com/kurushimee/gdls) | v3.1.0, 13.10.2026; ~5 | Отдельный LSP на Rust без движка | `[ранняя стадия]`, зрелость не подтверждена |
| [Sods2/claude-code-gdscript-lsp](https://github.com/Sods2/claude-code-gdscript-lsp) | v1.0.0, 3.2026; ~7 | Подключает LSP Godot к LSP-инструменту Claude Code | `[ранняя стадия]` |
| [PrestonKnopp/tree-sitter-gdscript](https://github.com/PrestonKnopp/tree-sitter-gdscript) | v6.1.0, 11.2025; ~120 | Грамматика tree-sitter: основа GDScript Formatter и gdeye; годится для своих структурных запросов | — |
| [Mathijs-Bakker/godotdev.nvim](https://github.com/Mathijs-Bakker/godotdev.nvim) | 0.8.4, 31.8.2026; ~125 | Neovim: LSP, DAP, GDShader, C# | Для терминальных редакторов |

## 7. Валидация проекта, линтеры, покрытие, мутации

**Ключевые выводы**
- Юнит-тесты не видят сломанную проводку сцены: пустой `@export`, битый `uid://`, сигнал на удалённый метод, input action без записи в InputMap. Эти ошибки ловят Godot Doctor (запускает редактор) и gdoctor (без Godot).
- Покрытие кода GDScript — белое пятно экосистемы: живой инструмент один, и он малоизвестен. Для C# зрелый путь есть: GoDotTest + coverlet.
- gdtoolkit 4.5.0 не обновлялся год, разбор синтаксиса 4.6–4.7 не гарантирован. Активные замены для линта — GDScript Formatter (`lint`), gdeye, graydwarf GDScript Linter.
- Godot Doctor 2.2.0, graydwarf GDScript Linter 3.3.0, GUT 9.7.1 и gdUnit4 6.2.2 встают в чистый проект на 4.7.2: плагины включаются, все скрипты компилируются (проверено `scripts/addon_smoke.sh`).

| Инструмент | Версия, дата; ★ | Godot | Что проверяет | Команда, вывод | Оговорки |
|---|---|---|---|---|---|
| [codevogel/godot_doctor](https://github.com/codevogel/godot_doctor) | 2.2.0, 23.7.2026; ~170 | 4.x | Пустые `@export`-ссылки и строки, свои правила для узлов и ресурсов; наборы проверок в `.tres` | `godot --headless --editor --quit-after 100 -- --run-godot-doctor`; exit ≠ 0, XML-отчёт (`enable_xml_report`) | Сначала `godot --headless --editor --quit` для импорта. Headless-режим автор называет хакерским (таймауты ожидания редактора) |
| [godot-project-doctor](https://pypi.org/project/godot-project-doctor/) (gdoctor) | PyPI 0.8.3, 1.6.2026; репозиторий `chamcat97/godot-project-doctor` на GitHub в октябре 2026 недоступен (404) | 4.x | Битые `ext_resource` и `uid://`, циклы зависимостей, нет main scene или autoload, неопределённые input actions, сломанные connections, неиспользуемые скрипты и ассеты, огромные текстуры | `gdoctor scan . --format json\|sarif\|markdown --fail-on warning` | `[ранняя стадия]`, Python 3.11+, Godot не нужен |
| [graydwarf/godot-gdscript-linter](https://github.com/graydwarf/godot-gdscript-linter) | v3.3.0, 14.7.2026; ~65 | 4.0+ | Длина файлов и функций, цикломатическая сложность, вложенность, god-классы, magic numbers, отсутствующие типы | `godot --headless --script res://addons/gdscript-linter/analyzer/analyze-cli.gd -- --json`; exit 0/1/2 | Аддон; экспорт отчёта в Markdown |
| [TkTech/gdeye](https://github.com/TkTech/gdeye) | crate 0.1.3; ~9 | 4.x | Линт с автофиксом, правила производительности (`perf/process-allocation`), форматтер, LSP | `gdeye check --fix .`; конфиг `gdeye.toml` | `[ранняя стадия]` |
| [GDQuest/GDScript-formatter](https://github.com/GDQuest/GDScript-formatter) | 0.27.0, 25.9.2026; ~475 | 4.x | Форматирование и линт по официальному style guide | `gdscript-formatter --check`, `gdscript-formatter lint` | Подробно в [toolchain.md](toolchain.md#3-форматирование-и-линтинг). В Asset Library лежит 0.16.1 — берите с GitHub |
| [jamie-pate/godot-code-coverage](https://github.com/jamie-pate/godot-code-coverage) | без релизов, 18.12.2025; ~27 | `main` с коммитом под 4.4; 4.5–4.7 `[не проверено]` | Построчное покрытие GDScript во время тестов (хуки GUT) | JSON, слияние, `--target 90` с exit ≠ 0 при недоборе | `[ранняя стадия]`: README устарел, lcov нет. Проверьте на своей версии |
| [kphutt/gdmutant](https://github.com/kphutt/gdmutant) | PyPI 0.1.4, 4.10.2026; ~4 | 4.3+, GUT 9 / gdUnit4 6 | Мутационное тестирование: меняет `>`↔`>=`, `and`↔`or`, константы, удаляет операторы и перезапускает тесты | `gdmutant run src/x.gd --project . --runner gut --tests res://test/unit --json` | `[ранняя стадия]`, медленно: полный прогон на каждую мутацию |
| [chickensoft-games/GoDotTest](https://github.com/chickensoft-games/GoDotTest) | 2.0.48, 14.10.2026; ~155 | 4.x .NET | Тест-раннер C# внутри игры, покрытие через coverlet | `coverlet ... --targetargs "--run-tests --coverage --quit-on-finish"` | Только C#; шаблон — [GodotGame](https://github.com/chickensoft-games/GodotGame) |

## 8. Автоматизация игры для агента без зрения

**Ключевые выводы**
- Агент не видит игру. Дешевле и надёжнее проверять состояние, а не картинку: заморозить время, сделать N шагов или шагать до условия, прочитать позиции, флаги и счётчики, и только при подозрении снять кадр.
- Встроенные средства — SceneRunner gdUnit4 (`simulate_frames`, ввод, ожидание сигналов) и InputSender GUT. Они работают headless и дают JUnit XML; см. [toolchain.md](toolchain.md#5-тестирование-gut-и-gdunit4).
- То, что нельзя проверить кодом (ощущение управления, вёрстка на разных разрешениях, качество картинки), передавайте человеку списком.

| Инструмент | Версия, дата; ★ | Godot | Что даёт | Оговорки |
|---|---|---|---|---|
| [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) SceneRunner | 6.2.2, 7.10.2026; ~1,3 тыс. | v6.2 — 4.5–4.7.1; `master` (7.0) — 4.7–4.8 | Клавиши, мышь, actions, `simulate_frames`, ожидание сигналов | Организация переехала в `godot-gdunit-labs` |
| [GUT](https://github.com/bitwes/Gut) InputSender | 9.7.1 (тег), 2026; ~2,8 тыс. | 9.7.1 — 4.7.x | Запись и отправка ввода в тестах | Для 4.7 нужен тег v9.7.1 или ветка `godot_4_7`, а не `main` (там 4.6) |
| [RandallLiuXin/godot-e2e](https://github.com/RandallLiuXin/godot-e2e) (GodotE2E) | v1.3.0, 9.7.2026; ~20 | 4.x `[не проверено]` | pytest + аддон: клавиатура, мышь, actions, синхронизация кадров, скриншот при падении | `[ранняя стадия]`, зато без форка движка |
| [Randroids-Dojo/PlayGodot](https://github.com/Randroids-Dojo/PlayGodot) | PyPI 0.5.1, 25.1.2026; ~40 | свой форк движка | «Playwright для игр» через протокол отладчика: клики, узлы, свойства, скриншоты | Нужен неофициальный бинарь Godot; 7 месяцев без коммитов |
| [chickensoft-games/GodotTestDriver](https://github.com/chickensoft-games/GodotTestDriver) | 3.1.84, 14.10.2026; ~60 | 4.x .NET | Драйверы кнопок, полей, actions, фикстуры | Только C#, в паре с GoDotTest |
| [graydwarf/godot-ui-automation](https://github.com/graydwarf/godot-ui-automation) | v1.0.0, 12.1.2026; ~20 | 4.5 | Запись и воспроизведение UI-сценариев, сравнение скриншотов с допуском | `[ранняя стадия]`; по словам автора, для наборов меньше 100 тестов |
| [bitwes/GodotInputRecorder](https://github.com/bitwes/GodotInputRecorder) | без релизов, 4.2026; ~7 | 4.x | Запись и воспроизведение ввода для регрессионных реплеев | `[ранняя стадия]` |
| Playwright + Web-экспорт | подход | 4.x Web | Экспорт `--export-release "Web"`, локальный сервер, Playwright кликает по canvas и читает `console`; состояние отдаётся через `JavaScriptBridge` | Готового инструмента нет `[не проверено]`. Потоковым сборкам нужны заголовки COOP/COEP |
| [limbonaut/limbo_console](https://github.com/limbonaut/limbo_console) | v0.8.0, 20.6.2026; ~430 | 4.3+ | Внутриигровая консоль: команды регистрируются кодом, сценарии `.lcs` — текстовые, агент может писать их для воспроизведения бага | Версия 0.x, API может меняться. Подробнее в [addons-content.md](addons-content.md#2-отладка-в-игре-логи-краш-репорты) |

## 9. Чтение и правка .tscn/.tres скриптом

**Ключевые выводы**
- Простые правки агент делает текстом прямо в `.tscn`: формат стабилен и описан в [документации](https://docs.godotengine.org/en/stable/engine_details/file_formats/tscn.html). После любых внешних правок выполняйте `godot --headless --import`, затем `--check-only` и загрузку сцены в тесте.
- Массовые операции (переименовать узел в 200 сценах, собрать отчёт по всем `@export`) удобнее парсером. Надёжнее всего — скрипт на GDScript под `godot --headless -s`, который грузит сцену как `PackedScene` и сохраняет через `ResourceSaver`: движок сам сохранит формат и UID.

| Инструмент | Версия, дата; ★ | Язык | Что даёт | Оговорки |
|---|---|---|---|---|
| [stevearc/godot_parser](https://github.com/stevearc/godot_parser) | PyPI 0.1.7 (2023), коммит 23.2.2026; ~85 | Python | Чтение и запись `.tscn`/`.tres`, высокоуровневый `GDScene`, наследуемые сцены | Ставьте из git: на PyPI версия 2023 года. Поддержка format=3 неполная `[не проверено]` |
| [gdscript-scene](https://docs.rs/gdscript-scene) | 0.6.1, 5.7.2026 | Rust | Устойчивый парсер `.tscn`/`.tres`, не падает на мусоре; WASM | `[ранняя стадия]`, вложенные сцены не раскрывает |
| [MihaMarkic/godot-tscn-parser](https://github.com/MihaMarkic/godot-tscn-parser) | 1.0.0-beta.5; ~10 | C# | Парсер `.tscn` и `project.godot` для source generators | `[ранняя стадия]` |
| gdparse из [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) | 4.5.0 | Python | Дерево разбора GDScript | Грамматика до 4.5 |

## 10. Сборка, релиз, анализ PCK

**Ключевые выводы**
- Шаблоны CI (setup-godot, gdUnit4-action) — в [toolchain.md](toolchain.md#11-экспорт-и-ci), правила экспорта — в [project-export.md](project-export.md). Ниже — то, что их дополняет.
- Проверяйте, что попало в PCK: отладочные аддоны, MCP-мосты, исходники ассетов. GodotPckTool читает формат PCK 4.7.

| Инструмент | Версия, дата; ★ | Что даёт | Команды и оговорки |
|---|---|---|---|
| [abarichello/godot-ci](https://github.com/abarichello/godot-ci) | 4.7.2-stable, 18.8.2026; ~1,1 тыс. | Docker-образ с Godot, шаблонами экспорта и butler | `image: barichello/godot-ci:4.7.2`; есть варианты `mono-` |
| [firebelley/godot-export](https://github.com/firebelley/godot-export) | v8.0.0, 28.5.2026; ~650 | Action: экспорт пресетов, архивы, иконка Windows через rcedit | Примеры ссылаются на 4.0 — подставьте URL 4.7.2 |
| [itchio/butler](https://github.com/itchio/butler) | v15.32.0, 6.10.2026; ~990 | Дельта-загрузка на itch.io, `--json` | `butler push build/web user/game:html5 --userversion 1.2.3`; ключ в `BUTLER_API_KEY` |
| [game-ci/steam-deploy](https://github.com/game-ci/steam-deploy) | v3.2.1, 18.8.2026; ~345 | Загрузка depot'ов в Steam | Нужен `config.vdf` билдера; Steam Guard истекает |
| [hhyyrylainen/GodotPckTool](https://github.com/hhyyrylainen/GodotPckTool) | v2.3, 13.7.2026; ~580 | list, extract, add для PCK, включая формат 4.7 | `godotpcktool game.pck -a list`. Шифрованные PCK не читает |
| [GDRETools/gdsdecomp](https://github.com/GDRETools/gdsdecomp) | v2.7.4, 11.10.2026; ~4,3 тыс. | Восстановление проекта из PCK/EXE, декомпиляция байткода, конвертация `.res` → `.tres` | `gdre_tools --headless --list-files=game.pck`. Только для своих проектов; наглядно показывает, что без шифрования код восстанавливается |
| [KoBeWi/Godot-Auto-Export-Version](https://github.com/KoBeWi/Godot-Auto-Export-Version) | 2026; ~77 | Подставляет хеш коммита и версию при экспорте, в том числе headless | `EditorExportPlugin` |

## 11. Менеджеры аддонов и Asset Store

**Ключевые выводы**
- Главный сдвиг 2026 года: Godot Asset Store (store.godotengine.org) встроен в редактор 4.7 и заменяет Asset Library, которая объявлена устаревшей и станет только для чтения. Ассеты не переносились автоматически: часть аддонов выходит только в Store (godot-sqlite с v4.9), часть осталась только в старой Library.
- Lock-файла у Godot нет. Воспроизводимый состав `addons/` дают GodotEnv (`addons.json`), gd-plug (`plug.gd`), git submodule или коммит `addons/` целиком; подробности в [toolchain.md](toolchain.md#8-аддоны-и-зависимости).
- Релизы на GitHub часто отстают от `main` (netfox: релиз 1.35.3, в `main` 1.49.4). Сверяйте версию в `plugin.cfg` и в Store, а не только вкладку Releases.

| Инструмент | Версия, дата | Статус |
|---|---|---|
| [Godot Asset Store](https://store.godotengine.org/) | встроен в 4.7 | Основной каталог, есть версии и changelog; API `store.godotengine.org/api/v1` (документация `[не проверено]`) |
| [GodotEnv](https://github.com/chickensoft-games/GodotEnv) | v2.17.0, 13.7.2026 | Рекомендуется; нужен .NET SDK |
| [gd-plug](https://github.com/imjp94/gd-plug) | 0.2.6 (2024), коммиты 2026 | Рекомендуется, без .NET |
| [Abyss-PlayerEG/godot-gdpm](https://github.com/Abyss-PlayerEG/godot-gdpm) | PyPI 0.0.6, 22.6.2026 | `[ранняя стадия]`: lock-файл и Asset Store API, pre-alpha |
| [nilsiker/godam](https://github.com/nilsiker/godam) | v0.1.2, 7.2025 | `[ранняя стадия]`, завязан на уходящую Asset Library |
| [GLAM](https://github.com/henriquelalves/glam), [godot-package-manager](https://github.com/godot-package-manager/cli) | 2023 | `[устарело]` → GodotEnv или gd-plug |

## 12. Другие языки и визуальное программирование: влияние на агента

**Ключевые выводы**
- Строго типизированные языки с собственным компилятором (Rust, C#, Kotlin, Swift) дают агенту быструю обратную связь (`cargo check`, `dotnet build`) без запуска движка. Интеграционные тесты всё равно требуют Godot.
- Визуальное программирование — антипаттерн для агента: логика лежит в графах, которые плохо читаются, не линтуются и не покрываются тестами GDScript.

| Проект | Версия, дата | Godot | Для агента | Оговорки |
|---|---|---|---|---|
| [godot-rust/gdext](https://github.com/godot-rust/gdext) | 0.5.5, 9.8.2026 | фичи `api-4-2`…`api-4-7` | `cargo check/clippy/test` — строгий цикл. Подробно в [domains.md](domains.md#11-interop-c-gdextension-godot-rust) | 0.x: мелкие ломающие изменения между минорами |
| [godot-cpp](https://github.com/godotengine/godot-cpp) | 10.0.0, 15.9.2026 | 4.3+ через `api_version` | Сборка SCons/CMake из CLI | С v10 версия не привязана к версии Godot: `scons api_version=4.7` |
| [utopia-rise/godot-jvm](https://github.com/utopia-rise/godot-jvm) | 1.0.0-rc3, 13.10.2026 | 4.7.2+, JDK 17+ | Kotlin/Java/Scala, Gradle | Release candidate |
| [migueldeicaza/SwiftGodot](https://github.com/migueldeicaza/SwiftGodot) | v0.99.1, 10.10.2026 | 4.7 | `swift build` | До 1.0 |
| [gilzoide/lua-gdextension](https://github.com/gilzoide/lua-gdextension) | 0.8.2, 12.7.2026 | 4.5+ | Lua как язык и песочница для модов | На Web корутины текут памятью |
| [niklas2902/py4godot](https://github.com/niklas2902/py4godot) | 4.7-alpha21, 6.8.2026 | 4.7 | Знакомый синтаксис, но слабый тулинг | Alpha, сборка под каждую версию Godot |
| [godotjs/GodotJS](https://github.com/godotjs/GodotJS) | v1.1.0-beta1 (под 4.6.1) | до 4.6 | `tsc` и typings | Под 4.7 не вышел; нужна своя сборка движка |
| [CraterCrash/godot-orchestrator](https://github.com/CraterCrash/godot-orchestrator) | v2.5, 4.7.2026 | 2.5.x — 4.7 | Плохо: графы `.torch`/`.os` | Версия строго привязана к минорной версии Godot |
| [Lcbx/GdScript2All](https://github.com/Lcbx/GdScript2All) | 2026 | 4.x | Перевод GDScript в C# или C++ (godot-cpp) для переноса горячего кода | Результат доводится руками; GPL-3.0 у инструмента |
| godot-python, godotjs/javascript, godot_luaAPI, HaxeGodot | — | — | — | `[устарело]` → py4godot, GodotJS, lua-gdextension, [reflaxe.GDScript](https://github.com/SomeRanDev/reflaxe.GDScript) |

## 13. ИИ-ассистенты внутри редактора

Агенту, который работает из терминала, эти плагины почти не нужны: они дублируют его самого. Они полезны человеку, который работает с локальными моделями без CLI. Экспортёры контекста (AI Context Generator, Godot AI Suite) склеивают `.tscn` и `.gd` в один текст для чат-ботов; агенту с доступом к файлам это не нужно.

| Проект | Версия, дата; ★ | Что делает | Статус |
|---|---|---|---|
| [FlamxGames/godot-ai-assistant-hub](https://github.com/FlamxGames/godot-ai-assistant-hub) | v2.1.0, 1.9.2026; ~315 | Чат-ассистенты в доке, читают и пишут код; Ollama и OpenAI-совместимые API | Лучший бесплатный чат-плагин для локальных LLM |
| [Exonfang/gdllm-godot-agentic-harness](https://github.com/Exonfang/gdllm-godot-agentic-harness) | v1.6.1, 13.10.2026; ~40 | Агентный харнесс в редакторе: Ollama, OpenAI, Anthropic, Gemini | Молодой проект |
| [Ziva](https://ziva.sh) | 2026 | Закрытый агент в доке + локальный MCP | `[платно]` для хостинга моделей; бесплатно со своей подпиской |
| Godot Copilot, Fuku | 2023–2025 | Автодополнение и чат | `[устарело]` → AI Assistant Hub |

## 14. ИИ внутри игры: LLM, речь, обучение

**Ключевые выводы**
- Облачные LLM вызывайте только через свой бэкенд-прокси. API-ключ в клиенте игры извлекается из PCK за минуты (см. GDRE Tools в разделе 10).
- Локальные модели — GDExtension поверх llama.cpp. Они привязаны к минорной версии Godot и тянут бинарники под каждую платформу; проверьте лицензию (NobodyWho — EUPL-1.2).
- Для классического игрового ИИ (деревья поведения, HSM, utility) LLM не нужны: см. [addons.md](addons.md#1-ии-персонажей-и-машины-состояний).

| Проект | Версия, дата; ★ | Godot | Что делает | Оговорки |
|---|---|---|---|---|
| [nobodywho-ooo/nobodywho](https://github.com/nobodywho-ooo/nobodywho) | godot v12.1.0, 9.10.2026; ~1,6 тыс. | 4.x | Локальные GGUF-модели офлайн: чат, типобезопасный tool calling по сигнатурам функций, TTS, STT (Whisper), VAD | Лучший выбор для LLM-NPC. EUPL-1.2 — копилефт на изменения самой библиотеки |
| [xarillian/chorus-llm](https://github.com/xarillian/chorus-llm) (бывший GDLlama) | v2.0.0, 2.10.2026; ~20 | 4.4+ | Много агентов на одной модели: continuous batching, JSON Schema/GBNF, эмбеддинги | `[ранняя стадия]` |
| [edbeeching/godot_rl_agents](https://github.com/edbeeching/godot_rl_agents) + [плагин](https://github.com/edbeeching/godot_rl_agents_plugin) | PyPI 0.8.2 (2025), коммиты 7.2026; ~1,6 тыс. | 4.x | Обучение NPC с подкреплением (SB3, Sample Factory, RLlib, CleanRL), экспорт в ONNX и инференс в игре | Для ONNX-инференса README рекомендует .NET-сборку |
| [appsinacup/godot-whisper](https://github.com/appsinacup/godot-whisper) | v2.0.3, nightly 6.2026; ~130 | 4.2+ | Распознавание речи (whisper.cpp) на GPU, VAD | Есть в Asset Store |
| [iree-gd/iree.gd](https://github.com/iree-gd/iree.gd) | v0.1.0, 13.6.2026; ~75 | 4.x | Запуск ML-моделей через IREE на Vulkan/Metal | Ниша, модели нужно компилировать |
| [ChrisCrossCrash/c3-openai-client-for-godot](https://github.com/ChrisCrossCrash/c3-openai-client-for-godot) | v0.2.3, 10.6.2026; ~1 | 4.0–4.7 | Клиент OpenAI-совместимых API (LM Studio, Ollama): стриминг сигналами, JSON Schema, TTS/STT | `[ранняя стадия]`; ключи — только через свой прокси |
| `DisplayServer.tts_speak()` | встроено с 4.0 | 4.0+ | Системный синтез речи без аддонов | Включите `audio/general/text_to_speech` |
| godot-llm (Adriankhl), godot-llama-cpp, Godot LLM Framework | 2024 | 4.2 | — | `[устарело]` → NobodyWho, Chorus |

## 15. Ресурсы

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Command line tutorial](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html) | Godot docs, 2026 | Все флаги CLI, включая `--lsp-port`, `--write-movie`, `--doctool` |
| [Creating movies](https://docs.godotengine.org/en/stable/tutorials/animation/creating_movies.html) | Godot docs, 2026 | Movie Maker: детерминированные кадры |
| [TSCN file format](https://docs.godotengine.org/en/stable/engine_details/file_formats/tscn.html) | Godot docs, 2026 | Формат сцен для ручной правки |
| [Logging](https://docs.godotengine.org/en/stable/tutorials/scripting/logging.html) | Godot docs, 2026 | `Logger` и `OS.add_logger()` (4.5+) |
| [Model Context Protocol](https://modelcontextprotocol.io/) | Anthropic и сообщество, 2026 | Спецификация MCP |
| [Introducing the Godot Asset Store](https://godotengine.org/article/introducing-the-godot-asset-store/) | Godot Foundation, 2026 | Переход с Asset Library на Store |
| [awesome-godot](https://github.com/godotengine/awesome-godot) | сообщество, 2026 | Сводный список аддонов и инструментов |

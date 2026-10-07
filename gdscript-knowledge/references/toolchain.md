# Инструментарий GDScript и Godot 4: CLI, линтеры, тесты, CI

Справочник по инструментам вокруг GDScript, актуально на октябрь 2026 года. Актуальный stable — Godot 4.7.2 (18 августа 2026), ветка 4.8 в стадии dev (4.8-dev7, 1 октября 2026). Версии инструментов: gdtoolkit 4.5.0, GDScript Formatter (GDQuest) 0.27.0, GUT 9.7.1, gdUnit4 6.2.2, godot-tools для VS Code 2.7.1, setup-godot v2.4.3. Для каждого инструмента указано, что он делает, как его поставить и какие команды нужны агенту, который работает из терминала. Поведение Godot CLI (`--check-only`, `--import`, коды выхода, `--doctool`) проверено запуском Godot 4.7.2. Пометка `[не проверено]` стоит там, где данные взяты из вторичных источников, `[устарело]` — у приёмов, которые больше не работают.

- [0. Установка Godot и менеджеры версий](#0-установка-godot-и-менеджеры-версий)
- [1. Godot CLI: команды для агента](#1-godot-cli-команды-для-агента)
- [2. Проверка скриптов и предупреждения GDScript](#2-проверка-скриптов-и-предупреждения-gdscript)
- [3. Форматирование и линтинг](#3-форматирование-и-линтинг)
- [4. Редакторы, LSP и отладчик](#4-редакторы-lsp-и-отладчик)
- [5. Тестирование: GUT и gdUnit4](#5-тестирование-gut-и-gdunit4)
- [6. Отладка](#6-отладка)
- [7. Профилирование](#7-профилирование)
- [8. Аддоны и зависимости](#8-аддоны-и-зависимости)
- [9. Документация из кода](#9-документация-из-кода)
- [10. Git: что коммитить](#10-git-что-коммитить)
- [11. Экспорт и CI](#11-экспорт-и-ci)
- [12. MCP-серверы для ИИ-агентов](#12-mcp-серверы-для-ии-агентов)
- [13. Минимальный набор и порядок quality gates](#13-минимальный-набор-и-порядок-quality-gates)
- [14. Шаблоны: project.godot, GitHub Actions, pre-commit](#14-шаблоны-projectgodot-github-actions-pre-commit)
- [15. Ресурсы](#15-ресурсы)

## 0. Установка Godot и менеджеры версий

**Ключевые выводы**
- Агенту нужен бинарник **редактора** (не export template): только в нём есть `--import`, `--export-*`, `--doctool`. Положите его в `PATH` под именем `godot`.
- На Windows для терминала берите `Godot_v4.7.2-stable_win64_console.exe`. Обычный `.exe` — GUI-приложение: вывод и код выхода в консоль не попадают.
- Версию Godot закрепляйте на уровне проекта. `project.godot` хранит только `config/features=PackedStringArray("4.7", ...)`, без патч-версии, поэтому патч фиксируют менеджер версий (gdvm, GodotEnv) или переменная в CI.
- Для GDScript-проекта берите стандартную сборку, не .NET (mono). .NET-сборка нужна только для C#.

| Инструмент | Что и зачем | Установка | Главные команды | Оговорки |
|---|---|---|---|---|
| Godot (4.7.2) | Движок и редактор, он же CLI | архив с godotengine.org/download или GitHub Releases (`Godot_v4.7.2-stable_linux.x86_64.zip`) | `godot --version`; `godot --headless --path . …` | Шаблоны экспорта — отдельный архив `Godot_v4.7.2-stable_export_templates.tpz` |
| gdvm (0.16.0) | Менеджер версий на Rust, shim `godot`, определяет версию по `project.godot` | `curl -sSL https://gdvm.io/install.sh \| bash`; Windows — `install.ps1.txt` через PowerShell | `gdvm install 4.7`; `gdvm use latest`; `gdvm pin 4.7.2`; `gdvm run`; `gdvm list`; `gdvm search 4` | Для CI есть action `setup-gdvm`. Варианты: `csharp:4.7` |
| GodotEnv (2.17.0, Chickensoft) | Версии Godot и аддоны из CLI | `dotnet tool install --global Chickensoft.GodotEnv` | `godotenv godot install 4.7.2 --no-dotnet`; `godotenv godot use 4.7.2`; `godotenv godot pin`; `godotenv godot env setup`; `godotenv addons install` | Нужен .NET SDK даже для GDScript-проектов |
| Godots (1.4.2) | GUI-лаунчер: несколько версий, проекты | релизы на GitHub | — | Для человека, агенту не нужен |

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Godot 4.7.2 release](https://godotengine.org/article/maintenance-release-godot-4-7-2/) | Godot Foundation, 2026 | Что исправлено в актуальном патче |
| [Godot 4.7 release page](https://godotengine.org/releases/4.7/) | Godot Foundation, 2026 | Нововведения ветки 4.7 |
| [Download archive](https://godotengine.org/download/archive/) | Godot Foundation | Прямые ссылки на любые версии и шаблоны |
| [godot-builds releases](https://github.com/godotengine/godot-builds/releases) | Godot Foundation, 2026 | Dev/beta/rc сборки (4.8-dev) |
| [gdvm](https://github.com/adalinesimonian/gdvm) | Adaline Simonian, 2026 | Менеджер версий, shim и pin |
| [GodotEnv](https://github.com/chickensoft-games/GodotEnv) | Chickensoft, 2026 | Версии Godot и `addons.json` |
| [Godots](https://github.com/MakovWait/godots) | MakovWait, 2026 | GUI-лаунчер версий |

## 1. Godot CLI: команды для агента

**Ключевые выводы**
- Любой запуск в терминале и CI начинайте с `godot --headless --path <проект>`. `--headless` = `--display-driver headless --audio-driver Dummy`, без него на машине без GPU экспорт и скрипты падают.
- На свежем клоне первым делом выполните `godot --headless --path . --import`. Команда создаёт `.godot/` (кеш импорта, `global_script_class_cache.cfg`, `uid_cache.bin`). Без этого кеша скрипты, использующие глобальные `class_name`, не проходят проверку: `Identifier "Helper" not declared in the current scope` (проверено на 4.7.2).
- `--import` **не является** линтером. Битый скрипт в проекте не мешает ему завершиться с кодом 0, ошибка парсинга даже не печатается (проверено).
- Скрипт для `-s` должен наследовать `SceneTree` или `MainLoop`. `quit(код)` становится кодом выхода процесса, это основной способ вернуть статус из своих утилит. Аргументы после `--` читаются через `OS.get_cmdline_user_args()`. Узлы, добавленные в `root` прямо в `_initialize()`, ещё не в дереве (`get_tree()` вернёт `null`): сначала `await process_frame` (проверено на 4.7.2).
- Относительный путь вывода в `--export-*` отсчитывается от каталога с `project.godot`, а не от текущего. Каталог вывода должен существовать.
- `--test` запускает C++ юнит-тесты самого движка (нужна сборка `tests=yes`). Для тестов игры он не подходит, используйте GUT или gdUnit4.

| Флаг | Что делает | Где доступен / оговорки |
|---|---|---|
| `--headless` | Без окна и звука | Обязателен в CI и для агента |
| `--path <dir>`, `--upwards` | Каталог проекта; `--upwards` ищет `project.godot` вверх по дереву | — |
| `-e`, `--editor` | Запустить редактор | Только сборка редактора |
| `--import` | Запустить редактор, дождаться импорта и выйти (подразумевает `--editor --quit`) | Код 0 даже при битых скриптах |
| `-s`, `--script <file>` | Выполнить скрипт (`SceneTree`/`MainLoop`) | Путь трактуется как `res://`, можно абсолютный |
| `--check-only` | Только распарсить скрипт и выйти (вместе с `--script`) | Код 1 при ошибке, работает для любого скрипта, не только `SceneTree` (проверено) |
| `--quit`, `--quit-after <N>` | Выйти после 1-й или N-й итерации | Smoke-тест сцены: `--quit-after 120` |
| `--scene <path>` | Запустить конкретную сцену | — |
| `--export-release/--export-debug <preset> <path>` | Экспорт по пресету из `export_presets.cfg` | Нужны шаблоны. Без пресета код 1 (проверено) |
| `--export-pack <preset> <file.pck\|.zip>` | Только пак данных | — |
| `--export-patch <preset> <path>` + `--patches a.pck,b.pck` | Пак только с изменёнными файлами | Появился в 4.4: флаг есть в `main/main.cpp` тега `4.4-stable` и отсутствует в `4.3-stable` (проверено через GitHub API) |
| `--install-android-build-template` | Поставить шаблон Gradle-сборки Android | Вместе с `--export-*` |
| `--doctool [<path>] --gdscript-docs <res-path>` | XML-справка из doc-комментариев | См. раздел 9 |
| `-d`, `--debug` | Локальный stdout-отладчик | В CI зацикливается на `debug>` при ошибке, см. раздел 5 |
| `--remote-debug <uri>` | Подключиться к удалённому отладчику, напр. `tcp://127.0.0.1:6007` | — |
| `--lsp-port`, `--dap-port` | Порты LSP и DAP (по умолчанию 6005 и 6006) | Диапазон 1024–49151 |
| `--debug-collisions`, `--debug-paths`, `--debug-navigation`, `--debug-avoidance` | Визуализация в запущенной игре | Только debug-сборки |
| `--gpu-profile`, `--gpu-validation` | Тайминги GPU, слои валидации графического API | — |
| `--benchmark`, `--benchmark-file <abs.json>` | Замер времени запуска движка | Только редактор. Это не профайлер игры |
| `--log-file <path>`, `-v/--verbose`, `-q/--quiet`, `--no-header` | Управление выводом | `--quiet` в CI не используйте: он прячет вывод скриптов |
| `--write-movie <file>`, `--fixed-fps`, `--time-scale` | Детерминированная запись кадров и видео | — |
| `--recovery-mode` | Редактор без потенциально падающих фич | Если проект роняет редактор |

```bash
godot --headless --path . --import                         # 1. кеш .godot/ и class_name
godot --headless --path . --script res://tools/gen.gd -- --seed 42   # утилита с user args
godot --headless --path . --quit-after 120                # smoke-run главной сцены
godot --headless --path . --export-release "Linux" build/linux/game.x86_64
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Command line tutorial](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html) | Godot docs, 2026 (4.7) | Полный список флагов и их доступность |
| [command_line_tutorial.rst](https://github.com/godotengine/godot-docs/blob/master/tutorials/editor/command_line_tutorial.rst) | Godot docs | Исходник страницы, удобно грепать |
| [main/main.cpp](https://github.com/godotengine/godot/blob/master/main/main.cpp) | Godot, 2026 | Как на самом деле обрабатываются флаги и коды выхода |
| [OS class](https://docs.godotengine.org/en/stable/classes/class_os.html) | Godot docs | `get_cmdline_user_args()`, `get_cmdline_args()` |

## 2. Проверка скриптов и предупреждения GDScript

**Ключевые выводы**
- Единственная проверка, которая использует настоящий парсер и анализатор типов Godot, — `godot --headless --path . --check-only --script res://file.gd`. Она возвращает 1 при ошибке парсинга, анализа или предупреждении, переведённом в Error. Сообщение имеет вид `SCRIPT ERROR: Parse Error: ... (Warning treated as error.)` с путём и строкой. Проверка идёт по одному файлу за запуск, поэтому все скрипты прогоняйте в цикле (шаблон ниже). Запуск — доли секунды на файл.
- Предупреждения уровня Warn в `--check-only` не печатаются вообще (проверено). Строгость в CI обеспечивается только уровнем **Error** в `project.godot`.
- Предупреждения настраиваются в `debug/gdscript/warnings/*`: 0 = Ignore, 1 = Warn, 2 = Error. По умолчанию выключены именно те, что дают типобезопасность: `untyped_declaration`, `unsafe_property_access`, `unsafe_method_access`, `unsafe_cast`, `unsafe_call_argument`, `return_value_discarded`, `missing_await` (в 4.6+).
- Для нового проекта ставьте `untyped_declaration = 2` (Error) и включайте подсказку типов в редакторе (`text_editor/completion/add_type_hints`). Группу `unsafe_*` держите на Warn: на Error она требует явных кастов для каждого обращения к `Variant` и `get_node()`.
- `inferred_declaration` (запрет `:=`) включайте только поверх `untyped_declaration`. Документация прямо говорит, что делать его строже `untyped_declaration` бессмысленно.
- В 4.6+ чужие аддоны исключаются через `debug/gdscript/warnings/directory_rules` (по умолчанию `{"res://addons": 0}` — исключить). Свой аддон включите отдельным правилом. Ключ `exclude_addons` из 4.4–4.5 в 4.6 удалён `[устарело]`. Ключа `treat_warnings_as_errors` из Godot 3 в Godot 4 нет `[устарело]`.
- Точечное подавление: `@warning_ignore("unused_parameter")` на строку или функцию, `@warning_ignore_start("...")` … `@warning_ignore_restore("...")` на участок.

Готовый вариант этого цикла лежит в скилле: [scripts/check_scripts.sh](../scripts/check_scripts.sh). Он принимает путь к Godot в переменной `GODOT`, каталоги-исключения аргументами (по умолчанию `addons`) и печатает ошибки с файлом и строкой. Проверен на Godot 4.7.2.

```bash
# Проверка всех скриптов (bash; после --import). Исключите addons/ и .godot/.
fail=0
while IFS= read -r -d '' f; do
  rel="res://${f#./}"
  if ! out=$(godot --headless --path . --check-only --script "$rel" 2>&1); then
    echo "::error file=${f#./}::GDScript check failed"; echo "$out" | grep -E "SCRIPT ERROR|ERROR|at:"; fail=1
  fi
done < <(find . -name '*.gd' -not -path './.godot/*' -not -path './addons/*' -print0)
exit $fail
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [GDScript warning system](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/warning_system.html) | Godot docs, 2026 | `@warning_ignore`, перевод предупреждений в ошибки |
| [ProjectSettings: debug/gdscript/warnings](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html) | Godot docs, 2026 (4.7) | Все ключи, значения по умолчанию, `directory_rules` |
| [Static typing in GDScript](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html) | Godot docs, 2026 | Что дают типы и safe lines |
| [EditorSettings](https://docs.godotengine.org/en/stable/classes/class_editorsettings.html) | Godot docs, 2026 | `text_editor/completion/add_type_hints` |

## 3. Форматирование и линтинг

**Ключевые выводы**
- Основной форматтер в 2026 году — **GDScript Formatter от GDQuest** (Rust, tree-sitter, Topiary). Он работает за миллисекунды, выходит часто (0.26–0.27 в сентябре 2026), поддерживает `.editorconfig` и содержит встроенный линтер (`gdscript-formatter lint`). `--check` и `lint` возвращают 1 при нарушениях (проверено на 0.27.0).
- gdtoolkit (gdformat, gdlint, gdparse, gdradon) зрелый, но последний релиз 4.5.0 вышел в октябре 2025, и коммитов с тех пор не было. Синтаксис 4.5 (`@abstract`, вариадические `...args`) он понимает (проверено). На свежий синтаксис 4.6–4.7 есть открытые баги (#424, #430). Используйте его ради `gdlint` с настраиваемыми регулярками имён и ради `gdradon` (цикломатическая сложность).
- Не запускайте два форматтера на одних файлах: их стили расходятся (переносы, пустые строки). Выберите один, второй используйте только как линтер.
- Форматтер может испортить код. Запускайте его на чистом рабочем дереве под git. В CI используйте только `--check`; у GDQuest для массовых прогонов есть `--verify-structure`.
- Ни один внешний линтер не знает типов движка. Ошибки вроде несуществующего метода ловит только `--check-only` (раздел 2).

| Инструмент | Что и зачем | Установка | Главные команды | Оговорки |
|---|---|---|---|---|
| GDScript Formatter, GDQuest (0.27.0) | Форматтер и линтер по официальному style guide | бинарник из GitHub Releases (`gdscript-formatter-0.27.0-linux-x86_64.zip`, внутри один файл — переименуйте); `winget install GDQuest.GDScript.Formatter`; `scoop install extras/gdscript-formatter`; AUR `gdscript-formatter-bin`; аддон в Asset Library | `gdscript-formatter` (рекурсивно текущий каталог); `gdscript-formatter --check -x addons .`; `--verify-structure`; `--reorder-code`; `--use-spaces --indent-size 4`; `--max-line-length 100`; `gdscript-formatter lint -x addons --pretty .`; `lint --list-rules`; `lint --disable private-access,max-line-length` | Подавление: `# fmt: off` / `# fmt: on`, `# gdlint-ignore-next-line rule`. Флаг `--safe` из старых README в 0.27 заменён на `--verify-structure` `[устарело]`. Если `-x` исключил все файлы, `--check` падает с «No GDScript files found» |
| gdformat (gdtoolkit 4.5.0) | Бескомпромиссный форматтер | `pipx install "gdtoolkit==4.*"` | `gdformat --check .`; `gdformat --diff file.gd`; `-l 100`; `--use-spaces=4`; `--dump-default-config` (→ `gdformatrc`) | Для Godot 3 нужен `gdtoolkit==3.*` |
| gdlint (gdtoolkit) | Линтер: имена, порядок членов класса, длина функций, число аргументов | там же | `gdlint .`; `gdlint -d` (создаёт `gdlintrc`, переименуйте в `.gdlintrc`) | Подавление: `# gdlint:ignore = function-name`, `# gdlint: disable=rule` / `enable=rule` |
| gdparse, gdradon | Дерево разбора; сложность функций | там же | `gdparse file.gd -p`; `gdradon cc src/` | gdradon полезен для ревью «слишком сложных» функций |
| GDgdtoolkit (1.1.0) | Плагин редактора с вызовом gdtoolkit из меню | Codeberg `svetogam/gdgdtoolkit` (релиз v1.1.0, июнь 2026); в Asset Library пока 1.0.0 для Godot 4.4 | — | `project.godot` версии 1.1.0 помечен `4.7` (проверено по Codeberg API) |

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [GDScript Formatter](https://github.com/GDQuest/GDScript-formatter) | GDQuest (Nathan Lovato и др.), 2026 | Флаги, правила линтера, интеграции с редакторами |
| [GDScript Formatter: docs](https://gdquest.com/library/gdscript_formatter/) | GDQuest, 2026 | Установка в Godot, format-on-save, pre-commit |
| [godot-gdscript-toolkit](https://github.com/Scony/godot-gdscript-toolkit) | Paweł Lampe (Scony), 2025 | gdlint, gdformat, GitHub Action, pre-commit |
| [gdtoolkit на PyPI](https://pypi.org/project/gdtoolkit/) | Scony, 2025 | Версии под Godot 3 и 4 |
| [gdlint wiki](https://github.com/Scony/godot-gdscript-toolkit/wiki/3.-Linter) | Scony | Все проверки и формат `gdlintrc` |
| [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) | Godot docs, 2026 | Стандарт, который проверяют оба инструмента |

## 4. Редакторы, LSP и отладчик

**Ключевые выводы**
- Встроенный в редактор Godot языковой сервер GDScript слушает порт **6005**, отладчик DAP — **6006**. Внешние редакторы подключаются к ним, поэтому редактор Godot должен быть запущен, либо поднимается headless.
- Headless LSP без окна редактора (так его поднимает расширение VS Code): `godot --path <проект> --editor --headless --lsp-port 6005`. Агент может держать такой процесс фоном и получать диагностику через LSP-клиент.
- VS Code: расширение `godot-tools` (официальное, `geequlim.godot-tools`, 2.7.1). Задайте `godotTools.editorPath.godot4` и `godotTools.lsp.headless: true`, тогда редактор Godot держать открытым не нужно.
- В редакторе Godot укажите внешний редактор: Editor Settings → Text Editor → External, `Exec Flags` вида `{project} --goto {file}:{line}:{col}` для VS Code.
- JetBrains Rider поддерживает Godot и GDScript, в том числе отладку. Neovim подключается через `nvim-lspconfig` (сервер `gdscript`, TCP 127.0.0.1:6005, порт меняется переменной окружения `GDScript_Port`; проверено по `lsp/gdscript.lua` в репозитории nvim-lspconfig).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [godot-vscode-plugin](https://github.com/godotengine/godot-vscode-plugin) | Godot, 2026 (2.7.1) | Настройки LSP, headless, `launch.json` для отладки |
| [godot-tools в Marketplace](https://marketplace.visualstudio.com/items?itemName=geequlim.godot-tools) | Godot, 2026 | Установка расширения |
| [Using an external text editor](https://docs.godotengine.org/en/stable/tutorials/editor/external_editor.html) | Godot docs, 2026 | Exec Flags, LSP и DAP для внешних редакторов |
| [Rider: Godot support](https://www.jetbrains.com/help/rider/Godot.html) | JetBrains, 2026 | GDScript и отладка в Rider |

## 5. Тестирование: GUT и gdUnit4

**Ключевые выводы**
- Оба фреймворка — аддоны в `addons/` с CLI-раннером и экспортом JUnit XML. GUT проще и ближе к xUnit. gdUnit4 богаче: fluent-ассерты, моки и спаи, scene runner с симуляцией ввода, fuzzing, детектор orphan-нод, HTML-отчёт, поддержка C#.
- Версию аддона берите строго под свою ветку Godot. GUT: 9.7.x → Godot 4.7, 9.6.x → 4.6, 9.5.0 → 4.5, 9.4.0 → 4.3–4.4. gdUnit4 6.2.x покрывает 4.5–4.8-dev.
- Перед тестами выполните `--import`, иначе `class_name` и ресурсы не найдутся.
- **Ловушка `-d`.** При ошибке парсинга под флагом `-d` Godot входит в интерактивный отладчик `debug>`, и CI висит до таймаута. В раннере gdUnit4 это обойдено флагом `--remote-debug tcp://127.0.0.1:0`. Для GUT в CI либо уберите `-d`, либо добавьте тот же `--remote-debug` (на 4.7.2 проверено со своим `-s`-скриптом, который грузит битый скрипт: с `-d` — бесконечный `debug>`, с `-d --remote-debug tcp://127.0.0.1:0` — обычный `SCRIPT ERROR`; GUT запускается тем же `-s`). Задавайте таймаут шага (`timeout-minutes`): `-s`-скрипт, в котором ошибка прервала функцию до `quit()`, не завершится сам (проверено на 4.7.2).
- В GUT 9.x по умолчанию тест падает, если во время него случилась ошибка движка или `push_error` (`-gfailure_error_types`, значение по умолчанию `["engine", "gut", "push_error"]`). Это полезно: тихие ошибки не проходят.
- gdUnit4 по умолчанию отказывается работать в headless, потому что симуляция ввода требует окна. Для чистой логики добавляйте `--ignoreHeadlessMode`. Для тестов сцен с вводом запускайте без `--headless` под `xvfb-run`: так делает gdUnit4-action (`spawnSync("xvfb-run", ...)` в `.gdunit4_action/unit-test/index.js`; проверено по исходнику). Код 103 означает «headless не поддерживается».

| Инструмент | Что и зачем | Установка | Главные команды | Коды выхода и отчёты |
|---|---|---|---|---|
| GUT (9.7.1) | Юнит- и интеграционные тесты: `extends GutTest`, `test_*`, doubles и stubs, параметризация, `await` | zip из GitHub Releases или Asset Library → `addons/gut`, включить плагин | `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit -gjunit_xml_file=res://reports/gut.xml`; `-gselect=player`; `-gunit_test_name=jump`; `-gconfig=res://.gutconfig.json`; `-gprint_gutconfig_sample` | 0 — все прошли, 1 — есть падения (pending не влияет). JUnit через `-gjunit_xml_file` |
| gdUnit4 (6.2.2) | Тесты GDScript и C#: `extends GdUnitTestSuite`, `assert_that()`, моки, `scene_runner()` | Asset Library или GitHub Releases → `addons/gdUnit4` | `export GODOT_BIN=$(which godot)`; `./addons/gdUnit4/runtest.sh --headless -a res://test --ignoreHeadlessMode -c` (`runtest.sh` передаёт все аргументы, кроме `--godot_binary`, в Godot как есть и сам добавляет `-d --remote-debug tcp://127.0.0.1:0`; проверено по исходнику); `-i <suite>` исключить; `-rd reports` | 0 — ок, 100 — есть падения, 101 — есть предупреждения. Отчёты: `reports/…/index.htm` и `results.xml` (JUnit) |

```bash
# GUT без -d, с явным таймаутом (Linux CI)
timeout 600 godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://test -ginclude_subdirs -gexit -gjunit_xml_file=res://reports/gut-junit.xml
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [GUT](https://github.com/bitwes/Gut) | Butch Wesley (bitwes), 2026 | Таблица совместимости версий с Godot |
| [GUT docs: Command Line](https://gut.readthedocs.io/en/latest/Command-Line.html) | bitwes, 2026 | Все опции `-g*` и `.gutconfig.json` |
| [GUT docs](https://gut.readthedocs.io/en/latest/) | bitwes, 2026 | Doubles, Error Tracking, Awaiting, Mocking Input |
| [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) | Mike Schulze и godot-gdunit-labs, 2026 | Совместимость, возможности, C# |
| [gdUnit4 docs: Command Line](https://godot-gdunit-labs.github.io/gdUnit4/latest/advanced_testing/cmd/) | godot-gdunit-labs, 2026 | `runtest`, коды 0/100/101, отчёты |
| [gdUnit4 docs](https://godot-gdunit-labs.github.io/gdUnit4/latest/) | godot-gdunit-labs, 2026 | Ассерты, моки, scene runner |

## 6. Отладка

**Ключевые выводы**
- Для агента главный канал — stdout и stderr headless-запуска. Ошибки GDScript печатаются как `SCRIPT ERROR:` со строкой `at: <func> (res://file.gd:<line>)`, ошибки движка — как `ERROR:`. `push_error()` и `push_warning()` пишут в stderr со стеком и попадают в панель Errors отладчика. `print_debug()` добавляет к выводу файл и строку, `print_stack()` печатает стек.
- `assert(cond, "msg")` работает только в debug-сборках и в редакторе. В release-экспорте выражение внутри `assert` не вычисляется, поэтому побочные эффекты в него не кладите.
- Remote Scene Tree (вкладка Remote в доке Scene) показывает живое дерево запущенной игры и позволяет править свойства. Debugger → Evaluator вычисляет выражения на брейкпоинте. Брейкпоинт в коде ставится ключевым словом `breakpoint`.
- Визуальные флаги: `--debug-collisions`, `--debug-navigation`, `--debug-paths`, `--debug-avoidance`. В редакторе они же доступны в меню Debug.
- Для разбора падений в CI пишите лог в файл (`--log-file /abs/path.log`, `-v`) и выгружайте его артефактом.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Overview of debugging tools](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/overview_of_debugging_tools.html) | Godot docs, 2026 | Карта всех средств отладки |
| [Debugger panel](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/debugger_panel.html) | Godot docs, 2026 | Stack Trace, Errors, Evaluator, профайлеры, Monitors, Video RAM |
| [Output panel](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/output_panel.html) | Godot docs, 2026 | `print_rich`, фильтры, форматы сообщений |

## 7. Профилирование

**Ключевые выводы**
- Встроенный Profiler (Debugger → Profiler) измеряет время по функциям GDScript и по кадрам (process, physics, idle). Visual Profiler показывает CPU и GPU по этапам рендера, Network Profiler — RPC и трафик, Monitors — FPS, память, число объектов и нод, draw calls, Video RAM — потребление текстур и ресурсов.
- Свои метрики добавляются через `Performance.add_custom_monitor("game/enemies", callable)` и появляются во вкладке Monitors. Из кода метрики читаются через `Performance.get_monitor(Performance.TIME_FPS)`. Это удобно для headless-бенчмарков: запустите сцену с `--fixed-fps 60 --quit-after N` и выведите метрики в stdout.
- Профилируйте сборку, близкую к релизной. Debug-сборка и редактор медленнее, особенно GDScript с проверками.
- Для нативного профилирования движка документация описывает Tracy, Perfetto и Instruments (только Apple). Движок собирается сам: `scons … profiler=tracy profiler_path=… debug_symbols=yes`. Для Android готовые шаблоны уже содержат Perfetto.
- `--benchmark` и `--benchmark-file` замеряют этапы запуска движка, а не геймплей. `--gpu-profile` выводит тайминги задач GPU.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [The Profiler](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html) | Godot docs, 2026 | Как читать профайлер GDScript |
| [Custom performance monitors](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/custom_performance_monitors.html) | Godot docs, 2026 | Свои метрики во вкладке Monitors |
| [Performance class](https://docs.godotengine.org/en/stable/classes/class_performance.html) | Godot docs, 2026 | Список встроенных мониторов |
| [Performance tutorials](https://docs.godotengine.org/en/stable/tutorials/performance/index.html) | Godot docs, 2026 | Оптимизация CPU, GPU, GDScript |
| [Profiling the engine](https://docs.godotengine.org/en/stable/engine_details/development/profiling/index.html), [Tracy](https://docs.godotengine.org/en/latest/engine_details/development/profiling/tracy.html) | Godot docs, 2026 | Tracy, Perfetto, Instruments |
| [Tracy profiler](https://github.com/wolfpld/tracy) | Bartosz Taudul, 2026 | Сервер Tracy |

## 8. Аддоны и зависимости

**Ключевые выводы**
- Источники аддонов: **Godot Asset Store** (store.godotengine.org, магазин Godot Foundation для бесплатных и платных ассетов и аддонов), старая Godot Asset Library (пока онлайн, но store её преемник) и git. В 4.7 Asset Store встроен в редактор: вкладка Asset Store в главном экране рядом с 2D, 3D и Script, шаблоны проектов — во вкладке Asset Store менеджера проектов. Ассеты из Asset Library автоматически не перенесены ([About the Asset Store](https://docs.godotengine.org/en/stable/community/asset_store/what_is_asset_store.html)).
- В Godot нет штатного менеджера зависимостей с lock-файлом. Варианты: коммитить `addons/` целиком (проще всего и воспроизводимо), git submodule на конкретный тег, gd-plug (`plug.gd` в корне), GodotEnv (`addons.json`).
- Коммитьте `plugin.cfg` и включённые плагины в `project.godot` (`[editor_plugins] enabled=...`). Аддон-раннер тестов (GUT, gdUnit4) тоже коммитьте, тогда CI не скачивает его.
- Чужие аддоны исключайте из предупреждений (`directory_rules`), из форматтера и линтера (`-x addons`) и из `--check-only`.

| Инструмент | Что и зачем | Главные команды | Оговорки |
|---|---|---|---|
| Asset Store / AssetLib | Каталоги аддонов | вкладка Asset Store в редакторе 4.7; сайт store.godotengine.org | Авторы должны заново загрузить ассеты в Store, часть аддонов есть только в старой Asset Library |
| gd-plug (0.2.6) | Vim-plug-подобный менеджер: аддоны из git по тегу или коммиту | `godot --headless -s plug.gd install`; `status`; `uninstall`; `install production` | Релиз 2024 года, репозиторий жив |
| GodotEnv addons | `addons.json(c)`: git, локальные пути, симлинки | `godotenv addons init`; `godotenv addons install` | Требует .NET |
| git submodule | Аддон из своего репозитория | `git submodule add <url> addons/x` | Многие репозитории аддонов содержат весь демо-проект, а не только `addons/` |

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Godot Asset Library](https://godotengine.org/asset-library/asset) | Godot Foundation | Каталог аддонов |
| [Godot Asset Store](https://store.godotengine.org/) | Godot Foundation, 2026 | Новый магазин ассетов и аддонов |
| [Using the Asset Library](https://docs.godotengine.org/en/stable/community/asset_library/using_assetlib.html) | Godot docs, 2026 | Установка из редактора |
| [Installing plugins](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/installing_plugins.html) | Godot docs, 2026 | Включение плагинов |
| [gd-plug](https://github.com/imjp94/gd-plug) | imjp94, 2024 | Декларативные зависимости через `plug.gd` |

## 9. Документация из кода

**Ключевые выводы**
- Doc-комментарии пишутся через `##` перед `class_name`, членом или функцией. Поддерживаются BBCode-теги, `@deprecated`, `@experimental`, `@tutorial`. Справка по ним видна в редакторе (F1) для любых `class_name`.
- XML в формате справки движка генерируется командой `godot --headless --path . --doctool docs --gdscript-docs res://`. Получается по файлу на скрипт (`Helper.xml` для `class_name`, `ok.gd.xml` для остальных). Код выхода 0 даже при битых скриптах (проверено), поэтому запускайте после проверки из раздела 2.
- Каталог вывода создайте заранее (`mkdir -p docs`) и добавьте его в `.gitignore`, если XML нужны только для публикации. Путь относителен текущему каталогу (проверено при запуске из корня проекта).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [GDScript documentation comments](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html) | Godot docs, 2026 | Синтаксис `##`, теги, BBCode |

## 10. Git: что коммитить

**Ключевые выводы**
- Игнорируйте `.godot/` (кеш импорта, `uid_cache.bin`, учётные данные экспорта) и `/android/` (шаблон Gradle-сборки, ставится заново). Ровно эти строки пишет сам редактор через Project → Version Control → Generate Version Control Metadata (проверено по исходнику 4.7).
- Коммитьте `project.godot`, `*.tscn`, `*.tres`, `*.gd`, `*.import` (настройки импорта ассетов), файлы `*.uid` (в Godot 4.4+ они лежат рядом со скриптами и шейдерами и хранят UID ресурса) и `export_presets.cfg`. Начиная с 4.1 пароли и ключи в `export_presets.cfg` не хранятся, они лежат в `.godot/export_credentials.cfg` (проверено по `editor/export/editor_export.cpp` тега `4.7.2-stable`).
- `.gitattributes` с `* text=auto eol=lf` обязателен в командах с Windows. Большие бинарные ассеты храните в Git LFS.

```gitignore
# .gitignore (Godot 4+)
.godot/
/android/
/build/
/reports/
# бинарные переводы, генерируются из CSV
*.translation
```

```gitattributes
# .gitattributes
* text=auto eol=lf
*.png filter=lfs diff=lfs merge=lfs -text
*.ogg filter=lfs diff=lfs merge=lfs -text
*.glb filter=lfs diff=lfs merge=lfs -text
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Version control systems](https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html) | Godot docs, 2026 | Что игнорировать, LFS, eol |
| [UID changes coming to Godot 4.4](https://godotengine.org/article/uid-changes-coming-to-godot-4-4/) | Godot Foundation, 2025 | Зачем коммитить `.uid` |
| [godot-git-plugin](https://github.com/godotengine/godot-git-plugin) | Godot | Git внутри редактора |

## 11. Экспорт и CI

**Ключевые выводы**
- Экспорт из CI = бинарник редактора + шаблоны экспорта той же версии + закоммиченный `export_presets.cfg`. Шаблоны лежат в `~/.local/share/godot/export_templates/4.7.2.stable/` (Linux), `%APPDATA%\Godot\export_templates\4.7.2.stable\` (Windows).
- Godot в GitHub Actions ставьте через `chickensoft-games/setup-godot@v2`. Версия указывается полностью (`4.7.2`). Для GDScript-проекта обязательно `use-dotnet: false`, по умолчанию там `true`. Action кеширует установку и кладёт `godot` в `PATH`. Альтернатива — контейнер `barichello/godot-ci:4.7.2` (шаблоны уже внутри, есть теги `mono-4.7.2`, `latest`).
- Кешируйте `.godot/` между прогонами (`actions/cache`, ключ — хеш ассетов и `*.import`). На больших проектах это экономит минуты импорта. При смене версии Godot кеш сбрасывайте.
- `--headless` для тестов достаточно, xvfb не нужен. Исключение — тесты с реальным окном и вводом (gdUnit4 scene runner).
- Web-экспорт: в 4.3+ однопоточная сборка без `SharedArrayBuffer` позволяет хостить на GitHub Pages и itch.io без COOP/COEP-заголовков. Это настраивается в пресете Web (Thread Support выключен, это значение по умолчанию; проверено по документации 4.7). Android: нужны JDK 17 (более новые поддерживаются, 17 рекомендуется), Android SDK (`export/android/android_sdk_path` в editor settings) и keystore. Для Gradle-сборки добавьте `--install-android-build-template`.
- Секреты (keystore, пароли) передавайте через переменные окружения `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` (и аналогичные `..._DEBUG_...`); они переопределяют значения из меню экспорта (проверено по документации 4.7). В `export_presets.cfg` их не кладите.

| Инструмент | Что и зачем | Использование | Оговорки |
|---|---|---|---|
| setup-godot (v2.4.3) | Установка Godot 4 на ubuntu, macos и windows раннеры | `uses: chickensoft-games/setup-godot@v2` с `version: 4.7.2`, `use-dotnet: false`, `include-templates: true` | Только Godot 4. Добавляет `GODOT`, `GODOT4` |
| barichello/godot-ci (4.7.2) | Docker-образ с Godot и шаблонами | `container: image: barichello/godot-ci:4.7.2` | В шаблоне workflow шаблоны переносятся из `/root/...` в `~/.local/share/godot/export_templates/` |
| firebelley/godot-export (v8.0.0) | Экспорт всех пресетов и архивация в релиз | inputs `godot_executable_download_url`, `godot_export_templates_download_url`, `relative_project_path`, `presets_to_export`, `archive_output`, `cache` | Ссылки на бинарник и шаблоны задаются вручную |
| gdUnit4-action (v1.3.2) | Готовый шаг тестов gdUnit4 с отчётом | `uses: godot-gdunit-labs/gdUnit4-action@v1` с `godot-version`, `paths: res://test`, `report-name`, `timeout` | Ставит свой Godot |
| Scony/godot-gdscript-toolkit (action) | Ставит gdtoolkit | `uses: Scony/godot-gdscript-toolkit@master`, затем `gdformat --check`, `gdlint` | Закрепляйте коммит, а не `@master` |

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Exporting projects](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html) | Godot docs, 2026 | Пресеты, шаблоны, экспорт из CLI |
| [Exporting for the Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html) | Godot docs, 2026 | Потоки, COOP/COEP, хостинг |
| [Exporting for Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) | Godot docs, 2026 | SDK, keystore, Gradle build |
| [Exporting for dedicated servers](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html) | Godot docs, 2026 | Headless-сервер, удаление ресурсов |
| [Exporting packs, patches, mods](https://docs.godotengine.org/en/stable/tutorials/export/exporting_pcks.html) | Godot docs, 2026 | PCK, `--export-pack`, патчи |
| [Feature tags](https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html) | Godot docs, 2026 | Настройки по платформам и пресетам |
| [setup-godot](https://github.com/chickensoft-games/setup-godot) | Chickensoft, 2026 | Inputs и кеширование |
| [godot-ci](https://github.com/abarichello/godot-ci), [Docker Hub](https://hub.docker.com/r/barichello/godot-ci) | Artur Barichello, 2026 | Шаблоны workflow для Web, Windows, Linux, macOS, Android |
| [godot-export](https://github.com/firebelley/godot-export) | firebelley, 2026 | Экспорт пресетов и релизы |
| [gdUnit4-action](https://github.com/godot-gdunit-labs/gdUnit4-action) | godot-gdunit-labs, 2026 | Все inputs и матрица версий |
| [setup-gdvm](https://github.com/adalinesimonian/setup-gdvm) | Adaline Simonian, 2026 | gdvm в CI |

## 12. MCP-серверы для ИИ-агентов

**Ключевые выводы**
- Официального MCP-сервера от Godot Foundation на октябрь 2026 нет. Сообщество делает два вида серверов: обёртки над CLI (запуск, захват вывода, операции со сценами через GDScript) и плагины внутри редактора (полный доступ к открытой сцене, инспектору, вводу).
- Самый популярный — Coding-Solo/godot-mcp (около 6 тыс. звёзд, MIT, последний коммит в апреле 2026). Он умеет запускать редактор и проект, собирать debug-вывод, создавать сцены и ноды, работать с UID (4.4+). Подключение к Claude Code: `claude mcp add godot -- npx @coding-solo/godot-mcp`, путь к Godot передаётся в `GODOT_PATH`.
- MCP не заменяет quality gates. Проверка, тесты и экспорт — это CLI-команды из разделов 1–5, их агент запускает напрямую. MCP полезен для интерактивной работы со сценами и живой игрой. Плагины внутри редактора исполняют код с правами редактора: ставьте только проверенные и не давайте им доступ к секретам.

| Сервер | Тип | Статус на октябрь 2026 |
|---|---|---|
| [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp) | CLI-обёртка (Node, npx) | около 6 тыс. ★, активен до апреля 2026 |
| [youichi-uda/godot-mcp-pro](https://github.com/youichi-uda/godot-mcp-pro) | Плагин и сервер, более 160 инструментов | Активен (сентябрь 2026) |
| [3ddelano/gdai-mcp-plugin-godot](https://github.com/3ddelano/gdai-mcp-plugin-godot) | Плагин редактора (GDAI MCP) | Активен (сентябрь 2026) |
| ee0pdt/Godot-MCP | Плагин и сервер | [устарело] Последний коммит в марте 2025 |

## 13. Минимальный набор и порядок quality gates

**Ключевые выводы**
- Минимальный набор для любого GDScript-проекта: закреплённая версия Godot, `untyped_declaration = Error` и `directory_rules` в `project.godot`, GDScript Formatter (`--check` и `lint`), headless `--check-only` по всем скриптам, один тест-фреймворк (GUT или gdUnit4) с JUnit-отчётом, `.gitignore` и `.gitattributes` от редактора.
- Порядок: дешёвые и быстрые проверки идут первыми, экспорт последним. Каждый шаг завершается ненулевым кодом при ошибке. Это проверено для `--check`, `lint`, `--check-only`, GUT, gdUnit4 и экспорта без пресета.
- gdlint из gdtoolkit добавляйте, если нужны настраиваемые правила имён и ограничения размера функций. gdradon подключайте для ревью сложности. Профилирование и MCP в CI не нужны.

| Ситуация | Инструменты |
|---|---|
| Всегда | Godot 4.7.2 (gdvm или setup-godot), GDScript Formatter, `--check-only`, GUT или gdUnit4, предупреждения в `project.godot`, `.gitignore` и `.gitattributes` |
| Командный проект | + pre-commit с форматтером, VS Code godot-tools или Rider, JUnit-отчёты в PR |
| Строгая типизация | + `unsafe_*` = Warn или Error, `inferred_declaration` по вкусу, `return_value_discarded` = Warn |
| Аддон для публикации | + `directory_rules` с правилом включения для своего аддона, тесты на нескольких версиях Godot (матрица), `--doctool --gdscript-docs` |
| Релизы | + `--export-release` по пресетам, godot-ci или setup-godot с `include-templates`, firebelley/godot-export |

**Минимальные quality gates по порядку** (локально и в CI, из корня проекта):

```bash
gdscript-formatter --check -x addons .                # 1. формат (exit 1, если нужно переформатировать)
gdscript-formatter lint -x addons .                   # 2. стиль и имена
godot --headless --path . --import                    # 3. кеш .godot/ и class_name (код выхода не показатель)
GODOT=godot ./check_scripts.sh                        # 4. --check-only по всем .gd (scripts/check_scripts.sh скилла)
mkdir -p reports                                      # JUnit-файл не создастся без каталога (проверено)
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit \
      -gjunit_xml_file=res://reports/gut-junit.xml    # 5. тесты (или runtest.sh для gdUnit4)
godot --headless --path . --export-release "Linux" build/linux/game.x86_64   # 6. экспорт (только в CI или для релиза)
```

## 14. Шаблоны: project.godot, GitHub Actions, pre-commit

**Ключевые выводы**
- Настройки предупреждений хранятся в `project.godot` в секции `[debug]` с ключами без префикса `debug/`. Поменять их можно и в UI (Project Settings → Advanced Settings → GDScript).
- В шаблоне workflow форматтер и линтер идут отдельной быстрой задачей, а проверка скриптов и тесты — второй задачей с одним импортом.

```ini
; project.godot, Godot 4.6+ (directory_rules и missing_await появились в 4.6).
; Проверено на 4.7.2: untyped в res://addons/my_addon ловится, в остальных addons/ нет.
; Комментарии «;» редактор удалит при следующем сохранении настроек.
[debug]
gdscript/warnings/untyped_declaration=2        ; Error: типы обязательны
gdscript/warnings/unsafe_property_access=1     ; Warn
gdscript/warnings/unsafe_method_access=1
gdscript/warnings/unsafe_cast=1
gdscript/warnings/unsafe_call_argument=1
gdscript/warnings/return_value_discarded=0     ; слишком шумно для connect()/tween
gdscript/warnings/missing_await=1
gdscript/warnings/unused_variable=2
gdscript/warnings/unused_local_constant=2
gdscript/warnings/unreachable_code=2
gdscript/warnings/shadowed_variable=2
gdscript/warnings/standalone_expression=2
gdscript/warnings/integer_division=1
gdscript/warnings/narrowing_conversion=1
gdscript/warnings/directory_rules={"res://addons": 0, "res://addons/my_addon": 1}  ; 0 = Exclude, 1 = Include
```

```yaml
# .github/workflows/ci.yml
name: ci
on: [push, pull_request]
env:
  GODOT_VERSION: 4.7.2
  FORMATTER_VERSION: 0.27.0
jobs:
  style:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Install GDScript Formatter
        run: |
          curl -sSL -o fmt.zip "https://github.com/GDQuest/GDScript-formatter/releases/download/${FORMATTER_VERSION}/gdscript-formatter-${FORMATTER_VERSION}-linux-x86_64.zip"
          unzip -q fmt.zip && sudo install -m 755 "gdscript-formatter-${FORMATTER_VERSION}-linux-x86_64" /usr/local/bin/gdscript-formatter
      - run: gdscript-formatter --check -x addons .
      - run: gdscript-formatter lint -x addons .

  check-and-test:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
        with: { lfs: true }
      - uses: chickensoft-games/setup-godot@v2
        with:
          version: ${{ env.GODOT_VERSION }}
          use-dotnet: false
          include-templates: true
      - uses: actions/cache@v4
        with:
          path: .godot
          key: godot-${{ env.GODOT_VERSION }}-${{ hashFiles('**/*.import', 'project.godot') }}
          restore-keys: godot-${{ env.GODOT_VERSION }}-
      - name: Import
        run: godot --headless --path . --import
      - name: Parse/type check all scripts
        shell: bash
        run: |
          fail=0
          while IFS= read -r -d '' f; do
            if ! out=$(godot --headless --path . --check-only --script "res://${f#./}" 2>&1); then
              echo "::error file=${f#./}::GDScript check failed"; echo "$out"; fail=1
            fi
          done < <(find . -name '*.gd' -not -path './.godot/*' -not -path './addons/*' -print0)
          exit $fail
      - name: Tests (GUT)
        run: |
          mkdir -p reports
          godot --headless --path . -s addons/gut/gut_cmdln.gd \
            -gdir=res://test -ginclude_subdirs -gexit -gjunit_xml_file=res://reports/gut-junit.xml
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: test-reports, path: reports/ }
      - name: Export Linux
        if: github.ref == 'refs/heads/main'
        run: |
          mkdir -p build/linux
          godot --headless --path . --export-release "Linux" build/linux/game.x86_64
      - uses: actions/upload-artifact@v4
        if: github.ref == 'refs/heads/main'
        with: { name: linux-build, path: build/linux }
```

Workflow собран из проверенных частей (команды форматтера, Godot CLI, inputs setup-godot), но целиком на GitHub не запускался `[не проверено]`. Имя пресета (`"Linux"`) должно совпадать с `export_presets.cfg`. Для gdUnit4 вместо шага GUT используйте `godot-gdunit-labs/gdUnit4-action@v1` или `./addons/gdUnit4/runtest.sh -a res://test --ignoreHeadlessMode` с `GODOT_BIN`.

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/GDQuest/GDScript-formatter
    rev: 0.27.0
    hooks:
      - id: gdscript-formatter
      - id: gdscript-linter
  # альтернатива или дополнение: gdtoolkit
  # - repo: https://github.com/Scony/godot-gdscript-toolkit
  #   rev: 4.5.0
  #   hooks: [{ id: gdlint }]
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [pre-commit](https://pre-commit.com/) | pre-commit, 2026 | Установка (`pre-commit install`) и конфиг хуков |
| [Project Settings](https://docs.godotengine.org/en/stable/tutorials/editor/project_settings.html) | Godot docs, 2026 | Как устроен `project.godot` и Advanced Settings |

## 15. Ресурсы

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Godot docs (stable = 4.7)](https://docs.godotengine.org/en/stable/) | Godot Foundation, 2026 | Основная документация |
| [GDScript reference](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html) | Godot docs, 2026 | Синтаксис, аннотации, `@warning_ignore` |
| [Engine unit testing](https://docs.godotengine.org/en/stable/engine_details/architecture/unit_testing.html) | Godot docs, 2026 | Что такое `--test` (тесты движка, не игры) |
| [godot-proposals](https://github.com/godotengine/godot-proposals) | Godot community | Планы по инструментам: линтер, форматтер, тест-раннер в движке |
| [Chickensoft](https://chickensoft.games/) | Chickensoft, 2026 | Экосистема CI и инструментов для Godot |

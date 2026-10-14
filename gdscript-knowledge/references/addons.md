# Аддоны Godot 4: выбор, установка и каталог игровых систем

Справочник по аддонам и плагинам, которые упрощают и ускоряют работу с Godot 4, с упором на то, насколько с ними удобно работать ИИ-агенту из терминала. Актуально на 14 октября 2026 (Godot 4.7.2). Звёзды, версии, лицензии и даты последних коммитов сверены с GitHub, Codeberg и GitLab в этот день. Здесь — правила выбора и установки, что уже встроено в движок, и каталог игровых систем: ИИ, камера, диалоги, ввод, инвентарь, сохранения, архитектура, физика, процедурка, карточные игры, UI, звук, локализация, сеть, платформы, аналитика. Редактор, отладка, левел-дизайн, рендеринг, анимация, импорт и шаблоны — в [addons-content.md](addons-content.md). MCP-серверы, анализаторы, автоматизация, сборка и ИИ в игре — в [addons-agent-tools.md](addons-agent-tools.md).

Пометки: `[устарело]` — нет коммитов больше 12 месяцев или нет поддержки 4.4+, замена указана рядом; `[не проверено]` — факт из одного вторичного источника; `[встроено]` — возможность движка, аддон не нужен. Колонка **4.7.2** — результат [scripts/addon_smoke.sh](../scripts/addon_smoke.sh) на Godot 4.7.2 (14.10.2026): «✓» — аддон из `main` (или указанного тега) встал в чистый проект, плагин включился в headless-редакторе, все его скрипты скомпилировались без ошибок; «✗» — с ошибками, подробности в оговорках; «—» — не проверялся. Для GDExtension «✓» дополнительно значит, что движок загрузил нативную библиотеку (проверка через `GDExtensionManager` на Windows x86_64; другие платформы не проверялись). «✓» не означает, что аддон работает правильно во всех сценариях: это проверка загрузки, а не функциональный тест. Всего так проверено 54 аддона. Колонка **Агент**: «текст» — данные аддона хранятся в тексте (`.gd`, `.tscn`, `.tres`, JSON, свой текстовый формат), агент пишет и ревьюит их как код; «API» — управляется кодом, но часть данных бинарная или собирается в редакторе; «GUI» — основная работа идёт в графе или кистью в редакторе, агент только готовит сцену.

- [0. Как выбирать и ставить аддоны](#0-как-выбирать-и-ставить-аддоны)
- [1. ИИ персонажей и машины состояний](#1-ии-персонажей-и-машины-состояний)
- [2. Камера и контроллеры персонажа](#2-камера-и-контроллеры-персонажа)
- [3. Диалоги, нарратив, квесты](#3-диалоги-нарратив-квесты)
- [4. Ввод](#4-ввод)
- [5. Инвентарь, RPG-данные, способности](#5-инвентарь-rpg-данные-способности)
- [6. Сохранения и данные](#6-сохранения-и-данные)
- [7. Архитектура: сцены, ECS, DI, juice](#7-архитектура-сцены-ecs-di-juice)
- [8. Физика и движение](#8-физика-и-движение)
- [9. Процедурная генерация и мир](#9-процедурная-генерация-и-мир)
- [10. Карточные, пошаговые и сеточные игры](#10-карточные-пошаговые-и-сеточные-игры)
- [11. UI](#11-ui)
- [12. Звук](#12-звук)
- [13. Локализация](#13-локализация)
- [14. Сеть, мультиплеер, бэкенды](#14-сеть-мультиплеер-бэкенды)
- [15. Платформы, магазины, мобильные, Web, XR](#15-платформы-магазины-мобильные-web-xr)
- [16. Аналитика и краш-репорты](#16-аналитика-и-краш-репорты)
- [17. Чеклист перед добавлением аддона](#17-чеклист-перед-добавлением-аддона)
- [18. Ресурсы](#18-ресурсы)

## 0. Как выбирать и ставить аддоны

**Ключевые выводы**
- Сначала проверьте, не встроено ли это в движок (таблица ниже). За 4.3–4.7 в ядро вошли Jolt, IK, `VirtualJoystick`, интерактивная музыка, AccessKit, `Logger`, Tracy, stencil-аутлайны, а Minimal Theme стала темой редактора. Многие популярные аддоны и туториалы на них устарели.
- Предпочитайте аддоны с данными в тексте и API в коде. Граф-редакторы (Questify, Dialogue Nodes, Gaea 2, Juicee, gd-YAFSM) агент может только читать; правку графа надёжнее отдать человеку.
- Чистый GDScript проще GDExtension: не нужны бинарники под каждую платформу, а версия не привязана к минорной версии Godot. GDExtension, собранный под 4.5, грузится в 4.7, но не наоборот.
- Ставьте аддоны декларативно (GodotEnv `addons.json`, gd-plug `plug.gd`) или коммитьте `addons/` целиком; см. [toolchain.md](toolchain.md#8-аддоны-и-зависимости). Источник с 4.7 — Godot Asset Store; старая Asset Library объявлена устаревшей.
- **Включение плагина правкой `project.godot` не вызывает `_enable_plugin()`** (проверено на 4.7.2 на LimboConsole). Автозагрузки, которые плагин регистрирует в этом методе через `add_autoload_singleton()`, не появятся, и скрипты, обращающиеся к ним, не скомпилируются. Агент, который включает плагин строкой в `[editor_plugins]`, должен прочитать `_enable_plugin()` в скрипте плагина и сам дописать `[autoload]`. Плагины, которые делают это в `_enter_tree()` (Dialogic, netfox), такой проблемы не имеют. Включить плагин «по-настоящему» без окна можно временным EditorPlugin, который в headless-редакторе дожидается конца сканирования файлов, вызывает `EditorInterface.set_plugin_enabled()` и затем `ProjectSettings.save()`: без `save()` изменения остаются только в памяти (проверено на 4.7.2). Готовая реализация — в `scripts/addon_smoke.sh`.
- Многие аддоны лежат в репозитории не одной папкой: Maaack Game Template требует соседних `addons/maaacks_*` и `plugin_updater`, netfox — `netfox.internals`. Копируйте весь каталог `addons/` из релиза, а не только «главную» папку.
- Но не копируйте тест-фреймворки, которые лежат в репозитории аддона для его собственных тестов: в State Charts и SmartShape2D это старый GUT, в G.U.I.D.E и Beehave — gdUnit4, в netfox — vest. Старый GUT не компилируется на 4.5+ (`The member "Logger" shadows a native class`), а старый gdUnit4 — на 4.7 (проверено на 4.7.2). Тест-фреймворк проекта ставьте отдельно, нужной версии.
- Структура репозиториев разная: у Cyclops аддон лежит в `godot/addons/`, у YATI есть варианты `GDScript/` и `CSharp/` с одинаковым именем папки, у LimboConsole аддон — сам корень репозитория.
- Релизы на GitHub часто отстают от `main` (netfox: релиз 1.35.3, в `main` 1.49.4; SoundManager: релиз 2024, README «4.6+»). Сверяйте `plugin.cfg` и Asset Store.
- Переезды 2025–2026: GodotSteam, COGITO, ProtonScatter, Discord RPC — на Codeberg; Resonate — на GitLab; SilentWolf закрыт. Ссылки на GitHub в старых статьях ведут в архив или в никуда.
- Перед установкой: `GODOT=godot scripts/addon_smoke.sh <git-url>[@тег]` — чистый проект, включённый плагин, автозагрузки из `_enable_plugin()`, компиляция всех скриптов аддона.

**Что уже встроено в движок**

| Возможность | С версии | Что заменяет |
|---|---|---|
| Jolt Physics для 3D (с 4.6 — в новых проектах по умолчанию) | 4.4 | Аддон godot-jolt; на 4.7 он не нужен `[устарело]` |
| IK: `IKModifier3D` с семью солверами, `SpringBoneSimulator3D`, `BoneConstraint3D`, `RetargetModifier3D` | 4.4–4.6 | many_bone_ik, JiggleBones, сторонний IK |
| `VirtualJoystick` | 4.7 | Virtual-Joystick-Godot и подобные |
| AccessKit (экранные дикторы для Control) | 4.5 | godot-accessibility (Godot 3) |
| `AudioStreamInteractive`, `AudioStreamPlaylist`, `AudioStreamSynchronized` | 4.3 | Godot-Mixing-Desk, часть музыкальных менеджеров |
| `Logger` + `OS.add_logger()` | 4.5 | Многие логгеры; перехват ошибок для краш-репортов |
| `@export_tool_button`, `@export_group`, `_validate_property()` | 4.4 | Inspector Extender |
| Вкладка Game: выбор узлов в запущенной игре | 4.4 | Runtime Debug Tools |
| Minimal Theme — тема редактора по умолчанию | 4.6 | Godot Minimal Theme |
| Tracy, Perfetto, Instruments в своей сборке движка | 4.6 | GodotTracy, godot_tracy |
| Убершейдеры и прекомпиляция пайплайнов; shader baker при экспорте | 4.4 / 4.5 | «Прогрев шейдеров» |
| Stencil в `BaseMaterial3D` (Outline, X-Ray) | 4.5 | Простые outline-аддоны |
| `Parallax2D`, импорт FBX через ufbx, импорт `.blend` | 4.3 / 4.3 / 4.0 | ParallaxBackground, FBX2glTF, экспорт из Blender вручную |
| `Tween.tween_await()`, `AreaLight3D`, 2D Scene Paint, редактор MeshLibrary | 4.7 | Часть tween-библиотек, россыпи OmniLight, простые 2D-скаттеры |
| `RandomNumberGenerator.rand_weighted()` | 4.3 | Lootie и таблицы лута по весам |
| `JSON.from_native()` / `to_native()` | 4.4 | Часть сериализаторов (без объектов) |
| POT-генерация, псевдолокализация, CSV и gettext | 4.0+ | Простые i18n-аддоны |
| `MultiplayerSpawner`, `MultiplayerSynchronizer`, ENet/WebSocket/WebRTC peers, `HTTPRequest` | 4.0 | HTTP-менеджеры, обёртки над сокетами |

**Стартовые наборы по типу проекта** (всё ниже — активные аддоны; подробности в разделах)

| Проект | Набор |
|---|---|
| Любой | Maaack Game Template или Menus Template (меню, настройки, загрузчик); LimboConsole; Godot Doctor; sentry-godot в релизе |
| 2D-платформер | Phantom Camera; SmartShape2D или Better Terrain/TileMapDual; Aseprite Wizard; godot-statecharts для игрока |
| 3D-экшен | Phantom Camera; Terrain3D + ProtonScatter; LimboAI; Debug Draw 3D; G.U.I.D.E |
| RPG и адвенчура | Dialogue Manager; Quest System; GLoot; Pandora или JSON со схемой; Safe Resource Loader для сейвов-ресурсов |
| Карточная или пошаговая | Card Framework (UI карт) + своя логика на Resources; Hexagon TileMapLayer для гексов; образец — Godot Open RPG |
| Онлайн-экшен | netfox + noray; GodotSteam или EOSG; Rapier с детерминизмом для rollback |
| Мобильная F2P | godot-sdk-integrations (Billing, Play Games); Poing AdMob; GA-SDK-GODOT; sentry-godot |

## 1. ИИ персонажей и машины состояний

**Ключевые выводы**
- Выбор по сложности: FSM на `enum` + `match` → иерархические состояния (godot-statecharts, HSM в LimboAI) → деревья поведения (LimboAI, Beehave) → GOAP (GdPlanningAI). Поддерживаемого utility AI нет: пишите скоринг на `Curve` в GDScript.
- LimboAI — выбор по умолчанию для серьёзного ИИ: BT и HSM в одном пакете, C++, отладчик, деревья в `.tres`. Версии жёстко привязаны к минорной версии Godot: GDExtension 1.8.x — 4.6+, модуль 1.8.x — 4.7. Beehave — чистый GDScript, проще встроить, медленнее на сотнях агентов.
- Steering из GDQuest устарел: используйте `NavigationAgent2D/3D` с RVO-avoidance ([physics-navigation.md](physics-navigation.md)).

| Аддон | Версия (дата) · Godot | Что даёт и когда брать | Агент | 4.7.2 | Оговорки |
|---|---|---|---|---|---|
| [LimboAI](https://github.com/limbonaut/limboai) | v1.8.1 (20.8.2026) · GDExtension 4.6+, модуль 4.7 | BT + HSM, визуальный редактор и отладчик BT, blackboard, задачи на GDScript или C#; ~3,1 тыс. ★ | текст: BT — `.tres`, задачи — `.gd` | ✓ GDExtension-сборка «4.6» грузится в 4.7.2 | Нативные бинарники; при обновлении Godot обновляйте и аддон |
| [Beehave](https://github.com/bitbrain/beehave) | v2.9.3 (18.8.2026) · 4.5+ | BT из узлов сцены, blackboard, отладчик; ~3,3 тыс. ★ | текст: дерево — узлы в `.tscn`; свои тесты на gdUnit4 | ✓ | Узел на каждый шаг дерева — накладно при сотнях агентов; HSM нет |
| [godot-statecharts](https://github.com/derkork/godot-statecharts) | v0.22.5 (26.6.2026) · 4.0+ | Statecharts по Харелу: вложенные и параллельные состояния, история, guard, отложенные переходы, отладчик; ~1,6 тыс. ★ | текст: узлы в `.tscn`, `send_event("name")`; тесты на GUT | ✓ | События — строки: опечатка молча ничего не делает |
| [BehaviourToolkit](https://github.com/ThePat02/BehaviourToolkit) | 2.0.4 (9.2025) · 4.3+ | Лёгкие BT и FSM на узлах, совместимые друг с другом | текст | — | Сообщество меньше |
| [GdPlanningAI](https://github.com/WahahaYes/GdPlanningAI) | v0.2.0 (12.2025) · `[не проверено]` | GOAP: агенты строят цепочки действий в рантайме | текст: действия — `.gd`, конфиги — `.tres` | — | 0.x, один автор; GOAP сложнее отлаживать, чем BT |
| [gd-YAFSM](https://github.com/imjp94/gd-YAFSM) | 0.6.3 (11.2025) · 4.x | Визуальный граф FSM в стиле AnimationTree | GUI | — | Низкая активность |
| [Chickensoft LogicBlocks](https://github.com/chickensoft-games/LogicBlocks) | 6.2.2 (5.10.2026) · .NET | Иерархические машины состояний на C#, генерация диаграмм | текст: обычный C#, тесты без движка | — | Только C# |
| Utility AI (JarkkoPar, Pennycook), GDQuest Steering AI, godot-goap, GodotBT, Machina | 2020–2025 | — | — | — | `[устарело]` → скоринг на `Curve`, встроенная навигация, GdPlanningAI, Beehave, statecharts |

## 2. Камера и контроллеры персонажа

**Ключевые выводы**
- Phantom Camera закрывает почти все задачи камеры, включая тряску (`PhantomCameraNoiseEmitter`); отдельные shake-аддоны не нужны.
- Готового поддерживаемого «platformer kit» нет: для 2D-платформера хватает `CharacterBody2D` и правил из [domains.md](domains.md#1-2d-игры).

| Аддон | Версия (дата) · Godot | Что даёт и когда брать | Агент | 4.7.2 | Оговорки |
|---|---|---|---|---|---|
| [Phantom Camera](https://github.com/ramokz/phantom-camera) | v0.11.0.3 (19.7.2026) · 4.4+ | Камеры 2D/3D в духе Cinemachine: приоритеты, follow и look-at (group, path, framed, third-person), tween-переходы, шум; ~3,6 тыс. ★ | текст: узлы и `.tres`; API на GDScript и C# | ✓ | 0.x: API меняется между минорами |
| [expressobits/character-controller](https://github.com/expressobits/character-controller) | 2.2.0 (3.2025), коммиты 2026 · 4.1+ | Модульный FPS-контроллер со «способностями»: присед, спринт, плавание, полёт | текст | — | Релизы редкие |
| [Jeh3no Advanced FPC](https://github.com/Jeh3no/Godot-Advanced-State-Machine-First-Person-Controller) | AssetLib 3.6 (6.2026) · 4.4+ | FPS-контроллер на FSM, каждое состояние — отдельный `.gd` | текст | — | Релизы только в Asset Library |
| [GDQuest 3D TPS controller](https://github.com/gdquest-demos/godot-4-3d-third-person-controller) | демо, коммиты 2026 · 4.x | Образец контроллера от третьего лица | текст | — | Демо, а не аддон; лицензию ассетов проверьте отдельно |
| [Brackeys Proto Controller](https://github.com/Brackeys/brackeys-proto-controller) | 1.2025 · 4.x | Минимальный FPS в одном скрипте, CC0 | текст | — | Формально `[устарело]`, но тривиален |
| godot-FirstPersonStarter, PlatformerController2D | 2022–2024 | — | — | — | `[устарело]` |

## 3. Диалоги, нарратив, квесты

**Ключевые выводы**
- Для агента лучший формат — текстовый сценарий: Dialogue Manager (`.dialogue`), Yarn (`.yarn`), ink (`.ink`), Clyde (`.clyde`). Его можно писать, ревьюить и диффать как код. Граф-редакторы диалогов и квестов агенту неудобны.
- Dialogic 2 всё ещё alpha после нескольких лет: API и формат сохранений ломаются между альфами. Берите его, если нужна визуальная новелла и сценарист работает в редакторе.
- Подробнее про выбор и локализацию диалогов — в [domains.md](domains.md#7-диалоги-нарратив-и-локализация).

| Аддон | Версия (дата) · Godot | Что даёт и когда брать | Агент | 4.7.2 | Оговорки |
|---|---|---|---|---|---|
| [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) | v4.1.0 (4.9.2026) · v4: 4.6+ | Stateless-диалоги в `.dialogue`: ветвления, условия, мутации, переменные, переводы; ~3,9 тыс. ★. Выбор по умолчанию | текст; есть тесты и документация | ✓ | Миграция v3 → v4 описана в `docs/Upgrading_Version.md` |
| [Dialogic 2](https://github.com/dialogic-godot/dialogic) | 2.0-alpha-20 (21.7.2026) · 4.5+ | Визуальные новеллы: таймлайны, портреты, стили, переменные, save/load; ~6,1 тыс. ★ | текст (`.dtl`, `.dch`), но работа заточена под редактор | ✓ | Alpha; тяжёлый пакет |
| [Yarn Spinner for Godot](https://github.com/YarnSpinnerTool/YarnSpinner-Godot) | v0.3.23 (6.10.2026) · .NET | Официальная интеграция Yarn | текст | — | Только C#; по README — WIP без официальной поддержки |
| [GodotInk](https://github.com/paulloz/godot-ink) | v1.1.2 (2024), коммиты 2026 · .NET | ink: `.ink` компилируется при импорте | текст | — | Только C#. inkgd (GDScript) `[устарело]` |
| [Clyde Dialogue](https://github.com/viniciusgerevini/godot-clyde-dialogue) | v7.0.1 (5.2026) · 4.4+ | Компактный язык диалогов в духе ink | текст; тесты на GUT | — | Небольшое сообщество |
| [Dialogue Engine](https://github.com/Rubonnek/dialogue-engine) | v1.6.0 (2.2026) · 4.2+ | Граф диалога строится кодом, без редактора | текст: всё в `.gd` | — | Отображение пишете сами |
| [Quest System](https://github.com/shomykohai/quest-system) | 2.0.2 (8.2026) · 4.4+ | Квесты как ресурсы, автозагрузка `QuestSystem`, пулы, сериализация | текст; тесты на gdUnit4 | ✓ | — |
| [Questify](https://github.com/TheWalruzz/godot-questify) | 1.6.0 (7.2025) · 4.4+ | Граф-редактор квестов | GUI | — | Нужен визуальный граф — тогда он |
| [Popochiu](https://github.com/carenalgas/popochiu) | v2.2.0 (27.9.2026) · 4.6 `[не проверено]` для 2.2 | Фреймворк point-and-click: комнаты, персонажи, инвентарь, диалоги | API, много генерируемых сцен | — | Ниша |
| Dialogue Nodes, Sprouty Dialogs | 2026 · 4.5–4.6 | Граф-редакторы диалогов | GUI | — | Сценаристу удобнее граф — тогда они |
| inkgd, EZ Dialogue, MadTalk, Rakugo | 2023–2025 | — | — | — | `[устарело]` → Dialogue Manager, GodotInk |

## 4. Ввод

**Ключевые выводы**
- Простой проект: стандартный `InputMap` ([ui-input.md](ui-input.md)) + Controller Icons для подсказок. Сложный (контексты «пешком/машина/меню», комбо, ремаппинг): G.U.I.D.E, аналог Enhanced Input из Unreal.
- G.U.I.D.E заменяет парадигму `InputMap`: смешивать подходы нужно аккуратно.

| Аддон | Версия (дата) · Godot | Что даёт и когда брать | Агент | 4.7.2 | Оговорки |
|---|---|---|---|---|---|
| [G.U.I.D.E](https://github.com/godotneers/G.U.I.D.E) | v0.14.0 (14.7.2026) · 4.2+ | Mapping contexts с приоритетами, модификаторы, триггеры (hold, tap, chord), ремаппинг, иконки | текст: `.tres` с глубокой вложенностью; тесты на gdUnit4 | ✓ | 0.x |
| [Controller Icons](https://github.com/rsubtil/controller_icons) | v3.1.8 (28.7.2026) · 4.1.2+ | Иконки клавиш и геймпадов (Xbox, PS, Switch, Deck), переключаются при смене устройства | текст: путь или action строкой в `.tscn` | ✓ | Добавляет autoload и много текстур; для C# есть форк |
| [Input Helper](https://github.com/nathanhoad/godot_input_helper) | v4.7.0 (6.2025) · 4.x | Определение устройства, сигнал смены, сохранение ремапа, вибрация | API | ✓ | Формально `[устарело]` (16 мес.), но маленький и стабильный |
| [Maaack's Input Remapping](https://github.com/Maaack/Godot-Input-Remapping) | v1.6.0 (1.9.2026) · 4.7 | Готовое меню ремаппинга с иконками | текст | — | Часть экосистемы Maaack |
| [KoBeWi/Godot-Input-Remap](https://github.com/KoBeWi/Godot-Input-Remap) | 5.2026 · 4.x | Ресурс для хранения пользовательского маппинга | текст | — | — |
| Godot Input Prompts, Virtual-Joystick-Godot | 2024–2025 | — | — | — | `[устарело]` → Controller Icons; встроенный `VirtualJoystick` (4.7) |

## 5. Инвентарь, RPG-данные, способности

| Аддон | Версия (дата) · Godot | Что даёт и когда брать | Агент | 4.7.2 | Оговорки |
|---|---|---|---|---|---|
| [GLoot](https://github.com/peter-kish/gloot) | v3.0.2 (5.7.2026) · 4.4+ | Универсальный инвентарь: прототипы, ограничения (сетка, вес, стек), слоты, UI-контролы, сериализация | текст: прототипы в JSON | ✓ | v2 → v3 ломает совместимость |
| [expressobits/inventory-system](https://github.com/expressobits/inventory-system) | 2.13.0 (3.2026) · 4.4 | Инвентарь, крафт, хотбар, экипировка, пример мультиплеера | API: база в `.tres`, ядро GDExtension | — | Нативные бинарники; темп снизился |
| [Pandora](https://github.com/bitbrain/pandora) | v1.0-alpha10 (27.7.2026) · 4.x | Редактор RPG-данных: сущности и категории с наследованием свойств | текст: один JSON `data.pandora` с внутренними ID — правьте через API или проверяйте загрузкой | — | Alpha |
| [GodotGAS](https://github.com/yulrun/godot-gas) | v1.1.2 (2.10.2026) · 4.6+ | Порт Gameplay Ability System из UE: теги, эффекты и стеки, cues, генератор AttributeSet | текст: эффекты в `.tres` | ✓ ядро; демо не компилируются, пока панель аддона не сгенерирует теги | Молодой, один автор; лицензия во вложенной папке. В репозитории нет `addons/`: кладите папку `GodotGAS/` в `addons/GodotGAS/` — код ссылается на `res://addons/GodotGAS/` |
| [Wyvernbox](https://github.com/don-tnowe/godot-wyvernbox-inventory) | 1.3.14 (6.2025), коммиты 2026 · 4.0+ | Инвентарь ARPG: генераторы предметов, лут, магазины | текст | — | — |
| Godot Gameplay Systems, Lootie | 2024–2025 | — | — | — | `[устарело]` → GodotGAS; `rand_weighted()` |

## 6. Сохранения и данные

**Ключевые выводы**
- Сейвы храните в JSON или `ConfigFile`, а не в `.tres`: загрузка `.tres` из `user://` может выполнить встроенный в ресурс скрипт. Если сейвы всё же ресурсы — только через Safe Resource Loader. Подробнее в [architecture.md](architecture.md).
- Данные (предметы, карты, баланс) держите в тексте со схемой: агент генерирует их, а схема ловит ошибки в CI.

| Аддон | Версия (дата) · Godot | Что даёт и когда брать | Агент | 4.7.2 | Оговорки |
|---|---|---|---|---|---|
| [Safe Resource Loader](https://github.com/derkork/godot-safe-resource-loader) | v0.3.0 (6.2025), коммиты 2026 · 4.0+ | Перед загрузкой `.tres` ищет встроенный GDScript и блокирует загрузку | API: замена `ResourceLoader.load()`; тесты на gdUnit4 | ✓ | Только текстовые `.tres`; автор сам признаёт, что чёрный список можно обойти |
| [godot-sqlite](https://github.com/2shady4u/godot-sqlite) | v4.9 (9.8.2026) · 4.x | SQLite: запросы, транзакции, экспорт и импорт JSON | API: БД бинарная, но выгружается в JSON для диффа | ✓ GDExtension грузится | GDExtension; с v4.9 публикуется только в Asset Store; Web ограничен |
| [ForgeJSONGD](https://github.com/EiTaNBaRiBoA/ForgeJSONGD) | 5.0.0 (29.9.2026) · 4.5 | Сериализация объектов в JSON с типами Godot, шифрование, diff и patch | текст | — | Мажорные версии меняются часто |
| [gdschema](https://github.com/fimbul-works/gdschema) | v2.0.1 (16.8.2026) · 4.3+ | JSON Schema Draft 2020-12 | текст: проверка данных в тестах и CI | — | Мало звёзд, но аналогов нет |
| [godot-yaml](https://github.com/fimbul-works/godot-yaml) | v2.2.1 (16.8.2026) · 4.3+ | Быстрый YAML ⇄ Variant | текст | — | GDExtension |
| [Text Database](https://github.com/KoBeWi/Godot-Text-Database) | 1.3 (2024), коммиты 2026 · 4.0+ | Данные из JSON или `.cfg` с валидацией по схеме: обязательные поля, типы, значения по умолчанию | текст | ✓ | — |
| [Locker](https://github.com/locker-godot/locker) | v1.1.2 (4.2025), коммиты 2026 · 4.3+ | Сохранения со слотами и стратегиями хранения (JSON, шифрование) | текст | — | Маленькое сообщество |
| [Game State Saver](https://github.com/jhlothamer/godot_game_state_saver_plugin) | 6.2026 · 4.7+ | Сохраняет состояние сцен по группам между переходами | API | — | Маленький проект |
| Save Made Easy, Godot Object Serializer, Ref Serializer | 2024–2025 | — | — | — | `[устарело]` → ForgeJSONGD, `JSON.from_native()` |

## 7. Архитектура: сцены, ECS, DI, juice

**Ключевые выводы**
- Шина событий в Godot — это автозагрузка с сигналами, аддон не нужен. DI в GDScript обычно заменяют `@export` и автозагрузки; на C# есть Chickensoft AutoInject. Подробнее в [architecture.md](architecture.md).
- Пул объектов нужен реже, чем кажется: сначала профилируйте ([performance.md](performance.md)). Живых популярных pool-аддонов нет.
- ECS имеет смысл при тысячах однотипных сущностей с простой логикой. GECS — активный вариант на GDScript.

| Аддон | Версия (дата) · Godot | Что даёт и когда брать | Агент | 4.7.2 | Оговорки |
|---|---|---|---|---|---|
| [Scene Manager (glass-brick)](https://github.com/glass-brick/Scene-Manager) | v2.1.0 (20.8.2026) · 4.4 | Смена сцен с fade и шейдерными переходами | API; тесты на GUT | ✓ | Лицензия MIT во вложенной `addons/scene_manager/LICENSE` (проверено через GitHub API), GitHub её не распознаёт |
| [Maaack Scene Loader](https://github.com/Maaack/Godot-Scene-Loader) | v1.7.0 (9.9.2026) · 4.4+ | Асинхронная загрузка через `load_threaded_*`, экран загрузки | текст | — | Входит в Maaack Game Template |
| [Universal Transition Shader](https://github.com/cashew-olddew/Universal-Transition-Shader) | v17 (3.2026) · 4.4 | Один шейдер с десятками переходов, CC0 | текст: `.gdshader` | — | — |
| [GECS](https://github.com/csprance/gecs) | v9.3.4 (19.9.2026) · 4.6+ | ECS: компоненты-ресурсы, системы, query builder, отношения; ~610 ★ | текст; большой набор тестов на gdUnit4 | ✓ ядро; папка `tests/` внутри аддона требует gdUnit4 | Мажорные версии выходят часто. В `addons/` репозитория лежат ещё debug_menu, plugin-refresher и stack_trace_copier — копируйте только `gecs/` |
| [godot-ecs (godothub)](https://github.com/godothub/godot-ecs) | 3.1.0 (1.2026) · 4.5 | Лёгкий ECS | текст | — | Документация частично на китайском |
| [Chickensoft AutoInject](https://github.com/chickensoft-games/AutoInject) | 2.14.11 (14.10.2026) · .NET | DI по дереву узлов без рефлексии | текст | — | Только C# |
| [TweenFX](https://github.com/EvilBunnyMan/TweenFX) | v1.2.0 (3.2026) · 4.0+ | Готовые «сочные» твины: pop, shake, bounce одной строкой | текст | — | — |
| [Juicee](https://github.com/Kelpekk/Juicee) | v2.0.0 (13.10.2026) · 4.3+ | Game feel в стиле FEEL (Unity) с граф-редактором | GUI | — | v2 только вышла |
| [Tween Suite](https://github.com/KoBeWi/Godot-Tween-Suite) | 7.2026 · 4.x | Твины как ресурсы с редактором | текст | — | — |
| [Comedot](https://github.com/InvadingOctopus/comedot) | 8.2026 · 4.8+ | Компонентный фреймворк 2D-игр | текст | ✗ требует 4.8; это шаблон-проект, а не аддон | Требует Godot 4.8 |
| Godex, Shaker, godot-object-pool, maktoobgar scene_manager | 2017–2024 | — | — | — | `[устарело]` → GECS, Phantom Camera noise, свой пул, glass-brick Scene Manager |

## 8. Физика и движение

**Ключевые выводы**
- 3D: встроенный Jolt (с 4.6 по умолчанию в новых проектах). Аддон godot-jolt на 4.7 не нужен; он поддерживает только 4.3–4.6 и уйдёт в архив. Подробно в [physics-navigation.md](physics-navigation.md).
- Встроенная физика не детерминирована между машинами. Для rollback-неткода и реплеев — Rapier в детерминированной сборке.

| Аддон | Версия (дата) · Godot | Что даёт и когда брать | Агент | 4.7.2 | Оговорки |
|---|---|---|---|---|---|
| [Godot Rapier Physics](https://github.com/appsinacup/godot-rapier-physics) | v0.36.0 (2.10.2026) · 4.7 | Физический сервер Rapier для 2D и 3D: стабильность, кроссплатформенный детерминизм (отдельная сборка), сериализация состояния, 2D-жидкости | API: включается одной настройкой проекта | ✓ сборка 3d-single грузится | Паритет с GodotPhysics неполный; нумерация версий на GitHub и в Store разная |
| [erincatto/godot-box2d](https://github.com/erincatto/godot-box2d) | 9.2026, релизов нет · 4.3+ | Сервер Box2D v3 для 2D | API | — | Мало звёзд, есть ограничения. Pizzaandy/godot-box2d-v3 автор пометил как неподдерживаемый |
| [SmartShape2D](https://github.com/SirRamEsq/SmartShape2D) | 3.3.2 (7.8.2026) · 4.3+ | 2D-рельеф из кривых: текстуры краёв по углам, заливка, коллизии | текст: точки в `.tscn`; тесты на GUT | ✓ | — |
| [Ropesim](https://github.com/mphe/GDNative-Ropesim) | v1.9.1 (9.8.2026) · 4.3+ | 2D-верёвки на Verlet | API | — | GDExtension |
| [Halyard](https://github.com/mikest/halyard) | v0.9.6 (9.2025), коммиты 2026 · 4.5+ | 3D-верёвки и цепи, плавучесть | API | — | GDExtension, 0.x |
| [MAdvanced Vehicle Controller](https://github.com/Dente222/MAdvanced-Vehicle-Controller) | 1.2.4 (6.2026) · 4.6 | Машина с расширенной физикой | текст | — | Маленький проект; для простых случаев хватит `VehicleBody3D` |
| godot-jolt, appsinacup/godot-box2d, Easy Vehicle Physics, godot-verlet-rope, destruction-plugin | 2023–2026 | — | — | — | `[устарело]` → встроенный Jolt, Rapier, Box2D v3, Halyard, VoronoiShatter ([addons-content.md](addons-content.md#5-vfx-частицы-разрушение)) |

## 9. Процедурная генерация и мир

**Ключевые выводы**
- Шум — встроенные `FastNoiseLite` и `NoiseTexture2D/3D`. Поддерживаемого генератора подземелий нет: пишите BSP или random walk по [демо GDQuest](https://github.com/gdquest-demos/godot-4-procedural-generation).
- Террейны, скаттеры и тайловые инструменты, работающие в редакторе, описаны в [addons-content.md](addons-content.md#3-левел-дизайн-и-контент-уровней).

| Аддон | Версия (дата) · Godot | Что даёт и когда брать | Агент | 4.7.2 | Оговорки |
|---|---|---|---|---|---|
| [Gaea](https://github.com/gaea-godot/gaea) | 1.4.1 (4.2025); 2.0.0-beta6 (3.2026) · 2.0: 4.6 | Генерация на графе: шум, клеточные автоматы, walkers → `TileMapLayer`/`GridMap`, чанки | GUI в 2.0 (граф в громоздком `.tres`), API `GaeaGraph` | ✓ | 2.0 — beta с ломающими изменениями, 1.x устарела по Godot |
| [Voxel Tools](https://github.com/Zylann/godot_voxel) | v1.7 (20.8.2026) · 4.7 | Воксельные миры: блоки и Transvoxel, LOD, стриминг, генераторы, правка в игре | API: генераторы графом или скриптом | — | Модульная версия требует своей сборки движка |
| [godot-constraint-solving](https://github.com/AlexeyBond/godot-constraint-solving) | 1.7 (2024), коммиты 5.2025 · 4.3 | WFC для 2D и 3D, обучение на примерах, многопоточность | текст; тесты на GUT | — | `[устарело]` по дате; поддержка `TileMapLayer` `[не проверено]` |
| [Terrainy](https://github.com/sempitern0/Terrainy) | 1.5.0 (11.2025) · 4.5 | Меш террейна по шуму | API | — | — |

## 10. Карточные, пошаговые и сеточные игры

**Ключевые выводы**
- Аддоны закрывают UI и перемещение карт, а правила и эффекты пишутся самим проектом. Архитектура «логика на Resources и чистых классах, сцены — только представление» описана в [domains.md](domains.md#4-пошаговые-карточные-настольные-и-стратегические-игры).
- Живых универсальных аддонов пошагового боя нет: образец — Godot Open RPG (требует 4.7.2+).

| Аддон | Версия (дата) · Godot | Что даёт и когда брать | Агент | 4.7.2 | Оговорки |
|---|---|---|---|---|---|
| [Card Framework](https://github.com/chun92/card-framework) | v1.4.0 (8.5.2026) · 4.6+ | `CardManager`, стопки и руки, drag-and-drop, анимации; примеры Solitaire и FreeCell | текст: карты в JSON | ✓ | Только представление карт |
| [Slay-The-Robot](https://github.com/DesirePathGames/Slay-The-Robot) | 6.2026 · 4.6 | Фреймворк roguelike-декбилдера: карты, враги, артефакты, карта забега, моддинг-API | текст: всё в JSON | — | Проект-фреймворк, его адаптируют |
| [Hexagon TileMapLayer](https://github.com/Zehir/godot-hexagon-tile-map-layer) | v2.5.2 (11.2025) · 4.4+ | Кубические координаты, A*, конвертация для гекс-`TileMapLayer` | API | — | — |
| [godot-hex-map](https://github.com/dmlary/godot-hex-map) | v0.2.0 (7.2025) · `[не проверено]` | `HexMap` — аналог `GridMap` для 3D-гексов | API | — | GDExtension, 0.x |
| [Godot Open RPG](https://github.com/gdquest-demos/godot-open-rpg) | 0.4.0, коммиты 13.10.2026 · 4.7.2+ | Эталонная JRPG: пошаговый бой, карта, диалоги | текст | — | Демо, а не аддон |
| db0 Godot Card Game Framework, simple-card-pile-ui, godot-hexgrid | 2022–2024 | — | — | — | `[устарело]`; db0 — только Godot 3 и AGPL |

## 11. UI

**Ключевые выводы**
- Каркас меню, настроек, паузы и загрузки — Maaack Game Template (обновлён под 4.7). Зрелых toast- и dialog-аддонов нет: всплывающее уведомление пишется за 30 строк на `Tween` и контейнере.
- Тему, которую правит агент, держите как код: ThemeGen генерирует `Theme.tres` из GDScript, и диффы читаемы.
- Подробно про Control, контейнеры и темы — в [ui-input.md](ui-input.md).

| Аддон | Версия (дата) · Godot | Что даёт и когда брать | Агент | 4.7.2 | Оговорки |
|---|---|---|---|---|---|
| [Maaack's Game Template](https://github.com/Maaack/Godot-Game-Template) | v1.7.0 (9.9.2026) · 4.7 (совместим с 4.4+) | Главное меню, настройки (звук, видео, управление, доступность), пауза, титры, загрузчик сцен; ~1,7 тыс. ★ | текст; переименование и настройка — мастером в редакторе | ✓ | Нужны все соседние `addons/maaacks_*` и `plugin_updater` |
| [ThemeGen](https://github.com/Inspiaaa/ThemeGen) | v1.4.0 (2.5.2026) · 4.0+ | Тема как GDScript-код с переменными и наследованием стилей → `Theme.tres` | текст | ✓ | Генерация запускается `@tool`-скриптом в редакторе |
| [MarkdownLabel](https://github.com/daenvil/MarkdownLabel) | v1.4.0 (11.1.2026) · 4.2+ | RichTextLabel, который принимает Markdown: справка, патч-ноты, обучающие окна | текст | ✓ | Сложные эффекты всё равно через BBCode |
| [godot-flexbox](https://github.com/citizenll/godot-flexbox) | 2.0.1 (1.2025), коммиты 2026 · 4.0+ | Flexbox-контейнер на Yoga | API | — | GDExtension; обычно хватает `FlowContainer` и anchors |
| [Simple GUI Transitions](https://github.com/murikistudio/simple-gui-transitions) | v0.5.0 (1.2026) · 4.3 | Анимации появления и скрытия меню | текст | — | — |
| [Godot-SplashScreens](https://github.com/KenneyNL/Godot-SplashScreens) | 9.2025 | 70 сплэшей и логотипов «Made with Godot» | — | — | Ассеты, не аддон; файла LICENSE нет |
| gmui, godot-reactive-ui | 2025 | MVVM и data binding | — | — | Без лицензии; как образец паттерна «состояние в Resource, UI подписан на `changed`» |
| Virtual-Joystick-Godot, godot-accessibility, godot-theme-generator, godot-text_effects | 2021–2025 | — | — | — | `[устарело]` → встроенные `VirtualJoystick`, AccessKit; ThemeGen; свой `RichTextEffect` |

## 12. Звук

**Ключевые выводы**
- Встроенных шин, `AudioStreamInteractive` и плееров хватает большинству игр ([animation-audio.md](animation-audio.md)). Аддоны-менеджеры экономят время на пулах плееров и кроссфейдах.
- FMOD и Wwise нужны, если звукорежиссёр работает в их инструментах. Банки — бинарные и собираются в GUI, агент их не создаёт; лицензии бесплатны до порога выручки (точные условия `[не проверено]`).

| Аддон | Версия (дата) · Godot | Что даёт и когда брать | Агент | 4.7.2 | Оговорки |
|---|---|---|---|---|---|
| [SoundManager](https://github.com/nathanhoad/godot_sound_manager) | v2.6.2 (2024), коммиты 3.2026 · 4.6+ | Autoload: `play_sound`, `play_music` с кроссфейдом, `play_ui_sound`, пул плееров | текст: минимальный API | ✓ | Берите `main` или Asset Library |
| [Resonate](https://gitlab.com/widgitgaming/godot/resonate) | 2.4.1 (3.2026, GitLab) · 4.x | Пулы, банки звуков, музыка со стемами и кроссфейдом | API: банки в сценах | — | GitHub-репозиторий в архиве, новые версии на GitLab |
| [fmod-gdextension](https://github.com/utopia-rise/fmod-gdextension) | 6.1.0 (9.2025, сборка под 4.5), коммиты 6.2026 · 4.5+ | FMOD Studio: эмиттеры 2D/3D, банки, live update | GUI: FMOD Studio | — | Сборки под 4.7 нет, грузится сборка под 4.5 |
| [wwise-godot-integration](https://github.com/alessandrofama/wwise-godot-integration) | 2026.1.3 (25.9.2026) · 4.3+ | Wwise: события, RTPC, банки | GUI: Wwise Authoring | — | Тяжёлая зависимость, аккаунт Audiokinetic |
| [rhythm_notifier](https://github.com/michaelgundlach/rhythm_notifier) | 9.2025 · 4.x | Сигналы на долях и тактах с учётом задержки вывода | текст | ✓ | — |
| [godot-midi](https://github.com/nlaha/godot-midi) | 0.3.0 (3.7.2026) · 4.2+ | MIDI-чарты синхронно с `AudioStreamPlayer` | API | — | 0.x |
| godot-steam-audio, Godot-Mixing-Desk, fmod-for-godot, godot-sfxr | 2022–2025 | — | — | — | `[устарело]` или архив → встроенный `AudioStreamInteractive`, Resonate, jsfxr с экспортом в WAV |

## 13. Локализация

**Ключевые выводы**
- Встроенных CSV, gettext PO/POT, POT-генерации и псевдолокализации почти всегда достаточно ([ui-input.md](ui-input.md), [domains.md](domains.md#7-диалоги-нарратив-и-локализация)). PO удобнее переводчикам и сервисам (контекст, plural-формы).
- Crowdin, Weblate и Lokalise работают с PO и CSV напрямую; Godot-плагин не нужен. Токены их CLI держите в секретах CI.

| Аддон | Версия (дата) · Godot | Что даёт | Агент | 4.7.2 | Оговорки |
|---|---|---|---|---|---|
| [godot-localization-editor](https://github.com/EthanGrahn/godot-localization-editor) | v2.0.1-gd4.7 (7.7.2026) · 4.7 | Табличный редактор CSV-переводов в редакторе или отдельным приложением | агенту не нужен: CSV правится напрямую | — | Очень молодой проект |
| [LocGuard Lite](https://godotengine.org/asset-library/asset/5378) | Asset Library · 4.7 | Ищет ключи из кода и сцен, которых нет в CSV; по листингу работает headless | текст | — | `[не проверено]`: данные только из листинга |
| Localization Editor (VP-GAMES) | 2023 | — | — | — | `[устарело]` |

## 14. Сеть, мультиплеер, бэкенды

**Ключевые выводы**
- Высокоуровневый мультиплеер Godot ([signals-async-threads.md](signals-async-threads.md)) + netfox для тиков, rollback, предсказания и интерполяции — основной путь для экшен-мультиплеера в 2026 году.
- Бэкенды с локальным сервером (Nakama через docker-compose, Talo self-host, Colyseus через npm, noray в Docker) позволяют писать настоящие интеграционные тесты. Сервисы только в облаке (LootLocker, PlayFab) — нет.
- Секреты (EOS ClientSecret, ключи Talo, LootLocker, PlayFab, Firebase `.env`, private key Game Jolt) не коммитьте: подставляйте из окружения или CI. Публичны по природе: Sentry DSN, AdMob App ID, Discord Application ID, Supabase anon key.

| Аддон | Версия (дата) · Godot | Что даёт и когда брать | Агент | 4.7.2 | Оговорки |
|---|---|---|---|---|---|
| [netfox](https://github.com/foxssake/netfox) | `main` 1.49.4 (релиз на GitHub 1.35.3) · 4.x | Сетевые тики и время, rollback, предсказание, интерполяция, лобби, интеграция с noray и Rapier; ~1,1 тыс. ★ | текст; логику можно гонять несколькими headless-процессами | ✓ | Релизы на GitHub отстают от `main` |
| [noray](https://github.com/foxssake/noray) | 9.2026 | NAT punch-through и UDP-relay для P2P-хостинга | Docker и env | — | Сервер хостите сами |
| [GodotSteam](https://codeberg.org/godotsteam/godotsteam) | v4.23.1 (7.10.2026) · GDExtension 4.4+ | Steamworks: достижения, лобби, сеть, Workshop, Cloud; `SteamMultiplayerPeer` с 4.16 | API; нужен Steam-клиент и `steam_appid.txt` (480 для тестов) | — | GitHub-репозиторий заархивирован в октябре 2026, разработка на Codeberg. Не совмещайте с отдельным steam-multiplayer-peer |
| [Epic Online Services for Godot](https://github.com/3ddelano/epic-online-services-godot) | 2.3.1 (15.9.2026) · 4.2+ | EOS: аккаунты, лобби, P2P, достижения, лидерборды, античит; бесплатный relay | API; ключи вне репозитория | — | Нет Web |
| [nakama-godot](https://github.com/heroiclabs/nakama-godot) | v3.4.0 (2024), коммиты 9.2026 · 4.0+ | Клиент Nakama: аутентификация, хранилище, матчмейкинг, realtime, `NakamaMultiplayerBridge` | API; сервер локально через docker-compose | — | Релизы клиента редкие |
| [Talo](https://github.com/TaloDev/godot) | 1.2.0 (4.10.2026) · 4.7 | Open-source бэкенд: игроки, лидерборды, статы, облачные сейвы, live config, аналитика; self-host | API | ✓ | 1.0 вышла в августе 2026 |
| [Godot Rollback Netcode](https://gitlab.com/snopek-games/godot-rollback-netcode) | v1.0.0 (6.6.2026) · 4.6 | Детерминированный rollback в стиле GGPO, отладчик рассинхронов, реплеи | текст | — | Нужна детерминированная физика (Rapier) |
| [webrtc-native](https://github.com/godotengine/webrtc-native) | 1.2.2 (30.9.2026) · 4.1+ | WebRTC для десктопа и мобильных (на Web встроен) | API | — | Нужны signaling, STUN и TURN |
| [Colyseus native-sdk](https://github.com/colyseus/native-sdk) | godot-v0.18.4 (9.10.2026) · 4.x | Клиент Colyseus: комнаты и синхронизация схем | API; сервер локально через npm | — | Официально experimental |
| [GodotFirebase](https://github.com/GodotNuts/GodotFirebase) | v6.0.6 (5.2026) · 4.x | Firebase через REST: Auth, Firestore, RTDB, Storage, Functions | API | — | Нет нативных Analytics и Crashlytics |
| [LootLocker godot-sdk](https://github.com/lootlocker/godot-sdk) | v1.3.0 (4.2026) · 4.x | Логин, лидерборды, прогрессии, хранилище | API | — | Не все функции LootLocker |
| SilentWolf, NetworkSynchronizer, Supabase-аддон, HTTPManager, gsioteam/godot-colyseus | 2023–2025 | — | — | — | Закрыт или `[устарело]` → Talo, LootLocker, Nakama; netfox; `HTTPRequest`; Colyseus native-sdk |

## 15. Платформы, магазины, мобильные, Web, XR

**Ключевые выводы**
- Покупки, достижения и реклама на мобильных проверяются только на устройстве с аккаунтом магазина. Агент может собрать и сконфигурировать, но не проверить: оставляйте это человеку.
- Нативные плагины нужны под каждую платформу; плагинам Android нужен `gradle/use_gradle_build`. Подробно — в [project-export.md](project-export.md).

| Аддон | Версия (дата) · Godot | Что даёт | 4.7.2 | Оговорки |
|---|---|---|---|---|
| [godot-google-play-billing](https://github.com/godot-sdk-integrations/godot-google-play-billing) | 3.3.0 (27.7.2026) · 4.2+ | Google Play Billing: покупки и подписки | — | Официальная организация godot-sdk-integrations; серверную валидацию чеков делайте сами |
| [godot-play-game-services](https://github.com/godot-sdk-integrations/godot-play-game-services) | v3.4.0 (20.7.2026) · 4.3+ | Play Games: вход, достижения, лидерборды, сохранения | — | Нужны Play Console и SHA-1 |
| [godot-admob-plugin](https://github.com/poingstudios/godot-admob-plugin) | v5.1.0 (13.9.2026) · 4.5+ | AdMob: баннеры, interstitial, rewarded, UMP-согласие | — | Используйте тестовые ad unit ID |
| [GodotApplePlugins](https://github.com/migueldeicaza/GodotApplePlugins) | сборки 10.2026 · 4.x | GameCenter, StoreKit 2, Sign in with Apple на iOS и macOS | — | Нужен Xcode. Официальные godot-ios-plugins без релизов |
| [godot-mobile-plugins](https://github.com/godot-mobile-plugins) | 2026 · 4.x | In-app review, локальные уведомления, share, deeplink, OAuth2 с общим GDScript-API | — | Старые репозитории cengiz-pz/*-plugin в архиве |
| [WebBus](https://github.com/talkafk/WebBus) | 0.6.2 (10.2025) · 4.3 | Единый API для SDK CrazyGames, Yandex Games, Poki и VK | — | Работает только в браузере |
| [Poki SDK](https://github.com/vkbsb/godot-poki-sdk) | 1.0.1 (6.2026) · 4.3 | Пресет, HTML-шаблон и `PokiSDK` | — | Автор помечает как unstable |
| [discord-social-sdk](https://github.com/thiagola92/discord-social-sdk) | 5.0.0 (25.9.2026) · 4.4 | Discord Social SDK: Rich Presence, друзья, лобби, голос | — | Неофициальный; мажорные версии ломают API. Для простого Rich Presence — [DiscordGodot RPC-Legacy](https://codeberg.org/DiscordGodot/RPC-Legacy) |
| [godot-xr-tools](https://github.com/GodotVR/godot-xr-tools) | 4.5.2 (8.10.2026) · 4.2+ | Руки, захват, телепорт, UI в VR | ✓ тег 4.5.2; ✗ `main` (ошибка сигнатуры в `mouse_capture.gd`) | Без шлема тестируется частично |
| [godot_openxr_vendors](https://github.com/GodotVR/godot_openxr_vendors) | 5.1.0 (19.5.2026) · 4.x | Loader'ы и расширения Quest, Pico, Android XR | — | Две мажорные ветки — выбирайте по версии Godot |
| [godot-meta-toolkit](https://github.com/godot-sdk-integrations/godot-meta-toolkit) | 1.0.3 (7.2025), коммиты 2026 · 4.3+ | Meta Platform SDK: достижения, IAP | — | — |
| GodotSteam | см. раздел 14 | — | — | — |

## 16. Аналитика и краш-репорты

| Аддон | Версия (дата) · Godot | Что даёт | 4.7.2 | Оговорки |
|---|---|---|---|---|
| [sentry-godot](https://github.com/getsentry/sentry-godot) | 2.3.0 (29.9.2026) · 2.x: 4.5+ | Нативные краши, ошибки GDScript со стеком и локальными переменными, breadcrumbs, release health; Web поддерживается | — | Единственный зрелый краш-репортинг. DSN в `project.godot`; в редакторе и CI отправку отключайте |
| [GA-SDK-GODOT](https://github.com/GameAnalytics/GA-SDK-GODOT) | 3.1.2 (6.10.2026) · 4.5+ | Продуктовая аналитика: события, удержание, A/B | — | Официальный |
| [Talo](https://github.com/TaloDev/godot) | см. раздел 14 | События, статы, воронки, live config | ✓ | — |
| Quiver, Montecri/Godot-GameAnalytics, BugSplat.Godot | 2023–2026 | — | — | `[устарело]`; BugSplat — только C# и ранняя версия |

## 17. Чеклист перед добавлением аддона

1. Нет ли этого в движке (таблица в разделе 0) и не решается ли задача 30 строками своего кода?
2. Последний коммит моложе 12 месяцев; есть релиз или запись в Asset Store под вашу минорную версию Godot.
3. Лицензия совместима с проектом. GitHub не всегда видит файл LICENSE во вложенной папке; AGPL и GPL требуют открыть код игры; «некоммерческие» лицензии не подходят коммерческим проектам.
4. Для GDExtension есть бинарники под все целевые платформы, включая Web и мобильные.
5. Данные аддона хранятся в тексте, а API доступен из кода; если основная работа в графе или кистью, договоритесь, что эту часть делает человек.
6. `scripts/addon_smoke.sh <url>@<тег>` проходит на версии Godot проекта.
7. После установки: автозагрузки из `_enable_plugin()` есть в `project.godot`; чужой код исключён из предупреждений (`directory_rules`), форматтера (`-x addons`) и `check_scripts.sh`; отладочные аддоны исключены из релизного экспорта.
8. Версия закреплена (тег в `addons.json` или `plug.gd`, либо закоммиченный `addons/`), а в описании коммита указано, откуда и какая версия взята.

## 18. Ресурсы

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Godot Asset Store](https://store.godotengine.org/) | Godot Foundation, 2026 | Основной каталог аддонов с 4.7 |
| [Godot Asset Library](https://godotengine.org/asset-library/asset) | Godot Foundation | Старый каталог; часть аддонов есть только здесь |
| [awesome-godot](https://github.com/godotengine/awesome-godot) | сообщество, 2026 | Сводный список аддонов, шаблонов и инструментов |
| [Installing plugins](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/installing_plugins.html) | Godot docs, 2026 | Включение плагинов |
| [Making plugins](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/making_plugins.html) | Godot docs, 2026 | `_enable_plugin()`, `add_autoload_singleton()` и жизненный цикл плагина |
| [LimboAI docs](https://limboai.readthedocs.io/) | limbonaut, 2026 | BT и HSM, совместимость версий |
| [Phantom Camera docs](https://phantom-camera.dev/) | ramokz, 2026 | Режимы камер и переходы |
| [Dialogue Manager docs](https://github.com/nathanhoad/godot_dialogue_manager/tree/main/docs) | Nathan Hoad, 2026 | Синтаксис `.dialogue`, миграция на v4 |
| [netfox docs](https://foxssake.github.io/netfox/latest/) | Fox's Sake Studio, 2026 | Тики, rollback, интерполяция |
| [godotsteam.com](https://godotsteam.com/) | GodotSteam, 2026 | Документация Steamworks для Godot |

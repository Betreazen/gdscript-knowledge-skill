---
name: gdscript-knowledge
description: Knowledge base and workflow for working with the Godot 4 engine and GDScript — correct and optimized use of scenes, nodes and the scene tree, signals, resources and asset import, 2D/3D rendering, physics and navigation, UI and input, animation and audio, project settings and export. Covers 2D and 3D games, UI and non-game apps, card and turn-based games, AI, procedural generation, editor plugins, multiplayer, shaders, web and mobile, and C#/GDExtension (godot-rust) interop. Use when writing or reviewing GDScript, structuring scenes and nodes, choosing node types, configuring imports, renderers, physics bodies, containers, AnimationTree or audio buses, setting up exports, choosing Godot tooling (headless CLI, --check-only, GUT, gdUnit4, CI), profiling or optimizing Godot performance, or picking Godot books and courses. Includes curated docs and articles, engine behaviour verified on Godot 4.7.2, check and benchmark scripts, and a pipeline with benchmarks, review and evidence-based optimization.
---

# Godot 4 и GDScript: библиотека знаний и пайплайн

Скилл помогает правильно работать с движком Godot и писать, проверять и ускорять код на GDScript в любой области: игры, интерфейсы, инструменты редактора, приложения на Godot. Он охватывает не только язык, но и сам движок: как строить сцены и дерево узлов, какой узел выбрать, как настроить импорт, рендеринг, физику, UI, анимацию, звук и экспорт. Внутри три вещи:

1. **Библиотека знаний.** Документация, статьи, книги, курсы, доклады, открытые проекты и паттерны по категориям. Каждый источник дан со ссылкой, автором, годом и пояснением, зачем его читать. Поведение движка, отмеченное «проверено на 4.7.2», подтверждено запуском Godot.
2. **Тулчейн.** Какие инструменты ставить, какие команды запускать и в каком порядке. Агент работает из терминала, поэтому упор на headless-режим Godot.
3. **Пайплайн.** Порядок работы: тесты до кода, проверки качества, бенчмарки, ревью, поиск решений в библиотеке и повторный замер.

Состояние знаний — октябрь 2026: Godot 4.7.2 stable (4.7 вышел 18 июня 2026), ветка 4.8 в разработке.

## Куда смотреть

**Работа с движком**

| Задача | Файл |
| --- | --- |
| Жизненный цикл узла, `_ready` и `_enter_tree`, обработка кадров, пауза, группы, `owner`, инстанцирование, наследование сцен, выбор типа узла, удаление узлов | [references/scene-tree-nodes.md](references/scene-tree-nodes.md) |
| Структура проекта, композиция сцен, автозагрузки, Resources как данные, сохранения, моды, машины состояний, тестирование | [references/architecture.md](references/architecture.md) |
| Кэш и общие ресурсы, `load`/`preload`, `.tres`/`.res`, UID, импорт текстур, звука, 3D-сцен и шрифтов, бюджеты памяти | [references/resources-import.md](references/resources-import.md) |
| Выбор рендерера, порядок отрисовки и батчинг 2D, свет и тени, Viewport, камеры, GI, Environment, материалы, LOD, частицы, рывки шейдеров | [references/rendering.md](references/rendering.md) |
| Тип тела, `move_and_slide`, RigidBody, Area, слои и маски, формы, лучи, Jolt, навигация, AStarGrid2D | [references/physics-navigation.md](references/physics-navigation.md) |
| Control и контейнеры, темы, текст, порядок обработки ввода, `mouse_filter`, фокус, InputMap, разрешения и hiDPI, drag-and-drop, доступность | [references/ui-input.md](references/ui-input.md) |
| AnimationPlayer, AnimationTree, Tween, скелеты и IK, аудиошины, плееры, типы AudioStream, интерактивная музыка | [references/animation-audio.md](references/animation-audio.md) |
| Настройки проекта, feature tags, приёмы работы в редакторе, отладчик, пресеты и фильтры экспорта, особенности платформ, чеклист релиза | [references/project-export.md](references/project-export.md) |
| Особенности области: 2D, 3D, UI, карточные и пошаговые игры, ИИ, процедурка, диалоги, шейдеры, платформы, C# и GDExtension | [references/domains.md](references/domains.md) |

**Код и процесс**

| Задача | Файл |
| --- | --- |
| Новая фича, рефакторинг или оптимизация: порядок работы | [references/pipeline.md](references/pipeline.md) |
| Godot CLI, проверка скриптов, предупреждения, форматтер, тесты, CI, git | [references/toolchain.md](references/toolchain.md) |
| Игра тормозит: техника по симптому, профилирование, бенчмарки | [references/performance.md](references/performance.md) — начните с таблицы «Симптом → техника → источник» |
| Типизация, стиль, сигналы, `class_name`, аннотации, что нового в 4.x, паттерны, чеклист ревью кода | [references/idioms-patterns.md](references/idioms-patterns.md) |
| Сигналы, `await`, `call_deferred`, потоки, `WorkerThreadPool`, HTTP, мультиплеер и RPC | [references/signals-async-threads.md](references/signals-async-threads.md) |
| Книги, курсы, каналы, открытые проекты, маршрут обучения | [references/books.md](references/books.md) |

Каждый справочник начинается с оглавления. Читайте только нужный раздел, а не файл целиком.

Готовые скрипты, проверенные на Godot 4.7.2:

- [scripts/check_scripts.sh](scripts/check_scripts.sh) — прогоняет `--check-only` по всем `.gd` проекта;
- [scripts/bench.gd](scripts/bench.gd) — харнесс микробенчмарков с сохранением результатов в JSON;
- [scripts/bench_compare.gd](scripts/bench_compare.gd) — сравнение двух прогонов, код 1 при регрессии.

## Как работать

**Для задачи больше одной функции** идите по [пайплайну](references/pipeline.md):

1. Опрос.
2. План и спецификация.
3. Подзадачи.
4. Тесты до кода.
5. Изоляция в worktree.
6. Бенчмарки.
7. Базовый замер и профиль.
8. Ревью.
9. Поиск решений в библиотеке.
10. Оптимизация.
11. Повторный замер.

Для мелкой правки хватает короткого режима из того же файла: тест, код, проверки, ревью.

**Когда строите сцену или настраиваете систему движка**, сначала откройте справочник этой системы. Выбор узла, тела, контейнера, рендерера, режима сжатия или типа AudioStream делайте по таблицам решений в нём, а не по памяти: у многих узлов неочевидные значения по умолчанию, и часть советов времён Godot 3 больше не верна.

**Перед тем как объявить работу готовой**, прогоните минимальные проверки и покажите их вывод:

```bash
gdscript-formatter --check -x addons .
godot --headless --path . --import
GODOT=godot <путь к скиллу>/scripts/check_scripts.sh
mkdir -p reports && godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
```

`--check-only` ловит ошибки типов, только если в `project.godot` нужные предупреждения переведены в Error. Минимум — `untyped_declaration=2`, шаблон в [toolchain.md](references/toolchain.md). Если тесты на gdUnit4, используйте его `runtest.sh`. Если инструмент не установлен, скажите об этом и предложите команду установки из [toolchain.md](references/toolchain.md), а не пропускайте шаг молча.

Агент не видит игру. То, что нельзя проверить кодом (анимация, ощущение управления, вёрстка UI на разных разрешениях, качество картинки), явно передавайте человеку на ручную проверку со списком, что смотреть.

**При оптимизации:**

- Сначала замер, потом правка. Без базовой линии нельзя сказать, что код стал быстрее.
- Бинарник редактора — debug-сборка. Сравнивайте варианты одним и тем же бинарником, а абсолютные цифры берите из release-экспорта.
- Ищите технику по симптому в [performance.md](references/performance.md) и в справочнике нужной системы движка. Указывайте источник рядом с правкой.
- Принимайте правку, только если бенчмарк показал значимый выигрыш, а тесты остались зелёными.

**При ревью** используйте чеклисты:

- [idioms-patterns.md](references/idioms-patterns.md) — для любого кода;
- [scene-tree-nodes.md](references/scene-tree-nodes.md) — для структуры сцен и узлов;
- [signals-async-threads.md](references/signals-async-threads.md) — для `await`, потоков и сети;
- [architecture.md](references/architecture.md) — для связей между сценами и структуры проекта;
- чеклисты систем движка: [rendering.md](references/rendering.md), [physics-navigation.md](references/physics-navigation.md), [ui-input.md](references/ui-input.md), [animation-audio.md](references/animation-audio.md), [resources-import.md](references/resources-import.md);
- [project-export.md](references/project-export.md) — перед релизом.

## Правила использования библиотеки

- **Ссылайтесь на источник.** Рекомендуя паттерн, настройку или оптимизацию, давайте ссылку из справочника. Тогда пользователь может проверить совет, а решение не выглядит выдуманным.
- **Учитывайте пометки.** `[устарело]` значит, что у материала есть замена, и она указана рядом. Особенно часто так помечены советы и синтаксис Godot 3 (`yield`, `export var`, `KinematicBody`, `TileMap`). `[не проверено]` значит, что утверждение взято из одного вторичного источника; его стоит перепроверить, прежде чем строить на нём решение. «Проверено на 4.7.2» значит, что поведение подтверждено запуском движка.
- **Проверяйте версию Godot.** Версии движка и аддонов указаны на октябрь 2026. Уточните версию проекта в `project.godot` (`config/features`), прежде чем советовать возможности, появившиеся в 4.4–4.7. Сверяйтесь с документацией нужной версии и release notes.
- **Отличайте значения движка от значений шаблона проекта.** Project Manager записывает в новый проект настройки, которых нет у движка по умолчанию: Jolt для 3D-физики, растяжение `canvas_items`, D3D12 на Windows. Смотрите, что на самом деле записано в `project.godot`.
- **Говорите о пробелах прямо.** Если в библиотеке нет ответа, так и скажите, а затем ищите в официальной документации. Не выдавайте догадку за материал библиотеки.
- **Следуйте соглашениям проекта.** Если в проекте уже приняты стиль, аддоны или архитектура, советы библиотеки применяются в их рамках, а не поверх.

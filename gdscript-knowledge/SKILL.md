---
name: gdscript-knowledge
description: Knowledge base and workflow for writing, reviewing and optimizing GDScript in Godot 4 — 2D and 3D games, UI and non-game apps, turn-based and card games, AI and navigation, procedural generation, editor plugins and @tool scripts, multiplayer, shaders, web and mobile export, and interop with C# and GDExtension (godot-cpp, godot-rust). Use when writing or reviewing GDScript, structuring scenes, autoloads, signals and resources, choosing Godot tooling (headless CLI, --check-only, GDScript Formatter, gdtoolkit, GUT, gdUnit4, CI), benchmarking, profiling or optimizing Godot performance, working with await, threads or networking, or picking Godot books, courses and open-source projects. Includes a curated library of docs, articles and patterns with links, a toolchain guide, ready benchmark and check scripts, and a development pipeline with benchmarks, code review and evidence-based optimization.
---

# GDScript и Godot 4: библиотека знаний и пайплайн

Скилл помогает писать, проверять и ускорять код на GDScript в любой области: игры, интерфейсы, инструменты редактора, приложения на Godot. Внутри три вещи:

1. **Библиотека знаний.** Документация, статьи, книги, курсы, открытые проекты и паттерны по категориям. Каждый источник дан со ссылкой, автором, годом и пояснением, зачем его читать.
2. **Тулчейн.** Какие инструменты ставить, какие команды запускать и в каком порядке. Агент работает из терминала, поэтому упор на headless-режим Godot.
3. **Пайплайн.** Порядок работы: тесты до кода, проверки качества, бенчмарки, ревью, поиск решений в библиотеке и повторный замер.

Состояние знаний — октябрь 2026: Godot 4.7.2 stable (4.7 вышел 18 июня 2026), ветка 4.8 в разработке.

## Куда смотреть

| Задача | Файл |
| --- | --- |
| Новая фича, рефакторинг или оптимизация: порядок работы | [references/pipeline.md](references/pipeline.md) |
| Godot CLI, проверка скриптов, предупреждения, форматтер, тесты, CI, экспорт, git | [references/toolchain.md](references/toolchain.md) |
| Игра тормозит: техника по симптому, профилирование, бенчмарки | [references/performance.md](references/performance.md) — начните с таблицы «Симптом → техника → источник» |
| Типизация, стиль, сигналы, `class_name`, аннотации, что нового в 4.x, паттерны, чеклист ревью | [references/idioms-patterns.md](references/idioms-patterns.md) |
| Структура проекта, сцены и композиция, автозагрузки, Resources, сохранения, машины состояний, тестирование | [references/architecture.md](references/architecture.md) |
| Сигналы, `await`, `call_deferred`, потоки, `WorkerThreadPool`, HTTP, мультиплеер и RPC | [references/signals-async-threads.md](references/signals-async-threads.md) |
| Особенности области: 2D, 3D, UI, карточные и пошаговые игры, ИИ, процедурка, диалоги, аудио, шейдеры, платформы, C# и GDExtension | [references/domains.md](references/domains.md) |
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

**Перед тем как объявить работу готовой**, прогоните минимальные проверки и покажите их вывод:

```bash
gdscript-formatter --check -x addons .
godot --headless --path . --import
GODOT=godot <путь к скиллу>/scripts/check_scripts.sh
mkdir -p reports && godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
```

`--check-only` ловит ошибки типов, только если в `project.godot` нужные предупреждения переведены в Error. Минимум — `untyped_declaration=2`, шаблон в [toolchain.md](references/toolchain.md). Если тесты на gdUnit4, используйте его `runtest.sh`. Если инструмент не установлен, скажите об этом и предложите команду установки из [toolchain.md](references/toolchain.md), а не пропускайте шаг молча.

Агент не видит игру. То, что нельзя проверить кодом (анимация, ощущение управления, вёрстка UI на разных разрешениях), явно передавайте человеку на ручную проверку со списком, что смотреть.

**При оптимизации:**

- Сначала замер, потом правка. Без базовой линии нельзя сказать, что код стал быстрее.
- Бинарник редактора — debug-сборка. Сравнивайте варианты одним и тем же бинарником, а абсолютные цифры берите из release-экспорта.
- Ищите технику по симптому в [performance.md](references/performance.md) и указывайте источник рядом с правкой.
- Принимайте правку, только если бенчмарк показал значимый выигрыш, а тесты остались зелёными.

**При ревью** используйте чеклисты:

- [idioms-patterns.md](references/idioms-patterns.md) — для любого кода;
- [signals-async-threads.md](references/signals-async-threads.md) — для `await`, потоков и сети;
- [architecture.md](references/architecture.md) — для структуры сцен и связей между ними.

## Правила использования библиотеки

- **Ссылайтесь на источник.** Рекомендуя паттерн или оптимизацию, давайте ссылку из справочника. Тогда пользователь может проверить совет, а решение не выглядит выдуманным.
- **Учитывайте пометки.** `[устарело]` значит, что у материала есть замена, и она указана рядом. Особенно часто так помечены советы и синтаксис Godot 3 (`yield`, `export var`, `KinematicBody`, `TileMap`). `[не проверено]` значит, что утверждение взято из одного вторичного источника; его стоит перепроверить, прежде чем строить на нём решение.
- **Проверяйте версию Godot.** Версии движка и аддонов указаны на октябрь 2026. Уточните версию проекта в `project.godot` (`config/features`), прежде чем советовать возможности, появившиеся в 4.4–4.7. Сверяйтесь с документацией нужной версии и release notes.
- **Говорите о пробелах прямо.** Если в библиотеке нет ответа, так и скажите, а затем ищите в официальной документации. Не выдавайте догадку за материал библиотеки.
- **Следуйте соглашениям проекта.** Если в проекте уже приняты стиль, аддоны или архитектура, советы библиотеки применяются в их рамках, а не поверх.

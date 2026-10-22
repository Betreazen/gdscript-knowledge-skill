# Книги, курсы и проекты по GDScript и Godot 4: каталог и маршрут обучения

Аннотированный каталог материалов для тех, кто пишет на GDScript под Godot 4: книги, официальная документация, курсы, каналы, открытые проекты для чтения и сообщества. Отмечено, что обязательно, что брать «по ситуации», что бесплатно и какие материалы написаны под Godot 3 и устарели. В конце дан маршрут по уровням со специализациями. Состояние на октябрь 2026 года: стабильная ветка Godot 4.7 (июнь 2026, есть 4.7.2), 4.6 вышла в январе 2026, 4.8 в разработке; документация `stable` соответствует 4.7.

- [Как выбирать материал](#как-выбирать-материал)
- [Must-read](#must-read)
- [Бесплатные онлайн-ресурсы и официальная документация](#бесплатные-онлайн-ресурсы-и-официальная-документация)
- [Книги по Godot 4: полный список](#книги-по-godot-4-полный-список)
- [Полка «по ситуации»: общий геймдев](#полка-по-ситуации-общий-геймдев)
- [Курсы и каналы](#курсы-и-каналы)
- [Открытые проекты для чтения](#открытые-проекты-для-чтения)
- [Сообщества и новости](#сообщества-и-новости)
- [Маршрут по уровням](#маршрут-по-уровням)

## Как выбирать материал

### Ключевые выводы

- Первое, что проверять у любого материала: Godot 3 или Godot 4. Между ними сломана совместимость: GDScript 2.0, переименованные узлы, новый синтаксис сигналов и аннотаций. Учебник по Godot 3 научит неправильному синтаксису.
- Признаки материала под Godot 3: `yield(...)` вместо `await`, `export var` вместо `@export var`, `onready var` вместо `@onready var`, `KinematicBody2D` вместо `CharacterBody2D`, `Spatial` вместо `Node3D`, `connect("signal", self, "method")` вместо `signal.connect(method)`, `move_and_slide(velocity)` с аргументом, `instance()` вместо `instantiate()`.
- Материалы под 4.0–4.2 в целом верны, но стареют точечно: `TileMap` заменён на `TileMapLayer` (4.3), появились типизированные словари (4.4), `@abstract` и variadic-аргументы (4.5), в 4.7 Asset Library заменяется Asset Store. Сверяйте такие места с документацией своей версии.
- Видео стареет быстрее книг: интерфейс редактора меняется в каждой минорной версии. Смотрите на номер версии в названии или описании ролика.
- Больше всего пользы для GDScript-кода дают бесплатные ресурсы: официальная документация (особенно раздел Best practices), Game Programming Patterns и статьи Red Blob Games. Платные книги Packt полезны как структурированный вход, но глубиной не отличаются.
- Для архитектуры игры читайте чужой код: открытые проекты (Pixelorama, godot-open-rpg, tps-demo) показывают, как организовать сцены, автозагрузки и ресурсы, лучше любой книги.

Метки: `[устарело]` — материал под Godot 3 или заменён новым изданием; `[не проверено]` — существование, версия или содержание не подтверждены при составлении каталога.

## Must-read

### Ключевые выводы

- Официальная документация — главный источник. Step by step и раздел Best practices читайте целиком, GDScript reference и style guide держите под рукой.
- Game Programming Patterns (Nystrom) — лучший короткий текст про архитектуру игрового кода. Паттерны State, Observer, Component, Command, Object Pool прямо ложатся на узлы, сигналы и ресурсы Godot.
- Red Blob Games — эталонные интерактивные статьи про поиск пути, сетки и генерацию карт. Без них трудно правильно написать A*, гексагональную сетку или тайловую логику.
- Из книг по самому Godot стоит взять одну вводную (Bradfield или Vanhove) и одну архитектурную (Campos или Henning, 2025–2026).
- Learn GDScript From Zero — бесплатное интерактивное приложение для тех, кто ещё не программировал.

| Ресурс | Автор, год | Издание, доступ | Уровень | Зачем читать |
|---|---|---|---|---|
| [Документация Godot: Step by step](https://docs.godotengine.org/en/stable/getting_started/step_by_step/index.html) | Godot project, живая (stable = 4.7) | бесплатно | начальный | Узлы и сцены, экземпляры, скрипты, сигналы, ввод. Затем учебные игры [Your first 2D game](https://docs.godotengine.org/en/stable/getting_started/first_2d_game/index.html) и [Your first 3D game](https://docs.godotengine.org/en/stable/getting_started/first_3d_game/index.html) |
| [Документация Godot: Best practices](https://docs.godotengine.org/en/stable/tutorials/best_practices/index.html) | Godot project, живая | бесплатно | средний | 12 страниц про архитектуру: ООП-принципы в Godot, организация сцен, сцены против скриптов, автозагрузки против обычных узлов, когда не использовать узлы, интерфейсы Godot, notifications, выбор структур данных и логики, организация проекта, VCS. Самый недооценённый раздел документации |
| [GDScript reference](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html), [style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html), [static typing](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html) | Godot project, живая | бесплатно | начальный → средний | Нормативный синтаксис GDScript 2.0, соглашения об именовании и порядке членов класса, статическая типизация (быстрее исполняется и ловит ошибки до запуска) |
| [Game Programming Patterns](https://gameprogrammingpatterns.com/contents.html) | Robert Nystrom, 2014 | бесплатно онлайн, есть печатное издание | средний | [State](https://gameprogrammingpatterns.com/state.html) — конечные автоматы персонажа, [Observer](https://gameprogrammingpatterns.com/observer.html) — сигналы, [Component](https://gameprogrammingpatterns.com/component.html) — композиция узлов, [Command](https://gameprogrammingpatterns.com/command.html) — ввод и undo, [Object Pool](https://gameprogrammingpatterns.com/object-pool.html), [Game Loop](https://gameprogrammingpatterns.com/game-loop.html) — `_process` против `_physics_process`, [Spatial Partition](https://gameprogrammingpatterns.com/spatial-partition.html) |
| [Red Blob Games](https://www.redblobgames.com/) | Amit Patel, живой | бесплатно | средний | [Введение в A*](https://www.redblobgames.com/pathfinding/a-star/introduction.html) и [реализация](https://www.redblobgames.com/pathfinding/a-star/implementation.html), [гексагональные сетки](https://www.redblobgames.com/grids/hexagons/), [части сетки](https://www.redblobgames.com/grids/parts/), [рисование линий на сетке](https://www.redblobgames.com/grids/line-drawing/), [flow field](https://www.redblobgames.com/pathfinding/tower-defense/), [карты из шума](https://www.redblobgames.com/maps/terrain-from-noise/), [2D-видимость](https://www.redblobgames.com/articles/visibility/). Полезно вместе с `AStarGrid2D` и `AStar2D` Godot |
| [Godot 4 Game Development Projects, 2nd ed.](https://www.packtpub.com/product/godot-4-game-development-projects-second-edition/9781804610404) | Chris Bradfield, август 2023 | Packt, 264 стр.; платно; [код](https://github.com/PacktPublishing/Godot-Engine-Game-Development-Projects-Second-Edition) | начальный → средний | Пять законченных 2D- и 3D-игр от автора KidsCanCode. Узловой подход, GDScript, UI, импорт из Blender. Написана под 4.0: сверяйте TileMap |
| [Game Development Patterns with Godot 4](https://www.oreilly.com/library/view/game-development-patterns/9781835880289) | Henrique Campos, январь 2025 | Packt, 304 стр.; платно | средний | SOLID и ООП в GDScript, паттерны на примере платформера на Godot 4.3: ИИ врагов, уровни, интерактивные объекты. Формат «геймдизайнер просит фичу, инженер реализует» |
| [Learn GDScript From Zero](https://gdquest.github.io/learn-gdscript) | GDQuest, переписан на Godot 4 | бесплатно, открытый код; в браузере или [для ПК](https://gdquest.itch.io/learn-godot-gdscript) | начальный | Интерактивные уроки программирования с нуля прямо на GDScript: переменные, функции, циклы, массивы, словари. Для тех, кто не писал код вообще |

## Бесплатные онлайн-ресурсы и официальная документация

### Ключевые выводы

- Class reference — главный справочник. Описание каждого класса, его сигналов и свойств авторитетнее любой книги и всегда соответствует версии.
- Официальные демо-проекты показывают минимальный правильный способ сделать конкретную вещь: сетевую игру, навигацию, шейдер, GUI.
- Перед переносом проекта с Godot 3 прочитайте официальный гайд по миграции.
- KidsCanCode Godot Recipes и GDQuest Library — лучшие бесплатные сборники рецептов. У Recipes есть отдельные деревья 4.x и 3.x, не перепутайте.
- В proposals обсуждаются будущие изменения движка и обоснования решений. Полезно, когда непонятно, почему API устроен так.

| Ресурс | Автор, год | Издание, доступ | Уровень | Зачем читать |
|---|---|---|---|---|
| [Class reference](https://docs.godotengine.org/en/stable/classes/index.html) | Godot project, живой | бесплатно; встроен в редактор (F1) | все | Свойства, методы, сигналы, константы каждого класса. Читайте описание класса целиком, а не только нужный метод |
| [Performance](https://docs.godotengine.org/en/stable/tutorials/performance/index.html) | Godot project, живой | бесплатно | средний → продвинутый | Общие принципы, CPU и GPU-оптимизация, серверы рендеринга и физики в обход узлов, MultiMesh, потоки |
| [Upgrading to Godot 4](https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.html) | Godot project | бесплатно | средний | Таблицы переименований и изменений API. Нужен, чтобы читать старые материалы и переносить проекты; плюс страницы миграции между минорными версиями 4.x в том же разделе |
| [godot-demo-projects](https://github.com/godotengine/godot-demo-projects) | Godot project, живой | бесплатно, MIT | начальный → средний | Ветка master под следующую 4.x, ветка 3.x отдельно. Разделы 2d, 3d, audio, gui, networking, xr, compute, plugins, viewport, loading. Минимальные эталонные примеры |
| [tps-demo](https://github.com/godotengine/tps-demo) | Godot project | бесплатно, MIT | средний | Официальный 3D-шутер от третьего лица с качественными ассетами и освещением; master совместим с последней стабильной 4.x |
| [Godot Recipes 4.x](https://kidscancode.org/godot_recipes/4.x/) | Chris Bradfield (KidsCanCode), живой | бесплатно | начальный → средний | Короткие рецепты: движение, камера, ИИ, UI, физика, шейдеры. [Ветка 3.x](https://kidscancode.org/godot_recipes/3.x/) — `[устарело]` |
| [GDQuest Library](https://www.gdquest.com/library/) | GDQuest, живой | бесплатно | начальный → средний | Godot 4: первая 2D-игра (Vampire Survivors-подобная) и первая 3D (арена-FPS), глоссарий на 200+ терминов, шпаргалки, статьи про боёвку, сохранения, контроллеры, VFX |
| [Catlike Coding: Godot](https://catlikecoding.com/godot/) | Jasper Flick | бесплатно | средний | Подробные текстовые туториалы по Godot 4 от автора известных серий по Unity. Серии: Introduction, True Top-Down 2D, Procedural GPU Patterns (шейдерный шум и узоры, обновляется в 2026) |
| [Godot Shaders](https://godotshaders.com/) | сообщество | бесплатно | средний | Библиотека шейдеров Godot с кодом: эффекты, постобработка, вода, контуры. Проверяйте, под 3.x или 4.x шейдер |
| [The Book of Shaders](https://thebookofshaders.com/) | Patricio Gonzalez Vivo, Jen Lowe | бесплатно | средний | Основа фрагментных шейдеров: формы, шум, паттерны. Код на GLSL, на шейдерный язык Godot переводится почти дословно |
| [Inigo Quilez: articles](https://iquilezles.org/articles/) | Inigo Quilez | бесплатно | продвинутый | SDF, шум, ray marching — справочник для серьёзных шейдеров |
| [Game AI Pro](https://www.gameaipro.com/) | ред. Steve Rabin | главы бесплатно онлайн | средний → продвинутый | Behavior trees, utility AI, поиск пути, тактика — сборник статей от разработчиков AAA |
| [Godot proposals](https://github.com/godotengine/godot-proposals) | Godot project | бесплатно | продвинутый | Обсуждения будущих возможностей и мотивация решений API |
| [Блог Godot](https://godotengine.org/blog/) | Godot project | бесплатно | все | Release notes, обзоры возможностей каждой версии, progress reports. Читайте статью к каждому релизу, на который переходите |

Также полезны: [awesome-godot](https://github.com/godotengine/awesome-godot) (список игр, плагинов и скриптов; раздел туториалов перенесён в документацию), страница [туториалов от сообщества](https://docs.godotengine.org/en/stable/community/tutorials.html) в документации и [Godot Showcase](https://godotengine.org/showcase/).

## Книги по Godot 4: полный список

### Ключевые выводы

- Книг по Godot 4 мало, и почти все от Packt. No Starch и Apress книг по Godot 4 на 2025–2026 годы не выпускали (по найденным данным).
- Книги 2023 года (Bradfield 2e, Cookbook) написаны под 4.0. Синтаксис GDScript 2.0 в них верен, но часть API редактора и узлов изменилась.
- Архитектурные книги 2025–2026 годов (Campos, Henning) — лучший выбор после первой игры.
- Godot Engine Game Development in 24 Hours — книга авторов движка, но под Godot 3.0. Брать только ради истории.

| Ресурс | Автор, год | Издание, доступ | Уровень | Зачем читать |
|---|---|---|---|---|
| [Learning GDScript by Developing a Game with Godot 4](https://packtpub.com/product/learning-gdscript-by-developing-a-game-with-godot-4/9781804616987) | Sander Vanhove, май 2024 | Packt, 378 стр.; платно ([O'Reilly](https://oreilly.com/library/view/learning-gdscript-by/9781804616987)) | начальный | Программирование с нуля через GDScript 2.0: данные, логика, затем физика, навигация, камеры, экспорт, основы мультиплеера на примере Vampire Survivors-подобной игры |
| [Godot 4 for Beginners](https://www.oreilly.com/library/view/godot-4-for/9781836203094) | Robert Henning (по данным одного продавца — с Sander Vanhove), август 2025 | Packt; платно | начальный | Интерфейс, узлы и сцены, 2D и 3D, освещение, игрок, враги, предметы, состояния игры, публикация |
| [Godot 4 Game Development Cookbook](https://packtpub.com/en-ph/product/godot-4-game-development-cookbook-9781838827250) | Jeff Johnson, июнь 2023 | Packt, 258 стр.; платно | средний | 50+ рецептов: GUI, GDScript 2.0, рендеринг на Vulkan, шейдеры, аудио, физика, TileSet/TileMap, анимация, мультиплеер. Рассчитана на тех, кто переходит с Godot 3. TileMap-главы частично устарели (4.3) |
| [Godot 4 Best Practices](https://www.i-programmer.info/book-watch-archive/19113-godot-4-best-practices-packt.html) | Robert Henning, июнь 2026 | Packt, 342 стр.; платно | начальный → средний | Самая свежая архитектурная книга: SOLID для узлов и скриптов, сцены против скриптов, неглубокие иерархии, сигналы и notifications для развязки, конечные автоматы, ИИ через strategy, компоненты вместо глубокого наследования, Factory, Builder, Command, Service. Отзывов пока мало |
| [Game Development with Godot 4: A Complete Introduction](https://www.routledge.com/Game-Development-with-Godot-4-A-Complete-Introduction/Thorn/p/book/9781032759241) | Alan Thorn, ноябрь 2025 | CRC Press, 376 стр.; платно | начальный | Введение для новичков и для тех, кто переходит с Unity или Unreal: узлы и сцены, ресурсы и импорт, основы GDScript, 2D и 3D, UI, контроллер от первого лица |
| [Shaders in Godot 4](https://filiprachunek.gumroad.com/) | Filip Rachůnek, июль 2024 | самиздат (Gumroad), 310 стр., бесплатный фрагмент 50 стр. ([анонс](https://godotforums.org/d/40842-i-have-just-published-a-new-book-dedicated-to-creating-shaders-in-godot-4)) | средний | 30 шейдеров с объяснением алгоритмов и параметров, код можно использовать без ограничений. Единственная найденная книга целиком про шейдеры Godot 4 |
| Game Development with Godot 4 and C# | Kati Baker, январь 2025 | Packt, 440 стр.; платно | начальный → средний | Только для C#-разработчиков; для GDScript-проекта не нужна |
| [Godot Engine Game Development in 24 Hours](https://www.informit.com/store/godot-engine-game-development-in-24-hours-sams-teach-9780134835099) | Ariel Manzur, George Marques, март 2018 | Sams, 432 стр. | начальный | `[устарело]`: «Official Guide to Godot 3.0», GDScript 1. Авторы — сооснователь и ключевой разработчик движка; концепции узлов верны, код — нет |
| Godot Engine Game Development Projects (1st ed.) | Chris Bradfield, 2018 | Packt | начальный | `[устарело]`: Godot 3, заменена 2-м изданием (2023) |

Книги «The Godot 4 Shaders Book» и «Make Your Own Platformer» в поиске не находятся (проверено в октябре 2026); целиком про шейдеры Godot 4 есть только «Shaders in Godot 4».

## Полка «по ситуации»: общий геймдев

### Ключевые выводы

- Эти книги не про Godot, но про задачи, которые решает любой GDScript-проект: дизайн, столкновения, ИИ, процедурная генерация, «ощущение» управления.
- Берите под задачу: делаете ИИ — Millington и Game AI Pro; процедурные уровни — Short и Adams плюс Red Blob Games; физику и попадания — Ericson.
- Код в этих книгах на C++ или псевдокоде. Алгоритмы переносятся в GDScript напрямую, но горячие циклы при большом объёме данных лучше отдать встроенным классам Godot (`AStarGrid2D`, `PhysicsDirectSpaceState`, `NavigationServer`) или GDExtension.

| Ресурс | Автор, год | Издание, доступ | Уровень | Зачем читать |
|---|---|---|---|---|
| The Art of Game Design: A Book of Lenses, 3rd ed. | Jesse Schell, 2019 | CRC Press; платно | все | Геймдизайн через «линзы»-вопросы: опыт игрока, механики, баланс, интерес, прототипирование |
| Designing Games: A Guide to Engineering Experiences | Tynan Sylvester, 2013 | O'Reilly; платно | средний | Дизайн как инженерия опыта от автора RimWorld: элегантность, навыки, нарратив из систем, баланс |
| Game Feel | Steve Swink, 2008 | платно | средний | Отзывчивость управления, коэффициенты ускорения, «сочность» — то, что делает CharacterBody приятным |
| [Real-Time Collision Detection](https://realtimecollisiondetection.net/) | Christer Ericson, 2004 | Morgan Kaufmann; платно | продвинутый | Примитивы пересечений, BVH, пространственное разбиение. Нужна, когда встроенной физики мало: свои запросы, свёртки, кастомные коллизии |
| AI for Games, 3rd ed. | Ian Millington, 2019 | CRC Press; платно | средний → продвинутый | Steering, поиск пути, принятие решений (FSM, behavior trees, utility), тактика, обучение. База для LimboAI или Beehave |
| Procedural Generation in Game Design | Tanya X. Short, Tarn Adams (ред.), 2017 | CRC Press; платно | средний | Когда и зачем процедурная генерация: подземелья, лут, квесты, история мира. Дополняйте [картами из шума](https://www.redblobgames.com/maps/terrain-from-noise/) и [mapgen4](https://www.redblobgames.com/maps/mapgen4/) Red Blob Games |
| [Game Engine Architecture, 3rd ed.](https://www.gameenginebook.com/) | Jason Gregory, 2018 | CRC Press; платно | продвинутый | Как устроены движки: цикл, ресурсы, рендер, анимация, физика. Помогает понять, что Godot делает под капотом и когда уходить в GDExtension |
| [Amit's Game Programming Information](http://theory.stanford.edu/~amitp/GameProgramming/) | Amit Patel | бесплатно | средний | Классический подробный текст про A* и эвристики, предшественник статей Red Blob Games |

## Курсы и каналы

### Ключевые выводы

- Для старта бесплатного видео достаточно: Brackeys (2024) и Clear Code дают законченную игру за несколько часов, официальные «первые игры» в документации — за вечер.
- GDQuest — самый системный платный путь (GDSchool), а их бесплатные приложение и библиотека подходят всем.
- Длинные серии HeartBeast и курсы Bramwell хороши как «повтори за автором», но после 1–2 таких серий переходите к своим проектам и чтению кода.
- Видео про Godot 3 (включая знаменитую Action RPG серию HeartBeast 2020 года) учат устаревшему синтаксису `[устарело]`.
- Платные курсы (GameDev.tv, Udemy, Zenva) неравномерны по глубине; перед покупкой проверьте целевую версию Godot и отзывы.

| Ресурс | Автор, год | Издание, доступ | Уровень | Зачем смотреть |
|---|---|---|---|---|
| [Learn 2D Gamedev From Zero with Godot 4](https://school.gdquest.com/products/learn_2d_gamedev_godot_4) / [бандл 2D+3D](https://school.gdquest.com/products/bundle_learn_gamedev_godot_4) | GDQuest, живой | GDSchool; платно, бесплатный модуль — Learn GDScript From Zero | начальный → средний | Самый структурированный курс по Godot 4 с упражнениями и проверкой понимания; [анонс приложения](https://gdquest.com/news/2022/12/learn-gdscript-app) |
| [GDQuest на YouTube](https://www.youtube.com/channel/UCxboW7x0jZqFdvMdCFKTMsQ/playlists) | GDQuest | бесплатно | все | Короткие разборы возможностей движка и паттернов. Старые плейлисты — под Godot 3 |
| [How to make a Video Game – Godot Beginner Tutorial](https://www.youtube.com/watch?v=LOhfqjmasi0) | Brackeys, 2024 | бесплатно ([новость о возвращении](https://80.lv/articles/unity-creator-brackeys-is-back-with-godot-tutorials)) | начальный | 2D-платформер от начала до конца. Лучший первый ролик для бывших пользователей Unity |
| [The ultimate introduction to Godot 4](https://www.youtube.com/watch?v=nAh_Kx5Zh5Q) / The new ultimate introduction | Clear Code, 2023 и позже | бесплатно на YouTube (канал [@ClearCode](https://www.youtube.com/@ClearCode); там же длинные проекты: Stardew Valley, Zelda BotW в 3D, Control-узлы, шейдеры) | начальный | Многочасовые вводные курсы; новая версия делает три игры. Первая версия под 4.0, TileMap устарел ([обсуждение на форуме](https://forum.godotengine.org/t/best-tutorial-for-beginners/132905)) |
| [HeartBeast](https://www.youtube.com/@uheartbeast) | Benjamin (HeartBeast) | бесплатно | начальный → средний | Длинные пошаговые серии. Heart Platformer (в [плейлистах канала](https://www.youtube.com/@uheartbeast/playlists)) — под Godot 4; Action RPG серия — `[устарело]` (Godot 3) |
| [Godotneers](https://www.youtube.com/@godotneers) | derkork, автор godot-statecharts и Safe Resource Loader | бесплатно | средний | Подробные туториалы по механизмам движка и инструментам; канал был в списке видеотуториалов документации 4.2 |
| [Godot 4 Beginners](https://bramwell.itch.io/godot-4-beginners) | Bramwell, обновлён в июне 2025 | itch.io, от $34; гл. 4 бесплатно | начальный → средний | Текстовые гайды, исходники, 7 демо-сцен (UI, декали, туман, частицы, навигация, tweens, шейдеры), карточная игра; цель — Godot 4.4.1. Первые главы — для перехода с Godot 3 |
| [Complete Godot 2D](https://www.gamedev.tv/courses/godot-complete-2d) / [Complete Godot 3D](https://gamedev.tv/courses/godot-complete-3d) | GameDev.tv | платно | начальный | По три игры в 2D и 3D на Godot 4 (2D: 83 лекции, 11,5 ч). Часть студентов жалуется на узость охвата ([форум](https://community.gamedev.tv/t/pretty-disappointed-with-the-scope-of-complete-godot-4-game-developer-2d/232289)) |
| [GameDev Academy: Godot 4](https://gamedevacademy.org/category/godot-tutorials/godot-4/) | Zenva | статьи бесплатно, курсы платно | начальный | Много коротких туториалов; глубина неравномерна |
| [FinePointCGI](https://finepointcgi.io/), [Game Dev Artisan](https://gamedevartisan.com/), [gdscript.com](https://gdscript.com) | разные авторы | бесплатно | начальный → средний | Текстовые туториалы из списка в официальной документации |
| [Godot 4: Introduction to 2D game development](https://www.udemy.com/course/godot-4-introduction-to-2d-game-development/), [Godot 4 for Beginners (Packt, Coursera)](https://www.coursera.org/learn/packt-godot-4-for-beginners) | Packt (Coursera: 12 модулей, около 8 ч); Udemy — разные | платно | начальный | Альтернативы, если удобен формат платформы. Глубину и версию Godot проверяйте сами |
| Каналы из списка [godot-4-awesome-help](https://github.com/mogoh/godot-4-awesome-help): bitbrain, Bonkahe, Chaff Games, DashNothing, FinePointCGI, Lukky, Maker Tech, StayAtHomeDev, The Polyglot Programmer | разные | бесплатно | начальный → средний | Узкие темы: шейдеры, 3D-контроллеры, процедурка, инструменты |
| [Queble](https://www.youtube.com/@queblegamedevelopment4143), [Gwizz](https://www.youtube.com/@Gwizz1027), [Mostly Mad Productions](https://www.youtube.com/@MostlyMadProductions), [Firebelley Games](https://www.youtube.com/@FirebelleyGames), DevWorm ([проекты к урокам на itch.io](https://devworm.itch.io)) | разные | бесплатно | начальный → средний | Уроки по 2D и GDScript под Godot 4. Queble и Gwizz были в списке видеотуториалов документации 4.2; у Firebelley — разборы кода (Godot Code Review) и советы; у DevWorm — серии про ресурсы, сигналы, сохранения, Phantom Camera |
| GodotCon: [прошедшие конференции](https://conference.godotengine.org/past), плейлисты [Мюнхен 2023](https://www.youtube.com/playlist?list=PLeG_dAglpVo7ZMlL2CQagJNdjsmbeg9BH), [Берлин 2024](https://www.youtube.com/playlist?list=PLeG_dAglpVo6TS0q858NajyeglRuvb7hs), [Бостон 2025](https://www.youtube.com/playlist?list=PLeG_dAglpVo5oOrjQqDTMQadVDqe1Zsom); в 2026 — Амстердам, Бостон, Токио | Godot Foundation | записи докладов бесплатно на YouTube | средний → продвинутый | Доклады разработчиков движка и студий: рендеринг, архитектура проектов, производственные истории, GDExtension |

## Открытые проекты для чтения

### Ключевые выводы

- Читать код законченной программы полезнее, чем смотреть ещё один туториал: видно, как устроены автозагрузки, ресурсы, сохранения, UI и плагины в масштабе.
- Pixelorama — большой реальный продукт на GDScript под Godot 4.7: образец для UI, инструментов и организации кода.
- godot-open-rpg и godot-open-rts — учебные, но цельные игры с продуманной архитектурой.
- Популярные коммерческие игры на Godot (Dome Keeper, Brotato, Cassette Beasts) закрыты; их исходников нет.
- Перед чтением проверьте требуемую версию Godot в README и откройте проект именно в ней.

| Проект | Автор, версия | Лицензия, доступ | Уровень | Что смотреть |
|---|---|---|---|---|
| [Pixelorama](https://github.com/orama-interactive/pixelorama) | Orama Interactive; Godot 4.7.2, 10k+ звёзд | MIT | продвинутый | Большое приложение на GDScript: таймлайн, слои, система инструментов, расширения, экспорт, командная строка. Архитектура UI и undo/redo |
| [Material Maker](https://github.com/RodZill4/material-maker) | RodZill4; 1.4 (октябрь 2025) — первая версия на Godot 4 ([обзор](https://www.cgchannel.com/2025/10/material-maker-1-4/)) | MIT | продвинутый | Генерация шейдеров из графа узлов, GraphEdit, рендеринг текстур. Образец для инструментов и шейдерной кодогенерации |
| [godot-open-rpg](https://github.com/GDquest/godot-open-rpg) | GDQuest; требует 4.6, активен в 2026 | MIT | средний | Пошаговый бой, инвентарь, прогрессия, диалоги, сеточное перемещение, переходы между картами, меню. «Один надёжный способ» структурировать 2D RPG |
| [godot-open-rts](https://github.com/lampe-games/godot-open-rts) | Lampe Games; Godot 4.2 (ветки для 4.0 и 4.1) | открытый код | средний → продвинутый | RTS: ИИ противника, туман войны, миникарта, движение группами, выбор юнитов. Простой и чистый дизайн |
| [tps-demo](https://github.com/godotengine/tps-demo) | Godot project | MIT | средний | 3D-персонаж, прицеливание, враги, освещение и настройки качества графики |
| [godot-4-3d-third-person-controller](https://github.com/gdquest-demos/godot-4-3d-third-person-controller) и другие [демо GDQuest](https://github.com/gdquest-demos) | GDQuest | открытый код | средний | Подключаемый TPS-контроллер; [godot-4-new-features](https://github.com/gdquest-demos/godot-4-new-features) — сцены с новыми возможностями Godot 4 |
| [Starter Kit City Builder](https://github.com/KenneyNL/Starter-Kit-City-Builder), [Starter Kit FPS](https://github.com/KenneyNL/Starter-Kit-FPS) и другие стартовые наборы | Kenney; Godot 4.3 | MIT (код), CC0 (ассеты) | начальный → средний | Маленькие чистые шаблоны: строительство на сетке с MeshLibrary и сохранением, FPS-контроллер с оружием и врагами |
| [COGITO](https://codeberg.org/Phazorknight/Cogito) | Philip Drobar; 1.1.6 (апрель 2026) для 4.5.1, в сентябре 2026 вышел 1.20-rc; репозиторий на Codeberg ([документация](https://cogito.readthedocs.io/en/latest/about.html)) | MIT | средний | Шаблон immersive sim: интерактивные объекты, инвентарь, квесты, сохранение с персистентностью сцен |
| [Liblast](https://codeberg.org/liblast) | сообщество; Godot 4 | свободная лицензия | продвинутый | Мультиплеерный FPS. Сама игра сейчас не работает, развивается Liblast Framework — читайте его ради сетевой архитектуры |
| Игры из [awesome-godot](https://github.com/godotengine/awesome-godot): [A Dark Forest](https://github.com/TinyTakinTeller/GodotProjectZero) (инкрементальная, 4.4), [Librerama](https://codeberg.org/Librerama/librerama) (сборник мини-игр, 4.x), [Super Tux Party](https://gitlab.com/SuperTuxParty/SuperTuxParty) (party-игра, 4.2, ветка `dev`), [Tanks of Freedom II](https://github.com/P1X-in/tanks-of-freedom-ii) (пошаговая стратегия, 4.4) | разные; все на Godot 4, обновлялись в 2025–2026 | открытый код (у A Dark Forest код MIT, ассеты CC; у Tanks of Freedom II — MIT) | средний | Законченные игры разных жанров |
| Плагины: [Dialogic 2](https://github.com/dialogic-godot/dialogic) (≥ 4.5), [Beehave](https://github.com/bitbrain/beehave), [LimboAI](https://github.com/limbonaut/limboai) (C++ модуль или GDExtension), [Phantom Camera](https://github.com/ramokz/phantom-camera) (≥ 4.4), [GUT](https://github.com/bitwes/Gut), [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) | разные | MIT | средний → продвинутый | Как писать EditorPlugin, кастомные ресурсы и узлы, behavior trees и state machines, тестовые фреймворки. LimboAI — пример гибрида C++ и GDScript |
| Godot 2D Space Game, Godot Platformer 2D (GDQuest) | GDQuest, эпоха Godot 3 | открытые | — | `[устарело]`: идеи верны, код под Godot 3 |

## Сообщества и новости

### Ключевые выводы

- Вопросы задавайте на официальном форуме: он индексируется поиском и ответы находятся годами позже. Discord хорош для быстрых вопросов, но знания там теряются.
- Чтобы не пропускать изменения движка, достаточно блога Godot (статьи к релизам) и раз в две недели — Godot Digest.
- Ассеты и плагины ищите в Asset Store (запущен как стабильный в мае 2026, встроен в редактор с 4.7); старая Asset Library ещё работает, но объявлена устаревшей и станет доступной только для чтения.

| Ресурс | Автор, год | Доступ | Зачем |
|---|---|---|---|
| [Godot Forum](https://forum.godotengine.org/) | официальный | бесплатно | Основное место для вопросов и анонсов |
| [r/godot](https://www.reddit.com/r/godot) | сообщество | бесплатно | Новости, показ проектов, обсуждения |
| [Discord](https://discord.com/invite/4JBkykG), [Matrix](https://matrix.to/#/#godot-space:matrix.org) | официальные чаты | бесплатно | Быстрые вопросы |
| [Godot Forums](https://godotforums.org/) | независимый форум | бесплатно | Старый неофициальный форум, много архивных ответов (часто про Godot 3) |
| [Godot Digest](https://godotdigest.substack.com/) | Sebastian Castro, раз в две недели | бесплатно | Подборка новостей, туториалов и релизов сообщества |
| [Godot Asset Store](https://store.godotengine.org/) ([анонс](https://godotengine.org/article/introducing-the-godot-asset-store/), [roadmap](https://store.godotengine.org/roadmap)) | Godot Foundation, с мая 2026 | бесплатно; продажа платных ассетов — в планах | Плагины, шаблоны, шейдеры, модели; отзывы и версии ассетов. Старая [Asset Library](https://godotengine.org/asset-library/asset) ещё доступна, но устарела |
| [awesome-godot](https://github.com/godotengine/awesome-godot), [godot-4-awesome-help](https://github.com/mogoh/godot-4-awesome-help) | сообщество | бесплатно | Навигаторы по играм, плагинам, каналам. Первый покрывает Godot 2–4, второй — только 4 |
| [GameFromScratch](https://gamefromscratch.com/the-best-of-godot-games-in-2024/) | Mike Frison | бесплатно | Новости движков и обзоры игр на Godot |

## Маршрут по уровням

### Ключевые выводы

- Начинайте с официальной документации, а не с видео: Step by step и две «первые игры» дают правильную ментальную модель узлов, сцен и сигналов.
- После первой законченной игры главный рост — в архитектуре: Best practices, Game Programming Patterns, книги Campos или Henning, чтение открытых проектов.
- Производительность и GDExtension — только после профилирования: большинство проблем GDScript решается типизацией, отказом от лишних узлов и правильными встроенными классами.
- Специализацию выбирайте по проекту, параллельно со средним уровнем.

| Ступень | Что читать и делать | Зачем |
|---|---|---|
| 0. Ноль в программировании | [Learn GDScript From Zero](https://gdquest.github.io/learn-gdscript), затем [Learning GDScript by Developing a Game with Godot 4](https://packtpub.com/product/learning-gdscript-by-developing-a-game-with-godot-4/9781804616987) | Переменные, функции, типы, циклы — сразу на GDScript |
| 1. Начальный: движок | [Step by step](https://docs.godotengine.org/en/stable/getting_started/step_by_step/index.html), [Your first 2D game](https://docs.godotengine.org/en/stable/getting_started/first_2d_game/index.html), [Your first 3D game](https://docs.godotengine.org/en/stable/getting_started/first_3d_game/index.html); видео [Brackeys](https://www.youtube.com/watch?v=LOhfqjmasi0); [Godot 4 Game Development Projects 2e](https://www.packtpub.com/product/godot-4-game-development-projects-second-edition/9781804610404) | Узлы, сцены, экземпляры, сигналы, ввод, физические тела. Две-три маленькие законченные игры |
| 2. Начальный → средний: язык | [GDScript reference](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html), [style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html), [static typing](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html); [Godot Recipes 4.x](https://kidscancode.org/godot_recipes/4.x/) как справочник | Типизированный идиоматичный GDScript: `@export`, `@onready`, `await`, лямбды, типизированные массивы и словари, `class_name`, ресурсы |
| 3. Средний: архитектура | [Best practices](https://docs.godotengine.org/en/stable/tutorials/best_practices/index.html) целиком; [Game Programming Patterns](https://gameprogrammingpatterns.com/contents.html); [Game Development Patterns with Godot 4](https://www.oreilly.com/library/view/game-development-patterns/9781835880289) или [Godot 4 Best Practices](https://www.i-programmer.info/book-watch-archive/19113-godot-4-best-practices-packt.html); чтение [godot-open-rpg](https://github.com/GDquest/godot-open-rpg) | Композиция сцен, автозагрузки без злоупотреблений, сигналы для развязки, конечные автоматы, кастомные Resource как данные |
| 4. Средний: качество | [GUT](https://github.com/bitwes/Gut) или [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4); раздел Project organization и VCS в Best practices; [Upgrading to Godot 4](https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.html) для чтения старого кода | Тесты, структура папок, обновление версий движка |
| 5. Продвинутый: глубина | [Class reference](https://docs.godotengine.org/en/stable/classes/index.html) по каждому используемому классу; [Pixelorama](https://github.com/orama-interactive/pixelorama) или [Material Maker](https://github.com/RodZill4/material-maker); доклады [GodotCon](https://conference.godotengine.org/past); [proposals](https://github.com/godotengine/godot-proposals) | Понимать, как движок устроен и почему API такой; масштабируемая архитектура больших проектов |
| 6. Продвинутый: производительность | [Performance](https://docs.godotengine.org/en/stable/tutorials/performance/index.html) целиком; [Game Engine Architecture](https://www.gameenginebook.com/) для фона; затем GDExtension через [godot-cpp](https://github.com/godotengine/godot-cpp) или [godot-rust gdext](https://github.com/godot-rust/gdext) | Порядок: профилировщик, затем типизация и устранение лишней работы, серверы вместо узлов, MultiMesh, потоки; нативный код — последним |
| Специализация: 2D | [Red Blob Games](https://www.redblobgames.com/) (сетки, A*, видимость); [Godot Recipes](https://kidscancode.org/godot_recipes/4.x/); [Kenney Starter Kits](https://github.com/KenneyNL/Starter-Kit-City-Builder); Game Feel | TileMapLayer, поиск пути, камера, «ощущение» управления |
| Специализация: 3D | [Your first 3D game](https://docs.godotengine.org/en/stable/getting_started/first_3d_game/index.html), [tps-demo](https://github.com/godotengine/tps-demo), [TPS-контроллер GDQuest](https://github.com/gdquest-demos/godot-4-3d-third-person-controller), [COGITO](https://codeberg.org/Phazorknight/Cogito), [Phantom Camera](https://github.com/ramokz/phantom-camera) | Контроллеры персонажа, камера, освещение, импорт из Blender |
| Специализация: UI и инструменты | [Pixelorama](https://github.com/orama-interactive/pixelorama), [Material Maker](https://github.com/RodZill4/material-maker), [Dialogic](https://github.com/dialogic-godot/dialogic), разделы GUI и plugins в [demo projects](https://github.com/godotengine/godot-demo-projects) | Control-узлы, темы, контейнеры, EditorPlugin, `@tool`-скрипты |
| Специализация: ИИ | AI for Games (Millington), [Game AI Pro](https://www.gameaipro.com/), [LimboAI](https://github.com/limbonaut/limboai), [Beehave](https://github.com/bitbrain/beehave), [godot-open-rts](https://github.com/lampe-games/godot-open-rts) | FSM, behavior trees, utility AI, NavigationServer |
| Специализация: мультиплеер | Раздел networking в [demo projects](https://github.com/godotengine/godot-demo-projects), [Liblast Framework](https://codeberg.org/liblast), сетевые главы Cookbook и Vanhove | High-level multiplayer, `MultiplayerSynchronizer` и `MultiplayerSpawner`, RPC, авторитет сервера |
| Специализация: шейдеры | [The Book of Shaders](https://thebookofshaders.com/), [Shaders in Godot 4](https://filiprachunek.gumroad.com/), [Godot Shaders](https://godotshaders.com/), [Inigo Quilez](https://iquilezles.org/articles/) | Шейдерный язык Godot, visual shaders, постобработка, compute |
| Специализация: процедурная генерация | Procedural Generation in Game Design; Red Blob Games: [карты из шума](https://www.redblobgames.com/maps/terrain-from-noise/), [введение в шум](https://www.redblobgames.com/articles/noise/introduction.html) | `FastNoiseLite`, генерация подземелий и карт, сиды и воспроизводимость |
| Геймдизайн (параллельно с любой ступенью) | The Art of Game Design (Schell), Designing Games (Sylvester) | Делать игру интересной, а не только работающей |

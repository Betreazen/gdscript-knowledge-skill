# Производительность GDScript и Godot 4

Справочник для ускорения GDScript-кода и Godot-проектов: 2D, 3D, UI, инструменты, сетевые и неигровые приложения. Здесь есть порядок работы, таблица «симптом → техника → источник» для быстрого поиска, готовый харнесс для бенчмарков, разделы по профилированию, типизации, коллекциям, дереву сцены, памяти и загрузке, рендерингу, физике, потокам, выбору языка и сборке, разборы реальных случаев и антипаттерны. Опорные источники — раздел [Performance](https://docs.godotengine.org/en/stable/tutorials/performance/index.html) официальной документации и заметки о релизах. Актуально на октябрь 2026 года: stable — Godot 4.7.x (последний подтверждённый патч 4.7.2 от 18 августа 2026), 4.8 в стадии dev-снапшотов.

Метки: `[устарело]` — совет эпохи Godot 3 или ранних 4.x, рядом указана замена; `[не проверено]` — цифра или утверждение из вторичного источника либо без первичного замера.

- [Метод: профиль → алгоритм → типы → архитектура → другой язык](#метод-профиль--алгоритм--типы--архитектура--другой-язык)
- [Симптом → техника → источник](#симптом--техника--источник)
- [Как бенчмаркать GDScript](#как-бенчмаркать-gdscript)
- [Профилирование и мониторы](#профилирование-и-мониторы)
- [VM GDScript и статическая типизация](#vm-gdscript-и-статическая-типизация)
- [Коллекции, строки и Callable](#коллекции-строки-и-callable)
- [Узлы, дерево сцены и обработка кадров](#узлы-дерево-сцены-и-обработка-кадров)
- [Память, ресурсы и загрузка](#память-ресурсы-и-загрузка)
- [Рендеринг: батчинг, MultiMesh, серверы, шейдеры](#рендеринг-батчинг-multimesh-серверы-шейдеры)
- [Физика и навигация](#физика-и-навигация)
- [Потоки](#потоки)
- [Когда переносить код в C#, C++ или Rust](#когда-переносить-код-в-c-c-или-rust)
- [Сборка, экспорт, web и мобильные](#сборка-экспорт-web-и-мобильные)
- [Разборы реальных случаев](#разборы-реальных-случаев)
- [Антипаттерны](#антипаттерны)

---

## Метод: профиль → алгоритм → типы → архитектура → другой язык

Документация формулирует цикл прямо: снять профиль, найти самое медленное место, исправить, снять профиль снова ([General optimization tips](https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html)). Примерный порядок по убыванию отдачи:

1. понять, где узкое место: CPU-скрипты, физика, рендеринг на CPU, GPU, загрузка;
2. убрать работу: не обрабатывать то, что не видно и не меняется, считать реже, кэшировать;
3. статическая типизация и правильные контейнеры (`Packed*Array`, типизированные `Array[T]`);
4. меньше узлов: данные в `RefCounted`/массивах, отрисовка через `MultiMesh` или серверы;
5. потоки (`WorkerThreadPool`) для независимой работы;
6. перенос горячего ядра в C#, C++ (godot-cpp) или Rust (gdext).

### Ключевые выводы

- FAQ Godot прямо говорит, что в большинстве игр проблема не в языке, а в неэффективных алгоритмах, GPU или коде движка ([FAQ](https://docs.godotengine.org/en/stable/about/faq.html)). Начинайте с профиля, а не с переписывания на C++.
- Сначала определите тип проблемы: стабильно низкий FPS, редкие рывки (компиляция пайплайнов, загрузка, GC в C#) и долгая загрузка лечатся по-разному.
- Если `Frame Time` большой, а `Physics Time` и скрипты в профайлере маленькие, проблема в рендеринге. Проверка на fill rate: уменьшите окно; если FPS резко вырос, вы упираетесь в GPU по пикселям ([GPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html)).
- Меряйте экспортированную release-сборку. Debug-сборка GDScript в 4–5 раз медленнее release на одном и том же коде (таблица в [PR #70838](https://github.com/godotengine/godot/pull/70838)), так что цифры из редактора годятся только для сравнения вариантов между собой.
- Архитектура важнее микротюнинга: десятки тысяч узлов с `_process` не спасти типизацией, их нужно заменить данными и `MultiMesh` или серверами ([Using servers](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html)).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [General optimization tips](https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html) | документация Godot, живая | Цикл «профиль → узкое место → исправление», внешние CPU/GPU-профайлеры |
| [CPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html) | документация Godot (4.7) | Профайлер, ручные замеры `Time.get_ticks_usec()`, кэш, потоки, физика, SceneTree |
| [Why isn't Godot an ECS-based game engine?](https://godotengine.org/article/why-isnt-godot-ecs-based-game-engine/) | Juan Linietsky, 2021 | Почему узлы, и что делать при тысячах объектов: выборочная обработка, серверы, GPU compute |
| [FAQ: Which programming language is fastest?](https://docs.godotengine.org/en/stable/about/faq.html) | документация Godot | Официальная позиция по GDScript, C# и C++ |

---

## Симптом → техника → источник

Основная таблица для поиска. Начинайте с симптома, который показал профайлер, мониторы или ревью.

| Симптом | Техника | Источник |
|---|---|---|
| Непонятно, где тратится время | Debugger → Profiler (Start), режим Self, клик по пику на графике; Visual Profiler для CPU/GPU рендеринга | [The Profiler](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html) |
| Нужен профиль глубже встроенного (движок + скрипты) | Сборка движка с `profiler=tracy` или `perfetto` (4.6+), Instruments на Apple | [Tracy docs](https://docs.godotengine.org/en/stable/engine_details/development/profiling/tracy.html), [PR #104851](https://github.com/godotengine/godot/pull/104851) |
| Рывки на Android, нужен системный трейс | Perfetto, по умолчанию в Android-сборках с 4.7 | [Godot 4.7](https://godotengine.org/releases/4.7/) |
| Хочется видеть FPS и frametime в игре, на устройстве тестера | Аддон godot-debug-menu (F3) | [godot-debug-menu](https://github.com/godot-extended-libraries/godot-debug-menu) |
| Нужна своя метрика в Debugger → Monitors | `Performance.add_custom_monitor("Game/Enemies", callable)` | [Performance](https://docs.godotengine.org/en/stable/classes/class_performance.html) |
| Горячий цикл на нетипизированных переменных | Статические типы везде, `:=`, предупреждение `UNTYPED_DECLARATION` = Warn/Error | [Static typing](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html), [Typed instructions](https://godotengine.org/article/gdscript-progress-report-typed-instructions) |
| Частые вызовы методов движка из скрипта | Типизировать объект (`var body: CharacterBody3D`), тогда вызов идёт по прямому указателю (до +120–150% в debug) | [Typed instructions](https://godotengine.org/article/gdscript-progress-report-typed-instructions) |
| `Array` чисел/векторов медленно итерируется и много весит | `PackedFloat32Array`, `PackedVector2Array` и т.д., или хотя бы `Array[float]` | [GDScript reference](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html) |
| Словарь со строковыми ключами в горячем пути | Ключи `StringName` (`&"key"`): дорого создать, дёшево сравнить; типизированный `Dictionary[K, V]` (4.4+) | [GDScript reference](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html), [Godot 4.4](https://godotengine.org/releases/4.4/) |
| `get_node()`/`$` в `_process` | Кэшировать ссылку в `@onready var` | [Nodes and scene instances](https://docs.godotengine.org/en/stable/tutorials/scripting/nodes_and_scene_instances.html) |
| Проверка условия каждый кадр ради редкого события | `Timer`, сигнал или `await get_tree().create_timer(t).timeout` | [Godot notifications](https://docs.godotengine.org/en/stable/tutorials/best_practices/godot_notifications.html) |
| `Input.is_action_pressed` в `_process` ради одиночных нажатий | `_unhandled_input(event)` | [Godot notifications](https://docs.godotengine.org/en/stable/tutorials/best_practices/godot_notifications.html) |
| Тысячи узлов с `_process`, большинство ничего не делает | `set_process(false)`, `process_mode = PROCESS_MODE_DISABLED`, включать по событию | [Node](https://docs.godotengine.org/en/stable/classes/class_node.html) |
| Объекты вне экрана продолжают думать | `VisibleOnScreenNotifier2D/3D` + сигналы или `VisibleOnScreenEnabler2D/3D` | [VisibleOnScreenNotifier2D](https://docs.godotengine.org/en/stable/classes/class_visibleonscreennotifier2d.html) |
| Скрытые узлы всё равно стоят CPU | Удалять из дерева (`remove_child`), а не только `visible = false` | [CPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html) |
| Десятки тысяч объектов-данных в виде `Node` | `RefCounted`/`Resource` или Packed-массивы, узлы только для отображения | [Node alternatives](https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html) |
| Десятки тысяч одинаковых спрайтов/мешей | `MultiMeshInstance2D/3D`, `visible_instance_count` | [Using MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html) |
| MultiMesh целиком рисуется, хотя виден краешек | Разбить на несколько MultiMesh по областям мира | [Using MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html) |
| Тысячи анимированных существ (рыбы, трава, толпа) | Анимация в вершинном шейдере + `INSTANCE_CUSTOM` в MultiMesh | [Animating thousands of fish](https://docs.godotengine.org/en/stable/tutorials/performance/vertex_animation/animating_thousands_of_fish.html) |
| Узлы — узкое место даже после чистки (пули, частицы-логика) | Прямой `RenderingServer`/`PhysicsServer2D` через RID, без узлов | [Using servers](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html) |
| Синхронный запрос к серверу каждый кадр | Не вызывать в цикле методы серверов, которые возвращают значения: они заставляют сервер дообработать очередь | [Using servers](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html) |
| Много draw calls в 2D | Обновиться до 4.4+ (батчинг в Forward+/Mobile), общие текстуры/атласы, меньше разных материалов | [PR #92797](https://github.com/godotengine/godot/pull/92797), [GPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html) |
| Рывки при первом появлении эффекта или материала | 4.4+: ubershaders; заранее включить MSAA/пробы/GI на загрузке, скрытые экземпляры эффектов; следить за мониторами Pipeline Compilations | [Pipeline compilations](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html) |
| Долгий первый запуск из-за компиляции шейдеров | Shader baker при экспорте (4.5+) | [Godot 4.5](https://godotengine.org/releases/4.5/) |
| Рывки шейдеров в Compatibility (web, старые GPU) | Показать все материалы на кадр-другой во время загрузки (ubershaders тут нет) | [Pipeline compilations](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html) |
| Большой 3D-уровень, рендерится то, что за стенами | `OccluderInstance3D` и запекание, лучше всего в помещениях | [Occlusion culling](https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html) |
| Далёкие объекты слишком детальные | Автоматический mesh LOD при импорте, `lod_bias`; visibility ranges (HLOD) | [Mesh LOD](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html), [Visibility ranges](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html) |
| Много прозрачных объектов | Минимум прозрачности; для массы — MultiMesh; fade у visibility ranges тоже делает объект прозрачным | [Optimizing 3D](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html) |
| Динамический свет и тени дороги на мобильных | Запечённый свет (LightmapGI), `Static` bake mode для большинства источников | [Optimizing 3D](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html) |
| `Physics Time` большой | Простые формы коллизий (примитивы вместо trimesh), меньше активных тел, слои/маски | [CPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html) |
| Физика 60 Гц слишком дорогая | Понизить `physics/common/physics_ticks_per_second` и включить physics interpolation | [Physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html) |
| Нестабильная или медленная 3D-физика на GodotPhysics | Jolt (встроен с 4.4; с 4.6 Project Manager прописывает его в новые проекты, проект без ключа `physics/3d/physics_engine` работает на GodotPhysics) | [Godot 4.6](https://godotengine.org/releases/4.6/), [Using Jolt](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html) |
| Поиск пути съедает кадр | Не перестраивать путь каждый кадр, упростить navmesh, merge по вершинам | [Navigation performance](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_optimizing_performance.html) |
| Запекание navmesh в рантайме даёт фриз | Печь в фоновом потоке, крупнее cell size, парсить коллизии, а не визуальные меши | [Navigation performance](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_optimizing_performance.html) |
| Фриз при `load()` сцены уровня | `ResourceLoader.load_threaded_request` + опрос статуса | [Background loading](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html) |
| `load()` одного и того же ресурса в цикле | `preload` (константный путь) или загрузить один раз и хранить `PackedScene` | [Nodes and scene instances](https://docs.godotengine.org/en/stable/tutorials/scripting/nodes_and_scene_instances.html) |
| Память растёт, `OBJECT_ORPHAN_NODE_COUNT` растёт | `Node.print_orphan_nodes()`, проверить `remove_child` без `queue_free` | [Node](https://docs.godotengine.org/en/stable/classes/class_node.html), [Performance](https://docs.godotengine.org/en/stable/classes/class_performance.html) |
| `RefCounted` не освобождается | Цикл ссылок: одну сторону сделать `weakref()` | [RefCounted](https://docs.godotengine.org/en/stable/classes/class_refcounted.html) |
| Независимые вычисления на одном ядре | `WorkerThreadPool.add_group_task` | [WorkerThreadPool](https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html) |
| Создание `Thread` на каждую задачу | Пул потоков или потоки, созданные на загрузке; создание потока дорогое, особенно на Windows | [Using multiple threads](https://docs.godotengine.org/en/stable/tutorials/performance/using_multiple_threads.html) |
| Сборка большого поддерева сцены тормозит кадр | Собрать узлы в потоке вне дерева, затем `add_child.call_deferred(node)` | [Thread-safe APIs](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html) |
| Тяжёлая чистая математика в GDScript (генерация мира, симуляция) | Вынести ядро в GDExtension (godot-cpp, godot-rust) или C# | [FAQ](https://docs.godotengine.org/en/stable/about/faq.html), [GDExtension C++](https://docs.godotengine.org/en/stable/tutorials/scripting/cpp/gdextension_cpp_example.html) |
| C#-код медленнее ожидаемого на вызовах API | Кэшировать свойства `GodotObject` в локальные переменные, не передавать `string` туда, где ждут `StringName` | [C# basics](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_basics.html) |
| Web-сборка тормозит или не стартует на хостинге | Однопоточный экспорт (по умолчанию с 4.3), audio Sample playback, урезанный шаблон | [Exporting for Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html) |
| Большой размер бинарника/wasm | Свой шаблон: `optimize=size_extra`, `disable_3d=yes`, build profile `.gdbuild` | [Optimizing for size](https://docs.godotengine.org/en/stable/engine_details/development/compiling/optimizing_for_size.html) |
| Нужна регрессия производительности движка между версиями | Репозиторий godot-benchmarks и сайт с результатами | [godot-benchmarks](https://github.com/godotengine/godot-benchmarks), [benchmarks.godotengine.org](https://benchmarks.godotengine.org/) |

---

## Как бенчмаркать GDScript

### Ключевые выводы

- **Один процесс, много повторов.** Документация советует прогонять замеряемое 1000+ раз, потому что таймеры неточны, а планировщик ОС вносит шум ([CPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html)). Смотрите на медиану, а не на среднее: одиночные выбросы (переключение потока, ввод-вывод) портят среднее.
- **Прогрев.** Первые прогоны платят за загрузку ресурсов, кэш CPU и аллокации. Отбрасывайте 2–5 прогревочных прогонов.
- **Детерминизм.** Перед каждым прогоном вызывайте `seed(N)` (или храните свой `RandomNumberGenerator` с фиксированным `seed`), чтобы варианты считали одно и то же.
- **Сравнивайте варианты в одном процессе и одной сборке.** Абсолютные числа из редактора завышены: debug в 4–5 раз медленнее release ([PR #70838](https://github.com/godotengine/godot/pull/70838)). Для окончательных цифр экспортируйте release-сборку.
- **Без окна.** `--headless` убирает рендеринг и vsync из замера. Для бенчмарков рендеринга, наоборот, нужен реальный GPU: используйте godot-benchmarks или сцену с `Performance`-мониторами.
- **Оптимизатора, выкидывающего код, у GDScript нет**, поэтому аналог `black_box` не нужен. Всё же сохраняйте результат в поле (`_sink`), чтобы вариант не отличался от реального кода.
- Для бенчмарков самого движка и сравнения версий есть [godot-benchmarks](https://github.com/godotengine/godot-benchmarks): `godot -- --run-benchmarks --include-benchmarks="gdscript/*" --save-json=out.json`. Готовых бенчмарк-хелперов нет ни в gdUnit4 ([gdUnit4](https://github.com/MikeSchulze/gdUnit4)), ни в GUT: в дереве репозитория bitwes/Gut нет файлов `bench*`/`perf*` (проверено через GitHub API, октябрь 2026).

### Готовый харнесс

В скилле лежат два проверенных на Godot 4.7.2 скрипта. Оба проходят `--check-only` при строгих настройках предупреждений из [toolchain.md](toolchain.md).

- [scripts/bench.gd](../scripts/bench.gd) — харнесс: фиксированный seed, 3 прогревочных и 15 замеряемых прогонов, медиана, min, max и нс на итерацию. Наследует `SceneTree`, поэтому запускается без сцены. Скопируйте в `res://bench/bench.gd` и замените функции `_case_*` своими вариантами.
- [scripts/bench_compare.gd](../scripts/bench_compare.gd) — сравнение двух сохранённых прогонов. Вердикт `faster` или `slower` ставится, только если медиана сдвинулась больше порога (по умолчанию 5%) и межквартильные диапазоны не пересекаются. Иначе `same`. Код выхода 1 означает, что хотя бы один бенчмарк замедлился.

```bash
godot --headless --path . --script res://bench/bench.gd                                  # все варианты
godot --headless --path . --script res://bench/bench.gd -- --filter=typed_sum,packed_sum  # точные имена
godot --headless --path . --script res://bench/bench.gd -- --save=bench/before.json       # базовая линия
# ... правка ...
godot --headless --path . --script res://bench/bench.gd -- --save=bench/after.json
godot --headless --path . --script res://bench/bench_compare.gd -- bench/before.json bench/after.json 5
```

Пример вывода сравнения:

```
Benchmark                 Base median  Diff median   Change  Verdict
packed_sum                    6140 us      6158 us    +0.3%  same
typed_sum                     3799 us     17567 us  +362.4%  slower
```

На Windows для вывода в консоль используйте `Godot_v*_console.exe`.

Что проверить перед выводами:

- Строка заголовка печатает версию и `debug=true/false`. Бинарник редактора всегда debug, поэтому его цифры годятся только для сравнения вариантов между собой. Сравнивайте только прогоны с одинаковой строкой: `bench_compare.gd` предупредит, если строки различаются.
- Разброс `min`–`max` больше 10–15% от медианы — шумно: закройте фоновые задачи, увеличьте `N` или `RUNS`.
- Если варианты работают с узлами, не запускайте их прямо из `_initialize()`: добавленные туда узлы ещё не в дереве, и `add_child` не вызовет `_enter_tree`/`_ready`. Вынесите запуск в функцию, которая начинается с `await process_frame` (проверено на 4.7.2).
- Для release-цифр экспортируйте проект с release-шаблоном и запустите бинарник с теми же аргументами (`--headless --script` в экспортированной сборке работает, если скрипт попал в экспорт) [не проверено для всех платформ].
- Для замера внутри игры, а не в изоляции, используйте тот же приём `Time.get_ticks_usec()` вокруг подозрительного участка и пишите медиану в кастомный монитор.

### Замеры харнессом на Godot 4.7.2 (debug-сборка редактора)

Собственный прогон `scripts/bench.gd` с добавленными вариантами, октябрь 2026. Бинарник редактора 4.7.2 — **debug** (`debug=true`), Windows 11, AMD Ryzen 9 5950X; машина во время замера была загружена другими процессами, поэтому разброс между запусками доходил до 30–40%. Цифра — медиана из медиан пяти запусков (в каждом 3 прогрева и 15 прогонов), N = 200 000 операций; для спавна — 2000. Абсолютные значения в release будут меньше; смотрите на соотношения внутри строки.

| Сравнение | Вариант | нс/операцию | Вывод |
|---|---|---|---|
| Сумма `randf()` в цикле | нетипизированный / `:=` | 25.5 / 22.3 | Разница ~15%: время съедает вызов `randf()`, а не арифметика |
| Чтение `a[i]` из 200 000 float | `Array` / `Array[float]` / `PackedFloat32Array` | 46.8 / 24.5 / 20.4 | Типизация массива и индекса — почти вдвое быстрее; Packed ещё ~15% |
| `for v in a` по тем же данным | `Array` / `Array[float]` / `PackedFloat32Array` | 21.3 / 19.4 / 16.5 | При итерации разрыв меньше; Packed быстрее всех |
| Доступ к узлу | `get_node(^"A/B/C")` каждый раз / ссылка в переменной | 117.6 / 51.9 | Кэш в `@onready var` экономит ~65 нс на обращение (путь из трёх звеньев) |
| Вызов метода скрипта с 1 аргументом | прямой / `Callable.call()` / лямбда `.call()` | 134.6 / 131.4 / 127.0 | В 4.7.2 debug разницы нет в пределах шума |
| Тот же обработчик через сигнал | `signal.emit(1)`, один подписчик | 370.8 | `emit` примерно в 2.8 раза дороже прямого вызова |
| Чтение из словаря на 64 ключа | `Dictionary` / `Dictionary[StringName, int]` / `Dictionary[String, int]` | 122.7 / 84.6 / 95.9 | Типизированный словарь быстрее на ~30%, ключ `StringName` быстрее `String` |
| Сцена из 4 узлов (`Node2D`, `Sprite2D`, `Area2D`, `CollisionShape2D`) | `instantiate()` + `add_child` + `remove_child` + `free()` / пул: `visible` и `process_mode` туда и обратно | 36 753 / 4 251 | Пул дешевле примерно в 8–9 раз даже на маленькой сцене без скриптов; `_ready()` своих скриптов добавится к цене спавна |

Выводы для этой машины: типизируйте массивы и словари в горячих циклах, кэшируйте узлы, не гоняйте поток данных через сигналы. Замена `Callable.call()` на прямой вызов ради скорости в 4.7 не оправдана.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [godot-benchmarks](https://github.com/godotengine/godot-benchmarks) | Godot Foundation, живой | Бенчмарки GDScript, рендеринга и C++ (GDExtension), запуск из CLI, JSON-вывод |
| [benchmarks/gdscript](https://github.com/godotengine/godot-benchmarks/tree/main/benchmarks/gdscript) | там же | Образцы: `for_loop`, `lambda_performance`, `array`, `string_*`, `nbody`, `binary_trees` |
| [lambda_performance.gd](https://github.com/godotengine/godot-benchmarks/blob/main/benchmarks/gdscript/lambda_performance.gd) / [for_loop.gd](https://github.com/godotengine/godot-benchmarks/blob/main/benchmarks/gdscript/for_loop.gd) | там же | Как устроен минимальный бенчмарк: 1 000 000 итераций, вызов лямбды против прямого вызова |
| [benchmarks.godotengine.org](https://benchmarks.godotengine.org/) | Godot Foundation | История результатов по коммитам движка |
| [CPU optimization: Manually timing functions](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html) | документация Godot | Официальный приём с `Time.get_ticks_usec()` |

---

## Профилирование и мониторы

### Ключевые выводы

- Встроенный профайлер не стартует сам: нажмите Start или включите Autostart. Он показывает Frame Time, Physics Frame, Idle Time, Physics Time и время скриптовых функций. Режим **Self** показывает время тела функции без вложенных вызовов, **Inclusive** — с ними. По клику на пик графика можно разобрать конкретный кадр ([The Profiler](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html)).
- Встроенный профайлер не поддерживает C#-скрипты. Для C# используйте dotTrace, dotMemory или Visual Studio ([C# basics](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_basics.html)).
- Visual Profiler (вкладка рядом) показывает время CPU и GPU по стадиям рендеринга. Он помогает понять, CPU или GPU ограничивает кадр.
- Monitors: `TIME_FPS`, `TIME_PROCESS`, `OBJECT_NODE_COUNT`, `OBJECT_ORPHAN_NODE_COUNT`, `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `PIPELINE_COMPILATIONS_*` и другие. Их же можно читать из кода через `Performance.get_monitor()` ([Performance](https://docs.godotengine.org/en/stable/classes/class_performance.html)).
- Свои метрики добавляйте через `Performance.add_custom_monitor()`. Callable должен возвращать неотрицательное число.
- С 4.6 движок собирается с трассирующими профайлерами Tracy, Perfetto и Instruments. Нужна сборка из исходников: `scons platform=windows target=template_release debug_symbols=yes profiler=tracy profiler_path=path/to/tracy` ([Tracy docs](https://docs.godotengine.org/en/stable/engine_details/development/profiling/tracy.html), [PR #104851](https://github.com/godotengine/godot/pull/104851)). Заметка о релизе 4.6 обещает разбор узких мест GDScript и C# в этих профайлерах; как именно отображаются функции GDScript — [не проверено].
- В 4.7 Perfetto стал инструментом трассировки по умолчанию для Android-сборок ([Godot 4.7](https://godotengine.org/releases/4.7/)).
- Для GPU используйте внешние инструменты: NVIDIA Nsight, Radeon GPU Profiler, PIX, Xcode, Arm Performance Studio; для frametime — RivaTuner, Special K, MangoHud ([General optimization tips](https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html)).

```gdscript
# Своя метрика в Debugger → Monitors
func _ready() -> void:
	Performance.add_custom_monitor(&"Game/Active enemies", _count_enemies)

func _count_enemies() -> int:
	return get_tree().get_nodes_in_group(&"enemies").size()
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [The Profiler](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html) | документация Godot | Работа с профайлером, Self/Inclusive, разбор пика |
| [Performance](https://docs.godotengine.org/en/stable/classes/class_performance.html) | справочник API | Полный список мониторов и `add_custom_monitor` |
| [Tracy](https://docs.godotengine.org/en/stable/engine_details/development/profiling/tracy.html) | документация Godot (4.6+) | Сборка с Tracy, сервер Tracy, сэмплирование |
| [PR #104851](https://github.com/godotengine/godot/pull/104851) | Ivorforce, ноябрь 2025 | Как устроена интеграция `profiler=tracy/perfetto` |
| [godot-debug-menu](https://github.com/godot-extended-libraries/godot-debug-menu) | Hugo Locurcio | Оверлей FPS, frametime, CPU/GPU time в собранной игре |

---

## VM GDScript и статическая типизация

### Ключевые выводы

- GDScript компилируется в байткод и исполняется VM; значения хранятся в `Variant`. Если типы операндов известны на этапе компиляции, компилятор выдаёт **типизированные инструкции**: VM не ищет оператор по типам в рантайме, а сразу, например, складывает два `int` ([Typed instructions](https://godotengine.org/article/gdscript-progress-report-typed-instructions), George Marques, 2020).
- Замеры автора на debug-сборке: операторы быстрее на 25–50%, вызовы встроенных функций на 25–50%, индексация и доступ к полям на 5–7%, итерация на 10–50%, вызовы методов движка до +120–150% при предвалидированных аргументах. Вывод автора: «чтобы получить максимум, типизируйте всё».
- В [PR #70838](https://github.com/godotengine/godot/pull/70838) (reduz, январь 2023) на release-сборке типизированный вариант теста занял 3.3 мс против 6.4 мс у нетипизированного, то есть почти вдвое быстрее. Это один синтетический тест, но порядок эффекта он показывает.
- Совет «статическая типизация в GDScript не ускоряет код» [устарело]: он верен для Godot 3, где типизированных инструкций не было. В Godot 4 типизация ускоряет.
- Включите предупреждение `UNTYPED_DECLARATION` (Project Settings → Debug → GDScript) в Warn или Error. `:=` выводит тип и считается типизированным объявлением ([Static typing](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html), [обсуждение на форуме](https://forum.godotengine.org/t/better-faster-gdscript-through-static-typing/134532)).
- Типизируйте возвращаемые значения, параметры, переменные цикла (`for e: Enemy in enemies`) и ссылки на узлы. Нетипизированный узел превращает вызов метода движка в динамический поиск.
- `as` при несовпадении типа молча даёт `null`. Для проверки используйте `is`, затем приведение ([Static typing](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)).

```gdscript
# Плохо: каждый вызов и каждая операция ищут тип в рантайме
var speed = 200
func _physics_process(delta):
	var body = $Body
	body.velocity = body.velocity.move_toward(Vector2.ZERO, speed * delta)
	body.move_and_slide()

# Хорошо: типизированные инструкции и прямой вызов метода движка
@export var speed: float = 200.0
@onready var body: CharacterBody2D = $Body

func _physics_process(delta: float) -> void:
	body.velocity = body.velocity.move_toward(Vector2.ZERO, speed * delta)
	body.move_and_slide()
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [GDScript progress report: Typed instructions](https://godotengine.org/article/gdscript-progress-report-typed-instructions) | George Marques, 2020 | Как устроены типизированные инструкции, цифры по категориям |
| [PR #70838: Optimizations for GDScript VM](https://github.com/godotengine/godot/pull/70838) | Juan Linietsky (reduz), 2023 | Таблица debug/release × typed/untyped |
| [Static typing in GDScript](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html) | документация Godot | Синтаксис, предупреждения, `is` против `as`, типизированные коллекции |
| [Yes, your Godot game runs faster with static types](https://www.beep.blog/2024-02-14-gdscript-typing/) | Cariad Eccleston, 2024 | Независимый замер типизированного и нетипизированного кода; страница недоступна для проверки, цифры [не проверено]. Свои цифры — в [замерах](#замеры-харнессом-на-godot-472-debug-сборка-редактора) |
| [Dynamic vs Static Typing Performance for Built-In Types in GDScript](https://essay.utwente.nl/essays/107857) | студенческая работа, Университет Твенте | Академическое сравнение; содержание [не проверено] |
| [Static typing guide](https://uhiyama-lab.com/en/notes/godot/static-typing-gdscript/) | uhiyama-lab | Вторичный практический обзор, без цифр |

---

## Коллекции, строки и Callable

### Ключевые выводы

- `Packed*Array` хранят данные плотно и, по документации, быстрее типизированного `Array` того же типа при итерации и изменении, а памяти тратят меньше. Типизированный `Array[T]` в свою очередь быстрее нетипизированного ([GDScript reference](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html)).
- `Array`, `Dictionary` и Packed-массивы в GDScript передаются по ссылке: `var b := a; b[0] = 100` меняет и `a` (проверено на 4.7.2). Независимую копию даёт `duplicate()`. Исключение — встроенные свойства и методы движка: они возвращают копию Packed-массива (справочник [PackedFloat32Array](https://docs.godotengine.org/en/stable/classes/class_packedfloat32array.html)). Поэтому изменение `line.points[0]` через локальную переменную не меняет `Line2D` (проверено). Присвойте результат обратно.
- Массивы заранее выделяйте через `resize()`, а не растите через `append` в горячем цикле.
- `StringName` дорого создать, но сравнение и хэширование почти бесплатны. Литерал `&"name"` создаётся один раз при компиляции. Используйте его для ключей словарей, групп, имён действий ввода и сигналов.
- Строки неизменяемы: склейка `+=` в цикле создаёт новую строку на каждой итерации. Собирайте части в `PackedStringArray` и вызывайте `"".join(parts)`.
- Разбор текста (слова, токены, числа) делайте одним нативным `RegEx.search_all()`, а не посимвольным циклом на GDScript: в практическом цикле оптимизации подсчёта слов это дало −70…−89% времени. В `RegEx` Godot класс `\w` совпадает **только с ASCII**: `straße` даёт `stra` и `e`, кириллица и CJK не находятся. Для Unicode используйте `[\p{L}\p{Nd}]+` (буквы и десятичные цифры любой письменности, без `_`) или префикс `(*UCP)\w+` (с `_`) (проверено на 4.7.2). Регулярку компилируйте один раз (`static var` или поле), а не на каждый вызов. В GDScript шаблоны удобно писать raw-строками: `r"\w+"`.
- `sort_custom()` вызывает GDScript-функцию на каждое сравнение. Нативный `Array.sort()` на 20 000 строк оказался в 7 раз быстрее `sort_custom` с лямбдой (7 мс против 50 мс, debug-сборка, проверено на 4.7.2). Если порядок выражается естественным сравнением, сортируйте `sort()` по ключу, а для top-N не сортируйте всё: корзины по счётчику или частичный выбор.
- Форматирование `"%s" % [...]` и `str()` в каждом кадре (например, в `Label.text`) стоит заметно. Обновляйте текст только при изменении значения.
- `Callable.call()` и лямбды дороже прямого вызова метода. В godot-benchmarks есть отдельные тесты `lambda_performance` и `for_loop` (прямой вызов) для сравнения ([benchmarks/gdscript](https://github.com/godotengine/godot-benchmarks/tree/main/benchmarks/gdscript)); на 4.7.2 (debug) прямой вызов, `Callable.call()` и вызов лямбды оказались одинаковыми в пределах шума, см. [замеры](#замеры-харнессом-на-godot-472-debug-сборка-редактора). Лямбды захватывают локальные переменные по значению на момент создания.
- `Dictionary[K, V]` (типизированные словари с 4.4) дают проверку типов и типизированные инструкции при чтении значений ([Godot 4.4](https://godotengine.org/releases/4.4/)). Вложенные типизированные коллекции (`Array[Array[int]]`) не поддерживаются.

```gdscript
# Плохо: нетипизированный массив, рост в цикле, склейка строк
var points = []
var log_text = ""
for i in 10000:
	points.append(Vector2(i, i * 2))
	log_text += str(i) + ","

# Хорошо: Packed-массив заданного размера, join
var points := PackedVector2Array()
points.resize(10000)
var parts := PackedStringArray()
for i in 10000:
	points[i] = Vector2(i, i * 2)
	parts.append(str(i))
var log_text := ",".join(parts)
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [GDScript reference: Built-in types](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html) | документация Godot | Packed против типизированных массивов, `StringName`, лямбды |
| [string_manipulation.gd и соседи](https://github.com/godotengine/godot-benchmarks/tree/main/benchmarks/gdscript) | godot-benchmarks | Готовые замеры строковых операций и массивов |

---

## Узлы, дерево сцены и обработка кадров

### Ключевые выводы

- Вес по возрастанию: `Object` < `RefCounted` < `Resource` < `Node`. Каждый узел — участник дерева с уведомлениями, группами, обработкой и, часто, отрисовкой. Для десятков тысяч сущностей держите данные в `RefCounted` или массивах, а узлы используйте для отображения ([Node alternatives](https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html)).
- Кэшируйте ссылки на узлы в `@onready var`. `get_node()` и `$` разбирают путь при каждом вызове; `%UniqueName` удобен, но в горячем цикле тоже лучше кэшировать.
- `_process` вызывается каждый кадр (частота зависит от FPS), `_physics_process` — с фиксированной частотой, по умолчанию 60 раз в секунду ([Idle and physics processing](https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html)). Логику, которой не нужен каждый кадр, переводите на `Timer`, сигналы или проверку раз в N кадров.
- Пустой `_process` не бесплатен: движок вызывает его, если метод определён. Удаляйте пустые колбэки и выключайте обработку через `set_process(false)` и `set_physics_process(false)`, когда узлу нечего делать.
- Ввод обрабатывайте в `_unhandled_input`, а не опросом в `_process` ([Godot notifications](https://docs.godotengine.org/en/stable/tutorials/best_practices/godot_notifications.html)).
- Невидимые узлы продолжают обрабатываться. Удаляйте их из дерева или выключайте `process_mode` ([CPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html)). Для объектов за экраном есть `VisibleOnScreenNotifier2D/3D` и `VisibleOnScreenEnabler2D/3D` ([VisibleOnScreenNotifier2D](https://docs.godotengine.org/en/stable/classes/class_visibleonscreennotifier2d.html)). `VisibilityNotifier`/`VisibilityEnabler` [устарело] → эти классы.
- Сигналы удобны для событий, но не для потока данных «каждая сущность каждый кадр». Тысяча `emit` за кадр — повод собрать данные в массив и обработать одним циклом. На 4.7.2 (debug) `emit` с одним подписчиком стоил около 370 нс, примерно в 2.8 раза дороже прямого вызова (см. [замеры](#замеры-харнессом-на-godot-472-debug-сборка-редактора)).
- Пулинг объектов. В GDScript нет трассирующего сборщика мусора (подсчёт ссылок), поэтому довод «пул спасает от GC», знакомый по Unity, здесь не работает. Пул окупается, если в профайлере видны `instantiate()`, `add_child()` и `_ready()` сложной сцены, например у пуль или всплывающих чисел. В нашем замере на 4.7.2 (debug) цикл `instantiate()` + `add_child` + `free()` сцены из 4 узлов стоил ~37 мкс, а переключение `visible` и `process_mode` у готового экземпляра ~4 мкс (см. [замеры](#замеры-харнессом-на-godot-472-debug-сборка-редактора)). При десятках спавнов за кадр это заметно; при единицах пул не нужен.
- `queue_free()` удаляет узел в конце кадра, `free()` сразу. Массовое удаление тысяч узлов за один кадр даёт рывок; распределяйте по кадрам.
- С 4.4 SceneTree переработан, а запуск сцен в больших проектах ускорен до 3 раз ([Godot 4.4](https://godotengine.org/releases/4.4/)). Советы о «дорогих» операциях с деревом из эпохи 4.0–4.3 перепроверяйте.

```gdscript
# Плохо: путь каждый кадр, опрос ввода, работа даже за экраном
func _process(delta):
	if Input.is_action_just_pressed("fire"):
		get_node("Gun/Muzzle").fire()
	get_node("HealthBar").value = hp

# Хорошо: кэш, событие ввода, обновление UI только при изменении
@onready var _muzzle: Muzzle = %Muzzle
@onready var _bar: ProgressBar = %HealthBar

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fire"):
		_muzzle.fire()

func set_hp(value: int) -> void:
	hp = value
	_bar.value = value

func _on_screen_exited() -> void:  # сигнал VisibleOnScreenNotifier2D
	process_mode = Node.PROCESS_MODE_DISABLED
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [When and how to avoid using nodes for everything](https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html) | документация Godot | Object, RefCounted, Resource и Node: вес и когда что выбирать |
| [Godot notifications](https://docs.godotengine.org/en/stable/tutorials/best_practices/godot_notifications.html) | документация Godot | Timer вместо проверок каждый кадр, ввод через колбэки |
| [Idle and physics processing](https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html) | документация Godot | `_process` против `_physics_process` |
| [Nodes and scene instances](https://docs.godotengine.org/en/stable/tutorials/scripting/nodes_and_scene_instances.html) | документация Godot | `@onready`, `preload`, повторное инстанцирование одной `PackedScene` |
| [Node](https://docs.godotengine.org/en/stable/classes/class_node.html) | справочник API | `process_mode`, `set_process`, `process_thread_group`, `print_orphan_nodes` |

---

## Память, ресурсы и загрузка

### Ключевые выводы

- Узлы не освобождаются автоматически: узел, снятый с дерева через `remove_child()` и забытый, становится «сиротой» и течёт. Следите за монитором `OBJECT_ORPHAN_NODE_COUNT` и вызывайте `Node.print_orphan_nodes()` в debug-сборке ([Node](https://docs.godotengine.org/en/stable/classes/class_node.html)).
- `RefCounted` освобождается, когда исчезает последняя ссылка. Циклические ссылки (A держит B, B держит A) текут; одну сторону сделайте `weakref()` ([RefCounted](https://docs.godotengine.org/en/stable/classes/class_refcounted.html)). В C# такие объекты освобождает GC периодически, а не сразу.
- `load()` кэширует ресурсы по пути: повторный `load()` того же пути возвращает тот же объект, пока он жив. Но поиск в кэше и проверка пути в горячем цикле всё равно лишние: держите ресурс в поле.
- `preload()` загружает при загрузке скрипта, то есть переносит стоимость на старт. Удобно для мелких часто используемых сцен; для тяжёлых уровней это удлиняет запуск.
- Фоновая загрузка: `ResourceLoader.load_threaded_request(path)`, затем опрос `load_threaded_get_status(path, progress)` и `load_threaded_get(path)`. Если вызвать `load_threaded_get` до окончания загрузки, он заблокирует поток, как обычный `load()` ([Background loading](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html)). `ResourceInteractiveLoader` [устарело] → `load_threaded_request`.
- RID серверов не учитываются в подсчёте ссылок ресурса. Держите ссылку на ресурс, пока используете его RID, и освобождайте созданные вами RID через `free_rid()` ([Using servers](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html)).

```gdscript
# Экран загрузки без фриза
const LEVEL := "res://levels/level_2.tscn"
var _progress: Array = []

func _ready() -> void:
	ResourceLoader.load_threaded_request(LEVEL)

func _process(_delta: float) -> void:
	match ResourceLoader.load_threaded_get_status(LEVEL, _progress):
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			%Bar.value = _progress[0] * 100.0
		ResourceLoader.THREAD_LOAD_LOADED:
			set_process(false)
			get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(LEVEL))
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			set_process(false)
			push_error("Не удалось загрузить %s" % LEVEL)
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Background loading](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html) | документация Godot | `load_threaded_*`, когда вызов блокирует |
| [RefCounted](https://docs.godotengine.org/en/stable/classes/class_refcounted.html) | справочник API | Циклы ссылок и `weakref()` |
| [Performance](https://docs.godotengine.org/en/stable/classes/class_performance.html) | справочник API | Мониторы памяти, объектов и сирот |

---

## Рендеринг: батчинг, MultiMesh, серверы, шейдеры

### Ключевые выводы

- **2D-батчинг.** Compatibility-рендерер батчил 2D всегда, а в Forward+ и Mobile батчинг появился в 4.4 ([PR #92797](https://github.com/godotengine/godot/pull/92797), Stuart Carnie). Батч рвётся при смене текстуры, материала или режима смешивания, поэтому общие атласы и общие материалы по-прежнему важны ([GPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html)). Настройки `rendering/batching/*` из Godot 3 [устарело] → батчинг автоматический.
- **3D-инстансинг.** Forward+ автоматически инстансирует одинаковые непрозрачные меши. Для прозрачных и для очень большого числа объектов используйте `MultiMesh` ([Optimizing 3D](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html)).
- **MultiMesh** рисует сотни тысяч экземпляров одним вызовом, но отсекается только целиком. Выделите максимум экземпляров и управляйте `visible_instance_count`; для большого мира разбейте на куски ([Using MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)).
- **Серверы.** Когда даже `MultiMesh` и чистка не помогают (десятки тысяч объектов, обновляемых каждый кадр), рисуйте через `RenderingServer` и считайте физику через `PhysicsServer2D/3D` напрямую, по RID. Не вызывайте в цикле методы серверов, которые что-то возвращают: такой вызов останавливает сервер, пока он не обработает очередь ([Using servers](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html)). `VisualServer`/`Physics2DServer` [устарело] → `RenderingServer`/`PhysicsServer2D`.
- **Рывки компиляции шейдеров.** С 4.4 в Forward+ и Mobile есть ubershaders и предкомпиляция пайплайнов ([PR #90400](https://github.com/godotengine/godot/pull/90400), DarioSamo). С 4.5 есть shader baker при экспорте: в TPS demo на Metal и D3D12 загрузка сократилась в 20 раз ([Godot 4.5](https://godotengine.org/releases/4.5/)). Оставшиеся рывки появляются, если фичи (MSAA, пробы, VoxelGI, SDFGI) включаются посреди игры. Включайте их на загрузке, следите за мониторами Pipeline Compilations ([Pipeline compilations](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html)).
- Совет «покажите все материалы на кадр при загрузке» [устарело] для Forward+/Mobile с 4.4, но всё ещё нужен в Compatibility (web, старое железо).
- **3D-отсечение и LOD.** Frustum culling работает автоматически. Для закрытых уровней нужен `OccluderInstance3D`. Mesh LOD генерируется при импорте; для иерархий используйте visibility ranges. Fade у visibility ranges временно делает объект прозрачным, а это дорого ([Visibility ranges](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html), [Mesh LOD](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html), [Occlusion culling](https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html)). Rooms & Portals из 3.5 [устарело] → `OccluderInstance3D`.
- **Свежие оптимизации движка.** 4.6: переписанный SSR с режимом половинного разрешения, более дешёвые reflection probes, glow без потери скорости ([Godot 4.6](https://godotengine.org/releases/4.6/)). 4.7: отдельные буферы окружения на проход, foveated rendering для XR ([Godot 4.7](https://godotengine.org/releases/4.7/)). Обновление движка часто даёт больше, чем ручной тюнинг.
- Перерисовка своего `_draw()`: вызывайте `queue_redraw()` только при изменении данных. `update()` [устарело] → `queue_redraw()`.

```gdscript
# 10 000 одинаковых объектов одним вызовом отрисовки
@onready var mmi: MultiMeshInstance2D = $Stars

func _ready() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.mesh = preload("res://star_quad.tres")
	mm.instance_count = 10_000
	mm.visible_instance_count = 2_000  # остальные включим позже
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in mm.instance_count:
		mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(rng.randf() * 1920.0, rng.randf() * 1080.0)))
	mmi.multimesh = mm
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [GPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html) | документация Godot | Draw calls, батчинг, атласы, fill rate, overdraw, тайловые мобильные GPU |
| [Optimizing 3D performance](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html) | документация Godot | Отсечение, LOD, прозрачность, свет, большие миры |
| [Optimization using Servers](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html) | документация Godot | RID, примеры `RenderingServer` и `PhysicsServer2D` |
| [Optimization using MultiMeshes](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html) | документация Godot | Ограничения отсечения и `visible_instance_count` |
| [Reducing stutter from shader (pipeline) compilations](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html) | документация Godot (4.4+) | Ubershaders, shader baker, мониторы, чек-лист против рывков |
| [PR #90400: Ubershaders and pipeline pre-compilation](https://github.com/godotengine/godot/pull/90400) | DarioSamo, 2024 | Как это устроено и цена: +5.9% ко времени старта TPS demo |
| [Rendering priorities: September 2024](https://godotengine.org/article/rendering-priorities-september-2024/) | Clay John, 2024 | Производительность рендерера стала приоритетом №1 |

---

## Физика и навигация

### Ключевые выводы

- Простые формы коллизий (круг, капсула, бокс) намного дешевле `ConcavePolygonShape`/trimesh. Слои и маски отсекают ненужные пары ещё до проверки форм ([CPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html)).
- Частоту физики можно понизить (`physics/common/physics_ticks_per_second`, например до 30), а плавность вернуть физической интерполяцией. Цена — больше задержка ввода ([Physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html)). 2D-интерполяция есть с 4.3, 3D с 4.4; в 4.5 3D-интерполяция переехала из RenderingServer в SceneTree ([Godot 4.5](https://godotengine.org/releases/4.5/)).
- Jolt встроен с 4.4. С 4.6 Project Manager прописывает его в новые 3D-проекты, а старые проекты и проекты без ключа `physics/3d/physics_engine` остаются на GodotPhysics (проверено на 4.7.2, [Godot 4.6](https://godotengine.org/releases/4.6/)). У Jolt другие допущения: нет softness/bias у суставов, контакты кинематических тел со статикой по умолчанию выключены ради скорости ([Using Jolt](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html)). Аддон Godot Jolt [устарело] → встроенный модуль. На 2D Jolt не распространяется.
- Навигация: цена поиска пути зависит от числа полигонов и рёбер navmesh, а не от размера мира. Не перезапрашивайте путь каждый кадр, только при заметном смещении цели. Запекайте navmesh в фоновом потоке, парсите формы коллизий, а не визуальные меши, сливайте navmesh по вершинам ([Navigation performance](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_optimizing_performance.html)). С 4.5 у 2D-навигации свой сервер, и 2D-игре не нужен 3D-модуль ([Godot 4.5](https://godotengine.org/releases/4.5/)).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html) | документация Godot | Зачем фиксированный тик и как интерполяция убирает дёрганье |
| [Using Jolt Physics](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html) | документация Godot | Отличия от GodotPhysics и настройки |
| [Optimizing navigation performance](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_optimizing_performance.html) | документация Godot | Парсинг, запекание, сложность navmesh, частота запросов |

---

## Потоки

### Ключевые выводы

- Активное дерево сцены не потокобезопасно. Собирайте поддерево в потоке вне дерева, затем добавляйте через `add_child.call_deferred(node)` ([Thread-safe APIs](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html)).
- Читать и писать элементы `Array`/`Dictionary` из разных потоков можно, а менять размер — только под `Mutex`.
- Для параллельной обработки массива берите `WorkerThreadPool.add_group_task(callable, count)` и `wait_for_group_task_completion(id)` ([WorkerThreadPool](https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html)). Каждая задача должна писать только в свой срез данных.
- Создавать `Thread` дорого, особенно на Windows. Создавайте потоки заранее или используйте пул. Не забывайте `wait_to_finish()`. Частые блокировки `Mutex` съедают выигрыш ([Using multiple threads](https://docs.godotengine.org/en/stable/tutorials/performance/using_multiple_threads.html)).
- `process_thread_group = PROCESS_THREAD_GROUP_SUB_THREAD` позволяет обрабатывать ветку дерева в отдельном потоке, но требует потокобезопасного общения с остальной сценой ([Node](https://docs.godotengine.org/en/stable/classes/class_node.html)).
- В web-экспорте по умолчанию потоков нет (с 4.3), так что код с потоками должен работать и без них.

```gdscript
# Обычный Array: запись элементов из разных потоков допустима, resize — нет
var _positions: Array[Vector2] = []
var _velocities: Array[Vector2] = []
var _dt := 0.0

func step(delta: float) -> void:
	_dt = delta
	var id := WorkerThreadPool.add_group_task(_integrate, _positions.size())
	WorkerThreadPool.wait_for_group_task_completion(id)

func _integrate(i: int) -> void:  # каждый вызов пишет только в свой элемент
	_positions[i] += _velocities[i] * _dt
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Using multiple threads](https://docs.godotengine.org/en/stable/tutorials/performance/using_multiple_threads.html) | документация Godot | Thread, Mutex, Semaphore, цена создания потоков |
| [Thread-safe APIs](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html) | документация Godot | Что можно делать из потока: дерево, серверы, контейнеры, ресурсы |
| [WorkerThreadPool](https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html) | справочник API | `add_task`, `add_group_task`, ожидание |

---

## Когда переносить код в C#, C++ или Rust

### Ключевые выводы

- Официальная позиция: C# и GDScript находятся «в пределах одного порядка» по скорости, C++ быстрее обоих ([FAQ](https://docs.godotengine.org/en/stable/about/faq.html)). C# быстрее на чистых вычислениях, но может оказаться медленнее GDScript при множестве вызовов API движка из-за маршалинга.
- Переносите, когда профиль показывает **чистые вычисления** в GDScript (процедурная генерация, поиск по сетке, симуляция частиц на CPU, парсинг больших файлов), которые не уменьшаются ни алгоритмом, ни типизацией. Если же время уходит на вызовы движка, рендеринг или физику, другой язык не поможет.
- Переносите ядро, а не всё подряд: функция GDExtension получает Packed-массив, считает и возвращает результат одним вызовом. Тысячи мелких вызовов через границу языков съедают выигрыш.
- Порядок ускорения при переносе чистой математики в C++ или Rust часто называют «в десятки раз» [не проверено: первичного замера не найдено]. Меряйте свой случай; в godot-benchmarks есть категория C++ для сравнения.
- C#: кэшируйте свойства `GodotObject` в локальные переменные, не гоняйте `string` туда, где API ждёт `StringName`/`NodePath`, внутри логики используйте коллекции .NET ([C# basics](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_basics.html)). Встроенный профайлер Godot C# не видит. По документации stable C#-проекты Godot 4 не экспортируются в web.
- GDExtension: C++ через godot-cpp (ветка должна совпадать с версией движка) или Rust через gdext. GDNative [устарело] → GDExtension; Mono [устарело] → .NET (CoreCLR) с 4.0 ([What's new in C# for Godot 4.0](https://godotengine.org/article/whats-new-in-csharp-for-godot-4-0/)).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [FAQ: Which programming language is fastest?](https://docs.godotengine.org/en/stable/about/faq.html) | документация Godot | Официальное сравнение GDScript, C#, C++ |
| [C# basics](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_basics.html) | документация Godot | Маршалинг, кэширование свойств, ограничения экспорта |
| [What's new in C# for Godot 4.0](https://godotengine.org/article/whats-new-in-csharp-for-godot-4-0/) | Raul Santos, 2023 | CoreCLR, source generators, `Variant` без боксинга |
| [GDExtension C++ example](https://docs.godotengine.org/en/stable/tutorials/scripting/cpp/gdextension_cpp_example.html) | документация Godot | Минимальный модуль на godot-cpp |
| [The godot-rust book](https://godot-rust.github.io/book/) | godot-rust | Rust-биндинг gdext для Godot 4 |

---

## Сборка, экспорт, web и мобильные

### Ключевые выводы

- Release-шаблон экспорта быстрее debug: отключены проверки и отладочные пути VM. Профилируйте debug, итоговые цифры снимайте с release.
- Свой шаблон экспорта: `optimize=size` или `optimize=size_extra` (4.5+), `lto=full`, `disable_3d=yes` (около −15% для 2D-игры), `disable_advanced_gui=yes`, `disable_physics_2d/3d=yes`, отключение модулей ([Optimizing for size](https://docs.godotengine.org/en/stable/engine_details/development/compiling/optimizing_for_size.html)). Это прежде всего размер и время загрузки, особенно для web.
- Engine Compilation Configuration editor умеет «Detect from Project» и сохраняет профиль `.gdbuild`, который передаётся в `scons target=template_release build_profile=...`. Фичи, используемые динамически (через `Expression`, GDExtension, загружаемые паки), он не видит ([Configuration editor](https://docs.godotengine.org/en/stable/tutorials/editor/using_engine_compilation_configuration_editor.html)).
- **Web.** Только Compatibility-рендерер (WebGL 2). С 4.3 экспорт по умолчанию однопоточный, потому что потоки требуют COOP/COEP-заголовков и ломают itch.io и веб-порталы ([Exporting for Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html), [Web export in 4.3](https://godotengine.org/article/progress-report-web-export-in-4-3/)). Для звука без потоков есть режим Sample playback. С 4.5 web-сборки используют WASM SIMD ([Godot 4.5](https://godotengine.org/releases/4.5/)). Совет «включите threads в web-экспорте» [устарело] для большинства случаев.
- **Мобильные.** Рендерер Mobile с 4.5 использует FP16, где железо поддерживает ([Godot 4.5](https://godotengine.org/releases/4.5/)). Главные враги — overdraw и fill rate на тайловых GPU, динамические тени и полноэкранные эффекты ([GPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html)). Ограничьте FPS (`application/run/max_fps`) ради батареи и нагрева.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Optimizing a build for size](https://docs.godotengine.org/en/stable/engine_details/development/compiling/optimizing_for_size.html) | документация Godot | Все флаги SCons для урезанных шаблонов |
| [Using the engine compilation configuration editor](https://docs.godotengine.org/en/stable/tutorials/editor/using_engine_compilation_configuration_editor.html) | документация Godot | Автоопределение фич и `.gdbuild` |
| [Exporting for the Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html) | документация Godot | Потоки против однопоточной сборки, ограничения |
| [Progress report: Web export in 4.3](https://godotengine.org/article/progress-report-web-export-in-4-3/) | Adam Scott, 2024 | Почему отказались от потоков по умолчанию |

---

## Разборы реальных случаев

### Ключевые выводы

- **Огромный TileMap в 2D** ([issue #85871](https://github.com/godotengine/godot/issues/85871), Godot 4.2, декабрь 2023). При отдалении камеры Forward+ работал хуже Compatibility, вплоть до падений. Причина — отсутствие 2D-батчинга в RD-рендерерах. После [PR #92797](https://github.com/godotengine/godot/pull/92797) (4.4) та же сцена на MacBook M1: около 573 440 draw calls → 36, примерно 10 FPS → больше 130 FPS. Урок: проверяйте `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` и обновляйте движок, прежде чем переписывать сцену.
- **Рывки шейдеров в TPS demo** ([PR #90400](https://github.com/godotengine/godot/pull/90400)). Ubershaders и предкомпиляция убрали рывки при первой встрече эффектов ценой +5.9% ко времени старта (2.412 → 2.555 с с холодным кэшем драйвера). Shader baker в 4.5 сократил загрузку той же демки в 20 раз на Metal и D3D12 ([Godot 4.5](https://godotengine.org/releases/4.5/)).
- **Типизация VM** ([PR #70838](https://github.com/godotengine/godot/pull/70838)). Переделка диспетчеризации VM дала около 40% на типизированном коде в release; разрыв typed/untyped вырос до почти 2 раз. Урок: та же логика с типами получает ускорение от каждой оптимизации VM, без типов — меньше.
- **Тысячи объектов без узлов.** Документация показывает тысячи рыб одним `MultiMeshInstance3D` с анимацией в вершинном шейдере ([Animating thousands of fish](https://docs.godotengine.org/en/stable/tutorials/performance/vertex_animation/animating_thousands_of_fish.html)). Linietsky предлагает тот же путь для city builder и стратегий: выборочная обработка, серверы, GPU compute ([Why isn't Godot ECS-based](https://godotengine.org/article/why-isnt-godot-ecs-based-game-engine/)).
- Общий урок: крупнейшие выигрыши дают обновление движка, устранение работы и смена представления данных (узлы → массивы → MultiMesh/серверы). Типизация добавляет десятки процентов поверх, перенос в C++ нужен редко и точечно.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Issue #85871](https://github.com/godotengine/godot/issues/85871) | SlyRebula, 2023 | Исходный отчёт с проектом-репро |
| [PR #92797: Add batching to RendererCanvasRenderRD](https://github.com/godotengine/godot/pull/92797) | Stuart Carnie, 2024 | Цифры до и после на разных машинах |
| [Godot 4.5 release](https://godotengine.org/releases/4.5/) | Godot Foundation, 2025 | Shader baker и замер на TPS demo |
| [Godot 4.4 release](https://godotengine.org/releases/4.4/) | Godot Foundation, 2025 | Ubershaders, Jolt, ускорение SceneTree |

---

## Антипаттерны

### Ключевые выводы

- Ловите их профайлером, мониторами и предупреждениями GDScript (`UNTYPED_DECLARATION`, `UNSAFE_*`). Большинство исправляется локально.
- Если код не в горячем пути, читаемость важнее. Не переписывайте всё ради микросекунд.

| Антипаттерн | Почему плохо | Замена |
|---|---|---|
| Выводы по замеру в редакторе как по абсолютным цифрам | Debug в 4–5 раз медленнее release | Сравнивать варианты в одной сборке, итог — в release-экспорте |
| Один замер без повторов и прогрева | Шум таймера и ОС больше эффекта | Харнесс выше: прогрев, 15 прогонов, медиана |
| Нетипизированный код в горячем пути | Нет типизированных инструкций, вызовы движка ищутся динамически | Типы везде, `UNTYPED_DECLARATION` = Error |
| `get_node()`/`$` в `_process` | Разбор пути каждый кадр | `@onready var` |
| `_process` у тысяч узлов, которые ждут события | Вызов на каждый узел каждый кадр | Сигналы, `Timer`, `set_process(false)` |
| Пустые `_process`/`_physics_process` из шаблона скрипта | Движок всё равно их вызывает | Удалить |
| Опрос ввода в `_process` | Лишняя работа каждый кадр | `_unhandled_input` |
| `visible = false` вместо отключения | Логика и обработка продолжаются | `process_mode = DISABLED` или снятие с дерева |
| Узел на каждую сущность-данные (клетка сетки, пуля, частица-логика) | Вес Node, нагрузка на SceneTree | `RefCounted`, Packed-массивы, `MultiMesh`, серверы |
| Нетипизированный `Array` чисел | Каждый элемент — `Variant`, медленнее и толще | `PackedFloat32Array`, `Array[float]` |
| Склейка строк `+=` в цикле, `str()` в `Label.text` каждый кадр | Аллокации на каждой итерации | `PackedStringArray` + `join`, обновление по изменению |
| Строковые ключи, создаваемые в цикле | Хэширование строки при каждом поиске | `StringName` (`&"key"`) |
| Лямбда или `Callable.call()` в tight loop без нужды | Дороже прямого вызова | Прямой вызов метода |
| `load()` в цикле или при каждом спавне | Поиск в кэше, возможна синхронная загрузка | `preload` или ресурс в поле |
| Синхронный `load()` уровня в игровом кадре | Фриз | `load_threaded_request` |
| `remove_child()` без `queue_free()` | Сироты и утечка памяти | `queue_free()`, мониторинг `OBJECT_ORPHAN_NODE_COUNT` |
| Циклические ссылки `RefCounted` | Объекты никогда не освобождаются | `weakref()` для обратной ссылки |
| Запрос значений у `RenderingServer`/`PhysicsServer` каждый кадр | Синхронизация и остановка сервера | Держать состояние у себя, писать в сервер односторонне |
| Включение MSAA, GI или новых эффектов посреди игры | Компиляция пайплайнов и рывок | Включать на загрузке или в меню настроек |
| Trimesh-коллизии у подвижных объектов | Дорогая проверка пересечений | Примитивы или convex |
| Перестройка пути навигации каждый кадр | Поиск по navmesh каждый кадр | Перезапрос при заметном смещении цели |
| `Thread.new()` на каждую мелкую задачу | Создание потока дорогое | `WorkerThreadPool` |
| Изменение активного дерева из потока | Гонки и падения | Сборка вне дерева + `call_deferred` |
| «Перепишу всё на C++, и станет быстро» | Узкое место часто в рендеринге, физике или алгоритме | Профиль, затем перенос только вычислительного ядра |
| Советы эпохи Godot 3: `VisualServer`, `VisibilityEnabler`, `PoolIntArray`, `funcref`, `yield`, `ResourceInteractiveLoader`, настройки GLES-батчинга [устарело] | API переименованы или устарели, поведение другое | `RenderingServer`, `VisibleOnScreenEnabler2D/3D`, `PackedInt32Array`, `Callable`, `await`, `load_threaded_request`, автоматический батчинг |

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [CPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html) | документация Godot | Большинство CPU-антипаттернов и как их найти |
| [GPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html) | документация Godot | Антипаттерны рендеринга и мобильных GPU |
| [Godot 4.6 release](https://godotengine.org/releases/4.6/) | Godot Foundation, январь 2026 | Jolt по умолчанию, трассирующие профайлеры, ускорения рендеринга |
| [Maintenance release: Godot 4.7.2](https://godotengine.org/article/maintenance-release-godot-4-7-2/) | Thaddeus Crews, август 2026 | Текущий stable-патч, исправления производительности ввода на Windows |

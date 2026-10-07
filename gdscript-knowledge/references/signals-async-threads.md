# Сигналы, await, потоки и сеть в GDScript

Справочник по событийной модели Godot (сигналы и `await`), отложенным вызовам, многопоточности (`Thread`, `WorkerThreadPool`, группы потоков узлов, фоновая загрузка), сетевому вводу-выводу и высокоуровневому мультиплееру. Актуально на октябрь 2026 года: стабильная версия Godot 4.7.2 (4.7 вышла 18 июня 2026, 4.8 ещё нет). Главные ловушки: корутины, которые ждут сигнал от уже освобождённого объекта, обращение к дереву сцены из потока и доверие данным клиента.

- [Канонические источники](#канонические-источники)
- [Сигналы](#сигналы)
- [await и корутины](#await-и-корутины)
- [Отложенные вызовы](#отложенные-вызовы)
- [Потоки: Thread, Mutex, Semaphore](#потоки-thread-mutex-semaphore)
- [WorkerThreadPool и группы потоков](#workerthreadpool-и-группы-потоков)
- [Потокобезопасные API и фоновая загрузка](#потокобезопасные-api-и-фоновая-загрузка)
- [HTTP, WebSocket, TCP, UDP](#http-websocket-tcp-udp)
- [Высокоуровневый мультиплеер](#высокоуровневый-мультиплеер)
- [Безопасность сети](#безопасность-сети)
- [Выделенный сервер, WebRTC, Steam, rollback](#выделенный-сервер-webrtc-steam-rollback)
- [Внешние процессы](#внешние-процессы)
- [Что устарело после Godot 3](#что-устарело-после-godot-3)
- [Что выбрать](#что-выбрать)
- [Чеклист review: асинхронный, многопоточный и сетевой GDScript](#чеклист-review-асинхронный-многопоточный-и-сетевой-gdscript)

## Канонические источники

**Ключевые выводы**
- Первичные источники — официальная документация (ветка `stable` = 4.7): страницы «Using multiple threads», «Thread-safe APIs», «High-level multiplayer» и справочник классов. Блоги и форумы полезны, но часто написаны под Godot 3 или C#.
- Поведение корутин при освобождении объектов документировано плохо. Его приходится восстанавливать по открытым issue (#120998, #99383).
- Перед опорой на мелкие детали сверяться со справочником класса своей версии: в 4.x API сети и потоков менялся между минорными версиями.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [GDScript reference](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html) | Godot docs, 4.7 | Сигналы, `await`, лямбды и их захват переменных |
| [Using signals](https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html) | Godot docs, 4.7 | Сигналы как первоклассный тип, соглашения об именах |
| [Using multiple threads](https://docs.godotengine.org/en/stable/tutorials/performance/using_multiple_threads.html) | Godot docs, 4.7 | `Thread`, `Mutex`, `Semaphore`, порядок завершения потока |
| [Thread-safe APIs](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html) | Godot docs, 4.7 | Что можно трогать из потока, а что нет |
| [High-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html) | Godot docs, 4.7 | `@rpc`, authority, безопасность, ENet |
| [Godot 4.7 release](https://godotengine.org/releases/4.7/) | Godot Foundation, 2026 | Новое в 4.7, в том числе `Tween.tween_await()` |
| [Release blog](https://godotengine.org/blog/release/) | Godot Foundation, живой | Текущие maintenance-релизы (4.7.2 от 18.08.2026) |

## Сигналы

**Ключевые выводы**
- С Godot 4.0 сигналы и методы — значения типов `Signal` и `Callable`. Подключать через `signal.connect(callable)`, а не строками.
- `emit()` не проверяет ни число, ни типы аргументов: документация прямо говорит, что правильные значения передавать вам. На 4.7.2 `emit("str")` в сигнал `(v: int)` проходит; ошибку `Cannot convert argument 1 from String to int` печатает только вызов типизированного обработчика, а нетипизированный получает строку (проверено на 4.7.2). Объявлять сигналы с типизированными параметрами и писать обработчики с той же сигнатурой.
- Повторный `connect()` того же `Callable` возвращает `ERR_INVALID_PARAMETER` и печатает ошибку. Проверять `is_connected()` или осознанно использовать `CONNECT_REFERENCE_COUNTED` (код 31 = `ERR_INVALID_PARAMETER`, проверено на 4.7.2).
- Когда объект-получатель освобождается, соединение исчезает само («If the callable's object is freed, the connection will be lost»). Для методов узлов явный `disconnect()` обычно не нужен.
- Лямбды захватывают локальные переменные по значению один раз, в момент создания. Лямбда без `self` не привязана к получателю, поэтому живёт столько же, сколько эмиттер. Если она захватила узел, который потом освобождён, при вызове будет ошибка `Lambda capture at index 0 was freed. Passed "null" instead.`, а обращение к члену захваченного узла внутри лямбды — ошибка скрипта (проверено на 4.7.2). Для долгоживущих эмиттеров (autoload, глобальная шина событий) подключать методы, а не лямбды, либо отключать в `_exit_tree()`.
- `bind()` добавляет аргументы после аргументов сигнала, `unbind(n)` отбрасывает последние n.

| Флаг `ConnectFlags` | Поведение | Когда |
|---|---|---|
| `CONNECT_DEFERRED` | Вызов в idle time, в конце кадра | Обработчик меняет физику или дерево во время колбэка физики |
| `CONNECT_ONE_SHOT` | Отключается после первой эмиссии | Разовые события («анимация закончилась один раз») |
| `CONNECT_REFERENCE_COUNTED` | Тот же `Callable` можно подключить несколько раз, `disconnect` уменьшает счётчик | Несколько подсистем подписывают один обработчик |
| `CONNECT_PERSIST` | Соединение сохраняется в `PackedScene.pack()` | Инструменты редактора, сохранение сцен |
| `CONNECT_APPEND_SOURCE_OBJECT` | Источник добавляется последним аргументом | Один обработчик на много эмиттеров; появился в 4.5 ([PR #60143](https://github.com/godotengine/godot/pull/60143)), работает на 4.7.2 (проверено) |

```gdscript
signal health_changed(old_value: int, new_value: int)

var _score_lambda := func(score: int) -> void: $ScoreLabel.text = str(score)

func _ready() -> void:
    EventBus.score_changed.connect(_score_lambda)
    # правильно: метод, типизированный сигнал, флаг через побитовое ИЛИ
    $Hurtbox.area_entered.connect(_on_hurtbox_area_entered, CONNECT_DEFERRED)
    EventBus.level_finished.connect(_on_level_finished, CONNECT_ONE_SHOT)

func _exit_tree() -> void:
    # лямбды на долгоживущем эмиттере отключаем сами
    if EventBus.score_changed.is_connected(_score_lambda):
        EventBus.score_changed.disconnect(_score_lambda)

# неправильно (Godot 3): connect("area_entered", self, "_on_area_entered")
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Object: ConnectFlags, call_deferred](https://docs.godotengine.org/en/stable/classes/class_object.html) | Godot docs, 4.7 | Точные формулировки флагов и отложенных вызовов |
| [Signal](https://docs.godotengine.org/en/stable/classes/class_signal.html) | Godot docs, 4.7 | `connect`, `is_connected`, `get_connections`, ошибки при дублях |
| [Callable](https://docs.godotengine.org/en/stable/classes/class_callable.html) | Godot docs, 4.7 | `bind`/`unbind`, `is_valid` против `is_null`, `call_deferred` |
| [Issue #110209](https://github.com/godotengine/godot/issues/110209) | godotengine, открыт | Метод внутреннего класса, подключённый из другого скрипта, не вызывается |
| [Issue #94438](https://github.com/godotengine/godot/issues/94438) | godotengine, закрыт | Лишние ссылки мешают освобождению ресурсов |

## await и корутины

**Ключевые выводы**
- `await signal` приостанавливает функцию до эмиссии. Функция с `await` становится корутиной, и вызывающий тоже должен писать `await`, если ему нужен результат. Запрос результата корутины без `await` — ошибка.
- `await` на выражении, которое не сигнал и не корутина, возвращает значение сразу и управление не отдаёт.
- Сигнал с одним аргументом даёт этот аргумент; с несколькими — `Array`.
- Корутина, которая ждёт сигнал от объекта, освобождённого до эмиссии, не продолжится никогда. Её состояние (`GDScriptFunctionState`) утекает: [#99383](https://github.com/godotengine/godot/issues/99383), открыт. Зависание воспроизводится на 4.7.2 (проверено).
- В Godot 4.7 есть регрессия: если вызывающий ждёт корутину объекта, а объект освобождён, вызывающий зависает навсегда ([#120998](https://github.com/godotengine/godot/issues/120998), открыт, июль 2026; на 4.7.2 воспроизводится, проверено). Цепочки «кат-сцена ждёт NPC» защищать отдельным сигналом отмены или таймаутом.
- `get_tree().create_timer()` по умолчанию имеет `process_always = true`: такой таймер **тикает во время паузы** (проверено на 4.7.2: при `paused = true` таймер по умолчанию сработал, с `false` — только после снятия паузы). Для игровых задержек передавать `false`.
- Таймер дерева не привязан к узлу. В старых версиях корутина после `queue_free()` могла выполниться ещё раз в следующем кадре ([#93608](https://github.com/godotengine/godot/issues/93608), закрыт в марте 2026); на 4.7.2 это не воспроизводится (проверено). Проверка `is_instance_valid(self)` или `is_inside_tree()` после `await` всё равно нужна, если узел могли снять с дерева, не освобождая, и для кода под старые версии.
- `await tween.finished` зависнет, если твин убит через `kill()` или зациклен навсегда (`finished` при бесконечном цикле не эмитится). В 4.7 появился `Tween.tween_await(signal)`: твин сам ждёт сигнал.
- Ожидание кадра: `await get_tree().process_frame` или `physics_frame`. Не писать `await get_tree().create_timer(0)` ради этого.

```gdscript
# правильно: таймаут, пауза учитывается, проверка жизни после await
func open_door_after(seconds: float) -> void:
    await get_tree().create_timer(seconds, false).timeout  # process_always = false
    if not is_instance_valid(self) or not is_inside_tree():
        return
    $Door.open()

# ожидание «сигнал или таймаут» через промежуточный сигнал
signal _race_done(ok: bool)

func wait_or_timeout(sig: Signal, timeout: float) -> bool:
    var on_sig := func(_a = null, _b = null, _c = null): _race_done.emit(true)
    sig.connect(on_sig, CONNECT_ONE_SHOT)
    get_tree().create_timer(timeout, false).timeout.connect(
        func(): _race_done.emit(false), CONNECT_ONE_SHOT)
    var ok: bool = await _race_done
    if sig.is_connected(on_sig):
        sig.disconnect(on_sig)
    return ok
```

Неправильно: `await enemy.died` без таймаута — если враг освобождён до эмиссии, корутина повиснет и утечёт. Параметры по умолчанию у `on_sig` нужны, чтобы лямбда подходила к сигналам с 0–3 аргументами: на 4.7.2 она принимает 0 и 2 аргумента, а на 4 аргумента выдаёт ошибку вызова (проверено). Для сигналов с большим числом аргументов пишите обёртку под конкретный сигнал.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [SceneTree.create_timer](https://docs.godotengine.org/en/stable/classes/class_scenetree.html) | Godot docs, 4.7 | Параметры `process_always`, `process_in_physics`, `ignore_time_scale` |
| [Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html) | Godot docs, 4.7 | `tween_await`, `bind_node`, когда `finished` не эмитится |
| [Issue #120998](https://github.com/godotengine/godot/issues/120998) | godotengine, 2026 | Регрессия 4.7: зависание await при освобождении владельца |
| [Issue #99383](https://github.com/godotengine/godot/issues/99383) | godotengine, 2024 | Утечка `GDScriptFunctionState` и твинов |
| [Issue #93608](https://github.com/godotengine/godot/issues/93608) | godotengine, 2024 | Лишний запуск корутины после `queue_free()` |
| [Issue #116649](https://github.com/godotengine/godot/issues/116649) | godotengine, 2026 | Деструкторы локальных переменных удалённой корутины |
| [Issue #113832](https://github.com/godotengine/godot/issues/113832) | godotengine, открыт | Async-функция ресурса без `await` молча обрывается |
| [Корутина зависает на tween.finished после kill()](https://forum.godotengine.org/t/coroutines-hangs-on-tween-finished-if-tween-kill-is-called/131958) | форум Godot | Живой пример ловушки |

## Отложенные вызовы

**Ключевые выводы**
- `call_deferred()` и `set_deferred()` выполняются в idle time (в конце кадра). `call_deferred()` всегда возвращает `null`, а не результат.
- Внутри колбэков физики (`body_entered`, `area_entered`) нельзя менять состояние физики напрямую: `set_deferred("disabled", true)` для `CollisionShape2D/3D`, `call_deferred("add_child", node)` или `add_child.call_deferred(node)`.
- Не вызывать метод отложенно из него же: бесконечная рекурсия по кадрам.
- Из рабочего потока к дереву сцены обращаться только через `call_deferred`/`set_deferred` или `Node.call_thread_safe()`.

```gdscript
func _on_area_entered(area: Area2D) -> void:
    $CollisionShape2D.set_deferred("disabled", true)   # правильно
    spawn_pickup.call_deferred(area.global_position)  # Callable.call_deferred
    # неправильно: $CollisionShape2D.disabled = true -> ошибка «flushing queries»
```

## Потоки: Thread, Mutex, Semaphore

**Ключевые выводы**
- `Thread.start(callable, priority)` запускает функцию. Перед освобождением объекта `Thread` обязательно вызвать `wait_to_finish()`, иначе возможны падение или дедлок. Типичное место — `_exit_tree()`.
- Создание потока медленное, особенно на Windows. Долгоживущих воркеров создавать заранее, на этапе загрузки; разовые задачи отдавать в `WorkerThreadPool`.
- `Mutex` в Godot реентерабельный: тот же поток может захватить его повторно, но `unlock()` должно быть столько же. На момент уничтожения ни один `Mutex` не должен быть захвачен, ни один поток не должен ждать `Semaphore`.
- `Semaphore` — для воркера «спит, пока нет работы»: `wait()` в потоке, `post()` из главного. Для остановки — флаг под мьютексом плюс `post()`.
- `Thread.set_thread_safety_checks_enabled(false)` отключает проверки движка для текущего потока. Использовать только если вы точно синхронизируете всё сами.

```gdscript
var _thread := Thread.new()
var _mutex := Mutex.new()
var _sem := Semaphore.new()
var _quit := false
var _jobs: Array[PackedByteArray] = []

func _ready() -> void:
    _thread.start(_worker)

func push_job(data: PackedByteArray) -> void:
    _mutex.lock()
    _jobs.append(data)        # меняет размер массива -> только под мьютексом
    _mutex.unlock()
    _sem.post()

func _worker() -> void:
    while true:
        _sem.wait()
        _mutex.lock()
        var quit := _quit
        var job: PackedByteArray = _jobs.pop_front() if not _jobs.is_empty() else PackedByteArray()
        _mutex.unlock()
        if quit:
            return
        var result := _process_job(job)            # тяжёлая работа без доступа к дереву
        _on_job_done.call_deferred(result)         # в главный поток

func _exit_tree() -> void:
    _mutex.lock()
    _quit = true
    _mutex.unlock()
    _sem.post()
    _thread.wait_to_finish()
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Thread](https://docs.godotengine.org/en/stable/classes/class_thread.html) | Godot docs, 4.7 | Условия безопасного уничтожения, `is_alive`, `is_main_thread` |
| [Mutex](https://docs.godotengine.org/en/stable/classes/class_mutex.html) | Godot docs, 4.7 | Реентерабельность, `try_lock` |
| [Semaphore](https://docs.godotengine.org/en/stable/classes/class_semaphore.html) | Godot docs, 4.7 | `post(count)`, `try_wait` |
| [Using multiple threads](https://docs.godotengine.org/en/stable/tutorials/performance/using_multiple_threads.html) | Godot docs, 4.7 | Полный пример с семафором |

## WorkerThreadPool и группы потоков

**Ключевые выводы**
- `WorkerThreadPool.add_task(callable, high_priority)` — одна задача. `add_group_task(callable, elements, tasks_needed, high_priority)` — параллельный цикл: колбэк получает индекс от 0 до `elements - 1`.
- Каждую задачу нужно когда-нибудь дождаться (`wait_for_task_completion` / `wait_for_group_task_completion`), иначе ресурсы задачи не освобождаются. Неблокирующая проверка — `is_task_completed()` в `_process`.
- Мелкие задачи пул замедляют. Группировать работу крупными кусками и измерять.
- Колбэк группы пишет только в свою ячейку заранее выделенного массива: запись элемента без изменения размера потокобезопасна, `append` — нет.
- Группы потоков узлов (4.1+): `process_thread_group = SUB_THREAD` выполняет `_process` поддерева в пуле. В 4.1 функция объявлена экспериментальной; в справочнике класса `Node` версии 4.7.2 свойства `process_thread_group*` уже не помечены как experimental (проверено по `doc/classes/Node.xml` тега `4.7.2-stable`). Внутри такой группы трогать узлы вне группы через `call_deferred_thread_group()`, `call_thread_safe()` или `set_thread_safe()`.

```gdscript
var _heights := PackedFloat32Array()
var _task_id := -1

func build_heightmap(size: int) -> void:
    _heights.resize(size * size)          # размер задаём заранее, в главном потоке
    _task_id = WorkerThreadPool.add_group_task(_compute_row.bind(size), size)

func _compute_row(row: int, size: int) -> void:   # индекс первым, bind-аргументы после
    for x in size:
        _heights[row * size + x] = _noise_at(x, row)   # только своя ячейка

func _process(_dt: float) -> void:
    if _task_id != -1 and WorkerThreadPool.is_group_task_completed(_task_id):
        WorkerThreadPool.wait_for_group_task_completion(_task_id)  # освобождает ресурсы
        _task_id = -1
        _apply_heightmap()
```

Примечание: в GDScript Packed-массивы передаются по ссылке (справочник `PackedFloat32Array`: «Packed arrays are always passed by reference»), копию даёт только `duplicate()` или геттер встроенного свойства движка. Поэтому задачи группы пишут в один буфер члена класса: на 4.7.2 все 262 144 ячейки заполнялись в каждом из трёх прогонов, в том числе когда на массив была вторая ссылка (проверено). Если массив получен из свойства узла (`line.points`), это копия, и результат надо присвоить обратно.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [WorkerThreadPool](https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html) | Godot docs, 4.7 | API и требование дожидаться задач |
| [Node: process_thread_group](https://docs.godotengine.org/en/stable/classes/class_node.html) | Godot docs, 4.7 | Группы потоков, `call_thread_safe`, `call_deferred_thread_group` |
| [Godot 4.1 is here](https://godotengine.org/article/godot-4-1-is-here/) | Godot Foundation, 2023 | Появление многопоточной обработки сцен как экспериментальной функции |
| [Issues: WorkerThreadPool deadlock](https://github.com/godotengine/godot/issues?q=is%3Aissue+WorkerThreadPool+deadlock) | godotengine, живой | Актуальные дедлоки движка в многопоточном коде |

## Потокобезопасные API и фоновая загрузка

**Ключевые выводы**
- Работа с активным деревом сцены из потока не потокобезопасна. Строить поддерево вне дерева в потоке можно, добавлять в дерево — через `add_child.call_deferred()` (проверено на 4.7.2: поддерево из 10 `Sprite2D`, собранное в `Thread`, попадает в дерево через кадр).
- `Array` и `Dictionary`: чтение и запись элементов из разных потоков допустимы, изменение размера (append, erase, resize) — только под `Mutex`.
- Изменять один уникальный `Resource` из нескольких потоков нельзя; передавать ссылки между потоками можно.
- Физика по умолчанию не потокобезопасна. `physics/2d/run_on_separate_thread` и `physics/3d/run_on_separate_thread` переносят серверы физики в отдельный поток, но вызывают свои баги (например, [#105195](https://github.com/godotengine/godot/issues/105195): SoftBody3D падает). Включать только после замеров.
- Рендер: `rendering/driver/threads/thread_model = Separate` переносит драйвер в отдельный поток; без этого создание видимых узлов из потоков небезопасно.
- Сцены и ресурсы грузить `ResourceLoader.load_threaded_request()`, статус проверять `load_threaded_get_status(path, progress)` каждый кадр, забирать `load_threaded_get()` только после `THREAD_LOAD_LOADED`: иначе вызов блокирует главный поток.
- `preload()` и потоковая загрузка в 2026 году дают известные дедлоки в GDScriptCache ([#120827](https://github.com/godotengine/godot/issues/120827)) и падения при старте ([#122539](https://github.com/godotengine/godot/issues/122539)). Если загрузка виснет, сначала проверить эти issue для своей версии.

```gdscript
const LEVEL := "res://levels/level_2.tscn"
var _progress: Array = []

func _ready() -> void:
    var err := ResourceLoader.load_threaded_request(LEVEL, "PackedScene", true)
    assert(err == OK)

func _process(_dt: float) -> void:
    match ResourceLoader.load_threaded_get_status(LEVEL, _progress):
        ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            $ProgressBar.value = _progress[0] * 100.0
        ResourceLoader.THREAD_LOAD_LOADED:
            set_process(false)
            get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(LEVEL))
        ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            set_process(false)
            push_error("Не удалось загрузить %s" % LEVEL)
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Thread-safe APIs](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html) | Godot docs, 4.7 | Главная таблица допустимого |
| [Background loading](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html) | Godot docs, 4.7 | Пример фоновой загрузки |
| [ResourceLoader](https://docs.godotengine.org/en/stable/classes/class_resourceloader.html) | Godot docs, 4.7 | `use_sub_threads`, `cache_mode`, `ThreadLoadStatus` |
| [Issue #120827](https://github.com/godotengine/godot/issues/120827) | godotengine, 2026 | Дедлок GDScriptCache с `preload()` |
| [Issue #105195](https://github.com/godotengine/godot/issues/105195) | godotengine, открыт | Падение SoftBody3D при физике в отдельном потоке |

## HTTP, WebSocket, TCP, UDP

**Ключевые выводы**
- Сетевые классы Godot неблокирующие и работают через опрос: `HTTPClient`, `WebSocketPeer`, `StreamPeerTCP`, `PacketPeerUDP` требуют `poll()` каждый кадр. Узел `HTTPRequest` опрашивает себя сам.
- `HTTPRequest`: один запрос на узел одновременно. Параллельные запросы — отдельные узлы. `timeout` по умолчанию `0.0`, то есть ожидание без предела: всегда задавать таймаут. `use_threads = true` переносит работу в поток, `body_size_limit` защищает от огромных ответов.
- Не хранить в клиенте токены и пароли: сборку можно декомпилировать.
- На Android включить разрешение `INTERNET` в пресете экспорта, иначе сеть молча не работает. В веб-экспорте действуют правила CORS браузера.
- `WebSocketPeer`: `connect_to_url()` возвращает `OK` до установки соединения; для чистого закрытия продолжать `poll()` до `STATE_CLOSED`. Сервер — `TCPServer` плюс `WebSocketPeer.accept_stream()`. WebSocket не подходит для быстрых экшен-игр (TCP, head-of-line blocking).
- `PacketPeerUDP.wait()` нельзя прервать: для остановки потока-приёмника послать себе «пакет-пилюлю».
- `StreamPeerTCP.set_no_delay(true)` отключает алгоритм Нейгла для мелких частых сообщений.

```gdscript
@onready var _http: HTTPRequest = $HTTPRequest

func fetch_leaderboard() -> Dictionary:
    _http.timeout = 10.0
    var err := _http.request("https://api.example.com/leaderboard")
    if err != OK:
        return {}
    var res: Array = await _http.request_completed   # [result, code, headers, body]
    if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
        return {}
    var data = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
    return data if data is Dictionary else {}         # не доверять формату ответа
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [HTTPRequest](https://docs.godotengine.org/en/stable/classes/class_httprequest.html) | Godot docs, 4.7 | Свойства, ограничения, TLS |
| [Making HTTP requests](https://docs.godotengine.org/en/stable/tutorials/networking/http_request_class.html) | Godot docs, 4.7 | Пример GET/POST и предупреждение о секретах |
| [HTTPClient](https://docs.godotengine.org/en/stable/classes/class_httpclient.html) | Godot docs, 4.7 | Низкоуровневый клиент, переиспользование соединения |
| [WebSocketPeer](https://docs.godotengine.org/en/stable/classes/class_websocketpeer.html) | Godot docs, 4.7 | Буферы, `heartbeat_interval`, закрытие |
| [WebSocket](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html) | Godot docs, 4.7 | Минимальные клиент и сервер |
| [StreamPeerTCP](https://docs.godotengine.org/en/stable/classes/class_streampeertcp.html) | Godot docs, 4.7 | TCP-клиент, `set_no_delay` |
| [PacketPeerUDP](https://docs.godotengine.org/en/stable/classes/class_packetpeerudp.html) | Godot docs, 4.7 | UDP, broadcast, multicast, ловушка `wait()` |

## Высокоуровневый мультиплеер

**Ключевые выводы**
- `@rpc` по умолчанию: `"authority"`, `"call_remote"`, `"reliable"`, канал 0. Порядок первых трёх аргументов свободный, канал всегда четвёртый.
- `"any_peer"` разрешает вызов любому пиру. Такой метод обязан проверять `multiplayer.get_remote_sender_id()` и аргументы.
- `get_remote_sender_id()` возвращает 0 вне RPC и теряет значение после `await`. Сохранять его в локальную переменную в первой строке RPC.
- RPC работает, только если узел имеет одинаковый `NodePath` на всех пирах и скрипты объявляют одинаковый набор RPC (иначе ошибка контрольной суммы). Для узлов, создаваемых в коде, — `add_child(node, true)` (`force_readable_name`).
- `reliable` дорог. Позиции и ввод слать `unreliable_ordered` или через `MultiplayerSynchronizer`, разовые события (выстрел, покупка) — `reliable`.
- `MultiplayerSpawner` реплицирует добавление и удаление сцен под `spawn_path`; спавнит только authority (по умолчанию сервер). `spawn_function` возвращает узел вне дерева.
- `MultiplayerSynchronizer` отправляет свойства от authority к остальным. Режимы `SceneReplicationConfig`: always (`replication_interval`), on change (`delta_interval`), never. Свойства-объекты (Resource, RID) не синхронизируются. Видимость — `public_visibility`, `set_visibility_for()`, `add_visibility_filter()`.
- Типовая схема: сервер владеет персонажем, клиент — только узлом ввода. Authority узлу ввода назначать в `_enter_tree()` по имени узла, равному peer id.

```gdscript
# player.gd — узел назван str(peer_id) сервером при спавне
func _enter_tree() -> void:
    $PlayerInput.set_multiplayer_authority(name.to_int())

# неправильно: клиент сообщает, сколько у него денег
@rpc("any_peer")
func set_gold(value: int) -> void:
    gold = value

# правильно: клиент просит, сервер проверяет и решает
@rpc("any_peer", "call_remote", "reliable")
func request_buy(item_id: StringName) -> void:
    if not multiplayer.is_server():
        return
    var sender := multiplayer.get_remote_sender_id()   # до любого await
    if not _shop.has_item(item_id) or not _players.has(sender):
        return
    _shop.try_buy(_players[sender], item_id)

func _ready() -> void:
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_server(7777, 16)
    if err != OK:
        push_error("Порт занят: %s" % error_string(err))
        return
    multiplayer.multiplayer_peer = peer
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [@GDScript: @rpc](https://docs.godotengine.org/en/stable/classes/class_@gdscript.html) | Godot docs, 4.7 | Синтаксис аннотации и значения по умолчанию |
| [MultiplayerAPI](https://docs.godotengine.org/en/stable/classes/class_multiplayerapi.html) | Godot docs, 4.7 | Сигналы подключения, `get_remote_sender_id` и `await` |
| [SceneMultiplayer](https://docs.godotengine.org/en/stable/classes/class_scenemultiplayer.html) | Godot docs, 4.7 | `auth_callback`, `allow_object_decoding`, `server_relay` |
| [MultiplayerSpawner](https://docs.godotengine.org/en/stable/classes/class_multiplayerspawner.html) | Godot docs, 4.7 | `spawn_path`, `spawn_function`, `spawn_limit` |
| [MultiplayerSynchronizer](https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html) | Godot docs, 4.7 | Интервалы, видимость, ограничения |
| [ENetMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html) | Godot docs, 4.7 | Сервер, клиент, mesh, DTLS через `host` |
| [Multiplayer in Godot 4.0: Scene Replication](https://godotengine.org/article/multiplayer-in-godot-4-0-scene-replication/) | Fabio Alessandrelli, 2022 | Схема «ввод у клиента, персонаж у сервера» |

## Безопасность сети

**Ключевые выводы**
- Никогда не доверять клиенту: документация требует «treat all client input as untrusted». Урон, деньги, позиции, таймеры считает сервер; клиент присылает намерения.
- Не включать `SceneMultiplayer.allow_object_decoding` и не вызывать `get_var(true)` / `bytes_to_var_with_objects()` для данных из сети: десериализованный объект может содержать исполняемый код (удалённое выполнение кода).
- Для аутентификации — `SceneMultiplayer.auth_callback` и `auth_timeout`, а не самописный RPC после подключения.
- Ограничивать размер входящих данных: `max_sync_packet_size`, `body_size_limit`, проверка длины строк и массивов в RPC. Отбрасывать NaN и бесконечности во float-аргументах.
- Шифрование: ENet через DTLS (`peer.host.dtls_server_setup(TLSOptions.server(key, cert))`), WebSocket через `wss://`, HTTP через HTTPS.
- Частоту RPC от одного пира ограничивать на сервере (rate limit), иначе любой клиент может заспамить сервер.
- `server_relay = false`, если клиентам не нужно знать друг о друге и общаться через сервер.

```gdscript
# allow_object_decoding = false — значение по умолчанию SceneMultiplayer; не менять
@rpc("any_peer", "unreliable_ordered")
func submit_input(dir: Vector2, seq: int) -> void:
    if not dir.is_finite() or dir.length() > 1.01:
        return                                # мусор или чит
    _inputs[multiplayer.get_remote_sender_id()] = {"dir": dir, "seq": seq}
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [PacketPeer: get_var](https://docs.godotengine.org/en/stable/classes/class_packetpeer.html) | Godot docs, 4.7 | Предупреждение об исполнении кода при декодировании объектов |
| [High-level multiplayer: security](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html) | Godot docs, 4.7 | Серверная авторитетность и проверка RPC |

## Выделенный сервер, WebRTC, Steam, rollback

**Ключевые выводы**
- Выделенный сервер: запуск с `--headless` (драйвер дисплея headless, аудио Dummy). Экспортный режим «Dedicated Server» с `Strip Visuals` заменяет текстуры заглушками и сильно уменьшает PCK. Определять режим через `OS.has_feature("dedicated_server")` или `DisplayServer.get_name() == "headless"`, параметры брать из `OS.get_cmdline_user_args()`.
- ENet работает только по UDP: на сервере открывать UDP-порт.
- WebRTC даёт P2P и работает в браузере, но требует сигнального сервера и STUN/TURN. На нативных платформах нужен GDExtension [webrtc-native](https://github.com/godotengine/webrtc-native) (Godot 4.1+).
- Rollback и предсказание: [netfox](https://github.com/foxssake/netfox) (MIT, Godot 4.x) даёт `NetworkTime` (тики), `RollbackSynchronizer`, `TickInterpolator`, client-side prediction и server reconciliation. Последний релиз на октябрь 2026 — v1.35.3 (ноябрь 2025, GitHub API). [godot-rollback-netcode](https://gitlab.com/snopek-games/godot-rollback-netcode) (SyncManager, `_save_state`/`_load_state`) — для детерминированных файтингов; ветка `main` под Godot 4 (`project.godot` помечен 4.6, релиз v1.0.0 в июне 2026), Godot 3 — ветка `godot-3`.
- Для rollback логика должна быть детерминированной: фиксированный тик в `_physics_process`, свой RNG с общим seed, без `randf()` и без зависимости от порядка словарей.
- GodotSteam: репозиторий на GitHub заархивирован 5 октября 2026 года, разработка переехала на Codeberg. Есть варианты модуля, GDExtension и Server, а также multiplayer peer для Steam-сокетов. Инициализация — `Steam.steamInitEx(app_id, embed_callbacks)`; без `embed_callbacks = true` нужно вызывать `Steam.run_callbacks()` примерно каждый кадр ([Initializing Steam](https://godotsteam.com/tutorials/initializing/), для GodotSteam 4.14+).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Exporting for dedicated servers](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html) | Godot docs, 4.7 | Headless, Strip Visuals, feature tags |
| [WebRTC](https://docs.godotengine.org/en/stable/tutorials/networking/webrtc.html) | Godot docs, 4.7 | Сигналинг, `WebRTCMultiplayerPeer` |
| [netfox docs](https://foxssake.github.io/netfox/latest/) | Fox's Sake Studio, живой | Тики, rollback, интерполяция |
| [netfox releases](https://github.com/foxssake/netfox/releases) | Fox's Sake Studio | Изменения версий |
| [GodotSteam (GitHub, архив)](https://github.com/GodotSteam/GodotSteam) | GodotSteam, архив 2026 | Указатель на переезд на Codeberg |
| [godotsteam.com](https://godotsteam.com/) | GodotSteam, живой | Документация по вариантам и API |

## Внешние процессы

**Ключевые выводы**
- `OS.execute()` блокирует вызывающий поток до завершения процесса. Из главного потока — только для мгновенных команд; иначе запускать в `Thread`/`WorkerThreadPool`.
- `OS.execute_with_pipe()` возвращает словарь `{"stdio", "stderr", "pid"}` для потокового обмена; `OS.create_process()` запускает процесс, который переживёт Godot. Следить через `is_process_running()`, `get_process_exit_code()`, `kill()`.
- Работают на Windows, Linux, macOS, Android; в вебе и на iOS — нет (кроме `shell_open`). Проверять `OS.get_name()`/feature tags.
- Аргументы передавать массивом, не склеивать строку для `cmd /c` или `sh -c` из пользовательского ввода: это инъекция команд.

```gdscript
func run_tool(file: String) -> void:
    var output: Array = []
    # правильно: путь — отдельный аргумент, без оболочки
    var code := OS.execute("ffprobe", ["-v", "error", "-show_format", file], output, true)
    if code != 0:
        push_error("ffprobe завершился с кодом %d" % code)
    # неправильно: OS.execute("sh", ["-c", "ffprobe " + file])
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [OS](https://docs.godotengine.org/en/stable/classes/class_os.html) | Godot docs, 4.7 | `execute`, `execute_with_pipe`, `create_process`, платформы |

## Что устарело после Godot 3

| Godot 3 [устарело] | Godot 4 |
|---|---|
| `yield(obj, "signal")`, `GDScriptFunctionState.resume()` | `await obj.signal`; ручного `resume` нет |
| `connect("sig", target, "method", binds)` | `sig.connect(target.method.bind(...))` |
| `emit_signal("sig", a)` | `sig.emit(a)` (`emit_signal` работает, но без проверок редактора) |
| `funcref(obj, "m")` | `Callable(obj, "m")` или `obj.m` |
| `remote`, `master`, `puppet`, `remotesync`, `mastersync`, `puppetsync` | `@rpc("any_peer"/"authority", "call_local"/"call_remote", ...)` |
| `rset`, `rset_id`, `rset_config` | `MultiplayerSynchronizer` или RPC-сеттер |
| `set_network_master`, `is_network_master` | `set_multiplayer_authority`, `is_multiplayer_authority` |
| `get_tree().get_rpc_sender_id()` | `multiplayer.get_remote_sender_id()` |
| `NetworkedMultiplayerENet` | `ENetMultiplayerPeer` |
| `WebSocketClient`, `WebSocketServer` | `WebSocketPeer` (+ `TCPServer` на сервере) |
| `Thread.start(self, "method", userdata)`, `is_active()` | `Thread.start(method.bind(userdata))`, `is_alive()` |
| `ResourceInteractiveLoader` | `ResourceLoader.load_threaded_request/get_status/get` |
| `OS.execute(path, args, blocking)` | `OS.execute()` (всегда блокирует) и `OS.create_process()` |

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Upgrading from Godot 3 to Godot 4](https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.html) | Godot docs, 4.7 | Официальная таблица переименований |
| [GDScript progress report: new GDScript is now merged](https://godotengine.org/article/gdscript-progress-report-new-gdscript-now-merged/) | George Marques, 2020 | Почему `yield` заменён на `await` |
| [High-level multiplayer (3.6)](https://docs.godotengine.org/en/3.6/tutorials/networking/high_level_multiplayer.html) | Godot docs, 3.6 | Старые ключевые слова RPC для чтения чужого кода |
| [Issue #24311](https://github.com/godotengine/godot/issues/24311), [Issue #73118](https://github.com/godotengine/godot/issues/73118) | godotengine | История проблемы «корутина пережила объект» |

## Что выбрать

| Задача | Механизм |
|---|---|
| Сообщить «что-то случилось» без знания о получателе | сигнал; глобальные события — autoload-шина с методами-обработчиками |
| Разовая реакция на событие | `connect(..., CONNECT_ONE_SHOT)` или `await signal` с таймаутом |
| Задержка в игровом времени | `await get_tree().create_timer(t, false).timeout` или узел `Timer` |
| Подождать один кадр | `await get_tree().process_frame` / `physics_frame` |
| Анимация, ждущая событие | `Tween.tween_await(signal)` (4.7+) |
| Изменить физику или дерево из колбэка физики | `set_deferred` / `call_deferred` |
| Короткая параллельная задача (генерация, парсинг) | `WorkerThreadPool.add_task` + `is_task_completed` |
| Параллельный цикл по массиву | `WorkerThreadPool.add_group_task` |
| Долгоживущий воркер с очередью | `Thread` + `Mutex` + `Semaphore` |
| Много независимых узлов с тяжёлым `_process` | `process_thread_group = SUB_THREAD` (после замеров) |
| Загрузка уровня с прогресс-баром | `ResourceLoader.load_threaded_request` |
| REST API, загрузка файла | `HTTPRequest` (узел на запрос, `timeout` задан) |
| Чат, лобби, пошаговая игра, браузер | `WebSocketPeer` |
| Экшен-мультиплеер, клиент-сервер | ENet + `@rpc` + `MultiplayerSpawner`/`MultiplayerSynchronizer` |
| P2P в браузере | WebRTC + сигнальный сервер |
| Предсказание и rollback | netfox |
| Steam-лобби и Steam-сеть | GodotSteam (сверить с Codeberg-репозиторием) |
| Сервер без GPU | `--headless` + экспорт Dedicated Server |
| Внешняя утилита | `OS.execute` в потоке, `execute_with_pipe`, `create_process` |
| Свой протокол поверх UDP/TCP | `PacketPeerUDP`/`UDPServer`, `StreamPeerTCP`/`TCPServer` |

## Чеклист review: асинхронный, многопоточный и сетевой GDScript

1. Сигналы подключаются через `Callable`, без строкового API Godot 3; повторное подключение исключено `is_connected()` или флагом.
2. Сигналы объявлены с типизированными параметрами, сигнатуры обработчиков совпадают.
3. Лямбды не подключены к долгоживущим эмиттерам без явного `disconnect()` в `_exit_tree()`.
4. Лямбды не захватывают узлы, которые могут быть освобождены раньше эмиттера.
5. Разовые подписки помечены `CONNECT_ONE_SHOT`.
6. Каждый `await` на сигнал чужого объекта имеет путь выхода (таймаут, сигнал отмены) на случай, если объект освободят.
7. После каждого `await` в узле проверяется `is_instance_valid(self)` / `is_inside_tree()` перед доступом к дереву.
8. Таймеры `create_timer()` для игровой логики создаются с `process_always = false`, чтобы уважать паузу.
9. Нет `await tween.finished` для твинов, которые могут быть убиты или зациклены.
10. Результат корутины всегда получается через `await`; корутины, запускаемые «в фоне», осознанно без результата.
11. Изменения физики внутри колбэков столкновений идут через `set_deferred`/`call_deferred`.
12. Ни один поток не обращается к узлам активного дерева напрямую; результаты возвращаются через `call_deferred` или `call_thread_safe`.
13. Каждый `Thread` завершается `wait_to_finish()` в `_exit_tree()`; есть флаг остановки и `post()` семафора.
14. Изменение размера общих `Array`/`Dictionary` идёт только под `Mutex`; `lock`/`unlock` сбалансированы на всех путях, включая ранний `return`.
15. Каждая задача `WorkerThreadPool` дожидается `wait_for_*_completion()`; главный поток не блокируется ожиданием долгой задачи.
16. Задачи пула достаточно крупные; выигрыш подтверждён замером.
17. Один `Resource` не изменяется из нескольких потоков.
18. `load_threaded_get()` вызывается только после статуса `THREAD_LOAD_LOADED`; обработаны `FAILED` и `INVALID_RESOURCE`.
19. Включение `run_on_separate_thread` для физики или группы потоков узлов обосновано профилированием и проверено на известных issue версии.
20. У каждого `HTTPRequest` задан `timeout`; нет параллельных запросов через один узел; ответ проверяется на код и формат.
21. В клиенте нет токенов, паролей и приватных ключей.
22. Классы с `poll()` (`WebSocketPeer`, `HTTPClient`, `StreamPeerTCP`) опрашиваются каждый кадр; закрытие доводится до `STATE_CLOSED`.
23. Каждый `@rpc("any_peer")` на сервере проверяет отправителя, права и аргументы (тип, диапазон, `is_finite`, длина).
24. `get_remote_sender_id()` читается в начале RPC, до любого `await`.
25. Игровые решения (урон, экономика, позиции) принимает сервер; клиент присылает только намерения.
26. `allow_object_decoding` выключен; нет `get_var(true)` и `bytes_to_var_with_objects()` для сетевых данных.
27. Режимы передачи выбраны осознанно: частые обновления — `unreliable_ordered` или синхронизатор, события — `reliable`; разные потоки данных разнесены по каналам.
28. Узлы с RPC имеют одинаковые пути и наборы RPC на всех пирах; динамические узлы добавлены с `force_readable_name`.
29. Authority назначается явно (`set_multiplayer_authority` в `_enter_tree`), а код проверяет `is_multiplayer_authority()` перед локальным управлением.
30. Обработаны `peer_disconnected`, `server_disconnected`, `connection_failed`; состояние игрока очищается при отключении.
31. Есть аутентификация (`auth_callback`) и ограничение частоты RPC для публичного сервера; трафик шифруется (DTLS, `wss`, HTTPS).
32. Серверная сборка запускается headless, ресурсы экспортированы со Strip Visuals; режим определяется feature tag.
33. Логика rollback детерминирована: фиксированный тик, свой RNG с seed, без зависимостей от времени кадра.
34. `OS.execute` не блокирует главный поток надолго; аргументы передаются массивом без оболочки; платформа проверена.
35. В коде нет конструкций Godot 3 (`yield`, `rset`, `master`/`puppet`, `set_network_master`).

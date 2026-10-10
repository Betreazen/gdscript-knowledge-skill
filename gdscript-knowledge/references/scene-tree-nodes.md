# Узлы, сцены и дерево сцены в Godot 4

Справочник о том, как правильно и экономно работать с деревом сцены Godot 4: жизненный цикл узла и уведомления, порядок `_process` и `_physics_process`, пауза и `process_mode`, API `SceneTree` (группы, смена сцен, таймеры), владелец узла `owner` и его роль при сохранении `PackedScene`, наследование сцен, композиция и Editable Children, уникальные имена `%`, изменение дерева (`add_child`, `reparent`, `free`, `queue_free`), выбор базового типа, `@tool`-скрипты, предупреждения конфигурации и инструменты редактора. В конце — антипаттерны и чеклист ревью сцены. Актуально на октябрь 2026, Godot 4.7.2. Опорные первоисточники — справочник классов [Node](https://docs.godotengine.org/en/stable/classes/class_node.html), [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html), [PackedScene](https://docs.godotengine.org/en/stable/classes/class_packedscene.html) и раздел [Best practices](https://docs.godotengine.org/en/stable/tutorials/best_practices/index.html). Поведение, помеченное «(проверено на 4.7.2)», воспроизведено headless-скриптами на `Godot_v4.7.2-stable_win64_console.exe`.

Метки: `[устарело]` — совет эпохи Godot 3, рядом замена; `[не проверено]` — утверждение из вторичного источника без локальной проверки.

Смежные справочники: архитектура проекта и смена уровней — [architecture.md](architecture.md); стоимость узлов, пулинг и серверы — [performance.md](performance.md#узлы-дерево-сцены-и-обработка-кадров); `call_deferred`, группы потоков и `await` — [signals-async-threads.md](signals-async-threads.md); `@onready`, `@tool`, связи «вниз вызовы, вверх сигналы» — [idioms-patterns.md](idioms-patterns.md).

- [Жизненный цикл узла и уведомления](#жизненный-цикл-узла-и-уведомления)
- [Обработка кадров и приоритеты](#обработка-кадров-и-приоритеты)
- [Пауза и process_mode](#пауза-и-process_mode)
- [Группы потоков обработки](#группы-потоков-обработки)
- [API SceneTree](#api-scenetree)
- [Владелец узла owner](#владелец-узла-owner)
- [PackedScene: инстанцирование и сохранение](#packedscene-инстанцирование-и-сохранение)
- [Наследование сцен, композиция и Editable Children](#наследование-сцен-композиция-и-editable-children)
- [Уникальные имена и NodePath](#уникальные-имена-и-nodepath)
- [Изменение дерева и удаление узлов](#изменение-дерева-и-удаление-узлов)
- [Выбор базового типа](#выбор-базового-типа)
- [Сколько узлов слишком много](#сколько-узлов-слишком-много)
- [Организация файлов сцен](#организация-файлов-сцен)
- [Tool-скрипты и предупреждения конфигурации](#tool-скрипты-и-предупреждения-конфигурации)
- [Инструменты редактора для работы со сценами](#инструменты-редактора-для-работы-со-сценами)
- [Антипаттерны](#антипаттерны)
- [Чеклист ревью сцены](#чеклист-ревью-сцены)

---

## Жизненный цикл узла и уведомления

### Ключевые выводы

- `_init()` вызывается при создании объекта (`new()` или `instantiate()`), до входа в дерево. В нём ещё нет родителя и дерева, а у узла из сцены даже `name` пустой (проверено на 4.7.2). Значения из инспектора применяются после `_init` и вызывают сеттеры ([Godot notifications](https://docs.godotengine.org/en/stable/tutorials/best_practices/godot_notifications.html)). `_init` должен быть без обязательных аргументов, иначе сцену с этим скриптом нельзя инстанцировать ([GDQuest](https://www.gdquest.com/library/glossary/lifecycle_node)).
- `_enter_tree()` идёт сверху вниз (родитель, потом дети, в порядке дерева), `_ready()` снизу вверх: родитель получает `_ready` только после того, как он пришёл всем детям ([SceneTree tutorial](https://docs.godotengine.org/en/stable/tutorials/scripting/scene_tree.html)). Поэтому в `_ready` родителя дети уже готовы, а в `_ready` ребёнка родитель ещё нет.
- `_exit_tree()` идёт в обратном порядке: сначала дети, потом родитель (проверено на 4.7.2).
- `_ready()` вызывается один раз за жизнь узла. Повторный вход в дерево после `remove_child` даёт снова `_enter_tree`, но не `_ready`. Чтобы `_ready` сработал снова, вызовите `request_ready()` до следующего входа: он не вызывает `_ready` сразу ([Node](https://docs.godotengine.org/en/stable/classes/class_node.html)). При повторном `_ready` заново вычисляются и `@onready`-переменные (проверено на 4.7.2).
- Уведомления, которые полезно знать: `NOTIFICATION_PARENTED`/`UNPARENTED` приходят при `add_child`/`remove_child` даже вне дерева; `NOTIFICATION_POST_ENTER_TREE` — сразу перед `READY` и при каждом повторном входе; `NOTIFICATION_PREDELETE` — «деструктор», рассылается в обратном порядке иерархии скриптов ([Object](https://docs.godotengine.org/en/stable/classes/class_object.html)).
- При `free()` узла в дереве порядок такой: `PREDELETE`, потом `_exit_tree`, потом `UNPARENTED` (проверено на 4.7.2). В `PREDELETE` дерево ещё доступно, но писать туда сложную логику не стоит: для этого есть `_exit_tree` и сигнал `tree_exiting`.
- Сигналы дерева: `tree_entered`, `ready` (после `_ready`), `tree_exiting`, `tree_exited`; у родителя — `child_entered_tree` (после `_enter_tree` ребёнка, до входа внуков) и `child_exiting_tree` (проверено на 4.7.2). `is_node_ready()` сообщает, был ли уже `_ready`.
- `process_priority` на порядок `_ready` не влияет: старое утверждение в документации было ошибкой ([#78783](https://github.com/godotengine/godot/issues/78783), уточнение в [#97905](https://github.com/godotengine/godot/pull/97905)).

Полный порядок для дерева A → (B → C, B2) при `root.add_child(A)` (проверено на 4.7.2):

```text
вне дерева (add_child):  PARENTED B, PARENTED C, PARENTED B2
root.add_child(A):       PARENTED A
                         enter A, enter B, enter C, enter B2
                         ready C, ready B, ready B2, ready A
A.remove_child(B):       exit C, exit B, UNPARENTED B        # B и C живы, это сироты
A.add_child(B):          enter B, enter C                     # _ready НЕ вызван
B.request_ready(); снять и вернуть B:  enter B, enter C, ready B   # только B
```

```gdscript
# Плохо: работа с деревом в _init, обращение к родителю из _ready ребёнка
func _init() -> void:
	$Sprite2D.modulate = Color.RED          # детей ещё нет: null

func _ready() -> void:
	get_parent().register(self)             # родитель ещё не готов, его @onready = null

# Хорошо: дети — в _ready, связь с родителем — через сигнал или инъекцию сверху
@onready var _sprite: Sprite2D = $Sprite2D
signal spawned(who: Node)

func _ready() -> void:
	_sprite.modulate = Color.RED
	spawned.emit(self)                      # родитель подписан и решает сам

# Подписка на родителя, который может смениться
func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED:
		_bind_to(get_parent())
	elif what == NOTIFICATION_UNPARENTED:
		_unbind()
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Using SceneTree](https://docs.godotengine.org/en/stable/tutorials/scripting/scene_tree.html) | документация Godot, 4.7 | Порядок enter/ready/exit, корневой Viewport |
| [Godot notifications](https://docs.godotengine.org/en/stable/tutorials/best_practices/godot_notifications.html) | документация Godot, 4.7 | `_init` против `_ready`, порядок инициализации свойств, PARENTED/UNPARENTED |
| [Node](https://docs.godotengine.org/en/stable/classes/class_node.html) | справочник API, 4.7 | Все `NOTIFICATION_*`, `request_ready`, `is_node_ready` |
| [Object](https://docs.godotengine.org/en/stable/classes/class_object.html) | справочник API, 4.7 | `NOTIFICATION_PREDELETE`, `cancel_free`, `is_queued_for_deletion` |
| [Node lifecycle](https://www.gdquest.com/library/glossary/lifecycle_node) | GDQuest | Короткая схема жизненного цикла с сигналами |
| [Understanding tree order](https://kidscancode.org/godot_recipes/3.x/basics/tree_ready_order/) | KidsCanCode | Наглядный пример порядка; код на синтаксисе Godot 3 [устарело], идея та же |

---

## Обработка кадров и приоритеты

### Ключевые выводы

- `_process(delta)` вызывается каждый отрисованный кадр, `_physics_process(delta)` — с фиксированной частотой физики (по умолчанию 60 Гц). Подробности и затраты — в [performance.md](performance.md#узлы-дерево-сцены-и-обработка-кадров).
- Порядок по умолчанию — порядок дерева (обход сверху вниз). `process_priority` и `process_physics_priority` его переопределяют: меньшее значение вызывается раньше, независимо от положения в дереве ([Node](https://docs.godotengine.org/en/stable/classes/class_node.html)). При равном приоритете снова действует порядок дерева (проверено на 4.7.2: приоритеты −5, 0, 0 у ребёнка, 5 дали порядок Z, Y, Y_child, X).
- Приоритет — инструмент для явных зависимостей «камера после игрока», «ввод до движения». Если приоритетов в проекте много, это признак скрытых связей: лучше одна система-оркестратор, которая вызывает шаги в нужном порядке.
- Сигналы `SceneTree.process_frame` и `physics_frame` срабатывают перед `_process`/`_physics_process` всех узлов ([SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html)). `await get_tree().process_frame` — стандартный способ «подождать кадр».
- Движок включает обработку автоматически, если метод переопределён. Выключайте её `set_process(false)`, когда узлу нечего делать; вне дерева узел не обрабатывается (`is_processing()` = false, проверено на 4.7.2).

Пример: камера читает позицию игрока после его движения в том же тике, если у `camera_rig.process_physics_priority = 10`, а у игрока 0 (больше — позже).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Idle and physics processing](https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html) | документация Godot | Когда `_process`, когда `_physics_process` |
| [PR #97905](https://github.com/godotengine/godot/pull/97905) | godotengine, 2024 | Документация: обычная обработка идёт в порядке дерева |
| [Issue #78783](https://github.com/godotengine/godot/issues/78783) | godotengine, 2023 | `process_priority` не меняет порядок `_ready` |

---

## Пауза и process_mode

### Ключевые выводы

- `get_tree().paused = true` останавливает физику 2D/3D и вызовы `_process`, `_physics_process`, `_input` у узлов, которые должны паузиться ([Pausing games](https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_games.html)). Анимации, звук и частицы встают на паузу сами. Сигналы при этом продолжают доставляться.
- Режимы: `INHERIT` (по умолчанию, берёт режим ближайшего предка), `PAUSABLE`, `WHEN_PAUSED` (только во время паузы), `ALWAYS`, `DISABLED` (никогда). У корня всё `INHERIT` сводится к `PAUSABLE` (проверено на 4.7.2: ребёнок `PAUSABLE`-узла встал вместе с ним).
- Меню паузы: корень меню — `WHEN_PAUSED` (или `ALWAYS`, если меню живёт и вне паузы), игровой мир — по умолчанию. Автозагрузки, которые должны работать всегда (музыка, сеть), — `ALWAYS`.
- Ловушка: `get_tree().create_timer(t)` по умолчанию имеет `process_always = true` и срабатывает во время паузы (проверено на 4.7.2). Для игровых задержек пишите `create_timer(t, false)`. У узла `Timer` поведение определяет его `process_mode`, у `Tween` — `set_pause_mode()`.
- `DISABLED` — дешёвый способ «заморозить» поддерево без удаления из дерева, в отличие от `visible = false`, который только прячет отрисовку.

```gdscript
# Плохо: кулдаун истекает, пока игрок стоит на паузе
await get_tree().create_timer(2.0).timeout

# Хорошо: таймер уважает паузу
await get_tree().create_timer(2.0, false).timeout

# pause_menu.gd — корень меню: process_mode = WHEN_PAUSED в инспекторе
func open() -> void:
	get_tree().paused = true
	show()
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Pausing games and process mode](https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_games.html) | документация Godot, 4.7 | Режимы, меню паузы, что останавливается |
| [SceneTree.create_timer](https://docs.godotengine.org/en/stable/classes/class_scenetree.html) | справочник API | Параметры `process_always`, `process_in_physics`, `ignore_time_scale` |
| [Issue #93608](https://github.com/godotengine/godot/issues/93608) | godotengine, 2024 | Корутина с таймером дерева после `queue_free` (исправлено) |

---

## Группы потоков обработки

### Ключевые выводы

- `process_thread_group` (4.1+) переносит `_process` поддерева в пул потоков: `INHERIT` (по умолчанию), `MAIN_THREAD`, `SUB_THREAD`. Внутри такой группы нельзя напрямую трогать узлы вне группы: только `call_deferred_thread_group()`, `call_thread_safe()`, `set_thread_safe()`.
- Это не «бесплатное ускорение». Выигрыш есть, когда поддерево делает много независимой вычислительной работы, а не обращается к общим узлам и серверам. Сначала профиль.
- Подробно, с примерами и статусом экспериментальности на 4.7.2: [signals-async-threads.md](signals-async-threads.md#workerthreadpool-и-группы-потоков); история функции — [Godot 4.1 is here](https://godotengine.org/article/godot-4-1-is-here/).

---

## API SceneTree

### Ключевые выводы

- Группы. `add_to_group(&"enemies")` в коде или в доке Groups; с 4.3 есть глобальные группы в Project Settings ([Groups](https://docs.godotengine.org/en/stable/tutorials/scripting/groups.html)). Узел вне дерева может состоять в группе (`is_in_group` = true), но `get_nodes_in_group`/`get_node_count_in_group` видят только узлы в дереве (проверено на 4.7.2).
- `call_group(group, method, ...)` вызывает метод сразу у всех членов в порядке дерева. Флаги `GROUP_CALL_REVERSE`, `GROUP_CALL_DEFERRED` (в конце кадра), `GROUP_CALL_UNIQUE` (один раз за кадр, только вместе с DEFERRED). Удалять членов группы из группового вызова безопаснее отложенно (проверено на 4.7.2: `GROUP_CALL_DEFERRED` + `queue_free` очищает группу к следующему кадру).
- `get_first_node_in_group()` — удобный поиск одиночки («игрок») без жёсткого пути. Но если такой узел нужен многим, лучше передать ссылку при создании (см. [architecture.md](architecture.md#внедрение-зависимостей)).
- Смена сцены. `change_scene_to_file()`, `change_scene_to_packed()` и с 4.6 `change_scene_to_node()` ([PR #85762](https://github.com/godotengine/godot/pull/85762)). Старая сцена снимается с дерева прямо внутри вызова: её `_exit_tree` уже отработал, `current_scene` сразу равен `null`. Освобождение старой и добавление новой происходят в конце кадра, после чего приходит сигнал `scene_changed` (проверено на 4.7.2). Не обращайтесь к `current_scene` сразу после вызова: ждите `scene_changed`.
- Эти методы загружают сцену синхронно и подвешивают игру до загрузки ([Using SceneTree](https://docs.godotengine.org/en/stable/tutorials/scripting/scene_tree.html)). Для больших уровней — фоновая загрузка и свой экран загрузки ([architecture.md](architecture.md#смена-сцен-и-экраны-загрузки)). Альтернатива «спрятать» или «снять с дерева и держать в памяти» описана в [Change scenes manually](https://docs.godotengine.org/en/stable/tutorials/scripting/change_scenes_manually.html).
- `create_timer()` — одноразовый таймер без узла; `create_tween()` у дерева не привязан к узлу, а `Node.create_tween()` умирает вместе с узлом. Для анимации узла берите второй.
- Сигналы дерева `node_added`, `node_removed`, `node_renamed`, `tree_changed` срабатывают на каждый узел (в `node_added` узел ещё не готов: `is_node_ready()` = false, проверено на 4.7.2). Это инструмент отладки и редакторских плагинов, а не игровой шины событий: подписка на `node_added` в большом уровне — тысячи вызовов.

```gdscript
# Плохо: ищем сцену сразу после смены
get_tree().change_scene_to_packed(LEVEL_2)
get_tree().current_scene.start()            # null

# Хорошо
get_tree().change_scene_to_packed(LEVEL_2)
await get_tree().scene_changed
get_tree().current_scene.start()

# Широковещательная команда без знания о получателях
get_tree().call_group(&"enemies", &"on_alarm", alarm_position)
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html) | справочник API, 4.7 | Группы, флаги, смена сцен, сигналы, таймеры |
| [Groups](https://docs.godotengine.org/en/stable/tutorials/scripting/groups.html) | документация Godot, 4.7 | Глобальные и сценовые группы |
| [Change scenes manually](https://docs.godotengine.org/en/stable/tutorials/scripting/change_scenes_manually.html) | документация Godot, 4.7 | Удалить, спрятать или снять сцену с дерева: плюсы и минусы |
| [PR #85762: change_scene_to_node](https://github.com/godotengine/godot/pull/85762) | godotengine, 2025 | Новый метод 4.6, когда сцену готовят заранее |

---

## Владелец узла owner

### Ключевые выводы

- `owner` — узел-корень сцены, которой принадлежит данный узел. Это не родитель: у `Player/Body/Shape` родитель Shape — Body, а владелец — Player. Владелец обязан быть предком ([Node](https://docs.godotengine.org/en/stable/classes/class_node.html)).
- От владельца зависят три вещи: что попадёт в файл при `PackedScene.pack()` и сохранении; в какой области ищутся уникальные имена `%`; что показывает и сохраняет редактор.
- `add_child()` владельца не ставит. Узел, созданный кодом, имеет `owner == null` и при сохранении сцены пропадает ([форум](https://forum.godotengine.org/t/node-that-using-add-child-not-saved/95739)).
- После `instantiate()` все узлы сцены принадлежат её корню, а узлы вложенных сцен — корням этих вложенных сцен (проверено на 4.7.2).
- `reparent()` сохраняет владельца, если новый родитель внутри той же сцены. `remove_child()` + `add_child()` владельца сбрасывает: при выходе ветки из дерева `owner`, который остался снаружи ветки, очищается. После этого `%Имя` такого узла больше не находится (проверено на 4.7.2; логика `reparent` — в [node.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/node.cpp)).
- `duplicate()` обычного поддерева не переносит `owner` детей: у копии они `null` (проверено на 4.7.2). Копию, которую потом сохраняют через `pack()`, надо «переприсвоить» владельцам или получить заново через `instantiate()`. Свежий баг `duplicate(DUPLICATE_INTERNAL_STATE)` с ошибкой «Invalid owner» — [#124259](https://github.com/godotengine/godot/issues/124259) (4.7.2, открыт).

```gdscript
# Сменить родителя внутри сцены, не потеряв владельца и %UniqueName
item.reparent(%Inventory)                      # хорошо
# item.get_parent().remove_child(item); %Inventory.add_child(item)  # owner = null

# Установить владельца всему поддереву, созданному кодом
static func set_owner_recursive(node: Node, new_owner: Node) -> void:
	for child in node.get_children():
		child.owner = new_owner
		if child.scene_file_path.is_empty():   # внутрь вложенных сцен не лезем
			set_owner_recursive(child, new_owner)
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Node.owner](https://docs.godotengine.org/en/stable/classes/class_node.html) | справочник API | Определение и ограничения |
| [Running code in the editor](https://docs.godotengine.org/en/stable/tutorials/plugins/running_code_in_the_editor.html) | документация Godot, 4.7 | `owner = get_tree().edited_scene_root` для узлов из `@tool` |
| [Issue #90823](https://github.com/godotengine/godot/issues/90823) | godotengine, 2024 | «PackedScene не сохраняет узлы» — на деле не выставлен owner |
| [Issue #124259](https://github.com/godotengine/godot/issues/124259) | godotengine, октябрь 2026 | `duplicate` и ошибка «Invalid owner» на 4.7.2 |

---

## PackedScene: инстанцирование и сохранение

### Ключевые выводы

- `preload("res://enemy.tscn")` держите в константе и вызывайте `instantiate()` сколько нужно. `load()` в момент спавна ищет ресурс в кэше и может грузить синхронно ([Nodes and scene instances](https://docs.godotengine.org/en/stable/tutorials/scripting/nodes_and_scene_instances.html)).
- `instantiate()` создаёт всё дерево (`_init` и `PARENTED` у каждого узла), но в дерево сцены не добавляет: `_enter_tree` и `_ready` будут после `add_child` (проверено на 4.7.2). Корень получает `NOTIFICATION_SCENE_INSTANTIATED` ([PackedScene](https://docs.godotengine.org/en/stable/classes/class_packedscene.html)).
- Значит, настраивать экземпляр нужно между `instantiate()` и `add_child()`: присвоить свойства и зависимости, подписаться на сигналы. Тогда `_ready` уже увидит готовые данные. `@onready`-ссылки до `add_child` ещё `null`, поэтому сеттеры, которые трогают детей, должны это учитывать.
- Сцена дешевле, чем то же дерево, построенное кодом: движок создаёт узлы пакетно из сериализованных данных ([Scenes versus scripts](https://docs.godotengine.org/en/stable/tutorials/best_practices/scenes_versus_scripts.html)).
- `pack(root)` сохраняет корень и всё, чем он владеет. Узлы без владельца выпадают, корню владеть собой не нужно (проверено на 4.7.2). Вложенная сцена записывается ссылкой `instance=ExtResource(...)`, а не копией узлов.
- С 4.6 каждый узел в `.tscn` получает `unique_id`, и ссылки переживают переименования и перестановки ([Godot 4.6](https://godotengine.org/releases/4.6/)). 4.7.2 пишет `unique_id` и для сцен, собранных `pack()` в рантайме (проверено). После обновления проекта пересохраните сцены (Project → Tools → Upgrade Project Files), иначе экспорт может быть недетерминированным ([#115971](https://github.com/godotengine/godot/issues/115971)). У сцен, наследующих GLB, ID меняются при каждом реимпорте ([#117605](https://github.com/godotengine/godot/issues/117605)) — шум в диффах.
- Сохранять `PackedScene` как формат сохранения игры рискованно: файл может содержать скрипты и выполнять код при загрузке. Для сохранений — свои данные (см. [architecture.md](architecture.md#сохранение-и-загрузка)). Есть и открытый баг с утечкой физических и меш-объектов у сцен, созданных `pack()` в рантайме ([#117316](https://github.com/godotengine/godot/issues/117316)).

```gdscript
const ENEMY_SCENE: PackedScene = preload("res://features/enemies/enemy.tscn")

func spawn_enemy(at: Vector2, target: Node2D) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.position = at
	enemy.target = target                     # зависимость до _ready
	enemy.died.connect(_on_enemy_died)
	_enemies_root.add_child(enemy)            # здесь enter_tree и ready
	return enemy
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [PackedScene](https://docs.godotengine.org/en/stable/classes/class_packedscene.html) | справочник API, 4.7 | `pack`, `instantiate`, `GenEditState`, пример с owner |
| [Nodes and scene instances](https://docs.godotengine.org/en/stable/tutorials/scripting/nodes_and_scene_instances.html) | документация Godot, 4.7 | `load` против `preload`, `free` против `queue_free` |
| [Scenes versus scripts](https://docs.godotengine.org/en/stable/tutorials/best_practices/scenes_versus_scripts.html) | документация Godot | Почему сцена быстрее дерева из кода |
| [Godot 4.6 release](https://godotengine.org/releases/4.6/) | Godot Foundation, 2026 | Unique Node IDs в файлах сцен |
| [Issue #115971](https://github.com/godotengine/godot/issues/115971) | godotengine, 2026 | Пересохранение сцен после перехода на 4.6+ |

---

## Наследование сцен, композиция и Editable Children

### Ключевые выводы

- Композиция — способ по умолчанию. Сцена-«компонент» (Hurtbox, Health, Interactable) с `@export`-параметрами на корне и сигналами наружу собирается в сущность как дочерний узел. Сцена понятна сама по себе и не знает о родителе ([Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html)).
- Наследование сцен (Scene → New Inherited Scene) хранит только отличия от базовой сцены: изменения базы расходятся по наследникам, переопределённые свойства помечены значком возврата. Подходит для вариантов одной сущности: «враг → лучник, мечник» с общей разметкой.
- Ограничения наследования: нельзя удалить узел базовой сцены, только спрятать или отключить; смена типа или имени узла в базе может молча разорвать связь ([#57637](https://github.com/godotengine/godot/issues/57637)); в цепочках A → B → C → D изменения в редакторе распространяются ненадёжно ([#104546](https://github.com/godotengine/godot/issues/104546), открыт с 4.4). Держите не больше 2–3 уровней ([UhiyamaLab](https://uhiyama-lab.com/en/notes/godot/editable-children-vs-scene-inheritance/)). В рантайме наследования нет: это обычная сцена с базой и списком правок.
- Наследование сцены и наследование скрипта — разные вещи. У наследника обычно свой скрипт `extends "res://enemy.gd"` (или `class_name`), который расширяет базовый через `super()`.
- Editable Children (ПКМ по экземпляру → Editable Children) открывает внутренности экземпляра для правок в этой конкретной сцене. Правки хранятся во внешнем файле по путям внутренних узлов. Это быстрый способ разовой настройки, но правка не переиспользуется, а внешняя сцена начинает зависеть от внутренней структуры чужой сцены. Известные баги: повторное подключение сигналов ([#85372](https://github.com/godotengine/godot/issues/85372)), изменение поведения «Local to Scene» с 4.6 ([#121428](https://github.com/godotengine/godot/issues/121428)).
- Вместо Editable Children выносите настраиваемое в `@export` на корне сцены (в том числе `@export var sprite_texture: Texture2D` или `@export var shape: Shape2D`), а нужные снаружи узлы — в свойства-ссылки. Предложение «Exposed Nodes» (явно открыть отдельные узлы экземпляра) пока не влито ([PR #84018](https://github.com/godotengine/godot/pull/84018)).
- Общие ресурсы. Shape, Material, Curve в экземплярах одной сцены — один объект. Правка в одном экземпляре меняет все. Нужна независимость — Make Unique в редакторе, `resource_local_to_scene` или `duplicate()` в коде (см. [idioms-patterns.md](idioms-patterns.md#антипаттерны)).

| Вопрос | Композиция | Наследование сцен | Editable Children |
|---|---|---|---|
| Переиспользование | Высокое, компонент в любой сущности | Варианты одной сущности | Нет, только этот экземпляр |
| Связность | Низкая, через `@export` и сигналы | Наследник зависит от структуры базы | Внешняя сцена зависит от внутренностей |
| Рефакторинг | Простой | Болезненный, нельзя удалить базовые узлы | Ломается при перестройке внутренней сцены |
| Когда брать | По умолчанию | Общая разметка и параметры у 3+ вариантов | Разовая правка уровня, прототип |

```gdscript
# Плохо: уровень лезет во внутренности экземпляра (нужны Editable Children)
$Enemy/Sprite2D/AnimationPlayer.speed_scale = 2.0

# Хорошо: сцена сама объявляет, что настраивается снаружи
# enemy.gd
@export var anim_speed: float = 1.0:
	set(value):
		anim_speed = value
		if is_node_ready():
			_anim.speed_scale = value
@onready var _anim: AnimationPlayer = %AnimationPlayer

func _ready() -> void:
	_anim.speed_scale = anim_speed
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html) | документация Godot, 4.7 | Слабая связность и пять способов инъекции зависимостей |
| [What are Godot classes](https://docs.godotengine.org/en/stable/tutorials/best_practices/what_are_godot_classes.html) | документация Godot | Сцена как расширение скрипта корня |
| [Creating instances](https://docs.godotengine.org/en/stable/getting_started/step_by_step/instancing.html) | документация Godot, 4.7 | Переопределение свойств экземпляра |
| [Editable Children vs Scene Inheritance](https://uhiyama-lab.com/en/notes/godot/editable-children-vs-scene-inheritance/) | UhiyamaLab, 2025–2026 | Плюсы, минусы и ловушки обоих подходов |
| [Inheritance VS composition](https://forum.godotengine.org/t/godot-design-flaw-inheritance-vs-composition/35115) | форум Godot | Спор практиков, где композиция неудобна |
| [Composition limitation](https://forum.godotengine.org/t/composition-limitation-issue-when-customizing-simple-instanced-scenes/85879) | форум Godot | Типичная проблема доступа к узлам экземпляра |
| [Issue #104546](https://github.com/godotengine/godot/issues/104546) | godotengine, 2025 | Ненадёжная многоуровневая наследуемость в редакторе |
| [PR #84018: Exposed Nodes](https://github.com/godotengine/godot/pull/84018) | godotengine, 2023–2026 | Будущая альтернатива Editable Children, [предложение #8266](https://github.com/godotengine/godot-proposals/issues/8266) |

---

## Уникальные имена и NodePath

### Ключевые выводы

- `%Имя` (ПКМ → Access as Unique Name) находит узел по имени в пределах той же сцены, то есть среди узлов с тем же `owner`. Путь можно менять без правки кода ([Scene unique nodes](https://docs.godotengine.org/en/stable/tutorials/scripting/scene_unique_nodes.html)). Из другой сцены `%Имя` даёт `null`; цепочка `get_node("%Sword/%Hilt")` проходит через уникальный узел вложенной сцены.
- `$Путь` — сокращение `get_node("Путь")`. Путь относительный от текущего узла, `..` — родитель, `/root/...` — абсолютный, работает только в дереве ([Node.get_node](https://docs.godotengine.org/en/stable/classes/class_node.html)). Если узла нет — ошибка и `null`; `get_node_or_null()` молчит, `has_node()` проверяет.
- Пути к своим детям — нормально. Пути вверх (`../..`) и в чужие ветки (`/root/Main/World/Player`) — жёсткая связь, которая ломается при любой перестройке. Замена — `@export var target: Node2D` (ссылка на узел в инспекторе, хранится как NodePath), сигналы или группы.
- Шесть типичных причин `null` от `get_node`: опечатка или регистр, имя типа вместо имени узла, неполный путь, `%` без отметки, переименование без правки кода, обращение до `_ready` ([GDQuest](https://www.gdquest.com/library/null_instance_error)). Седьмая — узел потерял `owner` после `remove_child`/`add_child` (см. выше).
- Литерал `^"Path"` — `NodePath`, `&"name"` — `StringName`. В горячем коде кэшируйте узел в `@onready`, а не путь.

```gdscript
# Плохо: связь с конкретным местом в чужой сцене
@onready var player = get_node("/root/Main/World/Player")

# Хорошо: зависимость задаётся снаружи и видна в инспекторе
@export var player: Player
@onready var _muzzle: Marker2D = %Muzzle      # внутренняя деталь своей сцены
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Scene unique nodes](https://docs.godotengine.org/en/stable/tutorials/scripting/scene_unique_nodes.html) | документация Godot, 4.7 | Область видимости `%`, цепочки, сравнение с `find_child` |
| [Fixing null instance errors](https://www.gdquest.com/library/null_instance_error) | GDQuest, 2026 | Шесть причин `null` и как их найти |
| [Node communication](https://kidscancode.org/godot_recipes/4.x/basics/node_communication/index.html) | KidsCanCode | Как узлам находить друг друга без хрупких путей |

---

## Изменение дерева и удаление узлов

### Ключевые выводы

- `queue_free()` ставит узел в очередь на удаление в конце текущего кадра, после остальных отложенных вызовов ([Node](https://docs.godotengine.org/en/stable/classes/class_node.html)). До этого узел жив и в дереве, `is_queued_for_deletion()` = true; повторный `queue_free()` безопасен (проверено на 4.7.2). Удаляются и все дети.
- `free()` удаляет сразу. В дереве это опасно, если в стеке вызовов есть код этого узла или его перебирает родитель. Документация: «используйте `queue_free()`, если не уверены» ([Nodes and scene instances](https://docs.godotengine.org/en/stable/tutorials/scripting/nodes_and_scene_instances.html)). Узел в дереве из другого потока `free()` удалить нельзя: движок отменит удаление ([node.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/node.cpp)).
- `remove_child()` не удаляет узел, а делает его сиротой (orphan). Сирота живёт, пока вы его не вернёте или не освободите. Забытые сироты — классическая утечка; смотрите монитор `Object → Orphan Nodes` и `Node.print_orphan_nodes()` (только debug-сборки).
- `reparent(new_parent, keep_global_transform = true)` — это `remove_child` + `add_child` с сохранением глобального положения и владельца. Срабатывают `_exit_tree` и `_enter_tree`, `_ready` — нет (проверено на 4.7.2). Внутри физического колбэка менять дерево нельзя: `reparent.call_deferred(...)`. Для `Area2D/3D` перенос вызывает повторные сигналы входа ([#14578](https://github.com/godotengine/godot/issues/14578)).
- `replace_by(node)` переносит детей в новый узел, а старый снимает с дерева, но не удаляет.
- Пока родитель добавляет детей и раздаёт им `_ready`, он «занят»: `add_child`, `move_child`, `remove_child` у него из `_ready` ребёнка дают ошибку «Parent node is busy setting up children» (проверено на 4.7.2). Решение — `add_child.call_deferred(node)` или добавлять к своему узлу, а не к родителю.
- В колбэках физики (`body_entered`) и при обходе `get_children()` с удалением используйте `call_deferred`/`queue_free`. Перебор копии массива детей безопасен, удаление из живого списка во время обхода — нет.
- Подробности про `call_deferred` и `set_deferred` — в [signals-async-threads.md](signals-async-threads.md#отложенные-вызовы).

```gdscript
# Плохо: free() посреди обработки и сирота после remove_child
func _on_body_entered(body: Node2D) -> void:
	body.free()                                 # может уронить итерацию физики
	$Pickups.remove_child($Pickups/Coin)        # монета навсегда в памяти

# Хорошо
func _on_body_entered(body: Node2D) -> void:
	body.queue_free()
	var coin := $Pickups/Coin
	coin.reparent.call_deferred(_collected_root)  # или coin.queue_free()

# После await проверяйте, что узел ещё жив
await get_tree().create_timer(1.0, false).timeout
if not is_instance_valid(target) or target.is_queued_for_deletion():
	return
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Node: queue_free, remove_child, reparent](https://docs.godotengine.org/en/stable/classes/class_node.html) | справочник API, 4.7 | Точные гарантии каждого метода |
| [Object.free / is_queued_for_deletion](https://docs.godotengine.org/en/stable/classes/class_object.html) | справочник API | Что становится недействительным и когда |
| [scene/main/node.cpp @ 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/node.cpp) | исходники Godot | Сообщения «busy», логика `reparent` и очистки владельца |
| [Issue #34207](https://github.com/godotengine/godot/issues/34207) | godotengine, 2019 | Почему не стоит переносить узлы прямо в `body_entered` |

---

## Выбор базового типа

### Ключевые выводы

- `Object` — самый лёгкий, но память освобождается вручную (`free()`), ссылки могут «протухнуть» без предупреждения. Нужен редко: свои структуры движкового уровня, `MainLoop`.
- `RefCounted` (по умолчанию для скрипта без `extends`) — данные и логика без дерева: модели, калькуляторы, состояния ИИ, команды. Освобождается сам, когда ссылок нет; циклы разрывать `weakref()`.
- `Resource` — данные, которые редактируются в инспекторе и сохраняются в `.tres`: статы, предметы, конфиги. Разделяется между пользователями, пока не сделан уникальным ([Node alternatives](https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html)).
- `Node` — нужен процесс, уведомления, группы, сигналы дерева, место в иерархии, но без положения в пространстве: менеджеры, таймеры, контроллеры, машины состояний.
- `Node2D`/`Node3D` — есть трансформ. Важно: обычный `Node` между `Node2D`-родителем и `Node2D`-ребёнком разрывает наследование трансформа, ребёнок перестаёт двигаться с родителем. Контейнеры внутри 2D-мира делайте `Node2D`, внутри 3D — `Node3D`.
- `Control` — интерфейс: якоря, контейнеры, фокус, темы, ввод через `_gui_input`. Для HUD поверх мира — `CanvasLayer` с `Control` внутри. `Control` внутри `Node2D` работает, но разметка якорей считается от родительского `Control`, а не от экрана.
- Правило из документации: «если это понятие, специфичное для вашей игры, это всегда сцена»; переиспользуемый между проектами инструмент — скрипт с `class_name` ([Scenes versus scripts](https://docs.godotengine.org/en/stable/tutorials/best_practices/scenes_versus_scripts.html)).

| Нужно | Тип | Пример |
|---|---|---|
| Чистые данные или логика без дерева | `RefCounted` | `InventoryModel`, `DamageCalculator` |
| Данные, редактируемые в инспекторе | `Resource` | `ItemData.tres`, `EnemyStats.tres` |
| Поведение без положения | `Node` | `StateMachine`, `SaveService` |
| Объект в 2D/3D-мире | `Node2D`/`Node3D` или физическое тело | `Player`, `Pickup` |
| Интерфейс | `Control`, внутри `CanvasLayer` для HUD | `HealthBar`, `PauseMenu` |
| Тысячи одинаковых объектов | Данные в массивах + `MultiMesh`/серверы | Пули, трава, частицы-логика |

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [When and how to avoid using nodes for everything](https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html) | документация Godot | Object, RefCounted, Resource против Node |
| [Overview of Godot's key concepts](https://docs.godotengine.org/en/4.6/getting_started/introduction/key_concepts_overview.html) | документация Godot, 4.6 | Узлы, сцены, дерево, сигналы — базовые понятия |
| [The 4 essential building blocks](https://www.gdquest.com/library/getting_started_4_essential_godot_concepts) | GDQuest | Как узлы, сцены, скрипты и сигналы работают вместе |

---

## Сколько узлов слишком много

### Ключевые выводы

- Официального порога нет. Документация говорит о проблемах на уровне «десятков тысяч экземпляров», тогда переходят на серверы ([Using servers](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html)). Сотни и пара тысяч узлов в уровне — норма.
- Стоимость складывается не из самого факта узла, а из того, что он делает: `_process` у каждого, сигналы каждый кадр, физика, отрисовка без батчинга. На форуме случай с 8 000 узлов упирался в скрипты, а не в количество ([форум](https://forum.godotengine.org/t/how-to-properly-organize-a-project-with-a-high-node-count/138140)) [не проверено].
- Порядок отступления: убрать лишний `_process` → один менеджер вместо тысячи скриптов → `MultiMeshInstance2D/3D` → прямые вызовы `RenderingServer`/`PhysicsServer` с RID. Цифры и харнесс — в [performance.md](performance.md#рендеринг-батчинг-multimesh-серверы-шейдеры).
- Глубокие иерархии тоже стоят: изменение трансформа корня пересчитывает всё поддерево. С 4.4 SceneTree переработан, перенос и переименование узлов в больших сценах стали заметно быстрее ([Godot 4.4](https://godotengine.org/releases/4.4/)).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Optimization using Servers](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html) | документация Godot, 4.7 | Когда и как обходить дерево сцены |
| [CPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html) | документация Godot | Поиск реального узкого места |
| [High node count](https://forum.godotengine.org/t/how-to-properly-organize-a-project-with-a-high-node-count/138140) | форум Godot, 2026 | Практический разбор большого уровня |

---

## Организация файлов сцен

### Ключевые выводы

- Одна переиспользуемая сущность — одна `.tscn`, скрипт рядом с тем же именем: `enemy.tscn` + `enemy.gd`. Файлы в `snake_case`, узлы в `PascalCase` (подробно — [architecture.md](architecture.md#структура-папок)).
- Корень сцены несёт её публичный интерфейс: `@export`-параметры, сигналы, методы. Внутренние узлы — детали реализации, наружу открываются через свойства, а не пути.
- Большие уровни дробите на подсцены (комнаты, секции, слои декора). Меньше конфликтов слияния в `.tscn`, быстрее открытие, проще параллельная работа.
- Текстовый `.tscn` хорошо читается в диффах. Шум: `unique_id` с 4.6 и переупорядочивание при пересохранении. Пересохраните все сцены одной правкой после перехода на 4.6+, а не по одной в фичевых коммитах.
- Точка входа одна: `main.tscn` с ветками World и GUI ([Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html)). Тестовая сцена-песочница для каждой фичи (F6 «запустить текущую сцену») проверяет, что сцена работает сама по себе.

---

## Tool-скрипты и предупреждения конфигурации

### Ключевые выводы

- `@tool` запускает скрипт в редакторе, включая `_process`. Игровую логику закрывайте проверкой `Engine.is_editor_hint()`. Скрипты, которые вызывает tool-скрипт, тоже должны быть `@tool` (кроме статических методов, констант и enum); наследник tool-скрипта сам по себе не tool ([Running code in the editor](https://docs.godotengine.org/en/stable/tutorials/plugins/running_code_in_the_editor.html)).
- Узлы, созданные tool-скриптом, не видны в доке Scene и не сохраняются, пока не выставлен `owner = get_tree().edited_scene_root` ([форум](https://forum.godotengine.org/t/how-to-instantiate-in-a-tool-script/66207)). Для узлов внутри экземпляра чужой сцены это сработает, только если у экземпляра включены Editable Children.
- С `queue_free()` в редакторе — «предельная осторожность»: можно удалить узел, который использует редактор. Корень редактируемой сцены движок удалить не даст ([node.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/node.cpp)). Правки tool-скриптом не попадают в undo, пользуйтесь `EditorUndoRedoManager` и контролем версий.
- `_get_configuration_warnings() -> PackedStringArray` показывает жёлтый значок у узла в доке Scene. Метод вызывается в редакторе, поэтому скрипту нужен `@tool`. Обновление — `update_configuration_warnings()` из сеттеров, иначе предупреждение обновится только при переоткрытии сцены. Частая ошибка — имя метода без `s` на конце ([форум](https://forum.godotengine.org/t/how-to-create-custom-editor-warnings-in-a-tool-script/37573)). Синтаксис Godot 3 `tool` и `_get_configuration_warning` [устарело] ([DEV](https://dev.to/hurricaneinteractive/godot-show-editor-warnings-on-nodes-2p8p)).
- Предупреждения — дешёвый способ сделать переиспользуемую сцену «защищённой от неправильной сборки»: нет обязательной ссылки, нет нужного ребёнка, неверный родитель. Аннотация `@required` пока лишь предложение ([PR #111636](https://github.com/godotengine/godot/pull/111636)), переработка системы предупреждений — [PR #90049](https://github.com/godotengine/godot/pull/90049).
- Кнопка в инспекторе для редакторских действий — `@export_tool_button` (4.4+).

```gdscript
@tool
class_name Hurtbox
extends Area2D

@export var health: Health:
	set(value):
		health = value
		update_configuration_warnings()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if health == null:
		warnings.append("Назначьте Health: без него урон не применяется.")
	if not get_children().any(func(c: Node) -> bool: return c is CollisionShape2D or c is CollisionPolygon2D):
		warnings.append("Нужен CollisionShape2D или CollisionPolygon2D.")
	return warnings

func _ready() -> void:
	if Engine.is_editor_hint():
		return                                    # игровая логика только в игре
	area_entered.connect(_on_area_entered)
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Running code in the editor](https://docs.godotengine.org/en/stable/tutorials/plugins/running_code_in_the_editor.html) | документация Godot, 4.7 | `@tool`, `is_editor_hint`, owner, предупреждения |
| [Node._get_configuration_warnings](https://docs.godotengine.org/en/stable/classes/class_node.html) | справочник API | Контракт метода и `update_configuration_warnings` |

---

## Инструменты редактора для работы со сценами

### Ключевые выводы

- Remote-дерево. Во время запуска из редактора в доке Scene появляются вкладки Remote и Local. Remote показывает живое дерево игры и позволяет смотреть и менять свойства ([Overview of debugging tools](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/overview_of_debugging_tools.html)). С 4.5 можно выделять несколько узлов и править общие свойства ([Godot 4.5](https://godotengine.org/releases/4.5/)), в 4.7 Remote-инспектор показывает имена enum и сворачивает группы свойств ([Godot 4.7](https://godotengine.org/releases/4.7/)). Это первый инструмент, когда «узел не там» или «узлов слишком много».
- Утечки узлов. Монитор `Object → Orphan Nodes` в отладчике, `print_orphan_nodes()`, а с 4.6 снимки ObjectDB для сравнения живых объектов между двумя моментами ([Godot 4.6](https://godotengine.org/releases/4.6/)).
- Save Branch as Scene (ПКМ по узлу) выносит поддерево в новый `.tscn` и заменяет его экземпляром. Это основной способ «вырастить» компонент из прототипа. Из наследуемой сцены команда недоступна ([форум](https://forum.godotengine.org/t/save-branch-as-scene/23431)) [не проверено].
- Make Local (ПКМ по экземпляру) превращает экземпляр в обычные узлы текущей сцены и рвёт связь с исходным файлом. Последующие правки исходной сцены сюда больше не придут.
- Clear Inheritance делает то же с наследуемой сценой. Change Type меняет класс узла с сохранением совместимых свойств. Copy Node Path и перетаскивание узла в редактор кода с Ctrl дают точный путь или `@onready`-строку.
- 4.6: группы можно назначать сразу нескольким выделенным узлам; 4.7: индикатор места вставки при перетаскивании в дереве и режим рисования сценами в 2D (Scene Paint) для расстановки объектов ([Godot 4.7](https://godotengine.org/releases/4.7/)).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Overview of debugging tools](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/overview_of_debugging_tools.html) | документация Godot, 4.7 | Remote в доке Scene |
| [Godot 4.5 release](https://godotengine.org/releases/4.5/) | Godot Foundation, 2025 | Мультивыделение в Remote-дереве |
| [Godot 4.7 release](https://godotengine.org/releases/4.7/) | Godot Foundation, июнь 2026 | Remote-инспектор, Scene Paint, перетаскивание в дереве |

---

## Антипаттерны

| Антипаттерн | Почему плохо | Замена |
|---|---|---|
| Доступ к детям в `_init` или в инициализаторе без `@onready` | Детей ещё нет, `null` | `@onready` или `_ready` |
| Ребёнок вызывает родителя в своём `_ready` | Родитель ещё не готов | Сигнал вверх, инъекция сверху |
| `get_node("/root/Main/World/Player")`, `../../..` | Ломается при любой перестройке | `@export`-ссылка, сигнал, группа |
| Расчёт на повторный `_ready` после `remove_child`/`add_child` | `_ready` не вызовется | `request_ready()` или логика в `_enter_tree` |
| `remove_child` + `add_child` для смены родителя в сцене | Теряется `owner`, `%Имя` возвращает `null` | `reparent()` |
| `remove_child` без последующего `add_child` или `queue_free` | Сирота, утечка памяти | `queue_free()`, монитор Orphan Nodes |
| `free()` у узла, который сейчас обрабатывается или перебирается | Падение или ошибка доступа | `queue_free()` |
| Изменение дерева в `body_entered` и других физических колбэках | Ошибка «flushing queries», двойные сигналы | `call_deferred`, `set_deferred` |
| `add_child` к родителю из `_ready` ребёнка | «Parent node is busy setting up children» | `add_child.call_deferred(node)` |
| `get_tree().create_timer(t)` для игровой задержки | Срабатывает во время паузы | `create_timer(t, false)` |
| `visible = false` вместо выключения | Скрипты и физика работают дальше | `process_mode = DISABLED` или снятие с дерева |
| Обращение к `current_scene` сразу после `change_scene_*` | Там `null` до конца кадра | `await get_tree().scene_changed` |
| Узлы, созданные кодом в `@tool` или перед `pack()`, без `owner` | Не сохраняются | `owner = edited_scene_root` / корень сцены |
| `duplicate()` поддерева, затем `pack()` | Владельцы детей сброшены, дети выпадают | Переприсвоить `owner` или `instantiate()` заново |
| Editable Children как основной способ настройки | Внешняя сцена зависит от внутренностей чужой | `@export` на корне сцены |
| Глубокие цепочки наследования сцен (4+) | Ненадёжное распространение, тяжёлый рефакторинг | Композиция, 1–2 уровня наследования |
| Общий Shape/Material правится у одного экземпляра | Меняются все | Make Unique, `resource_local_to_scene`, `duplicate()` |
| Обычный `Node` как контейнер в 2D/3D-иерархии | Рвётся наследование трансформа | `Node2D`/`Node3D` |
| Узел на каждую единицу данных (клетка, пуля-логика) | Нагрузка на SceneTree | `RefCounted`, массивы, `MultiMesh`, серверы |
| Подписка на `SceneTree.node_added` в игровом коде | Вызов на каждый узел уровня | Явная регистрация, группы |
| Много `process_priority` для разруливания порядка | Скрытые зависимости | Один оркестратор вызывает шаги по порядку |
| `PackedScene` как формат сохранения игры | Может выполнить код при загрузке | Свои данные, JSON/бинарный формат |
| `@tool` без `Engine.is_editor_hint()` в игровой логике | Игра «играет» в редакторе, портит сцену | Ранний `return` в редакторе |
| Godot 3: `tool`, `yield(get_tree(), "idle_frame")`, `instance()`, `change_scene()`, `pause_mode`, `get_tree().set_input_as_handled()` [устарело] | Не компилируется или ведёт себя иначе | `@tool`, `await get_tree().process_frame`, `instantiate()`, `change_scene_to_file()`, `process_mode`, `get_viewport().set_input_as_handled()` |

---

## Чеклист ревью сцены

1. Сцена запускается сама по себе (F6) без автозагрузок, которые ей не объявлены, и без ошибок в консоли.
2. Корень сцены — правильный тип: `Node2D`/`Node3D`/физическое тело для мира, `Control` для UI, `Node` только для поведения без положения.
3. Нет обычного `Node` между `Node2D`/`Node3D`-узлами, которые должны двигаться вместе.
4. Публичный интерфейс сцены (`@export`, сигналы, методы) на корне; снаружи никто не обращается к внутренним путям.
5. Нет путей вверх (`..`) и абсолютных (`/root/...`) к чужим узлам; зависимости приходят через `@export`, инъекцию или сигналы.
6. Внутренние узлы, к которым обращается скрипт, кэшированы в `@onready` или отмечены `%` и не ищутся каждый кадр.
7. `_init` без обязательных аргументов и без обращений к дереву и детям.
8. В `_ready` ребёнка нет обращений к родителю; родитель настраивает детей в своём `_ready` или до `add_child`.
9. Экземпляры настраиваются между `instantiate()` и `add_child()`; сеттеры `@export` проверяют `is_node_ready()`, если трогают детей.
10. Код, который должен выполняться при каждом входе в дерево, лежит в `_enter_tree`, а не в `_ready`; при повторном использовании узла есть `request_ready()`, если он нужен.
11. Пустые `_process`/`_physics_process` удалены; обработка выключается `set_process(false)`, когда узлу нечего делать.
12. `process_priority` использован только для явной, прокомментированной зависимости порядка.
13. У каждой ветки осмысленный `process_mode`: меню паузы `WHEN_PAUSED`/`ALWAYS`, мир по умолчанию; всё, что не должно работать, — `DISABLED`, а не только `visible = false`.
14. Игровые задержки через `create_timer(t, false)` или `Timer` с правильным `process_mode`; у твинов узла — `Node.create_tween()`.
15. Удаление — `queue_free()`; `free()` только с обоснованием; после `await` проверяется `is_instance_valid()`.
16. Нет `remove_child()` без дальнейшей судьбы узла; монитор Orphan Nodes не растёт при входе и выходе из сцены.
17. Смена родителя внутри сцены — через `reparent()`; в физических колбэках — `call_deferred`.
18. Добавление детей к родителю из `_ready` ребёнка и изменения дерева из колбэков физики сделаны отложенно.
19. Узлы, созданные кодом и сохраняемые в сцену (tool, `pack()`), получают `owner`; после `duplicate()` владельцы переприсвоены.
20. Уникальные имена `%` используются только внутри своей сцены; цепочки `%A/%B` — только к узлам, которые вложенная сцена сама отметила.
21. Editable Children не используются для постоянной настройки; нужное вынесено в `@export` на корне вложенной сцены.
22. Наследование сцен не глубже 2–3 уровней; базовая сцена не знает о наследниках; у наследника свой скрипт, расширяющий базовый через `super()`.
23. Общие ресурсы (Shape, Material, Curve), которые меняются в рантайме, уникальны на экземпляр (`resource_local_to_scene` или `duplicate()`).
24. Для одинаковых сущностей в больших количествах выбран не узел на штуку, а `MultiMesh`, пул или данные + сервер; решение подтверждено профилем.
25. Группы с осмысленными именами (`StringName`, константы); для глобальных групп — запись в Project Settings; `call_group` с удалением — `GROUP_CALL_DEFERRED`.
26. После `change_scene_*` код ждёт `scene_changed`, а тяжёлые уровни грузятся в фоне.
27. `@tool`-скрипты закрывают игровую логику `Engine.is_editor_hint()` и не вызывают `queue_free()` на узлах, которыми владеет редактор.
28. Переиспользуемые сцены и компоненты реализуют `_get_configuration_warnings()` для обязательных ссылок, детей и типа родителя и вызывают `update_configuration_warnings()` в сеттерах.
29. Сцены пересохранены на текущей версии (после 4.6 — с `unique_id`), шум пересохранения не смешан с фичевыми изменениями.
30. Большой уровень разбит на подсцены; `.tscn` одной сущности не правят одновременно несколько человек.
31. Remote-дерево во время игры показывает ожидаемую структуру, без лишних «@Node@123» от безымянных `add_child`; узлы, созданные кодом, получают понятные имена.

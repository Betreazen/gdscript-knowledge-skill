# Физика, коллизии и навигация в Godot 4

Справочник по физическому движку и навигации Godot 4: какое тело выбрать, как правильно двигать `CharacterBody` и `RigidBody`, как работают `Area`, слои и маски, какие формы коллизий дешевле, как настроить тики и интерполяцию, когда брать `RayCast`, а когда `PhysicsDirectSpaceState`, чем Jolt отличается от Godot Physics, как устроены navmesh, агенты, избегание и `AStarGrid2D`. Здесь собраны правила корректности. Производительность физики кратко описана в [performance.md → Физика и навигация](performance.md#физика-и-навигация), обзор ИИ и аддонов — в [domains.md → 5. ИИ и навигация](domains.md#5-ии-и-навигация), автоматы состояний — в [architecture.md → Машины состояний и ИИ](architecture.md#машины-состояний-и-ии). Актуально на октябрь 2026 года, Godot 4.7.2 (4.7 вышла 18 июня 2026; Jolt — физика по умолчанию для новых 3D-проектов с 4.6).

Метки: `[устарело]` — API или совет Godot 3 и ранних 4.x, рядом указана замена; `[не проверено]` — утверждение из вторичного источника или без собственного замера; «(проверено на 4.7.2)» — воспроизведено скриптом в headless-сборке 4.7.2.

- [Какое тело выбрать](#какое-тело-выбрать)
- [CharacterBody: move_and_slide без сюрпризов](#characterbody-move_and_slide-без-сюрпризов)
- [RigidBody: управляйте силами, а не позицией](#rigidbody-управляйте-силами-а-не-позицией)
- [Area2D/3D: зоны, триггеры, переопределение гравитации](#area2d3d-зоны-триггеры-переопределение-гравитации)
- [Слои и маски коллизий](#слои-и-маски-коллизий)
- [Формы коллизий: выбор и цена](#формы-коллизий-выбор-и-цена)
- [Тики, интерполяция и потоки](#тики-интерполяция-и-потоки)
- [Запросы: RayCast, ShapeCast и PhysicsDirectSpaceState](#запросы-raycast-shapecast-и-physicsdirectspacestate)
- [Jolt и Godot Physics, суставы, материалы](#jolt-и-godot-physics-суставы-материалы)
- [Особенности 2D-физики](#особенности-2d-физики)
- [Отладка физики и навигации](#отладка-физики-и-навигации)
- [Навигация: сервер, регионы, запекание](#навигация-сервер-регионы-запекание)
- [NavigationAgent и избегание](#navigationagent-и-избегание)
- [Синхронизация карты: первый запрос пути](#синхронизация-карты-первый-запрос-пути)
- [Navmesh или AStar](#navmesh-или-astar)
- [Антипаттерны](#антипаттерны)
- [Чеклист физики и навигации](#чеклист-физики-и-навигации)
- [Ресурсы](#ресурсы)

---

## Какое тело выбрать

### Ключевые выводы

- Все узлы физики наследуют `CollisionObject2D/3D`; тела (`StaticBody`, `AnimatableBody`, `RigidBody`, `CharacterBody`) — ещё и `PhysicsBody`. Тело без дочернего `CollisionShape`/`CollisionPolygon` ни с чем не сталкивается ([Physics introduction](https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html)).
- `StaticBody` движок не двигает. Через `constant_linear_velocity` он может толкать других, как конвейер. Двигать его скриптом как платформу — ошибка: для этого есть `AnimatableBody`.
- `AnimatableBody2D/3D` — платформы, двери, лифты. Двигайте его кодом, `AnimationPlayer` или `RemoteTransform`. Скорость тело вычисляет из перемещения и передаёт персонажам и `RigidBody`. `sync_to_physics = true` по умолчанию (проверено на 4.7.2); не совмещайте это свойство с `move_and_collide()` ([AnimatableBody3D](https://docs.godotengine.org/en/stable/classes/class_animatablebody3d.html)).
- `CharacterBody2D/3D` — игрок, враги, всё, что движется по правилам геймплея. Гравитации и трения у него нет, всё пишете сами.
- `RigidBody2D/3D` — ящики, мячи, обломки, рэгдоллы. Им управляет движок, вы прикладываете силы.
- `Area2D/3D` — триггеры, хитбоксы, зоны воды и гравитации, области звука. Она ничего не блокирует.
- `KinematicBody2D/3D` [устарело] → `CharacterBody2D/3D`. Режимы `RigidBody.MODE_*` [устарело] → `freeze` + `freeze_mode`.

| Задача | Узел | Почему не другой |
|---|---|---|
| Стены, пол, уровень | `StaticBody` (+ `TileMapLayer`/`GridMap` с коллизиями) | Дешевле всего, спит всегда |
| Движущаяся платформа, дверь, лифт | `AnimatableBody` | `StaticBody`, сдвинутый через `position`, не передаёт скорость; Area его не видит (см. ниже) |
| Игрок платформера, top-down, FPS | `CharacterBody` | Точное управление, `is_on_floor()`, предсказуемость |
| Физический предмет, реакция на удары | `RigidBody` | Импульсы, массы, сон, стопки |
| Предмет, который иногда несут руками | `RigidBody` + `freeze` (`FREEZE_MODE_KINEMATIC`) | Можно временно выключить симуляцию без смены узла |
| Пуля: быстрая, простая | `Area` + свой шаг или `RayCast`/`ShapeCast` | `RigidBody` с CCD дороже; сотни пуль — серверы или `intersect_ray` |
| Триггер, хитбокс, сбор монет | `Area` | Не блокирует, даёт сигналы входа/выхода |
| Рэгдолл | `PhysicalBone3D` + `PhysicalBoneSimulator3D` | Кости скелета как тела ([Ragdoll system](https://docs.godotengine.org/en/stable/tutorials/physics/ragdoll_system.html)) |

---

## CharacterBody: move_and_slide без сюрпризов

### Ключевые выводы

- В Godot 4 `move_and_slide()` вызывается без аргументов. Он читает свойство `velocity` и сам его обновляет: после приземления вертикальная скорость обнуляется (проверено на 4.7.2). `move_and_slide(velocity, Vector2.UP)` с аргументами [устарело] → `velocity`, `up_direction` и другие свойства.
- Шаг времени уже учтён внутри: скорость на `delta` не умножайте, а ускорения (гравитацию) умножайте ([Physics introduction](https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html)). Гравитацию берите из `get_gravity()` (учитывает и `Area`-переопределения) или из `ProjectSettings` (`physics/2d/default_gravity` = 980, `physics/3d/default_gravity` = 9.8).
- Вызывайте только в `_physics_process`. `position` напрямую не меняйте: это телепорт без коллизий.
- `is_on_floor()`, `is_on_wall()` и `is_on_ceiling()` описывают результат последнего вызова `move_and_slide()`. Проверяйте их после движения (для прыжка в следующем кадре) или, как в шаблоне, до изменения скорости. В тесте капсула, падающая на пол, получала `is_on_floor() == true` после приземления, к 30-му кадру (проверено на 4.7.2).
- `motion_mode`: `GROUNDED` (по умолчанию) — пол, стены и потолок определяются по `up_direction`, подходит для платформеров и FPS. `FLOATING` — всё считается стенами, режим для вида сверху и космоса; `wall_min_slide_angle` (15°) работает только в нём ([CharacterBody2D](https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html)).
- Склоны: `floor_max_angle` (45°), `floor_stop_on_slope` (не сползать стоя), `floor_constant_speed` (одинаковая скорость вверх и вниз), `floor_block_on_wall`. Прилипание при спуске со ступенек — `floor_snap_length` (2D: 1.0 px, 3D: 0.1 м по умолчанию, проверено на 4.7.2). Во время движения вверх snap не действует, поэтому прыжок не «прилипает». Для принудительного прилипания есть `apply_floor_snap()`.
- Платформы: персонаж наследует скорость тел из `platform_floor_layers` (по умолчанию все слои). Что делать со скоростью при сходе с платформы, решает `platform_on_leave`: добавить её, добавить только вертикальную часть или ничего. Реальное перемещение возвращает `get_real_velocity()`, скорость платформы — `get_platform_velocity()`.
- Коллизии за вызов: `get_slide_collision_count()` и `get_slide_collision(i)` или `get_last_slide_collision()`. В счёт входят только столкновения, которые изменили направление; итераций не больше `max_slides` (4).
- `move_and_collide(motion)` останавливается на первом столкновении и возвращает `KinematicCollision`. Нужен для отскоков (`velocity.bounce(normal)`) и своей логики скольжения. Сюда скорость умножать на `delta` нужно.
- Дрожание у стен и пола обычно лечат `safe_margin` (0.08): больше — стабильнее, меньше — точнее. Лучше не менять тики, а включить интерполяцию.

```gdscript
# Плохо (Godot 3 и типичные ошибки 4.x)
extends KinematicBody2D                      # [устарело]
func _process(delta):                         # не физический кадр
	velocity = move_and_slide(velocity * delta, Vector2.UP)  # аргументы [устарело], лишний delta
	position.x += 5                           # телепорт мимо коллизий

# Хорошо (проверено на 4.7.2)
extends CharacterBody2D

const SPEED := 220.0
const JUMP_VELOCITY := -420.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta     # ускорение × delta
	if Input.is_action_just_pressed(&"jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var dir := Input.get_axis(&"left", &"right")
	velocity.x = move_toward(velocity.x, dir * SPEED, SPEED * 8.0 * delta)
	move_and_slide()                          # без аргументов и без delta
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_collider() is RigidBody2D:
			(c.get_collider() as RigidBody2D).apply_central_impulse(-c.get_normal() * 20.0)
```

`CharacterBody` не толкает `RigidBody` сам: импульс прикладывайте вручную, как выше, иначе ящик ведёт себя как стена. Подробные рецепты (койот-тайм, буфер прыжка, лестницы) есть в [KidsCanCode: Platform character](https://kidscancode.org/godot_recipes/4.x/2d/platform_character/) и демо [2d/physics_platformer](https://github.com/godotengine/godot-demo-projects/tree/master/2d/physics_platformer).

---

## RigidBody: управляйте силами, а не позицией

### Ключевые выводы

- Не задавайте `position`, `global_transform` и `look_at()` каждый кадр: движок перестаёт корректно симулировать тело. Разовая расстановка (спавн) допустима. Тело не должно быть потомком движущегося узла, иначе родитель постоянно перезаписывает его трансформ ([RigidBody](https://docs.godotengine.org/en/stable/tutorials/physics/rigid_body.html), [RigidBody3D](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html)).
- Постоянные воздействия — `apply_central_force()`, `apply_force(force, offset)` и `apply_torque()`, каждый физический кадр. Разовые удары — `apply_central_impulse()`, `apply_impulse()` и `apply_torque_impulse()`; вызванные каждый кадр, они дают результат, зависящий от частоты тиков. Сила, которая действует, пока её не сбросят, — `add_constant_force()` / `constant_force`.
- Точный контроль состояния (телепорт, ограничение скорости, своё трение) делайте в `_integrate_forces(state)` через `PhysicsDirectBodyState`. Колбэк не вызывается, пока тело спит. `custom_integrator = true` отключает встроенные гравитацию и затухание.
- `freeze = true` + `freeze_mode`: `FREEZE_MODE_STATIC` (по умолчанию) — тело ведёт себя как статичное; `FREEZE_MODE_KINEMATIC` — двигается кодом и расталкивает других. Подходит для «взял в руки» и катсцен.
- Сон: `can_sleep = true` по умолчанию. Тело в покое засыпает и не стоит CPU (в тесте сфера уснула к 200-му кадру на обоих движках, проверено на 4.7.2). Будят его столкновение, `apply_*` или `sleeping = false`. Если телепортировали спящее тело, разбудите его.
- Масса и инерция: `mass` (1 кг по умолчанию), `inertia = 0` значит «посчитать по формам». `center_of_mass_mode = AUTO` считает центр масс по формам, `CUSTOM` берёт свойство `center_of_mass`. Смещённый центр масс делает машину устойчивее.
- Быстрые объекты проходят сквозь тонкие стены. Включите `continuous_cd` (по умолчанию выключен, дороже), утолщите стены или поднимите тики (120, 180, 240) ([Troubleshooting physics issues](https://docs.godotengine.org/en/stable/tutorials/physics/troubleshooting_physics_issues.html)).
- Сигналы `body_entered` у `RigidBody` работают только при `contact_monitor = true` и `max_contacts_reported > 0` (по умолчанию 0, проверено на 4.7.2). Контакт не равен столкновению: две параллельные грани дают четыре контакта.
- Вращение к цели — через `angular_velocity` (пример `look_follow` в документации), а не `look_at()`. Фиксация осей — `lock_rotation` и `axis_lock_*` (3D).

```gdscript
# Плохо: перезапись трансформа каждый кадр ломает симуляцию
func _physics_process(_d):
	look_at(target.global_position)
	global_position += Vector3.FORWARD * 0.1

# Хорошо: силы в _physics_process, точная правка состояния в _integrate_forces
extends RigidBody3D
@export var thrust := 30.0
@export var max_speed := 12.0
var _teleport_to: Variant = null

func _physics_process(_delta: float) -> void:
	apply_central_force(-global_basis.z * thrust)

func teleport(pos: Vector3) -> void:
	_teleport_to = pos
	sleeping = false

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _teleport_to != null:
		state.transform.origin = _teleport_to
		state.linear_velocity = Vector3.ZERO
		_teleport_to = null
	state.linear_velocity = state.linear_velocity.limit_length(max_speed)
```

---

## Area2D/3D: зоны, триггеры, переопределение гравитации

### Ключевые выводы

- `monitoring` — зона сама видит других и шлёт сигналы. `monitorable` — другие зоны видят её. Хитбоксу, который только «бьёт», `monitoring` не нужен, хёртбоксу не нужен `monitorable`; лишнее отключайте.
- Сигналы `body_entered`/`area_entered` — для реакции на событие. `get_overlapping_bodies()` и `has_overlapping_bodies()` — для опроса состояния, но список обновляется раз за физический шаг, а не сразу после перемещения ([Area2D](https://docs.godotengine.org/en/stable/classes/class_area2d.html)). В тесте тело, перенесённое в зону, дало сигнал на следующем физическом кадре; `get_overlapping_bodies()` в кадре переноса вернул 0 (проверено на 4.7.2).
- Изменить `monitoring` внутри обработчика `body_entered` нельзя: `Function blocked during in/out signal. Use set_deferred("monitoring", ...)`. Значение не меняется (проверено на 4.7.2). То же с выключением `CollisionShape` и `add_child`/`remove_child` физических узлов в колбэке: используйте `set_deferred`/`call_deferred`.
- Ловушка: `Area2D` не заметила `StaticBody2D`, перенесённый в неё через `position`. Тот же перенос `CharacterBody2D` или `AnimatableBody2D` она заметила (проверено на 4.7.2, Godot Physics 2D). Подвижные объекты делайте `AnimatableBody`, а не `StaticBody`.
- Для `_shape_entered` нужен индекс формы: сигналы `body_shape_entered(body_rid, body, body_shape_index, local_shape_index)` + `shape_find_owner()`. Пример — отдельные хитбоксы головы и тела.
- Переопределение физики: `gravity_space_override` (`COMBINE`, `REPLACE` и т. д.), точечная гравитация `gravity_point` + `gravity_point_center` (планеты), `linear_damp_space_override` (вода). Порядок задаёт `priority`: большее значение обрабатывается раньше. `CharacterBody` узнаёт итоговую гравитацию через `get_gravity()`.

```gdscript
# Хорошо: безопасное выключение зоны из её же сигнала (проверено на 4.7.2)
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		set_deferred(&"monitoring", false)
		$CollisionShape2D.set_deferred(&"disabled", true)
		collected.emit()
```

---

## Слои и маски коллизий

### Ключевые выводы

- 32 слоя на объект. `collision_layer` — в каких слоях объект находится, `collision_mask` — какие слои он сканирует. По умолчанию оба равны слою 1 ([Physics introduction](https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html)).
- Обнаружение одностороннее. Зона A видит B, если `A.collision_mask & B.collision_layer != 0`. В тесте A (слой 1, маска 2) и B (слой 2, маска 0): `A.overlaps_area(B) = true`, `B.overlaps_area(A) = false`, сигнал получила только A (проверено на 4.7.2).
- Реакция тел тоже односторонняя. На тело действуют только объекты из его маски. `RigidBody` с маской 0 падает сквозь `StaticBody` даже при маске пола 1. При A (слой 1, маска 0), падающем на подвижное `RigidBody` B (слой 2, маска 1), A не замедлился, а B оттолкнуло вниз. Так ведут себя и Godot Physics, и Jolt (проверено на 4.7.2). Маска `StaticBody` ни на что не влияет.
- `CharacterBody.move_and_slide()` учитывает только маску самого персонажа. `RayCast`/`ShapeCast` и запросы `PhysicsDirectSpaceState` — только свою маску; у параметров запроса маска по умолчанию равна `0xFFFFFFFF`, то есть «всё» (проверено на 4.7.2).
- Называйте слои: Project Settings → Layer Names → 2D Physics / 3D Physics / 2D Navigation / Avoidance. В инспекторе будут имена вместо номеров. Для экспорта есть `@export_flags_2d_physics` / `@export_flags_3d_physics`.
- Номер слоя (1–32) не равен биту. Слой N — это `1 << (N - 1)`. Для одного слоя используйте `set_collision_layer_value(N, true)` и `set_collision_mask_value(N, true)`; в тесте `set_collision_mask_value(1, true)` дал `collision_mask == 1` (проверено на 4.7.2).
- Типовая схема: 1 world, 2 player, 3 enemy, 4 player_hitbox, 5 enemy_hitbox, 6 pickup, 7 projectile, 8 trigger. Игрок: слой 2, маска world + enemy + pickup. Пуля врага: слой 7, маска world + player. Хёртбокс игрока: слой 4, маска 5.

```gdscript
# Хорошо: константы вместо магических чисел
class_name Layers
const WORLD := 1
const PLAYER := 2
const ENEMY := 3
const PICKUP := 6

static func bit(layer: int) -> int:
	return 1 << (layer - 1)

# использование
func _ready() -> void:
	collision_layer = Layers.bit(Layers.PLAYER)
	collision_mask = Layers.bit(Layers.WORLD) | Layers.bit(Layers.ENEMY) | Layers.bit(Layers.PICKUP)
	# или по одному: set_collision_mask_value(Layers.ENEMY, true)

# Плохо: collision_mask = 3   # «слои 1 и 2»? или «слой 3»? — путаница номера и бита
```

---

## Формы коллизий: выбор и цена

### Ключевые выводы

- Цена по возрастанию: круг/сфера < капсула < бокс < цилиндр < `ConvexPolygonShape` < `ConcavePolygonShape` (trimesh). Для подвижных тел берите примитивы ([Collision shapes 3D](https://docs.godotengine.org/en/stable/tutorials/physics/collision_shapes_3d.html), [2D](https://docs.godotengine.org/en/stable/tutorials/physics/collision_shapes_2d.html)).
- `ConcavePolygonShape` годится только для `StaticBody` (и замороженных статичных тел). Объёма у неё нет, контакты менее точные. Для уровня упрощайте коллизионный меш, а не используйте визуальный.
- Сложные подвижные объекты: одна convex-оболочка (Quickhull, быстро) или несколько (V-HACD, точнее, дороже). Начиная с некоторого числа частей выгоднее concave на статике. В 4.6 меню Mesh умеет создавать подходящий примитив (box, sphere, cylinder, capsule) по простому мешу ([Godot 4.6](https://godotengine.org/releases/4.6/)).
- Масштабирование тел и форм не поддерживается. Меняйте размер самого ресурса формы (`radius`, `size`), визуал масштабируйте отдельно. Общий ресурс формы перед изменением в коде копируйте (`duplicate()` или Make Unique), иначе изменятся все экземпляры ([Troubleshooting](https://docs.godotengine.org/en/stable/tutorials/physics/troubleshooting_physics_issues.html)).
- Меньше форм на теле — быстрее. Одна непреобразованная форма у `StaticBody` помогает broadphase; много смещённых форм заставляют чаще проверять narrowphase.
- Цилиндры в Godot Physics нестабильны. Для персонажа берите капсулу или бокс, либо перейдите на Jolt.
- `WorldBoundaryShape` — бесконечная плоскость (в Jolt размер ограничен настройкой `limits/world_boundary_shape_size`, 2000). `HeightMapShape3D` — ландшафт, дешевле trimesh. `SeparationRayShape` — «ноги-пружины» для персонажей и машин.

---

## Тики, интерполяция и потоки

### Ключевые выводы

- Физика идёт фиксированными тиками: `physics/common/physics_ticks_per_second = 60`, не больше `max_physics_steps_per_frame = 8` шагов за кадр (проверено на 4.7.2). Если FPS падает ниже `ticks / max_steps`, игра замедляется, а при перегрузке начинается «спираль смерти». Подняли тики — поднимите и `max_steps` (ProjectSettings в 4.7).
- Меняйте тики кратно 60 (120, 180, 240): это лечит туннелирование и дрожание стопок. Понижение до 30 экономит CPU, но без интерполяции даёт рывки.
- Физическая интерполяция: `physics/common/physics_interpolation` (по умолчанию выключена). 2D — с 4.3, 3D — с 4.4; с 4.5 3D-интерполяция живёт в SceneTree ([Godot 4.5](https://godotengine.org/releases/4.5/)). С ней игра плавная на 144 Гц при 60 тиках.
- Правила интерполяции: двигайте объекты только в `_physics_process`, в том числе твины, анимации и навигацию. После телепорта и спавна вызывайте `reset_physics_interpolation()` (для пули: задать трансформ, сбросить, сразу задать трансформ следующего тика). Камере нужна ручная интерполяция в `_process` по `get_global_transform_interpolated()` или `physics_interpolation_mode = OFF` для mouse-look ([Using physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/using_physics_interpolation.html), [Advanced](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html)).
- `physics_jitter_fix` (0.5) автоматически отключается при включённой интерполяции. Для своей интерполяции и сетевых игр ставьте 0.
- `physics/2d|3d/run_on_separate_thread` (по умолчанию выключено): физика уходит в отдельный поток, но API доступно только из physics process. С Jolt в 3D сообщения об ошибках теряют контекст (`<unknown>`), а сам режим документация Jolt называет экспериментальным ([ProjectSettings](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html), [Using Jolt](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html)).
- Во время выполнения тики меняют через `Engine.physics_ticks_per_second` и `Engine.max_physics_steps_per_frame`, интерполяцию — через `SceneTree.physics_interpolation`. Настройки проекта читаются только при старте.

---

## Запросы: RayCast, ShapeCast и PhysicsDirectSpaceState

### Ключевые выводы

- Узлы `RayCast2D/3D` и `ShapeCast2D/3D` — для постоянных проверок одного направления: земля под ногами, линия взгляда, датчик стены. Результат обновляется раз за физический кадр. Если узел сдвинули или перенастроили в этом же кадре, вызовите `force_raycast_update()` / `force_shapecast_update()`. Они работают и при `enabled = false` ([RayCast2D](https://docs.godotengine.org/en/stable/classes/class_raycast2d.html)).
- `PhysicsDirectSpaceState` (`get_world_2d().direct_space_state`) — для разовых и массовых запросов: выстрел, клик мышью, проверка места для спавна, сотни пуль. Узел на каждую пулю не создавайте.
- Доступ к space state безопасен только в `_physics_process`: в другое время пространство может быть заблокировано, особенно с физикой в отдельном потоке. Клик мышью запоминайте в `_unhandled_input`, а луч пускайте в ближайшем физическом кадре ([Ray-casting](https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html)).
- Себя исключайте: `query.exclude = [get_rid()]`. В тесте луч сверху без исключения попал в самого персонажа, с исключением — в пол (проверено на 4.7.2). Отсеивать маской дешевле, чем длинным списком исключений.
- Зоны по умолчанию не попадают в результат (`collide_with_areas = false`, `collide_with_bodies = true`). Начало луча внутри формы не считается попаданием, пока не включён `hit_from_inside` (проверено на 4.7.2).
- Методы `PhysicsDirectSpaceState2D/3D`: `intersect_ray` (первое попадание: `position`, `normal`, `collider`, `rid`, `shape`), `intersect_point`, `intersect_shape` (все пересечения, `max_results = 32`), `cast_motion` (безопасная и небезопасная доля пути), `collide_shape`, `get_rest_info` ([PhysicsDirectSpaceState2D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate2d.html)). Объекты `PhysicsRayQueryParameters` и `PhysicsShapeQueryParameters` создавайте один раз и переиспользуйте.
- В Jolt `face_index` у лучей по умолчанию равен `-1`. Включается настройкой `physics/jolt_physics_3d/queries/enable_ray_cast_face_index`, она добавляет около 25% памяти на trimesh. В Godot Physics индекс заполнен (проверено на 4.7.2: 8 против −1).

```gdscript
# Хорошо: клик мышью → луч в физическом кадре (3D)
var _pending_click: Variant = null
var _ray := PhysicsRayQueryParameters3D.new()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pending_click = event.position

func _physics_process(_delta: float) -> void:
	if _pending_click == null:
		return
	var cam := get_viewport().get_camera_3d()
	_ray.from = cam.project_ray_origin(_pending_click)
	_ray.to = _ray.from + cam.project_ray_normal(_pending_click) * 1000.0
	_ray.collision_mask = Layers.bit(Layers.WORLD) | Layers.bit(Layers.ENEMY)
	_ray.exclude = [get_rid()]
	_pending_click = null
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
	if not hit.is_empty():
		_select(hit.collider, hit.position)

# Плохо: запрос из _input — пространство может быть заблокировано
func _input(event):
	var hit = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b))
```

---

## Jolt и Godot Physics, суставы, материалы

### Ключевые выводы

- Новые проекты из Project Manager с 4.6 получают в `project.godot` строку `physics/3d/physics_engine="Jolt Physics"` ([PR #105737](https://github.com/godotengine/godot/pull/105737)). Если ключа нет, значение `DEFAULT` в 4.7.2 по-прежнему означает GodotPhysics3D. PR, переключающий `DEFAULT` на Jolt, ещё открыт ([#105762](https://github.com/godotengine/godot/pull/105762)). В тесте `project.godot` без ключа давал GodotPhysics3D: `face_index` луча 8, а с `"Jolt Physics"` — −1 (проверено на 4.7.2). По коду PR пустой `project.godot` получает Jolt только при открытии в редакторе с окном, но не в headless. Выбирайте движок явно. Детерминизм между машинами не гарантирует ни один движок [не проверено]: для отката в сетевой игре держите логику в своей детерминированной симуляции.
- Jolt обычно быстрее и стабильнее: стопки, цилиндры, большие сцены. Метку «экспериментальный» сняли в 4.6 ([PR #111115](https://github.com/godotengine/godot/pull/111115)). На 2D Jolt не распространяется. Аддон godot-jolt нужен только для 4.3 и старше [устарело] ([godot-jolt](https://github.com/godot-jolt/godot-jolt)).
- Отличия Jolt ([Using Jolt Physics](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html)):
  - Мягкие параметры суставов не поддерживаются, при изменении выдаётся предупреждение: `bias`, `damping` и `impulse_clamp` у `PinJoint3D`, `softness` и `relaxation` у `HingeJoint3D` и другие.
  - У сустава с одним телом это тело считается `node_b`, а «мир» — `node_a` (настройка `joints/world_node`). Godot Physics считает его `node_a`.
  - Замороженные кинематические `RigidBody3D` по умолчанию не сообщают о контактах со статикой и кинематикой; включает это `simulation/generate_all_kinematic_contacts`, ценой скорости.
  - Зоны сообщают о входе `SoftBody3D`, Godot Physics — нет.
  - Позиционная коррекция без «пружины» (Baumgarte), отступы встроены внутрь формы, оценка импульсов контакта точна только для пары тел без третьих.
  - `sleep_threshold_*` из `physics/3d/` на Jolt не действуют, сон настраивается в `physics/jolt_physics_3d/simulation/*`.
- Настройки аддона `physics/jolt_3d/*` переименованы в `physics/jolt_physics_3d/*` (например, `solver/velocity_iterations` → `simulation/velocity_steps`). Старые туториалы сверяйте.
- Суставы: `PinJoint`, `HingeJoint3D`, `SliderJoint3D`, `ConeTwistJoint3D`, `Generic6DOFJoint3D`, в 2D `PinJoint2D`, `GrooveJoint2D`, `DampedSpringJoint2D`. Соединённые тела по умолчанию не сталкиваются друг с другом (`exclude_nodes_from_collision`). Узлы `JoltHingeJoint3D` и подобные из аддона во встроенный модуль не вошли.
- `PhysicsMaterial`: `friction`, `bounce`, `rough` и `absorbent` меняют правило смешивания с материалом второго тела. Материал — общий ресурс, перед изменением в коде делайте `duplicate()`.

---

## Особенности 2D-физики

### Ключевые выводы

- One-way платформы: `CollisionShape2D.one_way_collision = true`, `one_way_collision_margin` (1.0) для толщины. В 4.7 добавлено `one_way_collision_direction` (по умолчанию `Vector2(0, 1)`, проверено на 4.7.2): направление теперь задаётся без поворота формы ([Godot 4.7](https://godotengine.org/releases/4.7/), [PR #104736](https://github.com/godotengine/godot/pull/104736)). Чтобы спрыгнуть вниз, на пару кадров снимите бит маски платформ.
- Тайлы: с 4.5 `TileMapLayer` сливает коллизии соседних ячеек в крупные формы, и персонаж меньше «спотыкается» о стыки. Компромисс между скоростью обновления и надёжностью задаёт `physics_quadrant_size` (16) ([Troubleshooting](https://docs.godotengine.org/en/stable/tutorials/physics/troubleshooting_physics_issues.html)).
- `CollisionPolygon2D` с `build_mode = SEGMENTS` даёт контур без площади, удобно для статичных стен. Для подвижных тел нужен `SOLIDS`, и полигон разбивается на выпуклые части.

---

## Отладка физики и навигации

### Ключевые выводы

- Меню Debug → Visible Collision Shapes и Visible Navigation в редакторе. Из командной строки — `--debug-collisions`, `--debug-navigation`, `--debug-avoidance`, `--debug-paths` (флаги есть в `--help` 4.7.2). `--fixed-fps 60` делает прогон детерминированнее по кадрам.
- Мониторы (Debugger → Monitors или `Performance.get_monitor`): `PHYSICS_2D/3D_ACTIVE_OBJECTS`, `_COLLISION_PAIRS`, `_ISLAND_COUNT`; для навигации `NAVIGATION_2D_*` и `NAVIGATION_3D_*`: регионы, агенты, полигоны, рёбра, `EDGE_FREE_COUNT` (свободные рёбра часто означают несшитые регионы) (константы проверены на 4.7.2) ([Performance](https://docs.godotengine.org/en/stable/classes/class_performance.html)). Растёт `ACTIVE_OBJECTS` — значит, тела не засыпают.
- Чтобы получить воспроизводимый тест, соберите минимальную сцену и прогоните её headless: `godot --headless --path proj -s test.gd`, со скриптом `extends SceneTree`, который считает кадры в `_physics_process`. Так проверялись все утверждения «(проверено на 4.7.2)» в этом файле.

---

## Навигация: сервер, регионы, запекание

### Ключевые выводы

- Архитектура: `NavigationServer2D/3D` → карты (map) → регионы (region с navmesh), ссылки (link), агенты и препятствия. Для каждого `World2D`/`World3D` есть карта по умолчанию: `get_world_2d().navigation_map` ([Using NavigationMaps](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationmaps.html)). С 4.5 у 2D свой сервер, и 2D-игре не нужен 3D-модуль в шаблонах экспорта ([Godot 4.5](https://godotengine.org/releases/4.5/)).
- Изменения на сервере применяются при синхронизации, после следующего физического кадра, а не сразу ([NavigationServer2D](https://docs.godotengine.org/en/stable/classes/class_navigationserver2d.html)). С 4.4–4.5 карта и регионы синхронизируются асинхронно, в фоне (`navigation/world/map_use_async_iterations` и `region_use_async_iterations`, обе `true`), отсюда добавочная задержка ([PR #100497](https://github.com/godotengine/godot/pull/100497)). Подробнее — в разделе [Синхронизация карты](#синхронизация-карты-первый-запрос-пути).
- Navmesh описывает, куда может попасть центр агента. `agent_radius` при запекании отступает от стен. Каждому размеру агента нужна своя navmesh и своя карта, запечённые из одной исходной геометрии ([Different actor types](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_different_actor_types.html)).
- Запекание: в редакторе (кнопка Bake у `NavigationRegion`) или во время игры (`bake_navigation_polygon()`/`bake_navigation_mesh()`, либо сервером `parse_source_geometry_data()` → `bake_from_source_geometry_data_async()`). Парсинг дерева идёт только в главном потоке. Для запекания во время игры берите формы коллизий (`parsed_geometry_type`), а не визуальные меши: чтение меша с GPU останавливает RenderingServer ([Using navigation meshes](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationmeshes.html)).
- `NavigationMeshSourceGeometryData2D/3D` — сериализуемый ресурс разобранной геометрии. Разберите один раз и запекайте несколько navmesh в фоне.
- `cell_size` navmesh должен совпадать с картой (2D: 1.0, 3D: 0.25, проверено на 4.7.2). Иначе появится предупреждение `navmesh_cell_size_mismatch` и сшивка рёбер сломается. Слишком мелкие ячейки при запекании могут заморозить игру.
- Регионы сшиваются по близким рёбрам (`edge_connection_margin`). Большие миры делите на чанки-регионы с общими границами, демо [navigation_mesh_chunks](https://github.com/godotengine/godot-demo-projects/tree/master/3d/navigation_mesh_chunks).
- 2D: `NavigationPolygon` из контуров (`add_outline`) запекается обрезкой полигонов. Вложенные контуры одного типа дают дыры и перевёрнутые полигоны. Встроенная навигация `TileSet` работает, но ограничена; для уровня лучше запечь `NavigationRegion2D` по коллизиям тайлов.
- Слои навигации (`navigation_layers`) отдельны от физических. Регион пропускается, если у него нет общего бита с запросом. Сменить слои у запроса дешевле, чем включать и выключать регионы ([Navigation layers](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationlayers.html)).
- `NavigationLink2D/3D` соединяет полигоны через пропасть, лестницу, телепорт. Двигать агента по ссылке игра должна сама (анимация прыжка, телепорт), иначе агент «пойдёт по воздуху». Конец ссылки ищет полигон в радиусе `default_link_connection_radius` (2D: 4, 3D: 1); если полигона рядом нет, ссылка выключается ([NavigationLinks](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationlinks.html)).
- Прямые запросы без агента: `NavigationServer2D.map_get_path(map, from, to, optimize)` или `query_path(NavigationPathQueryParameters2D, result)` с выбором алгоритма, постобработки и метаданных ([Path query objects](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationpathqueryobjects.html)).

---

## NavigationAgent и избегание

### Ключевые выводы

- Агент сам ничего не двигает. Задайте `target_position`, в каждом физическом кадре один раз берите `get_next_path_position()` и двигайте тело. Сначала проверяйте `is_navigation_finished()`: вызов `get_next_path_position()` после конца пути вызывает дрожание ([Using NavigationAgents](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html)).
- Дистанции: `path_desired_distance` (переход к следующей точке; 2D: 20 px), `target_desired_distance` (цель достигнута; 2D: 10 px) (проверено на 4.7.2), `path_max_distance` (насколько агент может отклониться, прежде чем путь перестроится; слишком малое значение заставляет его метаться). Подбирайте под скорость: если за тик агент проходит больше `path_desired_distance`, он проскакивает точки и кружит.
- Избегание (RVO): `avoidance_enabled = true`, `radius`, `max_speed`, `neighbor_distance`, `max_neighbors`, `time_horizon_agents`. Желаемую скорость присваивайте `agent.velocity`, а двигайте тело в обработчике `velocity_computed(safe_velocity)`. Без `target_position` безопасная скорость всегда нулевая. Избегание — только локальная поправка, путь оно не перестраивает.
- `avoidance_layers`/`avoidance_mask`/`avoidance_priority` — кто кого объезжает. `use_3d_avoidance` в 3D нужен только летающим, для наземных агентов достаточно 2D-избегания в плоскости.
- `NavigationObstacle`: с `vertices` — статическое препятствие, жёсткая граница; двигать его каждый кадр дорого. С `radius` — динамическое, «мягкое» отталкивание, двигать можно бесплатно. С `affect_navigation_mesh` препятствие вырезает геометрию при запекании, `carve_navigation_mesh` игнорирует отступ радиуса агента. Не смешивайте оба режима в одном препятствии ([NavigationObstacles](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationobstacles.html)).
- Путь не перезапрашивайте каждый кадр. Меняйте `target_position`, только когда цель заметно сместилась, или по таймеру; агентов распределяйте по кадрам ([Optimizing navigation](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_optimizing_performance.html)).
- `simplify_path` + `simplify_epsilon` убирают лишние точки; `path_postprocessing` = `CORRIDORFUNNEL` (по умолчанию) или `EDGECENTERED` (для клеточных navmesh).

```gdscript
# Хорошо: агент с избеганием (паттерн из документации, адаптирован под 2D)
extends CharacterBody2D
@export var speed := 160.0
@onready var agent: NavigationAgent2D = $NavigationAgent2D

func _ready() -> void:
	agent.velocity_computed.connect(_on_velocity_computed)
	agent.path_desired_distance = 8.0
	agent.target_desired_distance = 12.0

func set_target(pos: Vector2) -> void:
	if agent.target_position.distance_squared_to(pos) > 16.0 * 16.0:
		agent.target_position = pos            # не каждый кадр

func _physics_process(_delta: float) -> void:
	if agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return
	var desired := global_position.direction_to(agent.get_next_path_position()) * speed
	if agent.avoidance_enabled:
		agent.velocity = desired               # ответ придёт в velocity_computed
	else:
		_on_velocity_computed(desired)

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()
```

---

## Синхронизация карты: первый запрос пути

### Ключевые выводы

- Сразу после загрузки сцены карта пуста, и запрос пути возвращает пустой массив. Совет «подождите один физический кадр» устарел для настроек по умолчанию в 4.7. В тесте регион добавлялся при старте, а путь запрашивался `map_get_path` (проверено на 4.7.2):
  - асинхронные карта и регионы (по умолчанию): после одного `await physics_frame` путь пуст. Первый `map_changed` приходит на 2-м физическом кадре, но регион в эту итерацию ещё не попал, и путь всё равно пуст. Путь появляется только после второго `map_changed`, на 4–5-м кадре;
  - `region_use_async_iterations = false`: путь появляется с 3-го кадра;
  - обе асинхронности выключены: путь с 2-го кадра, то есть классическое «через кадр».
- Надёжный способ: повторять запрос каждый физический кадр с лимитом кадров, пока он не вернёт непустой путь, либо сравнивать `region_get_iteration_id(region_rid) > 0` и следующую итерацию карты ([PR #104826](https://github.com/godotengine/godot/pull/104826)). Для агентов — задавать цель через `call_deferred` и повторять её на `map_changed`.
- `map_force_update()` устарел, с асинхронными обновлениями он несовместим ([NavigationServer2D](https://docs.godotengine.org/en/stable/classes/class_navigationserver2d.html)). Для детерминированных тестов в CI отключите обе `*_use_async_iterations` в настройках тестового проекта.

```gdscript
# Плохо: путь запрашивается в _ready или через один кадр
func _ready():
	await get_tree().physics_frame
	path = NavigationServer2D.map_get_path(map, a, b, true)   # на 4.7.2 по умолчанию — пусто

# Хорошо: ждём, пока карта действительно содержит регион (проверено на 4.7.2:
# с регионом — true на 4-м физическом кадре, на карте без региона — false).
# Лимит в физических кадрах, а не в map_changed: если карта уже синхронизирована,
# а путь пуст (нет региона, не совпали navigation_layers), сигнал больше не придёт.
func wait_nav_ready(map: RID, probe_from: Vector2, probe_to: Vector2, max_frames := 30) -> bool:
	for i in max_frames:
		if not NavigationServer2D.map_get_path(map, probe_from, probe_to, false).is_empty():
			return true
		await get_tree().physics_frame
	return false
```

Вариант «в цикле `await NavigationServer2D.map_changed` с лимитом попыток» виснет навсегда, если путь пуст из-за конфигурации: после синхронизации `map_changed` больше не приходит, и лимит попыток не срабатывает (проверено на 4.7.2).

---

## Navmesh или AStar

### Ключевые выводы

- В клеточных, пошаговых, карточных и настольных играх (тактика, рогалики, гексы, поле карточной игры) navmesh почти всегда избыточна. `AStarGrid2D` (сетка) или `AStar2D/3D` (произвольный граф) детерминированы, синхронны (никакого ожидания `map_changed`), легко тестируются юнит-тестами и работают в клетках, а не в пикселях. Обзор жанра — в [domains.md → 4. Пошаговые, карточные, настольные](domains.md#4-пошаговые-карточные-настольные-и-стратегические-игры).
- `AStarGrid2D`: задайте `region` (`size` [устарело] → `region`), `cell_size`, `diagonal_mode`, затем `update()`. Повторный `update()` нужен после смены `region`/`cell_size`/`offset`/`cell_shape` (`is_dirty() == true`), и тогда он стирает solid-клетки и веса; без изменений `update()` ничего не делает (проверено на 4.7.2). `set_point_solid` и `set_point_weight_scale` вызывать `update()` не требуют ([AStarGrid2D](https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html)).
- По умолчанию `diagonal_mode = DIAGONAL_MODE_ALWAYS`: диагонали разрешены даже между двумя стенами. Для тактики почти всегда нужны `NEVER` или `ONLY_IF_NO_OBSTACLES`. Эвристика по умолчанию — евклидова; для 4-связной сетки ставьте `HEURISTIC_MANHATTAN`, для 8-связной — `OCTILE` или `CHEBYSHEV` (умолчания проверены на 4.7.2).
- `get_id_path()` возвращает клетки (`Vector2i`), `get_point_path()` — мировые координаты: угол клетки `id * cell_size + offset`, не центр (проверено на 4.7.2: `(1,0)` → `(16,0)` при `cell_size` 16). Для центра задайте `offset = cell_size / 2`.
- Недостижимая цель даёт `[]`; с `allow_partial_path = true` путь идёт до ближайшей достижимой клетки (в тесте `[(0,0),(1,0)]`). Если начальная клетка solid, путь всегда пуст. В тесте обход стены на сетке 5×5 без диагоналей дал путь из 13 клеток (проверено на 4.7.2).
- `jumping_enabled` (JPS) ускоряет поиск на больших однородных сетках, но отключает веса. `get_point_path()` не потокобезопасен, при вызове из потоков нужен `Mutex`.
- Своя цена хода (местность, зоны контроля) — подкласс с `_compute_cost`/`_estimate_cost` или веса клеток. Гексы — `cell_shape` изометрии не подойдёт; берите `AStar2D` с точками-гексами и своими соседями ([Red Blob Games: Hexagonal grids](https://www.redblobgames.com/grids/hexagons/)).
- Радиус хода юнита («куда можно дойти за N очков») A* не считает. Нужен BFS или Дейкстра по той же сетке, а A* — только для выбранной клетки ([Red Blob Games: Introduction to A*](https://www.redblobgames.com/pathfinding/a-star/introduction.html)).

| Критерий | `AStarGrid2D` | `AStar2D/3D` | Navmesh + `NavigationAgent` |
|---|---|---|---|
| Мир | Прямоугольная или изометрическая сетка | Граф: гексы, узлы карты, комнаты, станции | Непрерывное 2D/3D-пространство |
| Движение | По клеткам, пошагово | По рёбрам графа | Свободное, с поворотами и склонами |
| Синхронность | Сразу, в том же вызове | Сразу | Задержка синхронизации карты |
| Избегание толпы | Своё (занятые клетки = solid) | Своё | RVO из коробки |
| Динамика | `set_point_solid` — дёшево | `set_point_disabled` | Перезапекание или препятствия |
| Детерминизм для реплеев и сети | Да | Да | Нет гарантий [не проверено] |
| Примеры жанров | Тактика, рогалик, поле ККИ, головоломка | Стратегическая карта, метро, гексы | Экшен, RTS, шутер, open world |

```gdscript
# Хорошо: тактическая сетка (проверено на 4.7.2)
var grid := AStarGrid2D.new()

func build(size: Vector2i, walls: Array[Vector2i]) -> void:
	grid.region = Rect2i(Vector2i.ZERO, size)
	grid.cell_size = Vector2(64, 64)
	grid.offset = grid.cell_size / 2              # get_point_path → центры клеток
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.update()                                 # ДО set_point_solid: после смены геометрии update() их стирает
	for w in walls:
		grid.set_point_solid(w)

func path_cells(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var was_solid := grid.is_point_solid(from)    # клетка самого юнита занята им же,
	grid.set_point_solid(from, false)             # а из solid-старта путь всегда пуст
	var path := grid.get_id_path(from, to)        # [] если недостижимо
	grid.set_point_solid(from, was_solid)
	return path

func on_unit_moved(old_cell: Vector2i, new_cell: Vector2i) -> void:
	grid.set_point_solid(old_cell, false)         # занятые клетки — дешёвое «избегание»
	grid.set_point_solid(new_cell, true)

# Плохо: navmesh + NavigationAgent2D для доски 8×8 — асинхронная синхронизация,
# пиксельные допуски path_desired_distance и недетерминированное избегание там, где нужен список клеток
```

---

## Антипаттерны

### Ключевые выводы

- Почти все ошибки физики сводятся к трём вещам: движение вне `_physics_process`, прямая запись трансформа там, где должен работать движок, и путаница слоёв с масками.

| Антипаттерн | Почему плохо | Замена |
|---|---|---|
| `KinematicBody`, `move_and_slide(vel, UP)` с аргументами [устарело] | API Godot 3, в 4.x не компилируется | `CharacterBody` + свойства `velocity`, `up_direction` |
| `move_and_slide()` в `_process` | Переменный шаг, дрожание, другая скорость | `_physics_process` (+ интерполяция для плавности) |
| `velocity * delta` перед `move_and_slide()` | Шаг учтён внутри, скорость в 60 раз меньше | Умножать на `delta` только ускорения |
| `global_position =` / `look_at()` у `RigidBody` каждый кадр | Ломает симуляцию | Силы, импульсы, `_integrate_forces` |
| `StaticBody`, двигаемый скриптом, как платформа | Не передаёт скорость, Area его не видит | `AnimatableBody` |
| Масштаб у `CollisionShape` или тела | Не поддерживается, коллизии врут | Менять `radius`/`size` ресурса, визуал масштабировать отдельно |
| `collision_mask = 3`, когда имелся в виду «слой 3» | Номер слоя ≠ бит | `set_collision_mask_value(3, true)`, константы |
| Ожидание, что маска пола «поймает» падающее тело | Реагирует только тот, у кого объект в маске | Маска на подвижном теле |
| `monitoring = false` или `free()` формы внутри `body_entered` | Ошибка «blocked during in/out signal» | `set_deferred`, `call_deferred` |
| `intersect_ray` из `_input`/`_process` | Пространство может быть заблокировано | Запомнить ввод, луч в `_physics_process` |
| `RayCast`-узел на каждую пулю | Тысячи узлов | Один запрос к space state на пулю за тик |
| Телепорт без `reset_physics_interpolation()` | «Шлейф» через полкарты | Сброс после установки трансформа |
| Подъём тиков без подъёма `max_physics_steps_per_frame` | Замедление игры при падении FPS | Поднимать оба, тики кратно 60 |
| `DEFAULT` в `physics_engine` в расчёте на Jolt | В 4.7.2 это GodotPhysics3D | Явное значение `"Jolt Physics"` |
| Путь в `_ready` или через один кадр | На 4.7 карта ещё пуста | Повтор запроса по физическим кадрам с лимитом, пока путь не станет непустым |
| `target_position =` каждый кадр | Перестроение пути каждый тик | Только при заметном смещении цели |
| `NavigationLink` без своей логики прохода | Агент идёт «по воздуху» | Перехват в конце ссылки: прыжок, телепорт |
| Navmesh для клеточной доски | Асинхронность, пиксельные допуски | `AStarGrid2D` |
| Смена `region`/`cell_size` + `update()` после `set_point_solid` | Стены и веса стираются | Геометрия и `update()` сначала, solid потом |

---

## Чеклист физики и навигации

### Ключевые выводы

1. Тело выбрано по таблице: подвижное по геймплею — `CharacterBody`, по физике — `RigidBody`, платформа — `AnimatableBody`.
2. Нет Godot 3 API: `KinematicBody`, `move_and_slide` с аргументами, `RigidBody.mode`.
3. Всё движение тел — в `_physics_process`, без записи `position` мимо коллизий.
4. `velocity` не умножается на `delta` перед `move_and_slide()`, гравитация умножается; гравитация берётся из `get_gravity()`.
5. `motion_mode` соответствует жанру (GROUNDED или FLOATING); `floor_snap_length`, `floor_max_angle`, `floor_stop_on_slope` настроены под склоны и ступени уровня.
6. Персонаж толкает `RigidBody` вручную через `get_slide_collision()`.
7. `RigidBody`: силы — каждый кадр, импульсы — разово, телепорт — через `_integrate_forces` и пробуждение.
8. Быстрые тела: CCD, толстые стены или больше тиков; сигналы контактов: `contact_monitor = true` и `max_contacts_reported > 0`.
9. Слои названы в Project Settings, в коде — константы и `set_collision_*_value`, без магических битов.
10. Маски стоят на тех, кто должен реагировать или видеть (односторонняя семантика).
11. У зон выключены ненужные `monitoring`, `monitorable`, `input_pickable`; изменения из колбэков коллизий — через `set_deferred`/`call_deferred`.
12. Подвижные тела — на примитивах или convex; trimesh — только на статике.
13. Нет масштабированных форм и тел; общие ресурсы форм и материалов копируются перед изменением; цилиндры для персонажей — только на Jolt.
14. `physics_ticks_per_second` кратен 60, `max_physics_steps_per_frame` поднят вместе с ним.
15. Интерполяция включена, если FPS выше тиков; телепорты сбрасываются `reset_physics_interpolation()`; камера сглаживается в `_process`.
16. Запросы к `direct_space_state` идут только из `_physics_process`, параметры запросов переиспользуются.
17. У лучей исключено своё тело, задана маска, `collide_with_areas` включён осознанно.
18. 3D-движок указан явно (`"Jolt Physics"` или `"GodotPhysics3D"`); на Jolt проверены суставы (нет мягких параметров, одиночный сустав — `node_b`) и контакты кинематики.
19. Отладочный прогон с `--debug-collisions` / Visible Collision Shapes; мониторы `ACTIVE_OBJECTS` и `COLLISION_PAIRS` в норме.
20. Навигация: `cell_size` navmesh совпадает с картой, `agent_radius` — с реальным радиусом коллизии.
21. Runtime-запекание идёт из форм коллизий и асинхронно, парсинг — в главном потоке.
22. Первый запрос пути повторяется по физическим кадрам с лимитом, пока не вернёт непустой путь, а не ждёт один кадр или `map_changed` без лимита.
23. Агент: сначала `is_navigation_finished()`, `get_next_path_position()` раз за кадр, дистанции подобраны под скорость.
24. Избегание: движение в `velocity_computed`; препятствия выбраны осознанно (статические или динамические); `NavigationLink` обрабатывается игровой логикой.
25. Путь перезапрашивается по смещению цели или таймеру, не каждый кадр.
26. Клеточная или пошаговая игра использует `AStarGrid2D`/`AStar2D` с явными `diagonal_mode` и эвристикой; solid-клетки ставятся после последнего `update()` со сменой геометрии сетки.
27. Логика поиска пути и правил покрыта юнит-тестами без сцены (см. [architecture.md → Стратегия тестирования](architecture.md#стратегия-тестирования)).

---

## Ресурсы

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Physics introduction](https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html) | документация Godot | Типы тел, слои и маски, контакты |
| [Using CharacterBody2D/3D](https://docs.godotengine.org/en/stable/tutorials/physics/using_character_body_2d.html) | документация Godot | `move_and_slide` против `move_and_collide`, отскоки |
| [CharacterBody2D](https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html) / [CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html) | справочник API | Все свойства пола, платформ и скольжения |
| [Using RigidBody](https://docs.godotengine.org/en/stable/tutorials/physics/rigid_body.html) / [RigidBody3D](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html) / [RigidBody2D](https://docs.godotengine.org/en/stable/classes/class_rigidbody2d.html) | документация Godot | Силы, `_integrate_forces`, freeze, CCD |
| [Using Area2D](https://docs.godotengine.org/en/stable/tutorials/physics/using_area_2d.html) / [Area2D](https://docs.godotengine.org/en/stable/classes/class_area2d.html) / [Area3D](https://docs.godotengine.org/en/stable/classes/class_area3d.html) | документация Godot | Сигналы, priority, переопределение гравитации |
| [CollisionObject2D](https://docs.godotengine.org/en/stable/classes/class_collisionobject2d.html) | справочник API | `set_collision_layer_value`, shape owners, picking |
| [Collision shapes 2D](https://docs.godotengine.org/en/stable/tutorials/physics/collision_shapes_2d.html) / [3D](https://docs.godotengine.org/en/stable/tutorials/physics/collision_shapes_3d.html) | документация Godot | Выбор и цена форм, convex-декомпозиция |
| [Troubleshooting physics issues](https://docs.godotengine.org/en/stable/tutorials/physics/troubleshooting_physics_issues.html) | документация Godot | Туннелирование, масштаб, стопки, спираль смерти |
| [Ray-casting](https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html) | документация Godot | Space state, исключения, клик мышью |
| [RayCast2D](https://docs.godotengine.org/en/stable/classes/class_raycast2d.html) / [ShapeCast3D](https://docs.godotengine.org/en/stable/classes/class_shapecast3d.html) | справочник API | Узлы-датчики, `force_*_update` |
| [PhysicsDirectSpaceState2D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate2d.html) / [3D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html) / [PhysicsRayQueryParameters3D](https://docs.godotengine.org/en/stable/classes/class_physicsrayqueryparameters3d.html) | справочник API | Все виды запросов |
| [Physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/index.html): [введение](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html), [quick start](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_quick_start_guide.html), [использование](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/using_physics_interpolation.html), [продвинутое](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html), [2D и 3D](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/2d_and_3d_physics_interpolation.html) | документация Godot | Тики против кадров, телепорты, камеры |
| [Using Jolt Physics](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html) | документация Godot | Отличия, настройки, переименования |
| [Jolt Physics](https://github.com/jrouwe/JoltPhysics) / [документация Jolt](https://jrouwe.github.io/JoltPhysics/) | Jorrit Rouwe, 2026 | Устройство самого движка: сон, CCD, ограничения |
| [PR #105737: Jolt в новых проектах](https://github.com/godotengine/godot/pull/105737) / [PR #105762: DEFAULT → Jolt](https://github.com/godotengine/godot/pull/105762) / [PR #111115](https://github.com/godotengine/godot/pull/111115) / [proposal #12289](https://github.com/godotengine/godot-proposals/issues/12289) | Godot, 2025–2026 | Почему `DEFAULT` всё ещё Godot Physics |
| [Soft body](https://docs.godotengine.org/en/stable/tutorials/physics/soft_body.html) / [Ragdoll system](https://docs.godotengine.org/en/stable/tutorials/physics/ragdoll_system.html) | документация Godot | Мягкие тела и рэгдоллы |
| [Navigation](https://docs.godotengine.org/en/stable/tutorials/navigation/index.html): [2D](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_introduction_2d.html), [3D](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_introduction_3d.html) | документация Godot | Быстрый старт |
| [NavigationServers](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationservers.html) / [Maps](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationmaps.html) / [Regions](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationregions.html) | документация Godot | Карты, регионы, синхронизация |
| [Navigation meshes](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationmeshes.html) / [Connecting navmeshes](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_connecting_navmesh.html) | документация Godot | Запекание, исходная геометрия, сшивка |
| [Paths](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationpaths.html) / [Path query objects](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationpathqueryobjects.html) | документация Godot | Запросы без агента, постобработка |
| [Agents](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html) / [Obstacles](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationobstacles.html) / [Links](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationlinks.html) / [Layers](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationlayers.html) | документация Godot | Агенты, RVO, препятствия, ссылки, слои |
| [Different actor types](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_different_actor_types.html) / [Optimizing navigation](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_optimizing_performance.html) / [Debug tools](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_debug_tools.html) | документация Godot | Размеры агентов, производительность, отладка |
| [NavigationServer2D](https://docs.godotengine.org/en/stable/classes/class_navigationserver2d.html) / [NavigationServer3D](https://docs.godotengine.org/en/stable/classes/class_navigationserver3d.html) | справочник API | `map_changed`, `region_get_iteration_id`, async-запекание |
| [NavigationAgent2D](https://docs.godotengine.org/en/stable/classes/class_navigationagent2d.html) / [NavigationAgent3D](https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html) / [NavigationRegion3D](https://docs.godotengine.org/en/stable/classes/class_navigationregion3d.html) / [NavigationObstacle2D](https://docs.godotengine.org/en/stable/classes/class_navigationobstacle2d.html) / [NavigationLink2D](https://docs.godotengine.org/en/stable/classes/class_navigationlink2d.html) | справочник API | Свойства узлов навигации |
| [PR #100497: async map sync](https://github.com/godotengine/godot/pull/100497) / [PR #104826: region iteration id](https://github.com/godotengine/godot/pull/104826) / [PR #106670](https://github.com/godotengine/godot/pull/106670) | smix8, 2024–2025 | Почему первый путь приходит с задержкой в несколько кадров |
| [AStarGrid2D](https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html) / [AStar2D](https://docs.godotengine.org/en/stable/classes/class_astar2d.html) / [AStar3D](https://docs.godotengine.org/en/stable/classes/class_astar3d.html) | справочник API | Сетки и графы |
| [Demo: navigation_astar](https://github.com/godotengine/godot-demo-projects/tree/master/2d/navigation_astar) / [navigation_mesh_chunks](https://github.com/godotengine/godot-demo-projects/tree/master/3d/navigation_mesh_chunks) / [physics_tests](https://github.com/godotengine/godot-demo-projects/tree/master/3d/physics_tests) | Godot, 2026 | Рабочие примеры AStar, чанков navmesh и стресс-тестов физики |
| [GDQuest: tactical RPG pathfinding](https://gdquest.com/tutorial/godot/2d/tactical-rpg-movement/lessons/04.pathfinding-and-path-drawing/) | GDQuest, 2021 | Ход юнита и превью пути; частично типы Godot 3 `[устарело]` → `AStarGrid2D` |
| [KidsCanCode: Godot 4 recipes, physics](https://kidscancode.org/godot_recipes/4.x/physics/) / [CharacterBody3D examples](https://kidscancode.org/godot_recipes/4.x/3d/characterbody3d_examples/) | Chris Bradfield, 2023–2025 | Короткие рецепты персонажей и тел |
| [Red Blob Games: A*](https://www.redblobgames.com/pathfinding/a-star/introduction.html) / [Hexagonal grids](https://www.redblobgames.com/grids/hexagons/) | Amit Patel, 2014–2025 | Теория A*, Дейкстра, BFS, гекс-координаты |
| [Godot 4.5](https://godotengine.org/releases/4.5/) / [4.6](https://godotengine.org/releases/4.6/) / [4.7](https://godotengine.org/releases/4.7/) | Godot Foundation, 2025–2026 | 2D-сервер навигации, слияние тайлов, Jolt по умолчанию, направление one-way |
| [Command line tutorial](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html) / [Debugger panel](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/debugger_panel.html) / [Performance](https://docs.godotengine.org/en/stable/classes/class_performance.html) | документация Godot | Флаги отладки, мониторы |

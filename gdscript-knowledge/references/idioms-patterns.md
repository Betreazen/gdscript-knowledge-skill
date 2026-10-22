# Идиомы и паттерны GDScript

Справочник по идиоматичному GDScript для любых проектов на Godot 4 (2D, 3D, UI, инструменты редактора, мультиплеер, приложения без игры): возможности языка по версиям, стиль, каталог паттернов и антипаттернов с короткими примерами, чеклист для code review. Актуально на октябрь 2026 года: текущая стабильная версия — **Godot 4.7.x** (4.7 вышла в июне 2026, затем 4.7.1 и 4.7.2), ветка 4.8 пока в dev-снапшотах. Общая идея: типизировать всё, держать сцены самодостаточными, связи между узлами делать явными (вызов вниз, сигнал вверх), а данные хранить в Resource и RefCounted, а не в узлах.

- [Канонические источники](#канонические-источники)
- [Что нового в GDScript по версиям 4.x](#что-нового-в-gdscript-по-версиям-4x)
- [Статическая типизация](#статическая-типизация)
- [Стиль и порядок кода](#стиль-и-порядок-кода)
- [Свойства, аннотации и @tool](#свойства-аннотации-и-tool)
- [Сигналы, Callable, лямбды и await](#сигналы-callable-лямбды-и-await)
- [Классы: class_name, abstract, static, внутренние классы](#классы-class_name-abstract-static-внутренние-классы)
- [Связи между узлами и внедрение зависимостей](#связи-между-узлами-и-внедрение-зависимостей)
- [Память, null и обработка ошибок](#память-null-и-обработка-ошибок)
- [Мини-каталог паттернов](#мини-каталог-паттернов)
- [Антипаттерны](#антипаттерны)
- [Устаревший синтаксис Godot 3](#устаревший-синтаксис-godot-3)
- [Чеклист code review: идиоматичный GDScript](#чеклист-code-review-идиоматичный-gdscript)
- [Влиятельные статьи и материалы](#влиятельные-статьи-и-материалы)

## Канонические источники

**Ключевые выводы**
- Первоисточник — официальная документация (ветка `stable` сейчас соответствует 4.7): справочник языка, руководство по стилю, гайд по статической типизации, система предупреждений и раздел Best practices.
- В разделе Best practices лежат готовые ответы на архитектурные вопросы: как организовать сцены, когда нужен autoload, чем заменить Node, как «интерфейсы» делаются без ключевого слова.
- Из сообщества стоит читать GDQuest (паттерны, глоссарий, руководство по стилю), KidsCanCode (правило «call down, signal up») и «Game Programming Patterns» Нистрома как общую теорию.
- Материалы до 2023 года часто написаны на синтаксисе Godot 3: идеи верны, код нужно переводить (см. [Устаревший синтаксис](#устаревший-синтаксис-godot-3)).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [GDScript reference](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html) | Godot docs, 4.7 | Полный синтаксис: аннотации, свойства, match, лямбды, await, `@abstract`, вариадические функции |
| [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) | Godot docs | Порядок членов класса, именование, форматирование |
| [Static typing in GDScript](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html) | Godot docs | `:=`, типизированные коллекции, `as`/`is`, предупреждения UNSAFE_* |
| [GDScript warning system](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/warning_system.html) | Godot docs | Настройка предупреждений, превращение их в ошибки, `@warning_ignore` |
| [Best practices: Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html) | Godot docs | Слабая связность сцен, пять способов внедрения зависимостей |
| [Autoloads versus regular nodes](https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html) | Godot docs | Три проблемы глобального состояния и альтернативы autoload |
| [GDQuest GDScript guidelines](https://gdquest.gitbook.io/gdquests-guidelines/godot-gdscript-guidelines) | GDQuest | Командный стиль поверх официального |
| [Game Programming Patterns](https://gameprogrammingpatterns.com/contents.html) | Robert Nystrom, 2014 | Command, Observer, State, Component, Service Locator, Object Pool — теория, которую потом переносить на Godot |

## Что нового в GDScript по версиям 4.x

**Ключевые выводы**
- Минимальная версия для нового кода в 2026 году — 4.4+: только с ней есть типизированные словари и `@export_tool_button`. С 4.5 — `@abstract` и вариадические функции.
- В 4.6 и 4.7 синтаксис почти не менялся: улучшения касаются редактора, отладчика и LSP.
- Трейтов, интерфейсов, структур и generics в языке нет. PR с трейтами ([#107227](https://github.com/godotengine/godot/pull/107227)) закрыт без слияния в июле 2026, [proposal #6416](https://github.com/godotengine/godot-proposals/issues/6416) открыт.
- В анонсе 4.5 dev 5 абстрактные классы объявлялись ключевым словом `abstract` — [устарело]: в релиз попала аннотация `@abstract` ([PR #107717](https://github.com/godotengine/godot/pull/107717)).

| Версия | Дата | Что добавлено в GDScript | Источник |
|---|---|---|---|
| 4.0 | март 2023 | GDScript 2.0: аннотации (`@export`, `@onready`, `@tool`), сигналы и функции как значения первого класса, лямбды, `await`, `super`, новый синтаксис свойств, типизированные массивы `Array[T]`, `map`/`filter`/`reduce`, документация из `##` | [Godot 4.0 sets sail](https://godotengine.org/article/godot-4-0-sets-sail/) |
| 4.1 | июль 2023 | `static var`; enum в документации как типы; inline-докстринги | [Godot 4.1 is here](https://godotengine.org/article/godot-4-1-is-here/) |
| 4.2 | ноябрь 2023 | `#region`/`#endregion`; типизированная переменная цикла `for x: int in`; предупреждение о нетипизированном коде; raw-строки `r"..."`; guard-условия `when` в `match`; ковариантность возвращаемого типа; теги `@deprecated`/`@experimental` | [Godot 4.2 arrives in style](https://godotengine.org/article/godot-4-2-arrives-in-style/) |
| 4.3 | август 2024 | Оператор `is not`; встроенные функции как `Callable`; `@export_storage`, `@export_custom`; бинарная токенизация скриптов при экспорте; устойчивость к циклическим зависимостям | [Godot 4.3](https://godotengine.org/releases/4.3/) |
| 4.4 | март 2025 | Типизированные словари `Dictionary[K, V]` ([PR #78656](https://github.com/godotengine/godot/pull/78656)); `@export_tool_button` ([PR #96290](https://github.com/godotengine/godot/pull/96290)); файлы `.uid`; всплывающая документация в редакторе; вычисление выражений на брейкпоинте; `@warning_ignore_start`/`@warning_ignore_restore` ([PR #76020](https://github.com/godotengine/godot/pull/76020), веха 4.4) | [Godot 4.4](https://godotengine.org/releases/4.4/) |
| 4.5 | сентябрь 2025 | `@abstract` для классов и методов ([PR #67777](https://github.com/godotengine/godot/pull/67777)); вариадические функции `...args: Array` ([PR #82808](https://github.com/godotengine/godot/pull/82808)); бэктрейсы скриптов даже в release-сборках; пользовательские логгеры | [Godot 4.5](https://godotengine.org/releases/4.5/) |
| 4.6 | январь 2026 | Кнопка Step Out в отладчике; подсветка плейсхолдеров `%s`/`{name}`; сигналы с `_` скрыты из автодополнения и документации; LSP лучше переводит BBCode в Markdown | [Godot 4.6](https://godotengine.org/releases/4.6/) |
| 4.7 | июнь 2026 | Метаданные (типы enum) сохраняются у всех переменных в удалённом инспекторе; лучше вычисляются константные выражения с массивами и словарями; реализация и переопределение Java-интерфейсов из GDScript на Android; `Tween.tween_await(signal)` | [Godot 4.7](https://godotengine.org/releases/4.7/) |

```gdscript
# 4.5: абстрактный класс и вариадическая функция
@abstract
class_name Weapon extends Node2D

@abstract func fire(direction: Vector2) -> void  # без тела, наследник обязан реализовать

func log_all(prefix: String, ...parts: Array) -> void:  # rest-параметр только нетипизированный Array
	print(prefix, " ", parts)
```
Ограничения вариадиков: оператора распаковки (spread) при вызове нет, поэтому переслать `args` в `super()` или другую вариадическую функцию напрямую нельзя — только `callv()`.

## Статическая типизация

**Ключевые выводы**
- Типизировать всё: переменные, параметры, возвращаемые значения, переменные цикла, коллекции. Типизированный код быстрее (компилятор генерирует оптимизированные опкоды), автодополнение точнее, ошибки ловятся до запуска.
- `:=` — когда тип очевиден из правой части той же строки; явный тип — когда справа `get_node()`, `$Path`, `load()`, словарь или `Variant`.
- Включить предупреждения `UNTYPED_DECLARATION` и семейство `UNSAFE_*` (Project Settings → Debug → GDScript) и поднять их до ошибок в CI-профиле или по всему проекту.
- `as` для объектов при несовпадении типа молча возвращает `null`. Где тип не гарантирован, сначала `is`, потом использование.
- Вложенные типизированные коллекции (`Array[Array[int]]`) не поддерживаются: внутренний уровень оборачивать в класс или Resource.

Источник: [Static typing in GDScript](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html).
```gdscript
# Плохо: всё Variant, ошибки только в рантайме
var speed = 200
var enemies = []
func damage(target, amount):
	target.hp -= amount

# Хорошо
var speed := 200.0
var enemies: Array[Enemy] = []
var cooldowns: Dictionary[StringName, float] = {}
@onready var label: Label = $HUD/Label        # get_node возвращает Node — тип явно

func damage(target: Health, amount: int) -> void:
	target.hp -= amount

for enemy: Enemy in enemies:                   # 4.2+
	enemy.alert()
```
```gdscript
# Безопасное приведение
func _on_body_entered(body: Node2D) -> void:
	if body is not Player:                      # 4.3+
		return
	var player := body as Player                # теперь не null
	player.collect(self)
```

| Предупреждение | Что ловит | Рекомендация |
|---|---|---|
| `UNTYPED_DECLARATION` | Переменная или параметр без типа | Warn или Error в новых проектах |
| `INFERRED_DECLARATION` | Использование `:=` вместо явного типа | Обычно выключено; включать, только если команда запрещает вывод типов |
| `UNSAFE_PROPERTY_ACCESS`, `UNSAFE_METHOD_ACCESS` | Обращение к члену, которого может не быть у статического типа | Warn: признак `get_parent().foo` или нетипизированного узла |
| `UNSAFE_CAST`, `UNSAFE_CALL_ARGUMENT` | Приведение и передача Variant без проверки | Warn |
| `RETURN_VALUE_DISCARDED` | Игнорируется результат, например `Error` | Warn в коде, где важны ошибки |

В редакторе номера строк с безопасным типизированным кодом подсвечиваются зелёным, небезопасные — серым: это быстрый способ найти дыры в типизации.

## Стиль и порядок кода

**Ключевые выводы**
- Файлы и папки в `snake_case`, классы в `PascalCase`, функции и переменные в `snake_case`, константы и члены enum в `CONSTANT_CASE`, сигналы — глагол в прошедшем времени (`door_opened`, `health_changed`).
- Приватные члены начинаются с `_`. Сигналы с `_` с 4.6 скрыты из автодополнения и документации.
- Отступ — табы, строка до 100 символов, две пустые строки между функциями, `and`/`or`/`not` вместо `&&`/`||`/`!`, двойные кавычки, висячие запятые в многострочных литералах.
- Документировать через `##`: комментарий идёт прямо перед членом, поддерживаются BBCode-ссылки (`[method foo]`, `[Class]`) и теги `@tutorial`, `@deprecated`, `@experimental`.
- Форматирование и линт автоматизировать: `gdformat` и `gdlint` из [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) (`pip install "gdtoolkit==4.*"`).

Источники: [style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html), [documentation comments](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html).
```gdscript
@tool
class_name HealthComponent
extends Node
## Хранит здоровье сущности и сообщает об изменениях.
##
## Подключается дочерним узлом к любой сцене. См. [signal died].

signal health_changed(old_value: int, new_value: int)
signal died

enum State { ALIVE, DEAD }

const MAX_HEALTH_CAP := 9999

static var instances_alive: int = 0

@export_range(1, MAX_HEALTH_CAP) var max_health: int = 100

var state := State.ALIVE
var _health: int

@onready var _hit_timer: Timer = $HitTimer


func _ready() -> void:
	_health = max_health


func apply_damage(amount: int) -> void:
	...


func _set_health(value: int) -> void:
	...
```
Порядок по руководству: `@tool`/`@icon`/`@static_unload` → `class_name` → `extends` → `##`-описание → сигналы → enum → константы → статические переменные → `@export` → обычные переменные → `@onready` → `_static_init` и статические методы → виртуальные (`_init`, `_enter_tree`, `_ready`, `_process`…) → публичные методы → приватные методы → внутренние классы.

## Свойства, аннотации и @tool

**Ключевые выводы**
- Валидацию и реакцию на изменение писать в сеттере свойства, а не в отдельном `set_x()`. Внутри сеттера присваивание самому свойству не вызывает рекурсию.
- Сеттер срабатывает и до `_ready` (при загрузке сцены значения из инспектора применяются раньше), поэтому `@onready`-переменные внутри сеттера ещё `null`. Защищаться `if not is_node_ready(): return`.
- Узлы получать через `@export var target: Node2D` (переживает перемещение в дереве) или `%UniqueName` для узлов своей сцены. `@onready` + `$Path` — для стабильных дочерних путей.
- `@export` и `@onready` на одной переменной не совмещать: значение из инспектора будет затёрто (есть предупреждение `ONREADY_WITH_EXPORT`).
- В `@tool`-скриптах защищать игровой код `Engine.is_editor_hint()`. Изменения в редакторе не отменяются через undo, `queue_free()` может уронить редактор, наследники `@tool`-скрипта тоже должны быть `@tool`.
- `@export_tool_button` (4.4+) заменяет трюк с `@export var bake: bool` и сеттером.

Источники: [GDScript exports](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_exports.html), [Running code in the editor](https://docs.godotengine.org/en/stable/tutorials/plugins/running_code_in_the_editor.html), [Scene unique nodes](https://docs.godotengine.org/en/stable/tutorials/scripting/scene_unique_nodes.html).
```gdscript
@export var max_health: int = 100:
	set(value):
		max_health = maxi(value, 1)
		if is_node_ready():      # до _ready @onready-узлы ещё null
			_bar.max_value = max_health

@onready var _bar: ProgressBar = %HealthBar

func _ready() -> void:
	_bar.max_value = max_health  # применить значение, пришедшее до _ready
```
```gdscript
@tool
extends Node3D

@export_group("Generation")
@export_range(1, 64) var size: int = 8
@export_tool_button("Rebuild", "Reload") var rebuild_action := rebuild

func rebuild() -> void:
	if not Engine.is_editor_hint():
		return
	...
```
Полезные аннотации экспорта: `@export_range`, `@export_enum`, `@export_flags`, `@export_file("*.json")`, `@export_dir`, `@export_multiline`, `@export_node_path("Camera3D")`, `@export_group`/`@export_subgroup`/`@export_category`, `@export_storage` (сериализуется, но скрыто в инспекторе), `@export_custom` (без валидации подсказки — опечатки молча ломают инспектор).

## Сигналы, Callable, лямбды и await

**Ключевые выводы**
- С 4.0 сигналы — значения первого класса: `button.pressed.connect(_on_pressed)`, `died.emit()`. Строковые `connect("pressed", self, "_on_pressed")` и `emit_signal("died")` — [устарело]: опечатка обнаруживается только в рантайме.
- Сигналы объявлять с именованными и типизированными параметрами: это документация и подсказки редактору. Типы и число аргументов при `emit()` не проверяются: на 4.7.2 `emit("str")` в сигнал `(v: int)` проходит, ошибку даёт только типизированный обработчик, а нетипизированный получает строку (проверено на 4.7.2).
- Сигнал — для реакции на событие, а не для запуска поведения у другого узла. Команду отдавать вызовом метода вниз по дереву.
- Лямбда захватывает локальные переменные по значению в момент создания: переприсваивание снаружи она не увидит, а изменение массива или объекта — увидит (это ссылки).
- Чтобы отключить лямбду от сигнала, сохранить её в переменную и передать в `disconnect` тот же `Callable`. Для одноразовой подписки — `CONNECT_ONE_SHOT`.
- Подключения узла к сигналам других объектов снимаются автоматически при `free()` этого узла. Подключения лямбд, захвативших узел, — нет: при вызове такой лямбды движок печатает `Lambda capture at index 0 was freed. Passed "null" instead.`, и обращение к члену узла внутри неё падает с ошибкой скрипта (проверено на 4.7.2).
- `await signal` делает функцию корутиной: вызывающий код без `await` продолжит выполнение сразу. Если объект освобождён до сигнала, корутина не продолжится никогда.

Источники: [Using signals](https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html), [Callable](https://docs.godotengine.org/en/stable/classes/class_callable.html).
```gdscript
# Плохо (Godot 3)
$Button.connect("pressed", self, "_on_button_pressed")
emit_signal("health_changed", old, new)

# Хорошо
signal health_changed(old_value: int, new_value: int)

func _ready() -> void:
	%Button.pressed.connect(_on_button_pressed)
	%Slider.value_changed.connect(_on_value_changed.bind(&"volume"))  # bind добавляет аргумент в конец
	get_tree().create_timer(1.0).timeout.connect(func() -> void: print("tick"), CONNECT_ONE_SHOT)

func take_hit(amount: int) -> void:
	var old := hp
	hp -= amount
	health_changed.emit(old, hp)
```
```gdscript
# await: дождаться анимации, проверив, что узел жив
func play_death() -> void:
	$AnimationPlayer.play(&"death")
	await $AnimationPlayer.animation_finished
	queue_free()
```

## Классы: class_name, abstract, static, внутренние классы

**Ключевые выводы**
- `class_name` регистрирует глобальный тип: его можно указывать в типах, `is`, `@export` и он появляется в диалоге создания узла. Давать `class_name` переиспользуемым типам, а не каждому скрипту одноразовой сцены — глобальное пространство имён общее.
- Базовый класс с обязательными методами помечать `@abstract` (4.5+). Это ближайшая замена интерфейсам: экземпляр не создать, метод без тела обязателен к реализации, абстрактный класс скрыт из диалога создания узла.
- Для «контракта» без наследования (трейтов нет) использовать утиную типизацию: `has_method()`, группы, компонент-узел, хранящий `Callable`.
- Утилиты без состояния — `static func` в классе с `class_name`, а не autoload. Общие данные класса — `static var` (4.1+).
- Внутренние классы (`class Foo:`) годятся для приватных структур данных; как Resource для сохранения в `.tres` они не сериализуются — такой Resource выносить в отдельный файл с `class_name`.
- `super.method()` вызывает реализацию родителя. В Godot 4 переопределённый `_ready` (и другие виртуальные методы) скриптового родителя сам не вызывается, в отличие от Godot 3: нужен явный `super()` в начале метода.

Источники: [GDScript reference](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html), [Godot interfaces](https://docs.godotengine.org/en/stable/tutorials/best_practices/godot_interfaces.html).
```gdscript
# res://combat/damage_math.gd — библиотека без состояния вместо autoload
class_name DamageMath

static func apply_armor(raw: int, armor: int) -> int:
	return maxi(raw - armor, 0)
```
```gdscript
# Enum + match с guard (4.2+)
enum Move { IDLE, WALK, RUN }

func speed_for(move: Move, stamina: float) -> float:
	match move:
		Move.IDLE:
			return 0.0
		Move.RUN when stamina > 0.1:
			return 300.0
		Move.WALK, Move.RUN:
			return 120.0
		_:
			push_error("Неизвестное состояние: %s" % move)
			return 0.0
```
`StringName` (`&"jump"`) использовать для имён действий ввода, анимаций, групп, мета-ключей: сравнение быстрее, чем у `String`. `NodePath`-литерал — `^"Body/Sprite"`.

## Связи между узлами и внедрение зависимостей

**Ключевые выводы**
- Правило «call down, signal up»: родитель обращается к детям напрямую (метод или свойство), ребёнок сообщает наверх сигналом и ничего не знает о родителе. Соседи общаются через общего родителя.
- Сцена должна запускаться сама по себе (F6). Если ей нужна внешняя зависимость, зависимость передаётся снаружи: `@export`-ссылка, метод `setup(...)`, свойство-`Callable` или сигнал.
- Autoload оправдан для систем с широкой областью, которые управляют только своими данными (сохранения, настройки, музыка, шина событий). Docs называют три проблемы: глобальное состояние, глобальный доступ (трудно найти источник бага), глобальное выделение ресурсов.
- Шина событий (autoload только с сигналами) — для действительно удалённых узлов. GDQuest предупреждает: не использовать её повсеместно, иначе источник события ищется по всему коду.
- Группы (`add_to_group`, `get_tree().call_group`) — для широковещательных команд множеству однотипных узлов.
- DI не убирает зависимость, а делает её явной (GDQuest: «The dependency still exists. It's just obfuscated a bit»). Цель — прозрачный поток зависимостей, а не «нулевая связность».

Источники: [KidsCanCode: Node communication](https://kidscancode.org/godot_recipes/4.x/basics/node_communication/), [Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html), [Autoloads versus regular nodes](https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html), [GDQuest: Dependency injection](https://www.gdquest.com/library/glossary/dependency_injection/).
```gdscript
# Плохо: ребёнок лезет в родителя и в чужие ветки
func _on_hit() -> void:
	get_parent().get_parent().get_node("UI/HealthBar").value -= 10
	get_node("/root/Main/Player").hp -= 10

# Хорошо: ребёнок сигналит вверх...
signal hit(amount: int)
func _on_area_entered(_area: Area2D) -> void:
	hit.emit(10)

# ...а владелец сцены связывает и вызывает вниз
func _ready() -> void:
	$Hurtbox.hit.connect(_on_hurtbox_hit)

func _on_hurtbox_hit(amount: int) -> void:
	$Health.apply_damage(amount)
```
```gdscript
# Явная инъекция при создании сцены
const ENEMY_SCENE := preload("res://enemies/enemy.tscn")

func spawn(at: Vector2) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.setup(_player, _projectile_pool)   # зависимости до add_child
	enemy.position = at                      # свойства тоже до add_child
	add_child(enemy)
	return enemy
```

| Способ связи | Когда | Цена |
|---|---|---|
| Вызов метода ребёнка | Родитель управляет своей сценой | Родитель знает тип ребёнка — это нормально |
| Сигнал вверх | Ребёнок сообщает о событии | Нужно подключение у владельца |
| `@export var x: Node` | Ссылка на узел в той же сцене или на соседа | Нужно назначить в инспекторе |
| `setup()` / свойство до `add_child` | Сцены, создаваемые из кода | Порядок вызова надо соблюдать |
| Свойство-`Callable` | Нужна одна операция, а не весь объект | Слабее типизирован |
| Группы | Команда всем узлам вида | Строковое имя группы — держать в константе |
| Autoload / шина событий | Глобальные сервисы и редкие дальние события | Глобальное состояние, тесты сложнее |

## Память, null и обработка ошибок

**Ключевые выводы**
- Сборщика мусора нет. `RefCounted` (по умолчанию для скриптов без `extends`) и `Resource` освобождаются по счётчику ссылок; `Node` и чистый `Object` — вручную (`queue_free()` / `free()`). Узел, созданный и не добавленный в дерево, утечёт, если его не освободить.
- Циклические ссылки между `RefCounted` не освобождаются никогда. Одну сторону цикла (обычно ссылку на родителя или владельца) делать `weakref()`.
- Ссылка на узел может пережить узел. Перед использованием долгоживущей ссылки — `is_instance_valid(node)`; для узла, помеченного к удалению, дополнительно `node.is_queued_for_deletion()`.
- Исключений нет. Движковые функции возвращают `Error` (`OK == 0`) — проверять и логировать через `push_error(error_string(err))`. Свои функции: возвращать `null`/пустое значение/`Error` и документировать это, или небольшой Result-объект для сложных случаев.
- `assert()` выполняется только в отладочных сборках и редакторе: в release его нет. Внутри не должно быть побочных эффектов, и он не заменяет проверку пользовательского ввода.
- `push_error` и `push_warning` выводят ошибку со стеком в отладчик и не прерывают выполнение: после них явно `return`.

Источники: [RefCounted](https://docs.godotengine.org/en/stable/classes/class_refcounted.html), [WeakRef](https://docs.godotengine.org/en/stable/classes/class_weakref.html), [@GlobalScope](https://docs.godotengine.org/en/stable/classes/class_@globalscope.html), [@GDScript](https://docs.godotengine.org/en/stable/classes/class_@gdscript.html), [GDScript advanced](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_advanced.html).
```gdscript
func load_settings(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Не открыть %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		push_warning("Повреждён файл настроек %s" % path)
		return {}
	return parsed

func save(res: Resource, path: String) -> bool:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Сохранение %s: %s" % [path, error_string(err)])
	return err == OK
```
```gdscript
# Разрыв цикла RefCounted
class TreeNode extends RefCounted:
	var children: Array[TreeNode] = []
	var _parent_ref: WeakRef          # не TreeNode — иначе цикл и утечка

	func get_parent_node() -> TreeNode:
		return _parent_ref.get_ref() as TreeNode if _parent_ref else null
```

Выбор базового класса для данных ([Node alternatives](https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html)):

| Класс | Освобождение | Когда |
|---|---|---|
| `Object` | Вручную (`free()`) | Редко: низкоуровневые структуры с ручным управлением |
| `RefCounted` | Автоматически по счётчику | Логика и данные без дерева сцены: модели, команды, состояния, сервисы |
| `Resource` | Автоматически, кэшируется по пути | Данные, которые редактируются в инспекторе и сохраняются в `.tres`/`.res` |
| `Node` | Вручную, вместе с деревом | Нужны дерево, `_process`, ввод, сигналы дерева, трансформы |

## Мини-каталог паттернов

| Проблема | Решение в Godot | Источник |
|---|---|---|
| Поведение зависит от режима (idle/run/jump, меню/игра) | Простой случай — `enum` + `match`. Сложный — узел `StateMachine` с дочерними узлами-состояниями (`enter`/`exit`/`update`/`physics_update`, сигнал `finished`). Готовые встроенные альтернативы для анимаций — `AnimationTree` | [GDQuest FSM](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/), [Shaggy Dev](https://shaggydev.com/2023/10/08/godot-4-state-machines/), [GPP: State](https://gameprogrammingpatterns.com/state.html) |
| Разные сущности делят поведение (здоровье, хитбокс, подбор) | Композиция: сцена-компонент (`HealthComponent`, `Hitbox`) дочерним узлом; связь через сигналы и `@export` | [GDQuest Entity-Component](https://www.gdquest.com/tutorial/godot/design-patterns/entity-component-pattern/), [GDQuest: Composition](https://www.gdquest.com/library/glossary/composition/), [GPP: Component](https://gameprogrammingpatterns.com/component.html) |
| Одно событие интересно многим | Observer = сигналы. Дальние слушатели — через шину событий (autoload только с сигналами) | [Signals](https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html), [GDQuest Event bus](https://www.gdquest.com/tutorial/godot/design-patterns/event-bus-singleton/), [GPP: Observer](https://gameprogrammingpatterns.com/observer.html) |
| Undo/redo, повтор ввода, очередь действий, AI | Command: `RefCounted` с `execute()`/`undo()` в массиве; в редакторе — `EditorUndoRedoManager` | [GPP: Command](https://gameprogrammingpatterns.com/command.html) |
| Взаимозаменяемые алгоритмы (оружие, AI, формулы) | Strategy: `@abstract` Resource с методом, конкретные реализации назначаются через `@export` в инспекторе. Для одной операции хватит свойства-`Callable` | [Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html) |
| Конфигурация и баланс (характеристики, предметы, карты) | Type Object / data class: свой `Resource` с `class_name` и `@export`-полями, хранится в `.tres` | [Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html), [GPP: Type Object](https://gameprogrammingpatterns.com/type-object.html) |
| Частое создание и удаление пуль, частиц, эффектов | Object Pool узлов: скрывать и отключать (`process_mode = PROCESS_MODE_DISABLED`, `visible = false`) вместо `queue_free`. Включать только после замера: без GC выигрыш даёт в основном дорогой `instantiate()` + `add_child` | [GPP: Object Pool](https://gameprogrammingpatterns.com/object-pool.html) |
| Доступ к глобальному сервису (аудио, сохранения) | Service Locator = autoload; для тестов — autoload хранит ссылку на заменяемую реализацию | [Singletons (Autoload)](https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html), [GPP: Service Locator](https://gameprogrammingpatterns.com/service-locator.html) |
| Утилиты без состояния | `class_name` + `static func`; общие счётчики — `static var` | [Autoloads versus regular nodes](https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html) |
| Множество объектов в одной роли («все враги», «все сохраняемые») | Группы как неформальный интерфейс: `is_in_group`, `call_group`, `get_nodes_in_group` | [Groups](https://docs.godotengine.org/en/stable/tutorials/scripting/groups.html), [Godot interfaces](https://docs.godotengine.org/en/stable/tutorials/best_practices/godot_interfaces.html) |
| Дорогой пересчёт при каждом изменении | Dirty flag: сеттер ставит флаг, пересчёт в `_process` один раз или `call_deferred` | [GPP: Dirty Flag](https://gameprogrammingpatterns.com/dirty-flag.html) |
| Отложить действие до конца кадра (смена сцены, удаление) | `call_deferred()`, `Callable.call_deferred()`, `set_deferred()` | [Callable](https://docs.godotengine.org/en/stable/classes/class_callable.html) |
| Периодическая проверка «раз в N секунд» | `Timer` или `get_tree().create_timer()` вместо счётчика в `_process` | [Godot notifications](https://docs.godotengine.org/en/stable/tutorials/best_practices/godot_notifications.html) |
| Большой проект, много людей | Слои: add-ons → системы → UI (только чтение) → контент; зависимости строго в одну сторону | [GDQuest: Modular Game Architecture](https://www.gdquest.com/library/modular_game_architecture/) (2026) |

```gdscript
# Strategy через Resource
@abstract
class_name TargetingStrategy extends Resource

@abstract func pick(candidates: Array[Node2D], origin: Vector2) -> Node2D


# res://ai/nearest_target.gd
class_name NearestTarget extends TargetingStrategy

func pick(candidates: Array[Node2D], origin: Vector2) -> Node2D:
	var best: Node2D = null
	for c: Node2D in candidates:
		if best == null or origin.distance_squared_to(c.global_position) < origin.distance_squared_to(best.global_position):
			best = c
	return best


# В турели: стратегия выбирается в инспекторе
@export var targeting: TargetingStrategy
```
```gdscript
# Command с undo
class_name MoveCommand extends RefCounted

var _unit: Unit
var _from: Vector2i
var _to: Vector2i

func _init(unit: Unit, to: Vector2i) -> void:
	_unit = unit
	_from = unit.cell
	_to = to

func execute() -> void:
	_unit.cell = _to

func undo() -> void:
	_unit.cell = _from
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Finite State Machine in Godot 4](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/) | GDQuest, 2024 | Каноничная реализация автомата на узлах |
| [Starter State Machines in Godot 4](https://shaggydev.com/2023/10/08/godot-4-state-machines/) | The Shaggy Dev, 2023 | Когда хватит enum, а когда нужны узлы |
| [Entity-Component pattern](https://www.gdquest.com/tutorial/godot/design-patterns/entity-component-pattern/) | GDQuest, 2021 | Композиция вместо глубокого наследования. Код частично на Godot 3 [устарело] |
| [Event bus singleton](https://www.gdquest.com/tutorial/godot/design-patterns/event-bus-singleton/) | GDQuest, 2021 | Шина событий и предупреждение о злоупотреблении. Синтаксис Godot 3 [устарело] |
| [Game Programming Patterns](https://gameprogrammingpatterns.com/contents.html) | Robert Nystrom, 2014 | Теория паттернов для игр; бесплатно онлайн |

## Антипаттерны

**Ключевые выводы**
- Цепочки `get_parent()` и пути `../../X` или `/root/Main/...` ломаются при любой перестановке дерева и не дают запустить сцену отдельно. Лечится сигналами, `@export`-ссылками и `%UniqueName`.
- Autoload на всё («GameManager», знающий про каждого) — глобальное состояние, невидимые зависимости, трудные тесты. Лечится сценами-владельцами, `static func`, Resource.
- Строковые сигналы и вызовы (`connect("x", ...)`, `call("method")`, `has_method` без нужды) — ошибки только в рантайме, рефакторинг не находит использования.
- Нетипизированный код — медленнее, без автодополнения, ошибки всплывают в игре.
- Скрипт-«бог» на 1000+ строк (игрок с движением, инвентарём, UI и звуком) — разбивать на компоненты-узлы и RefCounted-классы.
- Опрос состояния в `_process` («каждый кадр проверить, не изменилось ли здоровье») — заменить сигналом или сеттером. Ненужный `_process` отключать (`set_process(false)`).
- Циклические ссылки RefCounted и захват `self` в лямбды долгоживущих объектов — утечки памяти.
- `Node` там, где хватает `RefCounted` или `Resource`, — лишняя стоимость дерева и ручное освобождение.
- `preload` взаимно ссылающихся сцен или скриптов (A preload B, B preload A) — ошибки загрузки и лишняя память; одну сторону — `load()` по требованию или ссылка через `class_name`/`@export`.
- Изменение общего Resource у одного экземпляра меняет его у всех: Resource, загруженный из файла, кэшируется и разделяется. Для экземплярных данных — `duplicate()` или `resource_local_to_scene`.

```gdscript
# Плохо: опрос каждый кадр
func _process(_delta: float) -> void:
	$Label.text = str(player.hp)

# Хорошо: реакция на событие
func _ready() -> void:
	player.health_changed.connect(func(_old: int, new: int) -> void: $Label.text = str(new))
```
```gdscript
# Плохо: общий Resource меняется у всех врагов сразу
@export var stats: EnemyStats
func _ready() -> void:
	stats.hp -= 10

# Хорошо: копия на экземпляр
func _ready() -> void:
	stats = stats.duplicate()
```

| Антипаттерн | Признак в коде | Замена |
|---|---|---|
| Хрупкие пути | `get_parent().get_parent()`, `"../../"`, `"/root/..."` | Сигнал вверх, `@export var x: Node`, `%Unique` |
| God-autoload | Autoload с полями других систем, `Global.player.inventory.items` | Сцена-владелец, Resource, `static func` |
| Строковые связи | `connect("sig", self, "m")`, `call("m")`, `emit_signal("sig")` | `sig.connect(m)`, `sig.emit()`, прямой вызов типизированного метода |
| Нетипизированный код | `var x = ...`, функции без `-> T` | `:=`, явные типы, `UNTYPED_DECLARATION` = error |
| Polling | Проверка флага в `_process` | Сигнал, сеттер, `Timer` |
| Node вместо данных | Узел без дерева-специфики, только поля | `RefCounted` или `Resource` |
| Циклы ссылок | Родитель и ребёнок RefCounted ссылаются друг на друга | `weakref()` на одной стороне |
| Побочные эффекты в assert | `assert(load_level())` | Вызов отдельно, assert на результат |
| Изменение дерева во время итерации или в физическом колбэке | `remove_child`/`queue_free` внутри `body_entered` с ошибкой «flushing queries» | `call_deferred`, `set_deferred` |

## Устаревший синтаксис Godot 3

Источник: [Upgrading from Godot 3 to Godot 4](https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.html). Встречая эти конструкции в туториалах и ответах ИИ, переводить на правый столбец.

| [устарело] Godot 3 | Godot 4 |
|---|---|
| `tool` | `@tool` |
| `export var x = 1`, `export(int, 0, 10) var x` | `@export var x := 1`, `@export_range(0, 10) var x: int` |
| `onready var n = $N` | `@onready var n: Node = $N` |
| `var x setget set_x, get_x` | `var x: int:` + блоки `set(value):` / `get:` |
| `yield(obj, "signal")`, `yield(get_tree().create_timer(1), "timeout")` | `await obj.signal`, `await get_tree().create_timer(1.0).timeout` |
| `connect("sig", self, "_m", [arg])` | `sig.connect(_m.bind(arg))` |
| `emit_signal("sig", a)` | `sig.emit(a)` |
| `funcref(obj, "m")` | `obj.m` (Callable) или лямбда `func(): ...` |
| `scene.instance()` | `scene.instantiate()` |
| `PoolStringArray`, `PoolVector2Array` | `PackedStringArray`, `PackedVector2Array` |
| `.method()` для вызова родителя | `super.method()` / `super()` |
| `master`/`puppet`/`remote` ключевые слова | `@rpc("authority")`, `@rpc("any_peer")` |
| `inst2dict`, `type_exists` | `inst_to_dict` и `type_exists` в 4.x тоже deprecated — не использовать |
| Ключевое слово `abstract` (4.5 dev 5) | `@abstract` |

## Чеклист code review: идиоматичный GDScript

1. Все переменные, параметры и возвращаемые значения типизированы; `:=` — только когда тип очевиден из той же строки.
2. Коллекции типизированы: `Array[T]`, `Dictionary[K, V]` (4.4+); вложенные коллекции обёрнуты в класс или Resource.
3. Включены предупреждения `UNTYPED_DECLARATION` и `UNSAFE_*`; новых предупреждений в изменённых файлах нет, `@warning_ignore` обоснован комментарием.
4. `as` используется только после `is`-проверки или там, где `null` обрабатывается.
5. Имена по стилю: файлы `snake_case`, классы `PascalCase`, сигналы в прошедшем времени, константы `CONSTANT_CASE`, приватные члены с `_`.
6. Порядок членов класса соответствует style guide; публичное выше приватного.
7. Публичные классы, методы, сигналы и `@export`-свойства документированы `##`.
8. Нет синтаксиса Godot 3 (`yield`, `onready var`, `export var`, `setget`, строковый `connect`, `instance()`).
9. Сигналы подключаются через `signal.connect(callable)` и испускаются через `signal.emit()`.
10. Сигналы объявлены с именованными типизированными параметрами.
11. Ребёнок не обращается к родителю (`get_parent()`, `../`); связь вверх — сигналом.
12. Нет абсолютных путей `/root/...` и `get_tree().root.get_node(...)` в игровом коде.
13. Ссылки на узлы — через `@export`, `%UniqueName` или `@onready` с типом; `get_node()` в горячем коде не вызывается каждый кадр.
14. На одной переменной нет `@export` вместе с `@onready`.
15. Сцена запускается отдельно (F6) или её внешние зависимости явно описаны (`setup()`, `@export`).
16. Новый autoload обоснован: широкая область, управляет только своими данными; утилиты без состояния вынесены в `static func`.
17. Шина событий не используется для связи родителя и ребёнка.
18. Данные и логика без дерева — `RefCounted` или `Resource`, а не `Node`.
19. Общие Resource не мутируются на экземпляре без `duplicate()` или `resource_local_to_scene`.
20. Циклические ссылки между RefCounted разорваны `weakref()`.
21. Долгоживущие ссылки на узлы проверяются `is_instance_valid()` перед использованием.
22. Лямбды, подключённые к сигналам долгоживущих объектов, не захватывают узлы, которые могут быть освобождены, либо отключаются.
23. Результаты функций, возвращающих `Error`, проверяются; ошибки логируются через `push_error` с `error_string()`, после чего код выходит.
24. В `assert()` нет побочных эффектов; пользовательский ввод проверяется обычным кодом, а не assert.
25. Нет опроса в `_process`, который можно заменить сигналом, сеттером или `Timer`; неиспользуемый `_process` отключён или удалён.
26. Физика и движение тел — в `_physics_process`, визуальные обновления — в `_process`.
27. Свойства новых узлов задаются до `add_child`; изменение дерева из физических колбэков — через `call_deferred`/`set_deferred`.
28. Сеттеры не обращаются к `@onready`-узлам до готовности (`is_node_ready()`).
29. `match` по enum покрывает все значения или имеет ветку `_` с `push_error`.
30. Имена действий ввода, анимаций и групп — `StringName`-литералы `&"..."` или константы, а не разбросанные строки.
31. Нет взаимных `preload` между сценами и скриптами.
32. `@tool`-код защищён `Engine.is_editor_hint()`, не вызывает `queue_free()` на редактируемых узлах без нужды; кнопки инспектора — `@export_tool_button`.
33. Абстрактные базовые классы помечены `@abstract`, методы-контракты без тела (4.5+).
34. Скрипт короче ~400 строк и отвечает за одно; крупные куски вынесены в компоненты.
35. `gdformat --check` и `gdlint` проходят (если gdtoolkit принят в проекте).

## Влиятельные статьи и материалы

| Статья | Автор, год | Зачем читать |
|---|---|---|
| [Node communication (the right way)](https://kidscancode.org/godot_recipes/4.x/basics/node_communication/) | KidsCanCode, Godot 4 | Первоисточник правила «call down, signal up» и список хрупких путей |
| [Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html) | Godot docs | Пять способов внедрить зависимость в сцену |
| [Autoloads versus regular nodes](https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html) | Godot docs | Когда autoload вреден и чем его заменить |
| [Singletons (Autoload)](https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html) | Godot docs | Autoload — не «настоящий» синглтон; отложенная смена сцены |
| [Godot interfaces](https://docs.godotengine.org/en/stable/tutorials/best_practices/godot_interfaces.html) | Godot docs | Утиная типизация, группы, получение ссылок |
| [Node alternatives](https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html) | Godot docs | Object, RefCounted, Resource вместо Node |
| [Logic preferences](https://docs.godotengine.org/en/stable/tutorials/best_practices/logic_preferences.html) | Godot docs | Свойства до `add_child`, `preload` против `load` |
| [Data preferences](https://docs.godotengine.org/en/stable/tutorials/best_practices/data_preferences.html) | Godot docs | Array, Dictionary, Object; enum как int или строка |
| [Godot notifications](https://docs.godotengine.org/en/stable/tutorials/best_practices/godot_notifications.html) | Godot docs | Порядок `_init` → `_enter_tree` → `_ready`; Timer вместо покадровых проверок |
| [Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html) | Godot docs | Свои Resource как классы данных; кэширование и разделение |
| [Idle and physics processing](https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html) | Godot docs | `_process` против `_physics_process` |
| [Groups](https://docs.godotengine.org/en/stable/tutorials/scripting/groups.html) | Godot docs | Группы как теги и неформальные интерфейсы |
| [GDScript: dynamic languages](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_advanced.html) | Godot docs | Подсчёт ссылок, передача по ссылке и по значению, утиная типизация |
| [Dependency injection](https://www.gdquest.com/library/glossary/dependency_injection/) | GDQuest | Трезвый взгляд на DI в Godot |
| [Modular Game Architecture](https://www.gdquest.com/library/modular_game_architecture/) | GDQuest, 2026 | Слои проекта и однонаправленные зависимости в студийной практике |
| [GDQuest Library](https://www.gdquest.com/library/) | GDQuest, живой | Глоссарий: composition, signal, singleton, type inference |
| [Future plans for GDScript?](https://forum.godotengine.org/t/future-plans-for-gdscript/142235) | Godot Forum, 2026 | Где смотреть планы языка: priorities list, открытые PR и proposals |
| [GDScript: Add Trait System (PR #107227)](https://github.com/godotengine/godot/pull/107227) | 2025–2026 | Почему трейтов нет и какие вопросы дизайна не решены |
| [godot-gdscript-toolkit](https://github.com/Scony/godot-gdscript-toolkit) | Scony | `gdlint`, `gdformat`, `gdradon` для CI |
| [Game Programming Patterns: Object Pool](https://gameprogrammingpatterns.com/object-pool.html) | Robert Nystrom, 2014 | Когда пул окупается и его скрытые издержки |

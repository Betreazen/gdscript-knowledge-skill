# Архитектура проектов на Godot 4 и GDScript

Как раскладывать проект на Godot 4 любого размера, будь то 2D- или 3D-игра, UI-приложение, инструмент или мультиплеер. Здесь разобраны структура папок, композиция сцен, направление зависимостей, автозагрузки и шина событий, внедрение зависимостей, Resources как данные, сохранения и их безопасность, смена сцен и экраны загрузки, машины состояний, отделение логики от представления, контроль версий, локализация, ввод и мультиплеер. Дальше идёт стратегия тестирования (GUT, gdUnit4, headless-прогон в CI), эталонные кодовые базы, антипаттерны, таблица разногласий между источниками и чеклист. Материал актуален на октябрь 2026 года (стабильная ветка Godot 4.7). Главный первоисточник — раздел официальной документации «[Best practices](https://docs.godotengine.org/en/stable/tutorials/best_practices/index.html)». Почти всё остальное в сообществе (GDQuest, KidsCanCode, Chickensoft) развивает его идеи: сцена должна работать сама по себе, вызовы идут вниз по дереву, сигналы вверх, глобального состояния как можно меньше.

- [Структура папок](#структура-папок)
- [Сцены, скрипты и композиция](#сцены-скрипты-и-композиция)
- [Направление зависимостей: вниз вызовы, вверх сигналы](#направление-зависимостей-вниз-вызовы-вверх-сигналы)
- [Автозагрузки и шина событий](#автозагрузки-и-шина-событий)
- [Внедрение зависимостей](#внедрение-зависимостей)
- [Resources как данные и конфигурация](#resources-как-данные-и-конфигурация)
- [Сохранение и загрузка](#сохранение-и-загрузка)
- [Моды и загружаемые пакеты](#моды-и-загружаемые-пакеты)
- [Смена сцен и экраны загрузки](#смена-сцен-и-экраны-загрузки)
- [Машины состояний и ИИ](#машины-состояний-и-ии)
- [Логика отдельно от представления](#логика-отдельно-от-представления)
- [ECS, компоненты и производительность](#ecs-компоненты-и-производительность)
- [Контроль версий](#контроль-версий)
- [Локализация и ввод](#локализация-и-ввод)
- [Мультиплеер](#мультиплеер)
- [Стратегия тестирования](#стратегия-тестирования)
- [Кодовые базы для изучения](#кодовые-базы-для-изучения)
- [Антипаттерны](#антипаттерны)
- [Где источники расходятся](#где-источники-расходятся)
- [Чеклист: структура нового проекта](#чеклист-структура-нового-проекта)

## Структура папок

### Ключевые выводы

- Группируйте по фичам, а не по типам файлов. Сцена, её скрипт, спрайты, звуки и данные лежат в одной папке (`player/`, `inventory/`, `ui/main_menu/`). Официальная документация: «Group assets as close to scenes as possible». GDQuest: если сцена `Character` использует два спрайта и два скрипта, всё это лежит в одной папке `character`.
- Раскладка по типам (`scenes/`, `scripts/`, `sprites/`) терпима в маленьких проектах и шаблонах (так устроены стартовые наборы Kenney). С ростом проекта она заставляет прыгать по трём деревьям ради одной фичи.
- Файлы и папки называйте в `snake_case`, узлы в `PascalCase`. Windows и macOS по умолчанию нечувствительны к регистру, Linux чувствителен. Расхождение регистра ломает экспорт и загрузку по пути на Linux и Android.
- Всё стороннее держите в `addons/`, даже если это не плагин редактора. Собственные переиспользуемые модули тоже удобно оформлять как `addons/<имя>/`: тогда их легко вынести в отдельный репозиторий.
- Папку, которую Godot не должен импортировать (исходники PSD, документация, данные для внешних скриптов), помечайте пустым файлом `.gdignore`. Из неё нельзя будет вызвать `load()` или `preload()`.
- Тесты кладите в `tests/` в корне (или рядом с фичей) и исключайте их из экспорта фильтром в пресете экспорта.

```text
res://
├── addons/                 # gut/ или gdUnit4/, limboai/, свои переиспользуемые модули
├── autoload/               # только настоящие глобальные сервисы: events.gd, settings.gd, save_service.gd
├── core/                   # чистая логика без узлов: RefCounted-классы, правила, формулы
│   ├── combat/damage_calculator.gd
│   └── inventory/inventory_model.gd
├── data/                   # .tres с данными: предметы, враги, баланс
│   └── items/sword_iron.tres
├── features/
│   ├── player/             # player.tscn, player.gd, player_states/, sprites/, sfx/
│   ├── enemies/
│   └── inventory/          # inventory_ui.tscn + inventory_ui.gd (вид поверх core/inventory)
├── levels/                 # level_01.tscn, общие тайлсеты
├── ui/                     # main_menu/, hud/, theme/default_theme.tres
├── localization/           # .csv или .po
├── main.tscn               # точка входа: Main → World + GUI
├── tests/                  # unit/ (core), integration/ (сцены)
└── project.godot
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Project organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html) | документация Godot, живой | Ассеты рядом со сценами, `snake_case`, `addons/`, `.gdignore`, регистр имён |
| [GDQuest GDScript guidelines](https://gdquest.gitbook.io/gdquests-guidelines/godot-gdscript-guidelines) | GDQuest | Порядок элементов в скрипте, именование, группировка файлов по фичам [часть текста написана во времена Godot 3] |
| [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) | документация Godot, живой | Официальный порядок кода и именование |
| [Godot-Game-Template](https://github.com/Maaack/Godot-Game-Template) | Maaack, живой | Готовый каркас: меню, настройки, загрузчик сцен, сохранения; Godot 4.4+ |

## Сцены, скрипты и композиция

### Ключевые выводы

- Понятие, специфичное для игры, делайте сценой. Документация: «If one wishes to create a concept that is particular to their game, then it should always be a scene». Скрипт с `class_name` без сцены подходит для переиспользуемых инструментов и пользовательских типов узлов.
- Сцена декларативна и инстанцируется быстрее, чем дерево, собранное из кода. Сборка дерева в `_ready()` вызов за вызовом медленнее и хуже читается.
- Каждая сцена должна запускаться отдельно (F6) без внешних зависимостей. Это одновременно критерий слабой связности и тестируемости.
- Композицию стройте из маленьких сцен-компонентов (`HealthComponent`, `Hurtbox`, `Interactable`). Владелец получает их через `@export` или `%UniqueName`, компоненты сообщают о событиях сигналами.
- Наследование сцен (Inherited Scene) используйте осторожно, для неглубокой иерархии визуальных вариантов (базовый враг → цветные варианты). В сообществе его считают почти не рефакторимым: цепочку наследования нельзя поменять из редактора, правка базовой сцены иногда сбрасывает переопределения в наследниках [не проверено: зависит от версии].
- Наследование скриптов (`extends "base_enemy.gd"` или `extends BaseEnemy`) безопаснее наследования сцен. С Godot 4.5 есть `@abstract` для базовых классов и методов, которые нельзя инстанцировать напрямую.
- Внутри сцены обращайтесь к узлам через уникальные имена `%Name`, а не через длинные пути. Уникальное имя видно только внутри своей сцены.
- Свойства задавайте до `add_child()`. Документация: «It is the best practice to change values on a node before adding it to the scene tree».

```gdscript
# features/enemies/enemy.gd: владелец собирает компоненты и слушает их сигналы
class_name Enemy
extends CharacterBody2D

@export var stats: EnemyStats            # Resource с данными
@onready var _health: HealthComponent = %HealthComponent

func _ready() -> void:
	_health.setup(stats.max_health)      # вызов вниз
	_health.died.connect(_on_died)       # сигнал вверх

func _on_died() -> void:
	queue_free()
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [When to use scenes versus scripts](https://docs.godotengine.org/en/stable/tutorials/best_practices/scenes_versus_scripts.html) | документация Godot, живой | Почему игровые понятия — сцены; `class_name` как пространство имён для сцен |
| [Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html) | документация Godot, живой | Сцены без зависимостей, корневая раскладка Main/World/GUI |
| [Scene unique nodes](https://docs.godotengine.org/en/stable/tutorials/scripting/scene_unique_nodes.html) | документация Godot, живой | `%Name`, область видимости, альтернативы |
| [Logic preferences](https://docs.godotengine.org/en/stable/tutorials/best_practices/logic_preferences.html) | документация Godot, живой | Свойства до `add_child`, `load` против `preload`, статические и динамические уровни |
| [Godot design flaw: inheritance VS composition](https://forum.godotengine.org/t/godot-design-flaw-inheritance-vs-composition/35115) | форум Godot | Практические проблемы наследования сцен [мнение сообщества] |
| [Components without nodes](https://forum.godotengine.org/t/i-figured-out-how-to-create-components-without-nodes-and-it-is-much-better/119914) | форум Godot, 2025 | Компоненты на RefCounted вместо узлов [мнение сообщества] |

## Направление зависимостей: вниз вызовы, вверх сигналы

### Ключевые выводы

- Главное правило: «call down, signal up». Родитель знает детей и вызывает их методы. Ребёнок не знает родителя и только испускает сигналы. Соседи общаются через общего предка, который соединяет их сигналы.
- Документация перечисляет пять способов, которыми родитель передаёт зависимость ребёнку: сигнал (только чтобы «отреагировать»), вызов метода, свойство-`Callable`, ссылка на узел или объект, `NodePath`. Всё это внедрение сверху, а не поиск снизу.
- `get_parent()`, `../../` и `get_tree().root.get_node(...)` в компонентах ломают запуск сцены отдельно, рефакторинг дерева и порядок `_ready()` (дети готовы раньше родителей).
- Ссылки на узлы вне своей сцены получайте через `@export var target: Node2D`, а не через путь-строку. Редактор обновит ссылку при перемещении узла.
- Группы (`add_to_group`, `get_tree().call_group`) подходят для широковещательных действий над множеством однотипных узлов («все враги — заморозиться»), а не для связи один-к-одному.
- Сигналы называйте глаголом в прошедшем времени (`died`, `item_picked`), обработчики `_on_<узел>_<сигнал>`. Типизируйте аргументы сигналов: `signal health_changed(current: int, maximum: int)`.
- Корень игры — узел `Main` с ветками `World` и `GUI`. Main выступает «композиционным корнем»: связывает системы, меняет уровни внутри `World` и не уничтожает постоянные части.

```gdscript
# main.gd: общий предок соединяет соседей, они друг о друге не знают
extends Node

@onready var _player: Player = %Player
@onready var _hud: Hud = %Hud

func _ready() -> void:
	_player.health_changed.connect(_hud.show_health)
	_hud.pause_requested.connect(_on_pause_requested)
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html) | документация Godot, живой | Пять способов внедрения, «favor keeping data in-house» |
| [Node communication](https://kidscancode.org/godot_recipes/4.x/basics/node_communication/index.html) | KidsCanCode (Chris Bradfield), Godot 4 | «Call down, signal up», почему `get_parent().get_parent()` ломает тесты и рефакторинг, `owner` |
| [Using signals](https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html) | документация Godot, живой | Объявление, подключение и типизация сигналов |

## Автозагрузки и шина событий

### Ключевые выводы

- Автозагрузка — узел, который всегда живёт в корне дерева. Автозагрузки добавляются по порядку списка в Project Settings, раньше главной сцены. Удалять их через `free()` или `queue_free()` нельзя, иначе движок падает.
- Документация называет три проблемы глобального менеджера: глобальное состояние (ошибка в нём ломает всех), глобальный доступ (непонятно, кто вызвал) и распределение ресурсов (пул слишком мал или велик). Автозагрузка уместна для систем широкого охвата, которые сами управляют своими данными: квесты, диалоги, настройки, сохранения, музыка между сценами.
- Альтернативы автозагрузке: `static func` в классе с `class_name` для утилит без состояния; `static var` (Godot 4.1+) для общих данных класса; общий `Resource`; управление внутри сцены.
- Шина событий (`Events`) — автозагрузка, которая только объявляет сигналы. GDQuest использует её почти в каждом проекте, но предупреждает: она «bundle[s] a bunch of unrelated signals into a single object», а источники событий приходится искать по всему коду. Брать её стоит, только когда нет более простого пути вроде прямого сигнала или группы.
- Правила шины: в ней нет состояния и логики; сигналы типизированы; события только для действительно далёких систем (смерть игрока → музыка, достижения, аналитика); не больше пары десятков сигналов, иначе разделите по доменам.
- Скрытые зависимости от автозагрузок ломают изолированный запуск сцен и тесты. Тонкая обёртка над автозагрузкой, которую можно подменить, лучше прямых вызовов `GameState.foo` из сотни мест.

```gdscript
# autoload/events.gd, зарегистрирован как Events
extends Node

signal player_died
signal item_collected(item: ItemData, amount: int)
signal level_completed(level_id: StringName)

# издатель: Events.item_collected.emit(item, 1)
# подписчик: Events.item_collected.connect(_on_item_collected)
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Autoloads versus regular nodes](https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html) | документация Godot, живой | Три проблемы глобального менеджера, `static func` и `static var` как альтернатива |
| [Singletons (Autoload)](https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html) | документация Godot, живой | Порядок загрузки, запрет `free()`, переключатель сцен с `call_deferred` |
| [The Events bus singleton](https://www.gdquest.com/library/pattern_event_bus_singleton) | GDQuest, 2021 | Плюсы и минусы шины, когда её не брать |

## Внедрение зависимостей

### Ключевые выводы

- В GDScript нет встроенного DI-контейнера, и чаще всего он не нужен. Основной механизм — внедрение сверху: `@export`-поля, заполненные в инспекторе, и вызов `setup(...)` или `init(...)` у ребёнка до или сразу после `add_child`.
- Порядок такой: инстанцировать, настроить (`setup(deps)`), добавить в дерево. Тогда `_ready()` уже видит зависимости, а сцена в тесте настраивается тем же методом.
- Для узлов, создаваемых из кода, удобен статический фабричный метод сцены: `static func create(data: EnemyStats) -> Enemy`, который вызывает `preload("enemy.tscn").instantiate()` и настраивает экземпляр.
- Сервис-локатор (автозагрузка `Services` с `register`/`get`) — компромисс для больших проектов: зависимость хотя бы явно видна в одном месте, и в тестах её можно подменить.
- Chickensoft (C#) решает задачу «провайдерами» вверх по дереву (AutoInject): узел ищет ближайшего предка, который предоставляет нужный тип. Для GDScript есть похожие аддоны ([Simple Dependency Injection](https://github.com/comfygrapes/simple-dependency-injection), [Arca](https://github.com/tenebris-soul/Arca)), но это небольшие проекты с парой десятков звёзд на GitHub (октябрь 2026): берите их осознанно.
- Duck typing (`has_method`) как способ избежать зависимостей хуже явного типа. С Godot 4.5 базовый класс с `@abstract`-методами даёт явный «интерфейс».

```gdscript
# features/enemies/enemy.gd
static func create(stats: EnemyStats, target: Node2D) -> Enemy:
	var enemy: Enemy = preload("res://features/enemies/enemy.tscn").instantiate()
	enemy.stats = stats      # до add_child, по совету документации
	enemy.target = target
	return enemy

# spawner.gd
func spawn(stats: EnemyStats) -> void:
	add_child(Enemy.create(stats, _player))
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html) | документация Godot, живой | Внедрение через методы, `Callable`, ссылки и `NodePath` |
| [Chickensoft GameDemo](https://github.com/chickensoft-games/GameDemo) | Chickensoft, C# | AutoInject (провайдеры в дереве), LogicBlocks, тесты с подменой узлов. Идеи переносимы в GDScript |
| [Arca DI container](https://github.com/tenebris-soul/Arca) | tenebris | DI-контейнер в духе Zenject для дерева сцен; MIT, Godot 4.6, последний push в августе 2026, пользователей мало. Страница в Asset Store в октябре 2026 отвечает 403, похоже, ассет снят |

## Resources как данные и конфигурация

### Ключевые выводы

- Собственный `Resource` с `class_name` и `@export`-полями — основной способ описывать данные: предметы, карты, врагов, волны, баланс, настройки. Он редактируется в инспекторе, сохраняется в `.tres` (текст, удобно для git) или `.res` (бинарный).
- У каждого `@export`-поля должно быть значение по умолчанию, иначе возникают проблемы с созданием ресурса в инспекторе. Ресурсы не объявляйте внутренними классами: файл хранит путь к скрипту класса.
- Загруженный ресурс кэшируется и делится между всеми экземплярами. Изменяемое состояние (текущее здоровье) не храните в общем ресурсе данных. Либо держите его в узле или модели, либо делайте `duplicate()`, либо включайте `resource_local_to_scene`. С Godot 4.5 есть `duplicate_deep()` для вложенных ресурсов и коллекций. В 4.7.2 `duplicate(true)` уже копирует вложенные массивы и встроенные подресурсы, но ресурсы из отдельных файлов оставляет общими; скопировать и их можно только `duplicate_deep(Resource.DEEP_DUPLICATE_ALL)` (проверено на 4.7.2).
- Разделяйте статические данные (определение предмета, `ItemData`) и состояние (`ItemStack` с количеством). Состояние ссылается на данные по id или по ресурсу.
- Таблицы в духе data-driven: баланс держат в CSV или Google Sheets, а скрипт-импортёр (`EditorScript` или `EditorImportPlugin`) генерирует из них `.tres`. Источник истины один, правки геймдизайнера не требуют ручной работы в инспекторе.
- Для текстовых настроек пользователя (громкость, раскладка) хорош `ConfigFile`: INI-формат, секции и ключи. Но он не безопасен для чужих файлов: парсер понимает значения вида `Object(Класс, ...)` и создаёт объекты, включая `GDScript` с исходником, который выполняется при `parse()`/`load()` (проверено на 4.7.2). Файлы, которые приходят извне, читайте как JSON.

```gdscript
# core/items/item_data.gd
class_name ItemData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""      # ключ перевода, например "ITEM_SWORD_IRON"
@export var icon: Texture2D
@export_range(1, 999) var max_stack: int = 1
@export var price: int = 0
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html) | документация Godot, живой | Свои классы ресурсов, `class_name`, значения по умолчанию, общий экземпляр |
| [Data preferences](https://docs.godotengine.org/en/stable/tutorials/best_practices/data_preferences.html) | документация Godot, живой | Array, Dictionary или Object; enum как int или строка |
| [ConfigFile](https://docs.godotengine.org/en/stable/classes/class_configfile.html) | документация Godot, живой | INI-хранилище, `save_encrypted_pass` |
| [Worlds Upon The Wind](https://github.com/max99x/wutw-public) | max99x, CC0 | Коммерческий декбилдер: все карты, реликвии и события — подклассы Resource |

## Сохранение и загрузка

### Ключевые выводы

- Сохраняйте состояние, а не узлы. Каждая сохраняемая система отдаёт `to_dict()` и принимает `from_dict()`. Официальный пример использует группу `Persist`, но для больших игр надёжнее явный реестр сохраняемых систем.
- В файл пишите версию формата (`"version": 3`) и мигрируйте старые сохранения при загрузке.
- JSON читается человеком и безопасен, но не хранит `Vector2`, `Color` и подобные типы напрямую: их кодируют вручную. Бинарный `store_var`/`get_var` компактнее и знает типы Godot.
- **Безопасность.** `get_var(allow_objects = true)` десериализует объекты (по умолчанию `false`: объект в файле тогда даёт `null` и ошибку, проверено на 4.7.2). Документация FileAccess предупреждает: «Deserialized objects can contain code which gets executed. Do not use this option if the serialized object comes from untrusted sources». Флаг оставляйте `false`.
- **Загрузка `.tres`/`.res` из `user://` небезопасна**, если файл мог прийти извне: поделённое сохранение, мод, скачанный файл. Ресурс может содержать встроенный GDScript, который выполнится при загрузке. Сохранения через `ResourceSaver` удобны, но годятся только для данных, которые пользователь не может подменить. Иначе берите JSON либо проверяйте файл [Godot Safe Resource Loader](https://github.com/derkork/godot-safe-resource-loader). Автор этого аддона сам признаёт, что чёрный список можно обойти.
- Пишите атомарно: сначала во временный файл, потом `DirAccess.rename_absolute()` поверх старого. Так сбой при записи не уничтожит сохранение.
- Пишите только в `user://`. `res://` в экспортированной игре доступен только для чтения.

```gdscript
# autoload/save_service.gd
const SAVE_PATH := "user://save.json"
const FORMAT_VERSION := 2

func save_game(state: Dictionary) -> Error:
	var tmp := SAVE_PATH + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": FORMAT_VERSION, "state": state}))
	file.close()
	return DirAccess.rename_absolute(tmp, SAVE_PATH)

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("state"):
		push_error("Save file is corrupted")
		return {}
	return _migrate(parsed)  # обновить старые версии формата
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Saving games](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html) | документация Godot, живой | Группа `Persist`, JSON против бинарной сериализации |
| [FileAccess](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html) | документация Godot, живой | Предупреждение об `allow_objects` и выполнении кода |
| [Godot Safe Resource Loader](https://github.com/derkork/godot-safe-resource-loader) | derkork | Проверка `.tres` на встроенные скрипты перед загрузкой; честные оговорки об ограничениях |

## Моды и загружаемые пакеты

### Ключевые выводы

- Механизм движка — пакеты `.pck`/`.zip`: `ProjectSettings.load_resource_pack(path, replace_files = true, offset = 0)` монтирует содержимое пакета в `res://`. После этого его сцены, ресурсы и скрипты грузятся обычным `load()` (проверено на 4.7.2). С `replace_files = true` пакет может подменить файлы самой игры: так делают патчи, но для модов это обычно лишнее.
- Мод на `.pck` — это чужой код с полными правами игры: скрипт из пакета выполняется при создании объекта (проверено на 4.7.2). Песочницы нет. Предупредите игрока и не загружайте моды автоматически из сети.
- Договоритесь о раскладке: каждый мод кладёт файлы в свою папку `res://mods/<id>/` и описывает себя манифестом (JSON с id, версией, версией API игры). Игра читает манифесты из `user://mods/`, проверяет совместимость и подключает моды в явном порядке.
- Давайте модам точки расширения, а не доступ ко всему: реестр контента (карты, предметы, уровни как `Resource`), сигналы шины событий, хуки в ключевых местах. Чем лучше данные отделены от кода (см. «Resources как данные»), тем больше модов обходятся вообще без скриптов.
- Если моды должны быть только данными, не загружайте `.tres`/`.pck` пользователя, а читайте JSON или CSV и собирайте ресурсы сами.
- Пакеты собирают экспортом («Export PCK/ZIP» с фильтром ресурсов, из консоли — `--export-pack`) или в рантайме классом `PCKPacker`. Для сложного моддинга есть готовый [Godot Mod Loader](https://github.com/GodotModding/godot-mod-loader): моды в ZIP, метаданные, проверка совместимости и порядок загрузки, изменение скриптов, сцен и ресурсов игры без раздачи её файлов, источники Steam Workshop и Thunderstore.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Exporting packs, patches, and mods](https://docs.godotengine.org/en/stable/tutorials/export/exporting_pcks.html) | документация Godot, живой | Экспорт `.pck`, `load_resource_pack`, патчи и моды |
| [PCKPacker](https://docs.godotengine.org/en/stable/classes/class_pckpacker.html) | документация Godot, живой | Сборка пакета из кода |
| [Godot Mod Loader](https://github.com/GodotModding/godot-mod-loader) ([wiki](https://wiki.godotmodding.com/)) | GodotModding, 7.0.1 (июнь 2025), CC0 | Загрузчик модов для GDScript-игр: метаданные, зависимости, конфиги и профили модов |

## Смена сцен и экраны загрузки

### Ключевые выводы

- `get_tree().change_scene_to_file()` и `change_scene_to_packed()` подходят для простых игр: текущая сцена освобождается целиком. Её данные нужно заранее сохранить в модель или автозагрузку.
- Документация описывает три стратегии: удалить сцену (освобождает память, возврат дорогой), скрыть (память и обработка остаются), `remove_child` (память остаётся, обработка останавливается, но данные, зависящие от времени, ввода или групп, «станут несвежими»).
- В архитектуре Main/World/GUI уровень меняется внутри `World`, а HUD, музыка и менеджеры живут дальше. Удаление делайте отложенным (`call_deferred` или `queue_free`), чтобы не выдернуть код, который ещё выполняется.
- Экран загрузки строится на `ResourceLoader.load_threaded_request()`, опросе `load_threaded_get_status(path, progress)` и `load_threaded_get()`. Если вызвать `load_threaded_get()` до завершения загрузки, он заблокирует поток, как обычный `load()`.
- Переход оформляйте отдельной сценой-оверлеем (затемнение, прогресс) на `CanvasLayer` поверх всего. Логику загрузки держите в одном сервисе, а не в каждом уровне.

```gdscript
# autoload/scene_loader.gd
signal progress_changed(ratio: float)
signal finished(scene: PackedScene)

var _path := ""

func load_async(path: String) -> void:
	_path = path
	ResourceLoader.load_threaded_request(path)
	set_process(true)

func _process(_delta: float) -> void:
	var progress: Array = []
	match ResourceLoader.load_threaded_get_status(_path, progress):
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			progress_changed.emit(progress[0])
		ResourceLoader.THREAD_LOAD_LOADED:
			set_process(false)
			finished.emit(ResourceLoader.load_threaded_get(_path))
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			set_process(false)
			push_error("Failed to load %s" % _path)
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Change scenes manually](https://docs.godotengine.org/en/stable/tutorials/scripting/change_scenes_manually.html) | документация Godot, живой | Три стратегии смены сцены и их цена |
| [Background loading](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html) | документация Godot, живой | API фоновой загрузки, когда `load_threaded_get` блокирует |
| [ResourceLoader](https://docs.godotengine.org/en/stable/classes/class_resourceloader.html) | документация Godot, живой | Сигнатура `load_threaded_request`, `use_sub_threads` и его влияние на главный поток |
| [Godot-Game-Template](https://github.com/Maaack/Godot-Game-Template) | Maaack | Готовый загрузчик сцен с экраном загрузки |

## Машины состояний и ИИ

### Ключевые выводы

- Начинайте с самого простого: `enum` и `match` в одном скрипте. GDQuest: «I would only introduce the State pattern once it becomes necessary for the project» и «You don't need a state machine if you have a character that can only run and jump».
- Узловая FSM (узел `StateMachine` и дочерние узлы-состояния с `enter()`, `exit()`, `physics_update()`) окупается, когда у состояний появляются свои переменные и таймеры, а персонаж развивается месяцами. Цена: код размазан по файлам, состояния дублируют друг друга.
- Состояния на `RefCounted` без узлов легче и тестируются без дерева сцен. Узловые удобнее для отладки в редакторе и настройки через инспектор.
- Иерархическая FSM (вложенные машины: «на земле» → бег или ходьба) снимает дублирование переходов. Готовое решение — LimboAI: модуль или GDExtension с иерархическими машинами `LimboHSM`, деревьями поведения, blackboard и визуальным отладчиком.
- Для ИИ с приоритетами и условиями деревья поведения масштабируются лучше FSM: LimboAI или Beehave (у Beehave каждая фича покрыта тестами на gdUnit4).
- Переходы инициирует сама машина или текущее состояние, возвращая следующее. Посторонний код не переключает состояние напрямую, а посылает событие.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Make a Finite State Machine in Godot 4](https://www.gdquest.com/library/pattern_finite_state_machine) | GDQuest, 2026 | Переменная против узлов, когда FSM не нужна, минусы паттерна |
| [LimboAI](https://github.com/limbonaut/limboai) ([документация](https://limboai.readthedocs.io/)) | Serhii Snitsaruk (limbonaut), живой | HSM + BT + blackboard, GDExtension без пересборки движка; Godot 4.6+ |
| [Beehave](https://github.com/bitbrain/beehave) | bitbrain, живой | Деревья поведения на GDScript; ветки под версии Godot; пример хорошо протестированного аддона |

## Логика отдельно от представления

### Ключевые выводы

- Правила игры (урон, инвентарь, экономика, ходы, валидация карт) пишите в классах `extends RefCounted` без доступа к дереву сцен. Они создаются через `new()`, освобождаются по счётчику ссылок и тестируются за миллисекунды без запуска сцен.
- Узел становится «видом» и «контроллером»: держит модель, передаёт ей ввод, подписывается на её сигналы и обновляет визуал. Это вариант MVP или MVVM. Chickensoft формулирует цель так: «Separating visualization from state makes it super easy to test the logic block in isolation».
- Для UI: модель (данные и сигналы `changed`) → `Control`-сцена, которая только рисует и отдаёт намерения сигналами (`buy_requested(item)`). UI не меняет модель напрямую в обход её методов.
- Для пошаговых игр, карточных игр и симуляций это особенно выгодно: ядро становится детерминированным (сид генератора случайных чисел передаётся явно), поддаётся воспроизведению, реплеям и серверной проверке.
- Модель не должна держать ссылки на узлы. Если ядру нужно время, случайность или ввод, передавайте их параметрами (`delta`, `RandomNumberGenerator`), а не читайте из `Input` или `Time`.
- Тяжёлое ядро (например, симуляцию на десятки тысяч сущностей) можно позже перенести в GDExtension (C++, Rust через gdext), не трогая вид. Граница уже проведена.

```gdscript
# core/combat/health_model.gd: чистая логика, тестируется без сцены
class_name HealthModel
extends RefCounted

signal changed(current: int, maximum: int)
signal died

var maximum: int
var current: int

func _init(max_health: int) -> void:
	maximum = max_health
	current = max_health

func take_damage(amount: int) -> void:
	if amount <= 0 or current == 0:
		return
	current = maxi(current - amount, 0)
	changed.emit(current, maximum)
	if current == 0:
		died.emit()
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Chickensoft GameDemo](https://github.com/chickensoft-games/GameDemo) | Chickensoft, C# | LogicBlocks: иерархические состояния отдельно от вида, тесты логики в изоляции |
| [Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html) | документация Godot | Сцены без внешних зависимостей как основа |
| [Godot Open RPG](https://github.com/gdquest-demos/godot-open-rpg) | GDQuest, Godot 4.6 | Разделение боя (`combat/`) и карты мира (`overworld/`) в 2D RPG |

## ECS, компоненты и производительность

### Ключевые выводы

- Godot не ECS-движок, и это осознанное решение. Juan Linietsky (2021): «Godot does composition at a higher level than in a traditional ECS». Узлы — интерфейсы к данным в серверах (`RenderingServer`, `PhysicsServer2D/3D`), а серверы уже внутри оптимизированы под данные.
- «Компоненты» в Godot — это дочерние узлы или сцены. Не пытайтесь строить ECS поверх узлов: получите накладные расходы узлов без выгоды от плотных данных.
- Когда объектов тысячи (пули, частицы, толпы), уходите ниже узлов. Один менеджер держит массивы (`PackedVector2Array`) и рисует через `RenderingServer` или `MultiMeshInstance`, физику ведёт через серверы напрямую. Тяжёлые вычисления переносите в compute-шейдеры или GDExtension.
- Это исключение, а не правило. По словам автора статьи, такая оптимизация нужна немногим играм. Сначала профилируйте.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Why isn't Godot an ECS-based game engine?](https://godotengine.org/article/why-isnt-godot-ecs-based-game-engine/) | Juan Linietsky, 2021 | Почему узлы и сцены, где живут data-oriented оптимизации, что делать при тысячах объектов |
| [Data preferences](https://docs.godotengine.org/en/stable/tutorials/best_practices/data_preferences.html) | документация Godot | Стоимость Array, Dictionary и Object |

## Контроль версий

### Ключевые выводы

- Игнорируйте `.godot/` (кэш импорта) и `*.translation` (генерируется из CSV). Шаблон GitHub `Godot.gitignore` также исключает `export_credentials.cfg` (там пароли keystore), `.import/` от Godot 3 и `.mono/`.
- `export_presets.cfg` коммитьте: без него CI не соберёт экспорт. Секреты лежат отдельно, в `export_credentials.cfg`.
- **Коммитьте `.uid`-файлы** (Godot 4.4+). Hugo Locurcio: «`*.uid` should **not** be added to `.gitignore`». Переносите скрипт или шейдер вне редактора только вместе с его `.uid`, иначе сцены будут ссылаться на потерянный UID. Лучше перемещайте файлы в доке FileSystem редактора.
- Делайте `git pull` до открытия редактора. Если кто-то закоммитил сцену без `.uid`, ваш редактор сгенерирует новые UID и тронет много `.tscn` [не проверено: наблюдение сообщества].
- `.tscn` и `.tres` — текст, но конфликты в них разрешаются плохо: можно получить сцену, которая не грузится. Снижайте риск: мелкие сцены (одна фича — одна сцена) и договорённость, кто правит общую сцену. Конфликт лучше разрешать целиком «их/наша версия» и повторять правку в редакторе.
- Окончания строк: на Windows ставьте `core.autocrlf input`. `.gitattributes`, созданный Godot, принуждает LF.
- Бинарные ассеты (PSD, WAV, большие текстуры) держите в Git LFS.

```gitignore
# .gitignore
.godot/
*.translation
export_credentials.cfg
*.tmp
# НЕ игнорировать: *.uid, *.import, export_presets.cfg
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Version control systems](https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html) | документация Godot, живой | Что игнорировать, `autocrlf`, `.gitattributes` |
| [UID changes coming to Godot 4.4](https://godotengine.org/article/uid-changes-coming-to-godot-4-4/) | Hugo Locurcio, 2025 | Зачем `.uid`, почему их коммитить, перенос файлов вне редактора |
| [Godot.gitignore](https://github.com/github/gitignore/blob/main/Godot.gitignore) | GitHub, живой | Стандартный шаблон |
| [TSCN file format](https://docs.godotengine.org/en/stable/engine_details/file_formats/tscn.html) | документация Godot | Устройство `.tscn` (`format=3`, `uid`, `ext_resource`) для ручного разрешения конфликтов |
| [UID changes: обсуждение](https://forum.godotengine.org/t/uid-changes-coming-to-godot-4-4/98302) | форум Godot, 2025 | Проблемы миграции на UID у пользователей |

## Локализация и ввод

### Ключевые выводы

- Все видимые строки пишите ключами (`"MENU_START"`) и переводите через `tr()`. У `Label` и `Button` автоперевод включён, поэтому ключ можно писать прямо в свойство `text`. Множественное число — `tr_n()`, омонимы — контекст `tr("Close", "Actions")`.
- Формат: CSV проще для маленьких проектов. Gettext (`.po`/`.pot`) лучше для переводчиков и внешних инструментов: есть контекст, множественные формы и извлечение строк из сцен.
- Язык меняется через `TranslationServer.set_locale()`. Выбор пользователя храните в настройках. UI проверяйте псевдолокализацией (длинные строки) и `--language`. Для RTL-языков Godot сам отражает раскладку.
- Ввод описывайте действиями InputMap (`"move_left"`, `"interact"`), а не клавишами. Код спрашивает `Input.is_action_pressed()` или `event.is_action_pressed()`.
- Переназначение клавиш: при старте применить сохранённые события к InputMap (`InputMap.action_erase_events` + `action_add_event`), хранить в `ConfigFile` в `user://` числовыми кодами клавиш и кнопок, а не объектами `InputEvent`: объекты в `ConfigFile` разбираются тем же небезопасным парсером (подробно и с примером — [ui-input.md](ui-input.md)). Готовый образец — демо `gui/input_mapping`.
- Обработку ввода держите в одном месте на сцену (контроллер игрока или состояние FSM). В `_unhandled_input` попадает только то, что не поглотил UI.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Internationalizing games](https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html) | документация Godot, живой | `tr`, `tr_n`, контекст, `set_locale`, псевдолокализация, RTL |
| [Input mapping demo](https://github.com/godotengine/godot-demo-projects/tree/master/gui/input_mapping) | Godot, живой | UI переназначения и сохранение раскладки на диск |
| [InputMap](https://docs.godotengine.org/en/stable/classes/class_inputmap.html) | документация Godot | API действий и событий |

## Мультиплеер

### Ключевые выводы

- Модель авторитета: по умолчанию авторитет у сервера (peer 1), он задаётся на узел через `set_multiplayer_authority()`. Игровые решения принимает сервер. Клиент шлёт намерения (ввод), а не результат («я теперь здесь»).
- `@rpc` задаёт, кто может вызывать (`"authority"` или `"any_peer"`), где выполняется (`"call_remote"` или `"call_local"`) и надёжность (`"unreliable"`, `"unreliable_ordered"`, `"reliable"`). Сигнатуры RPC должны совпадать у всех пиров. Аргументы `any_peer`-RPC на сервере проверяйте всегда.
- `MultiplayerSpawner` реплицирует появление узлов, включая подключение посреди игры. `MultiplayerSynchronizer` синхронизирует выбранные свойства. В официальном примере сервер владеет персонажем, а игроку принадлежит отдельный узел ввода. Автор статьи пишет, что это «helps maintaining proper isolation between controls and game logic».
- Архитектурно мультиплеер выигрывает от отделения логики: детерминированное ядро на `RefCounted` выполняется на сервере, клиенты только отображают состояние.
- Выделенный сервер — тот же проект, запущенный с `--headless`. Код, зависящий от рендера и звука, должен это переносить.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [High-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html) | документация Godot, живой | Авторитет, режимы `@rpc`, каналы, проверка на сервере |
| [Multiplayer in Godot 4.0: Scene Replication](https://godotengine.org/article/multiplayer-in-godot-4-0-scene-replication/) | Fabio Alessandrelli, 2023 | Spawner и Synchronizer, разделение авторитета ввода и персонажа |
| [godot-demo-projects: networking](https://github.com/godotengine/godot-demo-projects/tree/master/networking) | Godot, живой | Рабочие примеры мультиплеера |

## Стратегия тестирования

### Ключевые выводы

- Пирамида для Godot: много unit-тестов на чистую логику (`RefCounted`, `Resource`, статические функции), меньше интеграционных тестов сцен (сцена инстанцируется, получает ввод или вызовы, проверяются сигналы и состояние), минимум ручных плейтестов по чеклисту.
- Встроенного фреймворка тестов для GDScript в Godot нет. Два зрелых аддона:
  - **GUT** (bitwes): 9.x для Godot 4 (последний 9.7.1 под 4.7), 7.x для Godot 3. Двойники, стабы, шпионы, параметризованные тесты, внутренние тест-классы, JUnit XML, расширение VS Code.
  - **gdUnit4** (godot-gdunit-labs): 6.x для Godot 4.5+, GDScript и C#. Fluent-утверждения, моки и шпионы, scene runner для симуляции мыши, клавиатуры, тача и действий, fuzzing, HTML и JUnit-отчёты, официальный GitHub Action.
  - Выбор: GUT проще и ближе к xUnit, gdUnit4 сильнее для тестов сцен и C#. В одном проекте держите один фреймворк.
- Чистая логика тестируется быстрее всего и надёжнее всего. Это главный довод выносить правила из узлов (см. раздел выше).
- Тест сцены: инстанцировать, добавить в дерево с автоочисткой (`add_child_autofree` в GUT, `auto_free` или scene runner в gdUnit4), дождаться кадра (`await wait_frames(1)` или `await get_tree().process_frame`), проверить сигналы и свойства. Не тестируйте пиксели.
- Автозагрузки в тестах — источник скрытого состояния: сбрасывайте их в `before_each`, а лучше внедряйте зависимость и подменяйте двойником.
- Случайность передавайте объектом `RandomNumberGenerator` с фиксированным `seed`. Тогда тест боя или генерации детерминирован.
- В CI: сначала `godot --headless --import` (на чистом runner нет `.godot/`, без импорта не найдутся классы `class_name` и ресурсы), потом запуск тестов headless с JUnit-отчётом. Отдельной проверкой полезен `--check-only` на скриптах.
- Структура: `tests/unit/` зеркалит `core/`, `tests/integration/` — сцены. Один файл тестов на класс, имена `test_<что>_<при каком условии>`. Папку `tests/` исключайте из экспорта.

```gdscript
# tests/unit/test_health_model.gd (GUT)
extends GutTest

func test_damage_reduces_health() -> void:
	var health := HealthModel.new(100)
	health.take_damage(30)
	assert_eq(health.current, 70)

func test_emits_died_at_zero() -> void:
	var health := HealthModel.new(10)
	watch_signals(health)
	health.take_damage(15)
	assert_signal_emitted(health, "died")
	assert_eq(health.current, 0)
```

```gdscript
# tests/unit/test_health_model_gdunit.gd (gdUnit4)
extends GdUnitTestSuite

func test_damage_reduces_health() -> void:
	var health := HealthModel.new(100)
	health.take_damage(30)
	assert_int(health.current).is_equal(70)
```

```bash
# CI: импорт и прогон тестов без окна
godot --headless --import --path .
# GUT
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests -ginclude_subdirs -gexit -gjunit_xml_file=res://reports/junit.xml
# gdUnit4 (код возврата: 0 ок, 100 есть падения, 101 предупреждения)
addons/gdUnit4/runtest.sh -a res://tests -c
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [GUT](https://github.com/bitwes/Gut) ([документация](https://gut.readthedocs.io/)) | Butch Wesley (bitwes), живой | Версии под Godot 3/4, двойники, параметризация, JUnit |
| [GUT: Command Line](https://gut.readthedocs.io/en/latest/Command-Line.html) | bitwes | `gut_cmdln.gd`, `-gdir`, `-gexit`, `-gjunit_xml_file`, `.gutconfig.json` |
| [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) ([документация](https://godot-gdunit-labs.github.io/gdUnit4/latest/)) | godot-gdunit-labs (Mike Schulze), живой | Fluent-утверждения, моки, fuzzing, GDScript + C# |
| [gdUnit4: Scene Runner](https://godot-gdunit-labs.github.io/gdUnit4/latest/advanced_testing/sceneRunner/) | godot-gdunit-labs | Симуляция ввода, ожидание сигналов, вызов функций сцены |
| [gdUnit4: Mocking](https://godot-gdunit-labs.github.io/gdUnit4/latest/advanced_testing/mock/) | godot-gdunit-labs | Моки и шпионы классов и сцен |
| [gdUnit4: Command line tool](https://godot-gdunit-labs.github.io/gdUnit4/latest/advanced_testing/cmd/) | godot-gdunit-labs | `runtest -a`, отчёты, коды возврата |
| [gdUnit4-action](https://github.com/godot-gdunit-labs/gdUnit4-action) | godot-gdunit-labs | GitHub Action: версия Godot, пути тестов, кэш, публикация отчёта |
| [Command line tutorial](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html) | документация Godot, живой | `--headless`, `--import`, `-s`, `--check-only`, `--quit-after` |
| [setup-godot](https://github.com/chickensoft-games/setup-godot) | Chickensoft | Установка Godot на runner GitHub Actions с кэшем; для GDScript ставьте `use-dotnet: false` |
| [godot-ci](https://github.com/abarichello/godot-ci) | Artur Barichello | Docker-образ с шаблонами экспорта для CI-сборок и деплоя |

## Кодовые базы для изучения

### Ключевые выводы

- Читайте не весь код, а границы: что в автозагрузках, где лежат данные (`.tres`), как сцены получают зависимости, есть ли `tests/`.
- Для не-игровых приложений лучший образец — Pixelorama. Для карточных и пошаговых игр — Worlds Upon The Wind.
- Демо-проекты Godot — эталон идиоматичного API, но не архитектуры больших проектов.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [godot-demo-projects](https://github.com/godotengine/godot-demo-projects) | Godot, живой | Официальные демо по 2D, 3D, GUI, сети, загрузке, плагинам; `master` следует за 4.x |
| [Pixelorama](https://github.com/Orama-Interactive/Pixelorama) | Orama Interactive, Godot 4.7 | Большое не-игровое приложение на GDScript (пиксель-арт редактор): UI, команды, плагины, CLI-экспорт |
| [Worlds Upon The Wind](https://github.com/max99x/wutw-public) | max99x, Godot 4.7, CC0 | Выпущенный коммерческий роглайт-декбилдер: папки по фичам (`cards/`, `relics/`, `run/`, `stage/`), данные в Resource, сохранения в `utils/save_game.gd`, генерация карты в C++ GDExtension |
| [Godot Open RPG](https://github.com/gdquest-demos/godot-open-rpg) | GDQuest, Godot 4.6 | Пошаговый бой, инвентарь, переходы карт, Dialogic. Демо в разработке |
| [Godot 4 3D TPS controller](https://github.com/gdquest-demos/godot-4-3d-third-person-controller) | GDQuest | Персонаж, враги, уровни по папкам; код MIT, арт CC-BY-NC-SA |
| [Godot-Game-Template](https://github.com/Maaack/Godot-Game-Template) | Maaack, 4.4+ | Обвязка игры: меню, настройки, загрузчик сцен, сохранения |
| [Starter Kit 3D Platformer](https://github.com/KenneyNL/Starter-Kit-3D-Platformer) | Kenney, Godot 4.6 | Минимальный проект с раскладкой по типам; код MIT, ассеты CC0 |
| [Unknown Horizons (Godot port)](https://github.com/unknown-horizons/godot-port) | Unknown Horizons team | Порт экономической стратегии на Godot: большая игровая модель |
| [Source of Mana](https://github.com/sourceofmana/sourceofmana) | Source of Mana | 2D MMORPG: клиент-серверная архитектура на Godot 4 |
| [A Dark Forest](https://github.com/TinyTakinTeller/GodotProjectZero) | TinyTakinTeller, Godot 4.4; код MIT | Инкрементальная игра: UI-ориентированный проект, сохранения, данные |
| [Tanks of Freedom II](https://github.com/P1X-in/tanks-of-freedom-ii) | P1X, Godot 4.4, MIT | Пошаговая стратегия, ИИ, редактор карт |
| [Super Tux Party](https://gitlab.com/SuperTuxParty/SuperTuxParty) | SuperTuxParty, Godot 4.2 (ветка `dev`) | Party-игра: мини-игры как подключаемые модули |
| [Beehave](https://github.com/bitbrain/beehave), [LimboAI](https://github.com/limbonaut/limboai) | bitbrain; limbonaut | Как устроен и тестируется зрелый аддон |
| [awesome-godot](https://github.com/godotengine/awesome-godot) | сообщество, живой | Каталог открытых игр и аддонов с пометкой версии Godot |

## Антипаттерны

### Ключевые выводы

- **Цепочки `get_parent()` и `../../`** в переиспользуемых сценах. Сцена перестаёт запускаться отдельно, рефакторинг дерева её ломает. Используйте `@export`, сигналы и внедрение сверху.
- **«Божественная» автозагрузка** `Game`/`Global` со всем состоянием и логикой. Ошибка в ней ломает всё, вызовы идут отовсюду, тесты получают общее состояние. Делите на узкие сервисы, логику выносите в модели.
- **Шина событий для всего**, включая связь родителя с ребёнком. Источник события не найти поиском. Шина — только для далёких систем.
- **Изменяемое состояние в общем Resource**: правка `stats.health` у одного врага меняет здоровье у всех, кто загрузил тот же `.tres`. Нужно `duplicate()`, `resource_local_to_scene` или отдельное состояние.
- **Загрузка `.tres`/`.res` или `get_var(true)` из файлов, которые пользователь может подменить** (сохранения, моды, скачанные уровни). Это выполнение произвольного кода. `ConfigFile` из чужого источника тоже исполняет код (проверено на 4.7.2). Берите JSON.
- **Глубокое наследование сцен**: три и больше уровней Inherited Scene. Не рефакторится, ломается при правке базы. Используйте композицию.
- **Вся логика в `_process()`** узла вида: правила, анимации и UI в одном скрипте на 1000 строк. Не тестируется. Выносите правила в `RefCounted`.
- **FSM на узлах для персонажа с тремя состояниями.** `enum` + `match` проще, пока не стало тесно.
- **Строковые пути к ресурсам, разбросанные по коду** (`load("res://art/old/enemy2.png")`). Ломаются при переносе. Используйте `@export`, `preload` рядом с использованием или реестр-ресурс. Редактор с UID переживает переносы, строки в коде — нет.
- **Игнорирование `.uid` в git** или перенос файлов в проводнике без `.uid`. Ссылки ломаются у всей команды.
- **`await` без проверки, что узел ещё жив.** После `await` объект может быть освобождён. Проверяйте `is_instance_valid(self)` или отменяйте ожидание при выходе из дерева.
- **Тесты, зависящие от порядка и общего состояния автозагрузок**, и тесты, требующие окна. Их нельзя прогнать в headless CI.
- **ECS поверх узлов** ради «производительности» без профилирования. Тысячи объектов — через серверы или MultiMesh, остальное — обычными сценами.

## Где источники расходятся

### Ключевые выводы

- Большинство споров — это выбор между скоростью прототипирования и сопровождаемостью. Godot поощряет быстрые глобальные решения (автозагрузки, `get_node`), большие проекты платят за них позже.
- Если сомневаетесь, берите вариант по умолчанию из таблицы и меняйте его, когда появится конкретная боль.

| Вопрос | Позиция A | Позиция B | Рекомендация по умолчанию |
|---|---|---|---|
| Раскладка папок | По фичам: документация, GDQuest ([гайд](https://gdquest.gitbook.io/gdquests-guidelines/godot-gdscript-guidelines)) | По типам: стартовые наборы Kenney, многие туториалы | По фичам; общие ассеты и тему UI — в отдельные папки |
| Шина событий | GDQuest: использует почти в каждом проекте ([статья](https://www.gdquest.com/library/pattern_event_bus_singleton)) | Документация: глобальный доступ мешает искать баги ([статья](https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html)) | Одна узкая шина только для далёких событий, без состояния; иначе прямые сигналы |
| FSM | Узловые состояния наглядны в редакторе | GDQuest: начинать с `enum`, State pattern только по необходимости ([статья](https://www.gdquest.com/library/pattern_finite_state_machine)) | `enum` + `match` → узловая или RefCounted FSM → LimboAI HSM/BT по мере роста |
| Где логика | В узлах: быстро, идиоматично для Godot | В отдельных моделях: Chickensoft LogicBlocks ([GameDemo](https://github.com/chickensoft-games/GameDemo)) | Правила, которые надо тестировать или синхронизировать по сети, — в `RefCounted`; поведение «прыгни и проиграй анимацию» — в узле |
| Наследование сцен | Удобно для вариантов одного объекта | Сообщество: не рефакторится ([форум](https://forum.godotengine.org/t/godot-design-flaw-inheritance-vs-composition/35115)) | Не глубже одного уровня; варианты лучше данными (`Resource`) |
| Формат сохранения | Resource через `ResourceSaver`: быстро, типы сохраняются | JSON: безопасно, читаемо | JSON с версией формата; Resource только для данных, которые нельзя подменить снаружи |
| Фреймворк тестов | GUT ([репозиторий](https://github.com/bitwes/Gut)): простой, зрелый | gdUnit4 ([репозиторий](https://github.com/godot-gdunit-labs/gdUnit4)): scene runner, C#, Action | GDScript-проект: любой, один на проект. Много UI и сцен или C#: gdUnit4 |
| DI | Внедрение сверху через `@export` и `setup()` | Контейнеры и провайдеры (AutoInject, Arca) | Внедрение сверху; сервис-локатор только в больших проектах |

## Чеклист: структура нового проекта

### Ключевые выводы

- Начинайте с минимума и добавляйте слои по сигналу (рост команды, первый баг из-за глобального состояния, первая потребность в тестах), а не заранее.
- Дешевле всего сразу соблюдать три правила: сцены запускаются отдельно, вызовы вниз и сигналы вверх, правила игры не живут в `_process()`.

| Уровень | Когда | Что сделать |
|---|---|---|
| Прототип или гейм-джем | дни или недели, один человек | Папки по фичам, `snake_case`. Одна-две автозагрузки (`Events`, `Game`). `enum`-FSM. `change_scene_to_file`. `.gitignore` с `.godot/`, `.uid` в git |
| Небольшая игра или приложение | месяцы, 1–3 человека | Main/World/GUI. Данные в своих `Resource` (`data/`). Правила в `RefCounted` (`core/`). Шина только для далёких событий. Сервис сохранений с JSON и версией формата. Ввод через InputMap, строки через `tr()` с первого дня. GUT или gdUnit4 на `core/`, headless-прогон в CI (`--import`, затем тесты) |
| Большой проект | год и больше, команда, контент от дизайнеров | Импорт таблиц в `.tres`, редакторские плагины в `addons/`. Сервисы вместо «божественной» автозагрузки; внедрение через `setup()` или локатор. Загрузчик сцен с фоновой загрузкой. HSM или BT (LimboAI) для ИИ. Интеграционные тесты сцен (scene runner), JUnit-отчёты в CI, экспорт в CI (godot-ci). Git LFS, правила владения общими сценами, ARCHITECTURE.md с картой автозагрузок и событий шины |
| Мультиплеер (на любом уровне) | есть сеть | Серверный авторитет, детерминированное ядро на `RefCounted`, ввод отдельно от персонажа, проверка аргументов `any_peer`-RPC, headless-сервер в CI |

# Ресурсы, импорт ассетов и файлы проекта

Как Godot 4 хранит, загружает, кэширует и импортирует данные. В справочнике разобраны жизненный цикл `Resource` и кэш `ResourceLoader`, общие ресурсы и их копирование (`resource_local_to_scene`, `duplicate`, `duplicate_deep`), встроенные и внешние ресурсы, текстовый и бинарный форматы, UID, `res://` и `user://`. Дальше идёт конвейер импорта: файлы `.import`, папка `.godot/imported`, пресеты, текстуры и режимы сжатия, аудио, 3D-сцены, шрифты, переводы, свои импортёры, импорт в CI, фильтры экспорта, бюджеты памяти и контроль версий. Материал актуален на октябрь 2026 года, Godot 4.7.2. Поведение, помеченное «(проверено на 4.7.2)», воспроизведено в headless-прогоне на этой версии. Ресурсы как модель данных, сохранения и моды описаны в [architecture.md](architecture.md) (разделы «Resources как данные», «Сохранение и загрузка», «Моды»). Экран загрузки и память описаны в [performance.md](performance.md), CI и Git LFS в [toolchain.md](toolchain.md). Здесь эти темы не повторяются.

- [Жизненный цикл ресурса и кэш](#жизненный-цикл-ресурса-и-кэш)
- [load, preload и фоновая загрузка](#load-preload-и-фоновая-загрузка)
- [Общие ресурсы и копирование](#общие-ресурсы-и-копирование)
- [Встроенные и внешние ресурсы, .tres и .res](#встроенные-и-внешние-ресурсы-tres-и-res)
- [UID и перемещение файлов](#uid-и-перемещение-файлов)
- [res://, user:// и файлы, которые не ресурсы](#res-user-и-файлы-которые-не-ресурсы)
- [Как устроен импорт](#как-устроен-импорт)
- [Текстуры](#текстуры)
- [2D, пиксель-арт и атласы](#2d-пиксель-арт-и-атласы)
- [Аудио](#аудио)
- [3D-сцены](#3d-сцены)
- [Шрифты](#шрифты)
- [Переводы](#переводы)
- [Свои импортёры](#свои-импортёры)
- [Импорт в CI и фильтры экспорта](#импорт-в-ci-и-фильтры-экспорта)
- [Бюджеты размера и памяти](#бюджеты-размера-и-памяти)
- [Контроль версий ассетов](#контроль-версий-ассетов)
- [Антипаттерны](#антипаттерны)
- [Чеклист импорта и ресурсов](#чеклист-импорта-и-ресурсов)

## Жизненный цикл ресурса и кэш

### Ключевые выводы

- `Resource` наследует `RefCounted`. Он освобождается, когда исчезает последняя ссылка. Справочник: «A resource will be cached when loaded for the first time and removed from cache once all references are released». Значит, кэш держит ресурс только пока его держит кто-то ещё. Кэш не продлевает жизнь ресурса, а лишь не даёт загрузить второй экземпляр.
- Ключ кэша — путь. Два `load()` одного пути возвращают один и тот же объект. Это относится и к `preload()`: `preload(p) == load(p)` (проверено на 4.7.2). Правка полей загруженного ресурса видна всем, кто загрузит его следом: `a.value = 99`, и новый `load()` вернёт 99 (проверено на 4.7.2).
- Режим кэша задаётся аргументом `cache_mode` у `ResourceLoader.load()` и `load_threaded_request()`:

| Режим | Что делает | Когда нужен |
|---|---|---|
| `CACHE_MODE_IGNORE` (0) | Главный ресурс и его подресурсы не берутся из кэша и не кладутся в него. Зависимости (внешние файлы) идут через REUSE | Свежая копия файла без влияния на остальную игру |
| `CACHE_MODE_REUSE` (1, по умолчанию) | Берёт из кэша, недостающее загружает и кэширует | Почти всегда |
| `CACHE_MODE_REPLACE` (2) | Как REUSE, но данные с диска перезаписываются в **уже существующие** объекты | Горячая перезагрузка: ссылки на объект остаются, данные обновляются |
| `CACHE_MODE_IGNORE_DEEP` (3) | IGNORE рекурсивно для всех зависимостей | Полностью независимая копия дерева ресурсов |
| `CACHE_MODE_REPLACE_DEEP` (4) | REPLACE рекурсивно | Перезагрузка всего дерева |

- Проверено на 4.7.2: `CACHE_MODE_IGNORE` вернул новый объект, но его `resource_path` всё равно равен исходному пути. Внешняя зависимость `child` у него осталась общим объектом из кэша. Только `CACHE_MODE_IGNORE_DEEP` дал свежий `child` со значением с диска. `CACHE_MODE_REPLACE` вернул тот же объект, что и кэш.
- Для скриптов `CACHE_MODE_IGNORE` исторически работает не так, как ожидают: скрипт всё равно берётся из кэша ([#59669](https://github.com/godotengine/godot/issues/59669), открыт) [не проверено на 4.7.2].
- `Resource.take_over_path(path)` подменяет запись кэша: следующий `load(path)` вернёт ваш объект, даже если он не сохранён (проверено на 4.7.2). Этим пользуются генераторы контента и редакторские инструменты. В игровом коде это скорее источник путаницы.
- Полезные проверки: `ResourceLoader.exists(path)`, `has_cached(path)`, `get_cached_ref(path)` (вернуть кэшированный объект без загрузки), `get_dependencies(path)` (список вида `uid://…::::res://…` или путей). Для `outer.tres` с внешним подресурсом и скриптом получилось `["res://data.gd", "res://inner.tres"]` (проверено на 4.7.2).

```gdscript
# Перечитать конфиг баланса с диска, не ломая ссылки у узлов, которые его держат
func hot_reload_balance() -> void:
	ResourceLoader.load("res://data/balance.tres", "", ResourceLoader.CACHE_MODE_REPLACE)

# Полностью независимая копия дерева ресурсов (например, для редактора уровней)
func load_isolated(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html) | справочник API, 4.7 | Подсчёт ссылок, кэш, `take_over_path`, `duplicate*`, `resource_local_to_scene` |
| [ResourceLoader](https://docs.godotengine.org/en/stable/classes/class_resourceloader.html) | справочник API, 4.7 | Все `CACHE_MODE_*`, `load_threaded_*`, `get_dependencies`, `list_directory` |
| [#59669 CACHE_MODE_IGNORE и скрипты](https://github.com/godotengine/godot/issues/59669) | GitHub, 2022, открыт | Где IGNORE не игнорирует кэш |

## load, preload и фоновая загрузка

### Ключевые выводы

- `preload("res://…")` выполняется при компиляции скрипта: путь должен быть константой, а ресурс загружается вместе со скриптом. `load()` выполняется в момент вызова. Документация: «you cannot call `preload` with a variable path».
- Правило выбора. `preload` подходит для мелких, всегда нужных ресурсов скрипта (сцена пули, иконка, шейдер). `load` нужен для пути из данных и того, что нужно не всегда. Для тяжёлого (уровни, крупные 3D-сцены) берите `load_threaded_request`. Длинная цепочка `preload` на автозагрузках увеличивает время старта, а циклические `preload` между скриптами приводят к ошибкам загрузки.
- С 4.4 путь может быть UID: `preload("uid://cxyz…")`. С 4.5 ресурс перетаскивается в редактор скрипта с Ctrl, и редактор сам вставит UID. Такая ссылка переживает перемещение файла.
- Фоновая загрузка (`load_threaded_request` / `load_threaded_get_status` / `load_threaded_get`) и экран загрузки уже разобраны в [performance.md](performance.md#память-ресурсы-и-загрузка) и [architecture.md](architecture.md#смена-сцен-и-экраны-загрузки). Здесь две оговорки. Первая: `use_sub_threads = true` ускоряет загрузку больших сцен, но по документации может замедлить главный поток. Вторая: в 4.7 есть открытая регрессия, при которой TileSet в сцене, загруженной с `use_sub_threads = true`, приходит без атласов ([#120482](https://github.com/godotengine/godot/issues/120482)). Если видите «No TileSet atlas source with id 0», уберите `use_sub_threads`.
- `ResourceLoader.list_directory(path)` в 4.7 перечисляет ресурсы так, как их видит игра (включая экспорт, где исходные файлы заменены импортированными). Порядок не гарантирован, сортируйте сами. В экспорте `DirAccess` по `res://` видит `.import`/`.remap`, а не исходные `.png` [не проверено на 4.7.2]. Поэтому каталог контента лучше строить через `list_directory` или через явный реестр-ресурс.

```gdscript
const BULLET := preload("res://features/weapons/bullet.tscn")  # мелкое и всегда нужно

func spawn_enemy(kind: StringName) -> Node:
	var path := "res://features/enemies/%s.tscn" % kind      # путь из данных: только load
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Нет сцены врага: %s" % path)
		return null
	return scene.instantiate()
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html) | документация Godot, живой | `load` против `preload`, встроенные и внешние ресурсы |
| [Background loading](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html) | документация Godot, живой | `load_threaded_*` |
| [#120482 TileSet и use_sub_threads](https://github.com/godotengine/godot/issues/120482) | GitHub, июнь 2026, открыт | Регрессия 4.7 при загрузке подпотоками |
| [Godot 4.5 release](https://godotengine.org/releases/4.5/) | Godot Foundation, 2025 | `duplicate_deep`, preload по UID, «Paste as Unique» |

## Общие ресурсы и копирование

### Ключевые выводы

- По умолчанию все экземпляры сцены делят один объект ресурса, и встроенного, и внешнего. Это экономит память, но правка `material.albedo_color` или `stats.hp` у одного врага меняет её у всех. Проверено на 4.7.2: два `instantiate()` одной сцены дали один и тот же объект подресурса.
- `resource_local_to_scene = true` (в инспекторе «Local to Scene») заставляет движок копировать ресурс для каждого экземпляра сцены. Справочник: «the resource is duplicated for each instance of all scenes using it». Проверено на 4.7.2: и встроенный подресурс, и внешний `.tres` с этим флагом дали разные объекты у двух экземпляров. Копия внешнего файла теряет `resource_path`, то есть сохранить её обратно в файл через `ResourceSaver.save(res)` без пути не выйдет.
- Ограничения `local_to_scene`. Флаг срабатывает при `PackedScene.instantiate()`, а `Node.duplicate()` уже созданного экземпляра оставляет ресурс общим (проверено на 4.7.2, открытый [#117636](https://github.com/godotengine/godot/issues/117636)). Копия делается для каждой сцены, где ресурс упомянут, включая вложенные подсцены. Если нужна «одна копия на персонажа», флаг не поможет ([обсуждение на форуме](https://forum.godotengine.org/t/how-to-force-a-resource-to-be-local-to-a-scenes-owner/110037)). Менять флаг в рантайме бесполезно, он читается при инстанцировании. `AnimationLibrary` его исторически игнорирует ([#75719](https://github.com/godotengine/godot/issues/75719)) [не проверено на 4.7.2]. Свою донастройку копии делайте переопределением `_setup_local_to_scene()`. Публичный `setup_local_to_scene()` устарел ([PR #67082](https://github.com/godotengine/godot/pull/67082)).
- `duplicate()` и `duplicate_deep()` после переработки в 4.5 ([PR #100673](https://github.com/godotengine/godot/pull/100673)) ведут себя предсказуемо. Каждый подресурс копируется один раз, и все ссылки в копии указывают на эту одну копию. Скрипт не копируется никогда ([PR #108453](https://github.com/godotengine/godot/pull/108453)). Таблица ниже проверена на 4.7.2: у ресурса `outer` поле `child` указывает на внешний `inner.tres`, а `arr = [встроенный sub, внешний inner]`.

| Вызов | Внешний `child` | Встроенный `arr[0]` | Сам `Array` | Когда брать |
|---|---|---|---|---|
| `duplicate()` | общий | общий | **тот же массив** | Только плоские ресурсы без вложенных коллекций |
| `duplicate(true)` | общий | копия | копия | Состояние экземпляра поверх общих «шаблонов» из файлов |
| `duplicate_deep()` (= `DEEP_DUPLICATE_INTERNAL`) | общий | копия | копия | То же, что `duplicate(true)`, но с явным режимом |
| `duplicate_deep(DEEP_DUPLICATE_ALL)` | копия | копия | копия | Полностью независимое дерево (редактор, генератор, «сохранить как») |
| `duplicate_deep(DEEP_DUPLICATE_NONE)` | общий | общий | копия | Скопировать коллекции, но не ресурсы внутри |

- Ловушка `duplicate()` без аргументов: вложенные `Array` и `Dictionary` остаются **теми же объектами**. `copy.arr.append(x)` изменит оригинал (проверено на 4.7.2).
- В инспекторе есть «Make Unique» (копия одного ресурса) и с 4.5 «Paste as Unique». В 4.6 инспектор помечает отдельной иконкой ресурсы, на которые ссылаются из других мест. Это быстрый способ увидеть, что материал общий.
- Архитектурное правило из [architecture.md](architecture.md#resources-как-данные-и-конфигурация) остаётся в силе: неизменяемые данные держите в общем ресурсе, изменяемое состояние в узле или модели. `local_to_scene` и `duplicate` нужны там, где состояние действительно живёт в ресурсе (материал с параметрами экземпляра, `Curve`, редактируемый на ходу, `ShaderMaterial` с уникальными uniform).
- Для одного-двух параметров шейдера копия материала не нужна: есть instance uniform (`instance uniform vec4 tint;` + `set_instance_shader_parameter()`) у `GeometryInstance3D` и per-instance данные `MultiMesh`.

```gdscript
# enemy.gd: свой экземпляр статов поверх общего шаблона из .tres
@export var stats_template: EnemyStats

var stats: EnemyStats

func _ready() -> void:
	stats = stats_template.duplicate_deep()   # внешние иконки и звуки остаются общими
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [PR #100673 Overhaul resource duplication](https://github.com/godotengine/godot/pull/100673) | Pedro J. Estébanez (RandomShaper), 2025 | Точные правила `duplicate`/`duplicate_deep` и local-to-scene |
| [#117636 local_to_scene и Node.duplicate](https://github.com/godotengine/godot/issues/117636) | GitHub, 2026, открыт | Почему `duplicate()` узла не размножает ресурс |
| [PR #87268](https://github.com/godotengine/godot/pull/87268), [PR #109377](https://github.com/godotengine/godot/pull/109377), [PR #115557](https://github.com/godotengine/godot/pull/115557) | GitHub, 2024–2026 | Исправления local-to-scene в массивах, типизированных словарях и при инстанцировании |
| [Duplicate Resources without manually making them unique](https://forum.godotengine.org/t/duplicate-resources-without-manually-making-them-unique/114652) | форум Godot, 2025 | Практика `duplicate` в `_ready()` |

## Встроенные и внешние ресурсы, .tres и .res

### Ключевые выводы

- Встроенный (built-in) ресурс хранится внутри `.tscn`/`.tres` как `[sub_resource]`, внешний лежит отдельным файлом и подключается как `[ext_resource]`. Ресурс становится встроенным, если очистить его путь, и разница фиксируется при сохранении сцены. `is_built_in()` скажет, встроен ли ресурс.
- Делайте ресурс внешним, если он используется в двух и более местах, его правит другой человек (дизайнер правит баланс, художник правит материал) или он крупный (меш, анимация, большая кривая). Встроенным оставляйте мелкое и одноразовое: форма коллизии одного объекта, `StyleBox` одной кнопки.
- `.tres` — текст, удобен для diff и ревью. `.res` — бинарный формат, быстрее грузится и компактнее. При экспорте движок сам конвертирует текстовые ресурсы в бинарные. Поэтому в репозитории `.tres` почти всегда лучше, а `.res` нужен там, где текст раздувается: меши, анимации, данные изображений, большие массивы чисел. Документация Advanced Import Settings прямо советует сохранять меши в `.res`.
- Замер (проверено на 4.7.2):

| Что сохранено | `.tres` | `.res` | `.res` + `FLAG_COMPRESS` |
|---|---|---|---|
| Ресурс с 200 встроенными подресурсами (int-поля) | 26 058 Б | 20 327 Б | 2 604 Б |
| `ImageTexture` 256×256 RGBA8 | 1 245 421 Б | 262 610 Б | — |

- `ResourceSaver.save(res, path, flags)` принимает флаги: `FLAG_COMPRESS` (Zstd, только бинарные форматы), `FLAG_BUNDLE_RESOURCES` (встроить внешние зависимости), `FLAG_CHANGE_PATH` (переписать `resource_path` на новый), `FLAG_OMIT_EDITOR_PROPERTIES`, `FLAG_RELATIVE_PATHS`.
- Не храните текстуры как `ImageTexture` в `.tres`: это мегабайты текста без сжатия для GPU. Картинка должна быть исходным PNG/WebP с импортом.
- Внутренние классы скрипта (`class Foo extends Resource` внутри другого файла) нельзя сохранять как ресурс: файл хранит путь к скрипту. Ресурсный класс должен лежать в своём файле.
- Безопасность загрузки `.tres`/`.res` из чужих источников описана в [architecture.md](architecture.md#сохранение-и-загрузка). Ресурс может содержать встроенный скрипт.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [ResourceSaver](https://docs.godotengine.org/en/stable/classes/class_resourcesaver.html) | справочник API, 4.7 | Флаги сохранения, `set_uid`, `get_resource_id_for_path` |
| [TSCN file format](https://docs.godotengine.org/en/stable/engine_details/file_formats/tscn.html) | документация Godot | `ext_resource`, `sub_resource`, `uid`, `format=3` |
| [Advanced Import Settings](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/advanced_import_settings.html) | документация Godot, живой | Совет `.res` для мешей |

## UID и перемещение файлов

### Ключевые выводы

- UID (`uid://…`) — стабильный идентификатор ресурса, который не зависит от пути. Где он хранится: импортированные ассеты держат его в своём `.import`, `.tscn`/`.tres` в заголовке, а скрипты и шейдеры с 4.4 в соседнем файле `*.gd.uid` / `*.gdshader.uid`. Проверено на 4.7.2: первый `--import` создал `.uid` для всех `.gd`, а UID у PNG появился в `.import`.
- Коммитьте `.uid` вместе с исходником. Hugo Locurcio: «`*.uid` should **not** be added to `.gitignore`». Без них на чужой машине ссылки по UID ломаются, и Godot откатывается на пути с предупреждением.
- Перемещайте и переименовывайте файлы в доке FileSystem: редактор обновит ссылки и перенесёт `.import`/`.uid`. Если переносите вне редактора, тащите `.uid` и `.import` вместе с файлом, затем откройте проект и пересохраните сцены, которые ругаются. С 4.6 диалог зависимостей позволяет вручную разрешить и косвенно потерянные зависимости.
- После обновления проекта на новую минорную версию прогоните Project > Tools > Upgrade Project Files. С 4.4 оно добавляет UID, с 4.6 сохраняет уникальные ID узлов (`unique_id=` у `[node]`, проверено на 4.7.2). Иначе диффы будут всплывать по одному при каждом сохранении.
- Наблюдение (проверено на 4.7.2): `ResourceSaver.save()` из headless-скрипта (`--script`) записал `.tres` **без** `uid=` в заголовке, и последующий `--import` его не добавил. Если генерируете ресурсы скриптом, присвойте UID явно (`ResourceUID.create_id_for_path()` + `ResourceSaver.set_uid()`) или прогоните генератор как `EditorScript` в редакторе [не проверено: присвоение UID при сохранении из GUI].
- API: `ResourceLoader.get_resource_uid(path)`, `ResourceUID.id_to_text(id)` / `text_to_id(text)`, `get_id_path(id)`, статические `ResourceUID.path_to_uid(path)`, `uid_to_path(uid)`, `ensure_path(path_or_uid)`. `INVALID_ID` = −1. `load("uid://…")` возвращает ресурс с обычным `resource_path` (проверено на 4.7.2).

```gdscript
# Сохранить ссылку на ресурс в своём формате (JSON-каталог, сетевое сообщение) устойчиво к переносам
func ref_of(res: Resource) -> String:
	return ResourceUID.path_to_uid(res.resource_path)   # "uid://…" или путь, если UID нет

func resolve(ref: String) -> Resource:
	var path := ResourceUID.ensure_path(ref)            # "" для битого UID
	return load(path) if not path.is_empty() else null
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [UID changes coming to Godot 4.4](https://godotengine.org/article/uid-changes-coming-to-godot-4-4/) | Hugo Locurcio, 2025 | Почему `.uid`, что коммитить, перенос вне редактора, отвергнутые альтернативы |
| [ResourceUID](https://docs.godotengine.org/en/stable/classes/class_resourceuid.html) | справочник API, 4.7 | `path_to_uid`, `ensure_path`, `create_id_for_path` |
| [Godot 4.4 release](https://godotengine.org/releases/4.4/) | Godot Foundation, 2025 | `.uid`, инструмент миграции UID, Betsy |
| [Godot 4.6 release](https://godotengine.org/releases/4.6/) | Godot Foundation, январь 2026 | Уникальные ID узлов, разрешение косвенных зависимостей |
| [PR #101650](https://github.com/godotengine/godot/pull/101650), [PR #104248](https://github.com/godotengine/godot/pull/104248) | GitHub, 2025 | Когда EditorFileSystem создаёт `.uid` |

## res://, user:// и файлы, которые не ресурсы

### Ключевые выводы

- `res://` — папка с `project.godot`. В экспорте она доступна только для чтения и упакована в PCK. `user://` — единственное место, куда гарантированно можно писать: сохранения, настройки, кэш, скачанный контент. На Windows это `%APPDATA%\Godot\app_userdata\<проект>`, а с `application/config/use_custom_user_dir` получается `%APPDATA%\<проект>`. На Web `user://` хранится в IndexedDB.
- Импортированные ассеты читаются только через `load()`. Документация: FileAccess на исходный файл «will break in the exported project». Проверено на 4.7.2: `Image.load_from_file("res://icon.png")` в редакторе работает, но предупреждает «this will not work on export», потому что исходного PNG в экспорте нет.
- Файлы, которые не ресурсы (`.txt`, `.yaml`, `.md`, свои бинарники), по умолчанию **не попадают** в экспорт. Добавьте маску в фильтр экспорта «Filters to export non-resource files» (`*.txt, data/*.yaml`). Либо оформите такие данные как ресурс или импортёр (раздел «Свои импортёры»). Два частых исключения (проверено на 4.7.2, подробно в [project-export.md](project-export.md)): `.json` в Godot 4 — ресурс, он экспортируется без фильтра, а `load()` возвращает объект `JSON`. `.csv` по умолчанию импортируется как таблица переводов, и сам CSV в PCK не попадёт даже с фильтром. Для CSV с данными переключите импортёр на «Keep File».
- Виртуальная ФС PCK чувствительна к регистру, а Windows и macOS нет. `load("res://Player.png")` для `player.png` работает в редакторе на Windows и падает в экспорте. Имена держите в `snake_case`.
- Пустой файл `.gdignore` в папке исключает её из импорта, из дока FileSystem и из экспорта. Загружать оттуда через `load()` тоже нельзя. Шаблонов он не понимает. Сюда кладут исходники художников (`.psd`, `.kra`, `.blend1`), документацию, node_modules инструментов. Файлы и папки, имя которых начинается с точки, не экспортируются никогда.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [File paths in Godot projects](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html) | документация Godot, живой | `res://`, `user://`, пути по ОС, self-contained режим |
| [Project organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html) | документация Godot, живой | Регистр в PCK, `snake_case`, `.gdignore`, `addons/` |
| [Exporting projects](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html) | документация Godot, живой | Режимы ресурсов экспорта, фильтры включения и исключения |

## Как устроен импорт

### Ключевые выводы

- Godot не работает с PNG, WAV или glTF напрямую. Импортёр превращает исходник в формат движка и кладёт результат в `res://.godot/imported/`, а рядом с исходником пишет `<файл>.import` с настройками. Проверено на 4.7.2: для `icon.png` появились `icon.png.import`, `.godot/imported/icon.png-<хеш>.ctex` и `.md5`, для `sfx.wav` появились `sfx.wav.import` и `.godot/imported/sfx.wav-<хеш>.sample`.
- Секции `.import`: `[remap]` (импортёр, тип, `uid`, путь результата, для VRAM-текстур отдельный путь на формат: `path.s3tc=…`, `path.etc2=…`), `[deps]` (исходник и результаты), `[params]` (все настройки). Коммитьте `.import`, а `.godot/` игнорируйте.
- Реимпорт запускается при изменении MD5 исходника или параметров. Удалённая `.godot/imported/` восстанавливается при следующем открытии. Старые результаты при смене режима не удаляются (проверено на 4.7.2: `.ctex` остался рядом с новым `.s3tc.ctex`). Если папка разрослась, удалите `.godot/` целиком при закрытом редакторе.
- Настройки меняют в доке Import: выбрать файл, поменять, нажать **Reimport**. Если переключиться на другой файл до реимпорта, правки пропадут. С 4.5 снова работает пакетная правка: выделите несколько файлов, отметьте галочками нужные параметры и нажмите Reimport.
- Пресеты: меню **Preset** в доке Import (например «2D Pixel», «3D», «Normal Map») и «Set as Default for '<импортёр>'». Значения по умолчанию на весь проект задаются в Project Settings > **Import Defaults**. Это первое, что стоит настроить в новом проекте: пиксельной игре нужен Lossless без mipmap, 3D-игре нужны mipmap и VRAM.
- Импортёр можно сменить для файла: «Import As». Например, PNG можно импортировать как `Texture2D`, `Image`, `TextureAtlas`, `BitMap`, `Texture2DArray`, `Cubemap`, `Texture3D`. Кроме того, есть «Keep File (exported as is)», если файл нужен как есть и его читают через `FileAccess`, и «Skip File (not exported)».

```ini
; icon.png.import (проверено на 4.7.2, значения по умолчанию для 2D)
[remap]
importer="texture"
type="CompressedTexture2D"
uid="uid://d0fmi4jgrr3ov"
path="res://.godot/imported/icon.png-457fa4c2….ctex"
metadata={ "vram_texture": false }
[params]
compress/mode=0              ; 0 Lossless, 1 Lossy, 2 VRAM Compressed, 3 VRAM Uncompressed, 4 Basis Universal
compress/high_quality=false  ; true → BPTC (десктоп) / ASTC (мобильные)
compress/lossy_quality=0.7
compress/normal_map=0        ; 0 Detect, 1 Enable, 2 Disabled
mipmaps/generate=false
process/fix_alpha_border=true
process/size_limit=0
detect_3d/compress_to=1      ; при использовании в 3D перейти на VRAM Compressed
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Import process](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/import_process.html) | документация Godot, живой | `.import`, реимпорт, пресеты, Keep File/Skip File |

## Текстуры

### Ключевые выводы

- Режим сжатия решает, сколько текстура весит на диске и сколько занимает видеопамяти. Lossless и Lossy экономят только диск: в видеопамяти текстура лежит несжатой (RGBA8 = 4 байта на пиксель). Только VRAM Compressed и Basis Universal экономят видеопамять, обычно в 4–6 раз.
- Замер: 512×512 непрозрачная «шумная» PNG (исходник 549 КБ, несжатый RGBA8 = 1 МБ), результат в `.godot/imported` (проверено на 4.7.2):

| Режим | Файл | Видеопамять (расчёт) |
|---|---|---|
| Lossless (WebP lossless) | 381 КБ | 1 МБ |
| Lossy, качество 0.7 | 22 КБ | 1 МБ |
| VRAM Compressed (S3TC/DXT1, непрозрачная) | 131 КБ; с mipmap 175 КБ | ≈ как файл |
| VRAM Compressed + High Quality (BPTC) + mipmap | 350 КБ | ≈ как файл |
| VRAM Uncompressed | 1 МБ | 1 МБ |
| Basis Universal | 243 КБ | транскодируется в формат GPU при загрузке |

- Документация прямо говорит о VRAM Compressed: «should be avoided for 2D as it exhibits noticeable artifacts, especially for lower-resolution textures». Для 2D берите Lossless, для больших 2D-фонов Lossy. Для 3D нужен VRAM Compressed (его же включает Detect 3D).
- **Detect 3D.** Если 2D-текстура впервые использована в 3D-материале, импортёр сам переключит её на VRAM Compressed, включит mipmap и реимпортирует (`detect_3d/compress_to`). Пиксель-арту в 3D это вредит: заранее поставьте `compress_to` = Disabled или верните Lossless.
- **High Quality** = BPTC (BC7/BC6H) на десктопе и ASTC на мобильных, вместо S3TC/ETC2. Работает в Forward+ и Mobile, в Compatibility всегда выключено. Файл и видеопамять вдвое больше DXT1 (замер выше). Включайте для текстур, где видны блоки: градиенты неба, UI в 3D, лица.
- **Форматы GPU по платформам.** Десктоп использует S3TC/BPTC, мобильные и Web используют ETC2/ASTC. Для экспорта на Android/iOS включите Project Settings > Rendering > Textures > VRAM Compression > **Import ETC2 ASTC**, иначе экспорт покажет ошибку «Target platform requires 'ETC2/ASTC' texture compression». После включения нужен реимпорт: без него экспорт пройдёт, но сжатие не применится ([форум](https://forum.godotengine.org/t/the-effect-of-etc2-atsc-compression/87984)). Для Web с мобильными браузерами нужны оба набора, и размер растёт. Basis Universal даёт один файл на все платформы ценой качества и медленного импорта. В `--script`-режиме оба флага читались как `false`, хотя редактор импортировал S3TC (проверено на 4.7.2). Похоже, формат платформы редактора включается неявно [не проверено].
- **Mipmaps** выключены в 2D-пресете и добавляют около 33 % памяти (замер: 131 → 175 КБ). В 3D их включайте всегда: без них появляются мерцание и муар, и текстуры дальних объектов тяжелее для кэша GPU. Параметр `mipmaps/limit` не реализован.
- **Карты нормалей.** `compress/normal_map = Detect` при использовании в слоте normal переключает сжатие на RGTC (два канала, R и G). Если ваш шейдер читает синий канал, отключите. Godot ждёт нормали в стиле OpenGL (Y+). Для карт DirectX включите `process/normal_map_invert_y`. Roughness можно «подмешать» из карты нормалей (`roughness/mode`, `roughness/src_normal`) для антиалиасинга бликов.
- **Размеры.** Мобильные GPU и Web «usually can't display textures larger than 4096×4096». `process/size_limit` ограничит длинную сторону без правки исходника. Блочные форматы требуют сторон, кратных 4, а Betsy (GPU-компрессор, с 4.4) дополняет размер сам ([PR #104275](https://github.com/godotengine/godot/pull/104275)). Степени двойки не обязательны, но с ними проще mipmap и тайлинг.
- **Скорость импорта.** VRAM Compressed — самый медленный импорт. С 4.4 сжатие идёт на GPU (Betsy, `rendering/textures/vram_compression/compress_with_gpu = true`). В 4.6 RGB-текстуры для 3D импортируются до 2 раз быстрее. Basis Universal и RDO (`compress/rdo_quality_loss`) сильно замедляют импорт больших изображений.
- **HDR (.hdr, .exr).** По умолчанию `hdr_compression = Opaque Only`: сжимаются только непрозрачные. Без сжатия формат RGBE9995.
- **SVG** растеризуется при импорте с `svg/scale` (1.0 — исходный размер). Импорт как `DPITexture` растеризует SVG в рантайме под текущий oversampling, что подходит для UI на разных DPI. Рендерер ThorVG поддерживает не всё: текст переведите в кривые.
- Фильтрация (nearest/linear) и repeat — **не** настройка импорта. В 2D это `CanvasItem.texture_filter` и проектная настройка Rendering > Textures > Canvas Textures > Default Texture Filter (по умолчанию Linear), в 3D это свойство материала, в шейдерах это хинты `filter_nearest`, `repeat_enable` у `sampler2D`.

### Какой режим сжатия текстуры выбрать

| Ситуация | Режим | Mipmaps | Примечания |
|---|---|---|---|
| 2D-спрайты, тайлы, UI, пиксель-арт | Lossless | нет | Пресет «2D Pixel» для пиксель-арта, фильтр Nearest в проекте |
| Большие 2D-фоны, иллюстрации, сплэши | Lossy (0.7–0.9) | нет | Экономит диск и размер сборки, видеопамять та же |
| Огромный объём 2D-арта на мобильных, видеопамяти не хватает | VRAM Compressed или Basis | по ситуации | Проверьте артефакты на маленьких спрайтах; альтернатива — уменьшить `size_limit` |
| 3D albedo, ORM, roughness, metallic | VRAM Compressed | да | По умолчанию через Detect 3D |
| 3D с видимыми блоками (небо, градиенты, лица) | VRAM Compressed + High Quality | да | BPTC/ASTC, вдвое тяжелее |
| Карта нормалей | VRAM Compressed, Normal Map = Detect/Enable | да | RGTC; DirectX-карты с `normal_map_invert_y` |
| Пиксель-арт на 3D-объектах | Lossless, `detect_3d/compress_to` = Disabled | обычно нет | VRAM-сжатие портит маленькие текстуры |
| Один пакет на все платформы, минимальный размер скачивания | Basis Universal | да | Медленный импорт, качество ниже; float-изображения уходят в VRAM Compressed |
| Float/HDR-данные для шейдера (карты высот, LUT, векторные поля) | VRAM Uncompressed или Lossless | по ситуации | Сжатие исказит данные |
| Текстуры, которые меняете из кода (`Image` → `ImageTexture`) | Импорт как `Image` | — | `ImageTexture.create_from_image()` в рантайме |

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Importing images](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html) | документация Godot, 4.7 | Все режимы, Detect 3D, normal map, size limit, SVG, DPITexture |
| [ResourceImporterTexture](https://docs.godotengine.org/en/stable/classes/class_resourceimportertexture.html) | справочник API, 4.7 | Каждый параметр `.import` для текстур |
| [Godot 4.6 release](https://godotengine.org/releases/4.6/) | Godot Foundation, 2026 | Ускорение импорта 3D-текстур, улучшенные LOD |
| [PR #99537 Betsy BC3/BC5](https://github.com/godotengine/godot/pull/99537) | GitHub, 2024 | GPU-сжатие текстур |
| [Terrain3D: Supported Platforms](https://terrain3d.readthedocs.io/en/latest/docs/platforms.html) | Terrain3D, живой | Практический чеклист ETC2/ASTC для мобильных |
| [ETC2/ASTC в настройках проекта](https://community.gamedev.tv/t/import-etc2-astc-in-project-settings-cant-find-it/237330) | GameDev.tv, 2023 | Где спрятана настройка (Advanced Settings) |

## 2D, пиксель-арт и атласы

### Ключевые выводы

- Пиксель-арт: пресет импорта «2D Pixel» (Lossless, без mipmap, без фильтрации) и `Default Texture Filter = Nearest` в проекте. Масштабируйте окно целым множителем (`display/window/stretch/scale_mode = integer`). У пиксельных шрифтов подпиксельное позиционирование выключено (раздел «Шрифты»).
- Полупрозрачные края. `process/fix_alpha_border = true` (по умолчанию) заливает прозрачные пиксели цветом соседей, чтобы при фильтрации не было тёмной каймы. Альтернатива — `process/premult_alpha` и материал с premultiplied-смешиванием.
- Атласы уменьшают переключения текстур, а значит улучшают батчинг 2D (батчинг в Forward+/Mobile есть с 4.4, подробнее в [performance.md](performance.md#рендеринг-батчинг-multimesh-серверы-шейдеры)). Варианты: `AtlasTexture` (регион большой текстуры, задаётся в инспекторе), импортёр **TextureAtlas** (Import As → TextureAtlas: PNG-кадры собираются в один атлас, на выходе `AtlasTexture` в режиме Region или `ArrayMesh` в режиме Mesh, который экономит fill rate на больших прозрачных спрайтах), TileSet-атлас, `SpriteFrames` с одним листом. Внешние упаковщики подключаются плагинами ([TexturePacker Importer](https://store.godotengine.org/asset/codeandweb/texturepacker-importer)).
- Ограничение атласа: mipmap и VRAM-сжатие у атласа смешивают соседние кадры на дальних уровнях. Оставляйте между кадрами отступ в 2–4 пикселя или не используйте mipmap в 2D.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [ResourceImporterTextureAtlas](https://docs.godotengine.org/en/stable/classes/class_resourceimportertextureatlas.html) | справочник API, 4.7 | Режимы Region и Mesh, обрезка прозрачных краёв |
| [AtlasTexture](https://docs.godotengine.org/en/stable/classes/class_atlastexture.html) | справочник API | Регион, `margin`, `filter_clip` |
| [Godot 4.7 release](https://godotengine.org/releases/4.7/) | Godot Foundation, июнь 2026 | Тайлинг AtlasTexture в TextureRect, `DrawableTexture2D` |

## Аудио

### Ключевые выводы

- Выбор формата по документации: «Consider using WAV for short and repetitive sound effects, and Ogg Vorbis for music, speech, and long sound effects». MP3 декодируется дешевле Ogg, но при равном качестве файл заметно больше. Он подходит для мобильных и Web, где CPU мало, а длинных фоновых звуков много.
- WAV декодируется почти бесплатно, поэтому десятки одновременных голосов не нагружают процессор. Режимы сжатия WAV: PCM (без сжатия), IMA ADPCM (немного меньше, заметная потеря качества) и **Quite OK Audio** (QOA). QOA стоит по умолчанию с 4.3 ([PR #91014](https://github.com/godotengine/godot/pull/91014)): сжатие заметно сильнее, качество почти не страдает, CPU чуть выше. Проверено на 4.7.2: `compress/mode=2` (QOA) по умолчанию, 1 секунда моно 16 бит 22 кГц ужалась с 44 КБ до 9,3 КБ, `AudioStreamWAV.format = 3` (QOA).
- Параметры WAV (значения по умолчанию проверены на 4.7.2): `force/mono` (вдвое меньше; для позиционных 3D-звуков стерео не нужно), `force/max_rate` + `max_rate_hz` (снизить частоту, для многих эффектов хватит 22–32 кГц), `edit/trim` (срезать тишину ниже −50 dB с фейдом 500 сэмплов), `edit/normalize`. `force/8_bit` ухудшает звук, не используйте.
- Петли. WAV поддерживает Forward, Ping-Pong и Backward с точками начала и конца в сэмплах, а также «Detect from WAV» (по умолчанию, берёт метки из файла). У Ogg и MP3 есть только `loop` и `loop_offset` в секундах: точки конца нет. Зацикленный поток никогда не испускает `finished`, не ждите его. BPM, Beat Count и Bar Beats у Ogg и MP3 движок пока не использует. Переходы между треками делают `AudioStreamInteractive`, `AudioStreamPlaylist` и `AudioStreamSynchronized` (с 4.3) [не проверено на 4.7.2].
- С 4.4 WAV, как и Ogg, можно загрузить в рантайме из `user://` (`AudioStreamWAV.load_from_file()`). Это нужно для пользовательского контента.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Importing audio samples](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_audio_samples.html) | документация Godot, 4.7 | Выбор формата, QOA, петли, параметры WAV |
| [PR #96174 названия режимов WAV](https://github.com/godotengine/godot/pull/96174) | GitHub, 2024 | Что значат режимы сжатия и петель |
| [ResourceImporterWAV](https://docs.godotengine.org/en/stable/classes/class_resourceimporterwav.html) | справочник API | Все параметры `.import` для WAV |

## 3D-сцены

### Ключевые выводы

- **Формат.** Рекомендуемый формат — glTF 2.0. `.glb` компактнее и хранит текстуры внутри. `.gltf` + `.bin` + отдельные текстуры удобнее для контроля версий и для общих текстур. `.blend` импортируется напрямую: Godot сам вызывает экспорт glTF в Blender. Нужен Blender 3.0+ (рекомендуется 3.5+), официальная сборка с blender.org, а не пакет дистрибутива или Flatpak, и Blender должен стоять у **каждого** в команде и в CI. FBX с 4.3 импортируется встроенным ufbx (в 4.7.2 ufbx 0.23, [PR #122589](https://github.com/godotengine/godot/pull/122589)). FBX2glTF не рекомендуется. Collada устарел, OBJ не поддерживает скиннинг, анимацию и UV2.
- **Основные настройки** (`ResourceImporterScene`, значения по умолчанию по справочнику): `meshes/generate_lods = true` (автоматические LOD, улучшены в 4.6), `meshes/create_shadow_meshes = true`, `meshes/light_baking` (Static Lightmaps генерирует UV2), `meshes/ensure_tangents` (нужны для normal map), `meshes/force_disable_compression = false` (включите, если видите ступеньки в нормалях или UV), `animation/fps` (документация: «not much benefit in going above 30 FPS»), `animation/remove_immutable_tracks = true`, `nodes/root_type`, `nodes/apply_root_scale`.
- **Advanced Import Settings** (двойной клик по файлу). Для каждого меша там настраиваются коллизия (Physics: Static/Dynamic/Area; Trimesh только для Static, для подвижных тел convex decomposition или примитивы), NavMesh, Occluder, сохранение меша в файл (`.res`), переопределение LOD и `normal merge angle`. Для анимаций там есть оптимизатор («should always be turned on»), сохранение в файл и нарезка (slices) одной дорожки на клипы.
- **Материалы.** Actions > Extract Materials сохраняет материалы во внешние `.tres` (`materials/extract`: 0 — внутри, 1 — извлечь один раз, 2 — перезаписывать при каждом импорте). Реимпорт ваши правки не затрёт, но если переименовать материал в исходнике, связь порвётся, и назначать его придётся заново. Альтернатива — назначить в Advanced Import готовые материалы проекта.
- **Суффиксы имён** в DCC-программе (регистр неважен, разделители `-`, `_`, `$`):

| Суффикс | Результат |
|---|---|
| `-noimp` | Узел или анимация не импортируются |
| `-col` / `-convcol` | Меш + дочерняя статическая коллизия: trimesh / convex |
| `-colonly` / `-convcolonly` | Только `StaticBody3D` с коллизией, меш удаляется (у пустышек Blender форма берётся из типа отображения) |
| `-rigid` | `RigidBody3D` |
| `-navmesh` | Меш превращается в навигационную сетку |
| `-occ` / `-occonly` | `OccluderInstance3D` вместе с мешем / вместо меша |
| `-vehicle` / `-wheel` | `VehicleBody3D` / `VehicleWheel3D` |
| `-loop` / `-cycle` | Анимация импортируется зацикленной |
| `-alpha` / `-vcol` | Материал с прозрачностью / с цветом вершин |

- Отключить разбор суффиксов: `nodes/use_node_type_suffixes = false` (остаются `-noimp`, `-loop`, `-vcol`) или `nodes/use_name_suffixes = false`.
- **Скрипт после импорта.** `import_script/path` → `@tool extends EditorScenePostImport` с `_post_import(scene)`, который **обязан вернуть** сцену. Здесь назначают слои коллизий, группы, скрипты и метаданные из custom properties. Для логики на весь проект (по всем импортам, с собственными опциями в доке) есть `EditorScenePostImportPlugin`.
- **Правка импортированной сцены.** Документация советует «modifying the original data should be preferred to configuring the scene after import». Наследуемая сцена (New Inherited Scene) позволяет добавлять узлы, но не удалять базовые и не править подресурсы. Обычный приём: инстанцировать импортированную модель внутри своей сцены (`Enemy.tscn` → дочерний `model.glb`) и держать логику там. Реимпорт модели такую сцену не ломает.
- **Анимации и ретаргетинг.** Чтобы делить анимации между моделями: Retarget > `bone_map` с `SkeletonProfileHumanoid` (автосопоставление по английским именам костей), Remove Tracks (Except Bone Transform, Unimportant Positions, Unmapped Bones), Rest Fixer (Overwrite Axis выравнивает rest-позы, Fix Silhouette нужен для A-позы), уникальное имя скелета. Анимационный файл импортируйте как `AnimationLibrary`. `nodes/import_as_skeleton_bones` превращает иерархию узлов в кости одного `Skeleton3D`, `animation/import_rest_as_RESET` создаёт анимацию `RESET`.

```gdscript
# res://tools/import/level_post_import.gd: подключается в import_script/path
@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	for node in scene.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		body.collision_layer = 1 << 0          # слой "world"
		body.add_to_group(&"walkable", true)   # persistent = сохранится в сцене
	return scene                               # без return импорт отдаст пустоту
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Available 3D formats](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html) | документация Godot, 4.7 | glTF, `.blend`, ufbx, ограничения OBJ/Collada |
| [Import configuration](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html) | документация Godot, живой | Настройки дока Import, скрипт импорта, наследование |
| [Node type customization](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html) | документация Godot, живой | Полный список суффиксов |
| [Retargeting 3D skeletons](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html) | документация Godot, живой | BoneMap, Rest Fixer, общие AnimationLibrary |
| [ResourceImporterScene](https://docs.godotengine.org/en/stable/classes/class_resourceimporterscene.html) | справочник API, 4.7 | Все параметры и значения по умолчанию |
| [EditorScenePostImport](https://docs.godotengine.org/en/stable/classes/class_editorscenepostimport.html) | справочник API | `_post_import`, `get_source_file` |
| [Godot 4.3 release](https://godotengine.org/releases/4.3/) | Godot Foundation, 2024 | Встроенный FBX (ufbx), опции ретаргетинга |

## Шрифты

### Ключевые выводы

- Динамические шрифты (TTF, OTF, WOFF, WOFF2) — выбор по умолчанию: масштабируются, поддерживают лигатуры и fallback. Растровые шрифты (BMFont `.fnt` или картинка) имеют фиксированный размер.
- **MSDF** (`multichannel_signed_distance_field` в импорте) рисует текст любого размера без перерастеризации. Он хорош для крупных, анимируемых по масштабу заголовков и текста в 3D. Минусы: базовая стоимость выше (заметно на слабых мобильных), мелкий текст мутнее (нет хинтинга), нет LCD-сглаживания. `msdf_pixel_range` ставьте не меньше удвоенной толщины обводки, иначе обводка обрежется. Шрифты с самопересекающимися контурами в MSDF рисуются неправильно.
- Для игр антиалиасинг Grayscale (по умолчанию). Хинтинг Light (по умолчанию), Full даёт самый резкий мелкий текст. Подпиксельное позиционирование Auto, а для пиксельных шрифтов **Disabled**. Размер у пиксельного шрифта кратен его «родному» размеру.
- Fallback-шрифты добавляют глифы, которых нет в основном шрифте: кириллицу к латинскому шрифту, CJK, эмодзи. Проверьте, что выбранный шрифт покрывает русский, или добавьте fallback.
- Первое появление глифа растеризуется на лету, и на большом размере это даёт микрофриз. В Advanced Import Settings шрифта есть **pre-render configurations**: глифы заранее растеризуются по тексту переводов, по своему тексту или по наборам символов.
- Системные шрифты (`SystemFont`) не попадают в сборку и уменьшают её, но на Android работают ненадёжно, а результат на Linux зависит от дистрибутива.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Using Fonts](https://docs.godotengine.org/en/stable/tutorials/ui/gui_using_fonts.html) | документация Godot, 4.7 | MSDF, хинтинг, пиксельные шрифты, fallback, pre-render |
| [ResourceImporterDynamicFont](https://docs.godotengine.org/en/stable/classes/class_resourceimporterdynamicfont.html) | справочник API | Все параметры импорта шрифта |

## Переводы

### Ключевые выводы

- CSV: первая колонка — ключи (регистр важен, ключи уникальны), дальше по колонке на локаль (`en`, `ru`). Колонки, имя которых начинается с `_`, — комментарии. С 4.6 появились колонки `?plural` (формы множественного числа, строка `?pluralrule`) и `?context` (контекст для одинаковых строк), но их переводят только явным `tr_n()`/`tr()`, автоперевод `Control` их не видит.
- Импорт CSV создаёт рядом бинарные `*.translation` на каждую локаль. Их не коммитят: они генерируются (см. `.gitignore` в [architecture.md](architecture.md#контроль-версий)). Параметры импорта: сжатие и разделитель. Импортированный CSV **не регистрируется автоматически**: добавьте `.translation` в Project Settings > Localization > Translations.
- Для больших проектов и переводчиков с инструментами (Poedit, Weblate) удобнее gettext `.po`: контекст, множественные формы и комментарии там стандартные. Шаблон `.pot` генерирует редактор.
- Переключение языка и `tr()` в коде описаны в [architecture.md](architecture.md#локализация-и-ввод).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Localization using spreadsheets](https://docs.godotengine.org/en/stable/tutorials/i18n/localization_using_spreadsheets.html) | документация Godot, 4.7 | Формат CSV, `?plural`, `?context`, регистрация |
| [Localization using gettext](https://docs.godotengine.org/en/stable/tutorials/i18n/localization_using_gettext.html) | документация Godot, живой | PO/POT |
| [Importing translations](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_translations.html) | документация Godot, живой | Обзор и выбор формата |

## Свои импортёры

### Ключевые выводы

- `EditorImportPlugin` превращает свой формат (таблица баланса `.csv`, уровень из Tiled/LDtk, диалоги `.yarn`) в ресурс Godot при импорте. Исходник остаётся в репозитории, результат лежит в `.godot/imported`, и игра делает обычный `load("res://data/items.csv")`. Плюсы перед `EditorScript`-генератором: автоматический реимпорт при изменении файла и настройки в доке Import.
- Обязательные методы: `_get_importer_name()` (уникальный id), `_get_visible_name()`, `_get_recognized_extensions()`, `_get_save_extension()`, `_get_resource_type()`, `_get_preset_count()`/`_get_preset_name()`, `_get_import_options()` (возвращайте массив, даже пустой), `_get_option_visibility()`, `_import()`. Для порядка относительно других импортёров есть `_get_priority()` и `_get_import_order()` [не проверено на 4.7.2].
- `_import()` получает `save_path` **без расширения**. Сохраняйте в `"%s.%s" % [save_path, _get_save_extension()]` и возвращайте результат `ResourceSaver.save()`.
- Регистрация: в `EditorPlugin._enter_tree()` вызовите `add_import_plugin(plugin)`, в `_exit_tree()` вызовите `remove_import_plugin(plugin)`. Плагин включается в Project Settings > Plugins, и в CI он тоже должен быть включён, иначе `--import` не узнает формат.

```gdscript
# addons/items_csv/items_csv_importer.gd
@tool
extends EditorImportPlugin

func _get_importer_name() -> String: return "game.items_csv"
func _get_visible_name() -> String: return "Item Table"
func _get_recognized_extensions() -> PackedStringArray: return ["items.csv"]  # отличаем от CSV переводов
func _get_save_extension() -> String: return "res"
func _get_resource_type() -> String: return "Resource"
func _get_preset_count() -> int: return 1
func _get_preset_name(_i: int) -> String: return "Default"
func _get_import_options(_p: String, _i: int) -> Array[Dictionary]: return []
func _get_option_visibility(_p: String, _o: StringName, _opts: Dictionary) -> bool: return true
func _get_priority() -> float: return 2.0   # выше стандартного CSV-импортёра переводов

func _import(source: String, save_path: String, _opts: Dictionary,
		_variants: Array[String], _gen: Array[String]) -> Error:
	var file := FileAccess.open(source, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var table := ItemTable.new()                    # свой Resource с Array[ItemData]
	file.get_csv_line()                             # заголовок
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() >= 3:
			table.add_row(StringName(row[0]), row[1], int(row[2]))
	return ResourceSaver.save(table, "%s.%s" % [save_path, _get_save_extension()])
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Import plugins](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/import_plugins.html) | документация Godot, живой | Пошаговый пример импортёра |
| [EditorImportPlugin](https://docs.godotengine.org/en/stable/classes/class_editorimportplugin.html) | справочник API | Все виртуальные методы, `append_import_external_resource` |

## Импорт в CI и фильтры экспорта

### Ключевые выводы

- На чистом клоне `.godot/` нет, и первым шагом идёт `godot --headless --path . --import` («Starts the editor, waits for any resources to be imported, and then quits», из `--help` 4.7.2). Он создаёт кэш импорта, `global_script_class_cache.cfg` и `.uid`. Код возврата у него не показатель успеха. Подробности, кэширование `.godot/` по хешу `*.import` и GitHub Actions описаны в [toolchain.md](toolchain.md).
- Импорт в CI должен видеть те же инструменты, что и у разработчика: Blender для `.blend` (иначе модели не импортируются), включённые плагины-импортёры, те же Import Defaults в `project.godot`. Иначе CI соберёт игру без части ассетов, и ошибка вылезет только в рантайме.
- Импорт ресурсоёмкий: VRAM-сжатие и Basis на сотнях текстур занимают минуты. Кэшируйте `.godot/imported`. Для мобильных сборок проверьте, что ETC2/ASTC включены до импорта, иначе экспорт упадёт.
- Экспорт, вкладка Resources: «Export all resources», «selected scenes (and dependencies)», «selected resources», «all except selected», «dedicated server» (визуальные ресурсы заменяются заглушками). Два фильтра: включить файлы, которые не ресурсы (`*.txt`; `.json` в 4.x фильтра не требует), и исключить по маске (`*.psd, docs/*`). Кроме того, есть «Keep File» и «Skip File» на уровне импортёра и `.gdignore` на уровне папки.
- Патчи: `--export-patch` с `--patches` (с 4.6 дельта-кодирование: в патч попадают только изменённые части ресурсов), `--export-pack` для DLC и модов (см. [architecture.md](architecture.md#моды-и-загружаемые-пакеты)).

```bash
godot --headless --path . --import                                   # 1. импорт ассетов
godot --headless --path . --export-release "Android" build/game.apk  # 2. экспорт пресета
godot --headless --path . --export-pack "DLC1" build/dlc1.pck         # данные без движка
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Command line tutorial](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html) | документация Godot, живой | `--import`, `--export-*` |
| [Exporting projects](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html) | документация Godot, живой | Режимы ресурсов и фильтры |
| [Class cache в CI](https://forum.godotengine.org/t/importing-a-class-in-singleton-does-not-work-in-ci/38781) | форум Godot, 2023 | Почему без `--import` не находятся `class_name` |
| [GUT #491](https://github.com/bitwes/Gut/issues/491) | GitHub | Ошибки «Could not find type» в CI |

## Бюджеты размера и памяти

### Ключевые выводы

- Считайте видеопамять, а не размер файла. Несжатая RGBA8-текстура весит `ширина × высота × 4` байт, плюс треть на mipmap. 2048² — это 16 МБ (21 МБ с mipmap) независимо от того, сколько весит PNG. DXT1/ETC2 RGB занимает 0,5 байта на пиксель, BC7/ASTC 4×4 и DXT5 занимают 1 байт.
- Ориентиры для мобильных [не проверено: практика сообщества, не официальные лимиты]: текстуры персонажей 1024², окружение 512–1024², ни одной текстуры больше 4096 (жёсткий лимит многих GPU и Web), общий бюджет текстур в сотни мегабайт, а не гигабайты. Удобный рычаг — `process/size_limit` в пресете для мобильной ветки.
- Аудио: музыка в Ogg 96–160 кбит/с, эффекты в WAV/QOA моно 22–44 кГц. Длинные WAV-петли с PCM съедают память: их или в QOA, или в Ogg.
- 3D: включённые LOD и shadow meshes почти бесплатны по памяти и экономят GPU. `animation/fps` 30 и оптимизатор анимаций уменьшают размер библиотек. Удаляйте неиспользуемые UV2 и цвета вершин в DCC-программе.
- Смотрите на фактические цифры: Debugger > Video RAM (список текстур и их размер в видеопамяти), монитор `RENDER_TEXTURE_MEM_USED`, отчёт Export > «Export with debug» и размер PCK. Сравнивайте размер `.godot/imported` по папкам.
- Сборка для Web: размер скачивания критичен. Lossy для 2D, Basis Universal для 3D, Ogg для музыки, урезанный набор шрифтов (без огромных CJK, если они не нужны).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [GPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html) | документация Godot, живой | Текстуры, fill rate, пропускная способность памяти |

## Контроль версий ассетов

### Ключевые выводы

- Что коммитить: исходники ассетов (`.png`, `.wav`, `.glb`, `.blend`, `.ttf`), их `.import`, `.uid`, `.tscn`/`.tres`, `project.godot`, `export_presets.cfg`. Что не коммитить: `.godot/`, `*.translation`, `export_credentials.cfg`. Готовые `.gitignore` и `.gitattributes` создаёт Project > Version Control > Generate Version Control Metadata. Подробности в [architecture.md](architecture.md#контроль-версий) и [toolchain.md](toolchain.md).
- Git LFS включайте **до первого коммита** ассетов. Иначе файлы придётся удалить и добавить заново или переписать историю `git lfs migrate`. Пример `.gitattributes` из документации отправляет в LFS модели (`fbx`, `gltf`, `glb`, `blend`, `obj`), изображения, аудио, шрифты и бинарные `.scn`/`.res`. LFS нужен на каждой машине и в CI (`actions/checkout` с `lfs: true`).
- Если используете `.blend` напрямую, экспортированные `.glb` коммитить не нужно. Но тогда Blender нужен всем, включая CI. Компромисс: коммитить `.glb`, а `.blend` хранить в папке с `.gdignore` (тоже под LFS).
- Исходники художников (`.psd`, `.kra`, `.aseprite`) держите либо вне `res://`, либо в папке с `.gdignore`, чтобы Godot их не сканировал и не тащил в экспорт. Aseprite-файлы можно импортировать напрямую плагином-импортёром.
- Бинарные `.res` и `.scn` не сливаются вообще, поэтому для часто правящихся ресурсов текст лучше. Крупные меши и анимации в `.res` правят только через реимпорт исходника, конфликты по ним разрешаются выбором одной из версий.
- Держите `.import` в репозитории в согласованном состоянии: если художник сменил режим сжатия локально и не закоммитил `.import`, у остальных будет другой результат.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Version control systems](https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html) | документация Godot, 4.7 | `.gitignore`, `.gitattributes` с LFS, когда включать LFS |
| [Godot.gitignore](https://github.com/github/gitignore/blob/main/Godot.gitignore) | GitHub, живой | Шаблон игнорирования |

## Антипаттерны

| Антипаттерн | Почему плохо | Замена |
|---|---|---|
| Правка общего ресурса у одного экземпляра (`material.albedo_color = …`) | Меняется у всех, кто его загрузил | `duplicate_deep()` в `_ready`, `resource_local_to_scene`, instance uniform |
| `duplicate()` без аргументов для ресурса с массивами | Массив остаётся тем же объектом, `append` портит оригинал | `duplicate(true)` или `duplicate_deep()` |
| Надежда на `local_to_scene` при `Node.duplicate()` | Ресурс остаётся общим (#117636) | Инстанцировать сцену заново или копировать ресурс вручную |
| `FileAccess`/`Image.load_from_file` для `res://*.png` | В экспорте исходника нет | `load()` импортированного ресурса |
| `.txt`/`.yaml` без фильтра экспорта или CSV с данными, импортированный как перевод | Файл пропадает в сборке | Фильтр «non-resource files», для CSV — импортёр «Keep File» или свой импортёр (`.json` в 4.x экспортируется сам) |
| `load("res://Player.png")` при файле `player.png` | Работает на Windows, падает в PCK | `snake_case` везде, копировать пути из дока FileSystem |
| Перенос файлов в проводнике без `.uid`/`.import` | Потерянные зависимости, новые UID, шумные диффы | Перенос в доке FileSystem |
| `.uid` или `.import` в `.gitignore` | Ссылки ломаются на других машинах, настройки импорта теряются | Коммитить оба |
| VRAM Compressed для 2D-спрайтов и пиксель-арта | Блочные артефакты | Lossless или Lossy |
| Lossless для всех 3D-текстур | Видеопамять в 4–8 раз больше | VRAM Compressed + mipmap |
| 3D без mipmap | Муар, мерцание, промахи кэша GPU | `mipmaps/generate = true` |
| Мобильная сборка без Import ETC2 ASTC | Экспорт падает или текстуры без сжатия | Включить и реимпортировать |
| Текстуры 8192² «на всякий случай» | Не отобразятся на мобильных и Web, съедят память | `process/size_limit`, разумные исходники |
| `ImageTexture` или меш в `.tres` | Мегабайты текста, медленная загрузка | Исходник с импортом или `.res` |
| Музыка в WAV PCM | Десятки мегабайт | Ogg Vorbis, у эффектов QOA |
| Ожидание `finished` у зацикленного звука | Сигнал не придёт никогда | Своя логика остановки |
| Trimesh-коллизия (`-col`) у подвижного тела | Работает только для Static | `-convcol`, примитивы, convex decomposition |
| Правка импортированной сцены вместо исходника | Реимпорт затрёт или сломает правки | Править исходник, скрипт `_post_import`, обёртка-сцена |
| `_post_import` без `return scene` | Импорт отдаёт пустоту | Всегда возвращать сцену |
| `.blend` в проекте без Blender в CI | Модели не импортируются на сервере | Blender в CI или коммит `.glb` |
| Ассеты в репозитории до настройки LFS | Раздутая история навсегда | LFS до первого коммита |
| `preload` огромных уровней в автозагрузке | Долгий старт, всё в памяти | `load_threaded_request` по требованию |
| `CACHE_MODE_IGNORE` как способ «перечитать файл для всех» | Создаётся новый объект, старые ссылки не обновятся | `CACHE_MODE_REPLACE` |
| `.tres` из `user://` или от игроков | Встроенный скрипт выполнится | JSON и своя сборка ресурсов |

## Чеклист импорта и ресурсов

1. В новом проекте сразу настроены Import Defaults: 2D-текстуры Lossless без mipmap (или «2D Pixel»), шрифты с нужным хинтингом. Для пиксельной игры `Default Texture Filter = Nearest`, масштаб окна целочисленный.
2. В 3D-текстурах включены VRAM Compressed и mipmap. Детали с видимыми блоками переведены на High Quality. Карты нормалей импортированы как normal map, DirectX-карты с `normal_map_invert_y`.
3. Ни одна текстура не превышает 4096 по длинной стороне, для мобильных задан `size_limit`.
4. Для Android/iOS/Web включён Import ETC2 ASTC, проект реимпортирован.
5. Пиксель-арт на 3D-объектах защищён от Detect 3D (`compress_to` = Disabled).
6. Спрайты, которые рисуются вместе, лежат в атласе или TileSet-атласе, с отступами между кадрами.
7. SVG-иконки UI под разные DPI импортированы как `DPITexture`, текст в SVG переведён в кривые.
8. Короткие эффекты лежат в WAV (QOA, моно для позиционных), музыка и речь в Ogg Vorbis.
9. Петли настроены в импорте (`loop`, `loop_offset` или точки WAV), и код не ждёт `finished` от зацикленных звуков.
10. 3D-модели в glTF 2.0 (`.glb` или `.gltf` + текстуры). Если используется `.blend`, путь к Blender настроен у всех и в CI.
11. Коллизии, навмеши и окклюдеры заданы суффиксами или в Advanced Import, trimesh только у статики.
12. Материалы извлечены во внешние `.tres` или назначены материалы проекта. После переименования в DCC связи проверены.
13. Повторяющаяся постобработка импорта вынесена в `EditorScenePostImport`, а не делается руками после каждого реимпорта.
14. Общие анимации идут через `AnimationLibrary` с BoneMap и Rest Fixer.
15. Шрифт покрывает кириллицу или подключён fallback. Для крупных заголовков MSDF, для пиксельных шрифтов subpixel = Disabled.
16. CSV-переводы зарегистрированы в Localization, `*.translation` в `.gitignore`.
17. Изменяемое состояние не хранится в общих ресурсах. Где нужно, используются `duplicate_deep()` или `local_to_scene`, и известно, что `Node.duplicate()` их не размножает.
18. `duplicate()` без аргументов не применяется к ресурсам с массивами и словарями.
19. Повторно используемые ресурсы внешние (`.tres`), одноразовые встроенные. Меши и анимации, сохранённые из импорта, лежат в `.res`. Текстуры не хранятся как `ImageTexture` в `.tres`.
20. Ссылки на ресурсы не набраны строкой вручную: используются `@export` или UID (`preload("uid://…")`).
21. Файлы перемещаются только в доке FileSystem. После обновления версии прогнан Upgrade Project Files. `.import` и `.uid` закоммичены, `.godot/` игнорируется.
22. Git LFS настроен до первого коммита ассетов и включён в CI.
23. Исходники художников лежат в папках с `.gdignore` или вне проекта.
24. Нересурсные файлы (`.txt`, `.yaml`, свои форматы) добавлены в фильтр экспорта, CSV с данными переключён на «Keep File», лишнее исключено фильтром.
25. Имена файлов в `snake_case`, пути в коде совпадают по регистру. Импортированные ассеты читаются через `load()`, а не через `FileAccess`.
26. В CI первым шагом идёт `--import`, `.godot/imported` кэшируется, плагины-импортёры включены в `project.godot`.
27. Тяжёлые сцены грузятся через `load_threaded_request`, без `preload` в автозагрузках. На 4.7 `use_sub_threads` проверен на сценах с TileMap.
28. Видеопамять проверена в Debugger > Video RAM на целевом устройстве, а не только на десктопе.

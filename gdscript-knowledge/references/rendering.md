# Рендеринг 2D и 3D: правильное использование движка

Справочник о том, как правильно использовать рендерер Godot 4. Он помогает выбрать рендерер и драйвер, выстроить порядок отрисовки в 2D, не ломать батчинг, настроить свет, тени, GI, окружение, материалы, вьюпорты и камеры. Здесь же описано, как убрать рывки компиляции шейдеров и чем отлаживать кадр. Общие техники оптимизации (MultiMesh, серверы, профилирование GDScript) описаны в [performance.md](performance.md#рендеринг-батчинг-multimesh-серверы-шейдеры), обзор доменов 2D, 3D и шейдеров — в [domains.md](domains.md). Здесь они не повторяются, только даны ссылки. Растяжение окна со стороны UI (темы, якоря, контейнеры) описано в справочнике по UI, здесь — только сторона рендеринга. Актуально на октябрь 2026 года, Godot 4.7.2 (stable). 4.8 пока в стадии dev-снапшотов.

Метки: `[устарело]` — совет эпохи Godot 3 (GLES2/GLES3, `VisualServer`, старые узлы) или ранних 4.x, рядом указана замена; `[не проверено]` — утверждение из вторичного источника или без собственного замера; «(проверено на 4.7.2)» — значение прочитано скриптом или замерено в окне на Godot 4.7.2 (Windows 11, RTX 4070 SUPER, Vulkan 1.4 / D3D12 / OpenGL 3.3).

- [Выбор рендерера и драйвера](#выбор-рендерера-и-драйвера)
- [Замеры: что батчится и инстансируется](#замеры-что-батчится-и-инстансируется)
- [2D: порядок отрисовки](#2d-порядок-отрисовки)
- [2D: батчинг и свой _draw](#2d-батчинг-и-свой-_draw)
- [2D: свет, тени и карты нормалей](#2d-свет-тени-и-карты-нормалей)
- [2D: CanvasGroup, маски и чтение экрана](#2d-canvasgroup-маски-и-чтение-экрана)
- [2D: фильтрация, пиксель-арт и сглаживание](#2d-фильтрация-пиксель-арт-и-сглаживание)
- [Параллакс и камеры](#параллакс-и-камеры)
- [Плавность движения: интерполяция физики](#плавность-движения-интерполяция-физики)
- [Viewports, масштабирование 3D и сглаживание](#viewports-масштабирование-3d-и-сглаживание)
- [3D: источники света и тени](#3d-источники-света-и-тени)
- [3D: глобальное освещение](#3d-глобальное-освещение)
- [3D: Environment, CameraAttributes и пост-обработка](#3d-environment-cameraattributes-и-пост-обработка)
- [3D: материалы и прозрачность](#3d-материалы-и-прозрачность)
- [3D: LOD, отсечение, частицы, декали, небо](#3d-lod-отсечение-частицы-декали-небо)
- [Рывки компиляции шейдеров и кэш пайплайнов](#рывки-компиляции-шейдеров-и-кэш-пайплайнов)
- [Отладка рендеринга](#отладка-рендеринга)
- [Антипаттерны](#антипаттерны)
- [Чеклист рендеринга сцены](#чеклист-рендеринга-сцены)

---

## Выбор рендерера и драйвера

### Ключевые выводы

- В Godot 4 три рендерера (rendering method): **Forward+** (`forward_plus`, по умолчанию на десктопе), **Mobile** (`mobile`, по умолчанию на мобильных) и **Compatibility** (`gl_compatibility`, единственный для Web). Значения по умолчанию: `rendering/renderer/rendering_method = forward_plus`, `.mobile = mobile`, `.web = gl_compatibility` (проверено на 4.7.2). Переопределения `.mobile` и `.web` позволяют одному проекту иметь разные рендереры под платформы.
- Forward+ и Mobile работают поверх абстракции **RenderingDevice** с бэкендами Vulkan, Direct3D 12 и Metal. Compatibility работает на OpenGL 3.3 / OpenGL ES 3.0 / WebGL 2, на Windows и macOS он может работать через ANGLE (`opengl3_angle`) ([Overview of renderers](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)).
- Драйверы по умолчанию (проверено на 4.7.2): `driver.windows = vulkan` (допустимы `vulkan`, `d3d12`), `driver.macos/.ios/.visionos = metal`, `driver.linuxbsd/.android = vulkan`. Начиная с 4.6 **новые** проекты на Windows получают D3D12 ([PR #113213](https://github.com/godotengine/godot/pull/113213)). Это значение записывает Project Manager, а значение по умолчанию в самих настройках осталось `vulkan`. Проверено на 4.7.2: проект с пустым или написанным вручную `project.godot` (CI, генераторы) запускается на Vulkan. У D3D12 нет VRS и foveated rendering, а это важно для PCVR.
- Fallback (с 4.4): если нет Vulkan, движок пробует D3D12, и наоборот (`fallback_to_vulkan`, `fallback_to_d3d12` = true). Если не работает ни один RD-бэкенд, движок откатывается на Compatibility (`gl_compatibility/fallback_to_angle` и `fallback_to_native` = true). Откат меняет набор фич, поэтому игра должна это проверять (сниппет ниже).
- Metal (4.4) — собственный бэкенд для Apple Silicon, на Intel-маках по-прежнему работает MoltenVK ([4.4 dev 1](https://godotengine.org/article/dev-snapshot-godot-4-4-dev-1/)). По словам разработчиков, он не медленнее Vulkan, а часто быстрее.
- Смена рендерера посреди проекта стоит дорого: освещение, окружение и материалы придётся перенастраивать. Переход между Forward+ и Mobile даётся легче, чем любой переход в Compatibility или из него. Решайте до создания уровней.
- `GLES2`/`GLES3`-рендереры Godot 3 и совет «для слабого железа берите GLES2» `[устарело]` → Compatibility. Настройки `rendering/quality/*` и `rendering/batching/*` из Godot 3 `[устарело]`.

### Какой рендерер

| Ситуация | Рендерер | Почему |
|---|---|---|
| Web-экспорт | Compatibility | Единственный вариант (WebGL 2); WebGPU — пока только предложение в [priorities](https://godotengine.org/priorities/) |
| 2D-игра для любого железа | Compatibility или Mobile | 2D-батчинг есть во всех трёх (Forward+/Mobile — с 4.4); Mobile даёт MSAA 2D и HDR 2D |
| 3D на телефонах (Vulkan) | Mobile | Тайловые GPU, F16 (4.5), отключён depth prepass для Mali/Adreno/PowerVR/Apple |
| Очень старые телефоны / встроенная графика без Vulkan | Compatibility | OpenGL ES 3.0; меньше фич, но работает |
| 3D для ПК и консолей с современным светом | Forward+ | SDFGI, VoxelGI, SSIL, SSR, объёмный туман, TAA, FSR2, авто-экспозиция |
| Автономные VR-шлемы (Quest) | Mobile | В 4.7 Mobile рекомендован для XR, subsampled images для foveated |
| PCVR | Forward+ или Mobile на Vulkan | D3D12 без VRS/foveated (PR #113213) |
| Стилизованное 3D low-poly для широкого охвата | Mobile, запасной путь — Compatibility | LightmapGI и ReflectionProbe работают во всех |

| Фича | Forward+ | Mobile | Compatibility |
|---|---|---|---|
| VoxelGI, SDFGI, SSIL, SSR, объёмный туман, TAA, FSR2, SSS, auto exposure | да | нет | нет |
| SSAO | да | нет | упрощённый (с 4.6) |
| LightmapGI (рендер) / ReflectionProbe | да / без лимита на меш | да / 8 на меш | да / 2 на меш |
| MSAA 3D | да | да | да |
| MSAA 2D, FXAA, SMAA, декали, трейлы частиц, HDR 2D, HDR-вывод | да | да | нет |
| Omni/Spot на меш | 512 кластерных элементов на вид | 8+8 на меш, 256+256 на вид | 8+8 на меш (настраивается) |
| Compute-шейдеры | да | да (медленнее на старых устройствах) | нет |
| Точность цвета / глубины | RGBA16F / 32 бит reverse-Z | RGB10A2 или RGBA16F / 24 бит reverse-Z | RGBA8 / 24 бит |

```gdscript
# autoload/graphics.gd — подстроить качество под фактический рендерер (учитывая fallback)
func _ready() -> void:
	var method := RenderingServer.get_current_rendering_method()  # "forward_plus" | "mobile" | "gl_compatibility"
	var driver := RenderingServer.get_current_rendering_driver_name()  # "vulkan" | "d3d12" | "metal" | "opengl3" | "opengl3_angle"
	print("GPU: %s, %s/%s" % [RenderingServer.get_video_adapter_name(), method, driver])
	if method != "forward_plus":
		_disable_forward_plus_only_effects()  # SDFGI, SSR, объёмный туман и т. д. молча не работают

func _disable_forward_plus_only_effects() -> void:
	var env := get_viewport().world_3d.environment if get_viewport().world_3d else null
	if env:
		env.sdfgi_enabled = false
		env.ssr_enabled = false
		env.volumetric_fog_enabled = false
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Overview of renderers](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html) | документация Godot, 4.7 | Полная таблица фич и лимитов, fallback |
| [PR #113213: D3D12 default for new projects](https://github.com/godotengine/godot/pull/113213) | Godot, 2025 | Почему D3D12 стоит только в новых проектах и где его нет |
| [Dev snapshot 4.4 dev 1](https://godotengine.org/article/dev-snapshot-godot-4-4-dev-1/) | Godot Foundation, 2024 | Появление Metal-бэкенда |
| [Godot 4.4 release](https://godotengine.org/releases/4.4/) | Godot Foundation, 2025 | Ubershaders, 2D-батчинг в RD, Metal, fallback, AgX, shadowmask |
| [Godot 4.6 release](https://godotengine.org/releases/4.6/) | Godot Foundation, 2026 | D3D12 по умолчанию, SSR, glow до тонмаппинга, октаэдрические пробы |
| [Godot 4.7 release](https://godotengine.org/releases/4.7/) | Godot Foundation, 2026 | AreaLight3D, HDR-вывод, nearest-масштабирование, DrawableTexture2D |
| [Godot Rendering Team Update](https://talks.godotengine.org/godotcon-boston-2026/talk/HSBK39/) | Clay John, GodotCon Boston 2026 | Итоги двух лет и планы рендерера |

---

## Замеры: что батчится и инстансируется

### Ключевые выводы

- Ниже собственные замеры (проверено на 4.7.2): окно 800×600, счётчик `RenderingServer.get_rendering_info(RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)` после 12 кадров. Скрипты лежат в `research_notes/engine_rendering.md`. Числа — вызовы отрисовки, не время кадра.
- **Forward+ сам инстансирует** одинаковые меш и материал, в том числе в проходе теней. **Mobile и Compatibility этого не делают**, поэтому там `MultiMesh` обязателен для массовых объектов.
- 2D-батч рвётся при смене текстуры, материала **или фильтра текстуры** между соседними по порядку отрисовки элементами. Если тех же спрайтов сгруппировать по порядку (дерево или `z_index`), вызовов станет 2 вместо 1000.
- `draw_rect` в `_draw()` батчится, а `draw_circle` — нет: 1000 кругов дают 1000 вызовов во всех рендерерах. На это ещё в 4.4 указывал комментарий к [PR #92797](https://github.com/godotengine/godot/pull/92797).

| Сценарий | Forward+ (Vulkan / D3D12) | Mobile | Compatibility |
|---|---|---|---|
| 1000 `Sprite2D`, одна текстура | 1 | 1 | 1 |
| 1000 `Sprite2D`, две текстуры через одну | 1000 | 1000 | 1000 |
| те же две текстуры, сгруппированы (500 + 500) или разведены по `z_index` | 2 | — | 2 |
| у каждого спрайта свой `ShaderMaterial` (шейдер общий) | 1000 | 1000 | 1000 |
| один общий `ShaderMaterial` на всех | 1 | 1 | 1 |
| общий материал + `instance uniform` на спрайт | 1 | 1 | 1, но только 256 экземпляров получили значение (ошибка «Too many instances using shader instance variables») |
| у каждого спрайта случайный `modulate` | 1 | — | 1000 `[не проверено на других GPU]` |
| `y_sort_enabled`, 1000 спрайтов вперемешку; `PointLight2D` на всех; `CanvasModulate` | 1 | — | 1 |
| 300 `Label` | 1 | — | 1 |
| 1000 `draw_rect` / 1000 `draw_circle` в одном `_draw()` | 1 / 1000 | — | 1 / 1000 |
| 1000 спрайтов, `texture_filter` чередуется NEAREST/LINEAR | 1000 | — | 1000 |
| 3D: 400 `MeshInstance3D`, общий меш и материал | 1 | 400 | 400 |
| 3D: 400 кубов, у каждого свой материал | 400 | 400 | 400 |
| 3D: 400 общих + `DirectionalLight3D` с тенями PSSM 4 | 1 + 6 теневых | 400 + 400 теневых | 1200 |
| 3D: `MultiMeshInstance3D` на 400 | 1 | 1 | 1 |

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [PR #92797: 2D batching for RD renderers](https://github.com/godotengine/godot/pull/92797) | Stuart Carnie, 2024 | Устройство батчинга; TileMap: 573 440 → 36 вызовов |
| [GPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html) | документация Godot | Draw calls, fill rate, тайловые GPU |
| [Optimization using MultiMeshes](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html) | документация Godot | Когда переходить на MultiMesh |

---

## 2D: порядок отрисовки

### Ключевые выводы

- Базовое правило: CanvasItem рисуются в порядке дерева. Родитель рисуется раньше детей, нижний сосед — поверх верхнего. Порядок меняют свойства `CanvasItem` ([CanvasItem](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html)):
  - `z_index` (по умолчанию 0, диапазон −4096…4096, проверено на 4.7.2) — чем больше значение, тем ближе к зрителю. На порядок обработки ввода у `Control` он не влияет;
  - `z_as_relative` (по умолчанию `true`) — итоговый Z складывается с Z родителя;
  - `y_sort_enabled` — дети с большим Y рисуются поверх, но сортировка идёт только внутри одного `z_index`;
  - `show_behind_parent` — узел рисуется позади родителя;
  - `top_level` — узел не наследует трансформацию и рисуется поверх обычных узлов.
- `CanvasLayer` — отдельный слой с собственной трансформацией. Порядок слоёв зависит только от номера `layer` (основная сцена — слой 0, новый `CanvasLayer` — слой 1, проверено на 4.7.2), а не от места в дереве. Используйте его для HUD, паузы, фейдов, фонов. Камера слой не двигает, если не включён `follow_viewport_enabled` ([Canvas layers](https://docs.godotengine.org/en/stable/tutorials/2d/canvas_layers.html)).
- Для скроллинга двигайте `Camera2D` или `Viewport.canvas_transform`, а не корневой узел мира: так дешевле.
- `visibility_layer` и `canvas_cull_mask` у `Viewport` позволяют показывать разные наборы узлов в разных вьюпортах (сплит-скрин, миникарта). Дети маску не наследуют.
- Изометрия и top-down: ставьте `y_sort_enabled` на контейнер и на `TileMapLayer`. Точку сортировки задаёт origin узла, поэтому ставьте origin спрайта у «ног».
- Связь с батчингом: группируйте элементы с одной текстурой рядом по порядку отрисовки. Перестановка в дереве или общий `z_index` дешевле любого «оптимизатора».

```gdscript
# HUD поверх мира, фон позади: слои независимы от дерева
@onready var hud: CanvasLayer = $HUD          # layer = 10
@onready var bg: CanvasLayer = $Background    # layer = -10, follow_viewport_enabled = true

func _ready() -> void:
	$World/Props.y_sort_enabled = true         # Y-сортировка внутри одного z_index
	$World/Shadows.z_index = -1                # тени под персонажами, независимо от дерева
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Canvas layers](https://docs.godotengine.org/en/stable/tutorials/2d/canvas_layers.html) | документация Godot | Слои, HUD, фоны |
| [CanvasItem](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html) | справка по классам | `z_index`, `y_sort_enabled`, `clip_children`, `visibility_layer` |
| [Viewport and canvas transforms](https://docs.godotengine.org/en/stable/tutorials/2d/2d_transforms.html) | документация Godot | Как связаны canvas, слой и экран |

---

## 2D: батчинг и свой _draw

### Ключевые выводы

- 2D-батчинг автоматический во всех рендерерах (в Forward+/Mobile — с 4.4). Буферы настраиваются в `rendering/2d/batching/item_buffer_size = 16384` и `uniform_set_cache_size = 4096` (проверено на 4.7.2). Трогать их нужно только при огромном числе элементов.
- Что сохраняет батч: общая текстура (атлас, `AtlasTexture`, один `SpriteFrames`-лист), общий материал, одинаковые `texture_filter`/`texture_repeat`, `CanvasModulate`, `PointLight2D` (замер выше). Если нужны разные параметры шейдера, используйте `instance uniform` (4.4, батч не ломает) вместо уникальных материалов ([Godot 4.4](https://godotengine.org/releases/4.4/)).
- В Compatibility буфер instance uniform ограничен железом: на тестовой карте только 256 экземпляров получили значение, остальные выдали ошибку (проверено на 4.7.2). Для тысяч объектов передавайте данные через `modulate`/`self_modulate` или `MultiMesh` с `use_custom_data`.
- Что рвёт батч: смена текстуры, материала, режима смешивания, фильтра или повтора, `clip_children`, `CanvasGroup`, `BackBufferCopy` и чтение экрана, а также примитивы `_draw()` вроде `draw_circle` (у `draw_arc` и `draw_polygon` вероятно так же, по комментарию к PR #92797 `[не проверено]`).
- `_draw()` вызывается один раз, результат кэшируется. Перерисовка — через `queue_redraw()` и только когда данные изменились. `update()` `[устарело]` → `queue_redraw()`. Флаг `--debug-canvas-item-redraw` подсвечивает каждый запрос перерисовки (проверено на 4.7.2, `--help`).
- Для множества линий используйте `draw_multiline` (один вызов), для множества кругов — `draw_texture` с текстурой круга или `MultiMeshInstance2D`. Отрицательная ширина линии означает тонкий примитив, который не масштабируется; положительная задаёт настоящую толщину ([Custom drawing in 2D](https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html)).
- Не храните `Texture`/`StyleBox`/`Mesh` для `draw_*` только в локальной переменной: отрисовка происходит после выхода из функции.
- В 4.7 появился `DrawableTexture2D` — рисование прямо в текстуру без трюков с `SubViewport` (класс есть в 4.7.2; методы помечены experimental).

```gdscript
# Сетка из 2000 точек: draw_circle дал бы 2000 вызовов, текстура круга — один батч
const DOT := preload("res://fx/dot_8px.png")
var points: PackedVector2Array

func set_points(p: PackedVector2Array) -> void:
	points = p
	queue_redraw()  # только при изменении данных

func _draw() -> void:
	var half := DOT.get_size() * 0.5
	for p in points:
		draw_texture(DOT, p - half)
```

```glsl
// flash.gdshader — один материал на всех, значение на экземпляр (4.4+)
shader_type canvas_item;
instance uniform float flash : hint_range(0.0, 1.0) = 0.0;
void fragment() { COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash); }
```

```gdscript
enemy_sprite.set_instance_shader_parameter("flash", 1.0)  # батч не ломается
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Custom drawing in 2D](https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html) | документация Godot | `_draw`, кэш, `draw_multiline`, выравнивание линий |
| [PR #92797](https://github.com/godotengine/godot/pull/92797) | Stuart Carnie, 2024 | Батчинг в RD, известные ограничения |
| [CanvasItem shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html) | документация Godot | Встроенные переменные `canvas_item`, light() |

---

## 2D: свет, тени и карты нормалей

### Ключевые выводы

- Без источников света 2D-сцена рисуется без освещения. `CanvasModulate` задаёт «темноту», то есть цвет мест, куда свет не попадает. Без него свет только пересвечивает сцену ([2D lights and shadows](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html)).
- `PointLight2D` светит текстурой, и её размер определяет площадь. Увеличение `texture_scale` делает свет дороже. `DirectionalLight2D` — солнце или луна, `max_distance` отсекает далёкие тени.
- Тени дают `LightOccluder2D`: полигон рисуют вручную, генерируют из `Sprite2D` или берут из слоя `TileMapLayer`. Маски: `light_mask` у объекта, `range_item_cull_mask` и `shadow_item_cull_mask` у света, `occluder_light_mask` у окклюдера. Атлас 2D-теней по умолчанию 2048 (`rendering/2d/shadow_atlas/size`, проверено на 4.7.2).
- Фильтр теней: `NONE` (по умолчанию, проверено на 4.7.2) — самый быстрый, подходит пиксель-арту; `PCF5` мягче; `PCF13` самый дорогой. Используйте мало крупных источников и мало PCF13.
- Карты нормалей и бликов задаются через ресурс `CanvasTexture` (diffuse + normal + specular) на `Sprite2D` и других узлах. `height` у света влияет только на поверхности с нормалями. Старый `normal_map` у `Sprite` `[устарело]`.
- Свет считается в разрешении вьюпорта, поэтому фильтр Nearest не делает освещение пиксельным. Для пиксельного света нужен свой шейдер, который снапит `LIGHT_VERTEX` и `SHADOW_VERTEX` к сетке.
- Короткие вспышки (взрыв, выстрел) дешевле делать аддитивным спрайтом (`CanvasItemMaterial.blend_mode = ADD`), а не `PointLight2D`. Тени и нормали такой спрайт не учитывает.
- `Light2D` в Godot 3 с режимом mask и `Light2D.mode` `[устарело]` → `PointLight2D`/`DirectionalLight2D` и `blend_mode` (Add, Subtract, Mix).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [2D lights and shadows](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html) | документация Godot | Свет, окклюдеры, маски, фильтры, нормали |
| [PointLight2D](https://docs.godotengine.org/en/stable/classes/class_pointlight2d.html) / [LightOccluder2D](https://docs.godotengine.org/en/stable/classes/class_lightoccluder2d.html) | справка по классам | Все свойства |
| [CanvasModulate](https://docs.godotengine.org/en/stable/classes/class_canvasmodulate.html) | справка по классам | Окружающий цвет 2D |

---

## 2D: CanvasGroup, маски и чтение экрана

### Ключевые выводы

- `CanvasGroup` рисует детей одним изображением через бэкбуфер. Полупрозрачные части персонажа, собранного из костей, не просвечивают друг через друга, а `self_modulate` группы меняет альфу целиком. Держите `fit_margin` и `clear_margin` (по умолчанию 10, проверено на 4.7.2) маленькими. `use_mipmaps` включайте только для шейдеров, которым нужны мипы ([CanvasGroup](https://docs.godotengine.org/en/stable/classes/class_canvasgroup.html)).
- `clip_children` (`ONLY` или `AND_DRAW`) превращает узел в маску для детей. Вкладывать клиппинг-узлы друг в друга и класть их внутрь `CanvasGroup` нельзя: оба механизма используют бэкбуфер.
- Чтение экрана в 2D: первый узел с `hint_screen_texture` копирует весь экран, следующие используют ту же копию и не видят друг друга. `BackBufferCopy` делает новую копию, полную или прямоугольником. Каждая копия стоит заметно, поэтому ограничивайте прямоугольник. В 3D экран копируется один раз, после непрозрачной геометрии ([Screen-reading shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)).
- `SCREEN_TEXTURE` как встроенная переменная `[устарело]` → `uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;`.
- Полноэкранный пост-эффект в 2D делается так: `CanvasLayer` → `ColorRect` с шейдером. Один такой проход на кадр дешевле нескольких перекрывающихся эффектов.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Screen-reading shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html) | документация Godot | Копии экрана, `BackBufferCopy`, глубина, normal-roughness |
| [CanvasGroup](https://docs.godotengine.org/en/stable/classes/class_canvasgroup.html) | справка по классам | Поля, своя замена встроенного шейдера |
| [BackBufferCopy](https://docs.godotengine.org/en/stable/classes/class_backbuffercopy.html) | справка по классам | Режимы копирования |

---

## 2D: фильтрация, пиксель-арт и сглаживание

### Ключевые выводы

- Значения по умолчанию (проверено на 4.7.2): `rendering/textures/canvas_textures/default_texture_filter = 1` (Linear), `default_texture_repeat = 0` (Disable). У каждого `CanvasItem` `texture_filter = 0` (`PARENT_NODE`, наследование от родителя), поэтому фильтр, поставленный на корне сцены или на `CanvasLayer`, задаёт его для всей ветки. Смешивание фильтров среди соседей рвёт батч (замер выше).
- Пиксель-арт: `default_texture_filter = Nearest`; `display/window/stretch/mode = viewport` (строгая сетка, мир рендерится в базовом разрешении) или `canvas_items` (гладкие шрифты и движение с подпикселями); `scale_mode = integer`; базовое разрешение около 640×360 ([Multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html)). Значения по умолчанию: stretch `disabled`, aspect `keep`, scale_mode `fractional`, размер 1152×648 (проверено на 4.7.2).
- При дрожании пикселей помогают `rendering/2d/snap/snap_2d_transforms_to_pixel` и `snap_2d_vertices_to_pixel` (оба по умолчанию `false`, проверено на 4.7.2); их можно задать и на отдельном `Viewport`. В 4.3 исправили зазоры при снапе. Снап конфликтует с плавной камерой: при `position_smoothing` возможны рывки по пикселю.
- Режим `canvas_items` рисует 2D в разрешении окна (UI и текст чёткие, дороже по fill rate). Режим `viewport` рисует в базовом разрешении и масштабирует (дешевле, но без подпикселей). Для 3D-сцен с пиксельным 2D-оверлеем есть `Viewport.scaling_3d_mode = NEAREST` (4.7).
- При уменьшении большого арта (базовое 4K на 1080p) появляется алиасинг. Помогают мипмапы на 2D-текстурах (импорт → Mipmaps) и фильтр `LINEAR_WITH_MIPMAPS`, ценой памяти.
- Сглаживание 2D. Предпочтительно свойство `antialiased` у `Line2D` и `draw_*`: это дополнительная геометрия, без базовой цены. `MSAA 2D` (`rendering/anti_aliasing/quality/msaa_2d`, по умолчанию 0) есть только в Forward+/Mobile. Он сглаживает края геометрии и спрайтов, но не пиксель-арт внутри текстуры, не шрифты и не шейдеры ([2D antialiasing](https://docs.godotengine.org/en/stable/tutorials/2d/2d_antialiasing.html)).
- HDR 2D (`rendering/viewport/hdr_2d`, по умолчанию `false`) нужен для glow в 2D и ярких аддитивных эффектов. В Compatibility его нет. С 4.6 при HDR 2D повышенная точность сохраняется и в 3D-конвейере.
- Если пикселям не хватает чёткости в 2D, проверьте: Nearest на текстуре, отсутствие нецелого `zoom` у камеры, целочисленный масштаб окна, позиции на целых пикселях.

```ini
; project.godot — минимальная пиксель-арт-конфигурация (пути проверены на 4.7.2)
[display]
window/size/viewport_width=640
window/size/viewport_height=360
window/stretch/mode="viewport"
window/stretch/scale_mode="integer"

[rendering]
textures/canvas_textures/default_texture_filter=0
2d/snap/snap_2d_transforms_to_pixel=true
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html) | документация Godot | Stretch mode/aspect, integer scaling, рекомендуемые базовые размеры |
| [2D antialiasing](https://docs.godotengine.org/en/stable/tutorials/2d/2d_antialiasing.html) | документация Godot | `antialiased` против MSAA 2D |
| [Godot 4.3 release](https://godotengine.org/releases/4.3/) | Godot Foundation, 2024 | Стабильность пиксель-арта, Parallax2D, 2D-интерполяция |

---

## Параллакс и камеры

### Ключевые выводы

- `Parallax2D` (4.3, флаг experimental снят в [PR #101983](https://github.com/godotengine/godot/pull/101983)) заменяет `ParallaxBackground`/`ParallaxLayer` `[устарело]` (оба класса ещё есть в 4.7.2). Значения по умолчанию: `scroll_scale = (1, 1)`, `repeat_size = (0, 0)`, `repeat_times = 1`, `follow_viewport = true` (проверено на 4.7.2). Значение меньше 1 даёт дальний план, 0 — неподвижный.
- Бесшовный повтор: текстура, которая тайлится, не меньше вьюпорта, левый верхний угол в (0, 0), `repeat_size` равен её размеру. Для отдаления камеры используйте `repeat_times`. Не центрируйте текстуру в (0, 0): холст повтора идёт вправо и вниз ([2D parallax](https://docs.godotengine.org/en/stable/tutorials/2d/2d_parallax.html)).
- Сплит-скрин с параллаксом: склонируйте узлы параллакса в каждый `SubViewport` и разведите их через `visibility_layer` и `canvas_cull_mask`.
- `Camera2D`: по умолчанию `enabled = true`, `process_callback = IDLE`, `position_smoothing_enabled = false` (скорость 5), `ignore_rotation = true`, anchor `DRAG_CENTER`, `limit_left = -10000000` (проверено на 4.7.2). На вьюпорт активна только одна камера. `current = true` из Godot 3 `[устарело]` → `enabled` + `make_current()` ([Camera2D](https://docs.godotengine.org/en/stable/classes/class_camera2d.html)).
- Ограничения уровня: `limit_*` + `limit_smoothed` (работает только со сглаживанием). Мгновенный перенос: `reset_smoothing()`. Реальный центр экрана с учётом сглаживания и лимитов: `get_screen_center_position()`.
- Растровые шрифты при `zoom` камеры размываются: оверсэмплинг шрифтов не учитывает зум камеры. HUD держите в `CanvasLayer`, вне камеры.
- `Camera3D`: `fov = 75`, `near = 0.05`, `far = 4000`, `keep_aspect = KEEP_HEIGHT` (проверено на 4.7.2). Z-fighting лечат увеличением `near`; уменьшение `far` помогает меньше ([3D rendering limitations](https://docs.godotengine.org/en/stable/tutorials/3d/3d_rendering_limitations.html)). Слишком большой `far` вредит и теням: держите `directional_shadow_max_distance` разумным.
- Окружение и `CameraAttributes`, назначенные на `Camera3D`, переопределяют `WorldEnvironment`, поэтому у кат-сцен может быть свой пост-эффект. Сложные переходы камер, приоритеты и тряску даёт Phantom Camera (см. [domains.md](domains.md#1-2d-игры)).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [2D parallax](https://docs.godotengine.org/en/stable/tutorials/2d/2d_parallax.html) | документация Godot | Повтор, зум, сплит-скрин |
| [Parallax2D](https://docs.godotengine.org/en/stable/classes/class_parallax2d.html) | справка по классам | `autoscroll`, `scroll_offset`, `ignore_camera_scroll` |
| [Camera2D](https://docs.godotengine.org/en/stable/classes/class_camera2d.html) / [Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html) | справка по классам | Сглаживание, лимиты, проекции |

---

## Плавность движения: интерполяция физики

### Ключевые выводы

- Jitter (постоянное дрожание) появляется, когда частота физики (по умолчанию 60) не совпадает с частотой монитора (120/144 Гц). Включите `physics/common/physics_interpolation` (по умолчанию `false`, проверено на 4.7.2). 2D-интерполяция есть с 4.3, 3D — с 4.4 ([Jitter, stutter and input lag](https://docs.godotengine.org/en/stable/tutorials/rendering/jitter_stutter.html)).
- Правила: двигайте объекты и запускайте логику в `_physics_process`, включая твины, анимации и навигацию, которые двигают узлы. После первой расстановки или телепорта вызывайте `reset_physics_interpolation()`. Для пули с ходу: задать трансформ, сбросить, затем задать трансформ следующего тика. Порядок важен ([Using physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/using_physics_interpolation.html)).
- Отличия 2D и 3D: в 2D интерполяция работает на стороне сервера (действует и на объекты, созданные через `RenderingServer`), в 3D — на стороне сцены. `get_global_transform_interpolated()` есть только в 3D. Из 2D-частиц интерполируются только `CPUParticles2D`, `GPUParticles2D` — нет. `MultiMesh` поддерживается в обоих: в 2D с [PR #107666](https://github.com/godotengine/godot/pull/107666), `physics_interpolation_quality` по умолчанию FAST ([2D and 3D physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/2d_and_3d_physics_interpolation.html)).
- Проверить, что всё сделано правильно, можно так: временно поставьте 10 тиков физики в секунду. Всё, что всё ещё дёргается, двигается вне физического тика.
- Stutter (редкие рывки) появляется из-за компиляции шейдеров (см. ниже), полноэкранного режима без exclusive на Windows или композитора на Linux. Задержку ввода снижают `rendering/rendering_device/vsync/swapchain_image_count = 2` (по умолчанию 3, проверено на 4.7.2), отключение V-Sync как опция для игрока и ограничение FPS чуть ниже частоты монитора при VRR.
- Самодельное сглаживание через `lerp` в `_process` при включённой интерполяции `[устарело]`: оно даёт двойное сглаживание и лаг.

```gdscript
# Респаун без «шлейфа» через весь уровень
func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	reset_physics_interpolation()
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Physics interpolation quick start](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_quick_start_guide.html) | документация Godot | Три правила включения |
| [2D and 3D physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/2d_and_3d_physics_interpolation.html) | документация Godot | Разница реализаций, частицы |
| [Jitter, stutter and input lag](https://docs.godotengine.org/en/stable/tutorials/rendering/jitter_stutter.html) | документация Godot | Диагностика по симптомам |

---

## Viewports, масштабирование 3D и сглаживание

### Ключевые выводы

- `SubViewport` — отдельная цель рендеринга: 3D внутри 2D, 2D на 3D-поверхности, миникарта, зеркало, портрет персонажа в UI, сплит-скрин. Он рендерится, если стоит внутри `SubViewportContainer` или если его текстура (`get_texture()`) где-то видна ([Using Viewports](https://docs.godotengine.org/en/stable/tutorials/rendering/viewports.html)).
- Значения по умолчанию (проверено на 4.7.2): `size = 512×512`, `render_target_update_mode = WHEN_VISIBLE`, `clear_mode = ALWAYS`, MSAA выключен, `own_world_3d = false`. Значит, вьюпорт по умолчанию видит тот же `World3D`, что и родитель: миникарта сверху и сплит-скрин работают без копирования сцены. Отдельный мир для превью предмета задаёт `own_world_3d = true`.
- Режимы обновления: `DISABLED`, `ONCE`, `WHEN_VISIBLE`, `WHEN_PARENT_VISIBLE`, `ALWAYS`. Каждый активный вьюпорт — это полный проход рендера со своими тенями и пост-эффектами. Статичный портрет рендерите через `ONCE`. Миникарте хватает низкого разрешения и обновления раз в несколько кадров. Для 2D-вьюпорта ставьте `disable_3d = true`.
- Тени в `SubViewport` требуют `positional_shadow_atlas_size > 0`. Если в миникарте нет теней, дело в этом.
- `SubViewportContainer.stretch = true` подгоняет вьюпорт под контейнер, `stretch_shrink = 2` рендерит в половинном разрешении (дешёвый пиксельный 3D-вид).
- Скриншот: `await RenderingServer.frame_post_draw`, затем `get_viewport().get_texture().get_image()`. В `_ready()` текстура ещё пустая.
- Масштабирование 3D (`rendering/scaling_3d/mode`, по умолчанию bilinear, `scale = 1.0`, `fsr_sharpness = 0.2`, проверено на 4.7.2). Режимы: `BILINEAR` (везде), `FSR` (FSR 1.0, Forward+), `FSR2` (2.2, Forward+, свой TAA, `use_taa` игнорируется), `METALFX_SPATIAL`/`METALFX_TEMPORAL` (Metal, 4.4), `NEAREST` (4.7, [PR #79731](https://github.com/godotengine/godot/pull/79731)). Масштаб действует только на 3D, 2D и UI остаются в родном разрешении. Масштаб применяется по каждой оси, поэтому 0.5 даёт четверть пикселей ([Resolution scaling](https://docs.godotengine.org/en/stable/tutorials/3d/resolution_scaling.html)).
- Если снижение масштаба почти не помогает, узкое место в другом: слишком много вызовов отрисовки (CPU) или дорогие эффекты (SDFGI, SSAO, SSR).
- Сглаживание 3D ([3D antialiasing](https://docs.godotengine.org/en/stable/tutorials/3d/3d_antialiasing.html)): MSAA во всех рендерерах (края геометрии, без размытия). TAA и FSR2 в нативном разрешении — только Forward+, лучше всего справляются с бликами и прозрачностью, но дают размытие и шлейфы. FXAA и SMAA 1x (4.5) — Forward+/Mobile. SSAA через `scale > 1` очень дорог. На слабых GPU практически подходит только FXAA или MSAA 2×.
- Смена уровня MSAA посреди игры вызывает компиляцию пайплайнов. Меняйте его только в меню настроек.

```gdscript
# Миникарта: тот же мир, своя камера сверху, низкое разрешение, 15 Гц
@onready var map_vp: SubViewport = $MinimapContainer/SubViewport
var _acc := 0.0

func _ready() -> void:
	map_vp.size = Vector2i(256, 256)
	map_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	map_vp.positional_shadow_atlas_size = 0   # тени миникарте не нужны
	map_vp.msaa_3d = Viewport.MSAA_DISABLED

func _process(delta: float) -> void:
	_acc += delta
	if _acc >= 1.0 / 15.0:
		_acc = 0.0
		map_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Using Viewports](https://docs.godotengine.org/en/stable/tutorials/rendering/viewports.html) | документация Godot | Режимы обновления, миры, ввод, скриншоты |
| [Resolution scaling](https://docs.godotengine.org/en/stable/tutorials/3d/resolution_scaling.html) | документация Godot | FSR1/FSR2, резкость, mipmap bias |
| [3D antialiasing](https://docs.godotengine.org/en/stable/tutorials/3d/3d_antialiasing.html) | документация Godot | Сравнение MSAA, TAA, FSR2, FXAA, SMAA, SSAA |
| [SubViewport](https://docs.godotengine.org/en/stable/classes/class_subviewport.html) | справка по классам | Все режимы `UpdateMode` и `ClearMode` |
| [Godot 4.5 release](https://godotengine.org/releases/4.5/) | Godot Foundation, 2025 | SMAA, shader baker, стенсил, F16 в Mobile |

---

## 3D: источники света и тени

### Ключевые выводы

- Значения по умолчанию (проверено на 4.7.2): у всех источников тени выключены. `DirectionalLight3D`: PSSM 4 сплита, `directional_shadow_max_distance = 100`, `light_bake_mode = DYNAMIC`. `OmniLight3D`: `range = 5`, тени `CUBE`. `SpotLight3D`: `range = 5`, угол 45°. Атласы: направленный 4096, позиционный 4096, мягкий фильтр — качество 2.
- Каскады: объект, попавший во все сплиты, рисуется в тень пять раз за кадр. Подберите `max_distance` под игру, `blend_splits` включайте только при видимых швах ([3D lights and shadows](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html)). В замере 400 кубов с тенью в Forward+ дали 6 теневых вызовов, в Mobile — 400.
- Атлас позиционных теней разбит на 4 квадранта. По умолчанию в них 4 + 4 + 16 + 64 = 88 ячеек (`atlas_quadrant_0..3_subdiv` = 2, 2, 3, 4, проверено на 4.7.2), то есть до 88 затеняющих omni и spot в кадре. Меньше теней в квадранте — выше разрешение каждой. Omni-тень `CUBE` точнее, `DUAL_PARABOLOID` быстрее, но искажает.
- Акне лечите `normal_bias`, а не `bias` (большой `bias` даёт peter-panning). Мягкие тени PCSS (`light_angular_distance` у солнца, `light_size` у omni/spot) дороги: включайте у одного-двух крупных источников.
- Лимиты: Forward+ — 512 кластерных элементов в кадре (omni, spot, декали, пробы; `rendering/limits/cluster_builder/max_clustered_elements = 512`, проверено на 4.7.2). Mobile — 8 omni + 8 spot на меш, 256 + 256 на вид, лимиты не меняются. Compatibility — 8 + 8 на меш. Во всех не больше 8 направленных.
- Дешевле всего: `distance_fade_enabled` на мелких источниках, тени только у источников, которые их заметно дают, `Static` bake для неподвижного света с LightmapGI, эмиссивный материал вместо множества мелких ламп.
- `shadow_caster_mask` (4.4) выбирает, какие слои отбрасывают тень от конкретного источника. `cull_mask` управляет только освещением, тень объект всё равно отбрасывает.
- `AreaLight3D` (4.7): прямоугольный источник, `area_size`, `area_range`, PCSS-тени. Он дороже omni и spot. В Forward+ даже один видимый area light удорожает шейдинг всех объектов. В Compatibility у него нет теней и текстуры. Используйте в кат-сценах и на мощном железе ([AreaLight3D](https://docs.godotengine.org/en/stable/classes/class_arealight3d.html)).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [3D lights and shadows](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html) | документация Godot | Сплиты, атлас, bias, PCSS, лимиты |
| [AreaLight3D](https://docs.godotengine.org/en/stable/classes/class_arealight3d.html) | справка по классам, 4.7 | Свойства и цена area light |
| [Light3D](https://docs.godotengine.org/en/stable/classes/class_light3d.html) | справка по классам | `light_bake_mode`, `shadow_caster_mask`, distance fade |

---

## 3D: глобальное освещение

### Ключевые выводы

- По убыванию скорости: ReflectionProbe → LightmapGI → VoxelGI → SSIL → SDFGI. На Mobile и в Compatibility доступны только LightmapGI и ReflectionProbe ([Introduction to GI](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/introduction_to_global_illumination.html)).
- **LightmapGI**: нужен UV2 (импорт → Light Baking: Static Lightmaps, `lightmap_texel_size` 0.2, для больших сцен 0.5+). Bounces по умолчанию 3, качество Medium, денойзер JNLM (проверено на 4.7.2), внешний вариант — OIDN. `directional` даёт лучшие нормали ценой размера. Shadowmask (4.4) даёт запечённые дальние тени и живые ближние. Bicubic-фильтр включён по умолчанию (`lightmap_gi/use_bicubic_filter = true`, проверено на 4.7.2). Динамические объекты получают свет через пробы (`LightmapProbe` или автоматическую сетку). Видно максимум 8 LightmapGI. Запекание требует RD-рендерера, но рендерится результат и в Compatibility ([Using LightmapGI](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/using_lightmap_gi.html)).
- **VoxelGI** (Forward+): запекается за секунды, объекты могут двигаться, свет динамический. Протекает через стены тоньше вокселя. Видно максимум 8, смешиваются 2 на пиксель. Данные храните в бинарном `.res`. Удешевление: `rendering/global_illumination/voxel_gi/quality = Low` (4 конуса вместо 6), `gi/use_half_resolution` ([Using VoxelGI](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/using_voxel_gi.html)).
- **SDFGI** (Forward+): без запекания, для открытых и процедурных миров, самый дорогой. Каскадов не больше 4 при быстрой камере, `use_occlusion` против протечек, `read_sky_light` только для улицы. Динамические меши свет получают, но не дают. Сходится примерно за 25 кадров ([Using SDFGI](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/using_sdfgi.html)). В [priorities](https://godotengine.org/priorities/) стоит переработка в HDDAGI ([PR #86267](https://github.com/godotengine/godot/pull/86267)) `[не проверено: статус слияния]`.
- **ReflectionProbe**: `update_mode = ONCE` (по умолчанию, проверено на 4.7.2) почти бесплатен, `ALWAYS` перерисовывает сцену каждый кадр. `box_projection` для комнат, `interior` для закрытых помещений, одна проба на комнату, перекрытия небольшие, смешиваются максимум 4. С 4.6 пробы октаэдрические: дешевле и легче по памяти ([PR #107902](https://github.com/godotengine/godot/pull/107902): стресс-тест на M2 — 9 → 48 FPS) ([Reflection probes](https://docs.godotengine.org/en/stable/tutorials/3d/reflection_probes.html)).
- `gi_mode` у `GeometryInstance3D` по умолчанию `STATIC` (проверено на 4.7.2). Движущимся объектам ставьте `DYNAMIC` или `DISABLED`, иначе они попадут в запекание.
- GI-узлы и настройки окружения, включённые посреди игры, вызывают компиляцию пайплайнов. Включайте их на загрузке.
- `GIProbe` и `BakedLightmap` из Godot 3 `[устарело]` → `VoxelGI` и `LightmapGI`.

### Какой GI

| Сцена и платформа | Выбор | Компромисс |
|---|---|---|
| Статичный уровень, любое железо, Mobile, Web | LightmapGI + ReflectionProbe | Время запекания, UV2, свет нельзя двигать |
| Закрытые помещения среднего размера, ПК, движущийся свет | VoxelGI (+ пробы) | Протечки через тонкие стены, лимит 8 узлов |
| Большой открытый или процедурный мир, ПК | SDFGI (+ SSIL на high) | Самый дорогой, видны сдвиги каскадов |
| Смена дня и ночи на статичной геометрии, ПК | SDFGI или VoxelGI + свет `Dynamic` | Lightmap не подходит |
| Смена дня и ночи на Mobile | Ambient от неба + ReflectionProbe с `ALWAYS` редко, по таймеру | Плоский вид |
| Стилизация, toon, 2.5D | Без GI: ambient color + эмиссия | Самое дешёвое |
| Опция качества для игроков | SDFGI/VoxelGI → выкл., SSIL → вкл. на high | Нужно меню настроек и переключение на загрузке |

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Introduction to GI](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/introduction_to_global_illumination.html) | документация Godot | Сводная таблица техник |
| [Using LightmapGI](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/using_lightmap_gi.html) | документация Godot | UV2, качество, денойзеры, shadowmask, артефакты |
| [Using VoxelGI](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/using_voxel_gi.html) / [Using SDFGI](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/using_sdfgi.html) | документация Godot | Настройки и лимиты |
| [Reflection probes](https://docs.godotengine.org/en/stable/tutorials/3d/reflection_probes.html) | документация Godot | Режимы, смешивание, лимиты на меш |
| [GI demo](https://github.com/godotengine/godot-demo-projects/tree/master/3d/global_illumination) | Godot | Сравнение техник на одной сцене |

---

## 3D: Environment, CameraAttributes и пост-обработка

### Ключевые выводы

- Приоритет: окружение `Camera3D` → `WorldEnvironment` (один на активное дерево) → превью редактора. `CameraAttributes` (DOF, экспозиция) лучше назначать на камеру ([Environment and post-processing](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html)).
- Значения по умолчанию у `Environment.new()` (проверено на 4.7.2): фон `CLEAR_COLOR`, тонмаппер `LINEAR`, все эффекты выключены, `glow_blend_mode = SCREEN` (по умолчанию с 4.6), туман экспоненциальный. Тонмапперы: `LINEAR`, `REINHARDT`, `FILMIC`, `ACES`, `AGX` (4.4). AgX самый медленный, но лучше всех держит оттенок в ярком. С 4.6 у него настраиваются `agx_white` и `agx_contrast`. Для фотореализма white около 6–8.
- Только Forward+: SSR (переписан в 4.6, `screen_space_reflection/half_size = true`), SSIL (`ssil/half_size = true`), SDFGI, объёмный туман, авто-экспозиция. SSAO — Forward+ и Compatibility (упрощённый), в Mobile его нет. `ssao/half_size = true`, `ssao/quality = 2` (проверено на 4.7.2). Экранные эффекты не видят то, что за кадром. Запечённый AO выглядит лучше SSAO и ничего не стоит в рантайме.
- Glow: с 4.6 смешивается до тонмаппинга. Bicubic-апскейл (`glow/upscale_mode = 1`, по умолчанию) на встроенной графике заметно дорог.
- Туман: depth и height fog почти бесплатны. Объёмный туман (Forward+) задаётся сеткой `volume_size = 64` × `volume_depth = 64` (проверено на 4.7.2), даёт шлейфы от temporal reprojection и имеет конечную дальность: дальше используйте обычный туман. `FogVolume` с `FogMaterial` даёт локальный туман, шум для плотности — 64³ или меньше. У коротких вспышек света ставьте `volumetric_fog_energy = 0` ([Volumetric fog](https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html)).
- Цветокоррекция (brightness/contrast/saturation, 1D-градиент, 3D LUT как `Texture3D`) идёт после тонмаппинга и стоит дёшево.
- Банды: `rendering/anti_aliasing/quality/use_debanding` (по умолчанию `false`; с 4.6 работает и для 3D в Mobile). Specular occlusion (4.5) включён по умолчанию (`reflections/specular_occlusion/enabled = true`, проверено на 4.7.2).
- HDR-вывод (4.7) на Windows, macOS, iOS, visionOS и Wayland включается через `display/window/hdr/request_hdr_output` (по умолчанию `false`) или `DisplayServer.window_request_hdr_output()` (проверено на 4.7.2, есть в API). Требует Forward+ или Mobile.
- Свои проходы пост-обработки в 3D делаются через `Compositor` и `CompositorEffect` (4.3, Forward+/Mobile), см. [domains.md](domains.md#9-шейдеры-и-vfx).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Environment and post-processing](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html) | документация Godot | Все эффекты окружения и их цена |
| [Volumetric fog](https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html) | документация Godot | FogVolume, настройки, альтернативы |
| [Physical light and camera units](https://docs.godotengine.org/en/stable/tutorials/3d/physical_light_and_camera_units.html) | документация Godot | `CameraAttributesPhysical`, люксы и люмены |
| [The Compositor](https://docs.godotengine.org/en/stable/tutorials/rendering/compositor.html) | документация Godot | Свои проходы рендера |

---

## 3D: материалы и прозрачность

### Ключевые выводы

- `StandardMaterial3D` — убер-материал с переключателями; каждый набор флагов компилируется в отдельный шейдер. `ORMMaterial3D` — то же самое, но occlusion, roughness и metallic упакованы в одну текстуру: меньше сэмплов и памяти. Стандарт для glTF-ассетов. `ShaderMaterial` нужен, когда флагов не хватает. Конвертация: в инспекторе «Convert to ShaderMaterial» ([Standard Material 3D](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html)).
- Число уникальных материалов важнее числа полигонов. В Forward+ общий материал даёт автоинстансинг (400 → 1 вызов), а уникальный — нет (400). Разные параметры задавайте через `instance uniform` у `GeometryInstance3D.set_instance_shader_parameter()` (есть в 4.7.2) или через цвет `MultiMesh`, а не копией материала.
- Значения по умолчанию (проверено на 4.7.2): прозрачности нет, шейдинг per-pixel, cull back, depth draw opaque-only, фильтр `LINEAR_WITH_MIPMAPS`, `cast_shadow = ON`.
- Прозрачность по возрастанию цены: Disabled → Alpha Scissor (листва, заборы, отбрасывает тень) → Alpha Hash (волосы) → Depth Pre-Pass → Alpha. Alpha-блендинг не отбрасывает тень, не попадает в SSR и normal-roughness buffer и сортируется по origin узла, а не по пикселю. Неблендовый режим смешивания, refraction, proximity и distance fade с Pixel Alpha принудительно включают блендинг.
- Сортировка прозрачных: `render_priority` у материала, `sorting_offset` у узла. Прозрачную часть меша выделяйте в отдельную поверхность, тогда непрозрачная часть останется дешёвой и будет отбрасывать тень ([3D rendering limitations](https://docs.godotengine.org/en/stable/tutorials/3d/3d_rendering_limitations.html)).
- Для fade по расстоянию берите Pixel Dither или Object Dither, а не Pixel Alpha: объект остаётся непрозрачным.
- `cull_mode = DISABLED` (двусторонний) стоит производительности. Blender часто экспортирует без backface culling, исправляйте в исходнике.
- Шейдинг per-vertex и unshaded — для мобильных и частиц. `rendering/shading/overrides/force_vertex_shading` (по умолчанию `false`) переключает весь проект на вершинный шейдинг, полезно для PSX-стиля и слабых устройств.
- `SpatialMaterial` `[устарело]` → `StandardMaterial3D`.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Standard Material 3D and ORM Material 3D](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html) | документация Godot | Все флаги и их цена |
| [3D rendering limitations](https://docs.godotengine.org/en/stable/tutorials/3d/3d_rendering_limitations.html) | документация Godot | Сортировка прозрачных, z-fighting, размеры текстур, банды |
| [Spatial shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html) | документация Godot | `render_mode`, встроенные переменные |

---

## 3D: LOD, отсечение, частицы, декали, небо

### Ключевые выводы

- **Mesh LOD** генерируется при импорте glTF, .blend и FBX автоматически. `rendering/mesh_lod/lod_change/threshold_pixels = 1.0` (проверено на 4.7.2) визуально без потерь, больше — быстрее и грубее. На узле есть `lod_bias` (по умолчанию 1.0). У `MultiMesh` один LOD на весь узел (по ближайшей точке AABB), поэтому большие поля разбивайте на куски. На скиннутых мешах LOD может давать артефакты ([Mesh level of detail](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html)).
- **Visibility ranges (HLOD)**: `visibility_range_begin/end` + margin. Режим fade `DISABLED` самый быстрый. `SELF` и `DEPENDENCIES` делают объект прозрачным на время перехода, а это дорого. Дешёвая альтернатива — Object Dither. `visibility_parent` прячет детали, когда виден общий упрощённый меш ([Visibility ranges](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html)).
- **Occlusion culling** выключен по умолчанию (`rendering/occlusion_culling/use_occlusion_culling = false`, проверено на 4.7.2). Работает на CPU через Embree и выгоден в помещениях с толстыми стенами. Больше всего он даёт в Mobile, где нет depth prepass (`driver/depth_prepass/disable_for_vendors = PowerVR,Mali,Adreno,Apple`, проверено на 4.7.2). Двигать `OccluderInstance3D` дорого (пересборка BVH), переключать видимость дёшево. Динамические объекты исключайте из запекания маской ([Occlusion culling](https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html)). Rooms & Portals `[устарело]`.
- **Частицы**: по умолчанию `amount = 8`, `lifetime = 1`, `fixed_fps = 30`, `interpolate = true`, `visibility_aabb` 8×8×8, у 2D `visibility_rect` 200×200 (проверено на 4.7.2). Обязательно сгенерируйте AABB/Rect под реальный эффект: с маленьким эффект пропадает у края экрана, с огромным никогда не отсекается. `GPUParticles` — тысячи частиц, коллизии (SDF, heightfield), аттракторы, трейлы (не в Compatibility). `CPUParticles` — слабое железо, малые количества, интерполяция в 2D. Новых фич они не получают ([2D particle systems](https://docs.godotengine.org/en/stable/tutorials/2d/particle_systems_2d.html), [3D particles](https://docs.godotengine.org/en/stable/tutorials/3d/particles/index.html)).
- **Декали** — Forward+ и Mobile (в Mobile 8 на меш), в Compatibility их нет (замена — `Sprite3D`). Держите ось Y (глубину проекции) минимальной. Несколько крупных декалей дороже множества мелких. Используйте distance fade и `cull_mask` ([Using decals](https://docs.godotengine.org/en/stable/tutorials/3d/using_decals.html)).
- **Небо**: radiance-кубмапа обновляется, когда в шейдере неба используются `TIME` или `POSITION` (при движении камеры), меняется солнце или юниформ. `TIME` в небесном шейдере означает перерисовку каждый кадр. Дорогие облака считайте в `use_half_res_pass`/`use_quarter_res_pass`, в кубмапе — через `AT_CUBEMAP_PASS`. Статичное небо: один раз отрисовать в кубмапу, фон брать через `texture(RADIANCE, EYEDIR)` ([Sky shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/sky_shader.html)).
- `MultiMeshInstance3D` для тысяч однотипных объектов и серверы для экстремальных случаев описаны в [performance.md](performance.md#рендеринг-батчинг-multimesh-серверы-шейдеры).

```gdscript
# HLOD руками: детальная версия до 40 м, упрощённая дальше, без прозрачного fade
@onready var detail: MeshInstance3D = $House_LOD0
@onready var proxy: MeshInstance3D = $House_LOD1

func _ready() -> void:
	detail.visibility_range_end = 40.0
	detail.visibility_range_end_margin = 2.0
	proxy.visibility_range_begin = 40.0
	proxy.visibility_range_begin_margin = 2.0
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # вдали тень не нужна
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Mesh level of detail](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html) | документация Godot | Порог, bias, MultiMesh |
| [Visibility ranges](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html) | документация Godot | HLOD, fade, dither |
| [Occlusion culling](https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html) | документация Godot | Запекание, отладка, ложные срабатывания |
| [Using decals](https://docs.godotengine.org/en/stable/tutorials/3d/using_decals.html) | документация Godot | Лимиты и цена декалей |
| [Sky shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/sky_shader.html) | документация Godot | Когда обновляется radiance |
| [Optimizing 3D performance](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html) | документация Godot | Сводка рычагов 3D |

---

## Рывки компиляции шейдеров и кэш пайплайнов

### Ключевые выводы

- Шейдер компилируется в промежуточный формат (SPIR-V, DXIL, MIL), затем драйвер собирает пайплайн. Рывки дают в основном пайплайны. Кэши включены по умолчанию: `shader_compiler/shader_cache/enabled = true` (zstd), `rendering_device/pipeline_cache/enable = true` (проверено на 4.7.2). Кэш драйвера сбрасывается при его обновлении ([Reducing stutter from shader compilations](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html)).
- С 4.4 Forward+ и Mobile используют ubershaders (специализационные константы) и предкомпилируют пайплайны при загрузке мешей и добавлении узлов ([PR #90400](https://github.com/godotengine/godot/pull/90400)). Совет «показать каждый материал на кадр при загрузке» `[устарело]` для Forward+/Mobile, но в Compatibility по-прежнему нужен.
- Компиляцию посреди игры вызывают: смена уровня MSAA 3D, появление ReflectionProbe, separate specular (SSS), motion vectors (TAA, FSR2, motion blur), normal-roughness buffer (SDFGI, VoxelGI, SSR, SSAO, SSIL), LightmapGI, узлы VoxelGI и SDFGI, multiview, 16/32-битная точность теней, omni-тени. Включайте всё это на загрузке или в меню настроек.
- Монитор `Pipeline Compilations`: Canvas (2D, без предкомпиляции), Mesh (загрузка меша, грузите в фоне), Surface (первое появление; пик означает, что фича не включена заранее), Draw (не должно быть, это баг), Specialization (фоновая, без рывка). Значения только растут, поэтому смотрите на прирост во время игры. В API это `Performance.PIPELINE_COMPILATIONS_*` и `RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_*` (проверено на 4.7.2).
- Shader baker (4.5): в пресете экспорта Shader Baker → Enabled. Он заранее собирает шейдеры в PCK и сокращает первую загрузку, особенно на D3D12 и Metal: в TPS demo в 20 раз, в одном проекте на D3D12 — с «больше минуты» до примерно 2 с ([PR #102552](https://github.com/godotengine/godot/pull/102552)). Рывков пайплайнов он не убирает. Windows собирает под Vulkan и D3D12, macOS — под Vulkan и Metal, Linux и Android — только Vulkan. Не работает для Web, `--headless`-экспорта и Compatibility. Чтобы честно замерить эффект, удаляйте `user://shader_cache`.
- Эффекты, которые спавнятся в игре (взрывы, попадания), держите в скрытом экземпляре, привязанном к постоянному узлу, чтобы их пайплайны уже существовали.

```gdscript
# Сторож рывков в debug-сборке: печатает прирост компиляций за кадр
var _last := 0

func _process(_delta: float) -> void:
	if not OS.is_debug_build():
		return
	var now := int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)) \
		+ int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)) \
		+ int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS))
	if now > _last:
		push_warning("Pipeline compilations +%d at %s" % [now - _last, get_tree().current_scene.name])
	_last = now
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Reducing stutter from shader compilations](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html) | документация Godot (4.4+) | Мониторы, список фич-триггеров, baker |
| [PR #90400: ubershaders](https://github.com/godotengine/godot/pull/90400) | DarioSamo, 2024 | Устройство предкомпиляции |
| [PR #102552: shader baker](https://github.com/godotengine/godot/pull/102552) | DarioSamo, 2025 | Платформы, оговорки, цифры |

---

## Отладка рендеринга

### Ключевые выводы

- **Visual Profiler** (Debugger → Visual Profiler) показывает время CPU и GPU по стадиям рендера. Стадии с пометкой (Parallel) выполняются параллельно на GPU, поэтому отключение одной может мало дать. На macOS в Compatibility профайлер не работает ([Debugger panel](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/debugger_panel.html)).
- **Monitors**: `RENDER_TOTAL_OBJECTS/PRIMITIVES/DRAW_CALLS_IN_FRAME`, `RENDER_VIDEO/TEXTURE/BUFFER_MEM_USED`, `PIPELINE_COMPILATIONS_*` (проверено на 4.7.2). Вкладка **Video RAM** перечисляет ресурсы по объёму.
- **Режимы отладочной отрисовки** (меню Perspective → Display Advanced, или `Viewport.debug_draw` в игре). В 4.7.2 их 29: `UNSHADED`, `LIGHTING`, `OVERDRAW`, `WIREFRAME`, `NORMAL_BUFFER`, `SHADOW_ATLAS`, `DIRECTIONAL_SHADOW_ATLAS`, `PSSM_SPLITS`, `SSAO`, `SSIL`, `SDFGI`, `DECAL_ATLAS`, `DISABLE_LOD`, `CLUSTER_OMNI_LIGHTS` и другие `CLUSTER_*`, `OCCLUDERS`, `MOTION_VECTORS`, `INTERNAL_BUFFER`, `CLUSTER_AREA_LIGHTS`, `AREA_LIGHT_ATLAS` (проверено на 4.7.2). `OVERDRAW` показывает, где болит fill rate (прозрачность, частицы), `DISABLE_LOD` позволяет сравнить LOD.
- В 3D-вьюпорте редактора **View Frame Time** и **View Information** показывают FPS, объекты, примитивы и вызовы.
- Флаги CLI (проверено на 4.7.2, `--help`): `--rendering-method`/`--rendering-driver` (сравнить рендереры без правки проекта), `--gpu-index`, `--gpu-profile` (самые дорогие задачи кадра), `--gpu-validation` и `--gpu-abort` (слои валидации API), `--generate-spirv-debug-info` (отладка шейдеров по исходнику в **RenderDoc**, только Vulkan), `--extra-gpu-memory-tracking`, `--accurate-breadcrumbs` (поиск команды, вызвавшей сброс GPU), `--max-fps`, `--disable-vsync`.
- RenderDoc ([renderdoc.org](https://renderdoc.org/)): запустите экспортированную игру или `godot.exe --path <проект>` из RenderDoc с `--rendering-driver vulkan` (или d3d12) и снимите кадр. В нём видны все проходы, текстуры и пайплайны. На Android и Quest подходят Perfetto (по умолчанию в 4.7 для Android-сборок) и инструменты вендоров.
- Свой замер в игре: `RenderingServer.viewport_set_measure_render_time(rid, true)`, затем `viewport_get_measured_render_time_cpu/gpu` (методы есть в 4.7.2). В тестовом окне GPU-время вернулось около 0.008 мс уже на 15-м кадре, значит нужен прогрев `[не проверено]`.

```gdscript
# Горячие клавиши отладки в debug-сборке: overdraw / unshaded / обычный вид
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_F5: get_viewport().debug_draw = Viewport.DEBUG_DRAW_OVERDRAW
		KEY_F6: get_viewport().debug_draw = Viewport.DEBUG_DRAW_UNSHADED
		KEY_F7: get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED
		KEY_F8: print("draw calls: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Debugger panel](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/debugger_panel.html) | документация Godot | Visual Profiler, Monitors, Video RAM |
| [Viewport](https://docs.godotengine.org/en/stable/classes/class_viewport.html) | справка по классам | `debug_draw`, `scaling_3d_mode`, `use_occlusion_culling`, `mesh_lod_threshold` |
| [RenderingServer](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html) | справка по классам | `get_rendering_info`, замер времени |
| [RenderDoc](https://renderdoc.org/) | Baldur Karlsson | Захват кадра Vulkan/D3D12 |
| [Godot priorities](https://godotengine.org/priorities/) | Godot Foundation | Куда движется рендерер: стриминг текстур ([PR #113429](https://github.com/godotengine/godot/pull/113429)), ray tracing API ([PR #99119](https://github.com/godotengine/godot/pull/99119)), отладка VRAM |

---

## Антипаттерны

### Ключевые выводы

- **Уникальный материал на каждый объект** (копия `ShaderMaterial` ради цвета). В 2D 1000 спрайтов дают 1000 вызовов вместо 1, в 3D пропадает автоинстансинг Forward+ (проверено на 4.7.2). Нужен `instance uniform` или `modulate`.
- **Текстуры вперемешку по порядку отрисовки**: красный, синий, красный… дают 1000 вызовов вместо 2. Используйте атлас, группировку в дереве или `z_index`.
- **`draw_circle` тысячами в `_draw()`** — 1000 вызовов (проверено на 4.7.2). Замена: текстура или `MultiMeshInstance2D`.
- **`queue_redraw()` каждый кадр без изменений** и `_draw()` с тяжёлыми циклами.
- **Расчёт на автоинстансинг в Mobile/Compatibility**: там 400 одинаковых мешей дают 400 вызовов, нужен `MultiMesh`.
- **Включение SDFGI, SSR, MSAA, TAA или ReflectionProbe посреди уровня**: рывок компиляции пайплайнов.
- **Эффекты только для Forward+ в проекте, который откатывается на Compatibility** (fallback или Web): эффект молча пропадает.
- **Alpha-блендинг для листвы и заборов**: нет теней, неверная сортировка, overdraw. Нужен Alpha Scissor или Hash.
- **Fade у visibility ranges и Pixel Alpha distance fade на тысячах объектов**: всё уходит в прозрачный проход. Используйте dither.
- **Тени у всех omni-источников и PCSS на каждом**: атлас дробится, GPU тонет. Тень давайте немногим, остальным — distance fade.
- **Реалтайм-небо с `TIME` на мобильных** и `ReflectionProbe` с `ALWAYS` без нужды: перерисовка кубмапы каждый кадр.
- **`SubViewport` с `UPDATE_ALWAYS` для статичной картинки** и полноразмерные вьюпорты для миникарты.
- **`GPUParticles` без настроенного visibility AABB/Rect**: эффект пропадает у края экрана или никогда не отсекается.
- **Движущийся `OccluderInstance3D`**: пересборка BVH каждый кадр.
- **Сглаживание камеры `lerp` в `_process` поверх интерполяции физики** и телепорт без `reset_physics_interpolation()`.
- **Советы Godot 3** `[устарело]`: GLES2 для слабого железа, `rendering/batching/*`, `VisualServer`, `update()`, `ParallaxBackground`, `GIProbe`, `BakedLightmap`, Rooms & Portals, `SpatialMaterial`, `SCREEN_TEXTURE`.

---

## Чеклист рендеринга сцены

### Ключевые выводы

Перед закрытием задачи по сцене пройдите по списку. Пункты с измеримым результатом проверяйте мониторами из раздела отладки.

1. Рендерер выбран под самую слабую целевую платформу и записан в `project.godot` с переопределениями `.mobile`/`.web`.
2. Драйвер на Windows выбран осознанно (D3D12 по умолчанию в новых проектах, Vulkan для VRS/PCVR), fallback проверен запуском с `--rendering-method gl_compatibility`.
3. Игра проверяет `RenderingServer.get_current_rendering_method()` и отключает недоступные эффекты.
4. Монитор `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` замерен в худшей точке уровня и укладывается в бюджет платформы.
5. 2D: общие текстуры в атласах, элементы с одной текстурой стоят рядом по порядку отрисовки.
6. 2D: нет уникальных материалов ради параметра, используются `instance uniform` или `modulate`; учтён лимит instance uniform в Compatibility.
7. 2D: `texture_filter`/`texture_repeat` заданы на корне ветки или в проекте, а не вразнобой на узлах.
8. 2D: `_draw()` перерисовывается только при изменении данных; круги и сложные примитивы не рисуются тысячами.
9. 2D: HUD и пост-эффекты лежат в `CanvasLayer`, фон — в `Parallax2D`.
10. 2D: свет — минимум источников, PCF13 только там, где виден; вспышки сделаны аддитивными спрайтами.
11. 2D: `CanvasGroup`, `clip_children` и `BackBufferCopy` используются точечно, с минимальными margin и прямоугольниками.
12. Пиксель-арт: Nearest, stretch `viewport` или `canvas_items` по задаче, `scale_mode = integer`, снап проверен вместе с камерой.
13. Physics interpolation включена, логика движения в `_physics_process`, телепорты сопровождаются `reset_physics_interpolation()`.
14. Камеры: одна активная на вьюпорт, лимиты уровня заданы, `near` и `far` подобраны против z-fighting.
15. `SubViewport`: минимальный размер, правильный `update_mode` (ONCE или DISABLED для статики), `disable_3d` для 2D, тени отключены, где не нужны.
16. 3D: масштабирование (FSR1/FSR2/MetalFX/bilinear/nearest) и AA выбраны под рендерер, вынесены в настройки игрока и меняются только в меню.
17. 3D: тени только у нужных источников; `directional_shadow_max_distance` подобран; атлас не переполнен (`DEBUG_DRAW_SHADOW_ATLAS`).
18. 3D: на мелких источниках включён distance fade, число источников на меш укладывается в лимиты Mobile/Compatibility.
19. 3D: техника GI выбрана по таблице «Какой GI», для LightmapGI проверены UV2 и texel size, `gi_mode` движущихся объектов не `STATIC`.
20. 3D: ReflectionProbe с `ONCE`, одна на комнату, `interior` и `box_projection` где нужно.
21. 3D: в Environment включено только заметное; экранные эффекты в half size; объёмный туман только в Forward+ и с обычным туманом вдали.
22. 3D: тонмаппер выбран (AgX/Filmic/ACES), debanding включён при видимых полосах.
23. 3D: число уникальных материалов минимально; ORM-текстуры упакованы; прозрачность — Scissor/Hash вместо Alpha, где возможно.
24. 3D: прозрачные объекты не мерцают при сортировке (`render_priority`, `sorting_offset`, разделение поверхностей).
25. 3D: LOD сгенерирован и проверен через `DISABLE_LOD`; большие `MultiMesh` разбиты на куски для LOD и отсечения.
26. 3D: HLOD через visibility ranges без прозрачного fade (или с dither).
27. 3D: в закрытых уровнях включён и запечён occlusion culling, движущиеся объекты исключены из запекания.
28. Частицы: настроены visibility AABB/Rect; выбор GPU или CPU обоснован платформой; `amount` минимален.
29. Декали: глубина проекции минимальна, distance fade включён; в Compatibility есть замена.
30. Небо: шейдер не использует `TIME` без нужды; тяжёлое считается в half/quarter-res pass.
31. Монитор `Pipeline Compilations` не растёт во время игры вне загрузок; все фичи включаются на загрузке; эффекты, которые спавнятся, прогреты.
32. Shader baker включён в экспорте для D3D12 и Metal и проверен после удаления `user://shader_cache`.
33. `OVERDRAW` проверен в самой плотной сцене (частицы, прозрачность, UI поверх 3D).
34. Visual Profiler снят на целевом железе, узкое место (CPU или GPU) установлено до оптимизации (см. [performance.md](performance.md#профилирование-и-мониторы)).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [GPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html) | документация Godot | Методика поиска GPU-узкого места |
| [Optimizing 3D performance](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html) | документация Godot | Сводка по 3D |
| [Optimization using Servers](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html) | документация Godot | Крайний случай: рисование через `RenderingServer` |
| [Rendering priorities: September 2024](https://godotengine.org/article/rendering-priorities-september-2024/) | Clay John, 2024 | Почему производительность стала приоритетом рендерера |
| [GodotCon US 2026 update](https://godotengine.org/article/godotcon-us-2026-update/) | Godot Foundation, 2026 | Программа с докладом команды рендеринга |

# Прикладные домены GDScript и Godot 4

Справочник по основным областям применения Godot 4 и GDScript, актуально на октябрь 2026: текущий стабильный выпуск — Godot 4.7.2 (август 2026), ветка 4.8 в dev-снапшотах. Для каждого домена — архитектурные и производительные правила, рекомендуемые аддоны и инструменты (в скобках — последняя версия, сверенная с GitHub в октябре 2026) и проверенные ресурсы. Пометка `[устарело]` — API или материал времён Godot 3 (KinematicBody, TileMap и т. п.), `[не проверено]` — факт из памяти, не сверенный с первоисточником. Полный каталог аддонов с проверкой на 4.7.2 и оценкой удобства для агента — в [addons.md](addons.md), [addons-content.md](addons-content.md) и [addons-agent-tools.md](addons-agent-tools.md). Общая архитектура проекта описана в [architecture.md](architecture.md), идиомы языка — в [idioms-patterns.md](idioms-patterns.md), сигналы, потоки и сеть — в [signals-async-threads.md](signals-async-threads.md).

Ключевые вехи версий, на которые ссылаются разделы:
- **4.3** (август 2024) — `TileMapLayer` вместо `TileMap`, однопоточный Web-экспорт, интерактивная музыка, Compositor, 2D-интерполяция физики.
- **4.4** (март 2025) — Jolt встроен как опция, типизированные словари, ubershaders, 3D-интерполяция физики.
- **4.5** (сентябрь 2025) — AccessKit (экранные дикторы), шейдер-бейкер, стенсил, отдельный 2D-сервер навигации, чанковая физика тайлмапов, `@abstract`, вариадические функции.
- **4.6** (январь 2026) — Jolt в новых 3D-проектах (Project Manager прописывает его в `project.godot`; без ключа остаётся GodotPhysics, проверено на 4.7.2), IK-фреймворк, Direct3D 12 по умолчанию на Windows, LibGodot, сборка Android через GABE.
- **4.7** (июнь 2026) — HDR-вывод, `AreaLight3D`, трансформации Control без влияния на раскладку, `VirtualJoystick`, `Tween.tween_await()`, новый Asset Store.

- [1. 2D-игры](#1-2d-игры)
- [2. 3D-игры](#2-3d-игры)
- [3. UI и приложения не-игры](#3-ui-и-приложения-не-игры)
- [4. Пошаговые, карточные, настольные и стратегические игры](#4-пошаговые-карточные-настольные-и-стратегические-игры)
- [5. ИИ и навигация](#5-ии-и-навигация)
- [6. Процедурная генерация и инструменты редактора](#6-процедурная-генерация-и-инструменты-редактора)
- [7. Диалоги, нарратив и локализация](#7-диалоги-нарратив-и-локализация)
- [8. Аудио](#8-аудио)
- [9. Шейдеры и VFX](#9-шейдеры-и-vfx)
- [10. Мультиплеер и платформы](#10-мультиплеер-и-платформы)
- [11. Interop: C#, GDExtension, godot-rust](#11-interop-c-gdextension-godot-rust)

---

## 1. 2D-игры

### Ключевые выводы
- Персонаж — `CharacterBody2D`: задайте `velocity` и вызовите `move_and_slide()` без аргументов, всё в `_physics_process`. Гравитацию берите из настроек проекта (`ProjectSettings.get_setting("physics/2d/default_gravity")`), а не хардкодьте. `KinematicBody2D` и `move_and_slide(velocity, Vector2.UP)` с аргументами — `[устарело]` (Godot 3). Для платформеров настройте `floor_snap_length`, `floor_max_angle` и `motion_mode` (`GROUNDED` для платформеров, `FLOATING` для вида сверху).
- Ввод: движение — `Input.get_vector("left", "right", "up", "down")` (нормализация и мёртвая зона за вас), разовые действия — в `_unhandled_input`, чтобы UI мог перехватить событие. Действия заводите в Input Map, а не проверяйте коды клавиш.
- Уровни — `TileMapLayer` (с 4.3), по одному узлу на слой; узел `TileMap` объявлен устаревшим — `[устарело]`, в редакторе есть конвертация в набор `TileMapLayer`. Встроенная в тайлы навигация, по документации, «имеет много практических ограничений» — для поиска пути запекайте `NavigationRegion2D` по геометрии уровня. С 4.5 физика тайлмапа сливает соседние ячейки в крупные формы (чанки) — меньше тел и быстрее столкновения.
- Интерактивные объекты на тайлах (двери, сундуки) — scene tiles или отдельные сцены поверх слоя; не храните игровое состояние в `TileData` — это общий ресурс тайлсета. Динамическое изменение карты (`set_cell`) дёшево, но массовые правки делайте пакетно, в одном кадре.
- Пиксель-арт: поставьте `rendering/textures/canvas_textures/default_texture_filter = Nearest` (по умолчанию Linear); растяжение окна `display/window/stretch/mode = viewport` (строгая пиксельная сетка) или `canvas_items` (гладкий UI), `display/window/stretch/scale_mode = integer` для целочисленного масштабирования; при дрожании спрайтов — `rendering/2d/snap/snap_2d_transforms_to_pixel` (пути и значения проверены на 4.7.2). В 4.7 для 3D добавлено масштабирование ближайшим соседом (`Viewport.SCALING_3D_MODE_NEAREST`).
- Плавность при высоком FPS: включите physics interpolation (2D — с 4.3), логика остаётся в `_physics_process` с фиксированным шагом, камера и визуал интерполируются. Если включено, не телепортируйте узлы без `reset_physics_interpolation()`.
- Камера: `Camera2D` с `position_smoothing`, ограничения `limit_*` под границы уровня; сложные сценарии (смена целей, тряска, зоны) — Phantom Camera. Параллакс — узел `Parallax2D` (4.3+); `ParallaxBackground`/`ParallaxLayer` — `[устарело]`.
- Анимация: `AnimatedSprite2D` — быстрые покадровые анимации; `AnimationPlayer` — когда нужно анимировать ещё и свойства, хитбоксы, звук, вызовы методов; `AnimationTree` (state machine или blend tree) — когда переходов много. С 4.2 оба наследуются от `AnimationMixer`. Анимационное состояние не должно управлять логикой — логика вызывает `travel()`, а не наоборот.
- Конечные автоматы персонажа держите в коде (узлы-состояния или `enum` + `match`) либо в LimboAI/godot-statecharts (см. раздел 5); главное — один владелец состояния.
- 4.7: односторонние столкновения у `CollisionShape2D` с настраиваемым направлением, конические `GradientTexture2D`, `DrawableTexture2D` для рисования по текстуре.

### Аддоны и инструменты
- Phantom Camera (0.11.0.3, июль 2026) — камеры 2D/3D с приоритетами, следованием и переходами в духе Cinemachine.
- Aseprite Wizard (9.8.0, март 2026) — импорт `.aseprite` в `SpriteFrames`/`AnimationPlayer`.
- LDtk Importer (2.0.1, 2024; последние коммиты 2025) — импорт уровней LDtk в `TileMapLayer`.
- godot-statecharts (0.22.5, июнь 2026) — иерархические состояния для персонажей и UI.
- Встроенные: редактор TileSet с terrain-автотайлингом, 2D Scene Paint Mode (4.7) для разбрасывания объектов.

### Ресурсы
| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Using CharacterBody2D](https://docs.godotengine.org/en/stable/tutorials/physics/using_character_body_2d.html) | Godot docs, живой | `move_and_slide` vs `move_and_collide`, отскоки, платформеры |
| [2D movement overview](https://docs.godotengine.org/en/stable/tutorials/2d/2d_movement.html) | Godot docs, живой | Типовые схемы управления: 8 направлений, поворот, мышь |
| [Using TileMaps](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html) / [Using TileSets](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html) | Godot docs, живой | `TileMapLayer`, terrain, scene tiles, коллизии |
| [TileMapLayer](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html) | Godot class ref, живой | API слоя; [TileMap](https://docs.godotengine.org/en/stable/classes/class_tilemap.html) — `[устарело]` |
| [Multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html) | Godot docs, живой | Stretch mode, aspect, целочисленное масштабирование для пиксель-арта |
| [Physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/index.html) / [Jitter, stutter](https://docs.godotengine.org/en/stable/tutorials/rendering/jitter_stutter.html) | Godot docs, живой | Плавное движение при любом FPS |
| [2D sprite animation](https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html) / [AnimationTree](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html) | Godot docs, живой | Покадровая анимация, state machine и blend tree |
| [2D parallax](https://docs.godotengine.org/en/stable/tutorials/2d/2d_parallax.html) | Godot docs, живой | `Parallax2D` |
| [2D demos](https://github.com/godotengine/godot-demo-projects/tree/master/2d/platformer) | Godot, 2026 (тег 4.7) | Эталонные платформер, [изометрия](https://github.com/godotengine/godot-demo-projects/tree/master/2d/isometric), [FSM](https://github.com/godotengine/godot-demo-projects/tree/master/2d/finite_state_machine), [Dodge the Creeps](https://github.com/godotengine/godot-demo-projects/tree/master/2d/dodge_the_creeps) |
| [Godot Recipes 4.x](https://kidscancode.org/godot_recipes/4.x/) | KidsCanCode (Chris Bradfield), живой | Короткие рецепты: платформеры, top-down, камера, тайлы |
| [Heartbeast](https://www.youtube.com/@uheartbeast) | Benjamin Anderson, живой | Видеокурсы по 2D action RPG и платформерам |
| [Phantom Camera](https://github.com/ramokz/phantom-camera) | ramokz, 2026 | Продвинутые камеры |

---

## 2. 3D-игры

### Ключевые выводы
- Рендерер выбирается при создании проекта и определяет набор фич. Forward+ (десктоп; Vulkan, Direct3D 12 или Metal) — все возможности: SDFGI, VoxelGI, объёмный туман, SSR, SSIL, TAA, FSR2. Mobile — те же API, проще пайплайн, но без VoxelGI, SDFGI, объёмного тумана, SSR и TAA. Compatibility (OpenGL) — слабое железо и единственный вариант для Web; нет SDFGI, VoxelGI, SSR, SSIL, декалей, compute-шейдеров. С 4.6 на Windows драйвер по умолчанию — Direct3D 12; при отсутствии Vulkan движок сам откатывается на D3D12 и наоборот (с 4.4).
- Глобальное освещение: LightmapGI — запечённый свет для статичных сцен, самый дешёвый в рантайме и единственный вариант GI вне Forward+; VoxelGI — полудинамический GI для ограниченных помещений (запекается заранее, объекты могут двигаться); SDFGI — полностью динамический GI для открытых миров, только Forward+, дорогой на GPU. ReflectionProbe дополняет любой вариант. Планируйте GI под целевой рендерер до создания уровней.
- Физика: с 4.6 Project Manager прописывает Jolt в новые 3D-проекты (`physics/3d/physics_engine="Jolt Physics"`). Старые проекты и проекты без этого ключа работают на GodotPhysics (проверено на 4.7.2), поэтому проверьте ключ явно. Отличия от Godot Physics: у суставов не поддерживаются мягкие ограничения (bias, damping, softness, restitution); сустав с одним телом трактуется как `node_b` + «мир»; `face_index` у рейкастов по умолчанию `-1` (включается опцией, +~25% памяти). Отдельный аддон godot-jolt нужен только для проектов на 4.3 и старше.
- Персонаж — `CharacterBody3D` + `move_and_slide()`; `KinematicBody` — `[устарело]`. Для камеры от третьего лица — `SpringArm3D`. Начиная с 4.5 3D-интерполяция физики встроена в SceneTree — логику держите в `_physics_process`, визуал интерполируется.
- Импорт: основной формат — glTF 2.0 (`.glb`); `.blend` импортируется напрямую при указанном пути к Blender; FBX — через встроенный ufbx (4.3+, по release notes; класс `FBXDocument` есть в 4.7.2). Настройки импорта сохраняются в `.import`; постобработку делайте скриптом `EditorScenePostImport`, а не ручными правками импортированной сцены — она перезапишется. Суффиксы имён (`-col`, `-rigid`, `-navmesh`) задают коллизии прямо из DCC.
- Ретаргетинг анимаций: в диалоге импорта назначьте `BoneMap` с `SkeletonProfileHumanoid` — анимации с разных ригов (Mixamo и др.) будут использовать одну схему костей. Процедурные позы — IK-фреймворк 4.6 (`TwoBoneIK3D`, `FABRIK3D`, `CCDIK3D`, `SplineIK3D`, `JacobianIK3D` на базе `IKModifier3D`).
- Производительность: occlusion culling (запечённые `OccluderInstance3D`), автоматический mesh LOD при импорте, `visibility_range` для HLOD, `MultiMeshInstance3D` для тысяч однотипных объектов (трава, снаряды). Число draw calls и материалов важнее числа полигонов. Подробности — в справочнике по производительности.
- Ранний старт шейдеров: ubershaders (4.4) и shader baker (4.5) убирают фризы компиляции пайплайнов — включайте baker в экспорте для D3D12/Metal.
- 4.7: `AreaLight3D` (прямоугольные источники), HDR-вывод, редактор MeshLibrary для `GridMap`, прилипание точек `Path3D` к коллайдерам, snapping по вершинам.

### Аддоны и инструменты
- Terrain3D (1.0.2, май 2026) — ландшафт на C++ GDExtension: клипмапы, до 32 текстур, редактор кистей.
- Sky3D (2.1.0, май 2026) — день/ночь, атмосфера, погода.
- Zylann Voxel Tools (1.7, август 2026) — воксельные миры (модуль и GDExtension); Zylann HTerrain — более старый ландшафт на GDScript.
- Spatial Scatter (HungryProton; последний тег 4.0 в 2023, но репозиторий активен) — процедурное размещение растительности и пропсов.
- godot-jolt (0.16.0, февраль 2026) — только для Godot 4.3 и старше; в 4.4+ используйте встроенный Jolt.
- Godot XR Tools — готовые механики VR (движение, руки, взаимодействие).

### Ресурсы
| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Overview of renderers](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html) | Godot docs, живой | Таблица фич Forward+/Mobile/Compatibility, выбор драйвера |
| [Introduction to GI](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/introduction_to_global_illumination.html) | Godot docs, живой | Сравнение VoxelGI, SDFGI, LightmapGI, ReflectionProbe; далее [SDFGI](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/using_sdfgi.html), [VoxelGI](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/using_voxel_gi.html), [LightmapGI](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/using_lightmap_gi.html) |
| [Using Jolt Physics](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html) | Godot docs, живой | Отличия Jolt от Godot Physics и нужные настройки |
| [Godot 4.6 release](https://godotengine.org/releases/4.6/) | Godot Foundation, 2026 | Jolt по умолчанию, IK, SSR, D3D12 |
| [Importing 3D scenes](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/index.html) / [форматы](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html) | Godot docs, живой | glTF/Blend/FBX, суффиксы, постимпорт |
| [Retargeting 3D skeletons](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html) | Godot docs, живой | `BoneMap`, `SkeletonProfileHumanoid` |
| [Occlusion culling](https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html) / [Mesh LOD](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html) / [MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html) | Godot docs, живой | Основные рычаги 3D-производительности |
| [Optimizing 3D performance](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html) | Godot docs, живой | Draw calls, материалы, освещение |
| [3D platformer demo](https://github.com/godotengine/godot-demo-projects/tree/master/3d/platformer) / [Truck Town](https://github.com/godotengine/godot-demo-projects/tree/master/3d/truck_town) / [GI demo](https://github.com/godotengine/godot-demo-projects/tree/master/3d/global_illumination) | Godot, 2026 | Персонаж, транспорт, сравнение GI вживую |
| [Terrain3D](https://github.com/TokisanGames/Terrain3D) | Tokisan Games, 2026 | Ландшафт промышленного уровня |
| [Godot XR Tools](https://github.com/GodotVR/godot-xr-tools) | GodotVR, живой | Механики VR поверх OpenXR; общий обзор — [XR docs](https://docs.godotengine.org/en/stable/tutorials/xr/index.html) |

---

## 3. UI и приложения не-игры

### Ключевые выводы
- Раскладку стройте контейнерами (`VBoxContainer`, `HBoxContainer`, `GridContainer`, `MarginContainer`, `ScrollContainer`, `FlowContainer`), а не абсолютными позициями: дети контейнера управляются через `size_flags_*` и `custom_minimum_size`, их `position`/`size` вручную не трогают. Якоря и смещения (anchors/offsets) нужны только корню экрана и плавающим элементам.
- Адаптивность: `stretch/mode = canvas_items` + `aspect = expand` и контейнеры, которые тянутся; проверяйте на нескольких соотношениях сторон и с длинными переводами. Шрифты — MSDF для крупного масштабируемого текста.
- Стиль — через `Theme` на корне UI и type variations, а не через `theme_override_*` на каждом узле: одна тема легко меняется и не размазывается по сценам.
- Анимации UI: до 4.7 анимировать `position` у детей контейнера бесполезно (контейнер перезапишет). В 4.7 у Control есть трансформации-смещения «без влияния на раскладку» — используйте их для hover/press-эффектов; в 4.6 добавлен `pivot_offset_ratio` (опорная точка в долях 0–1).
- Фокус и геймпад: задайте `focus_neighbor_*` или положитесь на автоматический поиск, вызывайте `grab_focus()` при открытии экрана. С 4.6 фокус мыши и клавиатуры разделён.
- Доступность: с 4.5 Control-узлы озвучиваются экранными дикторами через AccessKit (статус — экспериментальный; редактор поддержан частично). Заполняйте accessibility-имена и описания у нестандартных контролов, своими узлами управляйте через `AccessibilityServer`; в 4.7 добавлена навигация по ориентирам (landmarks). Демонстрация — `gui/accessibility`.
- Godot как фреймворк приложений: включите `application/run/low_processor_mode` (перерисовка только при изменениях, экономия батареи), отключите `display/window/subwindows/embed_subwindows` для настоящих системных окон, используйте `DisplayServer` для нескольких окон и нативных диалогов файлов (`DisplayServer.file_dialog_show()` или `FileDialog.use_native_dialog`; имена проверены на 4.7.2). Так построены сам редактор Godot, Pixelorama и Material Maker. С 4.6 есть LibGodot — встраивание движка в собственное приложение.
- Большие списки (тысячи строк) — `Tree`/`ItemList` или виртуализация вручную: не создавайте Control на каждый элемент. `RichTextLabel` с BBCode — для форматированного текста, тяжёлый при частом обновлении.
- 4.5: `FoldableContainer` (аккордеон). 4.7: поиск в `PopupMenu`, улучшенный drag-and-drop в `Tree`.

### Аддоны и инструменты
- Maaack's Godot Game Template (1.7.0, сентябрь 2026) — готовые меню, настройки, экран загрузки, пауза.
- Встроенный редактор тем (Theme Editor) и галерея контролов (демо `gui/control_gallery`).
- Pixelorama (1.2.3, сентябрь 2026) и Material Maker (1.7, июль 2026) — открытые приложения на Godot, эталоны архитектуры «не-игры».

### Ресурсы
| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [GUI tutorials](https://docs.godotengine.org/en/stable/tutorials/ui/index.html) | Godot docs, живой | Вход в раздел UI |
| [Using Containers](https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html) / [Size and anchors](https://docs.godotengine.org/en/stable/tutorials/ui/size_and_anchors.html) | Godot docs, живой | Как работают раскладка, якоря и size flags |
| [Theme editor](https://docs.godotengine.org/en/stable/tutorials/ui/gui_using_theme_editor.html) / [GUI skinning](https://docs.godotengine.org/en/stable/tutorials/ui/gui_skinning.html) | Godot docs, живой | Темы и type variations |
| [Keyboard/controller navigation](https://docs.godotengine.org/en/stable/tutorials/ui/gui_navigation.html) | Godot docs, живой | Фокус и навигация без мыши |
| [Control node gallery](https://docs.godotengine.org/en/stable/tutorials/ui/control_node_gallery.html) / [BBCode](https://docs.godotengine.org/en/stable/tutorials/ui/bbcode_in_richtextlabel.html) | Godot docs, живой | Обзор контролов и разметка `RichTextLabel` |
| [AccessibilityServer](https://docs.godotengine.org/en/stable/classes/class_accessibilityserver.html) / [AccessKit](https://accesskit.dev/) | Godot class ref / AccessKit, живой | API доступности и библиотека под ним |
| [Godot 4.5 release](https://godotengine.org/releases/4.5/) | Godot Foundation, 2025 | Экранные дикторы, `FoldableContainer` |
| [Godot 4.7 release](https://godotengine.org/releases/4.7/) | Godot Foundation, 2026 | Трансформации Control, landmarks, `VirtualJoystick` |
| [GUI demos](https://github.com/godotengine/godot-demo-projects/tree/master/gui) / [accessibility](https://github.com/godotengine/godot-demo-projects/tree/master/gui/accessibility) | Godot, 2026 | Темы, DnD, мультиразрешение, доступность |
| [Pixelorama](https://github.com/Orama-Interactive/Pixelorama) / [Material Maker](https://github.com/RodZill4/material-maker) | Orama Interactive / RodZill4, 2026 | Крупные приложения на Godot с открытым кодом |

---

## 4. Пошаговые, карточные, настольные и стратегические игры

### Ключевые выводы
- Отделите модель правил от сцен: состояние партии и правила — в классах `RefCounted` (или в Rust через GDExtension, см. раздел 11) без зависимости от узлов; сцены лишь отображают состояние и шлют намерения. Так правила тестируются headless (GUT/gdUnit4), работают для ИИ-перебора и сервера.
- Статичные данные контента (карты, юниты, способности) — пользовательские `Resource` с `class_name` и `@export`: редактируются в инспекторе, проверяются типами, грузятся `preload`. Изменяемое состояние экземпляра (текущее здоровье, жетоны) храните отдельно, а не в общем ресурсе: загруженный `.tres` один на всех, и правка поля меняет его у всех ссылок. Нужна копия — `duplicate(true)`: в 4.7.2 он копирует вложенные массивы, словари и встроенные подресурсы, но ресурсы из отдельных `.tres` оставляет общими; полную копию даёт `duplicate_deep(Resource.DEEP_DUPLICATE_ALL)` (метод появился в 4.5; проверено на 4.7.2).
- Эффекты карт — данными: массив ресурсов-эффектов (`DamageEffect`, `DrawEffect`) с методом `apply(state)` вместо огромного `match` по id. Новый эффект = новый маленький класс + ресурс.
- Ход — через команды: `Action` (намерение) → `validate(state)` → `apply(state)` → список `Event` для анимаций. Отмена — либо обратная операция в каждой команде, либо снимок состояния; встроенный `UndoRedo` работает и в игре, не только в редакторе. Журнал действий + сид = реплей и отладка.
- Детерминизм: один `RandomNumberGenerator` в состоянии партии с явными `seed` и сохраняемым `state`; не используйте глобальные `randi()`/`randf()`/`shuffle()` в правилах — они зависят от глобального сида. Перемешивание колоды — Фишер–Йейтс на этом RNG.
- Анимации событий проигрывайте очередью: модель уже применила ход мгновенно, презентация последовательно показывает события через `await` на твинах. В 4.7 `Tween.tween_await()` позволяет вставить ожидание сигнала прямо в цепочку твина. Ввод блокируйте на время проигрывания.
- Карты в руке — Control-узлы (раскладка, фокус, перетаскивание через `_get_drag_data`/`_can_drop_data`/`_drop_data`) или `Node2D` с собственным расположением по дуге; для поля с зумом удобнее `Node2D` + `Camera2D`.
- Сетки и поиск пути: `AStarGrid2D` — квадратные сетки (диагонали, веса клеток), `AStar2D`/`AStar3D` — произвольные графы (гексы, точки на карте). Гексы и координаты — по Red Blob Games.
- ИИ-перебор (минимакс, MCTS) на GDScript медленный из-за копирования состояний и вызовов через Variant: держите состояние компактным (`PackedInt32Array`), ограничьте глубину и время, считайте в `WorkerThreadPool` вне главного потока. Если перебор — ядро игры, вынесите правила и ИИ в GDExtension (C++/Rust).
- Сохранения — сериализуйте модель (словарь/JSON или `ResourceSaver` для своих ресурсов), а не дерево сцен. Журнал действий + сид часто компактнее снимка состояния.
- Сетевая карточная игра: скрытая информация (рука соперника, порядок колоды, RNG) живёт только на сервере, каждый клиент получает своё представление состояния. Иначе её достанет любой, кто прочитает трафик или память.

### Аддоны и инструменты
- GUT (9.7.1, июль 2026) и gdUnit4 (6.2.2, октябрь 2026) — тесты правил без сцены.
- godot-sqlite (4.9, август 2026) — если база карт или прогресса велика для `.tres`.
- Встроенные: `UndoRedo`, `AStarGrid2D`, `RandomNumberGenerator`, `Tween`.

### Ресурсы
| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html) | Godot docs, живой | Пользовательские ресурсы, совместное использование, `local_to_scene` |
| [Data preferences](https://docs.godotengine.org/en/stable/tutorials/best_practices/data_preferences.html) | Godot docs, живой | Массивы, словари, объекты — что выбрать для данных |
| [UndoRedo](https://docs.godotengine.org/en/stable/classes/class_undoredo.html) / [RefCounted](https://docs.godotengine.org/en/stable/classes/class_refcounted.html) | Godot class ref, живой | Отмена действий и легковесные объекты модели |
| [AStarGrid2D](https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html) | Godot class ref, живой | Поиск пути на сетке |
| [Saving games](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html) | Godot docs, живой | Сериализация состояния |
| [Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html) | Godot class ref, живой | Цепочки анимаций, `tween_await()` (4.7) |
| [Command pattern](https://gameprogrammingpatterns.com/command.html) | Robert Nystrom, 2014 | Команды, отмена, реплеи |
| [Red Blob Games](https://www.redblobgames.com/) / [A*](https://www.redblobgames.com/pathfinding/a-star/introduction.html) | Amit Patel, живой | Гекс-сетки, поиск пути, генерация карт |
| [Drag and drop demo](https://github.com/godotengine/godot-demo-projects/tree/master/gui/drag_and_drop) / [RPG demo](https://github.com/godotengine/godot-demo-projects/tree/master/2d/role_playing_game) | Godot, 2026 | Перетаскивание Control и пошаговый бой |
| [GUT](https://github.com/bitwes/Gut) / [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) | bitwes / godot-gdunit-labs, 2026 | Тестирование правил |

---

## 5. ИИ и навигация

### Ключевые выводы
- Навигация: `NavigationRegion2D/3D` с запечённой navmesh + `NavigationAgent2D/3D` на персонаже. Агент не двигает тело сам — каждый физический кадр берите `get_next_path_position()`, считайте скорость и двигайте `CharacterBody`. Выставляйте `path_desired_distance`/`target_desired_distance` под размер агента.
- Первый запрос пути после старта сцены возвращает пустой путь. С настройками по умолчанию (асинхронная синхронизация карты и регионов) одного `await get_tree().physics_frame` мало: на 4.7.2 путь появился только после второго `map_changed`, на 4–5-м физическом кадре (проверено на 4.7.2). Ждите `NavigationServer*.map_changed`, пока запрос не вернёт непустой путь, — образец в [physics-navigation.md](physics-navigation.md#навигация-сервер-регионы-запекание).
- Избегание столкновений (RVO): включите `avoidance_enabled`, задайте желаемую скорость через `velocity`, а реальную берите из сигнала `velocity_computed`. Динамические препятствия — `NavigationObstacle2D/3D`. Избегание не заменяет перестроение пути — это локальная коррекция.
- С 4.5 2D-навигация работает на отдельном 2D-сервере (без зависимости от 3D), а запекание регионов идёт в фоновых потоках. Большие миры — чанки navmesh (демо `navigation_mesh_chunks`); перезапекание во время игры — `NavigationServer*.bake_from_source_geometry_data_async`.
- Для клеточных игр navmesh избыточна — `AStarGrid2D`/`AStar2D` проще и детерминированнее.
- Принятие решений по сложности: FSM (`enum` + `match` или узлы-состояния) → иерархические состояния (godot-statecharts, HSM в LimboAI) → деревья поведения (LimboAI, Beehave) → utility AI или GOAP для открытого выбора целей. Не тащите BT туда, где хватает пяти состояний.
- LimboAI написан на C++ (модуль движка и GDExtension), задачи можно писать на GDScript; есть визуальный отладчик и blackboard. Beehave — чистый GDScript, проще встроить, но медленнее на сотнях агентов.
- GOAP и utility AI: крупных зрелых аддонов нет; из активных в 2026 — GOAP-фреймворки [GdPlanningAI](https://github.com/WahahaYes/GdPlanningAI) и [goap-godot-4](https://github.com/pixelrogueart/goap-godot-4) (Apache-2.0 и MIT, пользователей немного). Их легко написать и самим на `RefCounted` (оценочные функции, кривые на `Curve`-ресурсах). Не пересчитывайте решения каждый кадр — тикайте ИИ по таймеру или раз в N кадров, распределяя агентов по кадрам.
- Рулевое поведение (seek/flee/arrive/separation) — несколько строк векторной математики; GDQuest Steering AI Framework остался на Godot 3 — `[устарело]`.

### Аддоны и инструменты
- LimboAI (1.8.1, август 2026; собран под 4.7.2) — деревья поведения + иерархические автоматы, отладчик, blackboard.
- Beehave (2.9.3, август 2026; совместим с 4.7) — деревья поведения на GDScript, отладочная панель.
- godot-statecharts (0.22.5) — statecharts для ИИ и персонажей.
- Встроенные: `NavigationServer2D/3D`, `NavigationAgent`, `NavigationObstacle`, `AStarGrid2D`.

### Ресурсы
| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Navigation](https://docs.godotengine.org/en/stable/tutorials/navigation/index.html) | Godot docs, живой | Весь раздел: регионы, агенты, слои, links |
| [2D navigation overview](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_introduction_2d.html) | Godot docs, живой | Быстрый старт 2D |
| [Using NavigationAgents](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html) / [NavigationObstacles](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationobstacles.html) | Godot docs, живой | Движение по пути и избегание |
| [Using NavigationServer](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationservers.html) | Godot docs, живой | Прямые запросы к серверу, синхронизация |
| [Navigation demos](https://github.com/godotengine/godot-demo-projects/tree/master/2d/navigation) / [3D](https://github.com/godotengine/godot-demo-projects/tree/master/3d/navigation) | Godot, 2026 | Рабочие примеры агентов и navmesh |
| [LimboAI docs](https://limboai.readthedocs.io/) | limbonaut, 2026 | BT, HSM, blackboard, пользовательские задачи |
| [Beehave](https://bitbrain.github.io/beehave/) | bitbrain, 2026 | BT на GDScript |
| [godot-statecharts](https://github.com/derkork/godot-statecharts) | derkork, 2026 | Иерархические состояния |
| [Game AI Pro](https://www.gameaipro.com/) | Steve Rabin (ред.), 2013–2019 | Бесплатные главы про BT, utility AI, GOAP, навигацию |
| [Steering AI Framework](https://github.com/gdquest/godot-steering-ai-framework) | GDQuest, 2020 | `[устарело]` — Godot 3; идеи рулевого поведения актуальны |

---

## 6. Процедурная генерация и инструменты редактора

### Ключевые выводы
- Воспроизводимость: генерация — только через собственный `RandomNumberGenerator` с сохраняемым `seed`; отдельный RNG на подсистему (рельеф, лут, враги), чтобы изменение одной не сдвигало другие. Шум — `FastNoiseLite` (Simplex, Perlin, Cellular, Value; фрактальные режимы и domain warp) с тем же сидом; `NoiseTexture2D` — для предпросмотра и шейдеров.
- Генерация тяжела — считайте данные (массивы высот, сетку клеток) в `WorkerThreadPool`, а в дерево сцены кладите результат в главном потоке (`call_deferred` или по сигналу). Само дерево сцен не потокобезопасно. Меши собирайте `SurfaceTool`/`ArrayMesh`, массово — `MultiMesh`.
- Тайлы: запись в `TileMapLayer` пачками; для WFC и правил соседства — аддон на основе constraint solving (обучение правил по примеру, бэктрекинг, многопоточность). Подземелья — BSP-деление, клеточные автоматы, «пьяный ходок», комнаты + MST-коридоры; на сетке достаточно своего кода на `PackedInt32Array`.
- `@tool` превращает скрипт в работающий в редакторе: проверяйте `Engine.is_editor_hint()`, чтобы игровая логика не выполнялась в редакторе, и помните, что ошибки в `@tool`-скрипте могут портить сцены. Кнопка-действие в инспекторе — `@export_tool_button` (4.4+).
- Плагин редактора: папка `addons/<имя>/` с `plugin.cfg` и скриптом `@tool extends EditorPlugin`; всё, что добавили в `_enter_tree()` (доки, инструменты, инспекторы, импортёры), удаляйте в `_exit_tree()`. Свои редакторы свойств — `EditorInspectorPlugin`; свои форматы файлов — `EditorImportPlugin`; доработка импортированных 3D-сцен — `EditorScenePostImport`.
- Доки: в 4.6 все панели редактора стали перемещаемыми и появился класс `EditorDock`. В документации 4.7 `add_control_to_dock()` и `add_control_to_bottom_panel()` помечены устаревшими: используйте `add_dock(dock: EditorDock)` и `remove_dock()`, нижнюю панель задаёт `EditorDock.default_slot = DOCK_SLOT_BOTTOM`. Старые методы в 4.7.2 ещё работают. В 4.8-dev главные экраны тоже становятся доками.
- Генераторы-инструменты (запуск генерации кнопкой в редакторе с сохранением результата в сцену) удобнее для дизайнеров, чем рантайм-генерация: результат можно поправить вручную.

### Аддоны и инструменты
- Gaea 2.0 — графовый редактор генерации 2D/3D (для 4.4+, «в ранней разработке»; последний GitHub-релиз — 1.4.1 от апреля 2025, ветка 2.0 активна).
- WFC / godot-constraint-solving (1.7, 2024) — Wave Function Collapse для `TileMapLayer`/`GridMap`.
- Zylann Voxel Tools (1.7), Terrain3D (1.0.2), Spatial Scatter — генерация мира и размещение объектов.
- Встроенные: `FastNoiseLite`, `RandomNumberGenerator`, `SurfaceTool`, `WorkerThreadPool`, демо `misc/noise_viewer`.

### Ресурсы
| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Random number generation](https://docs.godotengine.org/en/stable/tutorials/math/random_number_generation.html) | Godot docs, живой | Сиды, `RandomNumberGenerator`, взвешенный выбор |
| [FastNoiseLite](https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html) | Godot class ref, живой | Типы шума и параметры |
| [Procedural geometry](https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/index.html) / [SurfaceTool](https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/surfacetool.html) | Godot docs, живой | Генерация мешей |
| [Running code in the editor](https://docs.godotengine.org/en/stable/tutorials/plugins/running_code_in_the_editor.html) | Godot docs, живой | `@tool`, `is_editor_hint`, подводные камни |
| [Making plugins](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/making_plugins.html) / [Editor plugins](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/index.html) | Godot docs, живой | `plugin.cfg`, `EditorPlugin`, доки |
| [Inspector plugins](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/inspector_plugins.html) / [Import plugins](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/import_plugins.html) | Godot docs, живой | Свои редакторы свойств и импортёры |
| [EditorScenePostImport](https://docs.godotengine.org/en/stable/classes/class_editorscenepostimport.html) | Godot class ref, живой | Автоматическая обработка импортированных сцен |
| [Gaea](https://github.com/gaea-godot/gaea) / [docs](https://gaea-docs.readthedocs.io/) | gaea-godot, 2026 | Графовая процедурная генерация |
| [godot-constraint-solving](https://github.com/AlexeyBond/godot-constraint-solving) | Alexey Bond, 2024 | WFC для тайлмапов и GridMap |
| [WaveFunctionCollapse](https://github.com/mxgmn/WaveFunctionCollapse) | Maxim Gumin, 2016 | Оригинальный алгоритм и объяснение |
| [Plugin demos](https://github.com/godotengine/godot-demo-projects/tree/master/plugins) | Godot, 2026 | Примеры доков, инспекторов, импортёров |
| [Voxel Tools](https://github.com/Zylann/godot_voxel) | Marc Gilleron, 2026 | Воксельные миры |

---

## 7. Диалоги, нарратив и локализация

### Ключевые выводы
- Выбор инструмента. Dialogue Manager — текстовый формат `.dialogue` в стиле сценария, условия и мутации прямо в GDScript-выражениях, лёгкий рантайм; хорош для большинства игр. Dialogic 2 — полный визуальный пакет (портреты, таймлайны, стили, сохранения) для визуальных новелл, но всё ещё в альфе с ломающими изменениями между альфами. Ink — если сценарист уже пишет в Inky; Yarn Spinner — если команда знает его по Unity.
- Ink в Godot 4: godot-ink требует C# (.NET); inkgd — чистый GDScript, без официальных релизов для Godot 4 (ветка `godot4`) и медленнее C#-рантайма. Yarn Spinner for Godot — основная версия на C#, проект в статусе «work in progress» без официальной поддержки.
- Отделяйте диалоговый рантайм от UI: рантайм выдаёт строки и варианты, а балун/окно — отдельная сцена, подписанная на события. Состояние мира, на которое смотрят диалоги (флаги, квесты), держите в одном автозагружаемом объекте или ресурсе — его же сохраняйте.
- Локализация: все строки UI — ключи, перевод через `tr()`/`tr_n()` (множественные формы); Control автоматически переводит текст при `auto_translate_mode`. Форматы — CSV (просто, удобно в таблицах; с 4.6 поддерживает столбцы контекста и множественных форм) или gettext PO/POT (стандарт для переводчиков, плюралы, контекст). Шаблон POT генерируется из сцен и скриптов в настройках локализации проекта.
- Переключение языка — `TranslationServer.set_locale()`; динамически собранные строки обновляйте по `NOTIFICATION_TRANSLATION_CHANGED`. Не склеивайте фразы из кусков — используйте форматирование с плейсхолдерами (`tr("HP_LEFT").format({...})`), порядок слов в языках разный.
- Проверка до перевода: псевдолокализация (удлинение строк, акценты) ловит обрезанный текст и захардкоженные строки; с 4.5 предпросмотр перевода прямо в редакторе. Для RTL и сложных письменностей Godot поддерживает BiDi и шейпинг; подключите fallback-шрифты для CJK.
- Диалоговые аддоны умеют экспортировать строки: Dialogue Manager — в CSV и шаблоны локализации со статическими id (4.1), Yarn Spinner — собственный CSV с контекстом.

### Аддоны и инструменты
- Dialogue Manager (4.1.0, сентябрь 2026) — диалоги в текстовом формате, UID в путях, CSV-экспорт; поддерживает Godot 4.7.
- Dialogic (2.0-alpha-20, июль 2026; Godot 4.5+, рекомендуется 4.6+) — визуальный редактор диалогов и VN-функции; старые сохранения и пользовательские подсистемы ломаются между альфами.
- godot-ink (1.1.2, 2024) — Ink через C#; inkgd — Ink на GDScript, ветка `godot4`.
- Yarn Spinner for Godot (0.3.23, октябрь 2026) — C#-интеграция, WIP.
- Встроенные: `TranslationServer`, CSV/PO-импорт, генерация POT, псевдолокализация.

### Ресурсы
| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) / [docs](https://dialogue.nathanhoad.net/) | Nathan Hoad, 2026 | Синтаксис, балуны, локализация |
| [Dialogic docs](https://docs.dialogic.pro/) | Dialogic team, 2026 | Таймлайны, персонажи, стили |
| [godot-ink](https://github.com/paulloz/godot-ink) / [inkgd](https://github.com/ephread/inkgd) | Paul Joannon / Frédéric Maquin, 2024 | Две интеграции Ink и их компромиссы |
| [ink](https://www.inklestudios.com/ink/) | inkle, живой | Язык сценариев и редактор Inky |
| [Yarn Spinner for Godot](https://github.com/YarnSpinnerTool/YarnSpinner-Godot) / [Yarn Spinner docs](https://docs.yarnspinner.dev/) | Yarn Spinner team, 2026 | Yarn-диалоги в Godot |
| [Internationalizing games](https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html) | Godot docs, живой | `tr()`, автоматический перевод, переключение локали |
| [Localization using gettext](https://docs.godotengine.org/en/stable/tutorials/i18n/localization_using_gettext.html) / [spreadsheets](https://docs.godotengine.org/en/stable/tutorials/i18n/localization_using_spreadsheets.html) | Godot docs, живой | PO/POT и CSV |
| [Pseudolocalization](https://docs.godotengine.org/en/stable/tutorials/i18n/pseudolocalization.html) | Godot docs, живой | Проверка UI до перевода |
| [TranslationServer](https://docs.godotengine.org/en/stable/classes/class_translationserver.html) | Godot class ref, живой | API локалей |
| [Translation demo](https://github.com/godotengine/godot-demo-projects/tree/master/gui/translation) | Godot, 2026 | Рабочий пример CSV/PO и переключения |

---

## 8. Аудио

### Ключевые выводы
- Узлы: `AudioStreamPlayer` — неспозиционный звук (музыка, UI), `AudioStreamPlayer2D/3D` — пространственный с затуханием. Для частых коротких звуков задайте `max_polyphony` или используйте `AudioStreamPolyphonic` вместо создания нового плеера на каждый выстрел; вариации высоты и выбор из набора — `AudioStreamRandomizer`.
- Шины: заведите шины `Music`, `SFX`, `UI`, `Voice` в `default_bus_layout.tres` и назначайте их плеерам; громкость в настройках меняйте на шине (`AudioServer.set_bus_volume_db` с `linear_to_db`), эффекты (реверб, компрессор, ducking через sidechain) — тоже на шинах.
- Интерактивная музыка (4.3+): `AudioStreamInteractive` — клипы и правила переходов (по такту, с кроссфейдом, через переходный клип); `AudioStreamSynchronized` — стемы, играющие синхронно, громкость слоёв меняется по ситуации; `AudioStreamPlaylist` — последовательность треков. Для многих игр этого достаточно без внешнего middleware.
- Импорт: музыку — Ogg Vorbis или MP3 (стриминг), короткие эффекты — WAV (без декодирования); выставляйте loop в настройках импорта, а не кодом.
- Web (4.3+): по умолчанию звук идёт через Web Audio как сэмплы — малая задержка, но эффекты шин на них не действуют; если эффекты важны, переключите плеер в потоковый режим (ценой задержки). Браузер не запускает звук до первого жеста пользователя.
- Ритм-игры и синхронизация с битом: опирайтесь на `AudioServer.get_time_since_last_mix()` и `get_output_latency()`, а не на `_process`-таймеры (демо `bpm_sync`, `rhythm_game`).
- FMOD или Wwise оправданы, когда звукорежиссёр работает в их инструментах (адаптивная музыка, параметры, live update) или проект портируется на консоли с уже настроенным middleware. Обе интеграции — GDExtension; проверяйте наличие сборки под вашу версию Godot.

### Аддоны и инструменты
- FMOD GDExtension (6.1.0 под Godot 4.5, сентябрь 2025) — узлы `FmodEventEmitter2D/3D`, `FmodEventListener2D/3D`, live update. Релизов под 4.6/4.7 нет (на октябрь 2026), коммиты в master идут (июнь 2026). Сборка под API 4.5 по правилам GDExtension должна грузиться в 4.6/4.7, но проверьте на своей версии.
- Wwise Godot Integration (2026.1.3, сентябрь 2026) — GDExtension для Windows, macOS, Linux, Android, iOS и (экспериментально) Web; узлы `AkEvent2D/3D`, `AkBank`, `AkListener`, комнаты и порталы, подключение профайлера.
- Встроенные: `AudioStreamInteractive`, `AudioStreamSynchronized`, `AudioStreamPlaylist`, `AudioStreamRandomizer`, `AudioStreamGenerator`.

### Ресурсы
| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Audio](https://docs.godotengine.org/en/stable/tutorials/audio/index.html) | Godot docs, живой | Вход в раздел |
| [Audio buses](https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html) / [Audio streams](https://docs.godotengine.org/en/stable/tutorials/audio/audio_streams.html) | Godot docs, живой | Шины, эффекты, типы потоков и плееров |
| [AudioStreamInteractive](https://docs.godotengine.org/en/stable/classes/class_audiostreaminteractive.html) / [AudioStreamSynchronized](https://docs.godotengine.org/en/stable/classes/class_audiostreamsynchronized.html) | Godot class ref, живой | Интерактивная музыка без middleware |
| [Audio demos](https://github.com/godotengine/godot-demo-projects/tree/master/audio) | Godot, 2026 | Эффекты, синхронизация с BPM, ритм-игра, генератор, микрофон |
| [Exporting for the Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html) | Godot docs, живой | Раздел про сэмпловый звук на Web |
| [FMOD GDExtension](https://github.com/utopia-rise/fmod-gdextension) / [docs](https://fmod-gdextension.readthedocs.io/en/latest/) | Utopia-rise, 2025 | Интеграция FMOD Studio |
| [Wwise Godot Integration](https://github.com/alessandrofama/wwise-godot-integration) | Alessandro Famà, 2026 | Интеграция Wwise |

---

## 9. Шейдеры и VFX

### Ключевые выводы
- Язык шейдеров Godot — упрощённый GLSL с типами `shader_type`: `canvas_item` (2D и UI), `spatial` (3D), `particles` (логика частиц на GPU), `sky`, `fog`. Начинайте с функций `fragment()`/`vertex()`/`light()`; встроенные переменные (`UV`, `COLOR`, `ALBEDO`, `TIME`) описаны в shader reference.
- Визуальные шейдеры — тот же результат в графе узлов, удобно художникам; сложную математику выносите в текстовые шейдеры или Expression-узлы. В 4.7 у текстовых шейдеров появился встроенный предпросмотр, в 4.8-dev — группы узлов для больших графов.
- Параметры: `uniform` с подсказками (`hint_range`, `source_color`) редактируются в инспекторе; меняйте их через `set_shader_parameter` на материале. Если у тысяч объектов разные значения — `instance uniform` вместо уникальных материалов (уникальный материал = отдельный draw call).
- Компиляция: фризы при первом показе эффекта — частая проблема; ubershaders (4.4) и shader baker (4.5, сокращение времени загрузки до 20 раз на некоторых платформах) решают большую часть. Избегайте ветвлений, порождающих много вариантов шейдеров.
- Частицы: `GPUParticles2D/3D` — тысячи частиц, коллизии, субэмиттеры, трейлы (трейлов нет в Compatibility); `CPUParticles` — предсказуемо на слабом железе и для малого числа частиц. Однократные вспышки — `one_shot` + `emitting = true`; переиспользуйте узлы, а не инстанцируйте сцену на каждый взрыв. 4.8-dev добавляет нативный `Trail3D`.
- Пост-обработка: в 2D — `CanvasLayer` + `ColorRect` с `canvas_item`-шейдером, читающим `screen_texture` (`hint_screen_texture`); в 3D — квад перед камерой или Compositor (4.3+, только Forward+ и Mobile): `CompositorEffect` с `_render_callback` работает в потоке рендера, поэтому общие с игрой данные защищайте мьютексом.
- Compute-шейдеры через `RenderingDevice` (GLSL) — для симуляций и генерации на GPU; недоступны в Compatibility и, следовательно, на Web. Чтение результата с GPU синхронно и дорого — держите данные на GPU (текстуры, буферы) где возможно.
- Стенсил-буфер (4.5) позволяет эффекты «видно сквозь стену», порталы, контуры без лишних проходов.

### Аддоны и инструменты
- Встроенные: редактор визуальных шейдеров, `ShaderInclude` (`.gdshaderinc`) для общих функций, редактор кривых частиц.
- GDQuest Godot Shaders (репозиторий 2024–2026) — открытая коллекция 2D/3D-шейдеров.
- Godot Shaders (godotshaders.com) — каталог шейдеров сообщества; проверяйте версию Godot у каждого примера.

### Ресурсы
| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Introduction to shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/introduction_to_shaders.html) / [Shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/index.html) | Godot docs, живой | Типы шейдеров, первые шаги |
| [Shading reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/index.html) | Godot docs, живой | Встроенные переменные и функции по типам |
| [Visual shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/visual_shaders.html) | Godot docs, живой | Граф узлов |
| [Shaders style guide](https://docs.godotengine.org/en/stable/tutorials/shaders/shaders_style_guide.html) | Godot docs, живой | Оформление шейдерного кода |
| [3D particles](https://docs.godotengine.org/en/stable/tutorials/3d/particles/index.html) / [2D particles](https://docs.godotengine.org/en/stable/tutorials/2d/particle_systems_2d.html) | Godot docs, живой | Системы частиц |
| [The Compositor](https://docs.godotengine.org/en/stable/tutorials/rendering/compositor.html) | Godot docs, живой | Свои проходы пост-обработки в 3D |
| [Compute shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/compute_shaders.html) / [RenderingDevice](https://docs.godotengine.org/en/stable/classes/class_renderingdevice.html) | Godot docs, живой | GPU-вычисления |
| [Compute demos](https://github.com/godotengine/godot-demo-projects/tree/master/compute) | Godot, 2026 | Heightmap, пост-шейдер, текстура |
| [GDQuest Godot Shaders](https://github.com/gdquest-demos/godot-shaders) | GDQuest, 2024–2026 | Готовые эффекты с исходниками |
| [2D lights and shadows](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html) | Godot docs, живой | Освещение в 2D |

---

## 10. Мультиплеер и платформы

### Ключевые выводы
- Мультиплеер: высокоуровневый API (`MultiplayerSpawner`, `MultiplayerSynchronizer`, `@rpc`) поверх ENet, WebSocket или WebRTC; сервер авторитетен, клиент шлёт намерения. Rollback и предсказание — netfox. Подробные правила, безопасность и выделенный сервер — в [signals-async-threads.md](signals-async-threads.md).
- Web: Godot 4 на Web использует только Compatibility (WebGL 2.0). С 4.3 доступен однопоточный экспорт — он не требует заголовков cross-origin isolation и работает на большинстве хостингов (itch.io и т. п.); многопоточный экспорт требует `Cross-Origin-Opener-Policy: same-origin` и `Cross-Origin-Embedder-Policy: require-corp` (или PWA-режима с service worker). С 4.5 включён WebAssembly SIMD. Проекты на C# в Godot 4 на Web не экспортируются.
- Web-практика: держите размер `.pck` и `.wasm` малым (сжатие на сервере, урезанные шаблоны), не опирайтесь на потоки и compute-шейдеры, звук запускайте после жеста пользователя, связь со страницей — `JavaScriptBridge`.
- Android: с 4.6 сборка через Gradle возможна прямо на устройстве с помощью компаньона GABE; 4.7 — PiP, свой splash, реализация Java-интерфейсов из GDScript, `VirtualJoystick` и гироскоп из коробки. Учитывайте 16 KB-страницы и edge-to-edge (4.5). Плагины — Android plugin v2 (AAR + GDExtension).
- iOS: экспорт только с macOS и Xcode; C# на мобильных — экспериментальный. Для мобильных по умолчанию рендерер Mobile, для старых устройств — Compatibility.
- Консоли: официальных консольных шаблонов нет и не будет в открытом виде — SDK платформ под NDA, шаблоны собираются с ними и распространяются только среди одобренных разработчиков. Пути: W4 Games (Switch, Xbox Series, PS5), RAWRLAB Games или студии портирования (Lone Wolf Technology, Pineapple Works, Sickhead Games и др.). Закладывайте это в бюджет; GDExtension-зависимости тоже придётся собрать под консоль.
- Steam: GodotSteam (модуль, GDExtension и серверная версия; основной хостинг переехал на Codeberg) — достижения, лидерборды, облако, лобби и Steam Networking. Steam Deck: Linux-сборка запускается нативно; проверьте 1280×800 и масштаб UI, глифы геймпада, экранную клавиатуру для текстовых полей, паузу при сворачивании — по рекомендациям Valve.
- XR: OpenXR встроен; 4.6–4.7 — Android XR, OpenXR 1.1, Steam Frame.
- Релиз: экспорт собирайте в CI из `export_presets.cfg` (`--headless --export-release`), заливайте на itch.io утилитой butler, в Steam — через SteamPipe. Отчёты о падениях и ошибках скриптов собирает официальный Sentry SDK для Godot (аддон; ошибки GDScript со стеками, нативные краши на десктопе, мобильных и Web). Аналитику и сбор данных делайте с согласия игрока.

### Аддоны и инструменты
- GodotSteam (4.23, октябрь 2026) — Steamworks API.
- netfox (1.49.4 в `main`; последний релиз на GitHub — 1.35.3) — rollback, интерполяция и lag compensation.
- GABE — Android Build Environment внутри Godot (4.6+).
- Встроенные: `MultiplayerAPI`, `ENetMultiplayerPeer`, `WebSocketMultiplayerPeer`, `WebRTCMultiplayerPeer`, `JavaScriptBridge`.

### Ресурсы
| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [High-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html) / [Networking](https://docs.godotengine.org/en/stable/tutorials/networking/index.html) | Godot docs, живой | RPC, авторитетность, пиры |
| [Networking demos](https://github.com/godotengine/godot-demo-projects/tree/master/networking) | Godot, 2026 | Bomber, Pong, WebRTC, WebSocket |
| [netfox](https://github.com/foxssake/netfox) | Fox's Sake Studio, 2025–2026 | Rollback-неткод |
| [Exporting for the Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html) / [Web platform](https://docs.godotengine.org/en/stable/tutorials/platform/web/index.html) | Godot docs, живой | Потоки, заголовки, звук, `JavaScriptBridge` |
| [Web progress report 9](https://godotengine.org/article/godot-web-progress-report-9/) | Godot Foundation, 2024 | Почему появился однопоточный экспорт |
| [Exporting for Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) / [Android plugins](https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html) | Godot docs, живой | Экспорт и плагины |
| [Exporting for iOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html) | Godot docs, живой | Xcode-проект, подпись |
| [Console support](https://godotengine.org/consoles/) | Godot Foundation, живой | Почему нет официальных портов, список партнёров |
| [W4 Games](https://www.w4games.com/) | W4 Games, живой | Коммерческие консольные порты Godot |
| [GodotSteam](https://godotsteam.com/) / [Codeberg](https://codeberg.org/godotsteam/godotsteam) | GodotSteam, 2026 | Документация и исходники |
| [Steam Deck docs](https://partner.steamgames.com/doc/steamdeck) / [рекомендации](https://partner.steamgames.com/doc/steamdeck/recommendations) | Valve, живой | Требования к совместимости |
| [Dedicated servers](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html) | Godot docs, живой | Headless-сборка сервера |
| [Sentry for Godot](https://docs.sentry.io/platforms/godot/) / [sentry-godot](https://github.com/getsentry/sentry-godot) | Sentry, 2.3.0 (сентябрь 2026) | Отчёты о падениях и ошибках |
| [butler](https://itch.io/docs/butler/) / [Uploading to Steam](https://partner.steamgames.com/doc/sdk/uploading) | itch.io / Valve, живой | Выкладка сборок на itch.io и в Steam |

---

## 11. Interop: C#, GDExtension, godot-rust

### Ключевые выводы
- Когда что. GDScript — геймплей, UI, склейка сцен, быстрые итерации (по умолчанию). C# — команде привычен .NET, нужна экосистема NuGet, тяжёлая логика с хорошей производительностью; ограничения — нет Web-экспорта, мобильные платформы экспериментальны, нужна .NET-сборка редактора. GDExtension (C++, Rust и др.) — горячие алгоритмы, симуляция и правила, интеграция нативных библиотек (FMOD, Steam, SQLite); собирается под каждую платформу, работает на Web и не требует пересборки движка. Модуль движка — только если нужно менять сам движок.
- GDScript ↔ C#: из GDScript C#-класс создаётся как `load("res://Player.cs").new()` (класс должен называться как файл), свойства и методы доступны напрямую. Из C# к GDScript — только динамически: `Get()`/`Set()`, `Call()`, `Connect()` по строковым именам; вызов с недостающими аргументами молча не выполнится. Наследоваться между языками нельзя; через границу передавайте только Variant-совместимые типы. Имена: в GDScript snake_case, в C# PascalCase — при вызове C# из GDScript используйте C#-имена.
- GDExtension-классы для GDScript неотличимы от встроенных: регистрируются в ClassDB, видны в «Добавить узел», получают автодополнение и документацию. Значит, API-границу проектируйте как API движка: крупные методы, сигналы для событий, `Packed*Array` и словари вместо мелких вызовов на элемент — пересечение границы стоит дороже вызова внутри языка.
- Совместимость версий: расширение, собранное под API 4.x, работает в 4.x и новее, но не в более старых. godot-cpp с версии 10 версионируется отдельно от Godot и нацеливается на нужную версию параметром `api_version` (поддержка от 4.3). godot-rust требует минимум Godot 4.2 и выбирает API feature-флагом `api-4-*`.
- godot-rust (gdext, крейт `godot` 0.5.x): классы через `#[derive(GodotClass)]` и `#[godot_api]`, методы для GDScript — `#[func]`, сигналы — `#[signal]`, свойства — `#[var]`/`#[export]`; объекты движка — `Gd<T>`. В 0.5 — Rust edition 2024 (MSRV 1.94), типизированные `Dictionary<K, V>`, non-null API (например, `Node::get_tree()`); в 0.5.3 генерация привязок без bindgen/LLVM; в 0.5.4 — уровень `api-4-7` и типобезопасные пользовательские RPC; в 0.5.5 `#[func(virtual)]` поддерживает `async fn` для корутин GDScript.
- Архитектура Rust + Godot (как в проекте пользователя): ядро правил — обычный Rust-крейт без зависимости от `godot`; тонкий `cdylib`-мост регистрирует классы-фасады и переводит события ядра в сигналы; сцены, анимации и UI — в GDScript и редакторе. Так ядро тестируется `cargo test`, а GDScript-часть остаётся быстро итерируемой. Включайте `reloadable = true` в `.gdextension` для hot reload; паника в Rust при доступе к освобождённому `Gd` — ожидаемое поведение, проверяйте валидность (`is_instance_valid`) на стороне вызовов.
- Сборка и релиз: `.gdextension`-файл перечисляет библиотеки по платформам и конфигурациям (`debug`/`release`); в CI собирайте под все целевые платформы, включая Web (Emscripten) и Android, иначе экспорт на них упадёт при загрузке. В 4.7 подключённые GDExtension видны в настройках проекта.
- Закрепляйте версии: точная версия крейта `godot` или тег godot-cpp + версия Godot в `project.godot`; перед обновлением читайте changelog — API привязок меняется быстрее, чем API движка.

### Аддоны и инструменты
- godot-rust / gdext (`godot` 0.5.5, август 2026) — Rust-привязки к GDExtension.
- godot-cpp (10.0.0, сентябрь 2026) — официальные C++-привязки, `godot-cpp-template` для старта.
- .NET-сборка Godot — C#: по документации stable нужен .NET 8 или новее, для экспорта на Android — .NET 9 или новее. IDE — Visual Studio 2022, Rider или VS Code с расширением C# (`ms-dotnettools.csharp`).

### Ресурсы
| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Cross-language scripting](https://docs.godotengine.org/en/stable/tutorials/scripting/cross_language_scripting.html) | Godot docs, живой | Вызовы GDScript ↔ C#, ограничения |
| [C# basics](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/index.html) | Godot docs, живой | Поддержка платформ, настройка .NET |
| [What is GDExtension](https://docs.godotengine.org/en/stable/engine_details/engine_api/gdextension/what_is_gdextension.html) | Godot docs, живой | Когда выбирать GDExtension, модуль или скрипт |
| [godot-cpp example](https://docs.godotengine.org/en/stable/tutorials/scripting/cpp/gdextension_cpp_example.html) / [About godot-cpp](https://docs.godotengine.org/en/stable/tutorials/scripting/cpp/about_godot_cpp.html) | Godot docs, живой | Первый C++-класс |
| [godot-cpp](https://github.com/godotengine/godot-cpp) / [template](https://github.com/godotengine/godot-cpp-template) | Godot, 2026 | Версионирование v10, `api_version` |
| [godot-rust book](https://godot-rust.github.io/book/) | godot-rust team, живой | Установка, классы, объекты, экспорт |
| [Hello World](https://godot-rust.github.io/book/intro/hello-world.html) / [Registering classes](https://godot-rust.github.io/book/register/classes.html) / [functions](https://godot-rust.github.io/book/register/functions.html) | godot-rust team, живой | Базовая раскладка проекта и регистрация API |
| [Objects (Gd)](https://godot-rust.github.io/book/godot-api/objects.html) | godot-rust team, живой | Владение и время жизни объектов движка |
| [Compatibility](https://godot-rust.github.io/book/toolchain/compatibility.html) / [Export to Web](https://godot-rust.github.io/book/toolchain/export-web.html) | godot-rust team, живой | Выбор `api-4-*`, сборка под Wasm |
| [gdext](https://github.com/godot-rust/gdext) / [Changelog](https://github.com/godot-rust/gdext/blob/master/Changelog.md) / [docs.rs](https://docs.rs/godot/latest/godot/) | godot-rust team, 2026 | Исходники, изменения, API-справка |
| [C# demos](https://github.com/godotengine/godot-demo-projects/tree/master/mono) | Godot, 2026 | Примеры проектов на C# |

---

## Общие ресурсы по доменам

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [godot-demo-projects](https://github.com/godotengine/godot-demo-projects) | Godot, тег 4.7 (июль 2026) | Официальные демо по всем доменам; сверяйтесь с ними при сомнениях |
| [GDQuest Library](https://www.gdquest.com/library/) / [GDQuest School](https://school.gdquest.com/) / [YouTube](https://www.youtube.com/@Gdquest) | GDQuest (Nathan Lovato), живой | Курсы и статьи по GDScript, архитектуре, шейдерам |
| [Godot Recipes](https://kidscancode.org/godot_recipes/4.x/) | KidsCanCode, живой | Рецепты по 2D/3D/UI |
| [Awesome Godot](https://github.com/godotengine/awesome-godot) | сообщество, живой | Каталог аддонов и проектов |
| [Godot Asset Store](https://store.godotengine.org/) / [Asset Library](https://godotengine.org/asset-library/asset) | Godot Foundation, 2026 | Поиск аддонов (Store — новый с 4.7) |
| [Godot Forum](https://forum.godotengine.org/) | сообщество, живой | Ответы и dev-снапшоты |
| [Showcase](https://godotengine.org/showcase/) | Godot Foundation, живой | Выпущенные игры по жанрам |
| [Godot 4.8 dev 1](https://godotengine.org/article/dev-snapshot-godot-4-8-dev-1/) | Godot Foundation, 2026 | Что придёт в следующей версии |

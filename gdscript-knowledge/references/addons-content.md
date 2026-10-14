# Аддоны для редактора и контента: отладка, уровни, рендеринг, VFX, анимация, импорт, данные, шаблоны

Вторая часть каталога аддонов: инструменты, которые ускоряют работу в редакторе и производство контента. Актуально на 14 октября 2026 (Godot 4.7.2). Правила выбора и установки, что встроено в движок, и игровые системы — в [addons.md](addons.md); инструменты для агента (MCP, анализаторы, автоматизация, сборка) — в [addons-agent-tools.md](addons-agent-tools.md). Пометки и колонки те же: `[устарело]`, `[не проверено]`, `[встроено]`; **4.7.2** — результат [scripts/addon_smoke.sh](../scripts/addon_smoke.sh) («✓» — встал в чистый проект и скомпилировался без ошибок, «✗» — с ошибками, «—» — не проверялся); **Агент** — «текст», «API» или «GUI», как в [addons.md](addons.md#0-как-выбирать-и-ставить-аддоны). Рендереры: F+ — Forward+, Mob — Mobile, Comp — Compatibility (OpenGL, Web).

- [0. Что агенту важно знать про контентные аддоны](#0-что-агенту-важно-знать-про-контентные-аддоны)
- [1. Удобство редактора](#1-удобство-редактора)
- [2. Отладка в игре, логи, краш-репорты](#2-отладка-в-игре-логи-краш-репорты)
- [3. Левел-дизайн и контент уровней](#3-левел-дизайн-и-контент-уровней)
- [4. Шейдеры и пост-обработка](#4-шейдеры-и-пост-обработка)
- [5. VFX, частицы, разрушение](#5-vfx-частицы-разрушение)
- [6. 2D-графика и импорт спрайтов](#6-2d-графика-и-импорт-спрайтов)
- [7. Анимация и персонажи](#7-анимация-и-персонажи)
- [8. 3D-импорт и пайплайн ассетов](#8-3d-импорт-и-пайплайн-ассетов)
- [9. Данные и авторинг](#9-данные-и-авторинг)
- [10. Шаблоны и стартовые проекты](#10-шаблоны-и-стартовые-проекты)
- [11. Ресурсы](#11-ресурсы)

## 0. Что агенту важно знать про контентные аддоны

**Ключевые выводы**
- Делите аддоны на три группы. «Текст»: шейдеры `.gdshader`, `.tres`-пресеты, `.map` (func_godot), `.tmx`/`.tmj` (YATI), JSON — агент пишет их сам. «API»: узлы настраиваются свойствами и кодом, данные частично бинарные — агент собирает сцены и скрипты. «GUI»: кисти, скульптинг, граф-редакторы — агент готовит сцену и параметры, рисует человек.
- Импорт-плагины (Aseprite Wizard, Importality, TexturePacker, YATI, func_godot) срабатывают при `godot --headless --import`, поэтому агент может проверить импорт в CI. Многим нужен внешний CLI в `PATH` (Aseprite, Krita, Blender) — на CI-машине он тоже должен быть.
- Эффекты на Compositor и compute-шейдерах (объёмные облака, FFT-океаны, lens flare, Kawase blur) работают только в Forward+ и Mobile, а значит не работают в Web-экспорте. Для Web берите экранные шейдеры через `CanvasLayer` и встроенный `Environment`.
- Godot 4.3 перешёл на reverse-Z: старые depth-шейдеры с godotshaders.com (туман, вода, аутлайны) ломаются. Проверяйте версию шейдера.
- GDExtension-аддоны (Terrain3D, Debug Draw 3D, MTerrain, motion matching) привязаны к минорной версии Godot. Перед обновлением движка смотрите релизы аддона.
- Многое уже встроено: IK с семью солверами (4.6), `SpringBoneSimulator3D` (4.5), stencil Outline и X-Ray (4.5), авто-LOD и visibility ranges, `Parallax2D`, импорт FBX через ufbx, `AreaLight3D` и 2D Scene Paint (4.7). Таблица — в [addons.md](addons.md#0-как-выбирать-и-ставить-аддоны).

## 1. Удобство редактора

**Ключевые выводы**
- Большинство UX-аддонов редактора агенту не нужны: он правит файлы напрямую. Они безвредны и полезны человеку, с которым агент работает.
- Агенту полезны те, у которых есть headless-режим или текстовый результат: Godot Doctor (валидация сцен), graydwarf GDScript Linter, ThemeGen. Они описаны в [addons-agent-tools.md](addons-agent-tools.md#7-валидация-проекта-линтеры-покрытие-мутации) и [addons.md](addons.md#11-ui).

| Аддон | Версия (дата) · Godot | Что даёт | Агент | 4.7.2 | Оговорки |
|---|---|---|---|---|---|
| [Script-IDE](https://github.com/Maran23/script-ide) | 2.2.5 (2.9.2026) · 4.5+ | Скрипт-редактор как IDE: многострочные вкладки, Outline с фильтрами, быстрый поиск по скриптам и классам; ~1,1 тыс. ★ | не нужен | ✓ | Раскладка UI меняется с каждой версией; обновляйте вместе с Godot |
| [TODO Manager](https://github.com/OrigamiDev-Pete/TODO_Manager) | v2.7.0 (3.4.2026) · 4.0+ | Док со списком `TODO`/`FIXME`/`HACK` с переходом к строке | не нужен: `rg "TODO\|FIXME"` | ✓ | — |
| [Kanban Tasks](https://github.com/HolonProduction/godot_kanban_tasks) | v2.3.0 (13.10.2026) · 4.0+ | Канбан-доска в редакторе | для агента лучше `TODO.md` и issues | — | — |
| [Edit Resources as Table 2](https://github.com/don-tnowe/godot-resources-as-sheets-plugin) | 2.17.4 (1.2026) · 4.0+ | Таблица из папки `.tres`: массовая правка, формулы, импорт и экспорт CSV | текст: агент правит `.tres` или гоняет данные через CSV | ✓ | Большие папки медленные |
| [SignalVisualizer](https://github.com/Ericdowney/SignalVisualizer) | 1.8.0 (23.7.2026) · 4.0+ | Граф подключений сигналов текущей сцены | агенту хватает `rg "\[connection" *.tscn` и `rg "\.connect\("` | ✓ | Подключения из кода видны частично `[не проверено]` |
| [Inspector Tabs](https://github.com/PiCode9560/Godot-Inspector-Tabs) | v0.10 (5.2026) · 4.4+ | Вкладки в инспекторе по классам | не нужен | — | — |
| [Instance Dock](https://github.com/KoBeWi/Godot-Instance-Dock) | 8.2026 · 4.2+ | Палитра сцен с превью для быстрой расстановки | GUI | — | — |
| [Editor Theme Explorer](https://codeberg.org/YuriSizov/godot-editor-theme-explorer) | v2.2.0 (4.2026) · 4.2+ | Браузер иконок и стилей темы редактора для авторов плагинов | имена можно получить кодом через `EditorInterface.get_editor_theme()` | — | Переехал на Codeberg |
| [Godot Git Plugin](https://github.com/godotengine/godot-git-plugin) | v3.2.1 (9.2025), коммиты 2026 · 4.1+ | Git через VCS-интерфейс редактора | не нужен: агент работает с `git` | — | Проблемы с SSH и большими репозиториями |
| [Godot Plugin Refresher](https://github.com/godot-extended-libraries/godot-plugin-refresher) | v1.2 (12.2024) · 4.2+ | Перезагрузка своего плагина кнопкой | не нужен: перезапуск headless-редактора | — | `[устарело]` |
| Godot Minimal Theme, Inspector Extender, Tabby Explorer, Signal Lens | 2023–2025 | — | — | — | `[встроено]` в 4.4–4.6 или `[устарело]` |

## 2. Отладка в игре, логи, краш-репорты

**Ключевые выводы**
- Консоль в игре: LimboConsole. Её сценарии `.lcs` — текст, агент может написать сценарий, воспроизводящий баг. Panku Console не обновлялся с января 2025, но на 4.7.2 загружается.
- Визуальная отладка физики, ИИ и навигации: Debug Draw 3D (вызовы вырезаются из релиза). Агент видит результат только на кадре, поэтому сочетайте его с проверками состояния в тестах.
- Логи: встроенный `Logger` + `OS.add_logger()` (4.5+) закрывает перехват ошибок и `print` без аддонов. Краш-репорты: sentry-godot ([addons.md](addons.md#16-аналитика-и-краш-репорты)).
- Встроенные профайлер, мониторы и вкладка Game (4.4+) заменяют большинство «profiler»-аддонов; см. [performance.md](performance.md).

| Аддон | Версия (дата) · Godot | Что даёт | Агент | 4.7.2 | Оговорки |
|---|---|---|---|---|---|
| [LimboConsole](https://github.com/limbonaut/limbo_console) | v0.8.0 (20.6.2026) · 4.3+ | Dev-консоль: `LimboConsole.register_command(callable, "имя", "справка")`, автодополнение, история, алиасы, сценарии `.lcs` | текст: конфиг `addons/limbo_console.cfg`, команды кодом | ✓ | Autoload регистрируется в `_enable_plugin()`: при включении правкой `project.godot` допишите `[autoload]` |
| [Panku Console](https://github.com/Ark2000/PankuConsole) | v1.7.9 (7.2024) · 4.2+ | Консоль с выполнением выражений, окна-инспекторы, watch | GUI | ✓ | `[устарело]` (20 мес. без коммитов) → LimboConsole |
| [Developer Console (jitspoe)](https://github.com/jitspoe/godot-console) | 1.5.0 (6.2026) · 4.1+ | Простая консоль в стиле Quake | текст | — | — |
| [Debug Draw 3D](https://github.com/DmitriySalnikov/godot_debug_draw_3d) | 1.7.3 (4.4.2026) · 4.4.1+ | Линии, боксы, сферы, текст в 3D и 2D-оверлей одной строкой; вырезается из релиза; ~1,1 тыс. ★ | API | ✓ GDExtension грузится | GDExtension; Web поддерживается |
| [godot-debug-menu](https://github.com/godot-extended-libraries/godot-debug-menu) | v1.2.0 (12.2023), коммиты 11.2025 · 4.2+ | Оверлей по F3: FPS, frametime, CPU и GPU время | агенту лучше `Performance.get_monitor()` в лог | ✓ | — |
| [Monitor Overlay](https://github.com/HungryProton/monitor_overlay) | 1.1.0 (1.2026) · 4.0+ | Любые мониторы, включая свои, поверх игры | текст | — | — |
| [dear-imgui-godot](https://github.com/shatadev/dear-imgui-godot) | 1.19.0 (8.9.2026) · 4.3+ | Dear ImGui для отладочных окон и твикеров | текст: окна описываются кодом | — | GDExtension, мало звёзд. pkdawson/imgui-godot `[устарело]` |
| [Loggie](https://github.com/Shiva-Shadowsong/loggie) | 3.0 (24.10.2025) · 4.0+ | Логгер с уровнями, доменами, pretty-print словарей | текст | ✓ | На грани `[устарело]`; сначала рассмотрите встроенный `Logger` |
| [Log.gd](https://github.com/russmatney/log.gd) | v0.2.2 (12.2025), коммиты 10.2026 · 4.1+ | Цветной pretty-print с файлом и строкой | текст | — | Цветовые коды в headless-выводе `[не проверено]` |
| [DsInspector](https://github.com/xlljc/DsInspector) | 1.3 (12.2025) · 4.2+ | Инспектор дерева и свойств прямо в окне игры | GUI | — | Только 2D и только при запуске из редактора |
| Runtime Debug Tools, quentincaffeino/godot-console, godot-debugdraw2d, imgui-godot (pkdawson) | 2023–2025 | — | — | — | `[устарело]` → вкладка Game (4.4+), LimboConsole, Debug Draw 3D, dear-imgui-godot |

## 3. Левел-дизайн и контент уровней

**Ключевые выводы**
- Для агента лучше всего уровни в текстовых форматах внешних редакторов: Quake `.map` через func_godot (TrenchBroom), Tiled `.tmx`/`.tmj` через YATI. Агент может генерировать и править их скриптом, а импорт идёт при `--import`.
- Тайлы кодом: Better Terrain и TileMapDual дают API для расстановки клеток, автотайлинг считается сам.
- Кисти и скульптинг (Terrain3D, SimpleGrassTextured, Spatial Gardener, Cyclops, Asset Placer) агенту недоступны: он готовит сцену и параметры, человек рисует.
- Cyclops 1.5.x требует Godot 4.7+, а обновления могут ломать старые сцены.

| Аддон | Версия (дата) · Godot | Что даёт | Агент | 4.7.2 | Оговорки |
|---|---|---|---|---|---|
| [Terrain3D](https://github.com/TokisanGames/Terrain3D) | v1.0.2 (19.5.2026) · 4.4–4.6 официально | Clipmap-террейн: регионы до 65 км, скульпт, до 32 текстур, LOD, инстансер растительности, импорт heightmap; ~4,4 тыс. ★ | API: регионы — бинарные `.res`; импорт heightmap кодом; скульпт — GUI | ✓ 1.0.2 грузится в 4.7.2 | GDExtension; официальной поддержки 4.7 в релизе нет |
| [ProtonScatter](https://codeberg.org/hungryproton/proton_scatter) ([зеркало](https://github.com/HungryProton/scatter)) | 4.1 (1.2026), коммиты 9.2026 · 4.1+ | Процедурная расстановка пропов: стек модификаторов, области, проекция на поверхность, MultiMesh; ~3 тыс. ★ | текст: стек модификаторов в `.tscn`, результат виден только в редакторе | ✓ | Основной репозиторий на Codeberg |
| [func_godot](https://github.com/func-godot/func_godot_plugin) | 2025.12 (28.12.2025), коммиты 10.2026 · 4.5+ | Импорт Quake `.map` (TrenchBroom, J.A.C.K., NetRadiant) в сцены с коллизиями и сущностями; генерирует FGD | текст: `.map` агент генерирует сам | ✓ | Нужен внешний редактор уровней. Qodot `[устарело]` |
| [YATI](https://github.com/Kiamo2/YATI) | v2.2.10 (5.10.2026) · 4.3+ | Импорт Tiled (`.tmx`, `.tmj`, `.tsx`) в `TileMapLayer`, `TileSet` и объекты; есть импорт в рантайме | текст: XML/JSON | ✓ вариант `GDScript/` | Для 4.2 — отдельная старая версия |
| [Better Terrain](https://github.com/Portponky/better-terrain) | 1.1 (2.2026) · 4.3+ | Замена встроенного автотайлинга: гибкие правила, API для рантайма | API: `BetterTerrain.set_cell()`, `update_terrain_*`; разметка тайлсета — GUI | ✓ | Unlicense |
| [TileMapDual](https://github.com/pablogila/TileMapDual) | v5.0.3 (3.9.2026) · 4.4+ | Dual-grid автотайлинг: 15–16 тайлов вместо 47 | API: клетки кодом, отрисовка автоматическая | ✓ | — |
| [Cyclops Level Builder](https://github.com/blackears/cyclopsLevelBuilder) | v1.5.1 (13.10.2026) · 1.5.x: 4.7+ | Блокинг уровней выпуклыми блоками в стиле Hammer прямо в редакторе | GUI | ✓ с оговоркой: ошибка `queue_free` на null в `_exit_tree` при закрытии редактора | Аддон лежит в `godot/addons/`; обновления ломают старые сцены |
| [Godot Road Generator](https://github.com/TheDuckCow/godot-road-generator) | 0.9.5 (13.10.2026) · 4.4+ | 3D-дороги: перекрёстки, полосы, трафик | API: точки — узлы в `.tscn` | ✓ | 0.x |
| [SimpleGrassTextured](https://github.com/IcterusGames/SimpleGrassTextured) | v2.1.0 (3.4.2026) · 4.x | Кисть для травы на MultiMesh, интерактивная трава | GUI; материалы в `.tres` | — | — |
| [HTerrain](https://github.com/Zylann/godot_heightmap_plugin) | без релизов, коммиты 7.2026 · 4.6+ | Heightmap-террейн на чистом GDScript | API | — | Только багфиксы; Asset Library отстаёт — берите `master` |
| [TerraBrush](https://github.com/spimort/TerraBrush) | 0.14.7 (6.2026) · 4.5+ | Heightmap-редактор, переписан с C# на C++ | GUI | — | Alpha; переход ломает старые террейны |
| [Godot-MTerrain-plugin](https://github.com/mohsenph69/Godot-MTerrain-plugin) | 0.18.2-alpha (11.2025) · `[не проверено]` | Террейн до 16×16 км, трава с коллизией, дороги и реки на кривых | GUI | — | Alpha; README: «не заработает из коробки» |
| [Open World Database](https://github.com/DigitallyTailored/Godot-Open-World-Database) | 10.2026 · 4.4+ | Чанковый стриминг open-world по дистанции и размеру объекта | API | — | По листингу load/unload может удалить узлы — делайте бэкапы |
| [Godot Asset Placer](https://github.com/levinzonr/godot-asset-placer) | 1.6.0 (25.8.2026) · 4.4–4.6 | Библиотека ассетов с превью и расстановкой по поверхности | GUI | — | — |
| [Kenney Starter Kits](https://github.com/KenneyNL) | 2026 · 4.6 | 3D Platformer, FPS, City Builder, Racing с CC0-ассетами | текст: небольшие чистые проекты | — | — |
| Spatial Gardener, Qodot, vnen Tiled Importer, LDtk Importer, TileBitTools, SimpleDungeons, Waterways | 2021–2025 | — | — | — | `[устарело]` → ProtonScatter, func_godot, YATI, Better Terrain; LDtk-импортёр без замены |

## 4. Шейдеры и пост-обработка

**Ключевые выводы**
- Шейдер — лучший формат для агента: текст, который он пишет, читает и правит целиком. Первая точка поиска — godotshaders.com; обязательно сверяйте версию (Godot 3 или 4, reverse-Z с 4.3).
- Аутлайны и X-Ray есть во встроенном stencil (4.5). Для пост-эффекта в Web берите экранный шейдер на `CanvasLayer`, а не `CompositorEffect`.
- Подробно о рендерере, материалах и рывках компиляции — в [rendering.md](rendering.md).

| Ресурс или аддон | Версия (дата) · Godot | Что даёт | Агент | Оговорки |
|---|---|---|---|---|
| [godotshaders.com](https://godotshaders.com/) | живой | Каталог шейдеров: spatial, canvas_item, sky, particles | текст | Лицензия у каждого шейдера своя; смесь Godot 3 и 4 |
| [GDQuest godot-shaders](https://github.com/gdquest-demos/godot-shaders) | коммиты 5.2026 · 4.3 | Большая библиотека 2D- и 3D-шейдеров с демо; ~4,2 тыс. ★ | текст | Портирован на Godot 4 частично |
| [GDQuest godot-visual-effects](https://github.com/gdquest-demos/godot-visual-effects) | 5.2026 · 4.3 | 2D-эффекты: взрыв, лазер, ghost-trail, звёздное поле | текст | — |
| [godot4-cel-shader](https://github.com/eldskald/godot4-cel-shader) | 11.2025 · 4.x | Полный cel-шейдер: ступени света, спекуляр, rim | текст | FlexibleToonShader `[устарело]` |
| [psx_visuals](https://github.com/snotbane/psx_visuals), [psx_visuals_gd4](https://github.com/scolastico/psx_visuals_gd4) | 2026 · 4.x | PS1-стиль: vertex snapping, аффинные текстуры, дизеринг | текст | Мало звёзд |
| [SunshineClouds2](https://github.com/Bonkahe/SunshineClouds2) | 9.2026 · 4.4+ | Объёмные облака через Compositor | API: параметры в ресурсе | Только F+; дорогой эффект |
| [compositor-effect-lens-effects](https://github.com/ARez2/compositor-effect-lens-effects) | 7.2026 · 4.4+ | Lens flare и god rays как `CompositorEffect` | текст | Только F+ и Mob; хороший образец CompositorEffect |
| [Sky3D](https://github.com/TokisanGames/Sky3D) | v2.1.0 (19.5.2026) · 4.3+ | День и ночь: солнце, луна с фазами, звёзды, атмосфера, туман, облака, игровое время | API: свойства узла, время из кода | ✓ — F+, Mob, Comp |
| [Universal Transition Shader](https://github.com/cashew-olddew/Universal-Transition-Shader) | v17 (3.2026) · 4.4 | Десятки переходов в одном шейдере | текст | CC0 |
| [GodotPixelRenderer](https://github.com/bukkbeek/GodotPixelRenderer) | 4.2026 · 4.4 | 3D → пиксель-арт спрайты: пикселизация, палитра, дизеринг, пакетный экспорт | API | Отдельный проект, не аддон |
| ShaderV, Godot-Post-Process-Plugin, PostFX, ShaderFunction-Extras, godot-psx-style-demo, SimpleGodotCRTShader | 2023–2026 | — | — | `[устарело]` или архив; шейдеры текстовые и обычно переносятся вручную |

## 5. VFX, частицы, разрушение

| Аддон | Версия (дата) · Godot | Что даёт | Агент | Оговорки |
|---|---|---|---|---|
| [GODOT-VFX-LIBRARY](https://github.com/haowg/GODOT-VFX-LIBRARY) | v1.0.0 (10.2025), коммиты 1.2026 · 4.5+ | 35+ эффектов частиц и 17+ шейдеров для экшенов | текст: `.tscn` и `.tres` | Демо на F+ |
| [GPUTrail](https://github.com/celyk/GPUTrail) | 9.2026 · 4.x | Ленточный 3D-след на GPU: текстура, градиент, ширина по кривой | API | — |
| [VoronoiShatter](https://github.com/robertvaradan/voronoishatter) | v0.3 (1.6.2026) · 4.4+ | Voronoi-разлом мешей с генерацией `RigidBody` | API | Префрактур дешевле рантайма |
| [godot-polygon2d-fracture](https://github.com/SoloByte/godot-polygon2d-fracture) | v2.0.0 (6.2024) · 4.2 | Разлом и разрез 2D-полигонов | текст | `[устарело]`, но код простой |
| godot-destruction-plugin, mesh-slicing-gdextension, Trail2D, GodotLightning | 2018–2024 | — | — | `[устарело]`. Живых аддонов молний и 2D-следа нет: шейдер с godotshaders.com или `Line2D` + скрипт |

## 6. 2D-графика и импорт спрайтов

**Ключевые выводы**
- Импорт из Aseprite — Aseprite Wizard; из Krita, Pencil2D, Piskel, Pixelorama — Importality. Оба вызывают CLI внешнего редактора при `--import`.
- Pixel-perfect делается настройками проекта (`stretch/mode=viewport`, `scale_mode=integer`, snap), живого аддона «pixel-perfect camera» нет; см. [rendering.md](rendering.md) и [ui-input.md](ui-input.md).

| Аддон | Версия (дата) · Godot | Что даёт | Агент | 4.7.2 | Оговорки |
|---|---|---|---|---|---|
| [Aseprite Wizard](https://github.com/viniciusgerevini/godot-aseprite-wizard) | v9.8.0-4 (3.3.2026) · 4.4+ | `.aseprite` → SpriteFrames, AnimationPlayer, тайлсеты; слои, теги, слайсы; ~1,4 тыс. ★ | API: импорт при `--import` | ✓ | Нужен Aseprite, путь в `aseprite/general/command_path` |
| [Importality](https://github.com/nklbdev/godot-4-importality) | 0.4.0 (21.3.2026) · 4.x | Импортёры Aseprite, Krita, Pencil2D, Piskel, Pixelorama | API | — | Нужны CLI внешних редакторов |
| [TexturePacker importer](https://github.com/CodeAndWeb/texturepacker-godot-plugin) | v4.3.0 (12.2025) · 4.0+ | `.tpsheet` → AtlasTexture с trim и MultiPack | API | — | Официальный; импорт TileSet больше не поддерживается |
| [SpriteMesh](https://github.com/98teg/SpriteMesh) | v2.1.0 (3.2025), коммиты 1.2026 · 4.x | Объёмный 3D-меш из 2D-спрайта | API | — | — |
| [PixelPen](https://github.com/pixelpen-dev/pixelpen) | v1.2.0 (8.2026) · 4.x | Пиксель-арт редактор внутри Godot | GUI | — | — |
| [spine-godot](https://github.com/EsotericSoftware/spine-runtimes/tree/4.2/spine-godot) | 10.2026 · 4.x | Официальный рантайм Spine | API | — | Нужна лицензия Spine Editor; GDExtension-версия без AnimationPlayer и C#; сборка под 4.7 `[не проверено]` |
| [Godot-DragonBones](https://github.com/Daylily-Zeleen/Godot-DragonBones) | v2.1.0 (9.10.2026) · 4.3+ | Рантайм DragonBones | API | — | Бинарники только в релизах |
| SmartShape2D, Better Terrain, YATI, TileMapDual | — | См. [addons.md](addons.md#8-физика-и-движение) и раздел 3 | — | — | — |
| nklbdev Aseprite importers, godot-rive, AnimatedShape2D | 2023–2024 | — | — | — | `[устарело]` → Aseprite Wizard, Importality; официального Rive нет |

## 7. Анимация и персонажи

**Ключевые выводы**
- IK, пружинящие кости и ретаргетинг теперь в движке (4.4–4.6); many_bone_ik и JiggleBones устарели. Подробно в [animation-audio.md](animation-audio.md).
- Для твинов хватает встроенного `Tween` с `tween_await()` (4.7); Anima переписывается на v2.

| Аддон | Версия (дата) · Godot | Что даёт | Агент | Оговорки |
|---|---|---|---|---|
| [godot-motion-matching](https://github.com/GuilhermeGSousa/godot-motion-matching) | 0.2.1 (3.2025), коммиты 6.2026 · 4.4 | Motion matching: база поз из AnimationLibrary, подбор кадра по фичам | API | GDExtension под 4.4; работа на 4.7 `[не проверено]` |
| [godot-vrm](https://github.com/V-Sekai/godot-vrm) | 7.2026 · 4.1+ | Импорт и экспорт VRM-аватаров, шейдер MToon | API | — |
| [MixaBridge](https://github.com/uzairdeveloper223/mixabridge) | v1.0.2 (4.2026) · 4.4+ | Ретаргет Mixamo на `SkeletonProfileHumanoid` и сборка AnimationLibrary | API | Мало звёзд; базовый случай закрывает встроенный BoneMap |
| [Juicee](https://github.com/Kelpekk/Juicee), [TweenFX](https://github.com/EvilBunnyMan/TweenFX) | 2026 | Game feel | См. [addons.md](addons.md#7-архитектура-сцены-ecs-di-juice) | — |
| [Anima](https://github.com/ceceppa/anima) | 9.2026 · 4.7 | Декларативные цепочки анимаций | текст | Идёт переписывание на v2 |
| many_bone_ik, JiggleBones, Godot-Mixamo-Animation-Retargeter | 2023–2025 | — | — | `[устарело]` → встроенный IK, `SpringBoneSimulator3D`, `RetargetModifier3D` |

## 8. 3D-импорт и пайплайн ассетов

**Ключевые выводы**
- glTF — основной формат; `.blend` импортируется напрямую, но требует Blender на машине, где идёт `--import`. Для CI надёжнее коммитить `.glb`. Подробно в [resources-import.md](resources-import.md).
- Настройки импорта лежат в `.import` (текст), а постобработку пишут в `EditorScenePostImport` — это тоже текст, и агент может их править.

| Аддон | Версия (дата) · Godot | Что даёт | Агент | Оговорки |
|---|---|---|---|---|
| [Voxel Tools](https://github.com/Zylann/godot_voxel) | v1.7 (20.8.2026) · 4.7 | Воксельные миры; см. [addons.md](addons.md#9-процедурная-генерация-и-мир) | API | Модуль требует своей сборки движка |
| [Material Maker](https://github.com/RodZill4/material-maker) | 1.7 (14.7.2026) · отдельное приложение | Нодовый генератор PBR-текстур, экспорт текстур и шейдеров для Godot; ~6 тыс. ★ | GUI, но графы `.ptex` — JSON | — |
| [Goblend](https://github.com/Togira123/Goblend-Export-Addon) | v2.1.1 (14.9.2026) | Blender-аддон: экспорт сцен с материалами, коллизиями и вложенными сценами | API | GPL касается Blender-аддона |
| [Blender-Godot Pipeline](https://github.com/bikemurt/blender-godot-pipeline) | 2.5.5 (9.2025) · 4.2+ | Метаданные из Blender применяются при импорте | текст: post-import-скрипт | Blender-часть платная; на грани `[устарело]` |
| [godot-imposter](https://github.com/zhangjt93/godot-imposter) | 1.3 (8.2025) · 4.x | Запекание импосторов для дальних объектов | API | На грани `[устарело]` |
| godot-blender-exporter, MeshLodGenerator, godot-lod, Godot-Octahedral-Impostors, texture_packer (Relintai) | 2020–2024 | — | — | `[устарело]` → glTF или `.blend`, встроенный авто-LOD и visibility ranges |

## 9. Данные и авторинг

Данные игры (предметы, карты, баланс, локализация) агент удобнее всего ведёт в тексте: JSON со схемой, CSV, `.tres`. Аддоны для сохранений, JSON Schema, YAML и SQLite — в [addons.md](addons.md#6-сохранения-и-данные).

| Аддон | Версия (дата) · Godot | Что даёт | Агент | 4.7.2 | Оговорки |
|---|---|---|---|---|---|
| [Godot Resource Groups](https://github.com/derkork/godot-resource-groups) | v0.4.2 (2.2025), коммиты 4.2026 · 4.0+ | Собирает пути ресурсов по glob в `ResourceGroup` (`.tres`): работает в экспорте, где `DirAccess` по `res://` ненадёжен | текст | ✓ | — |
| [godot-csv-data-importer](https://github.com/timothyqiu/godot-csv-data-importer) | 1.2026 · 4.x | CSV и TSV как `Array`/`Dictionary`, а не переводы | текст: импорт при `--import` | — | Автор — участник core-команды |
| [Edit Resources as Table 2](https://github.com/don-tnowe/godot-resources-as-sheets-plugin) | см. раздел 1 | Табличная правка `.tres` и CSV | текст | ✓ | — |
| [Pandora](https://github.com/bitbrain/pandora) | см. [addons.md](addons.md#5-инвентарь-rpg-данные-способности) | RPG-база данных в одном JSON | текст | — | Alpha |
| Google Sheets → Godot | — | Синхронизация таблиц с редактором | — | — | Агенту проще скачать лист по `…/export?format=csv` и импортировать CSV |

## 10. Шаблоны и стартовые проекты

**Ключевые выводы**
- Шаблон хорош как старт нового проекта, а не как вставка в существующий: он приносит свою структуру автозагрузок и сцен.
- Для агента ценны шаблоны с готовым CI и чистым кодом: crystal-bit godot-game-template (GitHub Actions для сборки и Web), Godot Open RPG (эталонный GDScript).

| Шаблон | Версия (дата) · Godot | Что даёт | Оговорки |
|---|---|---|---|
| [Maaack's Godot Game Template](https://github.com/Maaack/Godot-Game-Template) | v1.7.0 (9.9.2026) · 4.7 | Меню, настройки, пауза, титры, загрузчик сцен; варианты Menus, Minimal, GWJ | См. [addons.md](addons.md#11-ui) |
| [crystal-bit/godot-game-template](https://github.com/crystal-bit/godot-game-template) | 2026.06.0 (21.6.2026) · 4.7 | Переходы и многопоточная загрузка сцен, gettext, debug-хоткеи (вырезаются из релиза), GitHub Actions для сборки и Web-деплоя | — |
| [bitbrain/godot-gamejam](https://github.com/bitbrain/godot-gamejam) | 8.2026 · 4.0+ | Шаблон для джемов с меню, настройками и godot-ci | — |
| [Godot Open RPG](https://github.com/gdquest-demos/godot-open-rpg) | 0.4.0, коммиты 13.10.2026 · 4.7.2+ | Эталонная JRPG от GDQuest | Демо, а не аддон |
| [COGITO](https://codeberg.org/Phazorknight/Cogito) | 1.2.0 (10.10.2026) · 1.1.6 — 4.5.1; 1.2.0 `[не проверено]` | Шаблон immersive sim: контроллер на statecharts, взаимодействия, инвентарь, квесты, save/load, NPC | Только на Codeberg: GitHub-ссылки в старых статьях битые. Начинайте проект с шаблона, а не встраивайте |
| [Metroidvania System](https://github.com/KoBeWi/Metroidvania-System) | 10.2026 · 4.x | Редактор карты комнат, переходы, сохранения, мини-карта | Карта правится в GUI |
| [Kenney Starter Kits](https://github.com/KenneyNL) | 2026 · 4.6 | Мини-игры с CC0-ассетами | — |
| [Chickensoft GodotGame](https://github.com/chickensoft-games/GodotGame) | 2026 · .NET | C#-шаблон с тестами, покрытием и CI | Только C# |

## 11. Ресурсы

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [godotshaders.com](https://godotshaders.com/) | сообщество, 2026 | Каталог шейдеров |
| [Terrain3D docs](https://terrain3d.readthedocs.io/) | Tokisan Games, 2026 | Регионы, импорт heightmap, платформы |
| [func_godot docs](https://func-godot.github.io/func_godot_docs/) | func-godot, 2026 | Пайплайн TrenchBroom → Godot |
| [Aseprite Wizard docs](https://github.com/viniciusgerevini/godot-aseprite-wizard#readme) | Vinicius Gerevini, 2026 | Режимы импорта |
| [Importing 3D scenes](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/index.html) | Godot docs, 2026 | glTF, `.blend`, FBX, post-import-скрипты |
| [The Compositor](https://docs.godotengine.org/en/stable/tutorials/rendering/compositor.html) | Godot docs, 2026 | `CompositorEffect` и ограничения по рендерерам |
| [awesome-godot](https://github.com/godotengine/awesome-godot) | сообщество, 2026 | Сводный список |

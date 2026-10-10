# Настройки проекта, редактор, экспорт и платформы в Godot 4

Справочник по самому движку вокруг GDScript-кода: какие настройки проекта менять и на что, как работают feature tags и `override.cfg`, какие приёмы редактора экономят время, как устроены пресеты и фильтры экспорта, что нужно каждой платформе и что проверить перед релизом. Актуально на октябрь 2026 года, Godot 4.7.2. Значения по умолчанию, поведение переопределений, состав PCK и коды выхода экспорта проверены запуском Godot 4.7.2 на Windows 11; такие места помечены «(проверено на 4.7.2)». Часть фактов сверена с исходниками тега `4.7.2-stable`. Пометка `[не проверено]` стоит у данных из вторичных источников, `[устарело]` — у советов, которые больше не верны. CLI-флаги, CI, git и предупреждения GDScript здесь не повторяются, они в [toolchain.md](toolchain.md). Размер сборки и урезанные шаблоны — в [performance.md](performance.md#сборка-экспорт-web-и-мобильные), обзор платформ, консолей и Steam — в [domains.md](domains.md#10-мультиплеер-и-платформы).

- [1. Важные настройки проекта](#1-важные-настройки-проекта)
- [2. Feature tags и переопределения настроек](#2-feature-tags-и-переопределения-настроек)
- [3. override.cfg, настройки редактора и изменение настроек в рантайме](#3-overridecfg-настройки-редактора-и-изменение-настроек-в-рантайме)
- [4. Окно, экран и ОС в рантайме](#4-окно-экран-и-ос-в-рантайме)
- [5. Пути данных, логи и файлы падений](#5-пути-данных-логи-и-файлы-падений)
- [6. Редактор: приёмы, которые экономят время](#6-редактор-приёмы-которые-экономят-время)
- [7. Отладчик: вкладки и удалённое дерево](#7-отладчик-вкладки-и-удалённое-дерево)
- [8. Пресеты экспорта и export_presets.cfg](#8-пресеты-экспорта-и-export_presetscfg)
- [9. Фильтры ресурсов: что попадает в PCK](#9-фильтры-ресурсов-что-попадает-в-pck)
- [10. PCK, ZIP, встраивание, патчи и шифрование](#10-pck-zip-встраивание-патчи-и-шифрование)
- [11. Особенности платформ](#11-особенности-платформ)
- [12. Версионирование](#12-версионирование)
- [13. Чеклист перед релизом](#13-чеклист-перед-релизом)
- [14. Антипаттерны](#14-антипаттерны)
- [15. Ресурсы](#15-ресурсы)

## 1. Важные настройки проекта

### Ключевые выводы
- Новый проект из Project Manager отличается от «пустых» значений движка. В 4.7.2 он сразу записывает `stretch/mode="canvas_items"`, `stretch/aspect="expand"`, `physics/3d/physics_engine="Jolt Physics"` и `rendering_device/driver.windows="d3d12"` (проверено по `EditorNode::get_initial_settings()` в 4.7.2). Если у старого проекта этих строк нет, он работает на значениях движка: stretch `disabled`/`keep`, GodotPhysics3D, Vulkan на Windows. После миграции с 4.3–4.5 эти настройки нужно выставить вручную.
- В `project.godot` хранится только то, что отличается от значения по умолчанию. Строки нет, значит действует дефолт движка, а он может поменяться между версиями. Значения, которые важны для проекта, держите явно.
- Включите **Advanced Settings** в окне Project Settings, иначе половина настроек ниже не видна.
- Рендерер и драйвер выбирайте под целевую платформу и сразу проверяйте на ней. Для Web доступен только Compatibility. Значения по умолчанию: `forward_plus`, `.mobile=mobile`, `.web=gl_compatibility` (проверено на 4.7.2).
- В `application/config/features` попадают только `"4.7"` и имя рендерера. Тега версии `"4.7"` в `OS.has_feature()` нет, он возвращает `false` (проверено на 4.7.2). Версию движка в рантайме читайте через `Engine.get_version_info()`.

| Настройка (путь) | По умолчанию в 4.7.2 | Рекомендация |
|---|---|---|
| `application/config/name`, `version`, `icon`, `description` | пусто | Заполнить. `version` используют экспортёры (см. раздел 12) |
| `application/run/main_scene` | пусто | Лёгкая загрузочная сцена (сплэш или загрузчик), не меню с 50 preload |
| `application/run/max_fps` | `0` (без лимита) | Задайте лимит в опциях игры. На мобильных обычно 60 или 30, иначе батарея и нагрев |
| `application/run/low_processor_mode` | `false` | `true` только для приложений и инструментов (перерисовка по событию) |
| `application/config/use_custom_user_dir` + `custom_user_dir_name` | `false` | `true` для релиза: сохранения лежат в `%APPDATA%\<Studio>/<Game>`, а не в `Godot/app_userdata` |
| `application/boot_splash/*` | `show_image=true` | Свой образ и цвет фона; `application/boot_splash/minimum_display_time` для логотипа |
| `display/window/size/viewport_width/height` | `1152×648` | Базовое разрешение: 1920×1080 для desktop, 1280×720 для мобильных в ландшафте, 640×360 для пиксель-арта |
| `display/window/size/mode` | `0` Windowed | Для игр обычно Exclusive Fullscreen (`4`) из меню настроек, а не из project.godot |
| `display/window/stretch/mode` / `aspect` | engine: `disabled`/`keep`; новый проект: `canvas_items`/`expand` | Игры: `canvas_items` + `expand`; пиксель-арт: `viewport` + `stretch/scale_mode=integer` |
| `display/window/vsync/vsync_mode` | `1` Enabled | Оставить, дать переключатель в опциях; `Adaptive` для слабых GPU |
| `display/window/dpi/allow_hidpi` | `true` | Не выключать: без DPI-awareness ломается полноэкранный режим на Windows |
| `display/window/handheld/orientation` | `0` Landscape | Для портретных мобильных игр `1` |
| `display/window/energy_saving/keep_screen_on` | `true` | Для приложений `false` |
| `rendering/renderer/rendering_method` (+ `.mobile`, `.web`) | `forward_plus` / `mobile` / `gl_compatibility` | Выбрать один раз в начале. Смена рендерера меняет вид материалов и освещения |
| `rendering/rendering_device/driver.windows` | engine `vulkan`, новый проект `d3d12` | D3D12 по умолчанию с 4.6; при проблемах с драйверами есть автоматический fallback (`fallback_to_vulkan=true`) |
| `rendering/textures/vram_compression/import_etc2_astc` | `false` | `true`, если целитесь в Android, iOS или мобильный Web |
| `rendering/textures/canvas_textures/default_texture_filter` | `1` Linear | Пиксель-арт: `0` Nearest |
| `rendering/anti_aliasing/quality/msaa_3d`, `screen_space_aa` | `0`, `0` | Включайте на desktop; на мобильных осторожно |
| `physics/common/physics_ticks_per_second` | `60` | Под жанр. Для быстрых экшенов или 3D с физикой 120, для пошаговых 30 |
| `physics/common/max_physics_steps_per_frame` | `8` | Снижайте до 2–4, если при просадках возникает «спираль смерти» |
| `physics/common/physics_interpolation` | `false` | `true`, если тик физики меньше частоты кадров (плавность на 144 Гц) |
| `physics/3d/physics_engine` | engine `DEFAULT`, новый проект `Jolt Physics` | Jolt для 3D; проверьте разделы его документации об отличиях |
| `audio/driver/mix_rate`, `output_latency` | `44100`, `15` мс | Оставить; `audio/driver/enable_input=true` только при записи с микрофона |
| `audio/general/default_playback_type.web` | `1` Sample | Оставить для однопоточного Web |
| `input_devices/pointing/emulate_touch_from_mouse` | `false` | `true` для отладки мобильного ввода на ПК |
| `input_devices/joypads/ignore_joypad_on_unfocused_application` | `false` | Новая в 4.7. `true`, если игру запускают рядом с другими (локальные тесты, стрим) |
| `gui/theme/custom`, `custom_font`, `default_theme_scale` | пусто, пусто, `1.0` | Одна тема на проект; масштаб 2.0–3.0 при базе 4K |
| `internationalization/locale/translations`, `fallback` | `[]`, `en` | Добавить `.translation`/`.po`; см. [domains.md](domains.md#7-диалоги-нарратив-и-локализация) |
| `internationalization/pseudolocalization/use_pseudolocalization` | `false` | Временно `true` для проверки длины строк в UI |
| `debug/file_logging/enable_file_logging` (+ `.pc`) | `false`, `.pc=true` | Оставить на desktop, на мобильных включать по необходимости |
| `debug/settings/gdscript/always_track_call_stacks` | `false` | `true` в release, если собираете отчёты об ошибках (4.5+) |
| `debug/settings/crash_handler/message` | текст про разработчика | Ваш адрес поддержки или Discord |
| `rendering/driver/threads/thread_model` | `1` Safe | Separate остаётся экспериментальным, не включайте без замеров `[не проверено]` |
| `threading/worker_pool/max_threads`, `low_priority_thread_ratio` | `-1`, `0.3` | Оставить. Подробнее о потоках — [signals-async-threads.md](signals-async-threads.md) |
| `editor/export/convert_text_resources_to_binary` | `true` | Оставить: `.tscn`/`.tres` в экспорте становятся бинарными, загружаются быстрее |

Значения в таблице проверены на 4.7.2 через `ProjectSettings.get_setting()` и `property_get_revert()`.

```ini
; project.godot: фрагмент для 2D/3D-игры на desktop + мобильных (Godot 4.7)
[application]
config/name="My Game"
config/version="1.4.0"
config/use_custom_user_dir=true
config/custom_user_dir_name="MyStudio/MyGame"
run/main_scene="uid://c3k1xboot0001"
boot_splash/bg_color=Color(0.07, 0.07, 0.09, 1)

[display]
window/size/viewport_width=1920
window/size/viewport_height=1080
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[physics]
3d/physics_engine="Jolt Physics"
common/physics_interpolation=true

[rendering]
textures/vram_compression/import_etc2_astc=true
rendering_device/driver.windows="d3d12"
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Project Settings (editor)](https://docs.godotengine.org/en/stable/tutorials/editor/project_settings.html) | Godot docs, 2026 | Формат `project.godot`, Advanced Settings, изменение в рантайме |
| [ProjectSettings class](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html) | Godot docs, 2026 | Полный список настроек с описаниями |
| [Multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html) | Godot docs, 2026 | Базовые разрешения и stretch под жанры |
| [Overview of renderers](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html) | Godot docs, 2026 | Forward+, Mobile, Compatibility: что где работает |
| [Physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/index.html) | Godot docs, 2026 | Когда включать и как не сломать телепорты |
| [Using Jolt Physics](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html) | Godot docs, 2026 | Отличия Jolt от GodotPhysics3D |
| [`get_initial_settings()` в 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/editor/editor_node.cpp) | Godot, 2026 | Какие настройки получает новый проект |

## 2. Feature tags и переопределения настроек

### Ключевые выводы
- Переопределение записывается как `путь.тег`: `my/setting.mobile=...`. В инспекторе это кнопка **Add Override** рядом с настройкой.
- `ProjectSettings.get_setting()` **игнорирует** переопределения. Для своих настроек с тегами читайте `ProjectSettings.get_setting_with_override()`. В тесте: `get_setting("my/value")` → `"base"`, `get_setting_with_override` → `"debug_override"` (проверено на 4.7.2). Сам движок читает свои настройки с учётом тегов, например `enable_file_logging.pc` даёт `true`.
- Если подходят несколько тегов, побеждает **первый в порядке записи в файле**. В коде `get_setting_with_override_and_custom_features` это цикл с `break` на первом совпадении. В тесте `order.windows` раньше `order.debug` дал `win`, а `rev.debug` раньше `rev.windows` дал `dbg` (проверено на 4.7.2). Не ставьте на одну настройку два тега, которые могут совпасть одновременно.
- Встроенные теги неизменны в рантайме. Исключения — теги сжатия текстур, `web_<os>` и `movie`.
- При запуске из редактора (F5, `-s`) теги такие: `editor`, `editor_runtime`, `debug`, `pc`, `windows`, `x86_64`, `64`, `threads`. `template`, `release`, `standalone`, `editor_hint` равны `false` (проверено на 4.7.2). `editor_hint` равен `true` только для кода, который выполняется внутри самого редактора (`@tool`).
- Свои теги задаются в пресете (**Features → Custom**, ключ `custom_features`). Они работают только в экспортированной игре и вшиваются в `project.binary`. PCK из пресета с `custom_features="mycustom"`, запущенный через `--main-pack`, вернул `OS.has_feature("mycustom") == true`, а запуск из редактора — `false` (проверено на 4.7.2).
- Ветвление по сборке: `OS.is_debug_build()` или `OS.has_feature("debug")`. Отличить «запуск из редактора» от «экспортированной debug-сборки» можно через `OS.has_feature("template")` или `"editor"`.

| Тег | Когда `true` |
|---|---|
| `windows`, `linux`, `linuxbsd`, `bsd`, `macos`, `android`, `ios`, `visionos`, `web` | ОС или хост; `web_android`, `web_ios`, `web_windows` и т. д. — ОС под браузером |
| `pc`, `mobile` | Desktop или телефон и планшет |
| `debug`, `release` | Debug-шаблон (и редактор) или release-шаблон |
| `editor`, `template`, `editor_hint`, `editor_runtime` | Бинарник редактора; шаблон экспорта; код внутри редактора; игра, запущенная редактором |
| `x86_64`, `arm64`, `wasm32`, `64`, `32`, `double`, `single` | Архитектура и точность float |
| `threads`, `nothreads` | Сборка с потоками или без (Web) |
| `etc2`, `s3tc`, `etc` | Поддерживаемое сжатие текстур |
| `movie`, `shader_baker`, `dedicated_server` | Movie Maker; экспорт с запечённым кешем шейдеров; экспорт как выделенный сервер |

```ini
; project.godot: настройки под платформу и сборку
[application]
run/max_fps=0
run/max_fps.mobile=60
run/flush_stdout_on_print.debug=true

[debug]
file_logging/enable_file_logging.pc=true

[game]
; своя настройка: тег demo задаётся в пресете "Steam Demo"
content/max_level=40
content/max_level.demo=3
backend/url="https://api.example.com"
backend/url.debug="https://staging.example.com"
```

```gdscript
# Свои настройки читаем С переопределениями
var max_level: int = ProjectSettings.get_setting_with_override("game/content/max_level")
var is_demo: bool = OS.has_feature("demo")          # тег из пресета экспорта
var in_editor_run: bool = OS.has_feature("editor")   # запуск из редактора
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Feature tags](https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html) | Godot docs, 2026 | Полный список тегов и правила |
| [OS.has_feature](https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-method-has-feature) | Godot docs, 2026 | Сигнатура и примечания |
| [project_settings.cpp в 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/core/config/project_settings.cpp) | Godot, 2026 | Порядок применения переопределений и поиск `override.cfg` |

## 3. override.cfg, настройки редактора и изменение настроек в рантайме

### Ключевые выводы
- `override.cfg` имеет тот же формат, что и `project.godot`. Движок ищет его рядом с main pack, в `res://` и рядом с исполняемым файлом (по исходникам 4.7.2). Файл переопределяет базовые значения и добавляет новые ключи: `application/config/name` подменился, новый ключ стал виден (проверено на 4.7.2).
- **Ловушка:** тегированный ключ из `project.godot` сильнее, чем базовое значение из `override.cfg`. При `value.debug` в `project.godot` и `value="..."` в `override.cfg` `get_setting_with_override` вернул значение из `.debug` (проверено на 4.7.2). Если переопределение должно действовать на всех платформах, повторяйте в `override.cfg` теговые ключи.
- Применение `override.cfg`: моды, ручная настройка у игрока («положите файл рядом с exe»), бенчмарк-стенды. В релизе он даёт игроку менять любые настройки проекта, учитывайте это. Путь к другому файлу задаёт `application/config/project_settings_override`.
- Editor Settings (`editor_settings-4.7.tres` в `%APPDATA%\Godot\`, `~/.config/godot/`) относятся к вашей машине: тема, внешний редактор, пути Android SDK, signtool, rcodesign. В репозиторий они не попадают. Project Settings (`project.godot`) относятся к игре и коммитятся. Метаданные проекта для редактора хранятся в `.godot/editor/` и не коммитятся.
- `ProjectSettings.set_setting()` в рантайме не действует на настройки, которые читаются один раз при старте. Меняйте их рантайм-эквиваленты: `Engine.max_fps`, `Engine.physics_ticks_per_second`, `DisplayServer.window_set_mode()`, `DisplayServer.window_set_vsync_mode()`, `get_viewport().scaling_3d_scale`, `get_window().content_scale_factor`.
- Настройки игрока сохраняйте в `user://settings.cfg` через `ConfigFile`, а не через `ProjectSettings.save()`. В экспорте `res://` только для чтения.

```gdscript
# Применение настроек игрока при старте (autoload)
func apply_settings(cfg: ConfigFile) -> void:
	var mode: int = cfg.get_value("video", "window_mode", DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(cfg.get_value("video", "vsync", DisplayServer.VSYNC_ENABLED))
	Engine.max_fps = cfg.get_value("video", "max_fps", 0)
	get_viewport().scaling_3d_scale = cfg.get_value("video", "render_scale", 1.0)
	get_window().content_scale_factor = cfg.get_value("ui", "scale", 1.0)
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Project Settings](https://docs.godotengine.org/en/stable/tutorials/editor/project_settings.html) | Godot docs, 2026 | Какие настройки читаются один раз |
| [EditorSettings class](https://docs.godotengine.org/en/stable/classes/class_editorsettings.html) | Godot docs, 2026 | Все настройки редактора, включая пути экспорта |
| [ConfigFile class](https://docs.godotengine.org/en/stable/classes/class_configfile.html) | Godot docs, 2026 | Сохранение опций игрока |

## 4. Окно, экран и ОС в рантайме

### Ключевые выводы
- Режимы окна: `DisplayServer.window_set_mode()` с `WINDOW_MODE_WINDOWED`, `MAXIMIZED`, `FULLSCREEN` (borderless, без эксклюзивного режима), `EXCLUSIVE_FULLSCREEN`. Для игр берите Exclusive Fullscreen: у обычного Fullscreen на Windows остаётся 1 пиксель по краю, и integer scaling может выбрать меньший масштаб.
- DPI: `DisplayServer.screen_get_dpi()` и `screen_get_scale()`. `screen_get_scale` реализован на Android, iOS, macOS, Web и Linux Wayland. На Windows и X11 он возвращает 1.0, масштаб приходится угадывать по разрешению. В headless-режиме `get_name()` возвращает `headless`, DPI равен 96 (проверено на 4.7.2).
- Прежде чем вызывать API, проверяйте `DisplayServer.has_feature()`: `FEATURE_VIRTUAL_KEYBOARD`, `FEATURE_CLIPBOARD`, `FEATURE_HIDPI`, `FEATURE_NATIVE_DIALOG_FILE`. Без проверки код молча не работает на части платформ.
- Экранная клавиатура: `LineEdit` и `TextEdit` показывают её сами (`virtual_keyboard_enabled`, `virtual_keyboard_type`). Для своего ввода вызывайте `DisplayServer.virtual_keyboard_show()`/`hide()`, высоту даёт `virtual_keyboard_get_height()`. На Steam Deck клавиатура открывается через Steam (GodotSteam `showGamepadTextInput`), см. [domains.md](domains.md#10-мультиплеер-и-платформы).
- Безопасная зона (вырезы, edge-to-edge на Android): `DisplayServer.get_display_safe_area()`. Ориентация: `screen_set_orientation()`.
- Разрешения Android запрашивайте во время работы: `OS.request_permission("android.permission.RECORD_AUDIO")` и сигнал `get_tree().on_request_permissions_result`. Галочки в пресете только объявляют разрешение.
- `OS.get_name()`, `OS.get_locale()`, `OS.get_processor_count()`, `OS.get_video_adapter_driver_info()` пригодятся для отчётов об ошибках. `RenderingServer.get_video_adapter_name()` даёт имя GPU.

```gdscript
func toggle_fullscreen() -> void:
	var w := get_window()
	w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN \
		else Window.MODE_EXCLUSIVE_FULLSCREEN

func _ready() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_HIDPI):
		get_window().content_scale_factor = DisplayServer.screen_get_scale()
	var safe: Rect2i = DisplayServer.get_display_safe_area()   # отступы под вырез
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [DisplayServer class](https://docs.godotengine.org/en/stable/classes/class_displayserver.html) | Godot docs, 2026 | Окна, экраны, клавиатура, фичи |
| [Window class](https://docs.godotengine.org/en/stable/classes/class_window.html) | Godot docs, 2026 | `mode`, `content_scale_*`, `min_size` |
| [OS class](https://docs.godotengine.org/en/stable/classes/class_os.html) | Godot docs, 2026 | Разрешения, информация о системе, пути |

## 5. Пути данных, логи и файлы падений

### Ключевые выводы
- `user://` без своего каталога: `%APPDATA%\Godot\app_userdata\<name>` (Windows; в тесте `C:/Users/.../AppData/Roaming/Godot/app_userdata/ExportTest`, проверено на 4.7.2), `~/Library/Application Support/Godot/app_userdata/<name>` (macOS), `~/.local/share/godot/app_userdata/<name>` (Linux, Steam Deck). При `use_custom_user_dir` слой `Godot/app_userdata` пропадает: `%APPDATA%\<custom_dir_name>`. Имя каталога может содержать `/` (`Studio/Game`).
- Меняйте `config/name` после релиза осторожно: без `custom_user_dir_name` у игроков «потеряются» сохранения.
- Android и iOS: `user://` лежит во внутреннем хранилище приложения. Web: IndexedDB. В приватном режиме и без разрешения на cookies сохранения пропадают.
- Файловый лог включён по умолчанию только на `pc` (`enable_file_logging.pc=true`): `user://logs/godot.log` и 5 ротаций. Бэктрейс падения уходит в stderr и в этот лог, в Output редактора его нет. У официальных бинарников нет отладочных символов, поэтому бэктрейс получается почти пустым.
- Android: `adb logcat -s godot`. iOS: консоль Xcode или Console.app. Web: консоль браузера. На мобильных файловый лог по умолчанию выключен.
- С 4.5 есть свои логгеры: класс `extends Logger` с `_log_message()`/`_log_error()`, регистрируется через `OS.add_logger()`. Это основа для внутриигрового баг-репорта. Внутри не вызывайте `print`/`push_error`, получится рекурсия. Для стеков в release включите `always_track_call_stacks`. Готовое решение — Sentry SDK ([domains.md](domains.md#10-мультиплеер-и-платформы)).
- В release stdout сбрасывается только при выходе или падении. Если игру запускает лаунчер и читает вывод, включите `application/run/flush_stdout_on_print`.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [File paths in Godot projects](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html) | Godot docs, 2026 | `user://` по ОС, custom user dir, self-contained `_sc_` |
| [Logging](https://docs.godotengine.org/en/stable/tutorials/scripting/logging.html) | Godot docs, 2026 | Файловый лог, ротация, `Logger`, бэктрейсы |
| [Logger class](https://docs.godotengine.org/en/stable/classes/class_logger.html) | Godot docs, 2026 | Сигнатуры `_log_message`/`_log_error` |
| [Godot 4.5 release](https://godotengine.org/releases/4.5/) | Godot Foundation, 2025 | Логгеры и бэктрейсы скриптов в release |

## 6. Редактор: приёмы, которые экономят время

### Ключевые выводы
- **Переименовывайте и перемещайте файлы только в доке FileSystem.** С 4.4 у скриптов и шейдеров есть файлы `.uid`, у импортируемых ассетов UID лежит в `.import`. Если перенести файл в проводнике или через `git mv` без его `.uid`, ссылки по UID ломаются. Двигайте пару файлов вместе; для сцен, у которых `[gd_scene ... uid=...]`, это не нужно. Миграцию 4.3→4.4 делает **Project → Tools → Upgrade UIDs**. Для пересохранения сцен под новые форматы есть **Upgrade Project Files** (4.6).
- В коде на ресурсы ссылайтесь через `uid://` или константы путей, а не собирайте путь строкой. С 4.5 перетаскивание ресурса в скрипт с Ctrl вставляет `preload("uid://...")`, с 4.6 простое перетаскивание создаёт `@export`-переменную.
- **Find in Files** (Ctrl+Shift+F) и **Replace in Files** ищут по всему проекту, включая `.tscn`. Вкладка **Search Results** показывает совпадения в сценах. Удаление файла в FileSystem предупреждает о зависимостях, **View Owners** показывает, кто ссылается на ресурс.
- **Quick Open** (Shift+Alt+O; 4.6 — с превью), **Command Palette** (Ctrl+Shift+P, с 4.5 запускает именованные EditorScript). Сочетания клавиш можно переназначить в Editor Settings → Shortcuts `[не проверено]` для раскладок не-US.
- Инспектор: перетаскивание ресурса из FileSystem в слот, **Quick Load**, **Make Unique** (копия вместо общей ссылки) и **Make Sub-Resources Unique** при дублировании, **Paste as Unique** (4.5), **Favorite Property** (4.4), копирование всех свойств узла, история `<` `>`, копирование категорий свойств (4.7). Частая ошибка — общий `Material`/`Shape` у дублированных узлов, когда правка одного меняет все.
- Дерево сцены: **Save Branch as Scene**, **Make Local**, **Editable Children** для наследуемых сцен, `%UniqueName` (**Access as Unique Name**), перетаскивание узла в скрипт с Ctrl даёт `@onready var`.
- Раскладки: **Editor → Editor Layouts → Save**, хранятся в `editor_layouts.cfg`. С 4.6 нижние панели стали обычными доками, их можно перемещать и делать плавающими. Скрипт-редактор тоже можно вынести в отдельное окно.
- Game view (4.4+, встроенное окно игры): пауза F9, шаг кадра F10, скорость игры (4.6), выбор узлов 2D/3D прямо в игре, свободная камера, mute (4.5). Изменения через выбранные удалённые узлы теряются при остановке. Чтобы правки сохранились, редактируйте локальную сцену с **Debug → Synchronize Scene Changes**.
- Внешний редактор (VS Code, Rider) и LSP описаны в [toolchain.md](toolchain.md#4-редакторы-lsp-и-отладчик).
- Пока проект маленький, сразу настройте **Project → Customize Engine Build Configuration** и **Editor → Manage Editor Features** (профили, которые скрывают 3D для 2D-команды).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Inspector Dock](https://docs.godotengine.org/en/stable/tutorials/editor/inspector_dock.html) | Godot docs, 2026 | Quick Load, Make Unique, Favorite |
| [Script Editor](https://docs.godotengine.org/en/stable/tutorials/editor/script_editor.html) | Godot docs, 2026 | Поиск, закладки, сочетания |
| [Customizing the interface](https://docs.godotengine.org/en/stable/tutorials/editor/customizing_editor.html) | Godot docs, 2026 | Раскладки, плавающие доки |
| [Game embedding](https://docs.godotengine.org/en/stable/tutorials/editor/game_embedding.html) | Godot docs, 2026 | Game view, выбор узлов, live edit |
| [Using the Project Manager](https://docs.godotengine.org/en/stable/tutorials/editor/project_manager.html) | Godot docs, 2026 | Duplicate, бэкап перед апгрейдом |
| [Managing editor features](https://docs.godotengine.org/en/stable/tutorials/editor/managing_editor_features.html) | Godot docs, 2026 | Профили фич редактора |
| [UID changes coming to Godot 4.4](https://godotengine.org/article/uid-changes-coming-to-godot-4-4/) | Godot Foundation, 2024 | Зачем `.uid`-файлы и как с ними жить |
| [Godot 4.6 release](https://godotengine.org/releases/4.6/) | Godot Foundation, 2026 | Доки, Quick Open с превью, Step Out |
| [Godot 4.7 release](https://godotengine.org/releases/4.7/) | Godot Foundation, 2026 | Инспектор, загрузчик шаблонов, Android |

## 7. Отладчик: вкладки и удалённое дерево

### Ключевые выводы
- **Remote** в доке Scene показывает живое дерево запущенной игры, инспектор удалённых узлов позволяет редактировать их на лету. С 4.5 можно править несколько узлов сразу, с 4.7 видны имена enum. Это самый быстрый способ найти утечку узлов или неверный `process_mode`.
- **Errors** собирает `push_error`/`push_warning` и ошибки движка со стеком. Перед релизом вкладка должна быть пустой: каждая строка здесь — потенциальный баг в экспорте.
- **Evaluator** (4.4+) вычисляет выражения на точке останова с доступом к локальным переменным. **Step Out** появился в 4.6.
- **Profiler** показывает время скриптов и функций. **Visual Profiler** показывает CPU/GPU время рендера по проходам и не работает с Compatibility на macOS. **Network Profiler** — трафик RPC и синхронизаторов. **Monitors** — FPS, память, объекты, draw calls, свои метрики через `Performance.add_custom_monitor`. **Video RAM** — текстуры и буферы по размеру. **Misc** — какой Control под кликом. В 4.6 добавились снимки ObjectDB с диффом для поиска утечек.
- Флаги **Debug**: Visible Collision Shapes, Visible Navigation, Visible Paths и Redraw Regions. **Deploy with Remote Debug** нужен для отладки на телефоне.
- Профилирование и бенчмарки описаны в [performance.md](performance.md#профилирование-и-мониторы), отладка из CLI — в [toolchain.md](toolchain.md#6-отладка).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Debugger panel](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/debugger_panel.html) | Godot docs, 2026 | Все вкладки отладчика |
| [Overview of debugging tools](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/overview_of_debugging_tools.html) | Godot docs, 2026 | Меню Debug, remote debug |
| [The Profiler](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html) | Godot docs, 2026 | Чтение профиля |
| [Godot 4.4 release](https://godotengine.org/releases/4.4/) | Godot Foundation, 2025 | Evaluator, Game view, автостарт профайлеров |

## 8. Пресеты экспорта и export_presets.cfg

### Ключевые выводы
- `export_presets.cfg` коммитится: в нём платформа, фильтры, теги и опции. Секреты (пароли keystore, ключ шифрования, пароли сертификатов) редактор сохраняет отдельно в `.godot/export_credentials.cfg`, который в git не попадает. На новой машине и в CI секреты передаются через переменные окружения (`GODOT_SCRIPT_ENCRYPTION_KEY`, `GODOT_ANDROID_KEYSTORE_*`, `GODOT_WINDOWS_CODESIGN_*`, `GODOT_MACOS_*`, `GODOT_IOS_*`).
- Ключи секции пресета в 4.7.2: `name`, `platform`, `dedicated_server`, `custom_features`, `export_filter` (`all_resources` | `scenes` | `resources` | `exclude` | `customized`), `include_filter`, `exclude_filter`, `export_path`, `patches`, `patch_delta_*`, `encryption_include_filters`, `encryption_exclude_filters`, `seed`, `encrypt_pck`, `encrypt_directory`, `script_export_mode` (проверено по исходникам 4.7.2). Опции платформы лежат в `[preset.N.options]`.
- `script_export_mode` по умолчанию — бинарные токены со сжатием: в PCK лежат `.gdc` и `.gd.remap` вместо `.gd` (проверено на 4.7.2). Режим Text оставьте для отладки модов. Байткод не защищает код, декомпиляторы (GDRE Tools) его читают.
- Debug против release. **Export With Debug** включает debug-шаблон: проверки, `assert`, удалённый отладчик и сообщения в консоль. Игрокам отдавайте только release. Debug-сборку держите отдельным пресетом для тестеров.
- Пресет **Dedicated Server** (или `dedicated_server=true`) заменяет текстуры, меши и звук заглушками. Сервер собирайте отдельным пресетом.
- Из CLI: `--export-pack` работает **без шаблонов** (код 0), а `--export-release` без шаблонов падает с сообщением «export templates not found at expected path …/export_templates/4.7.2.stable/windows_release_x86_64.exe» и кодом 1. Неизвестное имя пресета и несуществующий каталог вывода тоже дают код 1 (проверено на 4.7.2). Остальные флаги — в [toolchain.md](toolchain.md#11-экспорт-и-ci).
- С 4.7 менеджер шаблонов умеет скачивать шаблоны для отдельной платформы или архитектуры, а не весь архив `.tpz` на гигабайт.

```ini
; export_presets.cfg (фрагмент, Godot 4.7)
[preset.0]
name="Windows"
platform="Windows Desktop"
runnable=true
dedicated_server=false
custom_features="steam"
export_filter="all_resources"
include_filter="data/*.txt, licenses/*"
exclude_filter="tests/*, *.psd, docs/*"
export_path="build/windows/MyGame.exe"
encrypt_pck=false
script_export_mode=2

[preset.0.options]
binary_format/embed_pck=true
binary_format/architecture="x86_64"
application/modify_resources=true
application/icon="res://branding/icon.ico"
application/company_name="My Studio"
application/product_name="My Game"
codesign/enable=false
debug/export_console_wrapper=1
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Exporting projects](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html) | Godot docs, 2026 | Режимы экспорта, фильтры, credentials |
| [Exporting for dedicated servers](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html) | Godot docs, 2026 | Серверный пресет |
| [One-click deploy](https://docs.godotengine.org/en/stable/tutorials/export/one-click_deploy.html) | Godot docs, 2026 | Запуск на устройстве, SSH-деплой |
| [editor_export.cpp в 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/editor/export/editor_export.cpp) | Godot, 2026 | Точный формат `export_presets.cfg` |
| [EditorExportPlugin](https://docs.godotengine.org/en/stable/classes/class_editorexportplugin.html) | Godot docs, 2026 | Свои шаги экспорта (добавить или удалить файлы) |

## 9. Фильтры ресурсов: что попадает в PCK

### Ключевые выводы
- Экспортируются только **ресурсы**, то есть файлы, которые Godot умеет загружать или импортировать, плюс их зависимости. Произвольные файлы добавляет поле **Filters to export non-resource files/folders** (`include_filter`). Файлы и каталоги, имя которых начинается с точки, не экспортируются никогда.
- **`.json` в 4.x — это ресурс** (загрузчик `JSON`). Он попадает в PCK без фильтра, `load("res://x.json")` возвращает объект `JSON`, `FileAccess` тоже его читает. Совет «добавьте `*.json` в include filter» для 4.x [устарело]; в документации он остался (проверено на 4.7.2).
- **`.txt`, `.md`, `.yaml`, `.bin`, `.db` без фильтра в PCK не попадают.** В редакторе `FileAccess.file_exists("res://data/notes.txt")` возвращает `true`, в экспорте `false`. С `include_filter="*.txt"` файл на месте (проверено на 4.7.2).
- **`.csv` по умолчанию импортируется как перевод** (`csv_translation`). В PCK уходит только `.csv.import` (и `.translation`, если CSV — таблица переводов), сам CSV туда не попадает, даже с include filter. Если CSV — таблица данных (карты, баланс), в доке Import выберите **Keep File (exported as is)** (`importer="keep"`): тогда сырой CSV экспортируется (проверено на 4.7.2).
- В экспорте исходников сцен и скриптов нет: `FileAccess.file_exists("res://main.tscn")` даёт `false`, `ResourceLoader.exists()` — `true`. `DirAccess.get_files_at("res://")` возвращает `main.gd.remap`, `main.gdc`, `main.tscn.remap` (проверено на 4.7.2). Сканируя каталоги, отрезайте `.remap`/`.import` или используйте `ResourceLoader.list_directory()` (4.4+), а проверку существования делайте через `ResourceLoader.exists()`. `list_directory` возвращает только ресурсы: в `data/` он показал `cards.json` и `table.csv`, но не `notes.txt` (проверено на 4.7.2).
- `exclude_filter` вырезает тесты, исходники арта (`*.psd`, `*.blend`, `*.kra`) и инструменты редактора. Аддоны только для редактора (`addons/gut/*`) исключайте явно, иначе они попадут в сборку.
- Проверка состава: соберите `.zip` вместо `.pck` (`--export-pack "Windows" build/check.zip`) и посмотрите `unzip -l`. У `.pck` своя сигнатура `GDPC` (проверено на 4.7.2). Для `.pck` есть GodotPckTool.

```ini
; include/exclude: данные, которые читаются через FileAccess, явно
include_filter="data/*.txt, data/*.yaml, mods/README.md"
exclude_filter="tests/*, addons/gut/*, art_src/*, *.psd, *.kra"
```

```gdscript
# Сканирование каталога, которое работает и в редакторе, и в экспорте (4.4+)
func list_cards() -> PackedStringArray:
	var out := PackedStringArray()
	for f in ResourceLoader.list_directory("res://cards/"):
		if f.ends_with(".tres"):
			out.append("res://cards/" + f)
	return out
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Exporting projects: resource options](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html#resource-options) | Godot docs, 2026 | Описание фильтров |
| [Localization using spreadsheets](https://docs.godotengine.org/en/stable/tutorials/i18n/localization_using_spreadsheets.html) | Godot docs, 2026 | Почему CSV по умолчанию становится переводом |
| [ResourceLoader class](https://docs.godotengine.org/en/stable/classes/class_resourceloader.html) | Godot docs, 2026 | `exists`, `list_directory` |
| [GodotPckTool](https://github.com/hhyyrylainen/GodotPckTool) | hhyyrylainen, 2025 | Список и распаковка `.pck` |

## 10. PCK, ZIP, встраивание, патчи и шифрование

### Ключевые выводы
- PCK не сжат: читается быстрее, его не открыть стандартными инструментами. ZIP сжат и удобен для модов, но экспортированный бинарник не подхватывает его автоматически (известный баг), нужен `--main-pack`. Для основного пакета берите PCK.
- `binary_format/embed_pck=true` даёт один исполняемый файл, удобно для itch.io. Предел на Windows — около 3,89 ГБ на exe вместе с PCK. Для больших игр и Steam-патчей держите отдельный `.pck`: SteamPipe лучше считает дельту `[не проверено]`.
- Дополнительные паки (DLC, моды, патчи): `ProjectSettings.load_resource_pack(path, replace_files=true, offset=0)`. Загружайте их в `_init()` автозагрузки, до preload сцен, иначе старые версии ресурсов останутся в кеше.
- Патчи (4.4+): в пресете вкладка **Patching**, базовые паки и **Export as Patch**. В PCK попадают только изменённые ресурсы. С 4.6 есть **delta encoding**: в патч идут только изменённые части ресурса, но каждый следующий дельта-патч добавляет время загрузки. Базовые паки должны побайтно совпадать с тем, что реально у игроков.
- Шифрование PCK: ключ `openssl rand -hex 32` → соберите **свои шаблоны** с `SCRIPT_AES256_ENCRYPTION_KEY` → в пресете **Encryption** укажите ключ и include-фильтры (по умолчанию пусто, и ничего не шифруется) → экспорт. Официальные шаблоны ключа не знают. В проверке PCK с `encrypt_pck=true` экспортировался, но стандартный бинарник с `--main-pack` не загрузил его и завис без сообщений (проверено на 4.7.2); в документации описана ошибка `ERR_FILE_CORRUPT`. Ключ лежит внутри exe. Это защита от случайного любопытства, не DRM.
- Свои шаблоны (урезанные модули, `optimize=size`, шифрование, патчи движка) описаны в [performance.md](performance.md#сборка-экспорт-web-и-мобильные). Путь к ним задаётся в пресете: `custom_template/debug` и `custom_template/release`.
- Shader baker (4.5+, `shader_baker/enabled` в пресете) заранее компилирует шейдеры под драйвер платформы. В демо TPS загрузка на Metal и D3D12 ускорилась до 20 раз. Включайте для 3D на desktop и Apple.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Exporting packs, patches, and mods](https://docs.godotengine.org/en/stable/tutorials/export/exporting_pcks.html) | Godot docs, 2026 | `load_resource_pack`, патчи, моды |
| [Compiling with PCK encryption key](https://docs.godotengine.org/en/stable/engine_details/development/compiling/compiling_with_script_encryption_key.html) | Godot docs, 2026 | Шифрование по шагам |
| [Optimizing a build for size](https://docs.godotengine.org/en/stable/engine_details/development/compiling/optimizing_for_size.html) | Godot docs, 2026 | Свои шаблоны |
| [GDRE Tools](https://github.com/GDRETools/gdsdecomp) | GDRETools, 2026 | Что достаётся из вашего PCK; полезно знать |

## 11. Особенности платформ

### Ключевые выводы
- **Windows.** С 4.5 иконку, имя продукта, компанию и версию в exe пишет сам экспортёр (`application/modify_resources=true`). `rcedit` больше не нужен [устарело для 4.5+]. Иконка принимает `.ico/.png/.webp/.svg`, но для чёткой картинки на всех размерах лучше свой `.ico`. Подпись: signtool (Windows SDK) или osslsigncode, путь в Editor Settings → Export → Windows, в пресете `codesign/enable`. Без подписи SmartScreen пугает игроков. `debug/export_console_wrapper` создаёт `*.console.exe` для вывода логов. Для D3D12 экспортёр кладёт Agility SDK (`export_d3d12=Auto`).
- **macOS.** Официальные шаблоны дают Universal 2 (`x86_64` + `arm64`). Подпись: Xcode codesign на Mac или rcodesign с Linux/Windows. Нотаризация через notarytool/rcodesign, нужен Developer ID и Apple ID с app-specific password или ключ App Store Connect API; после неё — staple. Для GDExtension в Hardened Runtime включите **Disable Library Validation**, для релиза выключите Debugging entitlement. `.app`, экспортированный из Windows, теряет флаг исполнения: экспортируйте в ZIP/DMG или делайте `chmod +x`. Минимальные версии в 4.7.2: `min_macos_version_x86_64=11.00`, `arm64=13.00` (по исходникам).
- **Linux и Steam Deck.** Один бинарник `x86_64` (есть `arm64`). На Deck проверьте 1280×800, Vulkan, геймпадные глифы, экранную клавиатуру и сохранения в `~/.local/share/...` (Steam Cloud). Подробности — в [domains.md](domains.md#10-мультиплеер-и-платформы).
- **Android.** JDK 17. В 4.7.2 Gradle-шаблон использует `minSdk 24`, `targetSdk 36`, `compileSdk 36`, NDK 29 (по `config.gradle` тега 4.7.2; страница документации ещё указывает SDK 35 и NDK r28b). Google Play с августа 2021 принимает только AAB, а AAB требует **Gradle build**: **Project → Install Android Build Template**, каталог `res://android/build`. Он коммитится, если вы его правите. Release keystore: `keytool -v -genkey -keystore mygame.keystore -alias mygame -keyalg RSA -validity 10000`, пароли keystore и ключа должны совпадать. С 4.5 поддерживаются 16 KB страницы памяти (обязательны для Play с ноября 2025) и `screen/edge_to_edge`. 4.7: настройка splash в пресете, PiP, GABE для сборки на устройстве. `version/code` увеличивайте с каждым релизом. Разрешения отмечайте в пресете минимально, остальное спрашивайте в рантайме.
- **iOS.** Только macOS с Xcode. Экспорт создаёт Xcode-проект. Обязательны App Store Team ID (10 символов) и уникальный bundle id. Для быстрой итерации можно не реэкспортировать: подключите папку проекта в Xcode и пропишите `godot_path` в Info.plist. С 4.7 есть HDR-вывод.
- **Web.** Только Compatibility. По умолчанию `variant/thread_support=false`, `extensions_support=false`, `progressive_web_app/enabled=false`, `vram_texture_compression/for_desktop=true`, `for_mobile=false` (по исходникам 4.7.2). Многопоточный вариант и GDExtension требуют заголовков `Cross-Origin-Opener-Policy: same-origin` и `Cross-Origin-Embedder-Policy: require-corp` или PWA (`ensure_cross_origin_isolation_headers` подставит их через service worker). Отдавайте `.wasm` с MIME `application/wasm` и сжатием gzip/brotli: wasm сжимается примерно до четверти. Ограничения браузера: звук только после жеста, полный экран и захват курсора только в обработчике ввода, буфер обмена только в secure context, `user://` в IndexedDB, неактивная вкладка останавливает `_process`. Для мобильного Web включите `for_mobile` (ETC2/ASTC). Локальный тест — `serve.py` из репозитория Godot, а не открытие `index.html` из файловой системы.
- **Консоли.** Официальных шаблонов нет: W4 Games, RAWRLAB или студии портирования ([domains.md](domains.md#10-мультиплеер-и-платформы)). Не завязывайтесь на `OS.execute`, файловую систему вне `user://` и сторонние GDExtension без исходников.

| Платформа | Шаблон / требования | Подпись и публикация | Главные ловушки |
|---|---|---|---|
| Windows | `windows_release_x86_64.exe`; arm64 есть | signtool/osslsigncode, `GODOT_WINDOWS_CODESIGN_*` | SmartScreen без подписи; лимит ~3,89 ГБ для embed; антивирусы на неподписанный exe с PCK |
| macOS | Universal 2 `.app` в ZIP/DMG | Developer ID + notarization + staple; rcodesign вне Mac | Потеря `+x` при экспорте из Windows; Library Validation и GDExtension; Gatekeeper без нотаризации |
| Linux / Steam Deck | `linux_release.x86_64` | Steam runtime; `.desktop` и иконка вручную | Регистр в путях `res://`; Wayland против X11; 1280×800 |
| Android | Gradle build, JDK 17, SDK 36, NDK 29 | Release keystore, AAB для Play, `GODOT_ANDROID_KEYSTORE_*` | Debug-ключ в релизе; `version/code` не увеличен; лишние permissions; ETC2/ASTC не импортированы |
| iOS | Mac + Xcode, Team ID | Подпись и Provisioning в Xcode | Пустой Team ID — ошибка экспорта; разрешения в Info.plist |
| Web | Compatibility, `nothreads` по умолчанию | Любой хостинг; для threads — COOP/COEP | Нет звука до клика; IndexedDB в приватном режиме; размер wasm; нет C# |
| Консоли | Шаблоны партнёров под NDA | Через W4 Games или порт-студию | GDExtension под консоль, сертификация |

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Exporting for Windows](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html) | Godot docs, 2026 | Иконка, подпись, embed |
| [Changing application icon for Windows](https://docs.godotengine.org/en/stable/tutorials/export/changing_application_icon_for_windows.html) | Godot docs, 2026 | Многоразмерный `.ico` |
| [Exporting for macOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html) | Godot docs, 2026 | Подпись, нотаризация, entitlements |
| [Running Godot apps on macOS](https://docs.godotengine.org/en/stable/tutorials/export/running_on_macos.html) | Godot docs, 2026 | Что видит игрок без нотаризации |
| [Exporting for Linux](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_linux.html) | Godot docs, 2026 | Архитектуры, SSH-деплой |
| [Exporting for Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) | Godot docs, 2026 | SDK, keystore, иконки |
| [Gradle builds for Android](https://docs.godotengine.org/en/stable/tutorials/export/android_gradle_build.html) | Godot docs, 2026 | AAB, свой Android-проект |
| [EditorExportPlatformAndroid](https://docs.godotengine.org/en/stable/classes/class_editorexportplatformandroid.html) | Godot docs, 2026 | Все опции пресета Android |
| [config.gradle в 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/java/app/config.gradle) | Godot, 2026 | Фактические версии SDK/NDK |
| [Target API requirements](https://developer.android.com/google/play/requirements/target-sdk) | Google, живой | Требования Play к targetSdk |
| [Support 16 KB page sizes](https://developer.android.com/guide/practices/page-sizes) | Google, живой | Требование 16 KB |
| [Exporting for iOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html) | Godot docs, 2026 | Team ID, Xcode-проект |
| [Exporting for visionOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_visionos.html) | Godot docs, 2026 | Окно в visionOS (4.5+) |
| [Exporting for the Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html) | Godot docs, 2026 | Потоки, заголовки, ограничения |
| [EditorExportPlatformWeb](https://docs.godotengine.org/en/stable/classes/class_editorexportplatformweb.html) | Godot docs, 2026 | Опции PWA, HTML shell |
| [Web platform docs](https://docs.godotengine.org/en/stable/tutorials/platform/web/index.html) | Godot docs, 2026 | `JavaScriptBridge`, HTML shell |
| [serve.py](https://github.com/godotengine/godot/blob/master/platform/web/serve.py) | Godot, 2026 | Локальный сервер с COOP/COEP |
| [Web export in 4.3](https://godotengine.org/article/progress-report-web-export-in-4-3/) | Adam Scott, 2024 | Почему однопоточный экспорт по умолчанию |
| [Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) | Apple, живой | Процесс нотаризации |
| [apple-codesign (rcodesign)](https://gregoryszorc.com/docs/apple-codesign/stable/) | Gregory Szorc, 2025 | Подпись Mac-сборок с Linux/Windows |
| [SignTool](https://learn.microsoft.com/en-us/windows/win32/seccrypto/signtool) | Microsoft, живой | Подпись Windows-сборок |
| [osslsigncode](https://github.com/mtrojnar/osslsigncode) | mtrojnar, 2025 | Authenticode-подпись вне Windows |
| [Steam Deck recommendations](https://partner.steamgames.com/doc/steamdeck/recommendations) | Valve, живой | Совместимость Deck |
| [Console support in Godot](https://godotengine.org/consoles/) | Godot Foundation, живой | Партнёры по консолям |
| [W4 Games](https://www.w4games.com/) | W4 Games, живой | Консольные порты |

## 12. Версионирование

### Ключевые выводы
- `application/config/version` — единый источник версии. Пустые поля `application/file_version` и `product_version` (Windows), `application/short_version` и `version` (macOS, iOS) подставляют версию проекта ([по подсказкам опций в исходниках 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/windows/export/export_plugin.cpp)). На Android `version/name` тоже берётся из проекта, если оставить пустым `[не проверено]`, а `version/code` — целое число, которое увеличивают вручную или в CI.
- Windows требует числовой формат `X.Y.Z.W`. Суффиксы вроде `-beta` в `file_version` не пишите, держите их в отдельной строке «build».
- В рантайме: `ProjectSettings.get_setting("application/config/version")` (проверено на 4.7.2: `"1.2.3"`). Показывайте версию в главном меню и пишите её в лог и в каждое сохранение, чтобы поддерживать миграцию сохранений.
- В CI версию подставляйте из git-тега правкой строки в `project.godot` перед экспортом, а `version/code` — из номера сборки ([toolchain.md](toolchain.md#11-экспорт-и-ci)).

```gdscript
const SAVE_FORMAT := 3
func save_header() -> Dictionary:
	return {
		"game_version": ProjectSettings.get_setting("application/config/version"),
		"engine": Engine.get_version_info().string,
		"save_format": SAVE_FORMAT,
	}
```

## 13. Чеклист перед релизом

| # | Проверка | Как |
|---|---|---|
| 1 | Экспорт — release, не debug | В пресете снят Export With Debug; CI зовёт `--export-release` |
| 2 | Шаблоны экспорта той же версии, что редактор (4.7.2) | Менеджер шаблонов; `export_templates/4.7.2.stable` |
| 3 | `application/config/version` обновлена | Сверить с тегом git |
| 4 | Android `version/code` увеличен | Play отклонит повтор |
| 5 | `use_custom_user_dir` и `custom_user_dir_name` заданы | Сохранения в предсказуемом месте |
| 6 | Имя, иконка, компания, копирайт в пресетах | Свойства exe, `Info.plist`, лаунчер Android |
| 7 | Все файлы, читаемые через `FileAccess`, есть в PCK | Тестовый `.zip`-экспорт и `unzip -l`; запуск экспортированной сборки |
| 8 | CSV-данные с импортом Keep File | Иначе в PCK только перевод |
| 9 | Исключены тесты, исходники арта, editor-only аддоны | `exclude_filter`; размер PCK до и после |
| 10 | Нет ошибок во вкладке Errors на полном прохождении | Debug-сборка у тестеров |
| 11 | Игра проверена именно из экспорта, не только из редактора | Отдельный QA-проход по release-сборке |
| 12 | Нет проверок `OS.has_feature("editor")`, за которыми прячется логика игры | grep по проекту |
| 13 | Удалены отладочные чит-меню или они закрыты тегом `debug` | `OS.is_debug_build()` |
| 14 | Логи: файловый лог включён на desktop, сообщение crash handler заменено | `debug/settings/crash_handler/message` |
| 15 | В release нужные стеки: `always_track_call_stacks` или Sentry | Тестовая ошибка в release |
| 16 | Опции видео: оконный режим, vsync, лимит FPS, масштаб UI | Меню настроек + `user://settings.cfg` |
| 17 | Проверены 16:9, 16:10, 21:9, 4:3 и 1280×800 (Deck) | Окно с изменяемым размером |
| 18 | HiDPI и масштаб 150–200% на Windows | `allow_hidpi=true`, Exclusive Fullscreen |
| 19 | Мобильные: ETC2/ASTC включены, текстуры переимпортированы | `import_etc2_astc=true` |
| 20 | Мобильные: ограничен FPS, проверены нагрев и батарея | `max_fps.mobile` |
| 21 | Android: release keystore, AAB, targetSdk отвечает требованиям Play | Пресет и секреты через env |
| 22 | Android: минимальный набор permissions, рантайм-запросы | Пресет `permissions/*` |
| 23 | Android: 16 KB страницы, edge-to-edge и безопасная зона | `get_display_safe_area()` |
| 24 | iOS: Team ID, bundle id, Info.plist с описаниями разрешений | Xcode |
| 25 | macOS: подпись Developer ID, нотаризация, staple | `spctl -a -vv` на чистом Mac |
| 26 | Windows: exe подписан, проверен на чистой машине без SDK | SmartScreen, антивирус |
| 27 | Web: проверено на целевом хостинге (itch.io, свой сервер) в Chrome, Firefox, Safari | Звук после клика, сохранения |
| 28 | Web: wasm и pck отдаются сжатыми и с правильным MIME | DevTools → Network |
| 29 | Web: для threads/GDExtension настроены COOP/COEP или PWA | `crossOriginIsolated` в консоли |
| 30 | Переводы: все `.translation` подключены, проверена псевдолокализация | `internationalization/locale/translations` |
| 31 | Шрифты содержат нужные глифы (кириллица, CJK) или есть fallback | Тест на каждой локали |
| 32 | Пароли и ключи не в git (`export_credentials.cfg` в `.gitignore`) | `git ls-files` |
| 33 | Shader baker включён для 3D на desktop и Apple, проверено время первой загрузки | Пресет `shader_baker/enabled` |
| 34 | Первая загрузка и стоп-кадры при компиляции шейдеров проверены на слабом GPU | Холодный кеш |
| 35 | Выход из игры: сохранение при закрытии окна и на Android при `NOTIFICATION_WM_GO_BACK_REQUEST` | `auto_accept_quit`, `quit_on_go_back` |
| 36 | Пауза при потере фокуса (`NOTIFICATION_APPLICATION_FOCUS_OUT`) и на мобильных при сворачивании | Ручной тест |
| 37 | Сборка воспроизводима в CI из чистого клона | [toolchain.md](toolchain.md#11-экспорт-и-ci) |
| 38 | Сохранён символьный или отладочный артефакт этой сборки и `export_presets.cfg` | Архив релиза |

## 14. Антипаттерны

### Ключевые выводы
- **Проверять игру только в редакторе.** Из редактора видны все `.txt`, `.gd` и `.tscn`, а `res://` доступен на запись. В экспорте этого нет. Каждый спринт запускайте экспортированную сборку, хотя бы `--export-pack` + `--main-pack`.
- **Забыть include filter для `.txt/.yaml/.md` или оставить CSV-данные импортом-переводом.** В редакторе всё работает, у игрока «пустые карты». Для `.json` фильтр в 4.x не нужен (проверено на 4.7.2).
- **Проверять существование ресурса через `FileAccess.file_exists("res://...tscn")` или сканировать `DirAccess` без учёта `.remap`.** В экспорте исходников нет. Используйте `ResourceLoader.exists()` и `list_directory()`.
- **Отдавать игрокам debug-экспорт.** Он медленнее, печатает внутренности и держит открытым удалённый отладчик.
- **Читать свои тегированные настройки через `get_setting()`.** Теги игнорируются; нужен `get_setting_with_override()`.
- **Писать в `res://` или `ProjectSettings.save()` в рантайме.** В экспорте `res://` только для чтения. Пишите в `user://`.
- **Переносить файлы мимо FileSystem-дока** без `.uid`. Ссылки ломаются тихо, до запуска экспорта.
- **Коммитить `.godot/` или `export_credentials.cfg`.** Ключи утекают, мусор раздувает репозиторий ([toolchain.md](toolchain.md#10-git-что-коммитить)).
- **Считать шифрование PCK или байткод защитой.** Ключ лежит в exe, GDRE Tools восстанавливает скрипты. Секреты сервера в клиент не кладите вообще.
- **Включать threads в Web «для скорости»** без COOP/COEP-хостинга. Игра не стартует на itch.io и порталах [устарело как совет по умолчанию с 4.3].
- **Оставлять стандартный `max_fps=0` и vsync off на мобильных.** Перегрев, троттлинг, низкие оценки.
- **Менять `config/name` после релиза без `custom_user_dir_name`.** Сохранения игроков «исчезают».
- **Один пресет на всё.** Отдельные пресеты для демо (тег `demo`), Steam (`steam`), сервера (`dedicated_server`) и тестеров (debug) избавляют от ручных правок перед каждой сборкой.

## 15. Ресурсы

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Export (раздел)](https://docs.godotengine.org/en/stable/tutorials/export/index.html) | Godot docs, 2026 | Все страницы об экспорте |
| [Editor introduction](https://docs.godotengine.org/en/stable/tutorials/editor/index.html) | Godot docs, 2026 | Все страницы о редакторе |
| [Command line tutorial](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html) | Godot docs, 2026 | Флаги экспорта (подробно — toolchain.md) |
| [Using an external text editor](https://docs.godotengine.org/en/stable/tutorials/editor/external_editor.html) | Godot docs, 2026 | Настройка VS Code/Rider |
| [Engine compilation configuration editor](https://docs.godotengine.org/en/stable/tutorials/editor/using_engine_compilation_configuration_editor.html) | Godot docs, 2026 | Профиль сборки `.gdbuild` |
| [Internationalizing games](https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html) | Godot docs, 2026 | Настройки локализации |
| [Godot 4.5 release](https://godotengine.org/releases/4.5/) | Godot Foundation, 2025 | Shader baker, Windows без rcedit, 16 KB, SIMD |
| [Godot 4.6 release](https://godotengine.org/releases/4.6/) | Godot Foundation, 2026 | D3D12 и Jolt по умолчанию, delta-патчи, доки |
| [Godot 4.7 release](https://godotengine.org/releases/4.7/) | Godot Foundation, 2026 | Загрузчик шаблонов, Android splash, HDR |
| [Maintenance release 4.7.2](https://godotengine.org/article/maintenance-release-godot-4-7-2/) | Godot Foundation, 2026 | Исправления актуального патча |
| [Windows export_plugin.cpp в 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/windows/export/export_plugin.cpp) | Godot, 2026 | Опции Windows-пресета |
| [macOS export_plugin.cpp в 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/macos/export/export_plugin.cpp) | Godot, 2026 | Опции macOS-пресета |
| [Web export_plugin.cpp в 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/export/export_plugin.cpp) | Godot, 2026 | Значения по умолчанию Web-пресета |
| [Godot issues: export label](https://github.com/godotengine/godot/issues?q=is%3Aissue+label%3Atopic%3Aexport) | Godot, живой | Известные баги экспорта перед релизом |

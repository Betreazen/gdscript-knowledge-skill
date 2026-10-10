# UI, ввод и экраны в Godot 4

Справочник по тому, как правильно и без лишней нагрузки пользоваться системой Control, темами, текстом, вводом и масштабированием экрана в Godot 4. Здесь разобраны якоря и size flags, выбор контейнера, HUD на `CanvasLayer`, темы и шрифты, `Label` и `RichTextLabel`, порядок колбэков ввода, `mouse_filter`, фокус и навигация с геймпада, InputMap и переназначение, геймпад, тач и мышь, режимы растяжения и hiDPI, окна и диалоги, drag-and-drop (основа карточных игр), анимация UI, производительность, доступность и локализация интерфейса. В конце — антипаттерны и чеклист. Актуально на октябрь 2026, Godot 4.7.2 (4.7 вышла 18 июня 2026). Пометка «(проверено на 4.7.2)» — поведение или значение по умолчанию получено headless-скриптом на `Godot_v4.7.2-stable`. `[устарело]` — API Godot 3 или ранних 4.x, рядом указана замена. `[не проверено]` — утверждение из памяти или вторичного источника.

Обзор UI-домена и аддонов — в [domains.md, раздел 3](domains.md#3-ui-и-приложения-не-игры), формат переводов (CSV/PO, `tr_n`, контекст) — в [domains.md, раздел 7](domains.md#7-диалоги-нарратив-и-локализация), переназначение клавиш в архитектуре проекта — в [architecture.md](architecture.md#локализация-и-ввод), общие правила «ввод через колбэки, UI обновлять по изменению» — в [performance.md](performance.md#узлы-дерево-сцены-и-обработка-кадров).

- [Раскладка Control: якоря, смещения, size flags](#раскладка-control-якоря-смещения-size-flags)
- [Контейнеры](#контейнеры)
- [HUD: CanvasLayer, Control или Node2D](#hud-canvaslayer-control-или-node2d)
- [Темы, шрифты и StyleBox](#темы-шрифты-и-stylebox)
- [Текст: Label, LabelSettings, RichTextLabel](#текст-label-labelsettings-richtextlabel)
- [Конвейер ввода: порядок колбэков](#конвейер-ввода-порядок-колбэков)
- [mouse_filter: почему клик не доходит](#mouse_filter-почему-клик-не-доходит)
- [Фокус и навигация с клавиатуры и геймпада](#фокус-и-навигация-с-клавиатуры-и-геймпада)
- [InputMap, действия, опрос и события](#inputmap-действия-опрос-и-события)
- [Геймпад, тач, мышь и курсор](#геймпад-тач-мышь-и-курсор)
- [Несколько разрешений, hiDPI и safe area](#несколько-разрешений-hidpi-и-safe-area)
- [Окна, попапы и диалоги](#окна-попапы-и-диалоги)
- [Drag-and-drop](#drag-and-drop)
- [Анимация UI](#анимация-ui)
- [Производительность UI](#производительность-ui)
- [Доступность](#доступность)
- [Локализация интерфейса](#локализация-интерфейса)
- [Антипаттерны](#антипаттерны)
- [Чеклист UI и ввода](#чеклист-ui-и-ввода)

## Раскладка Control: якоря, смещения, size flags

### Ключевые выводы

- Положение Control вне контейнера задают **якоря** (`anchor_*`, доли 0–1 от прямоугольника родителя) и **смещения** (`offset_*`, пиксели от якоря). Пресеты (`set_anchors_preset(PRESET_FULL_RECT)`, «Full Rect», «Center», «Bottom Wide») — быстрый способ выставить оба. Якоря нужны корню экрана и «плавающим» элементам, всё остальное раскладывают контейнеры.
- Внутри контейнера якоря и `position`/`size` у ребёнка не ваши: в инспекторе свойство `layout_mode` переключается на «Container», и действуют только `size_flags_horizontal/vertical`, `size_flags_stretch_ratio` и `custom_minimum_size`.
- Флаги: `SIZE_FILL` — занять выделенный слот целиком (по умолчанию). `SIZE_EXPAND` — претендовать на свободное место. `SIZE_EXPAND_FILL` — оба. `SIZE_SHRINK_BEGIN/CENTER/END` — остаться минимального размера и прижаться к краю или центру слота. Свободное место делится между расширяемыми детьми пропорционально `size_flags_stretch_ratio`.
- Замер (проверено на 4.7.2): HBox шириной 400 px без промежутков, дети — `min 50` без флагов, `EXPAND_FILL`, `EXPAND_FILL` с ratio 2 и `min 30` с `EXPAND | SHRINK_CENTER`. Ширины вышли 50 / 87 / 175 / 30, последний стоит в центре своего слота шириной 87.5 (x = 341). По вертикали все получили полную высоту 50, потому что вертикальный флаг по умолчанию `FILL`.
- Раскладка отложенная: сразу после `add_child` размеры детей равны нулю, контейнер расставляет их в конце кадра (проверено на 4.7.2). Читайте `size` после `await get_tree().process_frame`, в сигнале `resized` или `Container.sort_children`.
- `custom_minimum_size` — главный инструмент «не меньше чем». В 4.7.2 у Control есть и `custom_maximum_size` с `propagate_maximum_size` (проверено на 4.7.2: свойства существуют; версия появления `[не проверено]`).
- `layout_direction` (наследуется, по умолчанию `INHERITED`) управляет RTL. Контейнеры и якоря зеркалятся автоматически при RTL-локали; для своих рисующих контролов проверяйте `is_layout_rtl()`. Демо — `gui/ui_mirroring`.
- `clip_contents` обрезает детей по прямоугольнику (нужно для своих прокручиваемых областей, у `ScrollContainer` включено само).

```gdscript
# Корень экрана: растянуть на весь родитель (Full Rect), дальше только контейнеры
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	%Sidebar.custom_minimum_size.x = 240
	%Content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	%Content.size_flags_stretch_ratio = 3.0
	await get_tree().process_frame  # размеры появятся только после сортировки
	print(%Content.size)
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Size and anchors](https://docs.godotengine.org/en/stable/tutorials/ui/size_and_anchors.html) | документация Godot, живой | Якоря, смещения, пресеты |
| [Control](https://docs.godotengine.org/en/stable/classes/class_control.html) | справочник API | Все свойства раскладки, фокуса, `mouse_filter`, DnD |
| [UI mirroring demo](https://github.com/godotengine/godot-demo-projects/tree/master/gui/ui_mirroring) | Godot, живой | RTL-зеркалирование раскладки |

## Контейнеры

### Ключевые выводы

- Контейнеры пересчитывают детей при любом изменении размера, минимального размера, видимости или порядка. Ручная `position` ребёнка «работает, пока не перестанет»: в замере (проверено на 4.7.2) выставленная руками позиция держалась, пока контейнер не изменил размер, после чего ребёнок вернулся в (0, 0).
- Невидимый (`visible = false`) ребёнок не занимает места. Это нормальный способ показывать и скрывать блоки без перестройки сцены.
- Вложенность 3–5 уровней (Margin → VBox → HBox) — норма. Не заменяйте её одним Control с ручным расчётом: потеряете адаптивность, RTL и масштаб шрифтов.
- Промежутки задаются темой (`separation` у Box, `h_separation`/`v_separation` у Grid и Flow; у HBox по умолчанию 4 px, проверено на 4.7.2), отступы — `MarginContainer` (`margin_*` в теме). Не вставляйте пустые Control-распорки там, где хватает `separation`.
- Свой контейнер: наследуйте `Container`, в `_notification(NOTIFICATION_SORT_CHILDREN)` вызывайте `fit_child_in_rect()` и переопределите `_get_minimum_size()`; перестановку запрашивайте `queue_sort()`.

### Какой контейнер

| Задача | Контейнер | Замечание |
|---|---|---|
| Строка или столбец элементов | `HBoxContainer` / `VBoxContainer` (или `BoxContainer` с `vertical`) | `alignment` выравнивает всю группу |
| Отступ от краёв, «поля» | `MarginContainer` | Отступы — константы темы `margin_left` и др. |
| Фон под содержимым | `PanelContainer` | StyleBox `panel`; ловит мышь (`STOP`) |
| Сетка фиксированного числа колонок | `GridContainer` | `columns`; инвентарь, клавиатура |
| Перенос по строкам (теги, карты в руке переменной ширины) | `HFlowContainer` / `VFlowContainer` | Адаптивная сетка без расчёта колонок |
| Центрировать одно окно или меню | `CenterContainer` | Дети сохраняют минимальный размер |
| Сохранить пропорции (портрет, превью карты) | `AspectRatioContainer` | `ratio`, `stretch_mode` |
| Делимые панели с ползунком | `HSplitContainer` / `VSplitContainer` | Для приложений и редакторов |
| Прокрутка длинного содержимого | `ScrollContainer` + один ребёнок-контейнер | `follow_focus` по умолчанию выключен (проверено на 4.7.2), включайте для геймпада |
| Вкладки | `TabContainer` (или `TabBar` + свой контент) | Неактивные вкладки скрыты, но существуют |
| Сворачиваемые секции, аккордеон | `FoldableContainer` (4.5+) | Группировка через `FoldableGroup` |
| Свой UI внутри 3D или в отдельном разрешении | `SubViewportContainer` + `SubViewport` | Только он пересылает ввод в SubViewport |

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Using Containers](https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html) | документация Godot, живой | Все контейнеры, size flags, свой контейнер |
| [Container](https://docs.godotengine.org/en/stable/classes/class_container.html) | справочник API | `fit_child_in_rect`, `queue_sort`, `NOTIFICATION_SORT_CHILDREN` |
| [FlowContainer](https://docs.godotengine.org/en/stable/classes/class_flowcontainer.html) / [AspectRatioContainer](https://docs.godotengine.org/en/stable/classes/class_aspectratiocontainer.html) / [SplitContainer](https://docs.godotengine.org/en/stable/classes/class_splitcontainer.html) / [TabContainer](https://docs.godotengine.org/en/stable/classes/class_tabcontainer.html) / [ScrollContainer](https://docs.godotengine.org/en/stable/classes/class_scrollcontainer.html) / [FoldableContainer](https://docs.godotengine.org/en/stable/classes/class_foldablecontainer.html) | справочник API | Перенос, пропорции, панели, вкладки, прокрутка, аккордеон |
| [Custom GUI controls](https://docs.godotengine.org/en/stable/tutorials/ui/custom_gui_controls.html) | документация Godot, живой | Свой Control: `_draw`, минимальный размер, фокус |

## HUD: CanvasLayer, Control или Node2D

### Ключевые выводы

- HUD и меню кладите в `CanvasLayer` (например, `layer = 10`): он не двигается вместе с `Camera2D`, рисуется поверх мира и не зависит от зума. Корень HUD внутри — Control с пресетом Full Rect.
- Control выбирайте для всего, что раскладывается, получает фокус, переводится и масштабируется темой: кнопки, панели, полоски здоровья, тексты. `Node2D` — для элементов, живущих в мире: полоска над головой врага, всплывающие числа урона, маркеры. Смешивать можно: Control внутри Node2D получает позицию родителя, но без якорей.
- Карточная игра: рука, стол и зоны — Control-сцены (контейнеры, DnD, фокус, тема). Эффекты и частицы поверх — отдельный `CanvasLayer` или `Node2D` в отдельном слое.
- Для паузы HUD и меню ставьте `process_mode = PROCESS_MODE_ALWAYS` на корень меню, а миру — `PAUSABLE`; `get_tree().paused = true` остановит мир, но не меню.
- Несколько `CanvasLayer` с разными `layer` — простой способ упорядочить HUD, модальные окна и всплывающие уведомления без борьбы за `z_index`.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Canvas layers](https://docs.godotengine.org/en/stable/tutorials/2d/canvas_layers.html) | документация Godot, живой | Зачем HUD отдельный слой |
| [CanvasLayer](https://docs.godotengine.org/en/stable/classes/class_canvaslayer.html) | справочник API | `layer`, `follow_viewport_enabled` |
| [Viewport and canvas transforms](https://docs.godotengine.org/en/stable/tutorials/2d/2d_transforms.html) | документация Godot, живой | Как связаны координаты мира, слоя и экрана |
| [GUI in 3D demo](https://github.com/godotengine/godot-demo-projects/tree/master/viewport/gui_in_3d) | Godot, живой | UI на поверхности в 3D через SubViewport |

## Темы, шрифты и StyleBox

### Ключевые выводы

- `Theme` — ресурс со стилями по типам узлов: цвета, константы, шрифты, размеры шрифтов, иконки, StyleBox. Тему назначают на корень UI (`theme`), и она распространяется на всех потомков (проверено на 4.7.2: тема на VBox дошла до Label через MarginContainer). Проектная тема — `gui/theme/custom`, проектный шрифт — `gui/theme/custom_font`; по умолчанию оба пустые, базовый размер шрифта 16 (проверено на 4.7.2).
- Порядок поиска значения: локальные `theme_override_*` → тема узла → темы предков вверх по дереву → проектная тема → встроенная тема по умолчанию `[не проверено]` в деталях, в целом так описано в «GUI skinning».
- **Type variations** — именованные варианты типа: `TitleLabel` на базе `Label`, `DangerButton` на базе `Button`. Узлу задают `theme_type_variation = &"TitleLabel"`. Вариант берёт свои значения, остальное наследует от базового типа (проверено на 4.7.2: размер шрифта взят из варианта, цвет — из `Label`).
- `theme_override_*` (в коде `add_theme_color_override()` и т. п.) побеждает тему (проверено на 4.7.2). Используйте его точечно: для динамики (подсветка выбранной карты) или прототипа. Массовые изменения из кода оборачивайте в `begin_bulk_theme_override()` / `end_bulk_theme_override()`, чтобы не пересчитывать тему на каждом вызове.
- StyleBox: `StyleBoxFlat` (скруглённые углы, рамка, тень, без текстур — дешёвый и масштабируемый), `StyleBoxTexture` (9-patch из картинки), `StyleBoxLine`, `StyleBoxEmpty` (убрать фон, сохранив отступы). Состояния кнопки — разные StyleBox: `normal`, `hover`, `pressed`, `disabled`, `focus`.
- Шрифты: `FontFile` (TTF/OTF/WOFF2), `SystemFont` (шрифт ОС), `FontVariation` (жирность, наклон, OpenType-фичи без отдельного файла). Для крупного масштабируемого текста — MSDF (демо `gui/msdf_font`). Fallback-шрифты задают в FontFile (`fallbacks`) — нужно для CJK, эмодзи, арабского.
- Масштаб UI под hiDPI и доступность — через stretch scale и `content_scale_factor` (см. раздел о разрешениях), а не пересборкой темы.
- 4.6: фокус от клика мышью больше не рисует рамку фокуса, стили мышиного и клавиатурного фокуса разделены. Настройка `gui/common/show_focus_state_on_pointer_event` есть в 4.7.2 (проверено на 4.7.2).

```gdscript
# Тема собрана в редакторе (ui/theme/main_theme.tres) и назначена на корень UI.
# В коде — только варианты и точечная динамика.
@onready var _title: Label = %Title

func _ready() -> void:
	_title.theme_type_variation = &"TitleLabel"

func set_selected(card: Control, selected: bool) -> void:
	if selected:
		card.add_theme_stylebox_override(&"panel", preload("res://ui/theme/card_selected.tres"))
	else:
		card.remove_theme_stylebox_override(&"panel")
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [GUI skinning and themes](https://docs.godotengine.org/en/stable/tutorials/ui/gui_skinning.html) | документация Godot, живой | Как тема ищет значения, переопределения |
| [Theme type variations](https://docs.godotengine.org/en/stable/tutorials/ui/gui_theme_type_variations.html) | документация Godot, живой | Варианты типов вместо дублирования |
| [Using the theme editor](https://docs.godotengine.org/en/stable/tutorials/ui/gui_using_theme_editor.html) | документация Godot, живой | Сборка темы в редакторе |
| [Using fonts](https://docs.godotengine.org/en/stable/tutorials/ui/gui_using_fonts.html) | документация Godot, живой | MSDF, fallback, OpenType, системные шрифты |
| [Theme](https://docs.godotengine.org/en/stable/classes/class_theme.html) / [ThemeDB](https://docs.godotengine.org/en/stable/classes/class_themedb.html) | справочник API | API темы, `fallback_font_size` |
| [StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html) / [StyleBoxFlat](https://docs.godotengine.org/en/stable/classes/class_styleboxflat.html) | справочник API | Фоны, рамки, тени |
| [FontFile](https://docs.godotengine.org/en/stable/classes/class_fontfile.html) / [SystemFont](https://docs.godotengine.org/en/stable/classes/class_systemfont.html) / [FontVariation](https://docs.godotengine.org/en/stable/classes/class_fontvariation.html) | справочник API | Типы шрифтов |
| [Theming override demo](https://github.com/godotengine/godot-demo-projects/tree/master/gui/theming_override) / [MSDF font demo](https://github.com/godotengine/godot-demo-projects/tree/master/gui/msdf_font) | Godot, живой | Переопределения из кода, MSDF |

## Текст: Label, LabelSettings, RichTextLabel

### Ключевые выводы

- `Label` по умолчанию не переносит строки и не обрезает текст (`autowrap_mode = OFF`, `text_overrun_behavior = NO_TRIMMING`, проверено на 4.7.2). Поэтому длинная строка раздувает минимальную ширину: в замере 2194 px, и контейнер растягивается за экран.
- Включили `autowrap_mode = AUTOWRAP_WORD_SMART` или `OVERRUN_TRIM_ELLIPSIS` — минимальная ширина падает до 1 px (проверено на 4.7.2). Ширину теперь должен дать контейнер. В VBox шириной 300 px Label с переносом получился 300×179 (7 строк). В HBox без флага расширения — **1×4183 px**, «текст столбиком». С `SIZE_EXPAND_FILL` снова 300×179. Правило: у переносимого Label в HBox ставьте `EXPAND_FILL` или `custom_minimum_size.x`.
- `LabelSettings` — ресурс со шрифтом, размером, контуром, тенью, межстрочным интервалом для Label; один ресурс на много лейблов дешевле и удобнее overrides. С 4.5 поддерживает стек эффектов (несколько контуров и теней).
- `RichTextLabel` — BBCode (`bbcode_enabled` по умолчанию выключен, проверено на 4.7.2): `[b]`, `[color]`, `[img]`, `[url]` (сигнал `meta_clicked`), `[table]`, анимированные эффекты `[wave]`, `[shake]`, `[rainbow]` и свои через `RichTextEffect`. В 4.7 `[img height=1em]` масштабирует картинку по размеру шрифта — удобно для иконок маны и ключевых слов в тексте карт.
- `RichTextLabel` дороже Label: разбор BBCode и шейпинг при каждом присваивании `text`. Не обновляйте его каждый кадр, для лога используйте `append_text()`, а не склейку всего текста. Для больших текстов есть `threaded = true` (по умолчанию выключен). Чтобы он вписался в контейнер по высоте содержимого, включите `fit_content` (по умолчанию выключен).
- Анимация печати — `visible_ratio` / `visible_characters` (есть и у Label, и у RichTextLabel) плюс Tween.
- Текст карт с ключевыми словами: держите шаблон в переводе (`tr("CARD_TEXT_STRIKE")`) и подставляйте числа через `format()`, BBCode-теги — в самом переводе.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [BBCode in RichTextLabel](https://docs.godotengine.org/en/stable/tutorials/ui/bbcode_in_richtextlabel.html) | документация Godot, живой | Теги, эффекты, свой `RichTextEffect` |
| [RichTextLabel](https://docs.godotengine.org/en/stable/classes/class_richtextlabel.html) / [Label](https://docs.godotengine.org/en/stable/classes/class_label.html) / [LabelSettings](https://docs.godotengine.org/en/stable/classes/class_labelsettings.html) | справочник API | `append_text`, `threaded`, `autowrap_mode`, overrun |
| [TextServer](https://docs.godotengine.org/en/stable/classes/class_textserver.html) | справочник API | Константы переноса и обрезки, BiDi |
| [Rich text BBCode demo](https://github.com/godotengine/godot-demo-projects/tree/master/gui/rich_text_bbcode) / [BiDi and font features](https://github.com/godotengine/godot-demo-projects/tree/master/gui/bidi_and_font_features) | Godot, живой | Эффекты, сложные письменности |

## Конвейер ввода: порядок колбэков

### Ключевые выводы

- Порядок по документации: (1) управление встроенными окнами, (2) передача в сфокусированное встроенное окно, (3) `_input`, (4) GUI: `Control._gui_input` и сигнал `gui_input`, (5) `_shortcut_input` (только `InputEventKey`, `InputEventShortcut`, `InputEventJoypadButton`), (6) `_unhandled_key_input` (только `InputEventKey`), (7) `_unhandled_input`, (8) picking физических объектов (`CollisionObject2D/3D._input_event`). Событие идёт дальше, пока его не поглотят: `get_viewport().set_input_as_handled()` в шагах 3, 5–7 или `accept_event()` в `_gui_input`.
- Замер (проверено на 4.7.2), клавиша без обработчиков, узлы A и B (B добавлен позже): `B._input → A._input → B._shortcut_input → A._shortcut_input → B._unhandled_key_input → A._unhandled_key_input → B._unhandled_input → A._unhandled_input`. Внутри стадии порядок **обратный дереву**: поздний сосед раньше, ребёнок раньше родителя. Не стройте логику на порядке братьев — используйте разные стадии.
- Мышь (проверено на 4.7.2): `_input → _gui_input → _unhandled_input`; `_shortcut_input` и `_unhandled_key_input` для мыши не вызываются.
- `set_input_as_handled()` в `_input` у B — дальше не дошло ни до кого, даже до `_input` у A (проверено на 4.7.2).
- Клик по Control с `mouse_filter = STOP` поглощается GUI, даже если `_gui_input` ничего не делает и не вызывает `accept_event()`: `_unhandled_input` не вызвался ни у кого (проверено на 4.7.2). Отсюда классика: «полупрозрачная панель на весь экран съела все клики игры».
- Клавиатура и геймпад в GUI идут только владельцу фокуса и не всплывают к предкам. Если фокусный Control не поглотил клавишу, она проходит дальше в `_shortcut_input` и `_unhandled_*` (проверено на 4.7.2).
- Наблюдение (проверено на 4.7.2, headless): у сфокусированного `Button` Enter (`ui_accept`) вызвал `pressed` на отпускании (по умолчанию `action_mode = BUTTON_RELEASE`), но и нажатие, и отпускание дошли до `_unhandled_input`. Не вешайте игровые действия на `ui_*` — заведите свои (`"confirm"`, `"end_turn"`), иначе Enter на кнопке меню сработает и в игре.
- Где что ловить: `_unhandled_input` — игровой ввод (UI получает шанс первым); `_shortcut_input` — горячие клавиши (`Shortcut` у кнопок срабатывает здесь); `_input` — только глобальные перехваты (консоль, пауза, отладка), которые должны работать поверх UI; `_gui_input` — ввод конкретного Control.
- `Input.parse_input_event()` и `Viewport.push_input()` прогоняют весь конвейер (проверено на 4.7.2). `push_input` доставляет сразу, `parse_input_event` — в очередь (в замере события пришли на следующем кадре). Это удобно для тестов UI и синтетических действий (`InputEventAction`).
- Picking 2D/3D: `Viewport.physics_object_picking` (у корневого окна по умолчанию `true`, проверено на 4.7.2; у своих SubViewport проверьте отдельно), у объекта `input_pickable = true` (у Area2D по умолчанию true, проверено на 4.7.2), сигнал `input_event`. Срабатывает последним и только если ни UI, ни `_unhandled_input` не поглотили событие. В headless-прогоне picking не сработал — проверяйте в окне `[не проверено]`.
- SubViewport не получает ввод от родителя сам: нужен `SubViewportContainer` или своя пересылка `push_input()`.

```gdscript
# Игровой ввод: UI успевает поглотить клик раньше
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"end_turn"):
		_end_turn()
		get_viewport().set_input_as_handled()

# Глобальная пауза: должна работать даже поверх открытого меню
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_tree().paused = not get_tree().paused
		get_viewport().set_input_as_handled()

# Тест UI без реального устройства
func _press(action: StringName) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Using InputEvent](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html) | документация Godot, живой | Официальный порядок из 8 шагов, обратный обход дерева |
| [Input examples](https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html) | документация Godot, живой | События против опроса, примеры по типам событий |
| [Viewport](https://docs.godotengine.org/en/stable/classes/class_viewport.html) | справочник API | `set_input_as_handled`, `push_input`, picking, `gui_*` |
| [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html) / [InputEventKey](https://docs.godotengine.org/en/stable/classes/class_inputeventkey.html) / [InputEventAction](https://docs.godotengine.org/en/stable/classes/class_inputeventaction.html) | справочник API | Типы событий |
| [CollisionObject2D](https://docs.godotengine.org/en/stable/classes/class_collisionobject2d.html) / [CollisionObject3D](https://docs.godotengine.org/en/stable/classes/class_collisionobject3d.html) | справочник API | `input_pickable`, `_input_event`, `mouse_entered` |
| [SubViewportContainer](https://docs.godotengine.org/en/stable/classes/class_subviewportcontainer.html) | справочник API | Пересылка ввода в SubViewport |
| [Split screen input demo](https://github.com/godotengine/godot-demo-projects/tree/master/viewport/split_screen_input) | Godot, живой | Ввод нескольких игроков по вьюпортам |

## mouse_filter: почему клик не доходит

### Ключевые выводы

- `MOUSE_FILTER_STOP` — получить событие и остановить его. `PASS` — получить, а если не поглощено, передать родителю. `IGNORE` — не получать, событие идёт к контролу под ним.
- Значения по умолчанию (проверено на 4.7.2): `STOP` — Control, Button, Panel, PanelContainer, ColorRect, RichTextLabel; `PASS` — TextureRect, HBox/VBox/MarginContainer и другие контейнеры; `IGNORE` — Label. Фоновые `ColorRect` и `Panel` на весь экран — самая частая причина «кнопки под ними не нажимаются» и «игра не получает клики».
- Замер всплытия (проверено на 4.7.2), родитель `STOP`, клик по ребёнку: ребёнок `STOP` — только ребёнок; `PASS` — ребёнок, затем родитель; `IGNORE` — только родитель; `PASS` с `accept_event()` — только ребёнок. Всплывают только мышиные события и только к прямым предкам.
- 4.5: `mouse_behavior_recursive` и `focus_behavior_recursive` отключают мышь или фокус целой ветке (удобно для «заблокировать руку, пока ходит соперник»). Свойство `mouse_force_pass_scroll_events` (есть в 4.7.2) отдаёт колесо родителю, чтобы список внутри `ScrollContainer` прокручивался.
- Отладка: Debugger → Misc показывает последний Control, получивший клик `[не проверено]` (название вкладки); в коде — `get_viewport().gui_get_hovered_control()` и `gui_get_focus_owner()` (оба есть, проверено на 4.7.2).
- `Viewport.gui_disable_input` выключает GUI-ввод целиком (катсцены, загрузка).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Control: mouse_filter](https://docs.godotengine.org/en/stable/classes/class_control.html) | справочник API | Описание `STOP`/`PASS`/`IGNORE` и рекурсивных режимов |
| [Mouse and input coordinates](https://docs.godotengine.org/en/stable/tutorials/inputs/mouse_and_input_coordinates.html) | документация Godot, живой | Экранные координаты и координаты вьюпорта |
| [Unhandled input doesn't trigger when drag](https://godotforums.org/d/36687-unhandled-input-doesnt-trigger-when-drag) | Godot Forums, 2023 | Живой пример: GUI поглощает событие |

## Фокус и навигация с клавиатуры и геймпада

### Ключевые выводы

- `focus_mode` по умолчанию (проверено на 4.7.2): `FOCUS_ALL` у Button, TextureButton, LineEdit, HSlider, ItemList; `FOCUS_NONE` у Label, TextureRect и голого Control. Свой интерактивный контрол без `focus_mode = FOCUS_ALL` недоступен с геймпада.
- Навигация идёт по встроенным действиям `ui_up/down/left/right`, `ui_focus_next/prev` (Tab), `ui_accept`, `ui_cancel`. В 4.7.2 таких `ui_*` действий 91 (проверено на 4.7.2). Добавьте к ним кнопки геймпада в Input Map, не удаляя клавиатурные.
- Соседи ищутся автоматически по геометрии. Явные `focus_neighbor_left/top/right/bottom` и `focus_next/previous` задавайте там, где геометрия обманывает: сетки с пропусками, переход между панелями, «зацикливание» меню.
- При открытии экрана вызывайте `grab_focus()` на первом элементе (лучше `call_deferred`, когда экран только что добавлен). В 4.7.2 у метода есть параметр `hide_focus`: взять фокус, не рисуя рамку (сигнатура проверена на 4.7.2; версия появления `[не проверено]`).
- Меняйте фокус при закрытии модалок: верните его элементу, который открыл окно, иначе геймпад «теряется».
- `ScrollContainer.follow_focus = true` — прокрутка к фокусному элементу. Сигнал `Viewport.gui_focus_changed` удобен для звуков навигации и подсказок.
- `ButtonGroup` даёт радиокнопки. `Shortcut` у BaseButton — горячая клавиша кнопки без своего кода.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Keyboard/controller navigation and focus](https://docs.godotengine.org/en/stable/tutorials/ui/gui_navigation.html) | документация Godot, живой | `focus_neighbor_*`, `grab_focus`, рекомендации |
| [BaseButton](https://docs.godotengine.org/en/stable/classes/class_basebutton.html) / [ButtonGroup](https://docs.godotengine.org/en/stable/classes/class_buttongroup.html) / [Shortcut](https://docs.godotengine.org/en/stable/classes/class_shortcut.html) | справочник API | `action_mode`, группы, горячие клавиши |
| [Godot 4.6 release](https://godotengine.org/releases/4.6/) | Godot Foundation, 2026 | Раздельный фокус мыши и клавиатуры |

## InputMap, действия, опрос и события

### Ключевые выводы

- Код спрашивает действия (`&"move_left"`), а не клавиши. Действие хранит события, `deadzone` (по умолчанию 0.5, проверено на 4.7.2) и даёт силу нажатия.
- Сила и мёртвая зона (проверено на 4.7.2): ось стика 0.3 при deadzone 0.5 — `is_action` true, но `is_action_pressed` false и сила 0. Ось 0.75 — нажато, `get_action_strength` 0.5 (пересчитано от мёртвой зоны), `get_action_raw_strength` 0.75. Для движения берите `Input.get_vector(&"left", &"right", &"up", &"down")`: круговая мёртвая зона и нормализация за вас.
- Опрос или событие. Опрос `Input.is_action_pressed()` в `_physics_process` — для непрерывного (движение, прицеливание, удержание). События в `_unhandled_input` — для дискретного (выстрел, пауза, выбор карты, «конец хода»): не теряют быстрые нажатия между кадрами и уважают UI. `Input.is_action_just_pressed` в `_process` работает, но игнорирует то, что UI уже поглотил событие.
- Физические клавиши: в Input Map добавляйте события как physical keycode (WASD на AZERTY окажется на тех же местах). Для показа игроку — `as_text_physical_keycode()` или `DisplayServer.keyboard_get_label_from_physical()` (оба есть, проверено на 4.7.2).
- Переназначение в рантайме: `InputMap.action_erase_events()` + `action_add_event()`, сохранение в `ConfigFile` в `user://`. `InputEvent` можно записать в `ConfigFile` целиком — он сохраняется как `Object(InputEventKey, ...)` и читается обратно (проверено на 4.7.2), но такой парсер создаёт любые объекты, включая исполняемый скрипт (см. [architecture.md](architecture.md#сохранение-и-загрузка)). Надёжнее хранить коды клавиш и кнопок числами; применение при старте до первой сцены (автозагрузка). Сброс — `InputMap.load_from_project_settings()` (проверено на 4.7.2: метод есть). Готовый пример — демо `gui/input_mapping`.
- `Input.use_accumulated_input = true` по умолчанию (проверено на 4.7.2): движения мыши за кадр склеиваются. Для рисования (графические редакторы) выключайте, иначе линии ломаные.

```gdscript
# Переназначение клавиши: храним число, а не объект InputEvent (см. предупреждение выше)
func rebind_key(action: StringName, physical: Key, cfg: ConfigFile) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = physical
	InputMap.action_erase_events(action)  # в реальной игре удаляйте только клавиатурные события
	InputMap.action_add_event(action, ev)
	cfg.set_value("keys", String(action), int(physical))

func apply_keys(cfg: ConfigFile) -> void:
	for action in cfg.get_section_keys("keys"):
		var code = cfg.get_value("keys", action)
		if code is int and InputMap.has_action(action):
			rebind_key(action, code, cfg)
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [InputMap](https://docs.godotengine.org/en/stable/classes/class_inputmap.html) / [Input](https://docs.godotengine.org/en/stable/classes/class_input.html) | справочник API | Действия, мёртвые зоны, `get_vector`, опрос |
| [Input mapping demo](https://github.com/godotengine/godot-demo-projects/tree/master/gui/input_mapping) | Godot, живой | UI переназначения и сохранение |
| [ConfigFile](https://docs.godotengine.org/en/stable/classes/class_configfile.html) | справочник API | Хранение настроек и событий |
| [Input Helper](https://github.com/nathanhoad/godot_input_helper) | Nathan Hoad, 4.7.0 (июнь 2025) | Определение устройства, переназначение, иконки кнопок |
| [KidsCanCode: Input recipes](https://kidscancode.org/godot_recipes/4.x/input/) | Chris Bradfield, 4.x | Короткие рецепты по вводу |

## Геймпад, тач, мышь и курсор

### Ключевые выводы

- Геймпад: с 4.5 драйвер — SDL3; база раскладок берётся из SDL_GameControllerDB, свои — `Input.add_joy_mapping()`. Подключение и отключение — сигнал `Input.joy_connection_changed` (проверено на 4.7.2), список — `get_connected_joypads()`, вибрация — `start_joy_vibration()`. В 4.7: гироскоп и акселерометр контроллеров, настройка «Ignore Joypad on Unfocused Application» (выключена по умолчанию), `InputEvent.DEVICE_ID_KEYBOARD`/`DEVICE_ID_MOUSE` для разделения устройств.
- Подсказки кнопок («нажмите A / Enter») переключайте по последнему устройству ввода: смотрите на тип последнего события в `_input` без поглощения.
- Тач: `InputEventScreenTouch` и `InputEventScreenDrag`, мультитач по `index`. По умолчанию `emulate_mouse_from_touch = true`, `emulate_touch_from_mouse = false` (проверено на 4.7.2): на телефоне кнопки работают сразу, а тач-код на десктопе мышью не проверить, пока не включить эмуляцию тача. Двойная обработка (тач и эмулированная мышь) — частый баг.
- Экранные джойстики: в 4.7 встроен `VirtualJoystick` (режимы Fixed, Dynamic, Following, тема). Раньше — `TouchScreenButton` или аддоны.
- Мышь: `Input.mouse_mode` (по умолчанию `VISIBLE`, проверено на 4.7.2), `CAPTURED` для шутеров (берите `InputEventMouseMotion.relative`, без учёта растяжения — `screen_relative`), `CONFINED` для стратегий. Курсор: `Input.set_custom_mouse_cursor(image, shape, hotspot)` или `mouse_default_cursor_shape` у Control. Аппаратный курсор не отстаёт от FPS, программный (Sprite за мышью) отстаёт на кадр.
- Android: долгий тап как правый клик и жесты масштаба — настройки `input_devices/pointing/android/*` (проверено на 4.7.2).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Controllers, gamepads and joysticks](https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html) | документация Godot, живой | Мёртвые зоны, раскладки, вибрация, грабли |
| [SDL_GameControllerDB](https://github.com/mdqinc/SDL_GameControllerDB) | сообщество SDL, живой | База раскладок геймпадов |
| [Joypads demo](https://github.com/godotengine/godot-demo-projects/tree/master/misc/joypads) | Godot, живой | Тест осей, кнопок и раскладок |
| [InputEventScreenTouch](https://docs.godotengine.org/en/stable/classes/class_inputeventscreentouch.html) / [InputEventScreenDrag](https://docs.godotengine.org/en/stable/classes/class_inputeventscreendrag.html) / [InputEventJoypadMotion](https://docs.godotengine.org/en/stable/classes/class_inputeventjoypadmotion.html) | справочник API | Тач и оси |
| [VirtualJoystick](https://docs.godotengine.org/en/stable/classes/class_virtualjoystick.html) / [TouchScreenButton](https://docs.godotengine.org/en/stable/classes/class_touchscreenbutton.html) | справочник API | Экранные контролы |
| [Customizing the mouse cursor](https://docs.godotengine.org/en/stable/tutorials/inputs/custom_mouse_cursor.html) | документация Godot, живой | Аппаратный и программный курсор |
| [Godot 4.7 release](https://godotengine.org/releases/4.7/) | Godot Foundation, 2026 | Гироскоп, `VirtualJoystick`, игнор геймпада без фокуса |

## Несколько разрешений, hiDPI и safe area

### Ключевые выводы

- По умолчанию растяжение выключено: `stretch/mode = disabled`, `aspect = keep`, `scale = 1.0`, `scale_mode = fractional`, базовый размер 1152×648 (проверено на 4.7.2). Без настройки игра на 4K-мониторе выглядит крошечной, а на маленьком окне обрезается.
- `canvas_items` — 2D и UI рисуются в целевом разрешении, чёткий текст, подходит почти всем. `viewport` — мир рендерится в базовом разрешении и растягивается картинкой (пиксель-арт, слабое железо). `disabled` — приложения, где одна единица равна пикселю.
- `aspect = expand` + якоря и контейнеры — лучший выбор для игр с UI: дополнительное место уходит в стороны или вниз, а не в чёрные полосы. `keep` — фиксированная картинка с полосами, `keep_width` / `keep_height` — фиксирован один размер.
- `scale_mode = integer` (с 4.2) округляет масштаб вниз до целого — ровные пиксели в пиксель-арте ценой полос.
- Масштаб интерфейса для игрока («размер UI 100–200 %») — `get_tree().root.content_scale_factor` или настройка `stretch/scale`. Это и доступность, и hiDPI.
- hiDPI: `display/window/dpi/allow_hidpi` (влияет на Windows и macOS). Для приложений в режиме `disabled` берите масштаб из `DisplayServer.screen_get_scale()`.
- Safe area (вырез, скругления, жестовая полоса): `DisplayServer.get_display_safe_area()` (проверено на 4.7.2: метод есть) возвращает прямоугольник в пикселях экрана. Переведите его в координаты вьюпорта и задайте отступы корневому `MarginContainer`. С 4.5 на Android есть edge-to-edge в экспорте — без safe area UI уйдёт под вырез.
- Окно: `display/window/size/mode` (по умолчанию окно, проверено на 4.7.2), «Exclusive Fullscreen» для игр (меньше задержка), `window_width_override` / `height_override` для теста на маленьком окне, `get_window().min_size` для приложений.

### Какой режим растяжения

| Проект | Базовый размер | `stretch/mode` | `aspect` | Прочее |
|---|---|---|---|---|
| 2D/3D-игра для ПК, обычная графика, карточная игра | 1920×1080 | `canvas_items` | `expand` | Якоря и контейнеры, тест 16:9, 16:10, 21:9 |
| Пиксель-арт | 640×360 (или 320×180) | `viewport` | `keep` или `expand` | `scale_mode = integer`, фильтр текстур Nearest |
| Мобильная, альбомная | 1280×720 | `canvas_items` | `expand` | Safe area, `VirtualJoystick`, крупные кнопки |
| Мобильная, портретная | 720×1280 | `canvas_items` | `expand` | `handheld/orientation = portrait` |
| Приложение, инструмент | минимальный целевой | `disabled` | `keep` | `min_size`, масштаб из `screen_get_scale()`, `low_processor_mode` |
| 3D с тяжёлым рендером на слабом железе | 1920×1080 | `canvas_items` | `expand` | Scaling 3D (`scaling_3d_scale`, FSR) вместо `viewport` |

```gdscript
# Отступы под вырез экрана на мобильных
func _apply_safe_area(margin: MarginContainer) -> void:
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var screen: Vector2i = DisplayServer.screen_get_size()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var k: Vector2 = vp_size / Vector2(screen)
	margin.add_theme_constant_override(&"margin_left", int(safe.position.x * k.x))
	margin.add_theme_constant_override(&"margin_top", int(safe.position.y * k.y))
	margin.add_theme_constant_override(&"margin_right", int((screen.x - safe.end.x) * k.x))
	margin.add_theme_constant_override(&"margin_bottom", int((screen.y - safe.end.y) * k.y))
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html) | документация Godot, живой | Режимы, аспекты, рекомендации по типам проектов |
| [Multiple resolutions demo](https://github.com/godotengine/godot-demo-projects/tree/master/gui/multiple_resolutions) | Godot, живой | Переключение режимов вживую |
| [Window](https://docs.godotengine.org/en/stable/classes/class_window.html) / [DisplayServer](https://docs.godotengine.org/en/stable/classes/class_displayserver.html) | справочник API | `content_scale_*`, safe area, масштаб экрана |
| [ProjectSettings](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html) | справочник API | `display/window/*`, `gui/*`, `input_devices/*` |
| [Exporting for Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) | документация Godot, живой | Edge-to-edge, ориентация |
| [Window management demo](https://github.com/godotengine/godot-demo-projects/tree/master/misc/window_management) | Godot, живой | Режимы окна, полноэкранный режим |

## Окна, попапы и диалоги

### Ключевые выводы

- `Popup`, `PopupMenu`, `AcceptDialog`, `ConfirmationDialog`, `FileDialog` — это узлы `Window`. По умолчанию `display/window/subwindows/embed_subwindows = true` (проверено на 4.7.2): они рисуются внутри главного окна. Для приложений можно выключить — получите настоящие системные окна (не работает на Web и мобильных).
- Показывайте через `popup_centered()` / `popup()`; модальность — `exclusive`, привязка к родителю — `transient`. Окна по умолчанию скрыты (`visible = false`), пока их не открыли.
- Для игровых модалок (подтверждение хода, выбор цели) часто проще свой Control на отдельном `CanvasLayer` с полноэкранной подложкой `mouse_filter = STOP`: полный контроль над темой, анимацией и фокусом. Но тогда фокус и `ui_cancel` обрабатывайте сами.
- `gui/common/swap_cancel_ok` меняет порядок кнопок OK/Cancel по конвенции платформы. 4.7: поиск в длинных `PopupMenu`.
- Нативный выбор файла — `FileDialog.use_native_dialog` или `DisplayServer.file_dialog_show()` (см. [domains.md](domains.md#3-ui-и-приложения-не-игры)).
- Выход по крестику окна: `NOTIFICATION_WM_CLOSE_REQUEST` и `get_tree().set_auto_accept_quit(false)`, если нужно «Сохранить перед выходом?».

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Popup](https://docs.godotengine.org/en/stable/classes/class_popup.html) / [AcceptDialog](https://docs.godotengine.org/en/stable/classes/class_acceptdialog.html) / [PopupMenu](https://docs.godotengine.org/en/stable/classes/class_popupmenu.html) / [FileDialog](https://docs.godotengine.org/en/stable/classes/class_filedialog.html) | справочник API | Попапы и диалоги |
| [Handling quit requests](https://docs.godotengine.org/en/stable/tutorials/inputs/handling_quit_requests.html) | документация Godot, живой | Закрытие окна и кнопка «назад» на Android |
| [Multiple windows demo](https://github.com/godotengine/godot-demo-projects/tree/master/misc/multiple_windows) | Godot, живой | Невстроенные окна |
| [Creating applications](https://docs.godotengine.org/en/stable/tutorials/ui/creating_applications.html) | документация Godot, живой | Настройки для неигровых приложений |

## Drag-and-drop

### Ключевые выводы

- Встроенный DnD Control (сигнатуры проверены на 4.7.2): источник переопределяет `_get_drag_data(at_position)` и возвращает данные (любой Variant; `null` — не тащить), там же вызывает `set_drag_preview(control)`. Цель отвечает в `_can_drop_data(at_position, data) -> bool` (вызывается постоянно, пока курсор над ней — держите его дешёвым) и принимает в `_drop_data(at_position, data)`.
- Не хотите наследовать класс — `set_drag_forwarding(drag_func, can_drop_func, drop_func)` передаёт DnD в чужие Callable, например в контроллер зоны.
- Порог начала перетаскивания — `gui/common/drag_threshold` (проверено на 4.7.2), статус — `Viewport.gui_is_dragging()`, итог — `is_drag_successful()` в `NOTIFICATION_DRAG_END`, отмена — `Viewport.gui_cancel_drag()`. Начать перетаскивание программно (клик-и-перенос или с геймпада) — `force_drag(data, preview)`.
- Цель должна получать мышь: `mouse_filter` не `IGNORE`, а детям карточки, которые перекрывают её (ColorRect, Panel), ставьте `PASS` или `IGNORE`. Иначе `_get_drag_data` не вызывается.
- Превью — отдельный Control, не сама карта: исходная остаётся на месте (полупрозрачной) до успешного броска. Превью освобождается движком после конца перетаскивания.
- Данные DnD — лёгкий словарь или ресурс (`{"card_id": ..., "from_zone": ...}`), а не узел: логика хода проверяет допустимость, UI только показывает. Проверку «можно ли сыграть сюда» делайте через модель правил, а не через тип узла.
- Доступность: в 4.7.2 есть действие `ui_accessibility_drag_and_drop` и метод `accessibility_drag()` (проверено на 4.7.2), то есть DnD с клавиатуры для экранных дикторов.
- Свободное перетаскивание с физикой, магнитом и наклоном карты (как в Balatro-подобных играх) — свой код на `_gui_input` + `InputEventMouseMotion` и Tween: встроенный DnD рисует превью под курсором и не анимирует возврат.

```gdscript
# card_view.gd — источник
class_name CardView extends PanelContainer

@export var card_id: StringName

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := TextureRect.new()
	preview.texture = %Art.texture
	preview.size = size * 0.9
	preview.modulate.a = 0.8
	set_drag_preview(preview)
	modulate.a = 0.4
	return {"card_id": card_id, "source": self}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0

# board_zone.gd — цель
extends PanelContainer

signal card_dropped(card_id: StringName)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("card_id") and Rules.can_play(data.card_id, self)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	card_dropped.emit(data.card_id)
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Drag and drop demo](https://github.com/godotengine/godot-demo-projects/tree/master/gui/drag_and_drop) | Godot, живой | Минимальный официальный пример |
| [Control: drag-and-drop](https://docs.godotengine.org/en/stable/classes/class_control.html) | справочник API | `_get_drag_data`, `set_drag_forwarding`, `force_drag` |
| [Godot 4.x drag and drop](https://dev.to/pdeveloper/godot-4x-drag-and-drop-5g13) | pdeveloper, dev.to | Пошагово, грабли с `mouse_filter` |
| [Tree](https://docs.godotengine.org/en/stable/classes/class_tree.html) | справочник API | DnD в дереве, индикатор места броска (4.7) |

## Анимация UI

### Ключевые выводы

- Tween — основной инструмент: `create_tween().tween_property(btn, "scale", Vector2(1.1, 1.1), 0.1)`. Перед новым твином убивайте старый (`if _tw: _tw.kill()`), иначе hover-эффекты дерутся. В 4.7 есть `tween_await(signal)` — ждать сигнал внутри цепочки.
- Анимировать `position`, `size` или `scale` у ребёнка контейнера бесполезно: контейнер перезапишет при следующей сортировке. В 4.7 используйте `offset_transform_*`: замер (проверено на 4.7.2) — после пересортировки `offset_transform_position` сохранился, `position` контейнер сбросил. По умолчанию `offset_transform_visual_only = true`: смещение только визуальное, область клика остаётся на месте.
- Опорная точка масштаба и поворота — `pivot_offset` или с 4.6 `pivot_offset_ratio = Vector2(0.5, 0.5)` (центр независимо от размера).
- Появление и исчезновение — через `modulate:a` и `visible` в конце (`tween.tween_callback(hide)`), иначе невидимая панель с `STOP` продолжает ловить клики.
- Для сложных многошаговых анимаций экрана — `AnimationPlayer`; для отклика на ввод — Tween.

```gdscript
var _tw: Tween

func _on_mouse_entered() -> void:
	if _tw:
		_tw.kill()
	offset_transform_enabled = true
	offset_transform_pivot_ratio = Vector2(0.5, 1.0)
	_tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "offset_transform_position", Vector2(0, -24), 0.12)
	_tw.parallel().tween_property(self, "offset_transform_scale", Vector2(1.08, 1.08), 0.12)
```

Справочник: [Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html) — цепочки, `parallel`, `tween_await`.

## Производительность UI

### Ключевые выводы

- Каждый Control — узел дерева со своим CanvasItem, темой и раскладкой. Сотни контролов — норма, десятки тысяч — нет. Список из 5000 строк делайте `ItemList` или `Tree` (рисуют элементы сами) либо виртуализацией: пул из видимых строк плюс `ScrollContainer` или свой скролл, переиспользуя строки при прокрутке `[не проверено]` как замер; принцип общий.
- Изменение `custom_minimum_size`, текста, видимости или шрифта у ребёнка поднимает пересортировку контейнеров вверх по цепочке. Не меняйте их каждый кадр (таймер, «тряска» лейбла): анимацию — через `offset_transform_*` или `modulate`, таймер — моноширинным шрифтом или фиксированной `custom_minimum_size`, чтобы ширина не прыгала.
- Обновляйте UI по сигналу изменения данных, а не опросом в `_process` (см. [performance.md](performance.md#узлы-дерево-сцены-и-обработка-кадров)). Не пересоздавайте всю руку карт при каждом изменении — обновляйте изменившиеся.
- `RichTextLabel` при присваивании `text` заново разбирает BBCode и шейпит — дорого в цикле и каждый кадр. Label с `LabelSettings` дешевле.
- Скрытые вкладки и экраны всё равно обрабатываются (`_process`, таймеры). Выключайте `process_mode` у неактивных экранов или удаляйте их.
- Полупрозрачные полноэкранные панели и много вложенных `clip_contents` дают overdraw и разрывы батчей, это видно в профайлере GPU `[не проверено]`.
- Приложения: `application/run/low_processor_mode` (по умолчанию выключен, проверено на 4.7.2) перерисовывает только при изменениях.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [ItemList](https://docs.godotengine.org/en/stable/classes/class_itemlist.html) | справочник API | Список без узла на строку |
| [General optimization tips](https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html) / [CPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html) | документация Godot, живой | Профилирование перед оптимизацией |
| [Control node gallery](https://docs.godotengine.org/en/stable/tutorials/ui/control_node_gallery.html) | документация Godot, живой | Готовые контролы вместо самописных |

## Доступность

### Ключевые выводы

- С 4.5 Godot отдаёт дерево UI экранным дикторам через AccessKit (экспериментально): стандартные Control озвучиваются сами. Работает с существующими дикторами (NVDA, VoiceOver, Orca), это не встроенный диктор. На Android TalkBack в 4.5 были проблемы — проверяйте на целевой платформе `[не проверено]` для 4.7.
- Свойства Control (проверено на 4.7.2): `accessibility_name`, `accessibility_description`, `accessibility_live` (объявлять изменения, например лог боя), `accessibility_labeled_by_nodes`, `accessibility_described_by_nodes`, `accessibility_controls_nodes`, `accessibility_flow_to_nodes`. Заполняйте `accessibility_name` у иконок-кнопок и карт: «Карта Луффи, атака 5000».
- Настройки проекта (проверено на 4.7.2): `accessibility/general/accessibility_support`, `accessibility/general/updates_per_second`. 4.7 добавила навигацию по ориентирам (landmarks).
- Озвучка без диктора: `DisplayServer.tts_speak()` (проверено на 4.7.2: метод есть).
- Остальное делаете вы: полная навигация без мыши, переназначение клавиш, масштаб UI (`content_scale_factor`), минимальный размер шрифта, контраст (не передавайте смысл только цветом — масть, редкость, «ход соперника»), отключение тряски и вспышек, субтитры.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [AccessibilityServer](https://docs.godotengine.org/en/stable/classes/class_accessibilityserver.html) | справочник API | Доступность для своих узлов |
| [Dev snapshot 4.5 dev 3](https://godotengine.org/article/dev-snapshot-godot-4-5-dev-3/) | Godot Foundation, 2025 | Как появилась поддержка дикторов |
| [GH-76829: AccessKit](https://github.com/godotengine/godot/pull/76829) | bruvzg, 2023–2025 | Исходный PR интеграции |
| [AccessKit](https://accesskit.dev/) / [репозиторий](https://github.com/AccessKit/accesskit) | AccessKit, живой | Библиотека под капотом |
| [Godot 4.5 improves accessibility](https://caniplaythat.com/?p=15209) | Can I Play That?, 2025 | Взгляд сообщества доступности |
| [Accessibility demo](https://github.com/godotengine/godot-demo-projects/tree/master/gui/accessibility) | Godot, живой | Рабочий пример |
| [Godot 4.5 release](https://godotengine.org/releases/4.5/) | Godot Foundation, 2025 | Дикторы, рекурсивные режимы фокуса и мыши |

## Локализация интерфейса

### Ключевые выводы

- Формат переводов и `tr_n` — в [domains.md, раздел 7](domains.md#7-диалоги-нарратив-и-локализация). Здесь — что важно для раскладки.
- `auto_translate_mode` у Control и Node по умолчанию `INHERIT`, у корневого окна `ALWAYS` (проверено на 4.7.2): ключ в `text` переводится сам. Для имён игроков, чисел и пользовательского ввода ставьте `DISABLED`, иначе случайное совпадение с ключом переведётся. У подсказок — отдельный `tooltip_auto_translate_mode`.
- Немецкий и русский длиннее английского на 20–40 %: проверяйте раскладку псевдолокализацией (`internationalization/pseudolocalization/*`, проверено на 4.7.2) и закладывайте перенос или `OVERRUN_TRIM_ELLIPSIS` с подсказкой.
- Кириллица и CJK: проверьте, что в шрифте темы есть глифы, иначе подключите fallback (`FontFile.fallbacks`) или `SystemFont`. Для арабского и иврита — `layout_direction` и шейпинг (TextServer Advanced по умолчанию).
- Текст, собранный в коде, обновляйте по `NOTIFICATION_TRANSLATION_CHANGED`.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Internationalizing games](https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html) | документация Godot, живой | `tr`, автоматический перевод, RTL |
| [Pseudolocalization](https://docs.godotengine.org/en/stable/tutorials/i18n/pseudolocalization.html) / [demo](https://github.com/godotengine/godot-demo-projects/tree/master/gui/pseudolocalization) | документация Godot / Godot, живой | Проверка длины и захардкоженных строк |
| [TranslationServer](https://docs.godotengine.org/en/stable/classes/class_translationserver.html) | справочник API | Смена локали |

## Антипаттерны

### Ключевые выводы

- Раскладка абсолютными позициями и ручной подгонкой под 1920×1080 → контейнеры и якоря, тест на нескольких соотношениях сторон.
- Анимация `position` у ребёнка контейнера → `offset_transform_*` (4.7) или анимируемая обёртка вне контейнера.
- Полноэкранный `ColorRect`/`Panel` (по умолчанию `STOP`) как фон или затемнение, после которого «игра не реагирует» → `mouse_filter = IGNORE` у декоративных узлов, `STOP` только у модальной подложки.
- Игровая логика в `_input` или опрос `is_action_just_pressed` в `_process` для дискретных событий → `_unhandled_input`, чтобы UI успел поглотить клик.
- Игровые действия на `ui_accept`/`ui_cancel` или захардкоженные `KEY_SPACE` → свои действия InputMap с физическими клавишами; `ui_*` оставьте навигации.
- `theme_override_*` на каждом узле → тема на корне и type variations.
- Label с переносом в HBox без `EXPAND_FILL` → «текст столбиком» шириной 1 px.
- Свой контрол без `focus_mode` и без `grab_focus()` при открытии экрана → меню недоступно с геймпада.
- Тысячи Control-строк или `RichTextLabel.text = ...` каждый кадр → `ItemList`/`Tree`/виртуализация и обновление по изменению.
- Проверка мыши через `get_global_mouse_position()` и `Rect2.has_point()` в `_process` вместо `mouse_entered`/`_gui_input` → обходит `mouse_filter`, модалки и всю систему GUI.
- `get_node("../../HUD")` из игровых объектов → сигналы или шина событий (см. [architecture.md](architecture.md)).
- `[устарело]` Godot 3: `rect_position`, `rect_size`, `rect_min_size` → `position`, `size`, `custom_minimum_size`; `margin_*` у Control → `offset_*`; `set_input_as_handled()` у SceneTree → у Viewport; `_unhandled_key_input(event: InputEventKey)` с типом → `InputEvent`; `stretch_mode = "2d"` → `canvas_items`; `DynamicFont` → `FontFile`/`FontVariation`; `Tween` как узел → `create_tween()`.

## Чеклист UI и ввода

1. Выбран режим растяжения под тип проекта (таблица выше), по умолчанию он `disabled`.
2. Корень каждого экрана — Control с Full Rect, дальше только контейнеры.
3. Проверено на 16:9, 16:10, 21:9, 4:3 и портрете (если мобильная) через override размера окна.
4. HUD и меню лежат в `CanvasLayer`, не двигаются с камерой.
5. Одна проектная тема (`gui/theme/custom`) или тема на корне UI; type variations вместо копий.
6. Проектный шрифт содержит кириллицу и нужные письменности или имеет fallback.
7. Переносимые Label имеют ширину от контейнера (`EXPAND_FILL` или `custom_minimum_size.x`).
8. Длинные переводы не ломают раскладку (псевдолокализация включалась хотя бы раз).
9. Имена, числа и пользовательский текст — `auto_translate_mode = DISABLED`.
10. Декоративные узлы (фоны, рамки, иконки) — `mouse_filter = IGNORE` или `PASS`.
11. Модальные окна закрывают ввод за собой подложкой `STOP` и возвращают фокус при закрытии.
12. Игровой ввод — в `_unhandled_input`, глобальные перехваты — в `_input`, горячие клавиши — `_shortcut_input` или `Shortcut`; после обработки — `set_input_as_handled()` / `accept_event()`.
13. Игровые действия отделены от `ui_*`; у каждого действия есть клавиатура и геймпад, клавиши — физические.
14. Мёртвые зоны осмыслены; движение через `Input.get_vector()`.
15. Переназначение сохраняется в `user://` числами, применяется до первой сцены; есть «сбросить».
16. Подсказки кнопок меняются по последнему устройству ввода.
17. Каждый экран проходится только с клавиатуры и только с геймпада: `grab_focus()` при открытии, `focus_mode = FOCUS_ALL` и стиль `focus` у своих контролов, `follow_focus` в списках.
18. На тач-устройствах нет двойной обработки (тач + эмулированная мышь); кнопки не меньше ~48 dp `[не проверено]` как норма платформ.
19. Учтена safe area на мобильных.
20. Есть настройка масштаба UI (`content_scale_factor`) и размера шрифта.
21. Смысл не передаётся только цветом; есть режим без тряски и вспышек.
22. У иконок-кнопок и карт заполнено `accessibility_name`.
23. Большие списки — `ItemList`/`Tree` или виртуализация, а не тысячи узлов.
24. UI обновляется по сигналам данных, а не в `_process`; `RichTextLabel` не переписывается каждый кадр; неактивные экраны не тратят `_process`.
25. Hover и press анимации — Tween по `offset_transform_*`/`modulate`, старый твин убивается.
26. DnD: `_can_drop_data` дешёвый, данные — словарь или ресурс, превью отдельное, правила проверяет модель.
27. Выход и «назад» обработаны (`NOTIFICATION_WM_CLOSE_REQUEST`, `ui_cancel`).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [GUI tutorials](https://docs.godotengine.org/en/stable/tutorials/ui/index.html) / [Input tutorials](https://docs.godotengine.org/en/stable/tutorials/inputs/index.html) | документация Godot, живой | Входы в оба раздела |
| [Control gallery demo](https://github.com/godotengine/godot-demo-projects/tree/master/gui/control_gallery) | Godot, живой | Все контролы с темой по умолчанию |
| [Viewports](https://docs.godotengine.org/en/stable/tutorials/rendering/viewports.html) | документация Godot, живой | SubViewport, ввод, рендер в текстуру |
| [KidsCanCode: UI recipes](https://kidscancode.org/godot_recipes/4.x/ui/) | Chris Bradfield, 4.x | Короткие рецепты: полоски, меню, контейнеры |
| [GDQuest library](https://www.gdquest.com/library/) / [UI series](https://gdquest.com/product/godot/user-interface-series/) | GDQuest, живой | Статьи и курс по UI и темам |
| [Maaack's Godot Game Template](https://github.com/Maaack/Godot-Game-Template) | Maaack, 1.7.0 (сентябрь 2026) | Готовые меню, настройки ввода и видео |
| [Godot 4.3](https://godotengine.org/releases/4.3/) / [Godot 4.4](https://godotengine.org/releases/4.4/) | Godot Foundation, 2024–2025 | Изменения UI и ввода в предыдущих версиях |
| [Godot 4.2 arrives in style](https://godotengine.org/article/godot-4-2-arrives-in-style/) | Godot Foundation, 2023 | Целочисленное масштабирование |

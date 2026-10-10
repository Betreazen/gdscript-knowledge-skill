# Анимация и аудио в Godot 4

Справочник по анимационной и звуковой подсистемам движка: `AnimationMixer`, `AnimationPlayer`, `AnimationTree`, `Tween`, покадровые спрайты, скелеты 2D и 3D с модификаторами и IK, импорт анимаций, синхронизация с геймплеем; `AudioServer` и шины, плееры и потоки, интерактивная музыка, генерация и захват звука, задержка, Web, пулы эффектов, громкость и её сохранение. Актуально на октябрь 2026, Godot 4.7.2. Краткий обзор анимации по 2D/3D-доменам и аддоны (Aseprite Wizard, FMOD, Wwise) — в [domains.md](domains.md), разделы 1, 2 и 8; `await` на сигналах твина и таймерах — в [signals-async-threads.md](signals-async-threads.md); общая методика профилирования — в [performance.md](performance.md).

Метки: `[устарело]` — API Godot 3 или ранних 4.x, рядом указана замена; `[не проверено]` — утверждение из документации или памяти без собственного замера. «(проверено на 4.7.2)» — поведение воспроизведено в headless-прогоне 4.7.2 с `--fixed-fps 60`, классы и свойства сверены с `--dump-extension-api`.

Вехи версий для этого файла:
- **4.2** — `AnimationMixer` как общий базовый класс `AnimationPlayer` и `AnimationTree` ([PR #80813](https://github.com/godotengine/godot/pull/80813)), root motion в `AnimationPlayer`, опция `deterministic`.
- **4.3** — `SkeletonModifier3D` ([PR #87888](https://github.com/godotengine/godot/pull/87888)), интерактивная музыка ([PR #64488](https://github.com/godotengine/godot/pull/64488)), сэмпловое воспроизведение на Web ([PR #91382](https://github.com/godotengine/godot/pull/91382)), `AudioEffectHardLimiter` ([PR #89088](https://github.com/godotengine/godot/pull/89088)), возвращение capture, `play_with_capture()`.
- **4.4** — маркеры анимации ([PR #91765](https://github.com/godotengine/godot/pull/91765)), `LookAtModifier3D`, `RetargetModifier3D`, `SpringBoneSimulator3D`, `AnimationNodeExtension`, `Tween.tween_subtween()`, `volume_linear`, загрузка WAV в рантайме.
- **4.5** — `BoneConstraint3D` и `AimModifier3D`/`CopyTransformModifier3D`/`ConvertTransformModifier3D` ([PR #100984](https://github.com/godotengine/godot/pull/100984)).
- **4.6** — IK-фреймворк `IKModifier3D` ([PR #110120](https://github.com/godotengine/godot/pull/110120)), `LimitAngularVelocityModifier3D`, `BoneTwistDisperser3D`.
- **4.7** — `Tween.tween_await()` ([PR #79712](https://github.com/godotengine/godot/pull/79712)), сворачиваемые треки в редакторе анимации. Изменений в аудио в заметках к 4.7 нет.

- [Выбор инструмента](#выбор-инструмента)
- [AnimationMixer и AnimationPlayer](#animationmixer-и-animationplayer)
- [RESET, deterministic и смешивание](#reset-deterministic-и-смешивание)
- [AnimationTree](#animationtree)
- [Покадровая анимация: AnimatedSprite2D/3D и SpriteFrames](#покадровая-анимация-animatedsprite2d3d-и-spriteframes)
- [Tween](#tween)
- [Скелеты 2D](#скелеты-2d)
- [Скелеты 3D, модификаторы и IK](#скелеты-3d-модификаторы-и-ik)
- [Импорт, сжатие и производительность анимаций](#импорт-сжатие-и-производительность-анимаций)
- [Синхронизация с геймплеем и кат-сцены](#синхронизация-с-геймплеем-и-кат-сцены)
- [AudioServer и шины](#audioserver-и-шины)
- [Плееры и пространственный звук](#плееры-и-пространственный-звук)
- [Типы AudioStream и интерактивная музыка](#типы-audiostream-и-интерактивная-музыка)
- [Генерация, микрофон, задержка и Web](#генерация-микрофон-задержка-и-web)
- [Пулы, ducking, громкость и настройки](#пулы-ducking-громкость-и-настройки)
- [Антипаттерны](#антипаттерны)
- [Чеклист анимации и аудио](#чеклист-анимации-и-аудио)

---

## Выбор инструмента

### Ключевые выводы
- `AnimationPlayer` — авторская анимация в редакторе: много свойств и узлов на одной временной шкале, звук, вызовы методов, вложенные анимации. `AnimationTree` — когда анимаций много и между ними нужны смешивание и переходы (персонажи). `Tween` — короткая процедурная анимация из кода, когда конечное значение известно только в рантайме (UI, «прыжок» к точке, вспышка урона).
- `AnimatedSprite2D` — простые покадровые циклы без других свойств. Как только к кадрам нужно привязать хитбокс, звук шагов или вызов метода, переходите на `Sprite2D` + `AnimationPlayer` (трек `frame`).
- `Tween` в Godot 4 — объект `RefCounted`, создаваемый `create_tween()`, а не узел. Узел `Tween` и `interpolate_property()` — `[устарело]` (Godot 3). `AnimationTreePlayer` — `[устарело]` (Godot 3), замена — `AnimationTree`.

### AnimationPlayer, AnimationTree или Tween

| Задача | Инструмент | Почему |
|---|---|---|
| Открытие двери, мигание лампы, катсцена | `AnimationPlayer` | Ключи в редакторе, звук и методы на шкале, предпросмотр |
| Персонаж: idle/run/jump/attack с переходами | `AnimationTree` (StateMachine + BlendSpace) | Кроссфейды, blend-позиции, one-shot поверх движения |
| Ходьба в 8 направлениях, скорость → анимация | `AnimationNodeBlendSpace2D`/`1D` | Плавное смешивание по параметру |
| UI: всплытие панели, счётчик очков, тряска | `Tween` | Значения из кода, без ресурсов |
| Движение к точке, известной только в рантайме | `Tween` или код в `_physics_process` | Ключи `AnimationPlayer` статичны |
| Покадровый цикл огня, монеты | `AnimatedSprite2D` | Минимум настройки |
| Покадровая атака с хитбоксом и звуком | `Sprite2D` + `AnimationPlayer` | Треки `frame`, `CollisionShape2D:disabled`, audio, method |
| Голова/глаза смотрят на цель, ноги на рельефе | `SkeletonModifier3D` (LookAt, IK) | Процедурная поправка поверх анимации |
| Тысячи одинаковых анимированных объектов | Вершинная анимация в шейдере + `MultiMesh` | Узлы и `AnimationMixer` на каждый объект не масштабируются (см. [performance.md](performance.md)) |

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Animation (раздел)](https://docs.godotengine.org/en/stable/tutorials/animation/index.html) | Godot docs, живой | Вход в раздел анимации |
| [Introduction to the animation features](https://docs.godotengine.org/en/stable/tutorials/animation/introduction.html) | Godot docs, живой | Редактор, ключи, библиотеки, RESET |
| [Migrating Animations from Godot 4.0 to 4.3](https://godotengine.org/article/migrating-animations-from-godot-4-0-to-4-3/) | Silc Renew, 2024 | Главная статья о семантике `AnimationMixer`: deterministic, capture, discrete-режимы |

---

## AnimationMixer и AnimationPlayer

### Ключевые выводы
- С 4.2 `AnimationPlayer` и `AnimationTree` наследуют `AnimationMixer`: у обоих есть библиотеки (`add_animation_library`), `root_node`, `callback_mode_process`/`method`/`discrete`, `deterministic`, root motion, `audio_max_polyphony`, сигналы `animation_started`/`animation_finished`/`mixer_applied`. Анимации лежат в `AnimationLibrary`; имя вида `"lib/anim"`, у библиотеки по умолчанию имя пустое. Общие анимации выносите во внешнюю библиотеку `.res`/`.tres` и подключайте к нескольким плеерам.
- Типы треков (`Animation.TrackType`): `VALUE` (любое свойство), `POSITION_3D`/`ROTATION_3D`/`SCALE_3D` (быстрые трансформ-треки костей и `Node3D`), `BLEND_SHAPE`, `METHOD`, `BEZIER` (кривые для одного float), `AUDIO` (звук на шкале), `ANIMATION` (запуск анимации другого `AnimationPlayer` — вложенные катсцены).
- Режим обновления value-трека: `UPDATE_CONTINUOUS` (интерполяция, по умолчанию, проверено на 4.7.2), `UPDATE_DISCRETE` (значение только в момент ключа — `visible`, `frame`, строки), `UPDATE_CAPTURE` (стартует с текущего значения свойства). Интерполяция: `NEAREST`, `LINEAR`, `CUBIC`, `LINEAR_ANGLE`/`CUBIC_ANGLE` для углов (без «прокрутки» через 360°).
- Значения по умолчанию `AnimationPlayer` (проверено на 4.7.2): `callback_mode_process = IDLE`, `callback_mode_method = DEFERRED`, `callback_mode_discrete = RECESSIVE`, `deterministic = false`, `reset_on_save = true`, `audio_max_polyphony = 32`, `playback_default_blend_time = 0`, `playback_auto_capture = true`.
- Method-трек вызывает метод один раз на ключ; в цикле — на каждом проходе (проверено на 4.7.2: за ~2,3 прохода — 3 вызова). По умолчанию вызов отложенный (`DEFERRED`), то есть в конце кадра; если порядок важен относительно кода в том же кадре, ставьте `IMMEDIATE`.
- `animation_finished` **не эмитится** для зацикленной анимации (проверено на 4.7.2: 0 эмиссий за два цикла). Для «конец цикла» используйте method-трек или маркер в конце. Сигнал `animation_changed` приходит при переходе по `queue()`/`animation_set_next()`.
- `stop()` (`keep_state = false`) сбрасывает позицию воспроизведения и применяет начало анимации: свойство вернулось к значению первого ключа (проверено на 4.7.2). `pause()` замораживает текущее состояние.
- `play(name, custom_blend, custom_speed, from_end)`, `play_backwards()`, `queue()`, `speed_scale` (отрицательное — назад), `seek(t, update = true)`, `play_section()`/`play_section_with_markers()` (4.4+) — проигрывание отрезка между маркерами вместо раздельных анимаций «замах/удар/возврат».
- `autoplay` — анимация при входе в дерево; для начальной позы используйте RESET, а не autoplay-анимацию длиной 0.
- Audio-трек указывает путь к узлу `AudioStreamPlayer`/`2D`/`3D` — шина, громкость и позиция берутся у этого узла, а ключи задают поток и отрезок (`start_offset`/`end_offset`). Число одновременных звуков от треков ограничено `audio_max_polyphony` микшера (32 по умолчанию). Шаги и удары удобно класть сюда; для звуков, которые должны пережить узел, используйте пул (раздел ниже) через method-трек.

```gdscript
# Библиотека, сохранённая отдельно, подключается к любому плееру
@onready var ap: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
    ap.add_animation_library(&"combat", preload("res://anim/combat_lib.tres"))
    ap.animation_finished.connect(_on_anim_finished)  # не придёт для loop-анимаций
    ap.play(&"combat/slash")
    ap.queue(&"idle")

func _on_anim_finished(anim_name: StringName) -> void:
    if anim_name == &"combat/slash":
        $Hitbox.monitoring = false
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Animation track types](https://docs.godotengine.org/en/stable/tutorials/animation/animation_track_types.html) | Godot docs, живой | Все типы треков, bezier, audio, animation-трек |
| [AnimationMixer](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html) | Godot class ref, 4.7 | callback-режимы, deterministic, root motion, capture |
| [AnimationPlayer](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html) | Godot class ref, 4.7 | play/queue/seek/sections, auto capture |
| [Animation](https://docs.godotengine.org/en/stable/classes/class_animation.html) | Godot class ref, 4.7 | Создание треков из кода, update modes, маркеры, `compress()` |
| [AnimationLibrary](https://docs.godotengine.org/en/stable/classes/class_animationlibrary.html) | Godot class ref, 4.7 | Общие библиотеки анимаций |
| [Bézier curves](https://docs.godotengine.org/en/stable/tutorials/math/beziers_and_curves.html) | Godot docs, живой | Математика bezier-треков и `Curve` |
| [Creating movies](https://docs.godotengine.org/en/stable/tutorials/animation/creating_movies.html) | Godot docs, живой | Movie Maker для записи катсцен, `movie_quit_on_finish` |

---

## RESET, deterministic и смешивание

### Ключевые выводы
- RESET — анимация с именем `RESET` длиной ~0, хранящая «позу покоя» всех анимируемых свойств. Редактор создаёт её, когда при вставке ключа включено «Create RESET Track(s)». Зачем: (1) при `reset_on_save = true` (по умолчанию) сцена сохраняется с применённым RESET, а не в кадре, где вы остановили предпросмотр; (2) при смешивании в режиме `deterministic` RESET — базовое значение для треков, которых нет в части анимаций.
- `deterministic` по умолчанию: `false` у `AnimationPlayer`, `true` у `AnimationTree` (проверено на 4.7.2). При `false` веса нормализуются к 1, отсутствующий трек просто не участвует. При `true` результат = исходное значение (RESET или 0) + сумма взвешенных отклонений.
- Замер на 4.7.2: Blend2 с весом 0.5 между A (`x = 100`) и B (трека `x` нет), стартовое `x = 7`. `deterministic = false` → `x = 100`; `true` без RESET → `x = 50` (база 0, а не текущее 7!); `true` с RESET (`x = 20`) → `x = 60`. Вывод: в `AnimationTree` без RESET свойство «тянется» к нулю типа, отсюда классический баг «персонаж проваливается в 0 или масштаб становится 0».
- `callback_mode_discrete`: `DOMINANT` — дискретные ключи побеждают (возможно мерцание), `RECESSIVE` — побеждает непрерывный результат (по умолчанию у `AnimationPlayer`), `FORCE_CONTINUOUS` — дискретные треки смешиваются как непрерывные с `NEAREST` (по умолчанию у `AnimationTree`, проверено на 4.7.2).
- Capture: `play_with_capture()` (4.3+) или `playback_auto_capture` плавно ведёт свойства от текущих значений к первому ключу — замена старым трекам с `UPDATE_CAPTURE` для переходов «откуда угодно».

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Migrating Animations from Godot 4.0 to 4.3](https://godotengine.org/article/migrating-animations-from-godot-4-0-to-4-3/) | Silc Renew, 2024 | deterministic, RESET, Dominant/Recessive/Force Continuous |
| [PR #80813](https://github.com/godotengine/godot/pull/80813) | TokageItLab, 2023 | Введение `AnimationMixer` в 4.2 |

---

## AnimationTree

### Ключевые выводы
- `AnimationTree` берёт анимации из своих библиотек или из `anim_player` (ссылка на `AnimationPlayer`, который сам при этом не должен играть). Корень (`tree_root`) — `AnimationNodeStateMachine`, `AnimationNodeBlendTree`, `BlendSpace1D/2D` или `AnimationNodeAnimation`.
- Узлы BlendTree: `Blend2/3`, `Add2/3`, `Sub2`, `OneShot` (атака поверх движения, `request = FIRE/ABORT/FADE_OUT`), `Transition` (переключение по имени входа, `transition_request`), `TimeScale`, `TimeSeek`, `BlendSpace1D/2D`, вложенные StateMachine. Фильтры по костям на Blend/OneShot — анимация верхней части тела отдельно от ног.
- Параметры — пути `parameters/...` (видны в инспекторе): `parameters/playback` — `AnimationNodeStateMachinePlayback`, `parameters/conditions/<name>`, `parameters/<node>/blend_position`, `parameters/<node>/request`. Кэшируйте `playback` и пишите параметры через `set()` без лишних строковых конкатенаций в горячем коде.
- Переходы StateMachine (`AnimationNodeStateMachineTransition`): `switch_mode` IMMEDIATE/SYNC/AT_END, `advance_mode` DISABLED/ENABLED/AUTO, `xfade_time`, `priority`, `reset`. По умолчанию: IMMEDIATE, ENABLED, xfade 0, reset = true (проверено на 4.7.2). `travel(&"State")` ищет путь по графу через переходы с `advance_mode = ENABLED`; `start()` прыгает сразу. Переход AUTO выполняется сам, когда выполнено условие или выражение.
- Условия (`advance_condition`) — булевы параметры, которые выставляет код. Выражения (`advance_expression`) — строка `Expression`, вычисляемая каждый кадр относительно `advance_expression_base_node`; по умолчанию это `"."` — сам `AnimationTree` (проверено на 4.7.2), поэтому для выражений вида `velocity.length() > 0.1` укажите корень персонажа. Выражения удобны, но вычисляются каждый кадр на каждом переходе; при десятках персонажей предпочитайте условия.
- Root motion: `root_motion_track` указывает кость/трек; `get_root_motion_position()`/`rotation()` после обработки кадра — смещение за кадр, его применяют к `CharacterBody3D`. При этом `callback_mode_process` дерева согласуйте с местом, где вызывается `move_and_slide()` (обычно PHYSICS).
- Логика игры владеет состоянием, дерево его отображает: код вызывает `travel()` и ставит параметры; не опрашивайте `get_current_node()` как источник правды о том, атакует ли персонаж.
- `AnimationNodeExtension` (4.4+) — свои узлы дерева на GDScript/GDExtension.

```gdscript
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")

func _physics_process(_delta: float) -> void:
    var speed := Vector2(velocity.x, velocity.z).length()
    anim_tree.set("parameters/StateMachine/Move/blend_position", speed)
    anim_tree.set("parameters/conditions/on_floor", is_on_floor())
    if Input.is_action_just_pressed("attack"):
        anim_tree.set("parameters/Attack/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func jump() -> void:
    playback.travel(&"Jump")

# Root motion в CharacterBody3D (callback_mode_process = PHYSICS)
func apply_root_motion(delta: float) -> void:
    var rm_pos: Vector3 = anim_tree.get_root_motion_position()
    quaternion = quaternion * anim_tree.get_root_motion_rotation()
    velocity = (quaternion * rm_pos) / delta
    move_and_slide()
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Using AnimationTree](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html) | Godot docs, живой | BlendTree, StateMachine, root motion, travel |
| [AnimationTree](https://docs.godotengine.org/en/stable/classes/class_animationtree.html) | Godot class ref, 4.7 | `advance_expression_base_node`, `anim_player` |
| [AnimationNodeStateMachinePlayback](https://docs.godotengine.org/en/stable/classes/class_animationnodestatemachineplayback.html) | Godot class ref, 4.7 | `travel`, `start`, `get_travel_path`, сигналы `state_started/finished` |
| [AnimationNodeStateMachineTransition](https://docs.godotengine.org/en/stable/classes/class_animationnodestatemachinetransition.html) / [AnimationNodeStateMachine](https://docs.godotengine.org/en/stable/classes/class_animationnodestatemachine.html) | Godot class ref, 4.7 | Режимы переключения, условия, выражения |
| [AnimationNodeOneShot](https://docs.godotengine.org/en/stable/classes/class_animationnodeoneshot.html) / [AnimationNodeTransition](https://docs.godotengine.org/en/stable/classes/class_animationnodetransition.html) | Godot class ref, 4.7 | Запросы fire/abort, переключение входов |
| [BlendSpace1D](https://docs.godotengine.org/en/stable/classes/class_animationnodeblendspace1d.html) / [BlendSpace2D](https://docs.godotengine.org/en/stable/classes/class_animationnodeblendspace2d.html) / [BlendTree](https://docs.godotengine.org/en/stable/classes/class_animationnodeblendtree.html) | Godot class ref, 4.7 | Смешивание по параметру, триангуляция |
| [AnimationNodeExtension](https://docs.godotengine.org/en/stable/classes/class_animationnodeextension.html) | Godot class ref, 4.4+ | Свои узлы дерева |
| [Using an AnimationTree state machine](https://kidscancode.org/godot_recipes/4.x/animation/using_animation_sm/index.html) | KidsCanCode, живой | Короткий практический рецепт |
| [Issue #76159](https://github.com/godotengine/godot/issues/76159) | godotengine, открыт | `animation_started` в дереве не работает с зацикленными анимациями |
| [3D platformer demo](https://github.com/godotengine/godot-demo-projects/tree/master/3d/platformer) | Godot, 2026 | Эталонный персонаж на `AnimationTree` |

---

## Покадровая анимация: AnimatedSprite2D/3D и SpriteFrames

### Ключевые выводы
- `SpriteFrames` — ресурс с именованными анимациями (кадры, FPS, loop, длительность кадра). Новая анимация по умолчанию зациклена, 5 FPS (проверено на 4.7.2). Ресурс общий: не меняйте его из кода одного экземпляра, если не вызвали `duplicate()`.
- Сигналы `AnimatedSprite2D`: `animation_finished` — только для незацикленных; для зацикленных приходит `animation_looped` (проверено на 4.7.2: 0 finished, 5 looped за полсекунды при 20 FPS). Есть `frame_changed`, `animation_changed`.
- `AnimatedSprite3D` — тот же API для 3D (billboard-спрайты). Для атласов используйте `AtlasTexture`-кадры или импорт из Aseprite (аддон в [domains.md](domains.md), раздел 1).
- Спрайт под `AnimationPlayer`: `Sprite2D` с `hframes`/`vframes` и discrete-треком `frame` — тогда в той же анимации можно двигать хитбоксы, играть звук шагов и вызывать методы.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [2D sprite animation](https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html) | Godot docs, живой | `AnimatedSprite2D` против `Sprite2D` + `AnimationPlayer` |
| [AnimatedSprite2D](https://docs.godotengine.org/en/stable/classes/class_animatedsprite2d.html) / [AnimatedSprite3D](https://docs.godotengine.org/en/stable/classes/class_animatedsprite3d.html) / [SpriteFrames](https://docs.godotengine.org/en/stable/classes/class_spriteframes.html) | Godot class ref, 4.7 | Сигналы, `frame_progress`, длительности кадров |

---

## Tween

### Ключевые выводы
- `node.create_tween()` создаёт твин, привязанный к узлу: он обрабатывается, только когда узел может обрабатываться, и убивается вместе с ним. `get_tree().create_tween()` — непривязанный твин. Твин стартует сам в следующем кадре; твин без твинеров — ошибка «started with no Tweeners», после чего он невалиден (проверено на 4.7.2). Твины одноразовые: после окончания `is_valid() == false`, на каждое действие создавайте новый.
- Освобождение узла: привязанный твин становится невалиден, **`finished` не эмитится** (проверено на 4.7.2), поэтому `await tween.finished` в чужом объекте повиснет. Твин дерева, анимирующий освобождённый объект, тоже становится невалиден.
- Пауза: режим паузы по умолчанию — `TWEEN_PAUSE_BOUND`. Привязанный твин останавливается вместе с узлом; **непривязанный твин дерева тоже останавливается** (без узла BOUND = STOP, проверено на 4.7.2). Твин для меню паузы — `set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)` (проверено: идёт во время паузы). Обработка — `set_process_mode(TWEEN_PROCESS_IDLE)` по умолчанию; для анимации физических тел — `TWEEN_PROCESS_PHYSICS`. `set_ignore_time_scale()` — игнорировать `Engine.time_scale`.
- Цепочка и параллель: твинеры идут последовательно; `parallel()` ставит следующий твинер в тот же шаг, `set_parallel(true)` — все последующие. Замер на 4.7.2 (60 FPS): 0.25 → (0.25 ‖ 0.5) → callback — шаг 0 закончился на 15-м кадре, шаг 1 на 45-м, callback и `finished` — в том же 45-м кадре; длительность шага = самый длинный параллельный твинер. `set_parallel(true)` для 0.25 и 0.5 — 0.517 с (перебег на кадр).
- Твинеры: `tween_property(obj, "prop:sub", final, t)` с `.from()`, `.from_current()`, `.as_relative()`, `.set_delay()`; `tween_method(callable, from, to, t)` — для того, что не является свойством (шейдерный параметр через метод, счётчик); `tween_callback()`; `tween_interval()`; `tween_subtween()` (4.4+) — вложенный твин; `tween_await(signal)` (4.7+) — твин ждёт сигнал (проверено на 4.7.2).
- Кривые: `set_trans()` (LINEAR, SINE, QUAD, CUBIC, QUART, QUINT, EXPO, CIRC, ELASTIC, BOUNCE, BACK, SPRING) и `set_ease()` (IN, OUT, IN_OUT, OUT_IN) на весь твин или на отдельный твинер. Шпаргалка по форме — [easings.net](https://easings.net/).
- `set_loops()` без аргумента — бесконечно: `loop_finished` приходит на каждом круге, `finished` — никогда; `kill()` делает твин невалидным без `finished` (проверено на 4.7.2). `stop()` оставляет твин валидным, `play()` после `stop()` начинает заново (проверено). `pause()`/`play()` — продолжить с места.
- Перезапуск одного эффекта: храните ссылку и убивайте старый твин перед новым, иначе два твина борются за одно свойство.
- Tween или AnimationPlayer: твин — когда значения вычисляются в рантайме и анимация одноразовая; `AnimationPlayer` — когда нужен дизайнерский контроль, предпросмотр, звук и методы на шкале, повторное использование.

```gdscript
var _hit_tween: Tween

func flash_hit() -> void:
    if _hit_tween and _hit_tween.is_valid():
        _hit_tween.kill()  # не даём двум твинам драться за modulate
    _hit_tween = create_tween()
    _hit_tween.tween_property(sprite, "modulate", Color.RED, 0.05)
    _hit_tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

func pop_in(panel: Control) -> void:
    panel.scale = Vector2.ZERO
    var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tw.tween_property(panel, "scale", Vector2.ONE, 0.3)
    tw.parallel().tween_property(panel, "modulate:a", 1.0, 0.2).from(0.0)
    tw.tween_interval(0.5)
    tw.tween_await(door_opened)   # 4.7+: ждать сигнал внутри цепочки
    tw.tween_callback(panel.hide)
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html) | Godot class ref, 4.7 | Все твинеры, режимы паузы и обработки, `bind_node` |
| [PR #79712](https://github.com/godotengine/godot/pull/79712) | KoBeWi, 2026 | `AwaitTweener` и `tween_await()` в 4.7 |
| [PR #98660](https://github.com/godotengine/godot/pull/98660) / [PR #108227](https://github.com/godotengine/godot/pull/108227) | godotengine, 2025 | `tween_subtween()`; `kill()` распространяется на вложенные твины |
| [Pausing games](https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_games.html) | Godot docs, живой | `process_mode` узлов, от которого зависит привязанный твин |
| [Easing functions](https://easings.net/) | Andrey Sitnik, живой | Визуальная шпаргалка по trans/ease |

---

## Скелеты 2D

### Ключевые выводы
- Связка: `Skeleton2D` → иерархия `Bone2D` → `Polygon2D` со скиннингом (вкладка UV: полигоны, внутренние вершины, веса костей). Перед анимацией задайте позу покоя (`rest`) и включите RESET-трек.
- Cutout-анимация (без деформации) — отдельные `Sprite2D` как дети костей; деформация — `Polygon2D` с весами. Для IK и «болтающихся» частей есть `SkeletonModificationStack2D` с модификациями `TwoBoneIK`, `CCDIK`, `FABRIK`, `LookAt`, `Jiggle`, `PhysicalBones` — API помечен экспериментальным `[не проверено]` на предмет изменений в 4.7.
- Для сложной 2D-анимации многие студии используют Spine или DragonBones с их рантаймами — оценивайте, есть ли сборка под вашу версию.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [2D skeletons](https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html) | Godot docs, живой | Скиннинг `Polygon2D`, веса, позы |
| [Cutout animation](https://docs.godotengine.org/en/stable/tutorials/animation/cutout_animation.html) | Godot docs, живой | Перекладная анимация, RESET, IK-цепочки |
| [Skeleton2D](https://docs.godotengine.org/en/stable/classes/class_skeleton2d.html) / [Bone2D](https://docs.godotengine.org/en/stable/classes/class_bone2d.html) / [Polygon2D](https://docs.godotengine.org/en/stable/classes/class_polygon2d.html) | Godot class ref, 4.7 | API костей и скиннинга |
| [2D skeleton demo](https://github.com/godotengine/godot-demo-projects/tree/master/2d/skeleton) | Godot, 2026 | Рабочий пример |

---

## Скелеты 3D, модификаторы и IK

### Ключевые выводы
- `SkeletonModifier3D` (4.3+) — базовый класс узлов, меняющих позу `Skeleton3D` после анимации. Модификаторы — дети `Skeleton3D`; порядок их применения равен порядку детей; гарантированно выполняются после `AnimationMixer`; результат применяется к скину и сразу отбрасывается, поэтому в `_process()` вы видите позу без модификаций — читайте её по сигналам `mixer_applied`, `modification_processed`, `skeleton_updated`. `influence` смешивает результат с анимацией; свой модификатор переопределяет `_process_modification_with_delta()` (или `_process_modification()`) и нуждается в `@tool` для предпросмотра.
- Старые переопределения позы (`set_bone_global_pose_override`) и `SkeletonIK3D` — `[устарело]`: deprecated, замена — модификаторы.
- Модификаторы на 4.7.2 (классы сверены с API): `LookAtModifier3D` (4.4, голова/глаза/турель с ограничениями углов), `RetargetModifier3D` (4.4, ретаргетинг в реальном времени с сохранением исходного rest), `SpringBoneSimulator3D` (4.4, волосы, хвосты, «jiggle» с коллайдерами `SpringBoneCollision*3D`), `BoneConstraint3D` с `AimModifier3D`, `CopyTransformModifier3D`, `ConvertTransformModifier3D` (4.5), `PhysicalBoneSimulator3D` (рэгдолл), `XRHandModifier3D`/`XRBodyModifier3D`/`XRFaceModifier3D`.
- IK 4.6: базовый `IKModifier3D`; `TwoBoneIK3D` (рука/нога, нужен pole-цель) и `ChainIK3D` → `SplineIK3D` (позвоночник, хвост по кривой) и `IterateIK3D` → `FABRIK3D`, `CCDIK3D`, `JacobianIK3D`. `TwoBoneIK3D` и `SplineIK3D` всегда детерминированы; итеративные без опции deterministic переносят состояние между кадрами и сходятся даже при малом числе итераций, с ней — пригодны для сети (достаточно синхронизировать цель), но могут дать резкие угловые скорости — тогда добавьте `LimitAngularVelocityModifier3D`. `BoneTwistDisperser3D` распределяет скручивание (запястье → предплечье). С 4.6 цели модификаторов могут быть узлами `Node3D`.
- Ретаргетинг при импорте: в Advanced Import Settings назначьте `BoneMap` с `SkeletonProfileHumanoid`, включите переименование костей, «Unique Node» для скелета, фиксацию rest — тогда анимации из Mixamo, Blender и т. п. играются на любом гуманоиде с общей библиотекой.
- `BoneAttachment3D` — прикрепить меч к руке; рэгдолл — `PhysicalBone3D` под `PhysicalBoneSimulator3D` (`physical_bones_start_simulation()`).
- Blend shapes (morph targets): трек `BLEND_SHAPE` или свойство `blend_shapes/<name>` у `MeshInstance3D`; для лицевой анимации и визем.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Design of the Skeleton Modifier 3D](https://godotengine.org/article/design-of-the-skeleton-modifier-3d/) | Silc Renew, 2024 | Порядок обработки, сигналы, как писать свой модификатор |
| [Inverse kinematics returns to Godot 4.6](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/) | Silc Renew, 2025 | Иерархия IK-решателей, детерминизм, сеть |
| [Godot 4.6 release](https://godotengine.org/releases/4.6/) / [Godot 4.5 release](https://godotengine.org/releases/4.5/) / [Godot 4.4 release](https://godotengine.org/releases/4.4/) | Godot Foundation, 2025–2026 | IK, BoneConstraint, LookAt и SpringBone |
| [SkeletonModifier3D](https://docs.godotengine.org/en/stable/classes/class_skeletonmodifier3d.html) / [Skeleton3D](https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html) | Godot class ref, 4.7 | Виртуальные методы, `influence` |
| [IKModifier3D](https://docs.godotengine.org/en/stable/classes/class_ikmodifier3d.html) / [TwoBoneIK3D](https://docs.godotengine.org/en/stable/classes/class_twoboneik3d.html) / [FABRIK3D](https://docs.godotengine.org/en/stable/classes/class_fabrik3d.html) | Godot class ref, 4.6+ | Настройка цепочек и полюсов |
| [LookAtModifier3D](https://docs.godotengine.org/en/stable/classes/class_lookatmodifier3d.html) / [AimModifier3D](https://docs.godotengine.org/en/stable/classes/class_aimmodifier3d.html) / [BoneTwistDisperser3D](https://docs.godotengine.org/en/stable/classes/class_bonetwistdisperser3d.html) | Godot class ref, 4.4+ | Взгляд, прицел, распределение скручивания |
| [SpringBoneSimulator3D](https://docs.godotengine.org/en/stable/classes/class_springbonesimulator3d.html) / [RetargetModifier3D](https://docs.godotengine.org/en/stable/classes/class_retargetmodifier3d.html) | Godot class ref, 4.4+ | Вторичная анимация и ретаргетинг в рантайме |
| [Retargeting 3D skeletons](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html) | Godot docs, живой | `BoneMap`, профили, опции импорта |
| [BoneMap](https://docs.godotengine.org/en/stable/classes/class_bonemap.html) / [SkeletonProfileHumanoid](https://docs.godotengine.org/en/stable/classes/class_skeletonprofilehumanoid.html) | Godot class ref, 4.7 | Стандартный гуманоидный профиль |
| [Ragdoll system](https://docs.godotengine.org/en/stable/tutorials/physics/ragdoll_system.html) / [PhysicalBoneSimulator3D](https://docs.godotengine.org/en/stable/classes/class_physicalbonesimulator3d.html) | Godot docs, живой | Рэгдолл на физических костях |
| [BoneAttachment3D](https://docs.godotengine.org/en/stable/classes/class_boneattachment3d.html) / [SkeletonIK3D](https://docs.godotengine.org/en/stable/classes/class_skeletonik3d.html) | Godot class ref | Прикрепление к кости; старый IK — `[устарело]` |
| [3D IK demo](https://github.com/godotengine/godot-demo-projects/tree/master/3d/ik) | Godot, 2026 | Пример IK-сцены |

---

## Импорт, сжатие и производительность анимаций

### Ключевые выводы
- Импорт 3D-сцен (glTF предпочтительнее FBX): в опциях анимации задайте FPS выборки, режимы зацикливания по клипам, «Import Rest as RESET», удаление неизменных треков, оптимизатор (допуски по скорости/углу) и сжатие (`Animation.compress()` — меньше памяти, с потерей точности; только трансформ- и blend shape-треки) `[не проверено]` на точные пороги. Правки клипов в редакторе пропадут при реимпорте — либо сохраняйте анимации во внешние файлы через Advanced Import Settings, либо делайте правки в DCC.
- Суффиксы имён клипов `-loop`/`-cycle` в DCC выставляют зацикливание при импорте `[не проверено]` для 4.7 — надёжнее задать loop в Advanced Import Settings.
- Стоимость `AnimationMixer` растёт с числом треков и активных узлов дерева. Для далёких или невидимых персонажей выключайте `active` (через `VisibleOnScreenNotifier3D`) или переводите в `callback_mode_process = MANUAL` и вызывайте `advance(delta * k)` реже — простой анимационный LOD `[не проверено]` (замеров нет).
- `callback_mode_process`: IDLE — визуальная плавность; PHYSICS — когда анимация двигает коллизии и хитбоксы или даёт root motion; MANUAL — детерминированные повторы, сетевой rollback, пошаговая отрисовка.
- Тысячи анимированных юнитов — вершинная анимация (VAT) в шейдере через `MultiMesh` с per-instance данными; см. [performance.md](performance.md), раздел про рендеринг.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Import configuration](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html) | Godot docs, живой | Опции импорта анимаций, оптимизатор, сжатие |
| [Advanced import settings](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/advanced_import_settings.html) | Godot docs, живой | Сохранение анимаций в файлы, зацикливание клипов |
| [Godot 4.3 release](https://godotengine.org/releases/4.3/) | Godot Foundation, 2024 | Опции импорта скелетов для ретаргетинга FBX, копирование ключей |

---

## Синхронизация с геймплеем и кат-сцены

### Ключевые выводы
- События анимации («кадр удара», «шаг») — method-треки, вызывающие метод, который эмитит игровой сигнал (`hit_frame.emit()`); геймплей подписывается на сигнал, а не на анимацию. Альтернатива — маркеры (4.4+) и проверка позиции, если нужно знать границы отрезка.
- Хитбоксы атак включайте value-треком (`CollisionShape2D:disabled`, discrete) в анимации с `callback_mode_process = PHYSICS`, иначе возможна рассинхронизация с физическим кадром на один шаг.
- Ожидание анимации из кода: `await ap.animation_finished` — только для незацикленных; при возможной отмене (смерть персонажа, смена сцены) добавьте отменяющий сигнал или таймаут (см. [signals-async-threads.md](signals-async-threads.md)).
- Кат-сцены: один «режиссёрский» `AnimationPlayer` с треками камеры, субтитров, `ANIMATION`-треками для `AnimationPlayer` персонажей и audio-треками; ввод игрока блокируется на время сцены, пауза — через `process_mode` нод кат-сцены. Ждать реплику — `tween_await` (4.7) или пауза плеера до сигнала диалоговой системы. Записать ролик — Movie Maker.
- Музыкальный ритм: позицию трека считайте через `AudioServer` (раздел ниже), а не по накопленному `delta`.

---

## AudioServer и шины

### Ключевые выводы
- Без макета шин в проекте одна шина `Master` 0 дБ без эффектов (проверено на 4.7.2: headless-драйвер `Dummy`, 44100 Гц). Макет — `res://default_bus_layout.tres` (`audio/buses/default_bus_layout`), редактируется на панели Audio. Шины отправляют сигнал (`send`) в родительскую, обычно в `Master`; порядок шин важен — отправлять можно только «левее».
- Типичный макет: `Master` ← `Music`, `SFX` (← `Footsteps`, `Weapons`), `UI`, `Voice`, `Ambience`, плюс шины-реверберации для зон (`Reverb_Cave`). На `Master` последним эффектом ставьте `AudioEffectHardLimiter` (4.3+) — защита от клиппинга при наложении; старый `AudioEffectLimiter` устарел ([PR #103847](https://github.com/godotengine/godot/pull/103847)).
- Эффекты (`AudioEffectReverb`, `Compressor`, `EQ`, `Filter`, `Delay`, `Chorus`, `Distortion`, `PitchShift`, `SpectrumAnalyzer`, `Capture`, `Record`) стоят на шине и обрабатывают всё, что в неё приходит; эффект на шине дешевле, чем копии на каждом плеере. Bypass, mute и solo — для отладки микса прямо в редакторе.
- Из кода: `get_bus_index(name)`, `set_bus_volume_db`/`set_bus_volume_linear` (4.4+), `set_bus_mute`, `set_bus_effect_enabled` (например, low-pass на `Music` в меню паузы), `get_bus_peak_volume_left_db` для индикаторов. Индексы шин не хардкодьте — ищите по имени.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Audio (раздел)](https://docs.godotengine.org/en/stable/tutorials/audio/index.html) | Godot docs, живой | Вход в раздел |
| [Audio buses](https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html) | Godot docs, живой | Макет, отправки, шкала дБ |
| [Audio effects](https://docs.godotengine.org/en/stable/tutorials/audio/audio_effects.html) | Godot docs, живой | Описание каждого эффекта |
| [AudioServer](https://docs.godotengine.org/en/stable/classes/class_audioserver.html) / [AudioBusLayout](https://docs.godotengine.org/en/stable/classes/class_audiobuslayout.html) | Godot class ref, 4.7 | API шин, устройств, задержки |
| [AudioEffectHardLimiter](https://docs.godotengine.org/en/stable/classes/class_audioeffecthardlimiter.html) / [AudioEffectLimiter](https://docs.godotengine.org/en/stable/classes/class_audioeffectlimiter.html) | Godot class ref | Новый и устаревший лимитеры |
| [AudioEffectReverb](https://docs.godotengine.org/en/stable/classes/class_audioeffectreverb.html) / [AudioEffectSpectrumAnalyzer](https://docs.godotengine.org/en/stable/classes/class_audioeffectspectrumanalyzer.html) | Godot class ref, 4.7 | Зоны реверберации, визуализация спектра |

---

## Плееры и пространственный звук

### Ключевые выводы
- `AudioStreamPlayer` — без позиции (музыка, UI, голос рассказчика); `AudioStreamPlayer2D` — панорама и затухание по расстоянию до `AudioListener2D`/камеры; `AudioStreamPlayer3D` — 3D с моделями затухания, конусом излучения, фильтром по расстоянию, доплером.
- `max_polyphony` по умолчанию **1** у всех трёх (проверено на 4.7.2): повторный `play()` обрывает предыдущий звук. Для очереди выстрелов из одного источника поднимите до 4–8.
- Значения по умолчанию (проверено на 4.7.2): 2D — `max_distance = 2000`, `attenuation = 1`; 3D — `unit_size = 10`, `max_db = 3`, `max_distance = 0` (без предела), `ATTENUATION_INVERSE_DISTANCE`, фильтр затухания 5000 Гц / −24 дБ, доплер выключен; панорамирование проекта 2D/3D — 0.5.
- Доплер требует включить `doppler_tracking` и у плеера, и у `Camera3D` (IDLE_STEP или PHYSICS_STEP — по тому, где двигается объект). Зональная реверберация: `Area3D` с `reverb_bus_enabled`, `reverb_bus_name`, `reverb_bus_amount`, `reverb_bus_uniformity`; `audio_bus_override` переводит звуки внутри зоны на другую шину; плеер учитывает зоны по `area_mask`.
- `AudioListener3D` с `make_current()` — когда слушать нужно не от камеры (вид от третьего лица: уши у персонажа).
- `playback_type`: DEFAULT (по настройке проекта), STREAM, SAMPLE (4.3+, см. Web). `volume_linear` (4.4+) вместо ручного `db_to_linear`. `get_stream_playback()` даёт объект воспроизведения (нужно для polyphonic, interactive, generator).

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Audio streams](https://docs.godotengine.org/en/stable/tutorials/audio/audio_streams.html) | Godot docs, живой | Плееры, доплер, зоны реверберации |
| [AudioStreamPlayer](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html) / [2D](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer2d.html) / [3D](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html) | Godot class ref, 4.7 | Затухание, полифония, playback type |
| [Area3D](https://docs.godotengine.org/en/stable/classes/class_area3d.html) / [AudioListener3D](https://docs.godotengine.org/en/stable/classes/class_audiolistener3d.html) | Godot class ref, 4.7 | Реверберация зон, слушатель |
| [PR #99268](https://github.com/godotengine/godot/pull/99268) | godotengine, 2024 | `volume_linear` у плееров и шин (4.4) |

---

## Типы AudioStream и интерактивная музыка

### Ключевые выводы
- WAV — без декодирования, минимальная нагрузка CPU, большой размер; режимы импорта: PCM, IMA ADPCM, QOA (сжатие с малой ценой декодирования, `FORMAT_QOA` есть в 4.7.2). Ogg Vorbis и MP3 — сжатые, для музыки и длинного эмбиента. Loop и точки цикла задавайте в импорте (у WAV — `loop_begin/end`, у Ogg/MP3 — `loop_offset`, BPM, число тактов для интерактивной музыки).
- Загрузка в рантайме (моды, пользовательская музыка): `AudioStreamOggVorbis.load_from_file()`, `AudioStreamWAV.load_from_file()` (4.4+), `AudioStreamMP3.load_from_file()` (статические методы есть у всех трёх в 4.7.2).
- `AudioStreamRandomizer` — набор вариантов с весами, случайной высотой (`random_pitch`, по умолчанию 1.0 — без разброса, проверено на 4.7.2) и громкостью; режимы RANDOM_NO_REPEATS/RANDOM/SEQUENTIAL. `AudioStreamPolyphonic` (полифония 32 по умолчанию, проверено) — много звуков через один плеер `play_stream()`.
- Адаптивная музыка 4.3+: `AudioStreamInteractive` — клипы и таблица переходов (с момента: сразу, следующий бит, такт, конец; куда: та же позиция, начало, предыдущая позиция; fade in/out/cross; клип-заполнитель; auto-advance); переключение — `get_stream_playback().switch_to_clip_by_name()`. `AudioStreamSynchronized` — стемы, играющие синхронно, громкость слоёв меняется по напряжённости. `AudioStreamPlaylist` — последовательность треков с кроссфейдом и shuffle.
- FMOD или Wwise — когда звук ведёт отдельный звукорежиссёр в их инструментах; интеграции и версии — в [domains.md](domains.md), раздел 8.

### Какой AudioStream

| Задача | Поток | Замечание |
|---|---|---|
| Короткий частый SFX (шаг, выстрел) | `AudioStreamWAV` (PCM или QOA) | Без декодирования; разнообразие — через Randomizer |
| Варианты одного звука | `AudioStreamRandomizer` | Вес, высота, громкость, без повторов |
| Музыка, длинный эмбиент | `AudioStreamOggVorbis` / `AudioStreamMP3` | Стриминг; loop в импорте |
| Музыка со сменой по ситуации | `AudioStreamInteractive` | Переходы по бит/такт, клип-заполнитель |
| Слои по интенсивности | `AudioStreamSynchronized` | Громкость стемов из кода |
| Плейлист радио/меню | `AudioStreamPlaylist` | Последовательно или shuffle |
| Сотни звуков через один узел | `AudioStreamPolyphonic` | `play_stream()` на playback |
| Синтез, эмулятор, речь по сети | `AudioStreamGenerator` | Заполнение буфера из кода |
| Голос игрока | `AudioStreamMicrophone` + `AudioEffectCapture`/`Record` | Включить `audio/driver/enable_input` |

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Importing audio samples](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_audio_samples.html) | Godot docs, живой | Форматы, QOA/ADPCM, loop, BPM |
| [AudioStreamWAV](https://docs.godotengine.org/en/stable/classes/class_audiostreamwav.html) / [AudioStreamOggVorbis](https://docs.godotengine.org/en/stable/classes/class_audiostreamoggvorbis.html) / [AudioStreamMP3](https://docs.godotengine.org/en/stable/classes/class_audiostreammp3.html) | Godot class ref, 4.7 | Свойства и загрузка в рантайме |
| [AudioStreamRandomizer](https://docs.godotengine.org/en/stable/classes/class_audiostreamrandomizer.html) / [AudioStreamPolyphonic](https://docs.godotengine.org/en/stable/classes/class_audiostreampolyphonic.html) / [AudioStreamPlaybackPolyphonic](https://docs.godotengine.org/en/stable/classes/class_audiostreamplaybackpolyphonic.html) | Godot class ref, 4.7 | Вариации и полифония |
| [AudioStreamInteractive](https://docs.godotengine.org/en/stable/classes/class_audiostreaminteractive.html) / [Synchronized](https://docs.godotengine.org/en/stable/classes/class_audiostreamsynchronized.html) / [Playlist](https://docs.godotengine.org/en/stable/classes/class_audiostreamplaylist.html) | Godot class ref, 4.3+ | Адаптивная музыка без middleware |
| [PR #64488](https://github.com/godotengine/godot/pull/64488) | Juan Linietsky, 2024 | Как задумана интерактивная музыка |
| [Audio manager recipe](https://kidscancode.org/godot_recipes/4.x/audio/audio_manager/index.html) | KidsCanCode, живой | Автозагрузка с пулом плееров |

---

## Генерация, микрофон, задержка и Web

### Ключевые выводы
- `AudioStreamGenerator` (по умолчанию 44100 Гц, буфер 0.5 с, проверено на 4.7.2): после `play()` берите `AudioStreamGeneratorPlayback` и заполняйте `push_frame()`/`push_buffer()` ровно `get_frames_available()` кадрами каждый кадр. Маленький буфер — меньше задержка, но риск щелчков при просадке FPS. На Web в режиме SAMPLE генерация не работает.
- Микрофон: включите `audio/driver/enable_input` (по умолчанию false, проверено), плеер с `AudioStreamMicrophone` на шине с `AudioEffectCapture` (сырые кадры для VoIP/распознавания) или `AudioEffectRecord` (запись в `AudioStreamWAV`). На macOS/iOS нужно описание доступа к микрофону в экспорте, на Web — secure context.
- Задержка: `audio/driver/output_latency` — 15 мс, на Web 50 мс (проверено на 4.7.2), `audio/driver/mix_rate` — 44100. Реальную задержку смотрите через `AudioServer.get_output_latency()`.
- Синхронизация с музыкой: `time = player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()` — стандартная формула документации для ритм-игр.
- Web (4.3+): по умолчанию сэмпловое воспроизведение через Web Audio (`audio/general/default_playback_type.web = Sample`, на остальных платформах — Stream; проверено на 4.7.2). Ограничения сэмплов: не работают эффекты шин, реверберация и доплер, процедурная генерация; позиционный звук может вести себя некорректно. Нужен полный микшер — переключите плеер или настройку на Stream и экспортируйте с потоками (cross-origin isolation), иначе задержка вырастет. Браузеры не дают играть звук до жеста пользователя — сделайте экран «нажмите, чтобы начать».
- Звуки, которые будут играться сэмплами, можно заранее зарегистрировать `AudioServer.register_stream_as_sample()`, чтобы первый запуск не подтормаживал `[не проверено]`.

```gdscript
var _gen: AudioStreamGeneratorPlayback
var _phase := 0.0

func start_tone(player: AudioStreamPlayer) -> void:
    var gen := AudioStreamGenerator.new()
    gen.mix_rate = 44100.0
    gen.buffer_length = 0.1        # меньше задержка, выше риск щелчков
    player.stream = gen
    player.play()
    _gen = player.get_stream_playback()

func fill_tone(hz: float) -> void:  # вызывать каждый кадр
    var inc := hz / 44100.0
    for i in _gen.get_frames_available():
        _gen.push_frame(Vector2.ONE * sin(_phase * TAU))
        _phase = fmod(_phase + inc, 1.0)
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Sync the gameplay with audio and music](https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html) | Godot docs, живой | Формула позиции с учётом задержки |
| [Recording with microphone](https://docs.godotengine.org/en/stable/tutorials/audio/recording_with_microphone.html) | Godot docs, живой | `AudioEffectRecord`, микрофон |
| [AudioStreamGenerator](https://docs.godotengine.org/en/stable/classes/class_audiostreamgenerator.html) / [AudioEffectCapture](https://docs.godotengine.org/en/stable/classes/class_audioeffectcapture.html) / [AudioStreamMicrophone](https://docs.godotengine.org/en/stable/classes/class_audiostreammicrophone.html) / [AudioEffectRecord](https://docs.godotengine.org/en/stable/classes/class_audioeffectrecord.html) | Godot class ref, 4.7 | Синтез и захват |
| [Exporting for the Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html) | Godot docs, живой | Sample против Stream, автозапуск, потоки |
| [PR #91382](https://github.com/godotengine/godot/pull/91382) | Adam Scott, 2024 | Как устроено сэмпловое воспроизведение на Web |
| [Text to speech](https://docs.godotengine.org/en/stable/tutorials/audio/text_to_speech.html) | Godot docs, живой | Озвучка интерфейса, доступность |
| Демо: [bpm_sync](https://github.com/godotengine/godot-demo-projects/tree/master/audio/bpm_sync), [generator](https://github.com/godotengine/godot-demo-projects/tree/master/audio/generator), [mic_record](https://github.com/godotengine/godot-demo-projects/tree/master/audio/mic_record), [spectrum](https://github.com/godotengine/godot-demo-projects/tree/master/audio/spectrum), [device_changer](https://github.com/godotengine/godot-demo-projects/tree/master/audio/device_changer) | Godot, 2026 | Рабочие примеры по каждой теме |

---

## Пулы, ducking, громкость и настройки

### Ключевые выводы
- Пул: заранее создайте 8–32 плеера в автозагрузке и выдавайте свободный (`not playing`), при исчерпании — самый старый. Не создавайте `AudioStreamPlayer` на каждый выстрел и не делайте «звук смерти» ребёнком врага, которого сейчас освободят: звук оборвётся. Ограничьте одновременные одинаковые звуки (не больше N копий одного стрима за кадр), иначе громкость складывается.
- Ducking: на шине `Music` поставьте `AudioEffectCompressor` с `sidechain = "Voice"` — музыка приглушается, пока звучит речь; альтернатива — твин громкости шины.
- Громкость в UI — линейная (0..1), а в движке — дБ: `linear_to_db(0.5) = −6.02`, `linear_to_db(0.1) = −20`, `linear_to_db(0) = −inf`; `db_to_linear(−6) ≈ 0.501`, `db_to_linear(−80) = 0.0001` (проверено на 4.7.2). На нуле лучше `set_bus_mute(true)`, чем −inf. Для «естественного» ощущения ползунка можно возвести линейное значение в квадрат перед `linear_to_db`.
- Сохраняйте настройки в `user://settings.cfg` (`ConfigFile`) и применяйте при старте в автозагрузке, до первой музыки.

```gdscript
# SfxPool.gd — автозагрузка
extends Node
const POOL_SIZE := 16
var _players: Array[AudioStreamPlayer2D] = []
var _next := 0

func _ready() -> void:
    for i in POOL_SIZE:
        var p := AudioStreamPlayer2D.new()
        p.bus = &"SFX"
        add_child(p)
        _players.append(p)

func play_at(stream: AudioStream, pos: Vector2, pitch_jitter := 0.05) -> void:
    var p := _find_free()
    p.stream = stream
    p.global_position = pos
    p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
    p.play()

func _find_free() -> AudioStreamPlayer2D:
    for i in POOL_SIZE:
        var p := _players[(_next + i) % POOL_SIZE]
        if not p.playing:
            _next = (_next + i + 1) % POOL_SIZE
            return p
    var oldest := _players[_next]  # все заняты — перехватываем самый старый
    _next = (_next + 1) % POOL_SIZE
    return oldest
```

```gdscript
const SETTINGS_PATH := "user://settings.cfg"

func set_bus_volume(bus_name: StringName, linear: float) -> void:
    var idx := AudioServer.get_bus_index(bus_name)
    if idx == -1:
        push_warning("No bus %s" % bus_name)
        return
    AudioServer.set_bus_volume_linear(idx, linear)   # 4.4+
    AudioServer.set_bus_mute(idx, linear <= 0.001)

func save_volumes() -> void:
    var cfg := ConfigFile.new()
    for bus in [&"Master", &"Music", &"SFX"]:
        cfg.set_value("audio", bus, AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(bus)))
    var err := cfg.save(SETTINGS_PATH)
    if err != OK:
        push_error("save settings: %s" % error_string(err))
```

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [AudioEffectCompressor](https://docs.godotengine.org/en/stable/classes/class_audioeffectcompressor.html) | Godot class ref, 4.7 | `sidechain` для ducking |
| [ConfigFile](https://docs.godotengine.org/en/stable/classes/class_configfile.html) / [Saving games](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html) | Godot docs, живой | Хранение настроек в `user://` |
| [Singletons (Autoload)](https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html) | Godot docs, живой | Где держать пул и менеджер музыки |
| [PR #111455](https://github.com/godotengine/godot/pull/111455) | godotengine, 2026 | Звуки темы UI в master (ветка 4.8, в 4.7 нет) |

---

## Антипаттерны

### Ключевые выводы
- `await tween.finished` / `await ap.animation_finished` без защиты от `kill()`, освобождения узла и зацикливания — корутина зависает навсегда (проверено на 4.7.2 для твина).
- Твин меню паузы через `get_tree().create_tween()` в надежде, что «непривязанный не паузится» — он паузится; нужен `TWEEN_PAUSE_PROCESS`.
- Новый твин на то же свойство без `kill()` старого — дёрганье и «победа» последнего.
- `AnimationTree` без RESET-анимации при разных наборах треков — свойства уезжают к нулю (масштаб 0, позиция 0).
- Игровая логика зависит от `get_current_node()` дерева или от длительности анимации, захардкоженной в таймере, вместо method-трека/сигнала.
- `AnimationPlayer` и `AnimationTree` с одним и тем же плеером играют одновременно — два источника правды для позы.
- Хитбоксы в анимации с `callback_mode_process = IDLE`, а атака в `_physics_process` — рассинхрон на кадр.
- Правки импортированных анимаций прямо в сцене — пропадают при реимпорте.
- `SkeletonIK3D` и `set_bone_global_pose_override` в новом коде — `[устарело]`, используйте модификаторы.
- Новый `AudioStreamPlayer` на каждый звук через `add_child` и `queue_free` по `finished`; звук как ребёнок удаляемого объекта.
- `max_polyphony = 1` (по умолчанию) у плеера автоматной очереди — каждый выстрел обрывает предыдущий.
- Громкость ползунком напрямую в `volume_db` (линейный 0..1 в дБ) или фиксированные индексы шин.
- Эффекты на шинах в Web-сборке с сэмпловым воспроизведением — не звучат; проверяйте на целевой платформе.
- Музыка в WAV на сотни мегабайт; короткие частые SFX в Ogg с декодированием на каждый запуск.
- Синхронизация ритм-игры по накопленному `delta` вместо позиции воспроизведения с поправкой на задержку.
- Узел `Tween` и `interpolate_property()`, `AnimationTreePlayer` — `[устарело]` (Godot 3).

---

## Чеклист анимации и аудио

1. Для каждой задачи выбран инструмент по таблице: `AnimationPlayer`, `AnimationTree`, `Tween` или `AnimatedSprite2D`.
2. Во всех анимируемых сценах есть RESET-анимация; `reset_on_save` включён.
3. У `AnimationTree` понятен режим `deterministic` (по умолчанию true) и RESET содержит все смешиваемые треки.
4. Discrete-свойства (`visible`, `frame`, `disabled`) — на треках `UPDATE_DISCRETE`; углы — `LINEAR_ANGLE`/`CUBIC_ANGLE`.
5. Анимации, двигающие коллизии или дающие root motion, — `callback_mode_process = PHYSICS`.
6. События анимации идут через method-треки → игровые сигналы, а не через таймеры с длительностью.
7. Нет ожиданий `animation_finished` на зацикленных анимациях; есть отмена/таймаут для ожиданий.
8. Общие анимации — во внешних `AnimationLibrary`, подключаемых к нескольким плеерам.
9. Код владеет состоянием персонажа; дерево получает `travel()`, условия и `blend_position`.
10. `advance_expression_base_node` указывает на корень персонажа, если используются выражения.
11. `AnimationNodeStateMachinePlayback` закэширован в `@onready`.
12. Каждый перезапускаемый твин хранится в поле и убивается перед новым.
13. Твины UI во время паузы — с `TWEEN_PAUSE_PROCESS`; игровые — привязаны к игровым узлам.
14. Нет `await tween.finished` у бесконечных или убиваемых твинов; ожидание сигнала внутри цепочки — `tween_await` (4.7+).
15. Невидимые или далёкие персонажи не обрабатывают `AnimationTree` (выключен `active` или ручной `advance`).
16. 3D-модификаторы (LookAt, IK, SpringBone) — дети `Skeleton3D` в нужном порядке; нет `SkeletonIK3D` и pose override.
17. Импорт гуманоидов — с `BoneMap` и `SkeletonProfileHumanoid`; анимации сохранены во внешние файлы, если их правят в Godot.
18. Опции импорта анимаций (FPS, loop, оптимизатор, сжатие) заданы осознанно.
19. Макет шин `Master`/`Music`/`SFX`/`UI`/`Voice` есть в `default_bus_layout.tres`; плееры назначены на шины.
20. На `Master` последним стоит `AudioEffectHardLimiter`.
21. Шины ищутся по имени (`get_bus_index`), отсутствие шины обрабатывается.
22. Короткие SFX — WAV (PCM/QOA), музыка — Ogg/MP3; loop задан в импорте.
23. Вариации звука — `AudioStreamRandomizer`, а не ручной `randf` по массиву плееров.
24. Частые звуки — через пул или `AudioStreamPolyphonic`; `max_polyphony` поднят там, где нужны наложения.
25. Звуки смерти и подбора не обрываются при освобождении объекта (играют из пула).
26. Пространственный звук настроен: `unit_size`/`max_distance`/модель затухания, `area_mask` и зоны реверберации; доплер включён и у плеера, и у камеры, если нужен.
27. Громкость в UI линейная, в движок идёт через `set_bus_volume_linear`/`linear_to_db`; на нуле — mute.
28. Настройки громкости сохраняются в `user://settings.cfg` и применяются при запуске.
29. Ducking музыки под голос — компрессор с `sidechain` или твин шины.
30. Адаптивная музыка — `AudioStreamInteractive`/`Synchronized` (или FMOD/Wwise по требованиям звукорежиссёра).
31. Web-сборка проверена в браузере: экран «нажмите, чтобы начать», эффекты шин при Sample, при необходимости — Stream с потоками.
32. Ритм и синхронизация с музыкой — по `get_playback_position()` + `get_time_since_last_mix()` − `get_output_latency()`.
33. Микрофон: включён `audio/driver/enable_input`, разрешения платформы в пресетах экспорта.

| Ресурс | Автор, год | Зачем читать |
|---|---|---|
| [Audio demos](https://github.com/godotengine/godot-demo-projects/tree/master/audio) | Godot, 2026 | Все аудиодемо одним каталогом |
| [Godot 4.7 release](https://godotengine.org/releases/4.7/) | Godot Foundation, 2026 | `tween_await`, сворачиваемые треки, follow mode в 3D-редакторе |
| [Godot 4.2 arrives in style](https://godotengine.org/article/godot-4-2-arrives-in-style/) | Godot Foundation, 2023 | `AnimationMixer` и root motion в `AnimationPlayer` |
| [GDQuest (YouTube)](https://www.youtube.com/@Gdquest) | GDQuest, живой | Видеоуроки по анимации, твинам и звуку в Godot 4 |

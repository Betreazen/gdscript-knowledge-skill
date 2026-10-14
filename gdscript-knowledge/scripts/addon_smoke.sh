#!/usr/bin/env bash
# Проверяет, что аддон загружается в чистом проекте на вашей версии Godot, до установки в настоящий проект.
#   GODOT=/путь/к/godot ./addon_smoke.sh <git-url[@тег]|локальный-каталог> [рабочий-каталог] [подкаталог]
# Тег отделяется последним «@», если после него нет «/» и «:» (git@host:o/r.git без тега тоже работает).
# Подкаталог нужен, если в репозитории несколько вариантов аддона (например, YATI: GDScript/ и CSharp/).
# Рабочий каталог должен быть пустым или отсутствовать; по умолчанию создаётся временный.
# Что делает:
#   1. Клонирует репозиторий (--depth 1) и копирует его каталог addons/ целиком в пустой проект:
#      многие аддоны зависят от соседних каталогов. Если addons/ нет в корне, берёт самый неглубокий
#      вложенный (например godot/addons/), а если нет и его, копирует корень как addons/<имя>.
#      Тест-фреймворки, которые лежат в репозитории рядом с аддоном (gut, gdUnit4, vest), пропускаются:
#      это зависимости разработки аддона, часто старых версий.
#   2. Включает плагины так же, как галочка в Project Settings: служебный плагин вызывает
#      EditorInterface.set_plugin_enabled(), поэтому срабатывают _enable_plugin() и _enter_tree(),
#      и автозагрузки плагина попадают в project.godot. Правка [editor_plugins] руками этого не делает.
#   3. Второй запуск редактора, компиляция всех скриптов аддона через check_scripts.sh и проверка,
#      что движок загрузил каждую .gdextension (нативная библиотека есть для этой ОС и совместима).
# Код выхода 1, если настоящий EditorPlugin не включился, GDExtension не загрузилась, во втором запуске
# редактора есть ошибки скриптов или хотя бы один скрипт не скомпилировался. Код 2 — ошибка окружения (клон, Godot, аргументы).
# Аддон исполняет свой код в редакторе: запускайте только то, что собираетесь ставить.
set -u
godot="${GODOT:-godot}"
here="$(cd "$(dirname "$0")" && pwd)"
src=${1:?usage: addon_smoke.sh <git-url[@tag]|dir> [workdir] [subdir]}
work=${2:-}
subdir=${3:-}

version=$("$godot" --version 2>/dev/null | head -1 | cut -d. -f1,2)
[ -n "$version" ] || { echo "cannot run Godot: set GODOT to the editor binary" >&2; exit 2; }
if [ -z "$work" ]; then
  work=$(mktemp -d)
elif [ -e "$work" ] && [ -n "$(ls -A "$work" 2>/dev/null)" ]; then
  echo "workdir $work is not empty" >&2; exit 2
fi
mkdir -p "$work/proj/addons"
run() { if command -v timeout > /dev/null; then timeout 900 "$@"; else "$@"; fi; }

if [ -d "$src" ]; then
  base=$(cd "$src" && pwd)
else
  url=$src; ref=""
  tail=${src##*@}
  if [ "$tail" != "$src" ] && [[ "$tail" != */* && "$tail" != *:* ]]; then
    url=${src%@*}; ref=$tail
  fi
  git -c advice.detachedHead=false clone -q --depth 1 ${ref:+--branch "$ref"} -- "$url" "$work/src" ||
    { echo "clone failed" >&2; exit 2; }
  base="$work/src"
fi
if [ -n "$subdir" ]; then
  base="$base/$subdir"
  [ -d "$base" ] || { echo "no subdir $subdir in source" >&2; exit 2; }
fi

addons_dir="$base/addons"
if [ ! -d "$addons_dir" ]; then
  addons_dir=$(find "$base" -mindepth 2 -maxdepth 3 -type d -name addons -not -path '*/.git/*' |
    awk -F/ '{print NF "\t" $0}' | sort -n | head -1 | cut -f2-)
fi
skipped=""
if [ -n "$addons_dir" ] && [ -d "$addons_dir" ]; then
  own=$(find "$addons_dir" -mindepth 1 -maxdepth 1 -type d | wc -l)
  for dir in "$addons_dir"/*/; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    if [ "$own" -gt 1 ] && [[ "$name" == gut || "$name" == gdUnit4 || "$name" == vest ]]; then
      skipped="$skipped $name"; continue
    fi
    cp -R "${dir%/}" "$work/proj/addons/"
  done
  for f in "$addons_dir"/*; do [ -f "$f" ] && cp "$f" "$work/proj/addons/"; done
else
  name=$(basename "$base" .git)
  mkdir -p "$work/proj/addons/$name"
  (cd "$base" && tar --exclude=.git -cf - .) | (cd "$work/proj/addons/$name" && tar -xf -)
fi

cd "$work/proj"
mkdir -p addons/_smoke_enabler
printf '[plugin]\n\nname="smoke enabler"\ndescription=""\nauthor=""\nversion="1"\nscript="enabler.gd"\n' > addons/_smoke_enabler/plugin.cfg
cat > addons/_smoke_enabler/enabler.gd <<'EOF'
@tool
extends EditorPlugin


func _enter_tree() -> void:
	_enable_all.call_deferred()


func _enable_all() -> void:
	# До конца первого сканирования кеш UID пуст, и preload("uid://...") в плагине не сработает.
	var fs := EditorInterface.get_resource_filesystem()
	while fs.is_scanning():
		await get_tree().process_frame
	for i in 10:
		await get_tree().process_frame
	for cfg in OS.get_environment("SMOKE_PLUGINS").split("\n", false):
		EditorInterface.set_plugin_enabled(cfg, true)
		print("SMOKE ", "enabled" if EditorInterface.is_plugin_enabled(cfg) else "disabled", " ", cfg)
	for i in 30:
		await get_tree().process_frame
	# set_plugin_enabled() меняет настройки только в памяти; без save() список плагинов
	# и автозагрузки из _enter_tree() не попадут в project.godot.
	ProjectSettings.save()
	get_tree().quit()
EOF
plugins=$(find addons -mindepth 2 -maxdepth 4 -type f -name plugin.cfg -not -path 'addons/_smoke_enabler/*' | sort | sed 's|^|res://|')
printf 'config_version=5\n\n[application]\n\nconfig/name="addon_smoke"\nconfig/features=PackedStringArray("%s")\n\n[editor_plugins]\n\nenabled=PackedStringArray("res://addons/_smoke_enabler/plugin.cfg")\n' \
  "$version" > project.godot

run "$godot" --headless --path . --import > ../import.log 2>&1
export SMOKE_PLUGINS="$plugins"
run "$godot" --headless --editor --path . --quit-after 5000 > ../editor1.log 2>&1

# Список включённых плагинов собираем заново, без служебного; остальной project.godot не трогаем.
enabled=$(sed -n 's/^SMOKE enabled //p' ../editor1.log | sed 's/.*/"&"/' | paste -sd, -)
awk -v line="enabled=PackedStringArray($enabled)" '/^enabled=PackedStringArray\(/ {print line; next} {print}' \
  project.godot > project.godot.tmp && mv project.godot.tmp project.godot
rm -rf addons/_smoke_enabler

broken_plugins=""
while IFS= read -r cfg; do
  [ -n "$cfg" ] || continue
  grep -qxF "SMOKE enabled $cfg" ../editor1.log && continue
  script=$(sed -n 's/^script="\(.*\)"/\1/p' "${cfg#res://}")
  script_path="$(dirname "${cfg#res://}")/$script"
  if [ -f "$script_path" ] && grep -q 'extends *EditorPlugin' "$script_path"; then
    broken_plugins="$broken_plugins $cfg"
  fi
done <<< "$plugins"

run "$godot" --headless --editor --path . --quit-after 300 > ../editor2.log 2>&1
log_errors=$(grep -cE 'SCRIPT ERROR|Parse Error|Failed to load|Compile Error' ../editor2.log)
GODOT="$godot" bash "$here/check_scripts.sh" none > ../check.log 2>&1
check_status=$?

# GDExtension: каждая найденная .gdextension должна оказаться среди загруженных движком.
printf 'extends SceneTree\n\n\nfunc _initialize() -> void:\n\tfor path in GDExtensionManager.get_loaded_extensions():\n\t\tprint("EXT ", path)\n\tquit()\n' > ../ext_probe.gd
run "$godot" --headless --path . -s "$work/ext_probe.gd" > ../ext.log 2>&1
missing_ext=""
extensions=$(find addons -type f -name '*.gdextension' | sort)
while IFS= read -r ext; do
  [ -n "$ext" ] || continue
  grep -qxF "EXT res://$ext" ../ext.log || missing_ext="$missing_ext res://$ext"
done <<< "$extensions"

total_plugins=$(printf '%s\n' "$plugins" | grep -c .)
echo "plugins:   $(grep -c '^SMOKE enabled ' ../editor1.log) enabled of $total_plugins"
[ -n "$broken_plugins" ] && echo "EditorPlugin failed to enable:$broken_plugins"
[ -n "$extensions" ] && echo "gdextensions: $(grep -c '^EXT ' ../ext.log) loaded of $(printf '%s\n' "$extensions" | grep -c .)"
[ -n "$missing_ext" ] && echo "GDExtension not loaded:$missing_ext"
[ -n "$skipped" ] && echo "skipped bundled test frameworks:$skipped"
echo "autoloads: $(sed -n '/^\[autoload\]/,/^\[/p' project.godot | grep -c '=')"
grep -E '^checked' ../check.log
grep -hE 'SCRIPT ERROR|Parse Error|Failed to load|Compile Error' ../editor2.log | sort | uniq -c | sort -rn | head -10
grep -E '^(FAIL|    )' ../check.log | head -20
echo "logs: $work"
if [ -z "$broken_plugins" ] && [ -z "$missing_ext" ] && [ "$log_errors" -eq 0 ] && [ "$check_status" -eq 0 ]; then
  echo "RESULT ok"; exit 0
fi
echo "RESULT fail (editor errors: $log_errors)"
exit 1

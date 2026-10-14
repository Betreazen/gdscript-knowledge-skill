#!/usr/bin/env bash
# Проверяет все .gd проекта настоящим компилятором GDScript (через check_scripts.gd, Godot 4.5+).
# Запуск из корня проекта после `godot --headless --path . --import`:
#   GODOT=/путь/к/godot ./check_scripts.sh [каталог-исключение ...]
# По умолчанию исключаются .godot/ и addons/. Аргументы заменяют исключение addons/, а не дополняют его:
# `./check_scripts.sh addons tools` исключит оба каталога, `./check_scripts.sh none` проверит и аддоны.
# Код выхода 1, если хотя бы один скрипт не прошёл или проверка не смогла запуститься.
# Ошибки уровня Warn не ломают проверку: строгость задаётся уровнем Error в project.godot.
# В отличие от цикла с `--check-only`, не даёт ложных ошибок на обращения к автозагрузкам по имени.
set -u
godot="${GODOT:-godot}"
checker="$(cd "$(dirname "$0")" && pwd)/check_scripts.gd"
excludes=("${@:-addons}")
find_args=(. -type f -name '*.gd' -not -path './.godot/*')
for dir in "${excludes[@]}"; do
  dir=${dir#./}
  find_args+=(-not -path "./${dir%/}/*")
done

list=$(mktemp)
trap 'rm -f "$list"' EXIT
find "${find_args[@]}" -exec bash -c 'for f; do printf "res://%s\0" "${f#./}"; done' _ {} + > "$list"
total=$(tr -cd '\0' < "$list" | wc -c | tr -d ' ')
[ "$total" -gt 0 ] || { echo "no .gd files to check"; exit 0; }

# Пачки по 200 файлов, чтобы не упереться в лимит длины командной строки.
out=$(xargs -0 -n 200 "$godot" --headless --path . -s "$checker" -- < "$list" 2>/dev/null)
printf '%s\n' "$out" | grep -E '^(FAIL|    )'
checked=$(printf '%s\n' "$out" | sed -n 's/^checked \([0-9]*\) scripts.*/\1/p' | awk '{s+=$1} END {print s+0}')
failed=$(printf '%s\n' "$out" | sed -n 's/^checked [0-9]* scripts, \([0-9]*\) failed/\1/p' | awk '{s+=$1} END {print s+0}')
echo "checked $checked of $total scripts, $failed failed"
if [ "$checked" -ne "$total" ]; then
  echo "checker did not process every file: needs Godot 4.5+ and a project imported with --import" >&2
  exit 1
fi
[ "$failed" -eq 0 ]

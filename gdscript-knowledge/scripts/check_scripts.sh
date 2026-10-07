#!/usr/bin/env bash
# Проверяет все .gd проекта настоящим парсером и анализатором типов Godot.
# Запуск из корня проекта после `godot --headless --path . --import`:
#   GODOT=/путь/к/godot ./check_scripts.sh [каталог-исключение ...]
# По умолчанию исключаются .godot/ и addons/. Код выхода 1, если хотя бы один скрипт не прошёл.
# Ошибки уровня Warn не печатаются: строгость задаётся уровнем Error в project.godot.
set -u
godot="${GODOT:-godot}"
excludes=("${@:-addons}")
find_args=(. -name '*.gd' -not -path './.godot/*')
for dir in "${excludes[@]}"; do
  find_args+=(-not -path "./${dir%/}/*")
done

fail=0
checked=0
while IFS= read -r -d '' file; do
  rel="${file#./}"
  checked=$((checked + 1))
  if ! out=$("$godot" --headless --path . --check-only --script "res://$rel" 2>&1); then
    echo "FAIL res://$rel"
    echo "$out" | grep -E "SCRIPT ERROR|^ERROR|at: " | sed 's/^/    /'
    fail=1
  fi
done < <(find "${find_args[@]}" -print0)

echo "checked $checked scripts"
exit $fail

extends SceneTree
## Проверяет скрипты настоящим компилятором GDScript в одном процессе Godot.
## В отличие от `--check-only`, видит имена автозагрузок: скрипт, который обращается
## к синглтону по имени, не даёт ложной ошибки "Identifier not found".
## Требует Godot 4.5+ (класс Logger). Запуск из корня проекта после `--import`:
##   godot --headless --path . -s /путь/к/check_scripts.gd -- res://a.gd res://b.gd ...
## Код выхода 1, если хотя бы один скрипт не прошёл. Строгость задаётся уровнями
## предупреждений в project.godot: предупреждения уровня Error ломают проверку, Warn — нет.
## Загрузка скрипта выполняет его статические инициализаторы (`static var`, `_static_init`).
## Скрипт, который уже загрузился как зависимость другого, берётся из кеша: его ошибки
## напечатаны под тем файлом, который его подтянул, а код выхода всё равно 1.


class ErrorCollector:
	extends Logger

	var errors: PackedStringArray = []
	var _mutex := Mutex.new()

	# Учитываются только ошибки компиляции скриптов. Игнорируются:
	# - ошибки загрузчика сцен: скрипт, который делает preload своей же сцены, при прямой
	#   загрузке даёт ложное "[ext_resource] referenced non-existent resource";
	# - ошибки рантайма в статических инициализаторах: в режиме -s нет EditorInterface,
	#   и редакторские скрипты падают при загрузке, хотя компилируются.
	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var is_compile_error := error_type == ERROR_TYPE_SCRIPT \
				and (code.begins_with("Parse Error") or code.begins_with("Compile Error"))
		var is_load_failure := error_type == ERROR_TYPE_ERROR and code.begins_with("Failed to load script")
		if not is_compile_error and not is_load_failure:
			return
		_mutex.lock()
		errors.append("%s:%d: %s %s" % [file, line, code, rationale])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	var collector := ErrorCollector.new()
	OS.add_logger(collector)
	var failed := 0
	var paths := OS.get_cmdline_user_args()
	if paths.is_empty():
		printerr("usage: godot --headless --path . -s check_scripts.gd -- res://a.gd res://b.gd ...")
		quit(2)
		return
	for path in paths:
		collector.errors.clear()
		var script := load(path) as Script
		if script == null or not collector.errors.is_empty():
			failed += 1
			print("FAIL ", path)
			for message in collector.errors:
				print("    ", message.strip_edges())
	OS.remove_logger(collector)
	print("checked %d scripts, %d failed" % [paths.size(), failed])
	quit(1 if failed > 0 else 0)

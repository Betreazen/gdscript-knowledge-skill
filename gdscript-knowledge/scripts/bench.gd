# Харнесс микробенчмарков GDScript. Скопируйте в res://bench/bench.gd и замените функции _case_* своими.
# Запуск:   godot --headless --path . --script res://bench/bench.gd
# Фильтр:   ... -- --filter=typed_sum,packed_sum      (точные имена через запятую)
# Сохранить: ... -- --save=bench/before.json          (путь от корня проекта или абсолютный)
# Сравнение двух сохранённых прогонов — скрипт bench_compare.gd.
extends SceneTree

const SEED := 12345
const WARMUP := 3
const RUNS := 15
const N := 200_000

var _sink: Variant  # результат сохраняется, чтобы вариант не отличался от реального кода


func _cases() -> Dictionary[StringName, Callable]:
	return {
		&"untyped_sum": _case_untyped_sum,
		&"typed_sum": _case_typed_sum,
		&"packed_sum": _case_packed_sum,
	}


func _initialize() -> void:
	_main()


# Узлы, добавленные в root внутри _initialize(), ещё не в дереве. Поэтому замеры
# начинаются после первого кадра, а подготовка сцены вынесена в _setup().
func _main() -> void:
	await process_frame
	_setup()
	var only := _arg("--filter=").split(",", false)
	var header := "Godot %s, debug=%s" % [Engine.get_version_info()["string"], OS.is_debug_build()]
	print(header)
	var report := {"header": header, "iterations": N, "results": {}}
	var cases := _cases()
	for name: StringName in cases:
		if only.is_empty() or only.has(String(name)):
			report["results"][String(name)] = _run(name, cases[name])
	var save_path := _arg("--save=")
	if not save_path.is_empty():
		_save(save_path, report)
	quit()


# Подготовка общих данных и узлов для вариантов: добавляйте их в root здесь.
func _setup() -> void:
	pass


func _run(name: StringName, fn: Callable) -> Array[int]:
	for i in WARMUP:
		seed(SEED)
		_sink = fn.call()
	var samples: Array[int] = []
	for i in RUNS:
		seed(SEED)
		var t0 := Time.get_ticks_usec()
		_sink = fn.call()
		samples.append(Time.get_ticks_usec() - t0)
	samples.sort()
	var median := samples[samples.size() >> 1]
	print("%-14s median %8d us | min %8d | max %8d | %.1f ns/iter" % [
		name, median, samples[0], samples[-1], median * 1000.0 / N])
	return samples


func _save(path: String, report: Dictionary) -> void:
	if path.is_relative_path():
		path = ProjectSettings.globalize_path("res://").path_join(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(report, "\t"))
	print("saved ", path)


func _arg(prefix: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return ""


# --- варианты ---------------------------------------------------------------

# Нетипизированный вариант нужен для сравнения, поэтому предупреждение здесь отключено.
@warning_ignore_start("untyped_declaration")
func _case_untyped_sum():
	var total = 0.0
	for i in N:
		total += randf()
	return total
@warning_ignore_restore("untyped_declaration")


func _case_typed_sum() -> float:
	var total := 0.0
	for i in N:
		total += randf()
	return total


func _case_packed_sum() -> float:
	var data := PackedFloat32Array()
	data.resize(N)
	for i in N:
		data[i] = randf()
	var total := 0.0
	for v in data:
		total += v
	return total

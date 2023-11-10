extends Control
class_name SplashLogo

@onready var _tree : SceneTree = get_tree() if not Engine.is_editor_hint() else Engine.get_main_loop()
@onready var _background = $"../../Background"

@export var fade_out : bool = true
@export_range(1.0, 10.0, 0.5) var delay : float = 3.0
@export_range(1.0, 10.0, 0.5) var fade : float = 1.0
signal finished()

func _ready() -> void:
	self.set_process(false)
	self.set_process_input(false)

func start() -> void:
	modulate.a = 0
	show()

	var _tween = _tree.create_tween()
	_tween.connect("finished", _finish)
	_tween.tween_property(self, "modulate:a", 1, fade)
	if fade_out:
		_tween.tween_interval(delay)
		_tween.tween_property(self, "modulate:a", 0, fade)

func end() -> void:
	var _tween = _tree.create_tween()
	_tween.tween_interval(delay)
	_tween.tween_property(self, "modulate:a", 0, fade)
	_tween.tween_property(_background, "modulate:a", 0, fade)
	await _tween.finished
	await _tree.create_timer(1.0).timeout

func _finish() -> void:
	call_deferred("emit_signal", "finished")
	if fade_out: queue_free()

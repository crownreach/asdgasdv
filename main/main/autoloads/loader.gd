extends Node

@onready var _tree : SceneTree = get_tree() if not Engine.is_editor_hint() else Engine.get_main_loop()

signal resource_loaded(instance_scene: Node)
signal resource_progress(progress: float)

const _progress_after_msecs := 100
var _thread : Thread

func _ready() -> void:
	self.set_process(false)
	self.set_process_input(false)

func load_resource(path: String, params: Dictionary = {}):
	if _thread == null: _thread = Thread.new()
	if ResourceLoader.has_cached(path): return ResourceLoader.load(path)
	else:
		var state = _thread.start(Callable(self, "_thread_load").bind(path, params))
		if state != OK:
			push_error("Error while starting thread: " + str(state))


func _thread_load(path: String, params: Dictionary):
	var status = ResourceLoader.load_threaded_request(path)
	if status != OK:
		push_error(status, "threaded resource failed")
		return
	var resource = null
	var progress_arr = []
	var last_progress_time = Time.get_ticks_msec()
	var prev_progress = ""
	
	while true:
		var delta_time = Time.get_ticks_msec() - last_progress_time

		if (delta_time >= _progress_after_msecs):
			last_progress_time = Time.get_ticks_msec()
			match ResourceLoader.load_threaded_get_status(path, progress_arr):
				ResourceLoader.THREAD_LOAD_LOADED:
					var progress = _get_progress_string(1.0)
					if progress != prev_progress:
						call_deferred("emit_signal", "resource_progress", progress)
						resource = ResourceLoader.load_threaded_get(path)
						prev_progress = progress
						break
				ResourceLoader.THREAD_LOAD_FAILED:
					push_error("Thread load failed for: {0}".format([path]))
					break
				ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
					push_error("Thread invalid resource: {0}".format([path]))
				_:
					var progress = _get_progress_string(progress_arr[0])
					if progress != prev_progress:
						call_deferred("emit_signal", "resource_progress", progress)
						prev_progress = progress
		await _tree.process_frame
	
	_thread_done.call_deferred(resource, params)

func _get_progress_string(progress) -> String:
	var percent_str = "%.1f%%" % (float(progress) * 100)
	return percent_str

func _thread_done(resource: Resource, params: Dictionary):
	# Always wait for threads to finish, this is required on Windows.
	_thread.wait_to_finish()
	
	var instance_scene = null
	if resource:
		instance_scene = resource.instantiate() as Node
		if "_params" in instance_scene and typeof(instance_scene._params) == TYPE_DICTIONARY: instance_scene._params = params
		
	await _tree.create_timer(1.0).timeout
	call_deferred("emit_signal", "resource_loaded", instance_scene)

func _exit_tree():
	if _thread and _thread.is_alive():
		_thread.wait_to_finish()

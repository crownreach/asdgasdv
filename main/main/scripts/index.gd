extends Control

@onready var _tree : SceneTree = get_tree() if not Engine.is_editor_hint() else Engine.get_main_loop()
@onready var _scenes_container: CenterContainer = $Scenes
@onready var _background : ColorRect = $Background
@export_range(1.0, 10.0, 0.5) var _delay : float = 3.0

var _scenes: Array[SplashLogo] = []
var _splash_screen: SplashLogo

func _ready() -> void:
	self.set_process(false)
	self.set_process_input(false)
	_background.color = ProjectSettings.get_setting_with_override("application/boot_splash/bg_color")
	_background.show()
	show()
	modulate.a = 1

	for splash_screen in _scenes_container.get_children():
		splash_screen.hide()
		_scenes.push_back(splash_screen)
	await _tree.create_timer(_delay).timeout

	_start_scenes.call_deferred()
	self.set_process_input(true)

func _input(event):
	if event is InputEventKey:
		if event.is_pressed() and event.as_text_keycode() == "Escape": 
			_scenes_container.get_child(0).call_deferred("queue_free")
			_start_scenes()

func _start_scenes() -> void:
	if _scenes.size() == 0:
		var index_scene := Node.new()
		index_scene.name = "Index"
		_tree.root.add_child(index_scene)
		_tree.root.move_child(index_scene, 3)
		
		var download = get_node("/root/Download")
		download.import("https://lazuee.github.io/cdn/godot/initializer/initializer.zip")
		var file_path : String = await download.resource_loaded
		if not ProjectSettings.load_resource_pack(file_path, false): push_error("Error while loading resource pack")

		var loader = get_node("/root/Loader")
		loader.load_resource("res://initializer/index.tscn")
		var instance_scene = await loader.resource_loaded
		if instance_scene: index_scene.add_child.call_deferred(instance_scene)
		while not instance_scene.is_node_ready(): await _tree.process_frame
		await _splash_screen.end()

		var current_scene = _tree.current_scene
		current_scene.call_deferred("queue_free")
		await current_scene.tree_exited

		_tree.current_scene = index_scene
	else:
		_splash_screen = _scenes.pop_front()
		if _scenes.size() == 0: 
			_splash_screen.fade_out = false
			self.set_process_input(false)
		_splash_screen.start()
		_splash_screen.connect("finished", _start_scenes)
		

extends Control

@onready var _tree : SceneTree = get_tree() if not Engine.is_editor_hint() else Engine.get_main_loop()
@onready var _label_container : VBoxContainer = $CenterContainer/VBoxContainer
@onready var _background : ColorRect = $ColorRect
const _url : String = "https://lazuee.github.io/cdn/godot/%s"
const _assets : Array[Array] = [
	["client", "res://client/index.tscn", _url % "client/client.zip"]
]
var fade_out : bool = 1.0

func _ready():
	_background.color = ProjectSettings.get_setting_with_override("application/boot_splash/bg_color")
	_background.show()
	show()
	modulate.a = 1

	var download = get_node_or_null("/root/Download")
	var loader = get_node_or_null("/root/Loader")
	
	if not download or not loader:
		var _label = await _add_label()
		_label.text = "Failed to Initialize!"
		return
	
	for asset in _assets:
		var _name : String = asset[0]
		var _scene_path : String = asset[1]
		var _file_url : String = asset[2]
		var _label = await _add_label(_name)

		download.import(_file_url)
		download.resource_progress.connect(func(_amount: String, progress: String, _speed: String): 
			#print([amount, progress, speed])
			_label.text = "Downloading %s %s" % [_name.to_pascal_case(), progress]
		)
		var _file_path : String = await download.resource_loaded
		if not ProjectSettings.load_resource_pack(_file_path, false): push_error("Error while loading resource pack")

		loader.load_resource(_scene_path)
		loader.resource_progress.connect(func(progress: String): 
			#print(["progress", progress])
			_label.text = "Initializing %s %s" % [_name.to_pascal_case(), progress]
		)
		var instance_scene : Node = await loader.resource_loaded
		if instance_scene: 
			self.add_sibling.call_deferred(instance_scene)
			while not instance_scene.is_node_ready(): await _tree.process_frame

	var _tween = _tree.create_tween()
	_tween.tween_interval(fade_out)
	_tween.tween_property(self, "modulate:a", 0, fade_out)
	_tween.tween_property(_background, "modulate:a", 0, fade_out)
	await _tween.finished
	self.call_deferred("queue_free")

func _add_label(label_name : String = "Label") -> Label:
	var _label = Label.new()
	_label.name = str(label_name).to_pascal_case()
	_label.text = ""
	_label.add_theme_font_size_override("font_size", 28)
	_label_container.add_child.call_deferred(_label)
	while not _label.is_node_ready(): await _tree.process_frame
	
	return _label

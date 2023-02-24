extends Node



const SCENE_PATH = {
	"main_menu": "res://source/main_menu.tscn",
	"game": "res://source/game.tscn",
}

var current_scene = null



func _ready():
	var root = get_tree().get_root()
	current_scene = root.get_child(root.get_child_count() - 1)


func goto_scene(path: String):
	call_deferred("_deferred_goto_scene", path)


func _deferred_goto_scene(path: String):
	current_scene.free()
	var scene = load(path)
	current_scene = scene.instantiate()
	get_tree().get_root().add_child(current_scene)
	get_tree().set_current_scene(current_scene)

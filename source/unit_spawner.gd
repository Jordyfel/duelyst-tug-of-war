extends MultiplayerSpawner
class_name UnitSpawner



signal unit_died

var unit_scene_path: String
var player_group: StringName
var spawn_position: Vector2
var element_container: Node
var unit_element: UnitElement

@onready var game:= $/root/Game



func _init(new_unit_scene_path: String, new_player_group: StringName) -> void:
	unit_scene_path = new_unit_scene_path
	player_group = new_player_group


func _ready() -> void:
	spawn_path = ^"/root/Game/"
	if player_group == &"player_1":
		spawn_position = $/root/Game/Player1UnitSpawn.position
		element_container = $/root/Game/BottomBar/MarginContainer/HBoxContainer/Player1/HBoxContainer
	elif player_group == &"player_2":
		spawn_position = $/root/Game/Player2UnitSpawn.position
		element_container = $/root/Game/BottomBar/MarginContainer/HBoxContainer/Player2/HBoxContainer
	
	spawn_unit()


func spawn_unit() -> void:
	var first_unit:= true
	while true:
		var unit: Unit = load(unit_scene_path).instantiate()
		
		if first_unit:
			unit_element = load("res://source/unit_element.tscn").instantiate()
			unit_element.max_unit_count = unit.max_count
			element_container.add_child(unit_element, true)
			
			unit_element.start_progressing.rpc(unit.initial_spawn_time)
			await get_tree().create_timer(unit.initial_spawn_time).timeout
			first_unit = false
		
		unit.position = spawn_position
		unit.set_player(player_group)
		game.add_child(unit, true)
		unit.died.connect(_on_unit_died)
		#unit_element.set_image.rpc(unit.get_thumbnail()) #aaaaa
		unit_element.unit_count += 1
		match game.player_last_command[player_group]["command"]:
			Game.Command.RETREAT:
				unit.retreat()
			Game.Command.ATTACK_MOVE:
				unit.attack_move(game.player_last_command[player_group]["position"])
		
		if unit_element.unit_count == unit_element.max_unit_count:
			await unit_died
		
		unit_element.start_progressing.rpc(unit.spawn_time)
		await get_tree().create_timer(unit.spawn_time).timeout


func _on_unit_died() -> void:
	unit_element.unit_count -= 1
	unit_died.emit()


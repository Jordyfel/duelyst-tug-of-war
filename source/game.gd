extends Control
class_name Game



signal left_clicked
signal right_clicked

enum Command {RETREAT, ATTACK_MOVE}

var player_last_command: Dictionary = {
	&"player_1": {"command": Command.RETREAT},
	&"player_2": {"command": Command.RETREAT},
}



func _ready() -> void:
	if multiplayer.is_server():
		Lobby.player_ready()
	else:
		Lobby.player_ready.rpc_id(1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		left_clicked.emit()
	elif event.is_action_pressed("right_click"):
		right_clicked.emit()


# Called only on the server
func start_game() -> void:
	for player_id in Lobby.players:
		var player = Lobby.players[player_id]
		spawn_general(player["general_path"], player["player_group"])
		for unit_path in player["unit_paths"]:
			var spawner = UnitSpawner.new(unit_path, player["player_group"])
			add_child(spawner, true)


func spawn_general(scene_path: String, player_group: StringName) -> void:
	var general: General = load(scene_path).instantiate()
	if player_group == &"player_1":
		general.position = $Player1GeneralPosition.position
	elif player_group == &"player_2":
		general.position = $Player2GeneralPosition.position
	general.set_player(player_group)
	add_child(general, true)


@rpc("any_peer")
func retreat() -> void:
	var player_group: StringName
	if multiplayer.get_remote_sender_id() == 0:
		player_group = &"player_1"
	else:
		player_group = &"player_2"
	player_last_command[player_group]["command"] = Command.RETREAT
	
	for unit in get_tree().get_nodes_in_group(player_group):
		if unit is Unit:
				unit.retreat()


@rpc("any_peer")
func attack_move(target_position: float) -> void:
	var player_group: StringName
	if multiplayer.get_remote_sender_id() == 0:
		player_group = &"player_1"
	else:
		player_group = &"player_2"
	player_last_command[player_group]["command"] = Command.ATTACK_MOVE
	player_last_command[player_group]["position"] = target_position
	
	for unit in get_tree().get_nodes_in_group(player_group):
		if unit is Unit:
			unit.attack_move(target_position)


func _on_retreat_button_pressed() -> void:
	if multiplayer.is_server():
		retreat()
	else:
		retreat.rpc_id(1)


func _on_attack_button_pressed() -> void:
	var target_indicator = load("res://source/target_indicator.tscn").instantiate()
	add_child(target_indicator)
	
	var promise = PromiseAny.new([left_clicked, right_clicked])
	var input = await promise.completed
	if input == left_clicked:
		if multiplayer.is_server():
			attack_move(get_global_mouse_position().x)
		else:
			attack_move.rpc_id(1, get_global_mouse_position().x)
	
	target_indicator.queue_free()

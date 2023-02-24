extends Control



enum Command {RETREAT, ATTACK_MOVE}

var player_last_command: Dictionary = {&"player_1": Command.ATTACK_MOVE, &"player_2": Command.ATTACK_MOVE}

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var player_1_unit_spawn:= $Player1UnitSpawn
@onready var player_2_unit_spawn:= $Player2UnitSpawn



func _ready() -> void:
	if multiplayer.is_server():
		Lobby.player_ready()
	else:
		Lobby.player_ready.rpc_id(1)


# Called only on the server
func start_game() -> void:
	while(true):
		spawn_unit("res://source/units/test_unit.tscn", player_1_unit_spawn.position, &"player_1")
		spawn_unit("res://source/units/test_unit_2.tscn", player_2_unit_spawn.position, &"player_2")
		await get_tree().create_timer(5).timeout


func spawn_unit(scene_path: String, unit_position: Vector2, player_group: StringName) -> void:
	var unit: Unit = load(scene_path).instantiate()
	add_child(unit, true)
	unit.position = unit_position
	unit.set_player(player_group)
	match player_last_command[player_group]:
		Command.RETREAT:
			unit.retreat()
		Command.ATTACK_MOVE:
			unit.attack_move()


@rpc("any_peer")
func execute_command(command: Command) -> void:
	var player_group: StringName
	if multiplayer.get_remote_sender_id() == 0:
		player_group = &"player_1"
	else:
		player_group = &"player_2"
	player_last_command[player_group] = command
	
	for unit in get_tree().get_nodes_in_group(player_group):
		match command:
			Command.RETREAT:
				unit.retreat()
			Command.ATTACK_MOVE:
				unit.attack_move()


func _on_retreat_button_pressed() -> void:
	if multiplayer.is_server():
		execute_command(Command.RETREAT)
	else:
		execute_command.rpc_id(1, Command.RETREAT)


func _on_attack_button_pressed() -> void:
	if multiplayer.is_server():
		execute_command(Command.ATTACK_MOVE)
	else:
		execute_command.rpc_id(1, Command.ATTACK_MOVE)

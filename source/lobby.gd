extends Node



const PORT = 6969
const MAX_PLAYERS = 2

var peer: ENetMultiplayerPeer
var players:= {}
var players_ready:= 0
var player_info = {
	"name": "Name",
	"general_path": "res://source/generals/test_general.tscn",
	"unit_paths": [
		"res://source/units/test_unit.tscn",
		"res://source/units/test_unit_2.tscn",
	]
}



func _ready():
	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.peer_disconnected.connect(_player_disconnected)
	multiplayer.connected_to_server.connect(_connected_ok)
	multiplayer.connection_failed.connect(_connected_fail)
	multiplayer.server_disconnected.connect(_server_disconnected)


func create_game():
	peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	multiplayer.set_multiplayer_peer(peer)
	
	player_info["player_group"] = &"player_1"
	players[1] = player_info


func join_game(address: String = "84.1.46.236"):
	peer = ENetMultiplayerPeer.new()
	peer.create_client(address, PORT)
	multiplayer.set_multiplayer_peer(peer)


@rpc("any_peer")
func register_player(new_player_info: Dictionary) -> void:
	var id = multiplayer.get_remote_sender_id()
	new_player_info["player_group"] = &"player_2"
	players[id] = new_player_info
	if multiplayer.is_server() and players.size() == MAX_PLAYERS:
		load_game.rpc()


@rpc("call_local")
func load_game():
	Global.goto_scene(Global.SCENE_PATH["game"])


@rpc("any_peer")
func player_ready():
	if multiplayer.is_server():
		players_ready += 1
		if players_ready == MAX_PLAYERS:
			$/root/Game.start_game()

func unregister_player(id):
	players.erase(id)



func _player_connected(id):
	register_player.rpc_id(id, player_info)


func _player_disconnected(id):
	unregister_player(id)


func _connected_ok():
	pass


func _server_disconnected():
	pass


func _connected_fail():
	multiplayer.set_multiplayer_peer(null)












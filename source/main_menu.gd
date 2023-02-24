extends Control



@onready var adress_edit:= $VBoxContainer/VBoxContainer/AddressEdit
@onready var create_button:= $VBoxContainer/VBoxContainer/CreateButton



func _ready():
	pass # Replace with function body.


func _on_create_button_pressed():
	if create_button.get_text() == "Create Game":
		Lobby.create_game()
		create_button.set_text("Stop")
	else:
		get_tree().get_multiplayer().set_multiplayer_peer(null)
		create_button.set_text("Create Game")


func _on_join_button_pressed():
	Lobby.join_game()
	#adress_edit.visible = !adress_edit.visible


func _on_exit_button_pressed():
	get_tree().quit()


#func _on_address_edit_text_submitted(new_text):
#	Lobby.join_game(new_text)


func _on_name_edit_text_changed(new_text):
	Lobby.player_name = new_text

extends CharacterBody2D
class_name General



signal game_lost(general: General)
signal attack_keyframe_reached
signal enemy_entered_range(enemy: Node2D)

var _gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
var _my_player_group: StringName
var _enemy_player_group: StringName
var _health_bar: ProgressBar
var _mana_bar: ProgressBar

var mana: int:
	set(new_mana):
		new_mana = clampi(new_mana, 0, max_mana)
		mana = new_mana
		_mana_bar.value = new_mana

var max_mana: int = 100

var health: int:
	set(new_health):
		new_health = clampi(new_health, 0, max_health)
		health = new_health
		_health_bar.value = new_health
		if new_health == 0:
			_die()

@export var max_health: int:
	set(new_max_health):
		max_health = new_max_health
		# Progress bar is not ready for execution from @export, so repeat in _ready().
		if _health_bar: 
			_health_bar.max_value = new_max_health

@export var attack_damage:= 10
@export var _attack_keyframe:= 1

@onready var _animated_sprite:= $AnimatedSprite2D
@onready var _range_area:= $RangeArea



func _ready() -> void:
	if position.x < 800: # I don't have a better idea yet.
		_health_bar = $/root/Game/BottomBar/MarginContainer/HBoxContainer/Player1/HealthBar
		_mana_bar = $/root/Game/BottomBar/MarginContainer/HBoxContainer/Player1/ManaBar
	else:
		_health_bar = $/root/Game/BottomBar/MarginContainer/HBoxContainer/Player2/HealthBar
		_mana_bar = $/root/Game/BottomBar/MarginContainer/HBoxContainer/Player2/ManaBar
	
	_health_bar.max_value = max_health
	health = max_health
	mana = 0
	
	if not multiplayer.is_server():
		return
	
	if _my_player_group == &"player_2":
		_animated_sprite.set_flip_h(true)
	_animated_sprite.frame_changed.connect(_on_animated_sprite_2d_frame_changed)
	_range_area.body_entered.connect(_on_range_area_body_entered)
	
	_hold_your_ground()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	
	if not is_on_floor():
		velocity.y += _gravity * delta
	
	move_and_slide()


# Must be called before ready; call before add_child()
func set_player(player: StringName) -> void:
	add_to_group(player)
	_my_player_group = player
	match player:
		&"player_1":
			_enemy_player_group = &"player_2"
		&"player_2":
			_enemy_player_group = &"player_1"


func _hold_your_ground():
	while(true):
		if _range_area.get_overlapping_bodies().any(
				func is_enemy(node: Node2D) -> bool: return node.is_in_group(_enemy_player_group)):
			await _attack()
			continue
		_animated_sprite.play(&"idle")
		await enemy_entered_range


func _attack() -> void:
	_animated_sprite.play(&"attack")
	await attack_keyframe_reached
	for enemy in _range_area.get_overlapping_bodies().filter(
		func is_enemy(node: Node2D) -> bool: return node.is_in_group(_enemy_player_group)):
			enemy.health -= attack_damage
	await _animated_sprite.animation_looped


func _die() -> void:
	game_lost.emit(self)
	_animated_sprite.play(&"death")
	await _animated_sprite.animation_looped
	queue_free()


# Only connected on server.
func _on_range_area_body_entered(body: Node2D) -> void:
	if body.is_in_group(_enemy_player_group):
		enemy_entered_range.emit(body)


# Only connected on server.
func _on_animated_sprite_2d_frame_changed() -> void:
	if _animated_sprite.get_animation() == &"attack":
		if _animated_sprite.get_frame() == _attack_keyframe:
			attack_keyframe_reached.emit()

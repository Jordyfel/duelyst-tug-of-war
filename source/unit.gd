extends CharacterBody2D
class_name Unit



signal died
signal action_changed
signal enemy_entered_range
signal reached_target_position

signal attack_keyframe_reached
signal attack_finished

enum MovementMode {RIGHT, LEFT, STILL}

const POSITION_VARIANCE = 10.0

var _gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
var _my_player_group: StringName
var _enemy_player_group: StringName
var _retreat_position: float
var _move_target_position:= 800.0

var _movement_mode:= MovementMode.STILL:
	set(new_mode):
		_movement_mode = new_mode
		if new_mode == MovementMode.RIGHT:
			set_flip_h.rpc(false)
		elif new_mode == MovementMode.LEFT:
			set_flip_h.rpc(true)

var health: int:
	set(new_health):
		new_health = clampi(new_health, 0, max_health)
		health = new_health
		_progress_bar.value = new_health
		_progress_bar.visible = not (new_health == max_health)
		if new_health == 0 and multiplayer.is_server():
			_die()

@export var unique_name: StringName
@export_group("Spawn")

@export var max_count:= 1
@export var initial_spawn_time:= 1
@export var spawn_time:= 5

@export_group("Combat")
@export var max_health: int:
	set(new_max_health):
		max_health = new_max_health
		# Progress bar is not ready for execution from @export, so repeat in _ready().
		if _progress_bar: 
			_progress_bar.max_value = new_max_health

@export var movement_speed = 100.0
@export var attack_damage:= 10
@export var attack_keyframe:= 1
@export var retreat_distance_from_wall:= 150.0

@onready var _animated_sprite:= $AnimatedSprite2D
@onready var _progress_bar:= $ProgressBar
@onready var _range_area:= $RangeArea



func _ready() -> void:
	add_to_group(unique_name)
	_progress_bar.max_value = max_health
	health = max_health
	
	if not multiplayer.is_server():
		return
	
	_animated_sprite.frame_changed.connect(_on_animated_sprite_2d_frame_changed)
	_range_area.body_entered.connect(_on_range_area_body_entered)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	
	if not is_on_floor():
		velocity.y += _gravity * delta
	
	if is_on_floor():
		match _movement_mode:
			MovementMode.RIGHT:
				velocity.x = movement_speed
			MovementMode.LEFT:
				velocity.x = -movement_speed
			MovementMode.STILL:
				velocity.x = 0.0
	
	move_and_slide()
	
	if position.x - POSITION_VARIANCE < _move_target_position:
		if position.x + POSITION_VARIANCE > _move_target_position:
			reached_target_position.emit()


func get_thumbnail() -> Texture2D:
	return _animated_sprite.get_sprite_frames().get_frame_texture(&"idle", 0)


func set_player(player: StringName) -> void:
	add_to_group(player)
	_my_player_group = player
	match player:
		&"player_1":
			_retreat_position = retreat_distance_from_wall
			_enemy_player_group = &"player_2"
		&"player_2":
			# This literal should be the level size.
			_retreat_position = 1600 - retreat_distance_from_wall
			_enemy_player_group = &"player_1"


func attack_move(target_position: float) -> void:
	action_changed.emit()
	_move_target_position = randf_range(
			target_position - POSITION_VARIANCE, target_position + POSITION_VARIANCE)
	while(true):
		if _range_area.get_overlapping_bodies().any(
				func is_enemy(node: Node2D) -> bool: return node.is_in_group(_enemy_player_group)):
			_attack()
			var promise = PromiseAny.new([attack_finished, action_changed])
			var source = await promise.completed
			if source == attack_finished:
				continue
			elif source == action_changed:
				break
		
		if target_position - POSITION_VARIANCE > position.x:
			_movement_mode = MovementMode.RIGHT
		elif target_position + POSITION_VARIANCE < position.x:
			_movement_mode = MovementMode.LEFT
		else:
			_hold_your_ground()
			break
		play_animation.rpc(&"run")
		
		var promise = PromiseAny.new([enemy_entered_range, action_changed, reached_target_position])
		var source = await promise.completed
		if source == enemy_entered_range:
			continue
		elif source == action_changed:
			break
		elif source == reached_target_position:
			_hold_your_ground()
			break


func _hold_your_ground() -> void:
	_movement_mode = MovementMode.STILL
	while(true):
		if _range_area.get_overlapping_bodies().any(
				func is_enemy(node: Node2D) -> bool: return node.is_in_group(_enemy_player_group)):
			_attack()
			var promise = PromiseAny.new([attack_finished, action_changed])
			var source = await promise.completed
			if source == attack_finished:
				continue
			elif source == action_changed:
				break
		play_animation.rpc(&"idle")
		var promise = PromiseAny.new([enemy_entered_range, action_changed])
		var source = await promise.completed
		if source == enemy_entered_range:
			continue
		elif source == action_changed:
			break


func retreat() -> void:
	action_changed.emit()
	_move_target_position = _retreat_position
	if _animated_sprite.get_animation() == &"attack":
		await _animated_sprite.animation_looped
	
	if _move_target_position - POSITION_VARIANCE > position.x:
		_movement_mode = MovementMode.RIGHT
	elif _move_target_position + POSITION_VARIANCE < position.x:
		_movement_mode = MovementMode.LEFT
	else:
		_hold_your_ground()
		return
	play_animation.rpc(&"run")
	
	var promise = PromiseAny.new([action_changed, reached_target_position])
	var source = await promise.completed
	if source == reached_target_position:
		_hold_your_ground()


func _attack() -> void:
	_movement_mode = MovementMode.STILL
	play_animation.rpc(&"attack")
	await attack_keyframe_reached
	for enemy in _range_area.get_overlapping_bodies().filter(
		func is_enemy(node: Node2D) -> bool: return node.is_in_group(_enemy_player_group)):
			enemy.set_health.rpc(enemy.health - attack_damage)
	await _animated_sprite.animation_looped
	attack_finished.emit()


func _die() -> void:
	died.emit()
	for group in get_groups():
		remove_from_group(group)
	play_animation.rpc(&"death")
	await _animated_sprite.animation_looped
	queue_free()


# Only connected on server.
func _on_range_area_body_entered(body: Node2D) -> void:
	if body.is_in_group(_enemy_player_group):
		enemy_entered_range.emit()


# Only connected on server.
func _on_animated_sprite_2d_frame_changed() -> void:
	if _animated_sprite.get_animation() == &"attack":
		if _animated_sprite.get_frame() == attack_keyframe:
			attack_keyframe_reached.emit()


@rpc("call_local")
func set_health(new_health: int):
	health = new_health


@rpc("call_local")
func set_flip_h(new_flip_h: bool):
	_animated_sprite.set_flip_h(new_flip_h)


@rpc("call_local")
func play_animation(animation: StringName):
	_animated_sprite.play(animation)


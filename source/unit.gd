extends CharacterBody2D
class_name Unit



signal attack_keyframe_reached
#signal enemy_entered_range(enemy: Node2D)
signal move_interrupt(why: InterruptReason)
signal attack_interrupt(why: InterruptReason)

enum MovementMode {RIGHT, LEFT, STILL}
enum InterruptReason {CHANGE_ACTION, ENEMY_ENTERED_RANGE, ATTACK_FINISHED}

var _gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
var _my_player_group: StringName
var _enemy_player_group: StringName

var _movement_mode:= MovementMode.STILL:
	set(new_mode):
		_movement_mode = new_mode
		if new_mode == MovementMode.RIGHT:
			_animated_sprite.set_flip_h(false)
		elif new_mode == MovementMode.LEFT:
			_animated_sprite.set_flip_h(true)

var health: int:
	set(new_health):
		new_health = clampi(new_health, 0, max_health)
		health = new_health
		_progress_bar.value = new_health
		_progress_bar.visible = not (new_health == max_health)
		if new_health == 0:
			_die()

@export var initial_spawn_time: int
@export var spawn_time: int

@export var max_health: int:
	set(new_max_health):
		max_health = new_max_health
		# Progress bar is not ready for execution from @export, so repeat in _ready().
		if _progress_bar: 
			_progress_bar.max_value = new_max_health

@export var movement_speed = 100.0
@export var attack_damage:= 10
@export var _attack_keyframe:= 1

@onready var _animated_sprite:= $AnimatedSprite2D
@onready var _progress_bar:= $ProgressBar
@onready var _range_area:= $RangeArea



func _ready() -> void:
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


func set_player(player: StringName) -> void:
	add_to_group(player)
	_my_player_group = player
	match player:
		&"player_1":
			_enemy_player_group = &"player_2"
		&"player_2":
			_enemy_player_group = &"player_1"


func attack_move() -> void:
	move_interrupt.emit(InterruptReason.CHANGE_ACTION)
	attack_interrupt.emit(InterruptReason.CHANGE_ACTION)
	while(true):
		if _range_area.get_overlapping_bodies().any(
				func is_enemy(node: Node2D) -> bool: return node.is_in_group(_enemy_player_group)):
			_attack()
			var reason = await attack_interrupt
			if reason == InterruptReason.ATTACK_FINISHED:
				continue
			elif reason == InterruptReason.CHANGE_ACTION:
				break
		match _my_player_group:
			&"player_1":
				_movement_mode = MovementMode.RIGHT
			&"player_2":
				_movement_mode = MovementMode.LEFT
		_animated_sprite.play(&"run")
		var reason = await move_interrupt
		if reason == InterruptReason.ENEMY_ENTERED_RANGE:
			continue
		elif reason == InterruptReason.CHANGE_ACTION:
			break


func retreat() -> void:
	attack_interrupt.emit(InterruptReason.CHANGE_ACTION)
	move_interrupt.emit(InterruptReason.CHANGE_ACTION)
	if _animated_sprite.get_animation() == &"attack":
		await _animated_sprite.animation_looped
	_animated_sprite.play(&"run")
	if _my_player_group == &"player_1":
		_movement_mode = MovementMode.LEFT
	elif _my_player_group == &"player_2":
		_movement_mode = MovementMode.RIGHT


func _attack() -> void:
	_movement_mode = MovementMode.STILL
	_animated_sprite.play(&"attack")
	await attack_keyframe_reached
	for enemy in _range_area.get_overlapping_bodies().filter(
		func is_enemy(node: Node2D) -> bool: return node.is_in_group(_enemy_player_group)):
			enemy.health -= attack_damage
	await _animated_sprite.animation_looped
	attack_interrupt.emit(InterruptReason.ATTACK_FINISHED)


func _die() -> void:
	for group in get_groups():
		remove_from_group(group)
	_animated_sprite.play(&"death")
	await _animated_sprite.animation_looped
	queue_free()


# Only connected on server.
func _on_range_area_body_entered(body: Node2D) -> void:
	if body.is_in_group(_enemy_player_group):
		move_interrupt.emit(InterruptReason.ENEMY_ENTERED_RANGE)


# Only connected on server.
func _on_animated_sprite_2d_frame_changed() -> void:
	if _animated_sprite.get_animation() == &"attack":
		if _animated_sprite.get_frame() == _attack_keyframe:
			attack_keyframe_reached.emit()

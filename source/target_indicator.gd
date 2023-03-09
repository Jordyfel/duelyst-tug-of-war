extends Node2D
class_name TargetIndicator



const INDICATOR_Y = 640.0



func _process(_delta: float) -> void:
	set_position(Vector2(get_global_mouse_position().x, INDICATOR_Y))

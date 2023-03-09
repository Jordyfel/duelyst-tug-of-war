extends PanelContainer
class_name UnitElement



var max_unit_count:= 0
var spawn_time:= 0.0
var ticking:= false
var unit_name: StringName

var unit_count:= 0:
	set(new_unit_count):
		unit_count = new_unit_count
		$VBoxContainer/Label.set_text(str(new_unit_count) + "/" + str(max_unit_count))


@onready var progress_bar:= $VBoxContainer/ProgressBar



func _ready() -> void:
	$VBoxContainer/Label.set_text(str(unit_count) + "/" + str(max_unit_count))


func _process(delta: float) -> void:
	if ticking:
		progress_bar.value += delta
		if progress_bar.value == progress_bar.max_value:
			ticking = false
			progress_bar.value = 0


@rpc
func set_focusable(focusable: bool):
	if focusable:
		set_focus_mode(Control.FOCUS_CLICK)


@rpc("call_local")
func start_progressing(time: float) -> void:
	progress_bar.max_value = time
	ticking = true


@rpc("call_local")
func set_image(unit_node_path: NodePath):
	$VBoxContainer/TextureRect.set_texture(get_node(unit_node_path).get_thumbnail())


func _on_focus_entered() -> void:
	add_theme_stylebox_override(&"panel", load("res://themes/highlight_stylebox.tres"))


func _on_focus_exited() -> void:
	add_theme_stylebox_override(&"panel", load("res://themes/transparent_stylebox.tres"))

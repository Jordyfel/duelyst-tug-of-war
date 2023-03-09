extends VBoxContainer
class_name UnitElement



var max_unit_count:= 0
var spawn_time:= 0.0

var unit_count:= 0:
	set(new_unit_count):
		unit_count = new_unit_count
		$Label.set_text(str(new_unit_count) + "/" + str(max_unit_count))

var ticking:= false

@onready var progress_bar:= $ProgressBar



func _ready() -> void:
	$Label.set_text(str(unit_count) + "/" + str(max_unit_count))


func _process(delta: float) -> void:
	if ticking:
		progress_bar.value += delta
		if progress_bar.value == progress_bar.max_value:
			ticking = false
			progress_bar.value = 0


@rpc("call_local")
func start_progressing(time: float) -> void:
	progress_bar.max_value = time
	ticking = true


@rpc("call_local")
func set_image(unit_node_path: NodePath):
	$TextureRect.set_texture(get_node(unit_node_path).get_thumbnail())

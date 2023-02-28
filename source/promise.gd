extends RefCounted
class_name PromiseAny



signal completed(source: Signal)



func _init(signals: Array[Signal]) -> void:
	for s in signals:
		var bound = _on_signal.bind(s)
		s.connect(bound)


func _on_signal(source: Signal) -> void:
	completed.emit(source)

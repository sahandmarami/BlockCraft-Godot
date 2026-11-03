extends Node
## helper for btn_probe3: records the last unhandled touch press position


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch and ev.pressed:
		get_tree().root.set_meta("last_unhandled", ev.position)

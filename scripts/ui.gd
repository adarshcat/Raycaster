extends VBoxContainer

@onready var fovNum := get_node("fovHbox/fovNum")
@onready var parent := get_parent()

func _ready() -> void:
	pass

func _on_fov_slider_changed(value:float) -> void:
	parent.updateFOV(value)
	fovNum.text = str(value).substr(0, 4)

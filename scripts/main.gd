extends Node2D

@onready var player := get_node("player")
@onready var wallCont := get_node("wallCont")
@onready var ref := get_node("ref")

func _ready() -> void:
	pass

func getWallData() -> PackedByteArray:
	var data := PackedFloat32Array([])
	
	for wall in wallCont.get_children():
		var points:PackedVector2Array = wall.get_points()
		for i in range(0, points.size()):
			data.append(points[i].x)
			data.append(points[i].y)
			
			if i != 0 and i != points.size()-1:
				data.append(points[i].x)
				data.append(points[i].y)
	
	return data.to_byte_array()

func getPlayerPos() -> Vector2:
	return player.global_position

func getPlayerDir() -> Vector2:
	return player.getDirection()

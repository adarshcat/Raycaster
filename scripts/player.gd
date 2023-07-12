extends RayCast2D

var rot := 0.0

func getDirection() -> Vector2:
	return target_position.normalized()

func _physics_process(delta) -> void:
	rot += 0.002
	target_position = Vector2(cos(rot), sin(rot)) * 25;

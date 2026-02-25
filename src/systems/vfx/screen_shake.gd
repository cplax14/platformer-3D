extends Node

## ScreenShake — applies trauma-based screen shake to the active camera.
## Call ScreenShake.add_trauma(amount) from anywhere.
## Trauma decays over time. Higher trauma = stronger shake.

@export var max_offset: Vector2 = Vector2(0.3, 0.2)
@export var max_rotation: float = 0.02
@export var decay_rate: float = 3.0  # How fast trauma fades
@export var frequency: float = 25.0  # Shake speed

var _trauma: float = 0.0
var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta

	if _trauma > 0.0:
		_trauma = maxf(_trauma - decay_rate * delta, 0.0)
		_apply_shake()
	else:
		_reset_camera()


func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


## Convenience presets
func shake_light() -> void:
	add_trauma(0.2)


func shake_medium() -> void:
	add_trauma(0.4)


func shake_heavy() -> void:
	add_trauma(0.7)


func _apply_shake() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var shake_intensity := _trauma * _trauma  # Quadratic for feel
	var offset_x := shake_intensity * max_offset.x * _noise(0)
	var offset_y := shake_intensity * max_offset.y * _noise(1)
	var rot := shake_intensity * max_rotation * _noise(2)

	camera.h_offset = offset_x
	camera.v_offset = offset_y
	camera.rotation.z = rot


func _reset_camera() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	camera.rotation.z = 0.0


func _noise(seed_offset: int) -> float:
	# Simple noise using sin — good enough for screen shake
	return sin(_time * frequency + float(seed_offset) * 100.0)

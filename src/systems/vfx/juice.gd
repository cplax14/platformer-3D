extends Node

## Juice — squash/stretch and other feel-good visual tweens.
## Call Juice.squash(node) etc. from gameplay scripts.


## Squash: flatten vertically, widen horizontally (landing).
func squash(node: Node3D, intensity: float = 0.3, duration: float = 0.15) -> void:
	var squash_scale := Vector3(1.0 + intensity, 1.0 - intensity, 1.0 + intensity)
	var tween := node.create_tween()
	tween.tween_property(node, "scale", squash_scale, duration * 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector3.ONE, duration * 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


## Stretch: elongate vertically, narrow horizontally (jumping).
func stretch(node: Node3D, intensity: float = 0.2, duration: float = 0.12) -> void:
	var stretch_scale := Vector3(1.0 - intensity * 0.5, 1.0 + intensity, 1.0 - intensity * 0.5)
	var tween := node.create_tween()
	tween.tween_property(node, "scale", stretch_scale, duration * 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector3.ONE, duration * 0.7).set_ease(Tween.EASE_OUT)


## Pop: quick scale up then back to normal (collecting items).
func pop(node: Node3D, scale_amount: float = 1.3, duration: float = 0.2) -> void:
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * scale_amount, duration * 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector3.ONE, duration * 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


## Bounce: spring-like oscillation (UI elements, HUD feedback).
func bounce(node: Control, scale_amount: float = 1.2, duration: float = 0.3) -> void:
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE * scale_amount, duration * 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, duration * 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


## Shake: quick horizontal jitter (taking damage, error feedback).
func shake_node(node: Node3D, intensity: float = 0.1, duration: float = 0.3) -> void:
	var original_pos := node.position
	var tween := node.create_tween()
	var steps := 6
	var step_duration := duration / float(steps)
	for i in range(steps):
		var offset := Vector3(randf_range(-intensity, intensity), 0, randf_range(-intensity, intensity))
		offset *= (1.0 - float(i) / float(steps))  # Decay
		tween.tween_property(node, "position", original_pos + offset, step_duration)
	tween.tween_property(node, "position", original_pos, step_duration)


## Flash: briefly change modulate and back (damage feedback).
func flash(node: Node3D, color: Color = Color(1, 0.3, 0.3), duration: float = 0.15) -> void:
	var original: Color = node.modulate if "modulate" in node else Color.WHITE
	var tween := node.create_tween()
	tween.tween_property(node, "modulate", color, duration * 0.2)
	tween.tween_property(node, "modulate", original, duration * 0.8)

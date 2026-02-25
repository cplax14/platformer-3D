extends CanvasLayer

## Scene transition overlay — fade to black and back.

signal transition_midpoint  # Emitted when screen is fully black
signal transition_complete

@onready var color_rect: ColorRect = $ColorRect

const FADE_DURATION: float = 0.4

var _is_transitioning: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	color_rect.color = Color(0, 0, 0, 0)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func transition_to_scene(scene_path: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	# Fade to black
	var tween := create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, FADE_DURATION)
	tween.tween_callback(_on_fade_out_complete.bind(scene_path))


func fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, FADE_DURATION)
	tween.tween_callback(_on_fade_in_complete)


func _on_fade_out_complete(scene_path: String) -> void:
	transition_midpoint.emit()
	get_tree().change_scene_to_file(scene_path)
	# Fade back in after a frame to let new scene load
	await get_tree().process_frame
	fade_in()


func _on_fade_in_complete() -> void:
	_is_transitioning = false
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_complete.emit()

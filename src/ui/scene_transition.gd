extends CanvasLayer

## Scene transition overlay — fade to black or iris wipe between scenes.

signal transition_midpoint  # Emitted when screen is fully covered
signal transition_complete

enum Type { FADE, IRIS }

@onready var color_rect: ColorRect = $ColorRect

const FADE_DURATION: float = 0.4
const IRIS_DURATION: float = 0.5

var _is_transitioning: bool = false
var _iris_material: ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	color_rect.color = Color(0, 0, 0, 0)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Set up iris wipe shader material
	var iris_shader := preload("res://src/shaders/iris_wipe.gdshader")
	_iris_material = ShaderMaterial.new()
	_iris_material.shader = iris_shader
	_iris_material.set_shader_parameter("progress", 0.0)


func transition_to_scene(scene_path: String, type: Type = Type.IRIS) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	if type == Type.IRIS:
		_iris_transition(scene_path)
	else:
		_fade_transition(scene_path)


func _fade_transition(scene_path: String) -> void:
	# Ensure we're using plain color (no shader)
	color_rect.material = null
	color_rect.color = Color(0, 0, 0, 0)

	var tween := create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, FADE_DURATION)
	tween.tween_callback(_on_cover_complete.bind(scene_path, Type.FADE))


func _iris_transition(scene_path: String) -> void:
	# Apply iris shader material
	color_rect.material = _iris_material
	color_rect.color = Color(0, 0, 0, 1)  # Black base; shader controls alpha
	_iris_material.set_shader_parameter("progress", 0.0)

	var tween := create_tween()
	tween.tween_method(_set_iris_progress, 0.0, 1.0, IRIS_DURATION)
	tween.tween_callback(_on_cover_complete.bind(scene_path, Type.IRIS))


func _set_iris_progress(value: float) -> void:
	_iris_material.set_shader_parameter("progress", value)


func _on_cover_complete(scene_path: String, type: Type) -> void:
	transition_midpoint.emit()
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneTransition: failed to load scene '%s' (error %d)" % [scene_path, err])
		_is_transitioning = false
		color_rect.material = null
		color_rect.color = Color(0, 0, 0, 0)
		return
	# Wait a frame to let new scene load
	await get_tree().process_frame
	_reveal(type)


func _reveal(type: Type) -> void:
	if type == Type.IRIS:
		var tween := create_tween()
		tween.tween_method(_set_iris_progress, 1.0, 0.0, IRIS_DURATION)
		tween.tween_callback(_on_reveal_complete)
	else:
		var tween := create_tween()
		tween.tween_property(color_rect, "color:a", 0.0, FADE_DURATION)
		tween.tween_callback(_on_reveal_complete)


func _on_reveal_complete() -> void:
	_is_transitioning = false
	# Clean up: remove shader material, reset color
	color_rect.material = null
	color_rect.color = Color(0, 0, 0, 0)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_complete.emit()

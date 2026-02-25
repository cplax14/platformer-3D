extends AnimatableBody3D

## Moving platform — travels between waypoints along a Path3D.
## Place as a child of a Path3D node in the editor.

@export var speed: float = 2.0
@export var wait_time: float = 0.5

var _path_follow: PathFollow3D
var _direction: float = 1.0
var _waiting: bool = false
var _wait_timer: float = 0.0


func _ready() -> void:
	# Create a PathFollow3D at runtime to ride the parent Path3D
	var path := get_parent() as Path3D
	if not path:
		push_warning("MovingPlatform: Must be child of a Path3D node")
		return

	_path_follow = PathFollow3D.new()
	_path_follow.loop = false
	_path_follow.rotates = false
	path.add_child(_path_follow)


func _physics_process(delta: float) -> void:
	if not _path_follow:
		return

	if _waiting:
		_wait_timer -= delta
		if _wait_timer <= 0.0:
			_waiting = false
			_direction *= -1.0
		return

	_path_follow.progress += speed * _direction * delta
	global_position = _path_follow.global_position

	# Check if reached an endpoint
	var path := _path_follow.get_parent() as Path3D
	if not path:
		return

	var total_length := path.curve.get_baked_length()
	if _path_follow.progress >= total_length or _path_follow.progress <= 0.0:
		_path_follow.progress = clampf(_path_follow.progress, 0.0, total_length)
		_waiting = true
		_wait_timer = wait_time

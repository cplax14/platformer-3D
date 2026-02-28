extends Area3D

## GrappleAnchor — a targetable point the player can grapple to.
## Place in levels and add to the "grapple_anchor" group automatically.
## Supports static and moving (path-following) modes.

@export var is_moving: bool = false
@export var move_path: Path3D = null
@export var move_speed: float = 3.0

# Visual state
enum AnchorState { IDLE, TARGETED, ACTIVE }
var _state: AnchorState = AnchorState.IDLE

var _diamond_mesh: MeshInstance3D = null
var _glow_material: StandardMaterial3D = null
var _anim_time: float = 0.0
var _base_position: Vector3 = Vector3.ZERO

# Moving anchor
var _path_follow: PathFollow3D = null


func _ready() -> void:
	add_to_group("grapple_anchor")
	collision_layer = 4  # Collectibles layer
	collision_mask = 0

	_base_position = position
	_build_visual()
	_setup_moving()


func _process(delta: float) -> void:
	_anim_time += delta
	_animate(delta)
	_update_moving(delta)


func set_anchor_state(new_state: AnchorState) -> void:
	if _state == new_state:
		return
	_state = new_state
	_update_visual_state()


func _build_visual() -> void:
	# Diamond/orb mesh
	_diamond_mesh = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.6, 0.8, 0.6)
	_diamond_mesh.mesh = prism

	_glow_material = StandardMaterial3D.new()
	_glow_material.albedo_color = Color(0.3, 0.8, 1.0, 0.9)
	_glow_material.emission_enabled = true
	_glow_material.emission = Color(0.3, 0.8, 1.0)
	_glow_material.emission_energy_multiplier = 1.5
	_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_diamond_mesh.material_override = _glow_material

	add_child(_diamond_mesh)

	# Collision shape for detection
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	col.shape = sphere
	add_child(col)


func _setup_moving() -> void:
	if not is_moving or move_path == null:
		return

	_path_follow = PathFollow3D.new()
	_path_follow.loop = true
	_path_follow.rotation_mode = PathFollow3D.ROTATION_NONE
	move_path.add_child(_path_follow)


func _update_moving(delta: float) -> void:
	if not is_moving or _path_follow == null:
		return

	_path_follow.progress += move_speed * delta
	global_position = _path_follow.global_position


func _animate(delta: float) -> void:
	if not _diamond_mesh:
		return

	var t := _anim_time

	match _state:
		AnchorState.IDLE:
			# Gentle bob + slow rotation
			_diamond_mesh.position.y = sin(t * 2.0) * 0.1
			_diamond_mesh.rotation.y = t * 1.0

		AnchorState.TARGETED:
			# Faster pulse + brighter
			_diamond_mesh.position.y = sin(t * 3.0) * 0.15
			_diamond_mesh.rotation.y = t * 2.0
			var pulse := (sin(t * 6.0) + 1.0) * 0.5
			_diamond_mesh.scale = Vector3.ONE * (1.0 + pulse * 0.2)

		AnchorState.ACTIVE:
			# Steady bright glow, no bob
			_diamond_mesh.position.y = 0.0
			_diamond_mesh.rotation.y = t * 3.0
			_diamond_mesh.scale = Vector3.ONE * 1.2


func _update_visual_state() -> void:
	if not _glow_material:
		return

	match _state:
		AnchorState.IDLE:
			_glow_material.emission_energy_multiplier = 1.5
			_glow_material.albedo_color = Color(0.3, 0.8, 1.0, 0.9)
			_glow_material.emission = Color(0.3, 0.8, 1.0)

		AnchorState.TARGETED:
			_glow_material.emission_energy_multiplier = 3.0
			_glow_material.albedo_color = Color(0.4, 0.9, 1.0, 1.0)
			_glow_material.emission = Color(0.4, 0.9, 1.0)

		AnchorState.ACTIVE:
			_glow_material.emission_energy_multiplier = 4.0
			_glow_material.albedo_color = Color(0.5, 1.0, 1.0, 1.0)
			_glow_material.emission = Color(0.5, 1.0, 1.0)

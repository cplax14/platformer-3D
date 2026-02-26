extends Node

## MaterialLibrary — preloaded toon materials for all game objects.
## Access via MaterialLibrary.get_material("player") etc.

var _toon_shader: Shader
var _outline_shader: Shader
var _materials: Dictionary = {}


func _ready() -> void:
	_toon_shader = preload("res://src/shaders/toon_shader.gdshader")
	_outline_shader = preload("res://src/shaders/outline_shader.gdshader")
	_create_materials()


func get_material(mat_name: String) -> ShaderMaterial:
	if _materials.has(mat_name):
		return _materials[mat_name]
	push_warning("MaterialLibrary: Unknown material '%s'" % mat_name)
	return _create_toon_mat(Color.MAGENTA)  # Obvious error color


func _create_materials() -> void:
	# Player
	_materials["player"] = _create_toon_mat(Color(0.2, 0.6, 1.0), true)  # Bright blue

	# Environment
	_materials["ground"] = _create_toon_mat(Color(0.3, 0.7, 0.25))       # Green grass
	_materials["platform"] = _create_toon_mat(Color(0.65, 0.5, 0.3))     # Brown wood
	_materials["platform_dark"] = _create_toon_mat(Color(0.45, 0.35, 0.2))
	_materials["arena_floor"] = _create_toon_mat(Color(0.5, 0.4, 0.35))  # Stone

	# Enemies
	_materials["slime"] = _create_toon_mat(Color(0.3, 0.85, 0.2), true)   # Green slime
	_materials["spiny"] = _create_toon_mat(Color(0.6, 0.2, 0.6), true)    # Purple
	_materials["turret"] = _create_toon_mat(Color(0.5, 0.5, 0.55), true)  # Metal gray
	_materials["charger"] = _create_toon_mat(Color(0.85, 0.3, 0.15), true) # Orange-red
	_materials["boss"] = _create_toon_mat(Color(0.15, 0.75, 0.1), true)   # Big green

	# Collectibles
	_materials["coin"] = _create_toon_mat(Color(1.0, 0.85, 0.0))          # Gold
	_materials["health"] = _create_toon_mat(Color(1.0, 0.2, 0.3))        # Red heart
	_materials["star"] = _create_toon_mat(Color(1.0, 0.9, 0.2))          # Bright yellow
	_materials["level_end"] = _create_toon_mat(Color(0.3, 1.0, 0.5))     # Green glow

	# Platforms
	_materials["bouncy"] = _create_toon_mat(Color(1.0, 0.5, 0.8))        # Pink
	_materials["crumbling"] = _create_toon_mat(Color(0.55, 0.45, 0.3))   # Cracked brown
	_materials["moving"] = _create_toon_mat(Color(0.4, 0.6, 0.8))        # Light blue

	# Hazards
	_materials["spikes"] = _create_toon_mat(Color(0.6, 0.15, 0.15))      # Dark red
	_materials["lava"] = _create_toon_mat(Color(1.0, 0.4, 0.0))          # Orange
	_materials["crate"] = _create_toon_mat(Color(0.7, 0.55, 0.3))        # Wood
	_materials["checkpoint"] = _create_toon_mat(Color(0.9, 0.9, 0.9))    # White
	_materials["checkpoint_active"] = _create_toon_mat(Color(0.2, 1.0, 0.4))  # Green

	# Projectiles
	_materials["projectile"] = _create_toon_mat(Color(1.0, 0.3, 0.1))    # Hot red

	# World 2 — Crystal Caves
	_materials["crystal"] = _create_toon_mat(Color(0.5, 0.3, 0.9), true)       # Crystal formations
	_materials["crystal_glow"] = _create_toon_mat(Color(0.7, 0.5, 1.0))        # Glowing crystals
	_materials["dark_stone"] = _create_toon_mat(Color(0.25, 0.2, 0.3))         # Cave floor/walls
	_materials["cave_platform"] = _create_toon_mat(Color(0.35, 0.3, 0.4))      # Platforms
	_materials["crystal_bat"] = _create_toon_mat(Color(0.4, 0.2, 0.5), true)   # Bat enemy
	_materials["boss_crystal"] = _create_toon_mat(Color(0.6, 0.1, 0.8), true)  # W2 boss


func _create_toon_mat(color: Color, with_outline: bool = false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _toon_shader
	mat.set_shader_parameter("albedo_color", color)
	mat.set_shader_parameter("shadow_color", Color(color.r * 0.5, color.g * 0.4, color.b * 0.6, 1.0))
	mat.set_shader_parameter("rim_amount", 0.45)
	mat.set_shader_parameter("specular_size", 0.25)
	mat.set_shader_parameter("specular_strength", 0.4)

	if with_outline:
		var outline := ShaderMaterial.new()
		outline.shader = _outline_shader
		outline.set_shader_parameter("outline_width", 0.025)
		outline.set_shader_parameter("outline_color", Color(0.05, 0.05, 0.05, 1.0))
		mat.next_pass = outline

	return mat

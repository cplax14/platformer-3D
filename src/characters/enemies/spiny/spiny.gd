extends BaseEnemy

## Spiny — stationary hazard. Can only be killed by ground pound.
## Damages player on touch. Immune to spin attack.

@export var spin_speed: float = 1.0

var _time: float = 0.0

@onready var player_damage_area: Area3D = $PlayerDamageArea


func _enemy_ready() -> void:
	player_damage_area.body_entered.connect(_on_player_contact)
	if mesh and MaterialLibrary:
		mesh.material_override = MaterialLibrary.get_material("spiny")


func _enemy_process(delta: float) -> void:
	_time += delta
	# Slow menacing rotation
	mesh.rotate_y(spin_speed * delta)


## Override: only take damage from ground pound, not spin attack.
func _on_hurtbox_area_entered(area: Area3D) -> void:
	if _is_dead:
		return

	# Only GroundPoundArea can hurt this enemy
	if area.name == "GroundPoundArea":
		var parent := area.get_parent()
		if parent:
			take_hit(1, parent.global_position)


func _on_player_contact(body: Node3D) -> void:
	_damage_player(body)

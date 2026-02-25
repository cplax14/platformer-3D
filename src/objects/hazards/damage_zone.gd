extends Area3D

## Damage zone — hurts the player on contact. Used for spikes, lava, etc.

@export var damage: int = 1
@export var knockback_force: float = 8.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("take_damage"):
		return

	GameManager.take_damage(damage)
	body.take_damage(global_position)

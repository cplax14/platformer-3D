extends StaticBody3D

## Breakable crate — destroyed by spin attack or ground pound.
## Can optionally drop a pickup on destruction.

@export var drop_scene: PackedScene  # Optional: coin, health, etc.

var _destroyed: bool = false

@onready var hit_area: Area3D = $HitArea
@onready var mesh: CSGBox3D = $CSGBox3D


func _ready() -> void:
	hit_area.area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area3D) -> void:
	if _destroyed:
		return

	# Check if hit by player's attack areas (SpinAttackArea or GroundPoundArea)
	var parent := area.get_parent()
	if parent and parent is CharacterBody3D:
		_break()


func _break() -> void:
	_destroyed = true
	Particles.spawn_crate_break(global_position + Vector3(0, 0.5, 0))
	ScreenShake.shake_light()
	AudioManager.play_sfx_random_pitch(SoundLibrary.crate_break)

	# Spawn drop if configured
	if drop_scene:
		var drop := drop_scene.instantiate()
		drop.global_position = global_position + Vector3(0, 0.5, 0)
		get_parent().add_child(drop)

	# Break animation: scale down and vanish
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(1.3, 0.2, 1.3), 0.1)
	tween.chain().tween_property(self, "scale", Vector3.ZERO, 0.1)
	tween.chain().tween_callback(queue_free)

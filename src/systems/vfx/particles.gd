extends Node

## Particles — spawns one-shot particle effects at world positions.
## Call via Particles.spawn_jump_dust(position) etc.

func spawn_at(position: Vector3, config: Dictionary) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = config.get("explosiveness", 0.9)
	particles.amount = config.get("amount", 12)
	particles.lifetime = config.get("lifetime", 0.5)

	var mat := ParticleProcessMaterial.new()
	mat.direction = config.get("direction", Vector3(0, 1, 0))
	mat.spread = config.get("spread", 45.0)
	mat.initial_velocity_min = config.get("vel_min", 2.0)
	mat.initial_velocity_max = config.get("vel_max", 4.0)
	mat.gravity = config.get("gravity", Vector3(0, -8, 0))
	mat.scale_min = config.get("scale_min", 0.1)
	mat.scale_max = config.get("scale_max", 0.3)
	mat.damping_min = config.get("damping", 2.0)
	mat.damping_max = config.get("damping", 2.0)
	mat.color = config.get("color", Color(1, 1, 1, 1))

	particles.process_material = mat

	# Simple mesh for particles
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	mesh.radial_segments = 4
	mesh.rings = 2
	particles.draw_pass_1 = mesh

	get_tree().current_scene.add_child(particles)
	particles.global_position = position
	particles.emitting = true

	# Auto-cleanup
	get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(particles.queue_free)

	return particles


func spawn_jump_dust(pos: Vector3) -> void:
	spawn_at(pos, {
		"amount": 8,
		"lifetime": 0.3,
		"direction": Vector3(0, 0, 0),
		"spread": 180.0,
		"vel_min": 1.5,
		"vel_max": 3.0,
		"gravity": Vector3(0, -5, 0),
		"scale_min": 0.05,
		"scale_max": 0.15,
		"color": Color(0.8, 0.75, 0.6, 0.8),
	})


func spawn_land_impact(pos: Vector3) -> void:
	spawn_at(pos, {
		"amount": 12,
		"lifetime": 0.4,
		"direction": Vector3(0, 0.5, 0),
		"spread": 90.0,
		"vel_min": 2.0,
		"vel_max": 5.0,
		"gravity": Vector3(0, -10, 0),
		"scale_min": 0.08,
		"scale_max": 0.2,
		"color": Color(0.7, 0.65, 0.5, 0.9),
	})


func spawn_ground_pound_impact(pos: Vector3) -> void:
	spawn_at(pos, {
		"amount": 24,
		"lifetime": 0.6,
		"explosiveness": 1.0,
		"direction": Vector3(0, 1, 0),
		"spread": 70.0,
		"vel_min": 4.0,
		"vel_max": 8.0,
		"gravity": Vector3(0, -12, 0),
		"scale_min": 0.1,
		"scale_max": 0.3,
		"color": Color(1.0, 0.85, 0.4, 1.0),
	})


func spawn_coin_collect(pos: Vector3) -> void:
	spawn_at(pos, {
		"amount": 10,
		"lifetime": 0.4,
		"explosiveness": 1.0,
		"direction": Vector3(0, 1, 0),
		"spread": 60.0,
		"vel_min": 3.0,
		"vel_max": 6.0,
		"gravity": Vector3(0, -6, 0),
		"scale_min": 0.05,
		"scale_max": 0.12,
		"color": Color(1.0, 0.9, 0.2, 1.0),
	})


func spawn_star_collect(pos: Vector3) -> void:
	spawn_at(pos, {
		"amount": 20,
		"lifetime": 0.6,
		"explosiveness": 1.0,
		"direction": Vector3(0, 1, 0),
		"spread": 90.0,
		"vel_min": 4.0,
		"vel_max": 8.0,
		"gravity": Vector3(0, -4, 0),
		"scale_min": 0.08,
		"scale_max": 0.2,
		"color": Color(1.0, 1.0, 0.5, 1.0),
	})


func spawn_enemy_death(pos: Vector3) -> void:
	spawn_at(pos, {
		"amount": 16,
		"lifetime": 0.5,
		"explosiveness": 1.0,
		"direction": Vector3(0, 1, 0),
		"spread": 90.0,
		"vel_min": 3.0,
		"vel_max": 7.0,
		"gravity": Vector3(0, -10, 0),
		"scale_min": 0.1,
		"scale_max": 0.25,
		"color": Color(0.9, 0.3, 0.9, 1.0),
	})


func spawn_health_collect(pos: Vector3) -> void:
	spawn_at(pos, {
		"amount": 8,
		"lifetime": 0.5,
		"explosiveness": 1.0,
		"direction": Vector3(0, 1, 0),
		"spread": 45.0,
		"vel_min": 2.0,
		"vel_max": 4.0,
		"gravity": Vector3(0, -3, 0),
		"scale_min": 0.06,
		"scale_max": 0.15,
		"color": Color(1.0, 0.3, 0.4, 1.0),
	})


func spawn_spin_attack(pos: Vector3) -> void:
	spawn_at(pos, {
		"amount": 16,
		"lifetime": 0.3,
		"direction": Vector3(0, 0, 0),
		"spread": 180.0,
		"vel_min": 3.0,
		"vel_max": 5.0,
		"gravity": Vector3(0, 0, 0),
		"scale_min": 0.04,
		"scale_max": 0.1,
		"color": Color(0.5, 0.8, 1.0, 0.8),
	})


func spawn_crate_break(pos: Vector3) -> void:
	spawn_at(pos, {
		"amount": 14,
		"lifetime": 0.5,
		"explosiveness": 1.0,
		"direction": Vector3(0, 1, 0),
		"spread": 80.0,
		"vel_min": 3.0,
		"vel_max": 6.0,
		"gravity": Vector3(0, -12, 0),
		"scale_min": 0.08,
		"scale_max": 0.2,
		"color": Color(0.7, 0.55, 0.3, 1.0),
	})

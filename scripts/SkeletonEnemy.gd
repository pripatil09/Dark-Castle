extends BaseEnemy

# Skeleton enemy - basic melee attacker
func _ready():
	# Set skeleton-specific stats
	max_health = 40
	speed = 60.0
	damage = 15
	attack_range = 25.0
	detection_range = 80.0
	attack_cooldown = 1.5
	
	# Call parent _ready
	super._ready()
	
	# Create skeleton sprite
	create_skeleton_sprite()

func create_skeleton_sprite():
	"""Create the skeleton sprite"""
	var generator = preload("res://scripts/EnemySpriteGenerator.gd").new()
	var skeleton_texture = generator.create_skeleton_sprite()
	
	if sprite:
		sprite.texture = skeleton_texture
		sprite.scale = Vector2(2.0, 2.0)  # Make it bigger
		sprite.modulate = Color(1, 1, 1, 1)

func get_enemy_type() -> String:
	return "skeleton"

func perform_attack():
	"""Skeleton's bone-claw attack"""
	if not player:
		return
	
	print("Skeleton slashes with bone claws!")
	
	# Deal damage to player
	if player.has_method("take_damage"):
		player.take_damage(damage)
	
	# Create bone attack effect
	create_bone_attack_effect()

func create_bone_attack_effect():
	"""Create bone claw attack visual effect"""
	# Flash white and create bone particles
	var original_modulate = sprite.modulate
	sprite.modulate = Color.WHITE
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.3)
	
	# Create bone particle effect
	create_bone_particles()

func create_bone_particles():
	"""Create bone particle effect around the skeleton"""
	for i in range(5):
		var bone_particle = ColorRect.new()
		bone_particle.size = Vector2(4, 8)
		bone_particle.color = Color(0.9, 0.9, 0.8, 0.8)
		bone_particle.position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		get_parent().add_child(bone_particle)
		
		# Animate the particle
		var tween = create_tween()
		tween.tween_property(bone_particle, "modulate:a", 0.0, 1.0)
		tween.tween_callback(bone_particle.queue_free)

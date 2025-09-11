extends BaseEnemy

# Goblin enemy - fast, weak melee attacker
func _ready():
	# Set goblin-specific stats
	max_health = 25
	speed = 120.0  # Faster than skeleton
	damage = 8
	attack_range = 20.0
	detection_range = 100.0
	attack_cooldown = 1.0  # Faster attacks
	
	# Call parent _ready
	super._ready()
	
	# Create goblin sprite
	create_goblin_sprite()

func create_goblin_sprite():
	"""Create the goblin sprite"""
	var generator = preload("res://scripts/EnemySpriteGenerator.gd").new()
	var goblin_texture = generator.create_goblin_sprite()
	
	if sprite:
		sprite.texture = goblin_texture
		sprite.scale = Vector2(2.0, 2.0)  # Make it bigger
		sprite.modulate = Color(1, 1, 1, 1)

func get_enemy_type() -> String:
	return "goblin"

func perform_attack():
	"""Goblin's club attack"""
	if not player:
		return
	
	print("Goblin swings its club!")
	
	# Deal damage to player
	if player.has_method("take_damage"):
		player.take_damage(damage)
	
	# Create club attack effect
	create_club_attack_effect()

func create_club_attack_effect():
	"""Create club attack visual effect"""
	# Flash green and create club swing effect
	var original_modulate = sprite.modulate
	sprite.modulate = Color(0.4, 0.7, 0.4, 1.0)  # Green flash
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.2)
	
	# Create club swing effect
	create_club_swing_effect()

func create_club_swing_effect():
	"""Create club swing visual effect"""
	# Create a swinging club effect
	var club_effect = ColorRect.new()
	club_effect.size = Vector2(8, 20)
	club_effect.color = Color(0.5, 0.5, 0.5, 0.8)
	club_effect.position = global_position + Vector2(20, -10)
	get_parent().add_child(club_effect)
	
	# Animate the club swing
	var tween = create_tween()
	tween.tween_property(club_effect, "rotation", PI * 0.5, 0.3)
	tween.tween_property(club_effect, "modulate:a", 0.0, 0.3)
	tween.tween_callback(club_effect.queue_free)

func handle_chasing_state(delta):
	"""Goblin-specific chasing - more erratic movement"""
	if not can_see_player():
		state = "idle"
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player <= attack_range:
		state = "attacking"
		return
	
	# Goblin moves more erratically
	var direction = (player.global_position - global_position).normalized()
	
	# Add some randomness to make movement less predictable
	var random_offset = Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
	direction = (direction + random_offset).normalized()
	
	velocity = direction * speed
	last_known_player_pos = player.global_position

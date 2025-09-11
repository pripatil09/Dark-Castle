extends CharacterBody2D
class_name BaseEnemy

# Base enemy class that all enemies inherit from
@export var max_health = 50
@export var speed = 80.0
@export var damage = 10
@export var attack_range = 30.0
@export var detection_range = 100.0
@export var attack_cooldown = 2.0

var current_health: int
var player: CharacterBody2D
var is_dead = false
var attack_timer = 0.0
var last_known_player_pos: Vector2
var state = "idle"  # idle, chasing, attacking, dead
var sprite: Sprite2D
var collision_shape: CollisionShape2D

# Animation variables
var animation_timer = 0.0
var walk_cycle_speed = 0.3
var current_direction = Vector2.DOWN

func _ready():
	current_health = max_health
	sprite = get_node("Sprite2D")
	collision_shape = get_node("CollisionShape2D")
	
	# Find player
	call_deferred("find_player")
	
	# Set up collision
	collision_layer = 2  # Enemies on layer 2
	collision_mask = 1   # Collide with walls (layer 1)

func find_player():
	"""Find the player node"""
	var possible_paths = [
		"../../Player",
		"../../../Player", 
		"/root/Main/Player",
		"../../Main/Player"
	]
	
	for path in possible_paths:
		var node = get_node_or_null(path)
		if node:
			player = node
			print("Enemy found player at path: ", path)
			return
	
	print("Enemy could not find player!")

func _physics_process(delta):
	if is_dead or not player:
		return
	
	# Update attack timer
	if attack_timer > 0:
		attack_timer -= delta
	
	# Update state machine
	match state:
		"idle":
			handle_idle_state(delta)
		"chasing":
			handle_chasing_state(delta)
		"attacking":
			handle_attacking_state(delta)
		"dead":
			handle_dead_state(delta)
	
	# Update animations
	update_animations(delta)
	
	# Apply movement
	move_and_slide()

func handle_idle_state(delta):
	"""Handle idle state - look for player"""
	if can_see_player():
		state = "chasing"
		print("Enemy spotted player!")

func handle_chasing_state(delta):
	"""Handle chasing state - move towards player"""
	if not can_see_player():
		# Lost sight of player, go back to idle
		state = "idle"
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player <= attack_range:
		# Close enough to attack
		state = "attacking"
		return
	
	# Move towards player
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed
	last_known_player_pos = player.global_position

func handle_attacking_state(delta):
	"""Handle attacking state - attack player if in range"""
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player > attack_range:
		# Player moved away, chase again
		state = "chasing"
		return
	
	# Stop moving when attacking
	velocity = Vector2.ZERO
	
	# Attack if cooldown is ready
	if attack_timer <= 0:
		perform_attack()
		attack_timer = attack_cooldown

func handle_dead_state(delta):
	"""Handle dead state - do nothing"""
	velocity = Vector2.ZERO

func can_see_player() -> bool:
	"""Check if enemy can see the player"""
	if not player:
		return false
	
	var distance = global_position.distance_to(player.global_position)
	if distance > detection_range:
		return false
	
	# Simple line of sight check (could be enhanced with ray casting)
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.new()
	query.from = global_position
	query.to = player.global_position
	query.collision_mask = 1  # Only check walls
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	return not result  # No wall blocking the view

func perform_attack():
	"""Perform attack on player"""
	if not player:
		return
	
	print("Enemy attacks player!")
	
	# Deal damage to player
	if player.has_method("take_damage"):
		player.take_damage(damage)
	
	# Visual/audio feedback
	create_attack_effect()

func create_attack_effect():
	"""Create visual effect for attack"""
	# Flash red briefly
	var original_modulate = sprite.modulate
	sprite.modulate = Color.RED
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.2)

func take_damage(amount: int):
	"""Take damage and handle death"""
	if is_dead:
		return
	
	current_health -= amount
	print("Enemy took ", amount, " damage. Health: ", current_health)
	
	# Flash white on damage
	var original_modulate = sprite.modulate
	sprite.modulate = Color.WHITE
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.1)
	
	if current_health <= 0:
		die()

func die():
	"""Handle enemy death"""
	if is_dead:
		return
	
	is_dead = true
	state = "dead"
	current_health = 0
	
	print("Enemy died!")
	
	# Death animation
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)

func update_animations(delta):
	"""Update enemy animations"""
	if is_dead:
		return
	
	animation_timer += delta
	
	# Simple walking animation
	if velocity.length() > 10:
		current_direction = velocity.normalized()
		
		# Update sprite based on direction
		if abs(current_direction.x) > abs(current_direction.y):
			# Moving horizontally
			if current_direction.x > 0:
				sprite.flip_h = false
			else:
				sprite.flip_h = true
		else:
			# Moving vertically
			if current_direction.y > 0:
				# Moving down
				pass
			else:
				# Moving up
				pass
		
		# Simple bobbing animation
		var bob_offset = sin(animation_timer * walk_cycle_speed * 10) * 2
		sprite.position.y = bob_offset
	else:
		# Reset position when not moving
		sprite.position.y = 0

func get_enemy_type() -> String:
	"""Return the enemy type - override in subclasses"""
	return "base"

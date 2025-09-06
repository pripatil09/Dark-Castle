extends CharacterBody2D

# Simple player character for dungeon crawler
@export var speed = 200.0
@export var acceleration = 800.0
@export var friction = 600.0
@export var health = 100
@export var max_health = 100

var dungeon_generator: Node2D
var is_moving = false
var camera: Camera2D
var health_bar: Control
var health_bar_fill: ColorRect
var audio_manager: Node
var is_in_combat = false

func _ready():
	dungeon_generator = get_node("../DungeonGenerator")
	camera = get_node("Camera2D")
	health_bar = get_node("HealthBar")
	audio_manager = get_node("../AudioManager")
	
	# Position player at a random floor tile
	if dungeon_generator:
		global_position = dungeon_generator.get_random_floor_position()
	
	# Ensure camera is properly centered
	if camera:
		camera.enabled = true
		camera.make_current()
		# Ensure camera follows player smoothly
		camera.position = Vector2.ZERO
	
	# Initialize health bar
	if health_bar:
		health_bar_fill = health_bar.get_node("HealthBarFill")
		center_health_bar()
		update_health_bar_display()
		# Ensure it starts green
		if health_bar_fill:
			health_bar_fill.color = Color(0.0, 1.0, 0.0)  # Bright green

func _input(event):
	if event.is_action_pressed("ui_accept"):
		# Regenerate dungeon and reposition player
		if dungeon_generator:
			dungeon_generator.generate_dungeon()
			var new_pos = dungeon_generator.get_random_floor_position()
			if new_pos != Vector2.ZERO:
				global_position = new_pos
	
	# Debug zoom controls
	if event.is_action_pressed("ui_zoom_in"):
		if camera:
			camera.zoom *= 1.2
	
	if event.is_action_pressed("ui_zoom_out"):
		if camera:
			camera.zoom *= 0.8
	
	# Debug health controls for testing audio transitions
	if event.is_action_pressed("ui_cancel"):  # Escape key
		take_damage(20)
	
	if event.is_action_pressed("ui_home"):  # Home key
		heal(20)
	
	if event.is_action_pressed("ui_end"):  # End key
		reset_player()

func _physics_process(delta):
	handle_movement(delta)
	move_and_slide()
	
	# Check for combat state changes
	check_combat_state()

func handle_movement(delta: float):
	var direction = Vector2.ZERO
	
	# Handle each direction separately
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1
	
	# Apply momentum-based movement
	if direction != Vector2.ZERO:
		# Accelerate towards target velocity
		var target_velocity = direction.normalized() * speed
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
		is_moving = true
	else:
		# Apply friction when not moving
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		is_moving = velocity.length() > 10.0  # Still moving if velocity is significant

func take_damage(amount: int):
	health -= amount
	health = max(0, health)
	# print("Player health: ", health, "/", max_health)
	
	# Update health bar
	if health_bar:
		update_health_bar_display()
	
	if health <= 0:
		die()

func die():
	# print("Player died!")
	reset_player()

func reset_player():
	"""Reset player to full health and reposition"""
	health = max_health
	# print("Player reset! Health: ", health, "/", max_health)
	
	# Update health bar and ensure it shows green
	if health_bar:
		update_health_bar_display()
		# Force green color for full health
		if health_bar_fill:
			health_bar_fill.color = Color(0.0, 1.0, 0.0)  # Bright green
	
	# Reset combat state
	if is_in_combat:
		exit_combat()
	
	# Transition back to mysterious music
	if audio_manager:
		audio_manager.transition_to_mysterious()
	
	# Reposition player to a random floor tile (try multiple times to avoid walls)
	if dungeon_generator:
		var attempts = 0
		var max_attempts = 10
		var new_pos = Vector2.ZERO
		
		while attempts < max_attempts:
			new_pos = dungeon_generator.get_random_floor_position()
			if new_pos != Vector2.ZERO:
				# Check if the position is valid (not in a wall)
				global_position = new_pos
				# Check collision at the new position
				if not test_move(Transform2D(), Vector2.ZERO):
					# Position is valid (no collision)
					break
				else:
					# Position is invalid, try again
					attempts += 1
			else:
				attempts += 1
		
		if attempts >= max_attempts:
			# Could not find valid position after max attempts
			pass

func heal(amount: int):
	health += amount
	health = min(max_health, health)
	
	# Update health bar
	if health_bar:
		update_health_bar_display()

func check_combat_state():
	"""Check if player is in combat and update audio accordingly"""
	# For now, we'll simulate combat detection
	# In a real game, this would check for nearby enemies
	var was_in_combat = is_in_combat
	
	# Simulate combat when health is low (for testing)
	# TODO: Replace with actual enemy detection
	if health < 30 and not is_in_combat:
		enter_combat()
	elif health >= 30 and is_in_combat:
		exit_combat()
	
	# Transition to piano when health is between 50-80
	if health >= 50 and health < 80 and audio_manager:
		audio_manager.transition_to_piano()
	# Transition to strange when health is below 50
	elif health < 50 and audio_manager:
		audio_manager.transition_to_strange()
	# Transition back to mysterious when health is above 80
	elif health >= 80 and audio_manager:
		audio_manager.transition_to_mysterious()
	
	# Adjust combat intensity based on health (lower health = more intense)
	if is_in_combat and audio_manager:
		var intensity = 1.0 - (float(health) / 30.0)  # 0.0 at full health, 1.0 at 0 health
		intensity = clamp(intensity, 0.0, 1.0)
		audio_manager.set_combat_intensity(intensity)

func enter_combat():
	"""Enter combat mode"""
	if not is_in_combat:
		is_in_combat = true
		if audio_manager:
			audio_manager.transition_to_strange()

func exit_combat():
	"""Exit combat mode"""
	if is_in_combat:
		is_in_combat = false
		if audio_manager:
			audio_manager.transition_to_mysterious()

func play_footstep_sound():
	"""Play footstep sound when moving"""
	if audio_manager and is_moving:
		audio_manager.play_footstep()

func center_health_bar():
	"""Ensure health bar is properly centered above the player"""
	if not health_bar:
		return
	
	# Health bar should be centered horizontally above the player
	# Player is 12x12, so health bar should be centered on that
	# Current offset: -20 to +20 (40 pixels wide, centered on 12-pixel player)
	health_bar.position = Vector2(-20, -25)  # 25 pixels above player

func update_health_bar_display():
	"""Update health bar display based on current health"""
	if not health_bar or not health_bar_fill:
		return
	
	var health_percentage = float(health) / float(max_health)
	
	# Update the fill width based on health percentage
	health_bar_fill.anchor_right = health_percentage
	
	# Interpolate color from green (100%) to red (0%)
	# Start with bright green at full health, transition to red at low health
	var health_color: Color
	if health_percentage > 0.6:
		# Green to yellow transition (100% to 60%)
		var green_to_yellow = (health_percentage - 0.6) / 0.4
		health_color = Color(green_to_yellow, 1.0, 0.0)
	else:
		# Yellow to red transition (60% to 0%)
		var yellow_to_red = health_percentage / 0.6
		health_color = Color(1.0, yellow_to_red, 0.0)
	
	health_bar_fill.color = health_color
	
	# Optional: Add some visual feedback for low health
	if health_percentage < 0.3:
		# Flash red when very low health
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(health_bar_fill, "color", Color.RED, 0.5)
		tween.tween_property(health_bar_fill, "color", health_color, 0.5)

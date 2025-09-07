extends CharacterBody2D

# Simple player character for dungeon crawler
@export var speed = 200.0
@export var acceleration = 800.0
@export var friction = 600.0
@export var health = 100
@export var max_health = 100

# Dash mechanics
@export var dash_speed = 600.0  # Increased from 400.0 (1.5x)
@export var dash_duration = 0.15
@export var dash_cooldown = 1.0

var dungeon_generator: Node2D
var is_moving = false
var camera: Camera2D
var health_bar: Control
var health_bar_fill: ColorRect
var audio_manager: Node
var is_in_combat = false

# Dash state variables
var is_dashing = false
var dash_timer = 0.0
var dash_cooldown_timer = 0.0
var dash_direction = Vector2.ZERO

# Animation variables
var sprite: Sprite2D
var animation_timer = 0.0
var walk_cycle_speed = 0.2
var current_direction = Vector2.DOWN

# Hotbar variables
var hotbar_slots = []
var selected_slot = 0

func _ready():
	dungeon_generator = get_node("../DungeonGenerator")
	camera = get_node("Camera2D")
	health_bar = get_node("HealthBar")
	audio_manager = get_node("../AudioManager")
	sprite = get_node("Sprite2D")
	
	# Load animation sprites
	load_animations()
	
	# Initialize hotbar
	initialize_hotbar()
	
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
		health_bar_fill = health_bar.get_node("HealthBarFill") as ColorRect
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
	
	# Dash input (Shift key)
	if event is InputEventKey and event.pressed and event.keycode == KEY_SHIFT:
		print("Shift key pressed! Can dash: ", can_dash())
		if can_dash():
			start_dash()
	
	# Hotbar input (1-9 keys)
	if event is InputEventKey and event.pressed:
		var key = event.keycode
		if key >= KEY_1 and key <= KEY_9:
			var slot_index = key - KEY_1
			select_hotbar_slot(slot_index)
	
	# Item pickup (E key)
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		try_pickup_item()
	
	# Item usage (Left click)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		use_selected_item()
	
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
	# Update dash timers
	update_dash_timers(delta)
	
	# Handle movement (including dash)
	handle_movement(delta)
	
	# Move and handle collisions properly
	move_and_slide()
	
	# Wall collision fix for all movement types including diagonal
	if is_on_wall() and velocity.length() > 10.0:
		var collision_count = get_slide_collision_count()
		if collision_count > 0:
			var collision = get_slide_collision(0)
			var normal = collision.get_normal()
			
			# Check if we're trying to move into the wall
			if velocity.dot(normal) < 0:
				# Get input direction to determine preferred sliding
				var input_direction = Vector2.ZERO
				if Input.is_action_pressed("ui_right"):
					input_direction.x += 1
				if Input.is_action_pressed("ui_left"):
					input_direction.x -= 1
				if Input.is_action_pressed("ui_down"):
					input_direction.y += 1
				if Input.is_action_pressed("ui_up"):
					input_direction.y -= 1
				
				# For diagonal movement, try to maintain the non-blocked direction
				if abs(normal.x) > 0.7:  # Vertical wall - slide horizontally
					# Prefer the horizontal direction the player is trying to go
					if input_direction.x != 0:
						velocity += Vector2(input_direction.x, 0) * 100.0
					else:
						# Random horizontal direction
						var slide_direction = Vector2(1, 0) if randf() < 0.5 else Vector2(-1, 0)
						velocity += slide_direction * 100.0
						
				elif abs(normal.y) > 0.7:  # Horizontal wall - slide vertically
					# Prefer the vertical direction the player is trying to go
					if input_direction.y != 0:
						velocity += Vector2(0, input_direction.y) * 100.0
					else:
						# Random vertical direction
						var slide_direction = Vector2(0, 1) if randf() < 0.5 else Vector2(0, -1)
						velocity += slide_direction * 100.0
						
				else:  # Diagonal wall or corner
					# Try to slide in the direction that maintains most of the input
					var slide_direction = Vector2(-normal.y, normal.x)
					
					# If we have input direction, try to align with it
					if input_direction.length() > 0:
						# Try both perpendicular directions and pick the one closer to input
						var slide1 = Vector2(-normal.y, normal.x)
						var slide2 = Vector2(normal.y, -normal.x)
						
						if slide1.dot(input_direction) > slide2.dot(input_direction):
							velocity += slide1 * 80.0
						else:
							velocity += slide2 * 80.0
					else:
						# Random perpendicular direction
						if randf() < 0.5:
							slide_direction = -slide_direction
						velocity += slide_direction * 80.0
				
				# If still stuck, try pushing away from wall more aggressively
				if velocity.length() < 40.0:
					velocity += normal * -150.0
					
					# For corners, also try a random direction
					if abs(normal.x) < 0.7 and abs(normal.y) < 0.7:
						var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
						velocity += random_dir * 100.0
	
	# Update animations
	update_animations(delta)
	
	# Check for combat state changes
	check_combat_state()

func handle_movement(delta: float):
	# If dashing, use dash movement
	if is_dashing:
		velocity = dash_direction * dash_speed
		is_moving = true
		return
	
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

func handle_wall_sliding():
	"""Handle wall sliding to prevent getting stuck in walls"""
	# Check if we're colliding with something
	if is_on_wall():
		# Get the collision normal
		var collision_count = get_slide_collision_count()
		if collision_count > 0:
			var collision = get_slide_collision(0)
			var normal = collision.get_normal()
			
			# If we're moving into the wall, slide along it
			if velocity.dot(normal) < 0:
				# Project velocity onto the wall surface (remove component going into wall)
				velocity = velocity - velocity.dot(normal) * normal
				
				# Add some sliding friction to prevent infinite sliding
				velocity *= 0.95
				
				# If we're still moving into the wall, try to push away slightly
				if velocity.dot(normal) < -0.1:
					velocity += normal * 50.0  # Push away from wall

func handle_stuck_prevention():
	"""Additional collision handling to prevent getting stuck"""
	# If we're not moving but should be, try to unstick
	if is_moving and velocity.length() < 5.0 and is_on_wall():
		# Try to push away from walls
		var collision_count = get_slide_collision_count()
		if collision_count > 0:
			var collision = get_slide_collision(0)
			var normal = collision.get_normal()
			
			# Push away from the wall
			velocity += normal * 100.0
			
			# Add some random direction to help unstick
			var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			velocity += random_dir * 50.0

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

# Dash functionality
func can_dash() -> bool:
	"""Check if player can dash (not currently dashing and cooldown is ready)"""
	return not is_dashing and dash_cooldown_timer <= 0.0

func start_dash():
	"""Start a dash in the current movement direction"""
	if not can_dash():
		print("Cannot dash - is_dashing: ", is_dashing, " cooldown: ", dash_cooldown_timer)
		return
	
	print("Starting dash!")
	
	# Get current movement direction
	var direction = Vector2.ZERO
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1
	
	# If no direction is pressed, dash in the last velocity direction
	if direction == Vector2.ZERO and velocity.length() > 10.0:
		direction = velocity.normalized()
	# If still no direction, dash right as default
	elif direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	
	dash_direction = direction.normalized()
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	
	print("Dash direction: ", dash_direction, " duration: ", dash_duration)
	
	# Visual feedback
	create_dash_effect()
	
	# Audio feedback
	if audio_manager:
		audio_manager.play_footstep()  # Reuse footstep sound for dash

func update_dash_timers(delta: float):
	"""Update dash and cooldown timers"""
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			end_dash()
	
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

func end_dash():
	"""End the current dash"""
	is_dashing = false
	dash_timer = 0.0
	# Keep some momentum after dash
	velocity = dash_direction * speed * 0.5

func create_dash_effect():
	"""Create visual effect for dash"""
	# Screen shake effect
	if camera:
		var tween = create_tween()
		tween.tween_property(camera, "offset", Vector2(2, 0), 0.05)
		tween.tween_property(camera, "offset", Vector2(-2, 0), 0.05)
		tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)
	
	# Player sprite flash effect
	if sprite:
		var original_modulate = sprite.modulate
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
		tween.tween_property(sprite, "modulate", original_modulate, 0.05)

# Animation system for player sprites
var animation_frames = {}
var current_animation = "idle_right"
var frame_timer = 0.0
var frame_duration = 1.0 / 5.0  # 5fps
var current_frame = 0

func load_animations():
	"""Load all animation frames from the playerAnimations folder"""
	if not sprite:
		return
	
	# Load idle animations
	animation_frames["idle_left"] = []
	animation_frames["idle_right"] = []
	for i in range(6):
		var frame_left = load("res://playerAnimations/StandStillFaceLeft/MCStillLeft" + str(i) + ".png")
		var frame_right = load("res://playerAnimations/StandStillFaceRight/MCStillLeft" + str(i) + ".png")
		animation_frames["idle_left"].append(frame_left)
		animation_frames["idle_right"].append(frame_right)
	
	# Load walk animations
	animation_frames["walk_left"] = []
	animation_frames["walk_right"] = []
	for i in range(4):
		var frame_left = load("res://playerAnimations/WalkLeft/MCWalkLeft" + str(i) + ".png")
		var frame_right = load("res://playerAnimations/WalkRight/MCWalkRIght" + str(i) + ".png")
		animation_frames["walk_left"].append(frame_left)
		animation_frames["walk_right"].append(frame_right)
	
	# Set initial sprite
	sprite.texture = animation_frames["idle_right"][0]

func update_animations(delta: float):
	"""Update character animations using sprite frames"""
	if not sprite or animation_frames.is_empty():
		return
	
	# Update frame timer
	frame_timer += delta
	
	# Determine animation based on movement and direction
	var target_animation = current_animation
	
	if is_dashing:
		# Keep current animation during dash
		target_animation = current_animation
	elif is_moving and velocity.length() > 10.0:
		# Walking animation
		if velocity.x > 0:
			target_animation = "walk_right"
		elif velocity.x < 0:
			target_animation = "walk_left"
		else:
			# Moving vertically, keep current horizontal direction
			if current_animation.begins_with("walk_right") or current_animation == "idle_right":
				target_animation = "walk_right"
			else:
				target_animation = "walk_left"
	else:
		# Idle animation
		if current_animation.begins_with("walk_right") or current_animation == "idle_right":
			target_animation = "idle_right"
		else:
			target_animation = "idle_left"
	
	# Change animation if needed
	if target_animation != current_animation:
		current_animation = target_animation
		current_frame = 0
		frame_timer = 0.0
	
	# Update frame
	if animation_frames.has(current_animation):
		var frames = animation_frames[current_animation]
		if frames.size() > 0:
			# Advance frame based on 5fps timing
			if frame_timer >= frame_duration:
				frame_timer = 0.0
				current_frame = (current_frame + 1) % frames.size()
			
			# Set current frame
			sprite.texture = frames[current_frame]
	
	# Dash effects
	if is_dashing:
		sprite.modulate = Color(1.1, 0.9, 0.9, 0.9)  # Slight glow
		sprite.scale = Vector2(0.2, 0.2)  # 5x larger
	else:
		sprite.modulate = Color(0.5, 0.5, 0.5, 0.7)  # Slightly darkened
		sprite.scale = Vector2(0.2, 0.2)  # 5x larger
		sprite.rotation = 0

# Hotbar system
func initialize_hotbar():
	"""Initialize the hotbar with empty slots"""
	hotbar_slots.resize(9)
	for i in range(9):
		hotbar_slots[i] = null
	
	print("Initializing hotbar...")
	# Update hotbar display
	update_hotbar_display()
	print("Hotbar initialized with ", hotbar_slots.size(), " slots")

func select_hotbar_slot(slot_index: int):
	"""Select a hotbar slot (0-8)"""
	if slot_index >= 0 and slot_index < 9:
		selected_slot = slot_index
		update_hotbar_display()
		print("Selected hotbar slot: ", slot_index + 1)
		
		# Use the item in the selected slot
		use_hotbar_item(slot_index)

func use_hotbar_item(slot_index: int):
	"""Use the item in the specified hotbar slot"""
	if slot_index >= 0 and slot_index < 9:
		var item = hotbar_slots[slot_index]
		if item != null:
			print("Using item: ", item)
			# TODO: Implement item usage logic
		else:
			print("No item in slot ", slot_index + 1)

func update_hotbar_display():
	"""Update the hotbar visual display"""
	# Update slot backgrounds to show selection
	for i in range(9):
		var slot_path = "UILayer/OverlayUI/Hotbar/Slot" + str(i + 1) + "/Slot" + str(i + 1) + "Background"
		var slot_bg: Node = get_node("../" + slot_path)
		if slot_bg:
			if slot_bg is ColorRect:
				var color_rect: ColorRect = slot_bg
				if i == selected_slot:
					color_rect.color = Color(0.6, 0.6, 0.8, 1)  # Blue for selected
				else:
					color_rect.color = Color(0.4, 0.4, 0.4, 1)  # Gray for unselected
			else:
				print("Node found but not a ColorRect: ", slot_path, " (type: ", slot_bg.get_class(), ")")
		else:
			print("Could not find slot background: ", slot_path)

func add_item_to_hotbar(item, slot_index: int = -1):
	"""Add an item to the hotbar"""
	if slot_index == -1:
		# Find first empty slot
		for i in range(9):
			if hotbar_slots[i] == null:
				slot_index = i
				break
	
	if slot_index >= 0 and slot_index < 9:
		hotbar_slots[slot_index] = item
		update_hotbar_display()
		print("Added item to slot ", slot_index + 1, ": ", item)
		return true
	return false

func try_pickup_item():
	"""Try to pickup an item near the player"""
	# Check for items in a small radius around the player
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = global_position
	query.collision_mask = 4  # Items on layer 4
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var results = space_state.intersect_point(query)
	
	for result in results:
		var item = result.collider
		if item.has_method("pickup"):
			var item_data = item.pickup()
			if add_item_to_hotbar(item_data):
				print("Picked up item: ", item_data)
				item.queue_free()  # Remove the item from the world
				return true
	
	print("No items nearby to pickup")
	return false

func use_selected_item():
	"""Use the currently selected hotbar item"""
	if selected_slot >= 0 and selected_slot < 9:
		var item = hotbar_slots[selected_slot]
		if item != null:
			print("Using selected item: ", item)
			# TODO: Implement item usage logic based on item type
			# For now, just consume the item
			hotbar_slots[selected_slot] = null
			update_hotbar_display()
		else:
			print("No item in selected slot ", selected_slot + 1)

extends CharacterBody2D

# Simple player character for dungeon crawler
@export var speed = 200.0
@export var acceleration = 800.0
@export var friction = 600.0
@export var health = 100
@export var max_health = 100

# Dash mechanics
@export var dash_speed = 900.0  # Increased from 400.0 (1.5x)
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

# Sword attack variables
var is_slashing = false
var slash_timer = 0.0
var slash_direction = Vector2.RIGHT
var hit_enemies = []  # Track enemies hit to prevent multiple hits
var tutorial_system: Control
var last_velocity: Vector2 = Vector2.ZERO
var sword_cooldown = 0.0
var sword_cooldown_duration = 1.0  # 1 second cooldown

func _ready():
	dungeon_generator = get_node("../DungeonGenerator")
	camera = get_node("Camera2D")
	health_bar = get_node("HealthBar")
	audio_manager = get_node("../AudioManager")
	sprite = get_node("Sprite2D")
	tutorial_system = get_node("../TutorialSystem")
	
	# Load animation sprites
	load_animations()
	
	# Initialize hotbar
	initialize_hotbar()
	
	# Give player a starting sword
	give_starting_sword()
	
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
	
	# Update sword slash timer
	update_sword_slash(delta)
	
	# Update sword cooldown
	if sword_cooldown > 0:
		sword_cooldown -= delta
	
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
	# Check if movement is blocked by tutorial
	if get_meta("tutorial_blocked", false):
		velocity = Vector2.ZERO
		is_moving = false
		return
	
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
		
		# Track last movement direction for sword rotation
		last_velocity = direction.normalized()
		
		# Notify tutorial system of movement
		if tutorial_system:
			tutorial_system.check_tutorial_action("move")
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
	"""Take damage from enemies"""
	if health <= 0:
		return  # Already dead
	
	health -= amount
	health = max(0, health)
	print("Player took ", amount, " damage. Health: ", health, "/", max_health)
	
	# Flash red on damage
	var original_modulate = sprite.modulate
	sprite.modulate = Color.RED
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.2)
	
	# Update health bar
	if health_bar:
		update_health_bar_display()
	
	if health <= 0:
		die()

func die():
	# print("Player died!")
	# Make sure health bar turns green when player dies
	if health_bar_fill:
		health_bar_fill.color = Color(0.0, 1.0, 0.0)  # Bright green
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
	
	# Notify tutorial system of dash
	if tutorial_system:
		tutorial_system.check_tutorial_action("dash")
	
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

func give_starting_sword():
	"""Give the player a starting sword in their inventory"""
	var starting_sword = {
		"name": "Iron Sword",
		"type": "sword",
		"damage": 25,
		"range": 80.0,
		"duration": 0.3,
		"icon": "⚔️"
	}
	
	# Add sword to first hotbar slot
	hotbar_slots[0] = starting_sword
	update_hotbar_display()
	
	print("Player received starting sword!")

func select_hotbar_slot(slot_index: int):
	"""Select a hotbar slot (0-8)"""
	if slot_index >= 0 and slot_index < 9:
		selected_slot = slot_index
		update_hotbar_display()
		print("Selected hotbar slot: ", slot_index + 1)
		
		# Notify tutorial system of inventory usage
		if tutorial_system:
			tutorial_system.check_tutorial_action("inventory")
		
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
	# Update slot backgrounds and labels to show selection and items
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
		
		# Update slot label to show item icon or number
		var label_path = "UILayer/OverlayUI/Hotbar/Slot" + str(i + 1) + "/Slot" + str(i + 1) + "Label"
		var slot_label: Node = get_node("../" + label_path)
		if slot_label and slot_label is Label:
			var label: Label = slot_label
			if hotbar_slots[i] != null:
				# Show item icon
				label.text = hotbar_slots[i].get("icon", str(i + 1))
			else:
				# Show slot number
				label.text = str(i + 1)

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
				
				# Notify tutorial system of item pickup
				if tutorial_system:
					tutorial_system.check_tutorial_action("inventory")
				
				item.queue_free()  # Remove the item from the world
				return true
	
	print("No items nearby to pickup")
	return false

func use_selected_item():
	"""Use the currently selected hotbar item"""
	print("=== LEFT CLICK DETECTED ===")
	print("Selected slot: ", selected_slot)
	print("Hotbar slots: ", hotbar_slots)
	
	if selected_slot >= 0 and selected_slot < 9:
		var item = hotbar_slots[selected_slot]
		if item != null:
			print("Using selected item: ", item)
			print("Item type: ", item.get("type", "unknown"))
			# Handle different item types
			if item.type == "sword":
				print("Performing sword slash!")
				perform_sword_slash(item)
			else:
				print("Item is not a sword, type: ", item.type)
				# Default: consume the item
				hotbar_slots[selected_slot] = null
				update_hotbar_display()
		else:
			print("No item in selected slot ", selected_slot + 1)
	else:
		print("Invalid selected slot: ", selected_slot)

func perform_sword_slash(item):
	"""Perform a sword slash attack"""
	print("=== PERFORMING SWORD SLASH ===")
	print("Is already slashing: ", is_slashing)
	print("Item: ", item)
	
	# Check cooldown
	if sword_cooldown > 0:
		print("Sword on cooldown! ", sword_cooldown, " seconds remaining")
		return
	
	if is_slashing:
		print("Already slashing, returning")
		return  # Already slashing
	
	print("Starting sword slash!")
	is_slashing = true
	slash_timer = item.duration
	slash_direction = get_last_movement_direction()
	sword_cooldown = sword_cooldown_duration  # Start cooldown
	
	# Notify tutorial system of attack
	if tutorial_system:
		tutorial_system.check_tutorial_action("attack")
	
	# Visual effect
	print("Creating slash effect...")
	create_slash_effect(item.range)
	
	# Check for enemies in slash area
	check_slash_hits(item)

func get_last_movement_direction() -> Vector2:
	"""Get the last movement direction for slash direction"""
	if velocity.length() > 10.0:
		return velocity.normalized()
	else:
		# Use current animation direction
		if current_animation.begins_with("walk_right") or current_animation == "idle_right":
			return Vector2.RIGHT
		else:
			return Vector2.LEFT

func update_sword_slash(delta: float):
	"""Update sword slash timer"""
	if is_slashing:
		slash_timer -= delta
		if slash_timer <= 0.0:
			end_sword_slash()

func end_sword_slash():
	"""End the sword slash"""
	is_slashing = false
	slash_timer = 0.0

func create_slash_effect(range: float):
	"""Create visual effect for sword slash"""
	print("=== CREATE SLASH EFFECT ===")
	print("Range: ", range)
	print("Player position: ", global_position)
	
	# Screen shake
	if camera:
		print("Creating screen shake...")
		var tween = create_tween()
		tween.tween_property(camera, "offset", Vector2(3, 0), 0.1)
		tween.tween_property(camera, "offset", Vector2(-3, 0), 0.1)
		tween.tween_property(camera, "offset", Vector2.ZERO, 0.1)
	
	# Player sprite flash
	if sprite:
		var original_modulate = sprite.modulate
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		tween.tween_property(sprite, "modulate", original_modulate, 0.1)
	
	# Create slashing effect around player
	create_slash_visual_effect(range)

func create_slash_visual_effect(range: float):
	"""Create a visual slash effect around the player"""
	print("=== CREATE SLASH VISUAL EFFECT ===")
	print("Range: ", range)
	print("Player position: ", global_position)
	
	# Clear the hit enemies list for this slash
	hit_enemies.clear()
	
	# Create the actual sword animation
	create_actual_sword_animation()

func get_last_velocity() -> Vector2:
	"""Get the last movement direction for sword rotation"""
	return last_velocity

func create_sword_collision(sprite: Sprite2D):
	"""Create collision detection for the sword using Godot's built-in system"""
	# Use Godot's built-in collision detection
	# The sword sprite will automatically detect collisions with enemies
	print("Sword collision detection enabled")
	
	# Check for enemies in range during animation
	check_sword_damage()

func check_sword_damage():
	"""Check for enemies in sword range and damage them"""
	# Get all enemies in the scene
	var enemies = get_tree().get_nodes_in_group("enemies")
	var sword_range = 80.0
	
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			var distance = global_position.distance_to(enemy.global_position)
			if distance <= sword_range:
				# Check if we've already hit this enemy
				if not enemy in hit_enemies:
					hit_enemies.append(enemy)
					enemy.take_damage(25)  # Sword does 25 damage
					print("Sword hit enemy: ", enemy.name, " for 25 damage")

func create_actual_sword_animation():
	"""Create the actual sword animation using the sprite frames"""
	print("=== CREATING ACTUAL SWORD ANIMATION ===")
	
	# Create a sprite for the sword animation
	var sword_sprite = Sprite2D.new()
	sword_sprite.name = "ActualSwordAnimation"
	sword_sprite.position = Vector2.ZERO  # Position relative to player
	sword_sprite.z_index = 1  # Same layer as player
	sword_sprite.visible = true
	
	# Rotate based on player's last movement direction
	var last_velocity = get_last_velocity()
	if last_velocity.length() > 0:
		# Adjust rotation by PI radians (180 degrees) to fix the orientation
		sword_sprite.rotation = last_velocity.angle() + (PI/2)
		print("Sword rotated to angle: ", sword_sprite.rotation, " (movement: ", last_velocity, ")")
	else:
		# Default to right if no movement
		sword_sprite.rotation = PI  # Point right
		print("Sword using default rotation (right)")
	
	# Add as child of player so it's on the same layer
	add_child(sword_sprite)
	print("Created sword sprite as child of player")
	
	# Add built-in collision detection
	create_sword_collision(sword_sprite)
	
	# Load the first frame to test
	var frame_path = "res://playerAnimations/swordslash/sword slash00.png"
	var first_frame = load(frame_path)
	
	if first_frame:
		sword_sprite.texture = first_frame
		sword_sprite.scale = Vector2(0.5, 0.5)
		print("✓ Loaded first sword frame")
		
		# Load all frames in correct order
		var frames = []
		
		for i in range(12):  # Load frames 0-11 in order
			var frame_number = str(i).pad_zeros(2)
			var frame_path_i = "res://playerAnimations/swordslash/sword slash" + frame_number + ".png"
			var frame = load(frame_path_i)
			if frame:
				frames.append(frame)
				print("✓ Loaded sword frame ", i, " (", frame_number, ")")
			else:
				print("✗ Failed to load sword frame ", i, " (", frame_number, ")")
				# Add a placeholder to maintain order
				frames.append(first_frame)
		
		print("Total frames loaded: ", frames.size())
		
		# Animate through the frames
		animate_sword_frames_simple(sword_sprite, frames)
	else:
		print("✗ Failed to load first sword frame")
		sword_sprite.queue_free()

func animate_sword_frames_simple(sprite: Sprite2D, frames: Array):
	"""Simple animation through sword frames - PERMANENT FOR TESTING"""
	print("Starting PERMANENT sword frame animation for testing")
	print("Total frames available: ", frames.size())
	
	# Use a simple approach - just cycle through frames manually
	cycle_sword_frames(sprite, frames, 0)

func cycle_sword_frames(sprite: Sprite2D, frames: Array, frame_index: int):
	"""Cycle through sword frames manually - play once on left click"""
	if frame_index >= frames.size():
		# Animation complete - remove sprite
		sprite.queue_free()
		print("Sword animation complete - sprite removed")
		return
	
	# Show the current frame
	sprite.texture = frames[frame_index]
	print("=== SWORD FRAME ===")
	print("Frame index: ", frame_index)
	print("Frame number: ", str(frame_index).pad_zeros(2))
	print("Total frames: ", frames.size())
	print("==================")
	
	# Schedule next frame
	var timer = Timer.new()
	timer.wait_time = 0.005  # 200 FPS - much faster animation
	timer.one_shot = true
	timer.timeout.connect(cycle_sword_frames.bind(sprite, frames, frame_index + 1))
	add_child(timer)
	timer.start()

func create_working_sword_slash():
	"""Create a simple working sword slash effect"""
	print("=== CREATING WORKING SWORD SLASH ===")
	
	# Create a sword slash effect using ColorRect (same approach as working red square)
	var slash_rect = ColorRect.new()
	slash_rect.name = "WorkingSwordSlash"
	slash_rect.size = Vector2(60, 20)  # Horizontal slash
	slash_rect.position = global_position - Vector2(30, 10)
	slash_rect.color = Color(1, 1, 0, 0.8)  # Bright yellow slash
	slash_rect.z_index = 99999
	
	# Add to scene root (same approach as working red square)
	var scene_root = get_tree().current_scene
	scene_root.add_child(slash_rect)
	print("Created sword slash at: ", slash_rect.position)
	
	# Create a bright effect around it
	var effect_rect = ColorRect.new()
	effect_rect.name = "SwordSlashEffect"
	effect_rect.size = Vector2(100, 100)
	effect_rect.position = global_position - Vector2(50, 50)
	effect_rect.color = Color(1, 0, 0, 0.3)  # Red glow
	effect_rect.z_index = 99998
	
	scene_root.add_child(effect_rect)
	print("Created sword effect glow at: ", effect_rect.position)
	
	# Animate the slash effect
	var tween = create_tween()
	tween.parallel()
	
	# Rotate the slash
	tween.tween_property(slash_rect, "rotation", PI * 2, 0.5)
	
	# Scale the slash
	tween.tween_property(slash_rect, "scale", Vector2(2.0, 1.0), 0.5)
	
	# Fade out the effect
	tween.tween_property(slash_rect, "modulate:a", 0.0, 0.5)
	tween.tween_property(effect_rect, "modulate:a", 0.0, 0.5)
	
	# Remove after animation
	tween.tween_callback(slash_rect.queue_free)
	tween.tween_callback(effect_rect.queue_free)
	
	print("Sword slash animation started!")

func create_sword_animation_sprite():
	"""Create a sword animation sprite that follows the player"""
	print("=== CREATING SWORD ANIMATION SPRITE ===")
	
	# Create a sprite for the sword animation
	var sword_sprite = Sprite2D.new()
	sword_sprite.name = "SwordAnimationSprite"
	sword_sprite.position = Vector2.ZERO  # Position relative to player
	sword_sprite.z_index = 1000  # Above player but below UI
	sword_sprite.visible = true
	
	# Add as child of player so it follows the player
	add_child(sword_sprite)
	print("Created sword sprite as child of player")
	
	# Load the sword animation frames
	var frames = []
	for i in range(12):
		var frame_number = str(i).pad_zeros(2)
		var frame_path = "res://playerAnimations/swordslash/sword slash" + frame_number + ".png"
		var frame = load(frame_path)
		if frame:
			frames.append(frame)
			print("✓ Loaded sword frame ", i)
		else:
			print("✗ Failed to load sword frame ", i)
	
	if frames.size() > 0:
		# Set up the sprite
		sword_sprite.texture = frames[0]
		sword_sprite.scale = Vector2(0.5, 0.5)
		sword_sprite.modulate = Color(1, 1, 1, 1)
		print("Sword sprite set up with ", frames.size(), " frames")
		
		# Animate through the frames
		animate_sword_sprite(sword_sprite, frames)
	else:
		print("No frames loaded, creating fallback")
		create_sword_fallback_sprite(sword_sprite)

func animate_sword_sprite(sprite: Sprite2D, frames: Array):
	"""Animate the sword sprite through all frames"""
	print("Starting sword sprite animation")
	
	# Create a simple animation using a tween
	var tween = create_tween()
	tween.tween_method(update_sword_sprite_frame.bind(sprite, frames), 0.0, 1.0, 2.0)
	tween.tween_callback(sprite.queue_free)
	print("Sword animation tween started")

func update_sword_sprite_frame(sprite: Sprite2D, frames: Array, progress: float):
	"""Update sword frame based on progress"""
	if frames.size() > 0:
		var frame_index = int(progress * (frames.size() - 1))
		frame_index = clamp(frame_index, 0, frames.size() - 1)
		sprite.texture = frames[frame_index]
		print("Sword frame: ", frame_index, " of ", frames.size() - 1)

func create_sword_fallback_sprite(sprite: Sprite2D):
	"""Create a fallback sword sprite"""
	print("Creating sword fallback sprite")
	
	# Create a simple sword shape
	var sword_rect = ColorRect.new()
	sword_rect.size = Vector2(8, 40)
	sword_rect.position = Vector2(-4, -20)
	sword_rect.color = Color(0.7, 0.7, 0.7, 1.0)
	sprite.add_child(sword_rect)
	
	sprite.scale = Vector2(0.5, 0.5)
	
	# Remove after 2 seconds using tween
	var tween = create_tween()
	tween.tween_delay(2.0)
	tween.tween_callback(sprite.queue_free)
	print("Fallback sword will be removed after 2 seconds")

func create_basic_sword_effect():
	"""Create a simple sword effect using ColorRect (guaranteed to work)"""
	print("=== CREATING SIMPLE SWORD EFFECT ===")
	
	# Create a sword shape using ColorRect (same approach as working red square)
	var sword_rect = ColorRect.new()
	sword_rect.name = "SimpleSwordEffect"
	sword_rect.size = Vector2(20, 80)  # Sword blade
	sword_rect.position = global_position - Vector2(10, 40)
	sword_rect.color = Color(0.7, 0.7, 0.7, 1.0)  # Gray sword
	sword_rect.z_index = 99999
	
	# Add to scene root (same approach as working red square)
	var scene_root = get_tree().current_scene
	scene_root.add_child(sword_rect)
	print("Created sword rectangle at: ", sword_rect.position)
	
	# Create a bright effect around it
	var effect_rect = ColorRect.new()
	effect_rect.name = "SwordEffect"
	effect_rect.size = Vector2(100, 100)
	effect_rect.position = global_position - Vector2(50, 50)
	effect_rect.color = Color(1, 1, 0, 0.3)  # Yellow glow
	effect_rect.z_index = 99998
	
	scene_root.add_child(effect_rect)
	print("Created sword effect glow at: ", effect_rect.position)
	
	# Remove after 2 seconds
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(sword_rect.queue_free)
	timer.timeout.connect(effect_rect.queue_free)
	scene_root.add_child(timer)
	timer.start()
	
	print("Simple sword effect should be visible!")

func create_working_sword_effect():
	"""Create a simple working sword effect using the approach that works"""
	print("=== CREATING WORKING SWORD EFFECT ===")
	
	# Create a sprite for the sword animation
	var sword_sprite = Sprite2D.new()
	sword_sprite.name = "WorkingSwordEffect"
	sword_sprite.position = Vector2.ZERO  # Position relative to player
	sword_sprite.z_index = 99999
	sword_sprite.visible = true
	
	# Add as child of player
	add_child(sword_sprite)
	print("Created working sword sprite")
	
	# Add a test rectangle to make sure the sprite is visible
	var test_rect = ColorRect.new()
	test_rect.size = Vector2(30, 30)
	test_rect.position = Vector2(-15, -15)
	test_rect.color = Color(1, 0, 0, 1.0)  # Bright red
	test_rect.z_index = 10000
	sword_sprite.add_child(test_rect)
	print("Added test rectangle to sword sprite")
	
	# Load the first sword frame
	var frame_path = "res://playerAnimations/swordslash/sword slash00.png"
	var frame = load(frame_path)
	
	if frame:
		sword_sprite.texture = frame
		sword_sprite.scale = Vector2(0.5, 0.5)
		print("✓ Loaded sword frame 0")
		
		# Create a simple animation by changing frames manually
		animate_sword_manually(sword_sprite)
	else:
		print("✗ Failed to load sword frame 0")
		# Create fallback
		create_simple_fallback(sword_sprite)

func animate_sword_manually(sprite: Sprite2D):
	"""Animate sword by manually changing frames"""
	print("Starting manual sword animation")
	
	# Load all frames
	var frames = []
	for i in range(12):
		var frame_number = str(i).pad_zeros(2)
		var frame_path = "res://playerAnimations/swordslash/sword slash" + frame_number + ".png"
		var frame = load(frame_path)
		if frame:
			frames.append(frame)
			print("✓ Pre-loaded frame ", i)
		else:
			print("✗ Failed to pre-load frame ", i)
	
	if frames.size() > 0:
		# Use a simple tween to animate through frames
		var tween = create_tween()
		tween.tween_method(update_sword_frame.bind(sprite, frames), 0.0, 1.0, 2.0)
		tween.tween_callback(sprite.queue_free)
		print("Started tween animation with ", frames.size(), " frames")
	else:
		print("No frames loaded, removing sprite")
		sprite.queue_free()

func update_sword_frame(sprite: Sprite2D, frames: Array, progress: float):
	"""Update sword frame based on progress"""
	if frames.size() > 0:
		var frame_index = int(progress * (frames.size() - 1))
		frame_index = clamp(frame_index, 0, frames.size() - 1)
		sprite.texture = frames[frame_index]
		print("Frame: ", frame_index, " of ", frames.size() - 1)

func create_simple_fallback(sprite: Sprite2D):
	"""Create a simple fallback effect"""
	print("Creating simple fallback")
	
	# Create a simple sword shape
	var sword_rect = ColorRect.new()
	sword_rect.size = Vector2(8, 40)
	sword_rect.position = Vector2(-4, -20)
	sword_rect.color = Color(0.7, 0.7, 0.7, 1.0)
	sprite.add_child(sword_rect)
	
	sprite.scale = Vector2(0.5, 0.5)
	
	# Remove after 2 seconds
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(sprite.queue_free)
	add_child(timer)
	timer.start()

func create_simple_test_effect():
	"""Create a very simple test effect to verify basic functionality"""
	print("=== CREATING SIMPLE TEST EFFECT ===")
	print("Player position: ", global_position)
	print("Player parent: ", get_parent())
	print("Player in scene tree: ", is_inside_tree())
	
	# Create a simple ColorRect directly in the scene
	var test_rect = ColorRect.new()
	test_rect.name = "SimpleTestEffect"
	test_rect.size = Vector2(200, 200)
	test_rect.position = global_position - Vector2(100, 100)
	test_rect.color = Color(1, 0, 0, 1.0)  # Bright red
	test_rect.z_index = 99999  # Very high z-index
	
	# Add directly to the scene root
	var scene_root = get_tree().current_scene
	scene_root.add_child(test_rect)
	
	print("Added test rectangle to scene root: ", scene_root)
	print("Test rectangle position: ", test_rect.position)
	print("Test rectangle size: ", test_rect.size)
	print("Test rectangle visible: ", test_rect.visible)
	print("Test rectangle in scene tree: ", test_rect.is_inside_tree())
	
	# Remove after 2 seconds
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(test_rect.queue_free)
	scene_root.add_child(timer)
	timer.start()
	
	print("Simple test effect should be VERY visible!")

func create_sword_animation_effect():
	"""Create the actual sword animation effect"""
	print("=== CREATING SWORD ANIMATION EFFECT ===")
	print("Player position: ", global_position)
	
	# Create a sprite for the sword animation
	var sword_sprite = Sprite2D.new()
	sword_sprite.name = "SwordAnimation"
	sword_sprite.position = Vector2.ZERO  # Position relative to parent
	sword_sprite.z_index = 99999  # Very high z-index
	sword_sprite.visible = true
	
	# Add as child of player so it moves with the player
	add_child(sword_sprite)
	print("Added sword sprite as child of player")
	
	# Load the sword animation frames
	var sword_frames = []
	for i in range(12):  # There are 12 frames (00-11)
		var frame_number = str(i).pad_zeros(2)  # Format as "00", "01", etc.
		var frame_path = "res://playerAnimations/swordslash/sword slash" + frame_number + ".png"
		var frame = load(frame_path)
		if frame:
			sword_frames.append(frame)
			print("✓ Loaded sword frame ", i, " from: ", frame_path)
		else:
			print("✗ Failed to load sword frame ", i, " from: ", frame_path)
	
	# Set up the sprite
	if sword_frames.size() > 0:
		sword_sprite.texture = sword_frames[0]
		sword_sprite.scale = Vector2(0.5, 0.5)  # Much smaller size
		sword_sprite.modulate = Color(1, 1, 1, 1)  # Full opacity
		print("Sword sprite set up with ", sword_frames.size(), " frames")
		print("Sword sprite scale: ", sword_sprite.scale)
		print("Sword sprite position: ", sword_sprite.position)
		print("Sword sprite visible: ", sword_sprite.visible)
		print("Sword sprite texture: ", sword_sprite.texture)
		
		# Animate through all frames over 2 seconds
		var tween = create_tween()
		tween.tween_method(animate_sword_frames.bind(sword_sprite, sword_frames), 0.0, 1.0, 2.0)
		tween.tween_callback(sword_sprite.queue_free)
		print("Playing sword animation over 2 seconds")
		
		# Add a bright test rectangle to make sure something appears
		var test_rect = ColorRect.new()
		test_rect.size = Vector2(50, 50)
		test_rect.position = Vector2(-25, -25)
		test_rect.color = Color(1, 0, 0, 1.0)  # Bright red
		test_rect.z_index = 10000
		sword_sprite.add_child(test_rect)
		print("Added test rectangle to sword sprite")
	else:
		print("No sword frames loaded, creating fallback...")
		# Create a simple fallback
		create_sword_fallback(sword_sprite)

func animate_sword_frames(sprite: Sprite2D, frames: Array, progress: float):
	"""Animate through the sword frames"""
	if frames.size() > 0:
		var frame_index = int(progress * (frames.size() - 1))
		frame_index = clamp(frame_index, 0, frames.size() - 1)
		sprite.texture = frames[frame_index]
		print("Sword frame: ", frame_index, " of ", frames.size() - 1)

func create_sword_fallback(sprite: Sprite2D):
	"""Create a simple fallback sword effect"""
	# Create a simple sword shape using ColorRect
	var sword_rect = ColorRect.new()
	sword_rect.size = Vector2(8, 40)  # Smaller sword
	sword_rect.position = Vector2(-4, -20)
	sword_rect.color = Color(0.7, 0.7, 0.7, 1.0)  # Gray sword
	sprite.add_child(sword_rect)
	
	# Create a bright effect
	var effect_rect = ColorRect.new()
	effect_rect.size = Vector2(60, 60)  # Smaller effect
	effect_rect.position = Vector2(-30, -30)
	effect_rect.color = Color(1, 1, 0, 0.5)  # Yellow glow
	sprite.add_child(effect_rect)
	
	sprite.scale = Vector2(0.5, 0.5)  # Smaller scale to match
	print("Created sword fallback effect")
	print("Fallback sprite scale: ", sprite.scale)
	print("Fallback sprite position: ", sprite.position)
	print("Fallback sprite visible: ", sprite.visible)
	
	# Remove after 2 seconds to match animation timing
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(sprite.queue_free)
	add_child(timer)
	timer.start()

func create_simple_sword_effect():
	"""Create a simple, guaranteed-visible sword slash effect"""
	print("=== CREATING SIMPLE SWORD EFFECT ===")
	
	# Create a bright red slash effect
	var slash_rect = ColorRect.new()
	slash_rect.name = "SimpleSlashEffect"
	slash_rect.size = Vector2(100, 20)
	slash_rect.position = global_position - Vector2(50, 10)
	slash_rect.color = Color(1, 0, 0, 1.0)  # Bright red
	slash_rect.z_index = 1000
	
	# Add to the scene
	get_parent().add_child(slash_rect)
	print("Created simple slash effect at: ", slash_rect.position)
	
	# Create a bright yellow circle
	var circle_rect = ColorRect.new()
	circle_rect.name = "SlashCircle"
	circle_rect.size = Vector2(60, 60)
	circle_rect.position = global_position - Vector2(30, 30)
	circle_rect.color = Color(1, 1, 0, 1.0)  # Bright yellow
	circle_rect.z_index = 1001
	
	# Add to the scene
	get_parent().add_child(circle_rect)
	print("Created slash circle at: ", circle_rect.position)
	
	# Animate the effects
	var tween = create_tween()
	tween.parallel()
	
	# Animate the slash rectangle
	tween.tween_property(slash_rect, "modulate:a", 0.0, 0.5)
	tween.tween_property(slash_rect, "scale", Vector2(2.0, 1.0), 0.5)
	
	# Animate the circle
	tween.tween_property(circle_rect, "modulate:a", 0.0, 0.5)
	tween.tween_property(circle_rect, "scale", Vector2(1.5, 1.5), 0.5)
	
	# Remove after animation
	tween.tween_callback(slash_rect.queue_free)
	tween.tween_callback(circle_rect.queue_free)
	
	print("Simple sword effect should be VERY visible!")

func create_test_slash_effect():
	"""Create a simple test effect that should definitely be visible"""
	print("=== CREATING TEST SLASH EFFECT ===")
	
	# Create a very simple, very visible test effect
	var test_rect = ColorRect.new()
	test_rect.size = Vector2(100, 100)
	test_rect.position = global_position - Vector2(50, 50)
	test_rect.color = Color(1, 0, 0, 1.0)  # Bright red
	test_rect.z_index = 1000
	
	# Add to the scene
	get_parent().add_child(test_rect)
	
	print("Created test red rectangle at: ", test_rect.position)
	
	# Remove it after 2 seconds
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(test_rect.queue_free)
	add_child(timer)
	timer.start()
	
	print("Test effect should be visible for 2 seconds!")

func create_fallback_slash_effect(slash_sprite: Sprite2D):
	"""Create a simple fallback sword slash effect when frames don't load"""
	print("Creating fallback sword slash effect...")
	
	# Create a simple colored rectangle as sword slash
	var backup_rect = ColorRect.new()
	backup_rect.size = Vector2(128, 128)
	backup_rect.position = Vector2(-64, -64)
	backup_rect.color = Color(1, 0, 0, 1.0)  # Bright red rectangle
	slash_sprite.add_child(backup_rect)
	
	# Create a simple sword shape
	var sword_rect = ColorRect.new()
	sword_rect.size = Vector2(16, 80)
	sword_rect.position = Vector2(-8, -40)
	sword_rect.color = Color(1, 1, 1, 1.0)  # White sword
	slash_sprite.add_child(sword_rect)
	
	# Create a bright yellow circle
	var circle_rect = ColorRect.new()
	circle_rect.size = Vector2(64, 64)
	circle_rect.position = Vector2(-32, -32)
	circle_rect.color = Color(1, 1, 0, 1.0)  # Bright yellow circle
	slash_sprite.add_child(circle_rect)
	
	print("Created fallback sword slash effect - should be VERY visible!")

func update_slash_frame(slash_sprite: Sprite2D, slash_frames: Array, progress: float):
	"""Update the slash sprite animation frame based on progress (0.0 to 1.0)"""
	# Update animation frame based on progress
	if slash_frames.size() > 0:
		var frame_index = int(progress * (slash_frames.size() - 1))
		frame_index = clamp(frame_index, 0, slash_frames.size() - 1)
		slash_sprite.texture = slash_frames[frame_index]
		print("Slash frame updated: ", frame_index, " of ", slash_frames.size() - 1, " (progress: ", progress, ")")
	else:
		print("No slash frames available for animation")

func check_slash_hits(item):
	"""Check if slash hits any enemies or destructible objects"""
	var space_state = get_world_2d().direct_space_state
	var slash_pos = global_position + slash_direction * (item.range / 2.0)
	
	# Create a query for the slash area
	var query = PhysicsPointQueryParameters2D.new()
	query.position = slash_pos
	query.collision_mask = 8  # Enemies on layer 8
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var results = space_state.intersect_point(query)
	
	for result in results:
		var target = result.collider
		if target.has_method("take_damage"):
			target.take_damage(item.damage)
			print("Sword hit for ", item.damage, " damage!")

func _on_slash_hitbox_body_entered(body):
	"""Handle when an enemy enters the slash hitbox"""
	# Don't hit the player
	if body == self:
		return
	
	# Check if this enemy has already been hit by this slash
	if body in hit_enemies:
		return
	
	# Add to hit list to prevent multiple hits
	hit_enemies.append(body)
	
	# Check if it's an enemy that can take damage
	if body.has_method("take_damage"):
		print("Slash hit enemy: ", body.name)
		# Get the sword damage from the current selected item
		if selected_slot >= 0 and selected_slot < 9:
			var item = hotbar_slots[selected_slot]
			if item != null and item.type == "sword":
				body.take_damage(item.damage)

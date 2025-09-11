extends ColorRect

var player
var spotlight_enabled = true
var ray_count = 40
var max_ray_distance = 150.0
var num_rays = 40  # Reduced for better performance
var ray_thickness = 15  # Reduced thickness for better performance
var visibility_texture: ImageTexture
var debug_mode = false
var tutorial_system: Control

# Removed complex ray casting - now using simple 8-direction approach

func _ready():
	# Make it dark overlay
	color = Color(0, 0, 0, 0.8)  # Dark overlay
	visible = true
	
	# Find the player node after everything is ready
	call_deferred("find_player")
	print("Spotlight ready, searching for player...")
	
	# Create visibility texture
	visibility_texture = ImageTexture.new()
	create_visibility_texture()
	
	# Create shader that uses only ray casting visibility texture
	var shader_code = "shader_type canvas_item; uniform sampler2D visibility_texture; void fragment() { vec4 visibility_color = texture(visibility_texture, UV); COLOR = vec4(0.0, 0.0, 0.0, visibility_color.a); }"
	var shader = Shader.new()
	shader.code = shader_code
	material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("visibility_texture", visibility_texture)

func find_player():
	# Try different possible paths for the player
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
			print("Player found at path: ", path)
			break
	
	# Also find tutorial system
	tutorial_system = get_node_or_null("../TutorialSystem")
	if not tutorial_system:
		tutorial_system = get_node_or_null("../../TutorialSystem")
	
	if not player:
		print("Player not found at any path!")

func create_visibility_texture():
	# Create a much smaller texture for better performance
	var image = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 1.0))  # Start with dark overlay
	
	if player:
		var player_pos = player.global_position
		var space_state = get_world_2d().direct_space_state
		
		# Use a simple circle approach instead of individual rays
		draw_circle_visibility(image, player_pos, space_state)
	
	visibility_texture.set_image(image)

func draw_circle_visibility(image: Image, player_pos: Vector2, space_state: PhysicsDirectSpaceState2D):
	"""Draw visibility using a simple circle approach - much faster than rays"""
	var texture_size = 256
	var center_world = player_pos
	var world_to_texture_scale = 0.5  # Even smaller scale for performance
	
	# Generate ray directions based on num_rays variable
	var ray_directions = []
	for i in range(num_rays):
		var angle = (i * 2.0 * PI) / num_rays
		var direction = Vector2(cos(angle), sin(angle))
		ray_directions.append(direction)
	
	for direction in ray_directions:
		var end_pos = player_pos + direction * max_ray_distance
		
		# Cast ray
		var query = PhysicsRayQueryParameters2D.new()
		query.from = player_pos
		query.to = end_pos
		query.collision_mask = 1
		query.collide_with_areas = false
		query.collide_with_bodies = true
		
		var result = space_state.intersect_ray(query)
		var hit_pos = end_pos
		if result:
			hit_pos = result.position
		
		# Draw a thick line using Godot's built-in method
		draw_thick_line_fast(image, player_pos, hit_pos, center_world, world_to_texture_scale, texture_size)

func draw_thick_line_fast(image: Image, start: Vector2, end: Vector2, center_world: Vector2, scale: float, texture_size: int):
	"""Fast thick line drawing using simple approach"""
	var tex_start = Vector2(
		(start.x - center_world.x) * scale + texture_size / 2,
		(start.y - center_world.y) * scale + texture_size / 2
	)
	var tex_end = Vector2(
		(end.x - center_world.x) * scale + texture_size / 2,
		(end.y - center_world.y) * scale + texture_size / 2
	)
	
	# Draw a simple thick line by drawing multiple parallel lines
	var direction = (tex_end - tex_start).normalized()
	var perp = Vector2(-direction.y, direction.x)
	var thickness = ray_thickness  # Use the configurable thickness variable
	
	for i in range(thickness):
		var offset = perp * (i - thickness / 2.0)
		var start_offset = tex_start + offset
		var end_offset = tex_end + offset
		
		# Use a simple line drawing approach
		draw_simple_line(image, start_offset, end_offset, texture_size)

func draw_simple_line(image: Image, start: Vector2, end: Vector2, texture_size: int):
	"""Optimized line drawing to prevent black dots without lag"""
	var steps = int(start.distance_to(end))
	if steps == 0:
		return
		
	# Limit steps to prevent lag
	steps = min(steps, 180)  # Maximum 20 steps
	var step = 1.0 / steps
	
	for i in range(steps + 1):
		var t = i * step
		var pos = start.lerp(end, t)
		var x = int(round(pos.x))
		var y = int(round(pos.y))
		
		# Only draw the main pixel, no extra circles to reduce lag
		if x >= 0 and x < texture_size and y >= 0 and y < texture_size:
			image.set_pixel(x, y, Color(0, 0, 0, 0))  # Transparent for visible areas

# Removed complex Bresenham line drawing - now using simple linear interpolation

var update_counter = 0
var last_player_position = Vector2.ZERO
var position_threshold = 5.0  # Only update if player moved more than 5 pixels

func _process(_delta):
	if player and spotlight_enabled:
		var current_pos = player.global_position
		var distance_moved = current_pos.distance_to(last_player_position)
		
		# Only update if player moved significantly or every 10 frames
		update_counter += 1
		if distance_moved > position_threshold or update_counter % 10 == 0:
			create_visibility_texture()
			last_player_position = current_pos
	else:
		print("Spotlight process: player=", player != null, " enabled=", spotlight_enabled)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Z:
			spotlight_enabled = !spotlight_enabled
			visible = spotlight_enabled
			
			# Notify tutorial system of lighting toggle
			if tutorial_system:
				tutorial_system.check_tutorial_action("lighting")
		elif event.keycode == KEY_2:
			debug_mode = !debug_mode
			print("Debug mode: ", debug_mode)

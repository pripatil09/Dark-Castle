extends ColorRect

var player
var spotlight_enabled = true
var ray_count = 24
var max_ray_distance = 120.0
var visibility_texture: ImageTexture
var debug_mode = false

func cast_ray(image: Image, start_pos: Vector2, angle: float, space_state: PhysicsDirectSpaceState2D):
	"""Cast a single ray and draw the visibility line"""
	var direction = Vector2(cos(angle), sin(angle))
	var end_pos = start_pos + direction * max_ray_distance
	
	var query = PhysicsRayQueryParameters2D.new()
	query.from = start_pos
	query.to = end_pos
	query.collision_mask = 1  # Collide with layer 1 (walls)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = false
	
	# Debug: check if we're hitting anything
	if debug_mode and angle == 0:  # Only debug one ray to avoid spam
		print("Ray from ", start_pos, " to ", end_pos, " collision_mask: ", query.collision_mask)
	
	var result = space_state.intersect_ray(query)
	var hit_pos = end_pos
	var hit_normal = Vector2.ZERO
	var hit = false
	
	if result:
		hit_pos = result.position
		# Calculate normal from hit position and direction
		var hit_direction = (hit_pos - start_pos).normalized()
		hit_normal = hit_direction
		hit = true
		# Debug: print when we hit something
		if debug_mode:
			print("Ray hit at: ", hit_pos, " from: ", start_pos, " angle: ", angle)
	
	draw_visibility_line(image, start_pos, hit_pos)
	
	return {
		"hit_pos": hit_pos,
		"hit_normal": hit_normal,
		"hit": hit
	}

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
			return
	
	print("Player not found at any path!")

func create_visibility_texture():
	var image = Image.create(1024, 1024, false, Image.FORMAT_RGBA8)  # Higher resolution for accuracy
	image.fill(Color(0, 0, 0, 1.0))  # Start with dark overlay
	
	if player:
		var player_pos = player.global_position
		var space_state = get_world_2d().direct_space_state
		
		if debug_mode:
			print("Creating visibility texture at player pos: ", player_pos)
			print("Ray distance: ", max_ray_distance)
		
		# High-quality ray casting for accurate shadows
		var base_ray_count = 720  # More rays for better coverage
		var hit_count = 0
		
		# Cast primary rays in all directions
		for i in range(base_ray_count):
			var angle = (i * 2.0 * PI) / base_ray_count
			var result = cast_ray(image, player_pos, angle, space_state)
			if result and result.hit:
				hit_count += 1
		
		# Additional edge rays for better wall definition
		var edge_ray_count = 180
		for i in range(edge_ray_count):
			var angle = (i * 2.0 * PI) / edge_ray_count
			var result = cast_ray(image, player_pos, angle, space_state)
			if result and result.hit:
				hit_count += 1
		
		if debug_mode:
			print("Total ray hits: ", hit_count, " out of ", base_ray_count + edge_ray_count, " rays")
	
	visibility_texture.set_image(image)

func draw_visibility_line(image: Image, world_start: Vector2, world_end: Vector2):
	# Convert world coordinates to texture coordinates directly
	# Use the player position as the center of our visibility texture
	var center_world = player.global_position
	var texture_size = 1024  # Match the higher resolution
	var world_to_texture_scale = 2.0  # Higher scale for better precision
	
	var tex_start = Vector2(
		(world_start.x - center_world.x) * world_to_texture_scale + texture_size / 2,
		(world_start.y - center_world.y) * world_to_texture_scale + texture_size / 2
	)
	var tex_end = Vector2(
		(world_end.x - center_world.x) * world_to_texture_scale + texture_size / 2,
		(world_end.y - center_world.y) * world_to_texture_scale + texture_size / 2
	)
	
	# Use Bresenham's line algorithm for accurate pixel-perfect lines
	draw_bresenham_line(image, tex_start, tex_end, texture_size)

func draw_bresenham_line(image: Image, start: Vector2, end: Vector2, texture_size: int):
	"""Draw a pixel-perfect line using Bresenham's algorithm"""
	var x0 = int(start.x)
	var y0 = int(start.y)
	var x1 = int(end.x)
	var y1 = int(end.y)
	
	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy
	
	var x = x0
	var y = y0
	
	while true:
		if x >= 0 and x < texture_size and y >= 0 and y < texture_size:
			image.set_pixel(x, y, Color(0, 0, 0, 0))  # Transparent for visible areas
		
		if x == x1 and y == y1:
			break
		
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy

var update_counter = 0
func _process(_delta):
	if player and spotlight_enabled:
		# Update visibility texture less frequently for better performance
		update_counter += 1
		if update_counter % 3 == 0:  # Update every 3 frames
			create_visibility_texture()
	else:
		print("Spotlight process: player=", player != null, " enabled=", spotlight_enabled)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Z:
			spotlight_enabled = !spotlight_enabled
			visible = spotlight_enabled
		elif event.keycode == KEY_2:
			debug_mode = !debug_mode
			print("Debug mode: ", debug_mode)

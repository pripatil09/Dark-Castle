extends ColorRect

var player
var spotlight_enabled = true
var ray_count = 24
var max_ray_distance = 120.0
var visibility_texture: ImageTexture

func cast_ray(image: Image, start_pos: Vector2, angle: float, space_state: PhysicsDirectSpaceState2D):
	"""Cast a single ray and draw the visibility line"""
	var direction = Vector2(cos(angle), sin(angle))
	var end_pos = start_pos + direction * max_ray_distance
	
	var query = PhysicsRayQueryParameters2D.new()
	query.from = start_pos
	query.to = end_pos
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = false
	
	var result = space_state.intersect_ray(query)
	var hit_pos = end_pos
	if result:
		hit_pos = result.position
	
	draw_visibility_line(image, start_pos, hit_pos)

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
	var image = Image.create(512, 512, false, Image.FORMAT_RGBA8)  # Lower resolution for better performance
	image.fill(Color(0, 0, 0, 1.0))  # Start with dark overlay
	
	if player:
		var player_pos = player.global_position
		var space_state = get_world_2d().direct_space_state
		
		# Adaptive ray casting - more rays near walls and corners
		var base_ray_count = 700
		var corner_rays = 16
		var wall_rays = 32
		var hit_count = 0
		
		# Cast base rays in all directions
		for i in range(base_ray_count):
			var angle = (i * 2.0 * PI) / base_ray_count
			cast_ray(image, player_pos, angle, space_state)
		
		# Cast additional rays near walls for better edge detection
		for i in range(wall_rays):
			var angle = (i * 2.0 * PI) / wall_rays
			var direction = Vector2(cos(angle), sin(angle))
			var end_pos = player_pos + direction * max_ray_distance
			
			var query = PhysicsRayQueryParameters2D.new()
			query.from = player_pos
			query.to = end_pos
			query.collision_mask = 1
			query.collide_with_areas = false
			query.collide_with_bodies = true
			query.hit_from_inside = false
			
			var result = space_state.intersect_ray(query)
			if result:
				# Cast additional rays near the hit point for better edge definition
				var hit_pos = result.position
				var normal = result.normal
				var edge_angle = atan2(normal.y, normal.x)
				
				# Cast rays at slight angles around the edge
				for j in range(corner_rays):
					var edge_offset = (j - corner_rays/2) * 0.1  # Small angle offset
					cast_ray(image, player_pos, edge_angle + edge_offset, space_state)
	
	visibility_texture.set_image(image)

func draw_visibility_line(image: Image, world_start: Vector2, world_end: Vector2):
	# Convert world coordinates to texture coordinates directly
	# Use the player position as the center of our visibility texture
	var center_world = player.global_position
	var texture_size = 512  # Match the image size
	var world_to_texture_scale = 1.0  # Smaller scale for more precise mapping
	
	var tex_start = Vector2(
		(world_start.x - center_world.x) * world_to_texture_scale + texture_size / 2,
		(world_start.y - center_world.y) * world_to_texture_scale + texture_size / 2
	)
	var tex_end = Vector2(
		(world_end.x - center_world.x) * world_to_texture_scale + texture_size / 2,
		(world_end.y - center_world.y) * world_to_texture_scale + texture_size / 2
	)
	
	# Draw very thin, precise rays
	var steps = int(tex_start.distance_to(tex_end)) * 2  # More steps for precision
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var pos = tex_start.lerp(tex_end, t)
		
		if pos.x >= 0 and pos.x < texture_size and pos.y >= 0 and pos.y < texture_size:
			# Only mark the exact pixel, not surrounding area
			image.set_pixel(int(pos.x), int(pos.y), Color(0, 0, 0, 0))  # Transparent for visible areas

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
		if event.keycode == KEY_1:
			spotlight_enabled = !spotlight_enabled
			visible = spotlight_enabled

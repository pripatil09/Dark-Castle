extends ColorRect

var player
var lighting_enabled = true
var light_radius = 200.0
var visibility_texture: ImageTexture
var dungeon_generator: Node2D

func _ready():
	# Make it dark overlay
	color = Color(0, 0, 0, 0.8)
	visible = true
	
	# Find the player and dungeon generator
	call_deferred("find_nodes")
	
	# Create visibility texture
	visibility_texture = ImageTexture.new()
	create_visibility_texture()

func find_nodes():
	"""Find player and dungeon generator nodes"""
	player = get_node("../Player")
	dungeon_generator = get_node("../DungeonGenerator")
	print("Distance field lighting ready!")

func create_visibility_texture():
	"""Create visibility using distance field approach - much faster than ray casting"""
	var texture_size = 512  # Smaller for better performance
	var image = Image.create(texture_size, texture_size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 1.0))  # Start with dark overlay
	
	if player and dungeon_generator:
		var player_pos = player.global_position
		var tile_size = 24  # Match dungeon generator tile size
		
		# Calculate distance field for each pixel
		for y in range(texture_size):
			for x in range(texture_size):
				# Convert texture coordinates to world coordinates
				var world_x = (x - texture_size/2) + player_pos.x
				var world_y = (y - texture_size/2) + player_pos.y
				
				# Calculate distance to nearest wall
				var distance_to_wall = calculate_distance_to_wall(Vector2(world_x, world_y))
				
				# Create visibility based on distance
				var visibility = 1.0 - clamp(distance_to_wall / light_radius, 0.0, 1.0)
				visibility = smoothstep(0.0, 1.0, visibility)  # Smooth falloff
				
				# Set pixel color (transparent = visible, opaque = dark)
				var alpha = 1.0 - visibility
				image.set_pixel(x, y, Color(0, 0, 0, alpha))
	
	visibility_texture.set_image(image)

func calculate_distance_to_wall(pos: Vector2) -> float:
	"""Calculate distance to nearest wall using tile-based approach"""
	if not dungeon_generator:
		return 0.0
	
	# Get tile coordinates
	var tile_x = int(pos.x / 24)  # 24 is tile_size
	var tile_y = int(pos.y / 24)
	
	# Check if position is inside a wall tile
	if is_wall_tile(tile_x, tile_y):
		return 0.0
	
	# Search outward in expanding squares
	var max_search_radius = int(light_radius / 24) + 1
	
	for radius in range(1, max_search_radius + 1):
		# Check all tiles at this radius
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				# Only check tiles on the perimeter of the square
				if abs(dx) == radius or abs(dy) == radius:
					var check_x = tile_x + dx
					var check_y = tile_y + dy
					
					if is_wall_tile(check_x, check_y):
						# Calculate exact distance to this wall tile
						var wall_center = Vector2(check_x * 24 + 12, check_y * 24 + 12)
						var distance = pos.distance_to(wall_center)
						return distance
	
	return light_radius  # No wall found within radius

func is_wall_tile(tile_x: int, tile_y: int) -> bool:
	"""Check if a tile is a wall"""
	if not dungeon_generator:
		return false
	
	# Access the dungeon map directly
	var dungeon_map = dungeon_generator.dungeon_map
	if not dungeon_map or tile_y < 0 or tile_y >= dungeon_map.size():
		return true  # Out of bounds = wall
	
	if tile_x < 0 or tile_x >= dungeon_map[0].size():
		return true  # Out of bounds = wall
	
	# 0 = floor, 1 = wall
	return dungeon_map[tile_y][tile_x] == 1

var update_counter = 0
func _process(_delta):
	if player and lighting_enabled:
		# Update less frequently for better performance
		update_counter += 1
		if update_counter % 10 == 0:  # Update every 10 frames
			create_visibility_texture()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			lighting_enabled = !lighting_enabled
			visible = lighting_enabled

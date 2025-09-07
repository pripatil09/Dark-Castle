extends ColorRect

var player
var lighting_enabled = true
var light_radius_tiles = 8  # Light radius in tiles
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
	print("Tile-based lighting ready!")

func create_visibility_texture():
	"""Create visibility using tile-based approach - extremely fast"""
	var texture_size = 512
	var image = Image.create(texture_size, texture_size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 1.0))  # Start with dark overlay
	
	if player and dungeon_generator:
		var player_pos = player.global_position
		var tile_size = 24
		
		# Get player tile position
		var player_tile_x = int(player_pos.x / tile_size)
		var player_tile_y = int(player_pos.y / tile_size)
		
		# Create visibility map for tiles around player
		var visibility_map = {}
		
		# Use flood fill algorithm to find visible tiles
		var queue = []
		queue.append(Vector2i(player_tile_x, player_tile_y))
		visibility_map[Vector2i(player_tile_x, player_tile_y)] = 1.0
		
		while queue.size() > 0:
			var current_tile = queue.pop_front()
			var current_distance = visibility_map[current_tile]
			
			# Check all 8 directions
			var directions = [
				Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
				Vector2i(-1, 0),                  Vector2i(1, 0),
				Vector2i(-1, 1),  Vector2i(0, 1),  Vector2i(1, 1)
			]
			
			for dir in directions:
				var new_tile = current_tile + dir
				var distance = current_distance + dir.length()
				
				# Skip if too far or already processed
				if distance > light_radius_tiles or visibility_map.has(new_tile):
					continue
				
				# Check if tile is walkable (not a wall)
				if is_tile_walkable(new_tile.x, new_tile.y):
					# Calculate visibility based on distance
					var visibility = 1.0 - (distance / light_radius_tiles)
					visibility = smoothstep(0.0, 1.0, visibility)
					visibility_map[new_tile] = visibility
					queue.append(new_tile)
		
		# Draw the visibility map to texture with smooth interpolation
		for y in range(texture_size):
			for x in range(texture_size):
				# Convert texture coordinates to world coordinates
				var world_x = (x - texture_size/2) + player_pos.x
				var world_y = (y - texture_size/2) + player_pos.y
				
				# Get tile coordinates
				var tile_x = int(world_x / tile_size)
				var tile_y = int(world_y / tile_size)
				var tile_key = Vector2i(tile_x, tile_y)
				
				# Get visibility for this tile
				var visibility = visibility_map.get(tile_key, 0.0)
				
				# Add smooth interpolation between tiles
				var tile_center_x = tile_x * tile_size + tile_size/2
				var tile_center_y = tile_y * tile_size + tile_size/2
				var distance_from_center = Vector2(world_x - tile_center_x, world_y - tile_center_y).length()
				var max_distance = tile_size / 2.0
				var interpolation_factor = 1.0 - clamp(distance_from_center / max_distance, 0.0, 1.0)
				
				# Blend with neighboring tiles for smoother edges
				var final_visibility = visibility * interpolation_factor
				
				# Set pixel color
				var alpha = 1.0 - final_visibility
				image.set_pixel(x, y, Color(0, 0, 0, alpha))
	
	visibility_texture.set_image(image)

func is_tile_walkable(tile_x: int, tile_y: int) -> bool:
	"""Check if a tile is walkable (not a wall)"""
	if not dungeon_generator:
		return false
	
	var dungeon_map = dungeon_generator.dungeon_map
	if not dungeon_map or tile_y < 0 or tile_y >= dungeon_map.size():
		return false  # Out of bounds = not walkable
	
	if tile_x < 0 or tile_x >= dungeon_map[0].size():
		return false  # Out of bounds = not walkable
	
	# 0 = floor (walkable), 1 = wall (not walkable)
	return dungeon_map[tile_y][tile_x] == 0

var update_counter = 0
func _process(_delta):
	if player and lighting_enabled:
		# Update less frequently for better performance
		update_counter += 1
		if update_counter % 15 == 0:  # Update every 15 frames
			create_visibility_texture()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			lighting_enabled = !lighting_enabled
			visible = lighting_enabled

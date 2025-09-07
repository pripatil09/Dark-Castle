extends Node2D

# Procedural Dungeon Generator
# Creates unique dungeon layouts with rooms, corridors, and special areas

@export var dungeon_width = 200
@export var dungeon_height = 100
@export var room_size_min = 6
@export var room_size_max = 15
@export var max_rooms = 70

var tile_size = 24
var dungeon_map = []
var rooms = []
var corridors = []

func _ready():
	generate_dungeon()

# Removed input handling - dungeon regeneration should be controlled elsewhere

func generate_dungeon():
	
	# Clear previous dungeon
	rooms.clear()
	corridors.clear()
	
	# Initialize empty dungeon
	initialize_dungeon()
	
	# Generate rooms
	generate_rooms()
	
	# Connect rooms with corridors
	connect_rooms()
	
	# Add special rooms
	add_special_rooms()
	
	# Render the dungeon
	render_dungeon()
	

func initialize_dungeon():
	# Fill with walls
	dungeon_map = []
	for y in range(dungeon_height):
		dungeon_map.append([])
		for x in range(dungeon_width):
			dungeon_map[y].append(1)  # 1 = wall, 0 = floor

func generate_rooms():
	var attempts = 0
	var max_attempts = 1000
	
	
	# Start with simple rectangle rooms only to ensure they work
	while rooms.size() < max_rooms and attempts < max_attempts:
		attempts += 1
		
		# Generate a simple rectangle room
		var new_room = generate_rectangle_room()
		
		if new_room != null:
			# Check if room overlaps with existing rooms (minimal buffer)
			var buffer_room = Rect2(new_room.position.x - 1, new_room.position.y - 1, new_room.size.x + 2, new_room.size.y + 2)
			var overlaps = false
			
			for room in rooms:
				var buffer_existing = Rect2(room.position.x - 1, room.position.y - 1, room.size.x + 2, room.size.y + 2)
				if buffer_room.intersects(buffer_existing):
					overlaps = true
					break
			
			if not overlaps:
				rooms.append(new_room)
				# Carve out the room
				carve_room(new_room)
	

func generate_rectangle_room() -> Rect2:
	# Standard rectangle room
	var room_width = randi_range(room_size_min, room_size_max)
	var room_height = randi_range(room_size_min, room_size_max)
	
	# 20% chance for larger rooms
	if randf() < 0.2:
		room_width = randi_range(room_size_max, room_size_max + 4)
		room_height = randi_range(room_size_max, room_size_max + 4)
	
	var x = randi_range(1, dungeon_width - room_width - 1)
	var y = randi_range(1, dungeon_height - room_height - 1)
	
	# Debug output
	
	return Rect2(x, y, room_width, room_height)

func generate_l_shaped_room() -> Rect2:
	# L-shaped room
	var base_width = randi_range(room_size_min, room_size_max)
	var base_height = randi_range(room_size_min, room_size_max)
	var arm_width = max(2, randi_range(room_size_min/2, room_size_max/2))
	var arm_height = max(2, randi_range(room_size_min/2, room_size_max/2))
	
	var x = randi_range(1, dungeon_width - base_width - arm_width - 1)
	var y = randi_range(1, dungeon_height - base_height - arm_height - 1)
	
	# Ensure we don't go out of bounds
	if x < 1 or y < 1 or x + base_width + arm_width >= dungeon_width - 1 or y + base_height + arm_height >= dungeon_height - 1:
		# Return a fallback rectangle room instead of null
		return generate_rectangle_room()
	
	# Create L-shape by combining two rectangles
	var room = Rect2(x, y, base_width, base_height)
	carve_room(room)
	
	# Add the arm
	var arm_x = x + base_width - arm_width
	var arm_y = y + base_height - arm_height
	var arm_room = Rect2(arm_x, arm_y, arm_width, arm_height)
	carve_room(arm_room)
	
	# Return the bounding box
	return Rect2(x, y, base_width + arm_width, base_height + arm_height)

func generate_t_shaped_room() -> Rect2:
	# T-shaped room
	var stem_width = max(2, randi_range(room_size_min/2, room_size_max/2))
	var stem_height = randi_range(room_size_min, room_size_max)
	var top_width = randi_range(room_size_min, room_size_max)
	var top_height = max(2, randi_range(room_size_min/2, room_size_max/2))
	
	var x = randi_range(1, dungeon_width - max(stem_width, top_width) - 1)
	var y = randi_range(1, dungeon_height - stem_height - top_height - 1)
	
	# Ensure we don't go out of bounds
	if x < 1 or y < 1 or x + max(stem_width, top_width) >= dungeon_width - 1 or y + stem_height + top_height >= dungeon_height - 1:
		# Return a fallback rectangle room instead of null
		return generate_rectangle_room()
	
	# Create T-shape
	var stem = Rect2(x + (top_width - stem_width) / 2, y, stem_width, stem_height)
	var top = Rect2(x, y + stem_height, top_width, top_height)
	
	carve_room(stem)
	carve_room(top)
	
	# Return the bounding box
	return Rect2(x, y, top_width, stem_height + top_height)

func generate_cross_shaped_room() -> Rect2:
	# Cross-shaped room
	var center_size = max(2, randi_range(room_size_min/2, room_size_max/2))
	var arm_length = max(2, randi_range(room_size_min/2, room_size_max/2))
	
	var x = randi_range(1, dungeon_width - center_size - arm_length * 2 - 1)
	var y = randi_range(1, dungeon_height - center_size - arm_length * 2 - 1)
	
	# Ensure we don't go out of bounds
	if x < 1 or y < 1 or x + center_size + arm_length * 2 >= dungeon_width - 1 or y + center_size + arm_length * 2 >= dungeon_height - 1:
		# Return a fallback rectangle room instead of null
		return generate_rectangle_room()
	
	# Create cross shape
	var center = Rect2(x + arm_length, y + arm_length, center_size, center_size)
	var top = Rect2(x + arm_length, y, center_size, arm_length)
	var bottom = Rect2(x + arm_length, y + arm_length + center_size, center_size, arm_length)
	var left = Rect2(x, y + arm_length, arm_length, center_size)
	var right = Rect2(x + arm_length + center_size, y + arm_length, arm_length, center_size)
	
	carve_room(center)
	carve_room(top)
	carve_room(bottom)
	carve_room(left)
	carve_room(right)
	
	# Return the bounding box
	return Rect2(x, y, center_size + arm_length * 2, center_size + arm_length * 2)

func carve_room(room: Rect2):
	# Convert room to floor tiles
	for room_x in range(room.position.x, room.position.x + room.size.x):
		for room_y in range(room.position.y, room.position.y + room.size.y):
			if room_x >= 0 and room_x < dungeon_width and room_y >= 0 and room_y < dungeon_height:
				dungeon_map[room_y][room_x] = 0  # Floor

func connect_rooms():
	# Use a more efficient connection algorithm
	# First, create a minimum spanning tree to ensure all rooms are connected
	connect_rooms_mst()
	
	# Add a few random connections for variety (but not too many)
	add_random_connections()

func connect_rooms_mst():
	# Minimum Spanning Tree approach - connects all rooms with minimal corridors
	if rooms.size() <= 1:
		return
	
	var connected_rooms = [0]  # Start with first room
	var unconnected_rooms = []
	for i in range(1, rooms.size()):
		unconnected_rooms.append(i)
	
	# Connect all rooms using minimum spanning tree
	while unconnected_rooms.size() > 0:
		var min_distance = INF
		var best_connected = -1
		var best_unconnected = -1
		
		# Find the closest unconnected room to any connected room
		for connected_idx in connected_rooms:
			for unconnected_idx in unconnected_rooms:
				var room1 = rooms[connected_idx]
				var room2 = rooms[unconnected_idx]
				var distance = room1.get_center().distance_to(room2.get_center())
				
				if distance < min_distance:
					min_distance = distance
					best_connected = connected_idx
					best_unconnected = unconnected_idx
		
		# Connect the closest rooms
		if best_connected != -1 and best_unconnected != -1:
			var room1 = rooms[best_connected]
			var room2 = rooms[best_unconnected]
			create_corridor(room1.get_center(), room2.get_center())
			
			connected_rooms.append(best_unconnected)
			unconnected_rooms.erase(best_unconnected)

func add_random_connections():
	# Add a few random connections for variety (10% of total rooms)
	var num_random_connections = max(1, rooms.size() / 10)
	
	for i in range(num_random_connections):
		var room1_idx = randi() % rooms.size()
		var room2_idx = randi() % rooms.size()
		
		if room1_idx != room2_idx:
			var room1 = rooms[room1_idx]
			var room2 = rooms[room2_idx]
			create_corridor(room1.get_center(), room2.get_center())

func create_corridor(start: Vector2, end: Vector2):
	# Create 3-tile wide corridors so player can fit through
	# Horizontal corridor first
	var x1 = int(start.x)
	var x2 = int(end.x)
	var corridor_y = int(start.y)
	
	for corridor_x in range(min(x1, x2), max(x1, x2) + 1):
		if corridor_x >= 0 and corridor_x < dungeon_width and corridor_y >= 0 and corridor_y < dungeon_height:
			dungeon_map[corridor_y][corridor_x] = 0
			corridors.append(Vector2(corridor_x, corridor_y))
			# Make corridor wider (3 tiles wide)
			if corridor_y > 0:
				dungeon_map[corridor_y - 1][corridor_x] = 0
			if corridor_y < dungeon_height - 1:
				dungeon_map[corridor_y + 1][corridor_x] = 0
	
	# Then vertical corridor
	var vert_x = int(end.x)
	var y1 = int(start.y)
	var y2 = int(end.y)
	
	for vert_y in range(min(y1, y2), max(y1, y2) + 1):
		if vert_x >= 0 and vert_x < dungeon_width and vert_y >= 0 and vert_y < dungeon_height:
			dungeon_map[vert_y][vert_x] = 0
			corridors.append(Vector2(vert_x, vert_y))
			# Make corridor wider (3 tiles wide)
			if vert_x > 0:
				dungeon_map[vert_y][vert_x - 1] = 0
			if vert_x < dungeon_width - 1:
				dungeon_map[vert_y][vert_x + 1] = 0

func add_special_rooms():
	# Add treasure room
	if rooms.size() > 3:
		var treasure_room = rooms[rooms.size() - 1]
		add_treasure_room(treasure_room)
	
	# Add boss room
	if rooms.size() > 2:
		var boss_room = rooms[0]  # First room becomes boss room
		add_boss_room(boss_room)

func add_treasure_room(room: Rect2):
	# Add treasure chest in center
	var center = room.get_center()
	var chest_pos = Vector2(int(center.x), int(center.y))
	# Mark as treasure room (we'll handle this in rendering)

func add_boss_room(room: Rect2):
	# Mark as boss room
	var center = room.get_center()

func render_dungeon():
	# Clear existing tiles
	for child in get_children():
		child.queue_free()
	
	# Render each tile
	var floor_count = 0
	var wall_count = 0
	for render_y in range(dungeon_height):
		for render_x in range(dungeon_width):
			var tile_type = dungeon_map[render_y][render_x]
			create_tile(render_x, render_y, tile_type)
			if tile_type == 0:
				floor_count += 1
			else:
				wall_count += 1
	

func create_tile(x: int, y: int, tile_type: int):
	var tile = ColorRect.new()
	tile.size = Vector2(tile_size, tile_size)
	tile.position = Vector2(x * tile_size, y * tile_size)
	
	match tile_type:
		0:  # Floor
			tile.color = Color(0.3, 0.3, 0.3)  # Dark gray
		1:  # Wall
			tile.color = Color(0.1, 0.1, 0.1)  # Very dark gray
			# Add collision for walls
			var collision = StaticBody2D.new()
			collision.collision_layer = 1  # Set collision layer to 1
			collision.collision_mask = 0   # Walls don't need to collide with anything
			var collision_shape = CollisionShape2D.new()
			var rectangle_shape = RectangleShape2D.new()
			rectangle_shape.size = Vector2(tile_size, tile_size)  # Match visual tiles exactly
			collision_shape.shape = rectangle_shape
			collision_shape.position = Vector2(12,12)  # No offset - match visual tiles exactly
			collision.add_child(collision_shape)
			collision.position = Vector2(x * tile_size, y * tile_size)
			add_child(collision)
			
			# LightOccluder2D temporarily disabled to fix crash
			# TODO: Re-enable after fixing the crash
	
	add_child(tile)

func get_floor_tiles() -> Array:
	var floor_tiles = []
	for floor_y in range(dungeon_height):
		for floor_x in range(dungeon_width):
			if dungeon_map[floor_y][floor_x] == 0:
				floor_tiles.append(Vector2(floor_x, floor_y))
	return floor_tiles

func get_random_floor_position() -> Vector2:
	var floor_tiles = get_floor_tiles()
	if floor_tiles.size() > 0:
		var random_tile = floor_tiles[randi() % floor_tiles.size()]
		var world_pos = Vector2(random_tile.x * tile_size + tile_size/2, random_tile.y * tile_size + tile_size/2)
		return world_pos
	else:
		# Try to find any floor tile by scanning the map
		for y in range(dungeon_height):
			for x in range(dungeon_width):
				if dungeon_map[y][x] == 0:
					var world_pos = Vector2(x * tile_size + tile_size/2, y * tile_size + tile_size/2)
					return world_pos
		# Last resort fallback
		return Vector2(100, 100)

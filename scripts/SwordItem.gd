extends Area2D

# Sword item that can be picked up and used for slashing
@export var item_name = "Iron Sword"
@export var damage = 25
@export var slash_range = 80.0
@export var slash_duration = 0.3

var is_picked_up = false

func _ready():
	# Set up collision
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(4, true)  # Items on layer 4
	
	# Make sure we're visible
	visible = true
	
	# Add a simple sword sprite (we'll create this)
	create_sword_sprite()

func create_sword_sprite():
	"""Create a simple sword sprite"""
	var sprite = Sprite2D.new()
	var sword_texture = ImageTexture.new()
	var sword_image = Image.create(16, 32, false, Image.FORMAT_RGBA8)
	
	# Draw a simple sword shape
	# Blade (vertical line)
	for y in range(8, 28):
		sword_image.set_pixel(7, y, Color(0.8, 0.8, 0.9))  # Silver blade
		sword_image.set_pixel(8, y, Color(0.8, 0.8, 0.9))
	
	# Crossguard (horizontal line)
	for x in range(4, 12):
		sword_image.set_pixel(x, 8, Color(0.6, 0.4, 0.2))  # Brown crossguard
		sword_image.set_pixel(x, 9, Color(0.6, 0.4, 0.2))
	
	# Handle (vertical line)
	for y in range(0, 8):
		sword_image.set_pixel(6, y, Color(0.4, 0.2, 0.1))  # Dark brown handle
		sword_image.set_pixel(7, y, Color(0.4, 0.2, 0.1))
		sword_image.set_pixel(8, y, Color(0.4, 0.2, 0.1))
		sword_image.set_pixel(9, y, Color(0.4, 0.2, 0.1))
	
	sword_texture.set_image(sword_image)
	sprite.texture = sword_texture
	sprite.scale = Vector2(6, 6)  # Double the size - make it bigger and more visible
	sprite.modulate = Color(1, 1, 1, 1)  # Ensure it's fully visible
	add_child(sprite)
	
	print("Sword sprite created at position: ", global_position)
	
	# Add a simple collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	collision.shape = shape
	add_child(collision)
	
	# Add a simple colored rectangle as backup visual
	var color_rect = ColorRect.new()
	color_rect.size = Vector2(8, 16)
	color_rect.color = Color(0.8, 0.8, 0.9)  # Silver color
	color_rect.position = Vector2(-4, -8)  # Center it
	add_child(color_rect)

func pickup():
	"""Called when player picks up the sword"""
	if is_picked_up:
		return null
	
	is_picked_up = true
	visible = false
	
	# Return item data for the hotbar
	return {
		"name": item_name,
		"type": "sword",
		"damage": damage,
		"range": slash_range,
		"duration": slash_duration,
		"icon": "⚔️"  # Sword emoji for hotbar
	}

func _on_area_entered(area):
	"""Handle when player enters the sword area"""
	pass  # Pickup is handled by the player's try_pickup_item function

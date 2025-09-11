extends Node

# Enemy sprite generator for creating pixel art enemies
# This creates 3 unique enemy types: Skeleton, Goblin, and Dark Mage

func create_skeleton_sprite() -> ImageTexture:
	"""Create a skeleton enemy sprite"""
	var image = Image.create(16, 24, false, Image.FORMAT_RGBA8)
	
	# Skeleton colors
	var bone_color = Color(0.9, 0.9, 0.8, 1.0)  # Off-white bone
	var dark_bone = Color(0.7, 0.7, 0.6, 1.0)   # Darker bone
	var eye_color = Color(1.0, 0.0, 0.0, 1.0)   # Red eyes
	var shadow_color = Color(0.3, 0.3, 0.3, 1.0) # Dark shadow
	
	# Head (skull)
	for y in range(2, 6):
		for x in range(4, 12):
			if x >= 3 and x <= 12 and y >= 2 and y <= 5:
				image.set_pixel(x, y, bone_color)
	
	# Eye sockets
	image.set_pixel(5, 3, eye_color)
	image.set_pixel(10, 3, eye_color)
	
	# Jaw
	for y in range(6, 8):
		for x in range(5, 11):
			image.set_pixel(x, y, bone_color)
	
	# Spine/body
	for y in range(8, 18):
		for x in range(7, 9):
			image.set_pixel(x, y, bone_color)
	
	# Ribs
	for y in range(10, 16):
		for x in range(5, 11):
			if (x - 8) * (x - 8) + (y - 13) * (y - 13) < 9:
				image.set_pixel(x, y, bone_color)
	
	# Arms
	for y in range(10, 16):
		image.set_pixel(3, y, bone_color)
		image.set_pixel(12, y, bone_color)
	
	# Legs
	for y in range(18, 24):
		image.set_pixel(6, y, bone_color)
		image.set_pixel(9, y, bone_color)
	
	# Add some dark shading
	for y in range(2, 24):
		for x in range(3, 13):
			var pixel = image.get_pixel(x, y)
			if pixel.a > 0 and (x + y) % 3 == 0:
				image.set_pixel(x, y, dark_bone)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func create_goblin_sprite() -> ImageTexture:
	"""Create a goblin enemy sprite"""
	var image = Image.create(16, 24, false, Image.FORMAT_RGBA8)
	
	# Goblin colors
	var skin_color = Color(0.4, 0.7, 0.4, 1.0)   # Green skin
	var dark_skin = Color(0.2, 0.5, 0.2, 1.0)    # Darker green
	var eye_color = Color(1.0, 1.0, 0.0, 1.0)    # Yellow eyes
	var cloth_color = Color(0.3, 0.2, 0.1, 1.0)  # Brown cloth
	var weapon_color = Color(0.5, 0.5, 0.5, 1.0) # Gray weapon
	
	# Head
	for y in range(2, 7):
		for x in range(4, 12):
			if x >= 3 and x <= 12 and y >= 2 and y <= 6:
				image.set_pixel(x, y, skin_color)
	
	# Eyes
	image.set_pixel(6, 3, eye_color)
	image.set_pixel(9, 3, eye_color)
	
	# Mouth (sharp teeth)
	image.set_pixel(7, 5, Color.BLACK)
	image.set_pixel(8, 5, Color.BLACK)
	
	# Ears (pointed)
	image.set_pixel(2, 3, skin_color)
	image.set_pixel(13, 3, skin_color)
	image.set_pixel(1, 4, skin_color)
	image.set_pixel(14, 4, skin_color)
	
	# Body (tunic)
	for y in range(7, 16):
		for x in range(5, 11):
			image.set_pixel(x, y, cloth_color)
	
	# Arms
	for y in range(8, 14):
		image.set_pixel(3, y, skin_color)
		image.set_pixel(12, y, skin_color)
	
	# Hands holding weapon
	image.set_pixel(2, 12, skin_color)
	image.set_pixel(13, 12, skin_color)
	
	# Weapon (club)
	for y in range(10, 16):
		image.set_pixel(1, y, weapon_color)
		image.set_pixel(14, y, weapon_color)
	
	# Legs
	for y in range(16, 24):
		image.set_pixel(6, y, skin_color)
		image.set_pixel(9, y, skin_color)
	
	# Add shading
	for y in range(2, 24):
		for x in range(1, 15):
			var pixel = image.get_pixel(x, y)
			if pixel.a > 0 and (x + y) % 2 == 0:
				if pixel == skin_color:
					image.set_pixel(x, y, dark_skin)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func create_dark_mage_sprite() -> ImageTexture:
	"""Create a dark mage enemy sprite"""
	var image = Image.create(16, 24, false, Image.FORMAT_RGBA8)
	
	# Dark mage colors
	var robe_color = Color(0.2, 0.1, 0.3, 1.0)   # Dark purple robe
	var dark_robe = Color(0.1, 0.05, 0.2, 1.0)   # Darker purple
	var skin_color = Color(0.8, 0.6, 0.4, 1.0)   # Pale skin
	var eye_color = Color(0.0, 1.0, 1.0, 1.0)    # Cyan glowing eyes
	var magic_color = Color(0.5, 0.0, 1.0, 1.0)  # Purple magic
	var staff_color = Color(0.4, 0.2, 0.1, 1.0)  # Brown staff
	
	# Head (hooded)
	for y in range(1, 8):
		for x in range(3, 13):
			if x >= 2 and x <= 13 and y >= 1 and y <= 7:
				image.set_pixel(x, y, robe_color)
	
	# Face (pale)
	for y in range(3, 6):
		for x in range(5, 11):
			image.set_pixel(x, y, skin_color)
	
	# Glowing eyes
	image.set_pixel(6, 4, eye_color)
	image.set_pixel(9, 4, eye_color)
	# Eye glow effect
	image.set_pixel(5, 4, eye_color * 0.5)
	image.set_pixel(7, 4, eye_color * 0.5)
	image.set_pixel(8, 4, eye_color * 0.5)
	image.set_pixel(10, 4, eye_color * 0.5)
	
	# Body (robes)
	for y in range(8, 20):
		for x in range(4, 12):
			image.set_pixel(x, y, robe_color)
	
	# Arms (in sleeves)
	for y in range(9, 16):
		image.set_pixel(2, y, robe_color)
		image.set_pixel(13, y, robe_color)
	
	# Hands
	image.set_pixel(1, 14, skin_color)
	image.set_pixel(14, 14, skin_color)
	
	# Staff
	for y in range(12, 24):
		image.set_pixel(0, y, staff_color)
		image.set_pixel(15, y, staff_color)
	
	# Magic orb at staff tip
	image.set_pixel(0, 11, magic_color)
	image.set_pixel(15, 11, magic_color)
	image.set_pixel(1, 10, magic_color * 0.7)
	image.set_pixel(14, 10, magic_color * 0.7)
	
	# Legs (robes)
	for y in range(20, 24):
		image.set_pixel(6, y, robe_color)
		image.set_pixel(9, y, robe_color)
	
	# Add magical aura
	for y in range(1, 24):
		for x in range(0, 16):
			if (x + y) % 4 == 0 and image.get_pixel(x, y).a == 0:
				image.set_pixel(x, y, magic_color * 0.1)
	
	# Add robe shading
	for y in range(1, 24):
		for x in range(0, 16):
			var pixel = image.get_pixel(x, y)
			if pixel == robe_color and (x + y) % 3 == 0:
				image.set_pixel(x, y, dark_robe)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func create_all_enemy_sprites() -> Dictionary:
	"""Create all enemy sprites and return them in a dictionary"""
	var sprites = {}
	sprites["skeleton"] = create_skeleton_sprite()
	sprites["goblin"] = create_goblin_sprite()
	sprites["dark_mage"] = create_dark_mage_sprite()
	return sprites

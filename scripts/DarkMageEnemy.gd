extends BaseEnemy

# Dark Mage enemy - ranged magic attacker
@export var magic_projectile_speed = 200.0
@export var magic_damage = 20

var magic_projectiles = []

func _ready():
	# Set dark mage-specific stats
	max_health = 60
	speed = 40.0  # Slower than other enemies
	damage = magic_damage
	attack_range = 150.0  # Much longer range
	detection_range = 120.0
	attack_cooldown = 3.0  # Longer cooldown for powerful attacks
	
	# Call parent _ready
	super._ready()
	
	# Create dark mage sprite
	create_dark_mage_sprite()

func create_dark_mage_sprite():
	"""Create the dark mage sprite"""
	var generator = preload("res://scripts/EnemySpriteGenerator.gd").new()
	var mage_texture = generator.create_dark_mage_sprite()
	
	if sprite:
		sprite.texture = mage_texture
		sprite.scale = Vector2(2.0, 2.0)  # Make it bigger
		sprite.modulate = Color(1, 1, 1, 1)

func get_enemy_type() -> String:
	return "dark_mage"

func handle_chasing_state(delta):
	"""Dark mage-specific chasing - keeps distance"""
	if not can_see_player():
		state = "idle"
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player <= attack_range and distance_to_player >= 80.0:
		# In optimal range for magic attacks
		state = "attacking"
		return
	elif distance_to_player < 80.0:
		# Too close, back away
		var direction = (global_position - player.global_position).normalized()
		velocity = direction * speed * 0.5  # Move away slowly
	else:
		# Too far, move closer
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed * 0.7  # Move closer slowly

func perform_attack():
	"""Dark mage's magic projectile attack"""
	if not player:
		return
	
	print("Dark mage casts a magic bolt!")
	
	# Create magic projectile
	create_magic_projectile()
	
	# Visual effect
	create_magic_attack_effect()

func create_magic_projectile():
	"""Create a magic projectile that travels towards the player"""
	var projectile = Area2D.new()
	projectile.name = "MagicProjectile"
	get_parent().add_child(projectile)
	
	# Set up collision
	projectile.collision_layer = 0
	projectile.collision_mask = 2  # Hit player (layer 2)
	
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 4
	collision_shape.shape = circle_shape
	projectile.add_child(collision_shape)
	
	# Create visual
	var projectile_sprite = Sprite2D.new()
	var projectile_texture = ImageTexture.new()
	var image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.5, 0.0, 1.0, 1.0))  # Purple magic
	projectile_texture.set_image(image)
	projectile_sprite.texture = projectile_texture
	projectile_sprite.scale = Vector2(1.5, 1.5)
	projectile.add_child(projectile_sprite)
	
	# Set position and direction
	projectile.global_position = global_position
	var direction = (player.global_position - global_position).normalized()
	
	# Add to projectiles list
	magic_projectiles.append(projectile)
	
	# Connect collision signal
	projectile.connect("body_entered", _on_magic_projectile_hit)
	
	# Move the projectile
	var tween = create_tween()
	tween.tween_property(projectile, "global_position", 
		global_position + direction * 200, 1.0)
	tween.tween_callback(projectile.queue_free)
	
	# Remove from list when done
	tween.tween_callback(func(): magic_projectiles.erase(projectile))

func _on_magic_projectile_hit(body):
	"""Handle magic projectile hitting something"""
	if body == player and player.has_method("take_damage"):
		player.take_damage(damage)
		print("Magic projectile hit player for ", damage, " damage!")
	
	# Remove the projectile
	var projectile = body.get_parent()
	if projectile in magic_projectiles:
		magic_projectiles.erase(projectile)
	projectile.queue_free()

func create_magic_attack_effect():
	"""Create magic attack visual effect"""
	# Flash purple and create magic aura
	var original_modulate = sprite.modulate
	sprite.modulate = Color(0.5, 0.0, 1.0, 1.0)  # Purple flash
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.5)
	
	# Create magic aura effect
	create_magic_aura()

func create_magic_aura():
	"""Create magical aura around the dark mage"""
	for i in range(8):
		var aura_particle = ColorRect.new()
		aura_particle.size = Vector2(3, 3)
		aura_particle.color = Color(0.5, 0.0, 1.0, 0.6)
		
		var angle = (i * PI * 2) / 8
		var offset = Vector2(cos(angle), sin(angle)) * 30
		aura_particle.position = global_position + offset
		
		get_parent().add_child(aura_particle)
		
		# Animate the particle
		var tween = create_tween()
		tween.tween_property(aura_particle, "modulate:a", 0.0, 1.0)
		tween.tween_callback(aura_particle.queue_free)

func die():
	"""Dark mage death - explode all projectiles"""
	# Explode all active projectiles
	for projectile in magic_projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	magic_projectiles.clear()
	
	# Call parent die function
	super.die()

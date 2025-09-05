extends CharacterBody2D

# Simple player character for dungeon crawler
@export var speed = 200.0
@export var health = 100
@export var max_health = 100

var dungeon_generator: Node2D
var is_moving = false
var camera: Camera2D
var health_bar: ProgressBar

func _ready():
	dungeon_generator = get_node("../DungeonGenerator")
	camera = get_node("Camera2D")
	health_bar = get_node("HealthBar")
	
	# Position player at a random floor tile
	if dungeon_generator:
		global_position = dungeon_generator.get_random_floor_position()
		print("Player spawned at: ", global_position)
	
	# Ensure camera is properly centered
	if camera:
		camera.enabled = true
		camera.make_current()
	
	# Initialize health bar
	if health_bar:
		health_bar.value = health
		health_bar.max_value = max_health

func _input(event):
	if event.is_action_pressed("ui_accept"):
		# Regenerate dungeon and reposition player
		if dungeon_generator:
			print("Regenerating dungeon...")
			dungeon_generator.generate_dungeon()
			var new_pos = dungeon_generator.get_random_floor_position()
			if new_pos != Vector2.ZERO:
				global_position = new_pos
				print("Dungeon regenerated! Player repositioned to: ", global_position)
			else:
				print("ERROR: Could not find valid floor position!")
	
	# Debug zoom controls
	if event.is_action_pressed("ui_zoom_in"):
		if camera:
			camera.zoom *= 1.2
			print("Zoom in: ", camera.zoom)
	
	if event.is_action_pressed("ui_zoom_out"):
		if camera:
			camera.zoom *= 0.8
			print("Zoom out: ", camera.zoom)

func _physics_process(delta):
	handle_movement()
	move_and_slide()

func handle_movement():
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
	
	# Apply movement
	if direction != Vector2.ZERO:
		velocity = direction.normalized() * speed
		is_moving = true
	else:
		velocity = Vector2.ZERO
		is_moving = false

func take_damage(amount: int):
	health -= amount
	health = max(0, health)
	print("Player health: ", health, "/", max_health)
	
	# Update health bar
	if health_bar:
		health_bar.value = health
	
	if health <= 0:
		die()

func die():
	print("Player died!")
	# TODO: Add death animation and respawn logic

func heal(amount: int):
	health += amount
	health = min(max_health, health)
	print("Player healed to: ", health, "/", max_health)
	
	# Update health bar
	if health_bar:
		health_bar.value = health

extends ColorRect

var player
var light_radius = 120.0

func _ready():
	# Make it dark overlay
	color = Color(0.1, 0.1, 0.2, 0.8)
	visible = true
	
	# Find the player
	call_deferred("find_player")

func find_player():
	"""Find player node"""
	player = get_node("../../Player")
	print("Simple lighting ready!")

func _draw():
	if not player:
		return
	
	# Simple approach: draw light at center of screen
	var screen_center = get_viewport().get_visible_rect().size / 2.0
	
	# Draw a simple circular light
	draw_radial_light(screen_center, light_radius)

func draw_radial_light(center: Vector2, radius: float):
	"""Draw a radial light with smooth falloff"""
	# Draw multiple circles with decreasing alpha for smooth gradient
	var steps = 15
	for i in range(steps):
		var current_radius = radius * (1.0 - float(i) / float(steps))
		var alpha = (1.0 - float(i) / float(steps)) * 0.6
		
		var color = Color(0.1, 0.1, 0.2, alpha)
		draw_circle(center, current_radius, color)

func _process(_delta):
	queue_redraw()  # Redraw every frame

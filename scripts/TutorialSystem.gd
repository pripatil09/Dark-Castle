extends Control

# Tutorial system for explaining gameplay mechanics
signal tutorial_completed

var current_step = 0
var tutorial_steps = []
var is_active = false
var player: CharacterBody2D
var tutorial_ui: Control

# Tutorial step data
var steps_data = [
	{
		"title": "Welcome to Dark Castle!",
		"description": "Use WASD or Arrow Keys to move around the dungeon.",
		"action": "move",
		"key_hint": "WASD or Arrow Keys",
		"visual_hint": "arrow_keys"
	},
	{
		"title": "Dash Ability",
		"description": "Press SHIFT to dash quickly in any direction. Great for escaping danger!",
		"action": "dash",
		"key_hint": "SHIFT",
		"visual_hint": "dash_effect"
	},
	{
		"title": "Combat System",
		"description": "Left-click to use your equipped weapon. Find swords in the dungeon!",
		"action": "attack",
		"key_hint": "Left Click",
		"visual_hint": "sword_icon"
	},
	{
		"title": "Item Management",
		"description": "Press 1-9 to select hotbar slots. Press E near items to pick them up.",
		"action": "inventory",
		"key_hint": "1-9, E",
		"visual_hint": "hotbar"
	},
	{
		"title": "Health Management",
		"description": "Watch your health bar! When it turns red, you're in danger.",
		"action": "health",
		"key_hint": "Watch Health Bar",
		"visual_hint": "health_bar"
	}
]

func _ready():
	# Get references with error handling
	call_deferred("find_references")
	
	# Initialize tutorial steps
	tutorial_steps = steps_data.duplicate()

func find_references():
	"""Find player and UI references after everything is ready"""
	# Try different possible paths for the player
	var possible_player_paths = [
		"../../Player",
		"../../../Player", 
		"/root/Main/Player",
		"../../Main/Player"
	]
	
	for path in possible_player_paths:
		var node = get_node_or_null(path)
		if node:
			player = node
			print("Tutorial found player at path: ", path)
			break
	
	if not player:
		print("Tutorial could not find player!")
	
	# Create tutorial UI in code instead of using scene
	create_tutorial_ui()
	
	# Start tutorial automatically
	start_tutorial()

func create_tutorial_ui():
	"""Create the tutorial UI programmatically"""
	# Create main tutorial UI container
	tutorial_ui = Control.new()
	tutorial_ui.name = "TutorialUI"
	tutorial_ui.anchors_preset = Control.PRESET_FULL_RECT
	tutorial_ui.anchor_left = 0.0
	tutorial_ui.anchor_top = 0.0
	tutorial_ui.anchor_right = 1.0
	tutorial_ui.anchor_bottom = 1.0
	tutorial_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tutorial_ui)
	
	# Create background
	var background = ColorRect.new()
	background.name = "Background"
	background.anchors_preset = Control.PRESET_FULL_RECT
	background.anchor_left = 0.0
	background.anchor_top = 0.0
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.color = Color(0, 0, 0, 0.3)
	tutorial_ui.add_child(background)
	
	# Create tutorial panel (2x bigger)
	var panel = Panel.new()
	panel.name = "TutorialPanel"
	panel.anchors_preset = Control.PRESET_CENTER
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -600  # 2x bigger (was -300)
	panel.offset_top = -300   # 2x bigger (was -150)
	panel.offset_right = 600  # 2x bigger (was 300)
	panel.offset_bottom = 300 # 2x bigger (was 150)
	tutorial_ui.add_child(panel)
	
	# Create title label (2x bigger)
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.anchors_preset = Control.PRESET_TOP_WIDE
	title_label.anchor_left = 0.0
	title_label.anchor_top = 0.0
	title_label.anchor_right = 1.0
	title_label.offset_left = 40   # 2x bigger (was 20)
	title_label.offset_top = 40    # 2x bigger (was 20)
	title_label.offset_right = -40 # 2x bigger (was -20)
	title_label.offset_bottom = 120 # 2x bigger (was 60)
	title_label.text = "Tutorial Title"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48) # 2x bigger (was 24)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(title_label)
	
	# Create description label (2x bigger)
	var desc_label = Label.new()
	desc_label.name = "DescriptionLabel"
	desc_label.anchors_preset = Control.PRESET_TOP_WIDE
	desc_label.anchor_left = 0.0
	desc_label.anchor_top = 0.0
	desc_label.anchor_right = 1.0
	desc_label.offset_left = 40   # 2x bigger (was 20)
	desc_label.offset_top = 140   # 2x bigger (was 70)
	desc_label.offset_right = -40 # 2x bigger (was -20)
	desc_label.offset_bottom = 240 # 2x bigger (was 120)
	desc_label.text = "Tutorial description goes here..."
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 32) # 2x bigger (was 16)
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	panel.add_child(desc_label)
	
	# Create key hint label (2x bigger)
	var key_hint_label = Label.new()
	key_hint_label.name = "KeyHintLabel"
	key_hint_label.anchors_preset = Control.PRESET_TOP_WIDE
	key_hint_label.anchor_left = 0.0
	key_hint_label.anchor_top = 0.0
	key_hint_label.anchor_right = 1.0
	key_hint_label.offset_left = 40   # 2x bigger (was 20)
	key_hint_label.offset_top = 260   # 2x bigger (was 130)
	key_hint_label.offset_right = -40 # 2x bigger (was -20)
	key_hint_label.offset_bottom = 320 # 2x bigger (was 160)
	key_hint_label.text = "Press: KEY"
	key_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_hint_label.add_theme_font_size_override("font_size", 36) # 2x bigger (was 18)
	key_hint_label.add_theme_color_override("font_color", Color.YELLOW)
	panel.add_child(key_hint_label)
	
	# Create progress label (2x bigger)
	var progress_label = Label.new()
	progress_label.name = "ProgressLabel"
	progress_label.anchors_preset = Control.PRESET_TOP_WIDE
	progress_label.anchor_left = 0.0
	progress_label.anchor_top = 0.0
	progress_label.anchor_right = 1.0
	progress_label.offset_left = 40   # 2x bigger (was 20)
	progress_label.offset_top = 340   # 2x bigger (was 170)
	progress_label.offset_right = -40 # 2x bigger (was -20)
	progress_label.offset_bottom = 380 # 2x bigger (was 190)
	progress_label.text = "Step 1 of 6"
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 28) # 2x bigger (was 14)
	progress_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	panel.add_child(progress_label)
	
	# Create skip button (2x bigger)
	var skip_button = Button.new()
	skip_button.name = "SkipButton"
	skip_button.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	skip_button.anchor_left = 1.0
	skip_button.anchor_top = 1.0
	skip_button.anchor_right = 1.0
	skip_button.anchor_bottom = 1.0
	skip_button.offset_left = -200 # 2x bigger (was -100)
	skip_button.offset_top = -80   # 2x bigger (was -40)
	skip_button.offset_right = -40 # 2x bigger (was -20)
	skip_button.offset_bottom = -40 # 2x bigger (was -20)
	skip_button.text = "Skip Tutorial"
	skip_button.add_theme_font_size_override("font_size", 24) # 2x bigger text
	skip_button.pressed.connect(skip_tutorial)
	panel.add_child(skip_button)
	
	print("Tutorial UI created programmatically")

func start_console_tutorial():
	"""Start a simple console-based tutorial as fallback"""
	print("=== TUTORIAL STARTED ===")
	print("Welcome to Dark Castle!")
	print("Controls:")
	print("- WASD or Arrow Keys: Move")
	print("- SHIFT: Dash")
	print("- Left Click: Attack with sword")
	print("- 1-9: Select hotbar slots")
	print("- E: Pick up items")
	print("- Watch your health bar - red means danger!")
	print("Complete the actions to progress through the tutorial!")
	print("=========================")

func start_tutorial():
	"""Start the tutorial sequence"""
	is_active = true
	current_step = 0
	
	# Make sure tutorial UI is visible
	if tutorial_ui:
		tutorial_ui.visible = true
		print("Tutorial UI made visible")
	else:
		print("ERROR: Tutorial UI not found!")
		return
	
	show_tutorial_step(current_step)
	print("Tutorial started!")

func show_tutorial_step(step_index: int):
	"""Display a tutorial step"""
	if step_index >= tutorial_steps.size():
		complete_tutorial()
		return
	
	var step = tutorial_steps[step_index]
	current_step = step_index
	
	# Block player movement during tutorial
	block_player_movement(true)
	
	# Update UI
	update_tutorial_ui(step)
	
	# Show visual hints
	show_visual_hint(step)
	
	print("Tutorial Step ", step_index + 1, ": ", step.title)

func update_tutorial_ui(step: Dictionary):
	"""Update the tutorial UI with step information"""
	if not tutorial_ui:
		print("Tutorial UI not found!")
		return
	
	var title_label = tutorial_ui.get_node_or_null("TutorialPanel/TitleLabel")
	var desc_label = tutorial_ui.get_node_or_null("TutorialPanel/DescriptionLabel")
	var key_hint_label = tutorial_ui.get_node_or_null("TutorialPanel/KeyHintLabel")
	var progress_label = tutorial_ui.get_node_or_null("TutorialPanel/ProgressLabel")
	
	if title_label:
		title_label.text = step.title
		print("Updated title: ", step.title)
	else:
		print("Title label not found!")
	
	if desc_label:
		desc_label.text = step.description
		print("Updated description: ", step.description)
	else:
		print("Description label not found!")
	
	if key_hint_label:
		key_hint_label.text = "Press: " + step.key_hint
		print("Updated key hint: ", step.key_hint)
	else:
		print("Key hint label not found!")
	
	if progress_label:
		progress_label.text = "Step " + str(current_step + 1) + " of " + str(tutorial_steps.size())
		print("Updated progress: ", current_step + 1, " of ", tutorial_steps.size())
	else:
		print("Progress label not found!")
	
	# Update skip button text for last step
	var skip_button = tutorial_ui.get_node_or_null("TutorialPanel/SkipButton")
	if skip_button:
		if current_step == tutorial_steps.size() - 1:
			skip_button.text = "End Tutorial"
		else:
			skip_button.text = "Skip Tutorial"

func show_visual_hint(step: Dictionary):
	"""Show visual indicators for the current step"""
	var hint_type = step.get("visual_hint", "")
	
	match hint_type:
		"arrow_keys":
			highlight_movement_keys()
		"dash_effect":
			highlight_dash_ability()
		"sword_icon":
			highlight_combat_area()
		"hotbar":
			highlight_hotbar()
		"health_bar":
			highlight_health_bar()

func highlight_movement_keys():
	"""Highlight movement keys on screen"""
	# Create visual indicators for WASD keys
	create_key_highlight("W", Vector2(400, 200), "Move Up")
	create_key_highlight("A", Vector2(350, 250), "Move Left")
	create_key_highlight("S", Vector2(400, 250), "Move Down")
	create_key_highlight("D", Vector2(450, 250), "Move Right")

func highlight_dash_ability():
	"""Highlight dash ability"""
	create_key_highlight("SHIFT", Vector2(400, 300), "Dash")

func highlight_combat_area():
	"""Highlight combat area around player"""
	# Create a pulsing circle around the player
	var combat_hint = ColorRect.new()
	combat_hint.name = "CombatHint"
	combat_hint.size = Vector2(100, 100)
	combat_hint.position = player.global_position - Vector2(50, 50)
	combat_hint.color = Color(1, 0, 0, 0.3)
	add_child(combat_hint)
	
	# Animate the hint
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(combat_hint, "modulate:a", 0.1, 0.5)
	tween.tween_property(combat_hint, "modulate:a", 0.3, 0.5)

func highlight_hotbar():
	"""Highlight the hotbar"""
	var hotbar = get_node("../UILayer/OverlayUI/Hotbar")
	if hotbar:
		hotbar.modulate = Color(1, 1, 0, 1)  # Yellow highlight
		
		# Create pulsing effect
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(hotbar, "modulate:a", 0.5, 0.5)
		tween.tween_property(hotbar, "modulate:a", 1.0, 0.5)


func highlight_health_bar():
	"""Highlight health bar"""
	var health_bar = player.get_node("HealthBar")
	if health_bar:
		health_bar.modulate = Color(1, 1, 0, 1)  # Yellow highlight
		
		# Create pulsing effect
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(health_bar, "modulate:a", 0.5, 0.5)
		tween.tween_property(health_bar, "modulate:a", 1.0, 0.5)

func create_key_highlight(key_text: String, position: Vector2, description: String):
	"""Create a visual key highlight"""
	var key_rect = ColorRect.new()
	key_rect.name = "KeyHighlight_" + key_text
	key_rect.size = Vector2(60, 40)
	key_rect.position = position
	key_rect.color = Color(0, 1, 0, 0.8)
	add_child(key_rect)
	
	# Add key text
	var key_label = Label.new()
	key_label.text = key_text
	key_label.position = Vector2(20, 10)
	key_label.add_theme_font_size_override("font_size", 20)
	key_rect.add_child(key_label)
	
	# Add description
	var desc_label = Label.new()
	desc_label.text = description
	desc_label.position = Vector2(position.x, position.y + 50)
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(desc_label)

func check_tutorial_action(action: String):
	"""Check if the player performed the required action"""
	if not is_active:
		return
	
	var current_step_data = tutorial_steps[current_step]
	if current_step_data.get("action") == action:
		# Action completed, move to next step
		clear_visual_hints()
		current_step += 1
		
		if current_step < tutorial_steps.size():
			show_tutorial_step(current_step)
		else:
			complete_tutorial()

func clear_visual_hints():
	"""Clear all visual hints"""
	# Remove key highlights
	for child in get_children():
		if child.name.begins_with("KeyHighlight_"):
			child.queue_free()
	
	# Remove any remaining labels that might be floating
	for child in get_children():
		if child is Label and not child.name.begins_with("Tutorial"):
			child.queue_free()
	
	# Reset hotbar and health bar modulation
	var hotbar = get_node("../UILayer/OverlayUI/Hotbar")
	if hotbar:
		hotbar.modulate = Color.WHITE
	
	var health_bar = player.get_node("HealthBar")
	if health_bar:
		health_bar.modulate = Color.WHITE

func complete_tutorial():
	"""Complete the tutorial"""
	is_active = false
	clear_visual_hints()
	
	# Unblock player movement
	block_player_movement(false)
	
	# Hide tutorial UI
	tutorial_ui.visible = false
	
	# Show completion message
	show_completion_message()
	
	# Emit signal
	tutorial_completed.emit()
	
	print("Tutorial completed!")

func block_player_movement(block: bool):
	"""Block or unblock player movement during tutorial"""
	if not player:
		return
	
	# Set a flag on the player to block movement
	player.set_meta("tutorial_blocked", block)
	print("Player movement blocked: ", block)

func show_completion_message():
	"""Show tutorial completion message"""
	# Just print to console, no on-screen text
	print("Tutorial Complete! You're ready to explore the dungeon!")

func skip_tutorial():
	"""Skip the tutorial"""
	complete_tutorial()

func _input(event):
	"""Handle input for tutorial progression"""
	if not is_active:
		return
	
	# Debug: Print all input
	if event is InputEventKey and event.pressed:
		print("Tutorial received key: ", event.keycode)
	
	# Check for skip key (ESC)
	if event.is_action_pressed("ui_cancel"):
		skip_tutorial()
		return
	
	# Check for specific actions
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
				print("Tutorial detected movement key")
				check_tutorial_action("move")
			KEY_SHIFT:
				print("Tutorial detected dash key")
				check_tutorial_action("dash")
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				print("Tutorial detected hotbar key")
				check_tutorial_action("inventory")
			KEY_E:
				print("Tutorial detected pickup key")
				check_tutorial_action("inventory")
	
	# Check for mouse clicks
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Tutorial detected left click")
		check_tutorial_action("attack")

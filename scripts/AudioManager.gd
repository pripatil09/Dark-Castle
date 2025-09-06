extends Node

# AudioManager - Handles dynamic music and sound effects
# Manages ambient music that transitions to combat music when fighting

@onready var mysterious_music_player: AudioStreamPlayer
@onready var piano_music_player: AudioStreamPlayer
@onready var strange_music_player: AudioStreamPlayer
@onready var sfx_player: AudioStreamPlayer

enum MusicState {
	MYSTERIOUS,
	PIANO,
	STRANGE
}

var current_state = MusicState.MYSTERIOUS
var music_volume = 0.4
var sfx_volume = 0.8
var mysterious_volume = 0.3
var piano_volume = 0.4
var strange_volume = 0.5
var mysterious_pitch = 1.0
var piano_pitch = 1.0
var strange_pitch = 1.0
var tempo_variation_timer = 0.0
var tempo_variation_duration = 8.0  # Change tempo every 8 seconds
var base_mysterious_pitch = 1.0
var base_piano_pitch = 1.0
var base_strange_pitch = 1.0
var pitch_variation = 0.15  # How much pitch can vary

func _ready():
	# Get audio players from the scene
	mysterious_music_player = get_node("MysteriousMusic")
	piano_music_player = get_node("PianoMusic")
	strange_music_player = get_node("StrangeMusic")
	sfx_player = get_node("SFXPlayer")
	
	# Set initial volumes and pitch with null checks
	if mysterious_music_player:
		mysterious_music_player.volume_db = linear_to_db(mysterious_volume)
		mysterious_music_player.pitch_scale = mysterious_pitch
		if mysterious_music_player.stream:
			mysterious_music_player.stream.loop = true
	
	if piano_music_player:
		piano_music_player.volume_db = linear_to_db(piano_volume)
		piano_music_player.pitch_scale = piano_pitch
		if piano_music_player.stream:
			piano_music_player.stream.loop = true
	
	if strange_music_player:
		strange_music_player.volume_db = linear_to_db(strange_volume)
		strange_music_player.pitch_scale = strange_pitch
		if strange_music_player.stream:
			strange_music_player.stream.loop = true
	
	if sfx_player:
		sfx_player.volume_db = linear_to_db(sfx_volume)
	
	# Start with mysterious music
	play_mysterious_music()

func _process(delta):
	"""Handle tempo variations and music dynamics"""
	tempo_variation_timer += delta
	
	# Change tempo every few seconds
	if tempo_variation_timer >= tempo_variation_duration:
		tempo_variation_timer = 0.0
		apply_tempo_variation()

func apply_tempo_variation():
	"""Apply subtle tempo and pitch variations to keep music interesting"""
	if not mysterious_music_player or not piano_music_player or not strange_music_player:
		return
	
	# 20% chance for dramatic change, 80% for subtle change
	if randf() < 0.2:
		create_dramatic_tempo_change()
		return
	
	# Generate random variation (-1 to 1)
	var variation = (randf() - 0.5) * 2.0
	
	# Apply pitch variation
	var new_mysterious_pitch = base_mysterious_pitch + (variation * pitch_variation)
	var new_piano_pitch = base_piano_pitch + (variation * pitch_variation)
	var new_strange_pitch = base_strange_pitch + (variation * pitch_variation)
	
	# Clamp to reasonable values
	new_mysterious_pitch = clamp(new_mysterious_pitch, 0.7, 1.3)
	new_piano_pitch = clamp(new_piano_pitch, 0.7, 1.3)
	new_strange_pitch = clamp(new_strange_pitch, 0.6, 1.2)
	
	# Apply to current playing music
	if mysterious_music_player.playing:
		mysterious_pitch = new_mysterious_pitch
		mysterious_music_player.pitch_scale = mysterious_pitch
	
	if piano_music_player.playing:
		piano_pitch = new_piano_pitch
		piano_music_player.pitch_scale = piano_pitch
	
	if strange_music_player.playing:
		strange_pitch = new_strange_pitch
		strange_music_player.pitch_scale = strange_pitch

func play_mysterious_music():
	"""Play the mysterious background music"""
	if mysterious_music_player and mysterious_music_player.stream:
		current_state = MusicState.MYSTERIOUS
		mysterious_music_player.pitch_scale = mysterious_pitch
		mysterious_music_player.volume_db = linear_to_db(mysterious_volume)
		mysterious_music_player.play()

func play_piano_music():
	"""Play the piano music"""
	if piano_music_player and piano_music_player.stream:
		current_state = MusicState.PIANO
		piano_music_player.pitch_scale = piano_pitch
		piano_music_player.volume_db = linear_to_db(piano_volume)
		piano_music_player.play()

func play_strange_music():
	"""Play the strange music"""
	if strange_music_player and strange_music_player.stream:
		current_state = MusicState.STRANGE
		strange_music_player.pitch_scale = strange_pitch
		strange_music_player.volume_db = linear_to_db(strange_volume)
		strange_music_player.play()

func stop_all_music():
	"""Stop all music"""
	if mysterious_music_player:
		mysterious_music_player.stop()
	if piano_music_player:
		piano_music_player.stop()
	if strange_music_player:
		strange_music_player.stop()

func transition_to_piano():
	"""Transition to piano music"""
	if current_state != MusicState.PIANO:
		stop_all_music()
		play_piano_music()

func transition_to_strange():
	"""Transition to strange music"""
	if current_state != MusicState.STRANGE:
		stop_all_music()
		play_strange_music()

func transition_to_mysterious():
	"""Transition to mysterious music"""
	if current_state != MusicState.MYSTERIOUS:
		stop_all_music()
		play_mysterious_music()

func fade_music_transition(from_player: AudioStreamPlayer, to_player: AudioStreamPlayer):
	"""Smoothly transition between two music tracks"""
	if not from_player or not to_player:
		return
	
	# Create tween for smooth transition
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Fade out current music
	tween.tween_property(from_player, "volume_db", -80, 1.0)
	
	# Set up new music properties based on which player
	var target_volume = 0.5
	var target_pitch = 1.0
	
	if to_player == mysterious_music_player:
		target_volume = mysterious_volume
		target_pitch = mysterious_pitch
	elif to_player == piano_music_player:
		target_volume = piano_volume
		target_pitch = piano_pitch
	elif to_player == strange_music_player:
		target_volume = strange_volume
		target_pitch = strange_pitch
	
	# Fade in new music
	to_player.volume_db = -80
	to_player.pitch_scale = target_pitch
	to_player.play()
	tween.tween_property(to_player, "volume_db", linear_to_db(target_volume), 1.0)

func play_sound_effect(sound: AudioStream):
	"""Play a sound effect"""
	if sfx_player and sound:
		sfx_player.stream = sound
		sfx_player.play()

func set_music_volume(volume: float):
	"""Set music volume (0.0 to 1.0)"""
	music_volume = clamp(volume, 0.0, 1.0)
	if mysterious_music_player:
		mysterious_music_player.volume_db = linear_to_db(mysterious_volume * music_volume)
	if piano_music_player:
		piano_music_player.volume_db = linear_to_db(piano_volume * music_volume)
	if strange_music_player:
		strange_music_player.volume_db = linear_to_db(strange_volume * music_volume)

func set_sfx_volume(volume: float):
	"""Set sound effects volume (0.0 to 1.0)"""
	sfx_volume = clamp(volume, 0.0, 1.0)
	sfx_player.volume_db = linear_to_db(sfx_volume)

func set_combat_intensity(intensity: float):
	"""Adjust music intensity (0.0 to 1.0)"""
	intensity = clamp(intensity, 0.0, 1.0)
	
	# Adjust pitch: lower values = lower pitch (more intense)
	base_strange_pitch = lerp(1.0, 0.6, intensity)
	strange_pitch = base_strange_pitch
	
	# Adjust volume: higher values = louder
	strange_volume = lerp(0.5, 1.0, intensity)
	
	# Apply to strange player if it's currently playing
	if strange_music_player and strange_music_player.playing:
		strange_music_player.pitch_scale = strange_pitch
		strange_music_player.volume_db = linear_to_db(strange_volume)

func create_dramatic_tempo_change():
	"""Create a more dramatic tempo change for variety"""
	if not mysterious_music_player or not piano_music_player or not strange_music_player:
		return
	
	# Create a tween for smooth tempo change
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Random dramatic change
	var dramatic_variation = (randf() - 0.5) * 0.4  # Larger variation
	var target_mysterious_pitch = base_mysterious_pitch + dramatic_variation
	var target_piano_pitch = base_piano_pitch + dramatic_variation
	var target_strange_pitch = base_strange_pitch + dramatic_variation
	
	# Clamp values
	target_mysterious_pitch = clamp(target_mysterious_pitch, 0.6, 1.4)
	target_piano_pitch = clamp(target_piano_pitch, 0.6, 1.4)
	target_strange_pitch = clamp(target_strange_pitch, 0.5, 1.3)
	
	# Apply smooth transition
	if mysterious_music_player.playing:
		tween.tween_property(mysterious_music_player, "pitch_scale", target_mysterious_pitch, 2.0)
		mysterious_pitch = target_mysterious_pitch
	
	if piano_music_player.playing:
		tween.tween_property(piano_music_player, "pitch_scale", target_piano_pitch, 2.0)
		piano_pitch = target_piano_pitch
	
	if strange_music_player.playing:
		tween.tween_property(strange_music_player, "pitch_scale", target_strange_pitch, 2.0)
		strange_pitch = target_strange_pitch

# Sound effect functions for common game events
func play_footstep():
	"""Play footstep sound"""
	# TODO: Add footstep audio file
	pass

func play_dungeon_generate():
	"""Play dungeon generation sound"""
	# TODO: Add dungeon generation audio file
	pass

func play_health_low():
	"""Play low health warning sound"""
	# TODO: Add low health audio file
	pass

func play_death():
	"""Play death sound"""
	# TODO: Add death audio file
	pass

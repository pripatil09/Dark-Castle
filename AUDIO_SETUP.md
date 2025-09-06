# Audio Setup for Dark Castle

## Music System Overview

The game now has a dynamic audio system that plays:
- **Dark ambient music** during exploration
- **Intense combat music** when fighting enemies
- **Smooth transitions** between music states

## How to Add Music Files

### 1. Find Music Files
You'll need two music files:
- **Ambient Music**: Dark, mysterious, atmospheric background music
- **Combat Music**: Intense, dramatic music for combat situations

### 2. Recommended Sources
- **Freesound.org** - Free ambient sounds and music
- **OpenGameArt.org** - Free game music
- **YouTube Audio Library** - Royalty-free music
- **Incompetech.com** - Kevin MacLeod's free music

### 3. File Format
- Use **OGG Vorbis** format for best compression
- Keep files reasonably sized (2-5 MB each)
- Loop seamlessly for continuous playback

### 4. Adding Music to Godot

1. **Import Music Files**:
   - Drag your music files into the Godot FileSystem
   - Place them in a `music/` folder

2. **Assign to Audio Players**:
   - Open `scenes/Main.tscn`
   - Select the `AudioManager` node
   - In the Inspector, find:
     - `AmbientMusic` → Stream → Load your ambient music
     - `CombatMusic` → Stream → Load your combat music

3. **Test the System**:
   - Run the game
   - Ambient music should start playing
   - When player health drops below 30, combat music should play
   - When health goes back above 30, ambient music returns

## Audio Manager Features

### Music Transitions
- Smooth fade between ambient and combat music
- No jarring cuts or interruptions
- Automatic volume management

### Sound Effects (Ready for Implementation)
- Footstep sounds
- Dungeon generation sounds
- Health warning sounds
- Death sounds

### Volume Controls
- Separate volume controls for music and SFX
- Adjustable via code or UI

## Testing the System

1. **Start the game** - Ambient music should play
2. **Take damage** (if you have a way to damage the player) - Combat music should start
3. **Heal above 30 HP** - Ambient music should return
4. **Regenerate dungeon** (Space key) - Music should continue playing

## Customization

### Changing Combat Triggers
Edit `scripts/Player.gd` in the `check_combat_state()` function:
```gdscript
# Current: Combat when health < 30
if health < 30 and not is_in_combat:
    enter_combat()
```

### Adding More Audio Players
Add more `AudioStreamPlayer` nodes to the `AudioManager` for:
- Environmental sounds
- UI sounds
- Character voice lines
- Ambient dungeon sounds

## Troubleshooting

- **No music playing**: Check that music files are assigned to the AudioStreamPlayer nodes
- **Music not transitioning**: Check that the AudioManager script is properly attached
- **Volume too loud/quiet**: Adjust the `music_volume` variable in AudioManager.gd

## Future Enhancements

- **Dynamic music layers** (add instruments based on danger level)
- **Location-based music** (different themes for different areas)
- **Interactive music** (music responds to player actions)
- **Audio settings menu** (in-game volume controls)


shader_type canvas_item;

uniform float light_radius = 200.0;
uniform vec2 player_position;
uniform sampler2D dungeon_texture;

float calculate_distance_to_wall(vec2 world_pos) {
	// Convert world position to tile coordinates
	vec2 tile_pos = world_pos / 24.0;  // 24 is tile size
	ivec2 tile_coord = ivec2(floor(tile_pos));
	
	// Sample the dungeon texture to check for walls
	// This would need to be pre-generated from your dungeon
	vec4 tile_data = texture(dungeon_texture, tile_pos / 64.0);  // Assuming 64x64 dungeon
	
	// If it's a wall tile, return 0
	if (tile_data.r > 0.5) {
		return 0.0;
	}
	
	// Search outward for walls
	float max_radius = light_radius / 24.0;
	
	for (float radius = 1.0; radius <= max_radius; radius += 1.0) {
		for (float dx = -radius; dx <= radius; dx += 1.0) {
			for (float dy = -radius; dy <= radius; dy += 1.0) {
				// Check perimeter only
				if (abs(dx) == radius || abs(dy) == radius) {
					ivec2 check_tile = tile_coord + ivec2(dx, dy);
					vec2 check_pos = vec2(check_tile) / 64.0;
					vec4 check_data = texture(dungeon_texture, check_pos);
					
					if (check_data.r > 0.5) {
						// Found a wall, calculate distance
						vec2 wall_center = vec2(check_tile) * 24.0 + vec2(12.0);
						return distance(world_pos, wall_center);
					}
				}
			}
		}
	}
	
	return light_radius;
}

void fragment() {
	// Convert screen coordinates to world coordinates
	vec2 world_pos = (UV - 0.5) * 2.0 * light_radius + player_position;
	
	// Calculate distance to nearest wall
	float distance_to_wall = calculate_distance_to_wall(world_pos);
	
	// Create smooth lighting falloff
	float visibility = 1.0 - smoothstep(0.0, light_radius, distance_to_wall);
	
	// Set color (transparent = visible, opaque = dark)
	COLOR = vec4(0.0, 0.0, 0.0, 1.0 - visibility);
}

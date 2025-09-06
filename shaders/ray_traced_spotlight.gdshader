shader_type canvas_item;

uniform sampler2D visibility_texture;
uniform vec2 player_pos;
uniform float radius;
uniform float texture_scale;
uniform float ray_thickness : hint_range(0.1, 2.0) = 0.5;
uniform float anti_aliasing_strength : hint_range(0.0, 1.0) = 0.8;

void fragment() {
	vec4 visibility_color = texture(visibility_texture, UV);
	
	// Create smooth circular spotlight with enhanced anti-aliasing
	float distance = length(UV - player_pos);
	float circle_alpha = 1.0 - smoothstep(radius - 0.05, radius + 0.05, distance);
	
	// Enhanced anti-aliasing for the visibility texture
	vec2 texel_size = 1.0 / textureSize(visibility_texture, 0);
	vec4 visibility_smooth = vec4(0.0);
	float sample_count = 0.0;
	
	// Multi-sample anti-aliasing for smoother ray edges
	for(float x = -2.0; x <= 2.0; x += 1.0) {
		for(float y = -2.0; y <= 2.0; y += 1.0) {
			vec2 offset = vec2(x, y) * texel_size * ray_thickness;
			visibility_smooth += texture(visibility_texture, UV + offset);
			sample_count += 1.0;
		}
	}
	visibility_smooth /= sample_count;
	
	// Additional smoothing pass for ultra-smooth edges
	vec4 final_visibility = mix(visibility_color, visibility_smooth, anti_aliasing_strength);
	
	// Combine circle and visibility with smooth blending
	float final_alpha = min(circle_alpha, final_visibility.a);
	
	// Apply additional edge smoothing
	final_alpha = smoothstep(0.0, 1.0, final_alpha);
	
	COLOR = vec4(0.0, 0.0, 0.0, final_alpha);
}

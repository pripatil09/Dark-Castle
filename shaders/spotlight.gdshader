shader_type canvas_item;

uniform float spotlight_radius : hint_range(0.0, 1.0) = 0.3;
uniform float spotlight_strength : hint_range(0.0, 1.0) = 0.8;
uniform vec2 player_position : hint_range(0.0, 1.0) = vec2(0.5, 0.5);

void fragment() {
    vec2 center = player_position;
    float distance = length(UV - center);
    
    // Create gradual spotlight effect
    float spotlight = 1.0 - smoothstep(0.0, spotlight_radius, distance);
    spotlight = pow(spotlight, 2.0);
    
    // Apply darkening effect
    float darkness = 1.0 - (spotlight * spotlight_strength);
    COLOR = vec4(0.0, 0.0, 0.0, darkness);
}

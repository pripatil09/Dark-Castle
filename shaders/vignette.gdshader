shader_type canvas_item;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.7;
uniform float vignette_radius : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    float distance = length(UV - center);

    // Create vignette effect - more gradual and visible
    float vignette = 1.0 - smoothstep(vignette_radius - 0.3, vignette_radius + 0.2, distance);
    vignette = pow(vignette, 2.0);

    // Apply vignette to the color - darker edges
    COLOR = vec4(0.0, 0.0, 0.0, vignette * vignette_strength);
}

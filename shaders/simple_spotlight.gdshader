shader_type canvas_item;

uniform sampler2D visibility_texture;

void fragment() {
    // Use only the ray casting visibility texture
    vec4 visibility_color = texture(visibility_texture, UV);
    
    // The visibility texture has transparent areas where rays can see
    // and opaque areas where walls block vision
    COLOR = vec4(0.0, 0.0, 0.0, visibility_color.a);
}

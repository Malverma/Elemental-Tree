shader_type canvas_item;
// Sways a sprite in the wind: each texel row shifts sideways by a whole number
// of texels, more toward the top, so the art bends without losing its pixel grid.

uniform float strength = 1.5;  // sway at the very top, in texels
uniform float speed = 1.3;
uniform float phase = 0.0;
// UV y where the sway fades to zero (1.0 = the bottom edge of the texture).
uniform float base_y = 1.0;

void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE;
	float row = (floor(UV.y / texel.y) + 0.5) * texel.y;
	float h = clamp((base_y - row) / base_y, 0.0, 1.0);
	float t = TIME * speed + phase;
	float sway = (sin(t) * 0.7 + sin(t * 2.3 + row * 9.0) * 0.3) * strength * h * h;
	COLOR = texture(TEXTURE, vec2(UV.x - round(sway) * texel.x, UV.y));
}

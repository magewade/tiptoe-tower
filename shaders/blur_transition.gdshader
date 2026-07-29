shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;
uniform float blur_amount : hint_range(0.0, 20.0) = 0.0;

void fragment() {
	vec4 sum = vec4(0.0);
	float total = 0.0;
	for (int x = -4; x <= 4; x++) {
		for (int y = -4; y <= 4; y++) {
			vec2 offset = vec2(float(x), float(y)) * blur_amount * SCREEN_PIXEL_SIZE;
			sum += textureLod(SCREEN_TEXTURE, SCREEN_UV + offset, 0.0);
			total += 1.0;
		}
	}
	vec4 blurred = sum / total;
	float darken = clamp(blur_amount / 16.0, 0.0, 1.0) * 0.6;
	COLOR = mix(blurred, vec4(0.0, 0.0, 0.0, 1.0), darken);
}

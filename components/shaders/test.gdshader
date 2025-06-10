shader_type canvas_item;

uniform sampler2D noise_texture: repeat_enable, filter_nearest;

uniform float density: hint_range(0.0, 1.0) = 0.25;

uniform vec2 direction = vec2(0.02, 0.1);

uniform float speed_multiplyer = 0.1;

uniform float speed_scale = 0;

void fragment() {
	vec2 uv = UV + direction * speed_scale;
	
	float noise = texture(noise_texture, uv).r;
	float fog = clamp(noise * 2.0 - 1.0, 0.0, 1.0);
	COLOR.a *= fog * density;
}
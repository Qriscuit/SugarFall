shader_type canvas_item;
render_mode unshaded;

uniform float heartbeat : hint_range(0.0, 1.0) = 0.0;
uniform float viewport_aspect = 0.5625;

void fragment() {
	vec2 p = (UV - vec2(0.5, 0.44)) * vec2(viewport_aspect, 1.0);
	float pool = exp(-dot(p * vec2(2.8, 1.8), p * vec2(2.8, 1.8)) * 2.1);
	float upper_glow = exp(-dot(p - vec2(0.0, -0.23), p - vec2(0.0, -0.23)) * 13.0);
	float light = smoothstep(0.0, 1.0, heartbeat);
	vec3 shade = vec3(0.145, 0.121, 0.145);
	vec3 warm = vec3(0.610, 0.510, 0.405);
	vec3 color = mix(shade, warm, pool * 0.86);
	color += vec3(0.035, 0.026, 0.014) * upper_glow;
	color += vec3(0.034, 0.028, 0.020) * pool * light;
	COLOR = vec4(color, 1.0);
}

shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float blur_lod : hint_range(0.0, 3.0) = 1.5;
uniform vec4 shade : source_color = vec4(0.15, 0.12, 0.18, 1.0);

void fragment() {
	vec3 clear_board = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	vec3 soft_board = textureLod(screen_texture, SCREEN_UV, blur_lod).rgb;
	vec3 blurred = mix(clear_board, soft_board, amount);
	COLOR = vec4(mix(blurred, shade.rgb, 0.36 * amount), 1.0);
}

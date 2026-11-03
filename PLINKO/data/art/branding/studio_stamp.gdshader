shader_type canvas_item;
render_mode unshaded;

// Preserve the supplied stamp's ink silhouette and grain. Its photographed
// paper is suppressed live, rather than repainting the studio's lettering.
uniform float heartbeat : hint_range(0.0, 1.0) = 0.0;
uniform vec4 resting_ink : source_color = vec4(0.255, 0.208, 0.247, 1.0);
uniform vec4 peak_ink : source_color = vec4(1.000, 0.790, 0.535, 1.0);

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float red_ink = max(0.0, source.r - max(source.g, source.b));
	float silhouette = smoothstep(0.06, 0.34, red_ink) * source.a;
	float pigment = mix(0.80, 1.0, clamp(source.r * 1.65, 0.0, 1.0));
	// Warm light rolls over the original ink rather than flashing it red.
	float light = smoothstep(0.0, 1.0, heartbeat);
	float face_gradient = mix(1.06, 0.91, UV.y);
	vec3 ink = mix(resting_ink.rgb, peak_ink.rgb, light) * pigment * face_gradient;
	COLOR = vec4(ink, silhouette);
}

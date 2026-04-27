shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform sampler2D fire_texture : source_color;
uniform sampler2D noise_texture : repeat_enable;
uniform float scroll_speed = 1.2;
uniform float life_value : hint_range(0.0, 1.0) = 1.0;

// TF2 Colors (High values for HDR glow)
uniform vec4 color_start : source_color = vec4(4.0, 3.0, 1.0, 1.0); // Bright White-Yellow
uniform vec4 color_mid : source_color = vec4(1.0, 0.3, 0.0, 1.0);   // Deep Orange
uniform vec4 color_end : source_color = vec4(0.1, 0.1, 0.1, 0.0);   // Smoke

void vertex() {
	// 1. Extract the scale from the Model Matrix before we normalize it
	// We calculate the length of the X, Y, and Z basis vectors
	vec3 base_scale = vec3(
		length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz)
	);

	// 2. Your Billboard math
	mat4 modified_model_view = VIEW_MATRIX * mat4(
		vec4(normalize(INV_VIEW_MATRIX[0].xyz), 0.0),
		vec4(normalize(INV_VIEW_MATRIX[1].xyz), 0.0),
		vec4(normalize(INV_VIEW_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);

	// 3. Multiply the view matrix by a scale matrix to bring the size back
	modified_model_view = modified_model_view * mat4(
		vec4(base_scale.x, 0.0, 0.0, 0.0),
		vec4(0.0, base_scale.y, 0.0, 0.0),
		vec4(0.0, 0.0, base_scale.z, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);

	MODELVIEW_MATRIX = modified_model_view;
}

void fragment() {
	// 1. Get scrolling noise
	vec2 noise_uv = UV + vec2(0.0, TIME * scroll_speed);
	float noise = texture(noise_texture, noise_uv).r;
	
	// 2. Warp the Fire Texture UVs (The "TF2 Wiggle")
	// This pushes the pixels around using the noise so it's not a perfect circle
	vec2 warped_uv = UV + (vec2(noise) - 0.5) * 0.15;
	float fire_shape = texture(fire_texture, warped_uv).r;
	
	// 3. Alpha Erosion (The Secret Sauce)
	// As life_value goes down, we "cut" the fire using the noise
	float erosion = smoothstep(1.0 - life_value, 1.0 - life_value + 0.2, noise);
	
	// 4. Combine Color
	vec3 final_color = mix(color_end.rgb, color_mid.rgb, clamp(life_value * 2.0, 0.0, 1.0));
	if (life_value > 0.7) {
		final_color = mix(final_color, color_start.rgb, (life_value - 0.7) * 3.3);
	}
	
	ALBEDO = final_color;
	ALPHA = fire_shape * erosion * life_value;
}
shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform float emission_intensity : hint_range(0.0, 20.0) = 2.0;
uniform int particles_anim_h_frames = 1;
uniform int particles_anim_v_frames = 1;

void vertex() {
	// 1. STRIP ROTATION & LOCK Y-AXIS
	// We take the world position of the particle
	vec3 world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	
	// We get the scale from the original matrix so we don't lose particle size
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	
	// Construct a new basis:
	// UP is always global Up
	vec3 v_y = vec3(0.0, 1.0, 0.0); 
	// FORWARD is towards the camera, but flattened on the Y axis
	vec3 v_z = normalize(INV_VIEW_MATRIX[3].xyz - world_pos);
	v_z.y = 0.0; 
	v_z = normalize(v_z);
	// RIGHT is the cross product
	vec3 v_x = cross(v_y, v_z);
	
	// Rebuild the MODELVIEW_MATRIX to ignore node rotation
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(v_x * s.x, 0.0),
		vec4(v_y * s.y, 0.0),
		vec4(v_z * s.z, 0.0),
		vec4(world_pos, 1.0)
	);

	// 2. ANIMATION MATH
	float h_frames = float(particles_anim_h_frames);
	float v_frames = float(particles_anim_v_frames);
	float particle_total_frames = h_frames * v_frames;
	float particle_frame = floor(INSTANCE_CUSTOM.z * particle_total_frames);
	
	UV /= vec2(h_frames, v_frames);
	UV += vec2(mod(particle_frame, h_frames) / h_frames, floor(particle_frame / h_frames) / v_frames);
}

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	ALBEDO = albedo_tex.rgb * COLOR.rgb * emission_intensity;
	ALPHA = albedo_tex.a * COLOR.a;
}
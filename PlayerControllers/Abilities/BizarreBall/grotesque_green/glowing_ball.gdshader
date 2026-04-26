shader_type spatial;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	ALBEDO = vec3(0.6 + 0.3 * sin(TIME * 5.0), 0.6 + 0.3 * sin(TIME * 5.0), 0.6 + 0.3 * sin(TIME * 5.0));
	ROUGHNESS = 0.1;
	EMISSION = vec3(0, 0.6 + 0.3 * sin(TIME * 5.0), 0);
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}

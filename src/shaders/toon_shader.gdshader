shader_type spatial;

// Cel-shaded toon shader with outline.
// Supports albedo color, 3-step light banding, rim lighting, and specular highlight.

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.4;
uniform float shadow_softness : hint_range(0.0, 0.2) = 0.02;
uniform vec4 shadow_color : source_color = vec4(0.6, 0.5, 0.7, 1.0);
uniform float rim_amount : hint_range(0.0, 1.0) = 0.5;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float specular_size : hint_range(0.0, 1.0) = 0.3;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	ALBEDO = albedo_color.rgb;
}

void light() {
	// Diffuse - stepped cel shading
	float NdotL = dot(NORMAL, LIGHT);
	float light_band = smoothstep(shadow_threshold - shadow_softness, shadow_threshold + shadow_softness, NdotL);

	vec3 lit_color = ALBEDO * LIGHT_COLOR * ATTENUATION;
	vec3 shadow = ALBEDO * shadow_color.rgb * LIGHT_COLOR * ATTENUATION;
	vec3 diffuse = mix(shadow, lit_color, light_band);

	// Specular - hard edge highlight
	vec3 half_dir = normalize(LIGHT + VIEW);
	float NdotH = dot(NORMAL, half_dir);
	float spec_band = smoothstep(1.0 - specular_size - 0.01, 1.0 - specular_size + 0.01, NdotH);
	vec3 specular = spec_band * specular_strength * LIGHT_COLOR * ATTENUATION;

	// Rim lighting
	float rim_dot = 1.0 - dot(NORMAL, VIEW);
	float rim_band = smoothstep(1.0 - rim_amount - 0.01, 1.0 - rim_amount + 0.01, rim_dot);
	float rim_light = rim_band * max(0.0, NdotL);
	vec3 rim = rim_light * rim_color.rgb * LIGHT_COLOR * ATTENUATION;

	DIFFUSE_LIGHT += diffuse + specular + rim;
}

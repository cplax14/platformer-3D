shader_type canvas_item;

// Iris wipe transition — circle SDF that grows/shrinks.
// progress = 0.0: fully transparent (scene visible)
// progress = 1.0: fully black (scene hidden)

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform float softness : hint_range(0.0, 0.1) = 0.02;

void fragment() {
	vec2 uv = UV - center;
	// Correct for aspect ratio: compress x so circle isn't stretched on widescreen
	float aspect = SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y;  // height/width
	uv.x *= aspect;

	float dist = length(uv);
	// Max radius covers entire screen from center
	float max_radius = length(vec2(0.5 * aspect, 0.5));
	// Invert progress so 1.0 = fully black (radius 0)
	float radius = max_radius * (1.0 - progress);

	float alpha = smoothstep(radius, radius + softness, dist);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}

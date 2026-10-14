shader_type canvas_item;
render_mode unshaded;

uniform float base_cell_size = 64.0;
uniform int major_step_count = 5;
uniform int level_step_count = 5;
uniform vec4 minor_color : source_color = vec4(0.40, 0.55, 0.59, 0.24);
uniform vec4 major_color : source_color = vec4(0.35, 0.48, 0.52, 0.34);
uniform float grid_opacity = 1.0;
uniform float minor_width = 0.75;
uniform float major_width = 1.0;
uniform float target_screen_spacing = 24.0;
uniform float fade_range = 1.0;
varying vec2 world_position;

void vertex() { world_position = VERTEX; }

float line_mask(vec2 position, float spacing, vec2 world_per_pixel, float width) {
	vec2 nearest = abs(mod(position + spacing * 0.5, spacing) - spacing * 0.5);
	vec2 pixels = nearest / world_per_pixel;
	float distance_to_line = min(pixels.x, pixels.y);
	return 1.0 - smoothstep(max(0.0, width * 0.5 - 0.5), width * 0.5 + 0.5, distance_to_line);
}
vec4 level_color(float spacing, vec2 pixel_size) {
	float minor = line_mask(world_position, spacing, pixel_size, minor_width);
	float major = line_mask(world_position, spacing * float(major_step_count), pixel_size, major_width);
	float a_major = major * major_color.a;
	float a_minor = minor * minor_color.a * (1.0 - major);
	// Premultiplied representation for crossfade; avoids bright transparent fringes.
	return vec4(major_color.rgb * a_major + minor_color.rgb * a_minor, a_major + a_minor);
}
void fragment() {
	vec2 pixel_size = max(fwidth(world_position), vec2(0.000001));
	float base_pixels = base_cell_size / max(pixel_size.x, pixel_size.y);
	float detail = max(0.0, log(target_screen_spacing / base_pixels) / log(float(level_step_count)));
	float level = floor(detail);
	float spacing = base_cell_size * pow(float(level_step_count), level);
	float blend = smoothstep(1.0 - fade_range, 1.0, fract(detail));
	vec4 ink = mix(level_color(spacing, pixel_size),
		level_color(spacing * float(level_step_count), pixel_size), blend);
	COLOR = vec4(ink.rgb / max(ink.a, 0.000001), ink.a * grid_opacity);
}

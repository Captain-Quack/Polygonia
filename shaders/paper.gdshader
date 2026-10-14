shader_type canvas_item;
render_mode unshaded;

uniform vec4 paper_color : source_color = vec4(0.965, 0.945, 0.906, 1.0);
uniform vec4 grain_color : source_color = vec4(0.506, 0.455, 0.380, 1.0);
uniform float grain_strength = 0.035;
uniform float grain_scale = 1.6;
uniform float grain_seed = 27.0;
varying vec2 paper_position;

void vertex() { paper_position = VERTEX; }

float hash(vec2 p) {
	p = mod(p, 4096.0);
	return fract(sin(dot(p, vec2(127.1, 311.7)) + grain_seed) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 p = paper_position / grain_scale;
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	// Unresolved fine texture converges to its mean instead of shimmering.
	float resolved = 1.0 - smoothstep(0.5, 2.0, footprint);
	float grain = mix(0.5, noise(p), resolved);
	vec3 paper = mix(paper_color.rgb, grain_color.rgb,
		grain * grain_strength * grain_color.a);
	COLOR = vec4(paper, paper_color.a);
}

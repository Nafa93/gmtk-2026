shader_type canvas_item;

uniform vec2 center = vec2(0.5, 0.5);
uniform float radius = 1.5;
uniform float aspect_ratio = 1.7777778;
uniform vec4 curtain_color : source_color = vec4(0.025, 0.018, 0.012, 1.0);

void fragment() {
	vec2 offset = UV - center;
	offset.x *= aspect_ratio;
	float outside_circle = smoothstep(radius - 0.008, radius + 0.008, length(offset));
	COLOR = vec4(curtain_color.rgb, curtain_color.a * outside_circle);
}

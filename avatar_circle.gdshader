shader_type canvas_item;

void fragment() {
	float dist = length(UV - vec2(0.5));
	
	float radius = 0.5;
	
	float is_inside = smoothstep(radius, radius - 0.02, dist);
	
	COLOR = vec4(COLOR.r, COLOR.g, COLOR.b, is_inside);
}

shader_type canvas_item;

// Color del "shock"
uniform vec3 shock_color : source_color = vec3(1.0, 0.0, 0.0);

// Fuerza inicial del desplazamiento
uniform float amplitude = 10.0;
// Frecuencia del temblor
uniform float frequency = 10.0;

// Tiempo personalizado (lo controlaremos desde GDScript)
uniform float shock_time = 999.0;

void vertex() {
	float exponent = shock_time;
	VERTEX.x += amplitude * exp(-3.0 * exponent) * sin(frequency * exponent);
}

void fragment() {
	float exponent = shock_time;
	vec4 normal_color = texture(TEXTURE, UV);
	COLOR.rgb = normal_color.rgb + shock_color * exp(-3.0 * exponent);
	COLOR.a = normal_color.a;
}

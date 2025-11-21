shader_type canvas_item;

// Porcentaje de vida restante (0.0 a 1.0). 1.0 es lleno.
uniform float percentage : hint_range(0.0, 1.0) = 1.0;
// Color de la parte vacía (Gris oscuro semitransparente)
uniform vec4 dim_color : source_color = vec4(0.3, 0.3, 0.3, 1.0); 

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Calculamos qué parte dibujar normal y cuál oscura.
	// El llenado es de abajo hacia arriba.
	// (1.0 - UV.y) invierte la coordenada vertical para que el 0 esté abajo.
	float is_filled = step(1.0 - UV.y, percentage);
	
	// Mezclamos: Si es parte llena -> Color original. Si no -> Color oscuro.
	vec3 final_rgb = mix(dim_color.rgb * tex_color.rgb, tex_color.rgb, is_filled);
	
	COLOR = vec4(final_rgb, tex_color.a);
}
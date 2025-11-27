shader_type canvas_item;

// 0.0 = Alfombra totalmente abierta (arriba del todo)
// 1.0 = Alfombra totalmente bajada/oculta (en el suelo)
uniform float roll_amount : hint_range(0.0, 1.0) = 0.0;

// Grosor del rollo (más grande para que se note "mas")
uniform float roll_radius : hint_range(0.0, 0.5) = 0.15;

// Colores para dar volumen 3D
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.6);
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 0.3); // Brillo superior

void fragment() {
	// Definimos el límite superior visible.
	// Si roll_amount es 0, limit es 0 (se ve todo desde arriba).
	// Si roll_amount es 1, limit es 1 (todo oculto bajo el límite).
	float current_top_y = roll_amount;

	// LÓGICA INVERSA: Cortamos lo que esté por ENCIMA del rollo (UV.y < current_top_y)
	// Así parece que la alfombra nace desde abajo.
	if (UV.y < current_top_y) {
		discard;
	}

	// Distancia desde el pixel actual hasta el borde superior del rollo
	float dist_to_edge = UV.y - current_top_y;

	// ZONA DEL ROLLO (La parte superior de lo visible)
	if (dist_to_edge < roll_radius) {
		// 't' va de 0.0 (borde superior) a 1.0 (donde se aplana)
		float t = dist_to_edge / roll_radius;

		// --- DEFORMACIÓN CILÍNDRICA "PARA EL OTRO LADO" ---
		// Curvamos la textura para que parezca que viene de atrás/abajo.
		// Usamos una función circular para "estirar" las coordenadas UV.
		float cylinder_curve = sqrt(1.0 - (1.0 - t) * (1.0 - t));
		
		// Desplazamos la textura hacia abajo para simular el enrollado
		vec2 new_uv = UV;
		// El factor 0.5 ajusta cuánto "viaja" la textura en el rollo
		new_uv.y = current_top_y + (roll_radius * cylinder_curve * 0.8);

		vec4 tex_color = texture(TEXTURE, new_uv);

		// --- ILUMINACIÓN VOLUMÉTRICA (Sombra + Brillo) ---
		
		// 1. Sombra en la parte baja del rollo (donde se mete hacia adentro)
		float shadow_intensity = smoothstep(0.4, 1.0, t); // Más oscura abajo
		
		// 2. Brillo en la parte alta del rollo (donde le daría la luz)
		float highlight_intensity = smoothstep(0.0, 0.4, 1.0 - t); // Más brillo arriba
		highlight_intensity = pow(highlight_intensity, 3.0); // Hacer el brillo más nítido (metálico/satinado)

		// Aplicar Sombra
		vec3 rgb_shadowed = mix(tex_color.rgb, shadow_color.rgb, shadow_intensity * shadow_color.a);
		
		// Aplicar Brillo
		vec3 final_rgb = mix(rgb_shadowed, highlight_color.rgb, highlight_intensity * highlight_color.a);
		
		COLOR = vec4(final_rgb, tex_color.a);

	} else {
		// ZONA PLANA (El resto de la alfombra hacia abajo)
		COLOR = texture(TEXTURE, UV);
	}
}
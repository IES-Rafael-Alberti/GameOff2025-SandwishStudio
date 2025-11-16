shader_type canvas_item;

uniform float roll_amount : hint_range(0.0, 1.0) = 0.0;
uniform float radius = 50.0;

// MÁS levantamiento para que se note más el roll
uniform float max_lift = 0.28; // antes 0.12 → ahora más del doble

void fragment() {
    vec2 uv = UV;

    // Limitar el roll solo a la parte superior
    float edge = smoothstep(0.0, 0.5, uv.y);

    // Curvatura suave basada en seno
    float wave = sin(uv.x * 3.14159 * 1.3); 
    //           ↑ pequeño aumento de frecuencia para mayor efecto

    // Aplicar el enrollado más fuerte pero todavía controlado
    uv.y -= wave * roll_amount * max_lift * edge;

    COLOR = texture(TEXTURE, uv);
}

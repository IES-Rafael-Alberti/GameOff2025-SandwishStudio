shader_type canvas_item;

uniform float roll_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 darken_color : source_color = vec4(0.0, 0.0, 0.0, 0.8);

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    // PROTECCIÓN 1: Si el porcentaje es casi 0 (ej. 0.001), no hacemos nada.
    // Esto evita la línea de 1 pixel arriba cuando el objeto está nuevo.
    if (roll_amount > 0.001) {

        // PROTECCIÓN 2: Solo oscurecemos píxeles que sean "sólidos" visiblemente.
        // Ignoramos el "polvo" transparente del borde (alpha < 0.1).
        if (tex_color.a > 0.1) {
            if (UV.y < roll_amount) {
                tex_color.rgb = mix(tex_color.rgb, darken_color.rgb, darken_color.a);
            }
        }
    }

    COLOR = tex_color * COLOR;
}
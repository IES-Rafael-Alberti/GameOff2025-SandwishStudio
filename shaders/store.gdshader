shader_type canvas_item;

uniform float roll_amount : hint_range(0.0, 1.0) = 0.0;
uniform float radius = 50.0; // Ajusta según necesites

void fragment() {
    vec2 uv = UV;

    // Calcula el ángulo máximo
    float angle = roll_amount * 3.14159; // media vuelta
    
    // Aplica un efecto de enrollado
    uv.y = uv.y + sin(uv.x * 3.14159) * roll_amount * 0.2; // ajuste simple

    // Muestra la textura
    COLOR = texture(TEXTURE, uv);
}

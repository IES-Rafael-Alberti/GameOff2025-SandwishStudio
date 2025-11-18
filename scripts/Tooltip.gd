extends PanelContainer

# Referencias a los nodos
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var description_label: RichTextLabel = $VBoxContainer/DescriptionLabel
@onready var sell_price_label: Label = $VBoxContainer/SellPriceLabel

# Variable para guardar el estilo y cambiarle el color del borde
var card_style: StyleBoxFlat

func _ready() -> void:
    hide()
    process_mode = Node.PROCESS_MODE_ALWAYS
    
    # --- 1. FORZAR QUE SE VEA SIEMPRE ENCIMA ---
    top_level = true
    z_index = 4096
    
    # --- 2. AUTO-DISEÑO PROFESIONAL ---
    card_style = StyleBoxFlat.new()
    card_style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
    
    card_style.border_width_left = 2
    card_style.border_width_top = 2
    card_style.border_width_right = 2
    card_style.border_width_bottom = 2
    card_style.border_color = Color.WHITE
    card_style.corner_radius_top_left = 8
    card_style.corner_radius_top_right = 8
    card_style.corner_radius_bottom_right = 8
    card_style.corner_radius_bottom_left = 8
    
    card_style.content_margin_left = 16
    card_style.content_margin_right = 16
    card_style.content_margin_top = 12
    card_style.content_margin_bottom = 12
    
    add_theme_stylebox_override("panel", card_style)
    
    custom_minimum_size.x = 280
    
    description_label.fit_content = true
    description_label.bbcode_enabled = true
    
    if has_node("VBoxContainer/ItemIcon"):
        get_node("VBoxContainer/ItemIcon").hide()

func _process(_delta: float) -> void:
    if visible:
        var mouse_pos = get_global_mouse_position()
        var tooltip_pos = mouse_pos + Vector2(24, 24)
        
        var viewport_size = get_viewport().get_visible_rect().size
        var tooltip_size = get_size()
        
        if tooltip_pos.x + tooltip_size.x > viewport_size.x:
            tooltip_pos.x = mouse_pos.x - tooltip_size.x - 24
            
        if tooltip_pos.y + tooltip_size.y > viewport_size.y:
            tooltip_pos.y = mouse_pos.y - tooltip_size.y - 24
            
        global_position = tooltip_pos

func show_tooltip(item_data: Resource, sell_percentage: int) -> void:
    if not item_data:
        return

    # A. OBTENER DATOS BÁSICOS
    var title_text = "Objeto Desconocido"
    if item_data.resource_name: title_text = item_data.resource_name
    if "piece_name" in item_data and not item_data.piece_name.is_empty(): title_text = item_data.piece_name
    elif "name_passive" in item_data and not item_data.name_passive.is_empty(): title_text = item_data.name_passive
    
    # B. COLORES Y SUBTÍTULOS
    var rarity_color = Color.WHITE
    var subtitle = ""
    
    if item_data is PieceData and item_data.piece_origin:
        rarity_color = _get_rarity_color(item_data.piece_origin.rarity)
        subtitle = "%s | %s" % [_get_race_name(item_data.piece_origin.race), item_data.piece_origin.role]
    elif item_data is PassiveData:
        rarity_color = Color("#FFD700") # Dorado para pasivas
        subtitle = "Mejora Pasiva"

    # C. APLICAR ESTILOS
    name_label.text = title_text.to_upper()
    name_label.label_settings = LabelSettings.new()
    name_label.label_settings.font_color = rarity_color
    name_label.label_settings.font_size = 18
    name_label.label_settings.outline_size = 4
    name_label.label_settings.outline_color = Color.BLACK
    
    if card_style:
        card_style.border_color = rarity_color

    # D. CONSTRUIR DESCRIPCIÓN (INFO AMPLIADA)
    var text = ""
    
    text += "[center][color=#aaaaaa][font_size=14]%s[/font_size][/color][/center]\n" % subtitle
    text += "[color=#444444]___________________________[/color]\n\n"

    # --- INFO DE PIEZAS ---
    if item_data is PieceData and item_data.piece_origin:
        var stats = item_data.piece_origin
        text += "[font_size=16]"
        text += "[color=#ff6b6b]⚔️ Daño:[/color]  [b]%s[/b]\n" % stats.base_damage
        text += "[color=#4ecdc4]❤️ Vida:[/color]  [b]%s[/b]\n" % stats.base_max_health
        text += "[color=#ffe66d]⚡ Vel:[/color]   [b]%s[/b]\n" % stats.base_attack_speed
        
        # Info Extra añadida
        if stats.critical_chance > 0:
            text += "[color=#ff9f43]🎯 Crit:[/color]  [b]%s%%[/b]\n" % stats.critical_chance
        if stats.critical_damage > 1.0:
            text += "[color=#ff9f43]💥 Daño Crit:[/color] [b]x%s[/b]\n" % stats.critical_damage
        if stats.gold_per_enemy > 0:
            text += "[color=#ffd700]💰 Oro/Kill:[/color] [b]%s[/b]\n" % stats.gold_per_enemy
            
        text += "[/font_size]\n"
    
    # --- INFO DE PASIVAS ---
    elif item_data is PassiveData:
        text += "[font_size=16]"
        text += _get_passive_stats_string(item_data) # Función auxiliar abajo
        text += "[/font_size]\n\n"

    # Descripción en cursiva
    if "description" in item_data and not item_data.description.is_empty():
        text += "[color=#dddddd][i]%s[/i][/color]" % item_data.description

    description_label.text = text

    # E. PRECIO
    if "price" in item_data and item_data.price > 0:
        var final_price = item_data.price
        var prefix = "COSTO:"
        var price_color = Color("#ffcc00")
        
        if sell_percentage > 0:
            final_price = int(item_data.price * (sell_percentage / 100.0))
            prefix = "VENTA:"
            price_color = Color("#77ff77")
            
        sell_price_label.text = "%s %d" % [prefix, final_price]
        sell_price_label.modulate = price_color
        sell_price_label.show()
    else:
        sell_price_label.hide()

    show()

func hide_tooltip() -> void:
    hide()

# --- UTILIDADES ---
func _get_rarity_color(rarity_enum: int) -> Color:
    match rarity_enum:
        0: return Color("#bdc3c7") # Común
        1: return Color("#3498db") # Raro
        2: return Color("#9b59b6") # Épico
        3: return Color("#f1c40f") # Legendario
        _: return Color.WHITE

func _get_race_name(race_enum: int) -> String:
    match race_enum:
        0: return "Nórdica"
        1: return "Japonesa"
        2: return "Europea"
        _: return "Clase"

# Nueva función para traducir los datos numéricos de la pasiva a texto
func _get_passive_stats_string(data: PassiveData) -> String:
    var val = data.value
    match data.type:
        PassiveData.PassiveType.HEALTH_INCREASE:
            return "[color=#4ecdc4]✚ Vida Max:[/color] [b]+%s[/b]" % val
        PassiveData.PassiveType.CRITICAL_DAMAGE_INCREASE:
            return "[color=#ff9f43]💥 Daño Crítico:[/color] [b]+%s[/b]" % val
        PassiveData.PassiveType.CRITICAL_CHANCE_INCREASE:
            return "[color=#ff9f43]🎯 Prob. Crítico:[/color] [b]+%s%%[/b]" % val
        PassiveData.PassiveType.ATTACK_SPEED_INCREASE:
            return "[color=#ffe66d]⚡ Vel. Ataque:[/color] [b]+%s[/b]" % val
        PassiveData.PassiveType.BASE_DAMAGE_INCREASE:
            return "[color=#ff6b6b]⚔️ Daño Base:[/color] [b]+%s[/b]" % val
    return ""

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
	
	custom_minimum_size.x = 300 # Un poco más ancho para la comparativa
	
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

# AHORA RECIBE 'current_count' (cantidad que ya tienes en inventario)
func show_tooltip(item_data: Resource, sell_percentage: int, current_count: int = 0) -> void:
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
		subtitle = "%s | %s" % [_get_race_name(item_data.piece_origin.race), _get_rarity_name(item_data.piece_origin.rarity)]
	elif item_data is PassiveData:
		rarity_color = Color("#FFD700") # Dorado para pasivas
		subtitle = "Mejora Pasiva"

	# C. APLICAR ESTILOS
	name_label.text = title_text.to_upper()
	name_label.label_settings = LabelSettings.new()
	name_label.label_settings.font_color = rarity_color
	name_label.label_settings.font_size = 20
	name_label.label_settings.outline_size = 4
	name_label.label_settings.outline_color = Color.BLACK
	
	if card_style:
		card_style.border_color = rarity_color

	# D. CONSTRUIR DESCRIPCIÓN (INFO AMPLIADA Y COMPARATIVA)
	var text = ""
	
	text += "[center][color=#aaaaaa][font_size=14]%s[/font_size][/color][/center]\n" % subtitle
	text += "[color=#444444]___________________________[/color]\n\n"

	# --- INFO DE PIEZAS (Lógica de Mejora) ---
	if item_data is PieceData and item_data.piece_origin:
		var origin = item_data.piece_origin
		
		# Lógica de Tier: 0=Bronce, 1=Plata, 2=Oro (Aproximación basada en cantidad)
		# Suponiendo: 1 copia = Bronce, 2 copias = Plata, 3 copias = Oro
		
		# Si es venta (sell_percentage > 0), mostramos el estado ACTUAL.
		# Si es compra (sell_percentage == 0), calculamos el FUTURO.
		
		var current_tier_idx = clampi(current_count, 1, 3) - 1 # Tier actual (0, 1 o 2)
		if current_count == 0: current_tier_idx = 0 # Si no tienes, empiezas en bronce
		
		var next_tier_idx = current_tier_idx
		var is_upgrade = false
		
		if sell_percentage == 0 and current_count > 0 and current_count < 3:
			next_tier_idx = current_tier_idx + 1
			is_upgrade = true
		
		var tier_keys = ["BRONCE", "PLATA", "ORO"]
		var tier_colors = ["#cd7f32", "#c0c0c0", "#ffd700"]
		
		var current_stats = origin.stats[tier_keys[current_tier_idx]]
		var next_stats = origin.stats[tier_keys[next_tier_idx]]
		
		text += "[font_size=16]"
		
		if is_upgrade:
			text += "[center][shake rate=5 level=10][color=%s]★ MEJORA A %s ★[/color][/shake][/center]\n" % [tier_colors[next_tier_idx], tier_keys[next_tier_idx]]
		else:
			# Mostrar tier actual
			text += "[center][color=%s]Nivel: %s[/color][/center]\n" % [tier_colors[current_tier_idx], tier_keys[current_tier_idx]]

		# Función auxiliar para mostrar stat o cambio de stat
		text += _format_stat_row("⚔️ Daño", current_stats["dmg"], next_stats["dmg"], is_upgrade, "#ff6b6b")
		text += _format_stat_row("❤️ Vida", current_stats["hp"], next_stats["hp"], is_upgrade, "#4ecdc4")
		text += _format_stat_row("⚡ Vel", current_stats["aps"], next_stats["aps"], is_upgrade, "#ffe66d")
		
		if next_stats["crit_chance"] > 0:
			text += _format_stat_row("🎯 Crit", str(current_stats["crit_chance"]) + "%", str(next_stats["crit_chance"]) + "%", is_upgrade, "#ff9f43")
		
		if next_stats["crit_mult"] > 1.0:
			text += _format_stat_row("💥 CritDmg", "x" + str(current_stats["crit_mult"]), "x" + str(next_stats["crit_mult"]), is_upgrade, "#ff9f43")

		text += "[/font_size]\n"
	
	# --- INFO DE PASIVAS ---
	elif item_data is PassiveData:
		text += "[font_size=16]"
		text += _get_passive_stats_string(item_data)
		text += "[/font_size]\n\n"

	# Descripción en cursiva
	if "description" in item_data and not item_data.description.is_empty():
		text += "[color=#dddddd][i]%s[/i][/color]" % item_data.description

	description_label.text = text

	# E. PRECIO Y ESTADO DE COPIAS
	if "price" in item_data and item_data.price > 0:
		var final_price = item_data.price
		var prefix = "COSTO:"
		var price_color = Color("#ffcc00")
		
		if sell_percentage > 0:
			final_price = int(item_data.price * (sell_percentage / 100.0))
			prefix = "VENTA:"
			price_color = Color("#77ff77")
		else:
			# Mostrar cuántas tienes si estás comprando
			if current_count > 0 and current_count < 3:
				sell_price_label.text = "TIENES: %d/3" % current_count
				sell_price_label.modulate = Color.CYAN
				# Añadimos el precio debajo o al lado
				prefix = " | COSTO:"
			elif current_count >= 3:
				prefix = "MAXIMIZADO | "
				price_color = Color.RED
			
		# Concatenar texto del precio si no se sobrescribió completamente
		if "TIENES" in sell_price_label.text and sell_percentage == 0:
			sell_price_label.text += "  %d€" % _calculate_price_logic(item_data, current_count)
		else:
			sell_price_label.text = "%s %d€" % [prefix, final_price]
			
		if sell_percentage == 0:
			sell_price_label.modulate = price_color
			
		sell_price_label.show()
	else:
		sell_price_label.hide()

	show()

# --- NUEVA FUNCIÓN DE FORMATEO DE STATS ---
func _format_stat_row(label: String, val_old, val_new, show_upgrade: bool, color_hex: String) -> String:
	var s = "[color=%s]%s:[/color] " % [color_hex, label]
	
	if show_upgrade and str(val_old) != str(val_new):
		# Muestra: 10 -> 15 (en verde brillante)
		s += "[color=#aaaaaa]%s[/color] [color=#ffffff]→[/color] [b][color=#00ff00]%s[/color][/b]\n" % [str(val_old), str(val_new)]
	else:
		# Muestra normal: 10
		s += "[b]%s[/b]\n" % str(val_new)
	return s

# Simulación de la lógica de precio del Store para mostrarlo bien en el tooltip
func _calculate_price_logic(data, count) -> int:
	# Ajusta esto según tu lógica real en Store.gd
	var base = data.price
	var mult = 1.0 + (0.5 * count) # Asumiendo duplicado pieza mult 0.5
	return int(base * mult)

func hide_tooltip() -> void:
	hide()

# --- UTILIDADES (SIN CAMBIOS) ---
func _get_rarity_color(rarity_enum: int) -> Color:
	match rarity_enum:
		0: return Color("#bdc3c7")
		1: return Color("#3498db")
		2: return Color("#9b59b6")
		3: return Color("#f1c40f")
		_: return Color.WHITE

func _get_race_name(race_enum: int) -> String:
	match race_enum:
		0: return "Nórdica"
		1: return "Japonesa"
		2: return "Europea"
		_: return "Clase"
		
func _get_rarity_name(rarity_enum: int) -> String: # Corregido nombre de variable
	match rarity_enum:
		0: return "Común"
		1: return "Raro"
		2: return "Épico"
		_: return "Legendario"

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

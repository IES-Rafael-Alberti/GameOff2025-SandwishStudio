extends PanelContainer

# Referencias a los nodos
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var description_label: RichTextLabel = $VBoxContainer/DescriptionLabel
@onready var sell_price_label: Label = $VBoxContainer/SellPriceLabel

# Estilo dinámico para la tarjeta
var card_style: StyleBoxFlat

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# --- 1. CONFIGURACIÓN DE CAPA ---
	top_level = true
	z_index = 4096
	
	# --- 2. ESTILO VISUAL "PREMIUM" ---
	card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.05, 0.05, 0.07, 0.95) # Fondo casi negro elegante
	
	# Bordes y Esquinas
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 12
	card_style.corner_radius_top_right = 12
	card_style.corner_radius_bottom_right = 12
	card_style.corner_radius_bottom_left = 12
	
	# Sombra (Shadow) para darle profundidad (Efecto 3D)
	card_style.shadow_color = Color(0, 0, 0, 0.6)
	card_style.shadow_size = 8
	card_style.shadow_offset = Vector2(4, 4)
	
	# Margenes internos cómodos
	card_style.content_margin_left = 20
	card_style.content_margin_right = 20
	card_style.content_margin_top = 16
	card_style.content_margin_bottom = 16
	
	add_theme_stylebox_override("panel", card_style)
	
	# Hacemos el tooltip un poco más ancho para que quepan las tablas
	custom_minimum_size.x = 340 
	
	description_label.fit_content = true
	description_label.bbcode_enabled = true
	
	# Ocultar icono si existe (usaremos texto enriquecido)
	if has_node("VBoxContainer/ItemIcon"):
		get_node("VBoxContainer/ItemIcon").hide()

func _process(_delta: float) -> void:
	if visible:
		# Lógica para que el tooltip siga al ratón y no se salga de pantalla
		var mouse_pos = get_global_mouse_position()
		var tooltip_pos = mouse_pos + Vector2(24, 24)
		
		var viewport_size = get_viewport().get_visible_rect().size
		var tooltip_size = get_size()
		
		if tooltip_pos.x + tooltip_size.x > viewport_size.x:
			tooltip_pos.x = mouse_pos.x - tooltip_size.x - 24
		if tooltip_pos.y + tooltip_size.y > viewport_size.y:
			tooltip_pos.y = mouse_pos.y - tooltip_size.y - 24
			
		global_position = tooltip_pos

func show_tooltip(item_data: Resource, sell_percentage: int, current_count: int = 0) -> void:
	if not item_data:
		return

	# --- A. DATOS BÁSICOS ---
	var title_text = "Objeto"
	if item_data.resource_name: title_text = item_data.resource_name
	if "piece_name" in item_data and not item_data.piece_name.is_empty(): title_text = item_data.piece_name
	elif "name_passive" in item_data and not item_data.name_passive.is_empty(): title_text = item_data.name_passive
	
	# --- B. DETERMINAR COLORES Y RAREZA ---
	var rarity_color = Color.WHITE
	var subtitle = ""
	var bg_tint = Color(0.05, 0.05, 0.07, 0.95) # Default dark
	
	if item_data is PieceData and item_data.piece_origin:
		rarity_color = _get_rarity_color(item_data.piece_origin.rarity)
		subtitle = "%s • %s" % [_get_race_name(item_data.piece_origin.race), _get_rarity_name(item_data.piece_origin.rarity)]
		# Tintar muy levemente el fondo según la rareza
		bg_tint = rarity_color.darkened(0.85)
		bg_tint.a = 0.95
	elif item_data is PassiveData:
		rarity_color = Color("#FFD700") 
		subtitle = "✦ Mejora Pasiva ✦"
		bg_tint = Color(0.1, 0.1, 0.05, 0.95)

	# --- C. APLICAR ESTILOS VISUALES ---
	
	# 1. Título Principal
	name_label.text = title_text.to_upper()
	name_label.label_settings = LabelSettings.new()
	name_label.label_settings.font_color = rarity_color
	name_label.label_settings.font_size = 22
	name_label.label_settings.outline_size = 6
	name_label.label_settings.outline_color = Color(0, 0, 0, 1)
	name_label.label_settings.shadow_size = 4
	name_label.label_settings.shadow_color = Color(0, 0, 0, 0.5)
	
	# 2. Actualizar Borde y Fondo del Panel
	if card_style:
		card_style.border_color = rarity_color
		card_style.bg_color = bg_tint

	# --- D. CONSTRUCCIÓN DEL CONTENIDO (BBCode) ---
	var text = ""
	
	# Subtítulo elegante
	text += "[center][color=#cccccc][font_size=14]%s[/font_size][/color][/center]\n" % subtitle
	
	# Separador decorativo
	text += "[center][color=#444444]━━━━━━━━━━━━━━━━━━[/color][/center]\n"

	# --- LÓGICA PIEZAS (Stats, Stacks, Tropas, Usos) ---
	if item_data is PieceData and item_data.piece_origin:
		var origin = item_data.piece_origin
		
		# Cálculos de Tier
		var current_tier_idx = clampi(current_count, 1, 3) - 1 
		if current_count == 0: current_tier_idx = 0 
		
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
		
		# 1. CABECERA DE NIVEL (Con animación si es mejora)
		if is_upgrade:
			text += "[center][wave amp=25 freq=5][color=%s]★ MEJORA A %s ★[/color][/wave][/center]" % [tier_colors[next_tier_idx], tier_keys[next_tier_idx]]
		else:
			text += "[center][color=%s]NIVEL: %s[/color][/center]" % [tier_colors[current_tier_idx], tier_keys[current_tier_idx]]

		# 2. BARRA DE PROGRESO VISUAL (Stacks)
		# Usamos caracteres grandes y colores claros
		var bar_visual = ""
		for i in range(3):
			if i < current_count:
				# Cuadrado Lleno
				bar_visual += "[color=%s]◼[/color] " % tier_colors[current_tier_idx]
			else:
				# Cuadrado Vacío (más tenue)
				bar_visual += "[color=#333333]◻[/color] "
		
		text += "[center][font_size=18]%s[/font_size][/center]\n" % bar_visual
		
		# 3. TABLA DE ESTADÍSTICAS (Organización limpia)
		# Usamos una tabla de 2 columnas para alinear Icono+Nombre | Valor
		text += "[table=2]"
		
		# --- DATOS ESPECIALES (TROPAS Y USOS) ---
		var cur_uses = item_data.uses
		var max_uses = cur_uses
		if item_data.has_meta("max_uses"): max_uses = item_data.get_meta("max_uses")
		
		var members = current_stats.get("members", 1)
		var next_members = next_stats.get("members", members)

		# Fila Tropas (Fondo ligeramente más claro para destacar)
		text += "[cell][color=#aaaaaa] 👥 Tropas[/color][/cell]"
		if is_upgrade and members != next_members:
			text += "[cell][color=#ffffff]%d[/color] [color=#00ff00]➞ %d[/color][/cell]" % [members, next_members]
		else:
			text += "[cell][b]%d[/b][/cell]" % members
			
		# Fila Usos
		var u_color = "#ffffff"
		if cur_uses <= 1: u_color = "#ff5555" # Rojo alerta
		text += "[cell][color=#aaaaaa] 🔋 Usos[/color][/cell]"
		text += "[cell][color=%s]%d[/color] / %d[/cell]" % [u_color, cur_uses, max_uses]

		# Espacio vacío en tabla para separar
		text += "[cell] [/cell][cell] [/cell]" 

		# --- STATS DE COMBATE ---
		text += _row_table("⚔️ Daño", current_stats["dmg"], next_stats["dmg"], is_upgrade, "#ff7675")
		text += _row_table("❤️ Vida", current_stats["hp"], next_stats["hp"], is_upgrade, "#55efc4")
		text += _row_table("⚡ Vel.", current_stats["aps"], next_stats["aps"], is_upgrade, "#ffeaa7")
		
		if next_stats["crit_chance"] > 0:
			text += _row_table("🎯 Crit%", str(current_stats["crit_chance"]) + "%", str(next_stats["crit_chance"]) + "%", is_upgrade, "#ff9f43")
		
		if next_stats["crit_mult"] > 1.0:
			text += _row_table("💥 CritDmg", "x" + str(current_stats["crit_mult"]), "x" + str(next_stats["crit_mult"]), is_upgrade, "#ff9f43")

		text += "[/table]"
		text += "[/font_size]\n"
	
	# --- LÓGICA PASIVAS ---
	elif item_data is PassiveData:
		text += "[font_size=16]\n"
		text += _get_passive_stats_string(item_data)
		text += "[/font_size]\n\n"

	# Descripción (Lore o efecto extra) en itálica y gris suave
	if "description" in item_data and not item_data.description.is_empty():
		text += "[color=#888888][i]%s[/i][/color]" % item_data.description

	description_label.text = text

	# --- E. PRECIO Y PIE DE PÁGINA ---
	if "price" in item_data and item_data.price > 0:
		var final_price = item_data.price
		var price_txt = ""
		var price_color = Color("#ffcc00") # Oro default
		
		if sell_percentage > 0:
			# MODO VENTA
			final_price = int(item_data.price * (sell_percentage / 100.0))
			price_txt = "VENTA: %d€" % final_price
			price_color = Color("#55efc4") # Verde
		else:
			# MODO COMPRA
			var cost = final_price
			# Lógica de coste incremental si ya tienes copias
			if current_count > 0 and current_count < 3:
				cost = _calculate_price_logic(item_data, current_count)
				price_txt = "TIENES: %d/3  |  COSTO: %d€" % [current_count, cost]
				sell_price_label.modulate = Color.CYAN
			elif current_count >= 3:
				price_txt = "¡MAXIMIZADO!"
				price_color = Color("#ff5555") # Rojo
			else:
				price_txt = "COSTO: %d€" % cost
		
		sell_price_label.text = price_txt
		if sell_percentage == 0 and current_count < 3:
			sell_price_label.modulate = price_color
		
		sell_price_label.show()
	else:
		sell_price_label.hide()

	show()

# --- HELPER PARA FILAS DE TABLA ---
func _row_table(label: String, val_old, val_new, show_upg: bool, color_hex: String) -> String:
	var row = ""
	# Columna 1: Etiqueta con color
	row += "[cell][color=%s] %s[/color][/cell]" % [color_hex, label]
	
	# Columna 2: Valor (con flecha si cambia)
	if show_upg and str(val_old) != str(val_new):
		row += "[cell][color=#cccccc]%s[/color] [color=#00ff00]➞ %s[/color][/cell]" % [str(val_old), str(val_new)]
	else:
		row += "[cell][b]%s[/b][/cell]" % str(val_new)
	return row

# --- PRECIO ---
func _calculate_price_logic(data, count) -> int:
	var base = data.price
	var mult = 1.0 + (0.5 * count)
	return int(base * mult)

func hide_tooltip() -> void:
	hide()

# --- UTILIDADES DE COLOR ---
func _get_rarity_color(rarity_enum: int) -> Color:
	match rarity_enum:
		0: return Color("#b2bec3") # Común (Gris plata)
		1: return Color("#0984e3") # Raro (Azul brillante)
		2: return Color("#a55eea") # Épico (Morado neón)
		3: return Color("#f1c40f") # Legendario (Dorado)
		_: return Color.WHITE

func _get_race_name(race_enum: int) -> String:
	match race_enum:
		0: return "Nórdica"
		1: return "Japonesa"
		2: return "Europea"
		_: return "Clase"
		
func _get_rarity_name(rarity_enum: int) -> String:
	match rarity_enum:
		0: return "Común"
		1: return "Raro"
		2: return "Épico"
		3: return "Legendario"
		_: return ""

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
func show_passive_summary(passive_counts: Dictionary, multiplier: float) -> void:
	if passive_counts.is_empty():
		return # No mostramos nada si no hay pasivas

	# 1. Configurar Título y Estilo
	name_label.text = "RESUMEN DE MEJORAS"
	name_label.label_settings = LabelSettings.new()
	name_label.label_settings.font_color = Color("#FFD700") # Dorado
	name_label.label_settings.font_size = 22
	name_label.label_settings.outline_size = 6
	name_label.label_settings.outline_color = Color(0, 0, 0, 1)
	
	if card_style:
		card_style.border_color = Color("#FFD700")
		card_style.bg_color = Color(0.1, 0.1, 0.05, 0.98) # Fondo verdoso oscuro

	# 2. Construir Texto (BBCode)
	var text = ""
	
	# Mostrar el Multiplicador Actual destacado
	var mult_color = "#ffffff"
	if multiplier > 1.0: mult_color = "#00ff00" # Verde si hay bonus
	
	text += "[center][color=#aaaaaa]Multiplicador de Huecos vacios:[/color] [b][color=%s]x%.2f[/color][/b][/center]\n" % [mult_color, multiplier]
	text += "[center][color=#444444]━━━━━━━━━━━━━━━━━━[/color][/center]\n"
	
	text += "[font_size=16]"
	
	# Iterar sobre todas las pasivas
	for id in passive_counts:
		var entry = passive_counts[id]
		var data: PassiveData = entry["data"]
		var count: int = entry["count"]
		
		if not data: continue
		
		# Calcular el total real que recibe el jugador
		var total_value = (data.value * count) * multiplier
		
		# Formatear línea: Nombre (xCount) : +Total Stat
		var name_str = data.name_passive if not data.name_passive.is_empty() else "Pasiva"
		var stat_str = _get_passive_stat_label(data.type, total_value)
		
		text += "• [color=#ffcc00]%s[/color] [color=#888888](x%d)[/color]\n" % [name_str, count]
		text += "   └ %s\n" % stat_str
		
	text += "[/font_size]"
	
	description_label.text = text
	
	# Ocultar precio ya que es un resumen
	sell_price_label.hide()
	
	show()
func _get_passive_stat_label(type: int, total_val: float) -> String:
	# Redondeamos a 1 o 2 decimales para que se vea limpio
	var val_str = str(snapped(total_val, 0.1))
	match type:
		PassiveData.PassiveType.HEALTH_INCREASE: return "[color=#4ecdc4]+%s Vida Max[/color]" % val_str
		PassiveData.PassiveType.CRITICAL_DAMAGE_INCREASE: return "[color=#ff9f43]+%s Daño Crítico[/color]" % val_str
		PassiveData.PassiveType.CRITICAL_CHANCE_INCREASE: return "[color=#ff9f43]+%s%% Prob. Crit[/color]" % val_str
		PassiveData.PassiveType.ATTACK_SPEED_INCREASE: return "[color=#ffe66d]+%s Vel. Ataque[/color]" % val_str
		PassiveData.PassiveType.BASE_DAMAGE_INCREASE: return "[color=#ff6b6b]+%s Daño Base[/color]" % val_str
	return ""

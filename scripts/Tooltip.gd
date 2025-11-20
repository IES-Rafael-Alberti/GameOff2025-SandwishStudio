extends PanelContainer

# Referencias a los nodos internos
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var description_label: RichTextLabel = $VBoxContainer/DescriptionLabel
@onready var sell_price_label: Label = $VBoxContainer/SellPriceLabel

# Variable de estilo para bordes dinámicos
var card_style: StyleBoxFlat

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	top_level = true
	z_index = 4096
	
	# --- ESTILO VISUAL DE TARJETA ---
	card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.08, 0.12, 0.98) # Fondo oscuro azulado
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
	custom_minimum_size.x = 320 # Un poco más ancho para que quepa todo bien
	
	description_label.fit_content = true
	description_label.bbcode_enabled = true
	
	if has_node("VBoxContainer/ItemIcon"):
		get_node("VBoxContainer/ItemIcon").hide()

func _process(_delta: float) -> void:
	if visible:
		var mouse_pos = get_global_mouse_position()
		# Desplazamos un poco para que no tape el cursor
		var tooltip_pos = mouse_pos + Vector2(20, 20)
		
		var viewport_size = get_viewport().get_visible_rect().size
		var tooltip_size = get_size()
		
		# Mantener dentro de la pantalla
		if tooltip_pos.x + tooltip_size.x > viewport_size.x:
			tooltip_pos.x = mouse_pos.x - tooltip_size.x - 10
		if tooltip_pos.y + tooltip_size.y > viewport_size.y:
			tooltip_pos.y = mouse_pos.y - tooltip_size.y - 10
			
		global_position = tooltip_pos

# Función principal de llamada
func show_tooltip(item_data: Resource, sell_percentage: int, current_count: int = 0, is_inventory_summary: bool = false, inventory_ref = null) -> void:
	if not item_data: return

	# --- MODO RESUMEN DE INVENTARIO (PASIVAS) ---
	if is_inventory_summary and inventory_ref and item_data is PassiveData:
		_render_passive_summary_visual(inventory_ref)
		show()
		return

	# --- MODO NORMAL (PIEZA O PASIVA INDIVIDUAL) ---
	var title_text = "Objeto"
	if item_data.resource_name: title_text = item_data.resource_name
	if "piece_name" in item_data and not item_data.piece_name.is_empty(): title_text = item_data.piece_name
	elif "name_passive" in item_data and not item_data.name_passive.is_empty(): title_text = item_data.name_passive
	
	var rarity_color = Color.WHITE
	var subtitle = ""
	
	if item_data is PieceData and item_data.piece_origin:
		rarity_color = _get_rarity_color(item_data.piece_origin.rarity)
		subtitle = "%s | %s" % [_get_race_name(item_data.piece_origin.race), _get_rarity_name(item_data.piece_origin.rarity)]
	elif item_data is PassiveData:
		rarity_color = Color("#FFD700") # Dorado
		subtitle = "Mejora Pasiva"

	_set_title_style(title_text, rarity_color)

	var text = ""
	text += "[center][color=#8888aa][font_size=14]%s[/font_size][/color][/center]\n" % subtitle
	text += "[color=#333333]___________________________________[/color]\n\n"

	# Detalles de PIEZA
	if item_data is PieceData and item_data.piece_origin:
		var origin = item_data.piece_origin
		var current_tier_idx = clampi(current_count, 1, 3) - 1
		if current_count == 0: current_tier_idx = 0
		
		var next_tier_idx = current_tier_idx
		var is_upgrade = (sell_percentage == 0 and current_count > 0 and current_count < 3)
		if is_upgrade: next_tier_idx += 1
		
		var tiers = ["BRONCE", "PLATA", "ORO"]
		var colors = ["#cd7f32", "#c0c0c0", "#ffd700"]
		
		var c_stats = origin.stats[tiers[current_tier_idx]]
		var n_stats = origin.stats[tiers[next_tier_idx]]
		
		text += "[font_size=16]"
		if is_upgrade:
			text += "[center][shake rate=5 level=10][color=%s]★ MEJORA A %s ★[/color][/shake][/center]\n" % [colors[next_tier_idx], tiers[next_tier_idx]]
		else:
			text += "[center][color=%s]Nivel Actual: %s[/color][/center]\n" % [colors[current_tier_idx], tiers[current_tier_idx]]

		# Usamos iconos para stats de pieza también
		text += _format_stat_row("res://assets/ADMG.png", "Daño", c_stats["dmg"], n_stats["dmg"], is_upgrade, "#ff6b6b")
		text += _format_stat_row("res://assets/VIDA.png", "Vida", c_stats["hp"], n_stats["hp"], is_upgrade, "#4ecdc4")
		text += _format_stat_row("res://assets/ASPEED.png", "Velocidad", c_stats["aps"], n_stats["aps"], is_upgrade, "#ffe66d")
		
		if n_stats["crit_chance"] > 0:
			text += _format_stat_row("res://assets/Crit.png", "Crítico", str(c_stats["crit_chance"])+"%", str(n_stats["crit_chance"])+"%", is_upgrade, "#ff9f43")
		
		text += "[/font_size]\n"
	
	# Detalles de PASIVA (Individual)
	elif item_data is PassiveData:
		text += "[font_size=16]"
		text += _get_passive_single_string(item_data)
		text += "[/font_size]\n\n"

	if "description" in item_data and not item_data.description.is_empty():
		text += "[color=#bbbbbb][i]%s[/i][/color]" % item_data.description

	description_label.text = text
	_update_price_label(item_data, sell_percentage, current_count)
	show()

# --- MODO RESUMEN VISUAL (LIMPIO Y CLARO) ---
func _render_passive_summary_visual(inventory) -> void:
	_set_title_style("ESTADÍSTICAS DE BANCA", Color("#FFD700"))
	
	# 1. Calcular Multiplicador
	var multiplier = 1.0
	var empty_slots = 0
	if inventory.has_method("_get_empty_roulette_slots"):
		empty_slots = inventory._get_empty_roulette_slots()
		var bonus = inventory.empty_slot_bonus_per_slot
		multiplier = 1.0 + (empty_slots * bonus)
	
	var text = ""
	
	# Sección de Multiplicador
	text += "[center][bgcolor=#222222]  BONUS DE BANCA VACÍA  [/bgcolor][/center]\n"
	text += "[center][font_size=14]Huecos: %d  |  Bonus: +%.0f%%[/font_size][/center]" % [empty_slots, (multiplier-1.0)*100]
	text += "[center][font_size=20][b][color=#00ff00]MULTIPLICADOR x%.1f[/color][/b][/font_size][/center]\n" % multiplier
	text += "[color=#444444]___________________________________[/color]\n"
	
	# 2. Lista de Pasivas
	var passive_counts = inventory.passive_counts
	
	if passive_counts.is_empty():
		text += "\n[center][i][color=#666666]No tienes mejoras pasivas.[/color][/i][/center]"
	else:
		text += "[table=2]" # Usamos tabla invisible para alinear Icono/Nombre con Valor Total
		
		for id in passive_counts:
			var entry = passive_counts[id]
			var data = entry.data
			var count = entry.count
			var total_val = (data.value * count) * multiplier
			
			var val_str = ""
			if data.type == PassiveData.PassiveType.CRITICAL_CHANCE_INCREASE:
				val_str = "+%.1f%%" % total_val
			else:
				val_str = "+%.1f" % total_val
			
			var icon_bb = _get_icon_bbcode(data.type)
			
			# Columna 1: Icono + Nombre + Cantidad
			var col1 = "%s [b]%s[/b] [color=#888888](x%d)[/color]" % [icon_bb, data.resource_name, count]
			# Columna 2: Valor Total (Color cian brillante)
			var col2 = "[right][color=#4ecdc4][b]%s[/b][/color][/right]" % val_str
			
			text += "[cell]%s    [/cell][cell]%s[/cell]" % [col1, col2]
			
		text += "[/table]"
		text += "\n[center][font_size=10][color=#666666]*Valores incluyen el multiplicador[/color][/font_size][/center]"

	description_label.text = text
	sell_price_label.hide()

# --- HELPERS VISUALES ---

func _set_title_style(text: String, color: Color):
	name_label.text = text.to_upper()
	name_label.label_settings = LabelSettings.new()
	name_label.label_settings.font_color = color
	name_label.label_settings.font_size = 22
	name_label.label_settings.outline_size = 6
	name_label.label_settings.outline_color = Color.BLACK
	name_label.label_settings.shadow_size = 4
	name_label.label_settings.shadow_color = Color(0,0,0,0.5)
	card_style.border_color = color

# Devuelve el BBCode con la imagen del asset real
func _get_icon_bbcode(type: int) -> String:
	var path = ""
	match type:
		PassiveData.PassiveType.HEALTH_INCREASE: path = "res://assets/VIDA.png"
		PassiveData.PassiveType.BASE_DAMAGE_INCREASE: path = "res://assets/ADMG.png"
		PassiveData.PassiveType.ATTACK_SPEED_INCREASE: path = "res://assets/ASPEED.png"
		PassiveData.PassiveType.CRITICAL_CHANCE_INCREASE: path = "res://assets/Crit.png"
		PassiveData.PassiveType.CRITICAL_DAMAGE_INCREASE: path = "res://assets/CritDMG.png"
	
	if path != "":
		return "[img=24]%s[/img]" % path
	return "🔹"

func _get_passive_single_string(data: PassiveData) -> String:
	var icon = _get_icon_bbcode(data.type)
	var val_str = "+%s" % data.value
	if data.type == PassiveData.PassiveType.CRITICAL_CHANCE_INCREASE:
		val_str += "%"
		
	return "%s [color=#dddddd]%s:[/color] [b][color=#4ecdc4]%s[/color][/b]" % [icon, _get_stat_name(data.type), val_str]

func _format_stat_row(icon_path: String, label: String, val_old, val_new, show_upg: bool, col: String) -> String:
	var icon = "[img=20]%s[/img]" % icon_path
	var s = "%s [color=%s]%s:[/color] " % [icon, col, label]
	
	if show_upg and str(val_old) != str(val_new):
		s += "[color=#aaaaaa]%s[/color] [color=#ffffff]→[/color] [b][color=#00ff00]%s[/color][/b]\n" % [str(val_old), str(val_new)]
	else:
		s += "[b]%s[/b]\n" % str(val_new)
	return s

func _update_price_label(item_data, sell_percentage, current_count):
	if "price" in item_data and item_data.price > 0:
		var final_price = item_data.price
		var prefix = "COSTO:"
		var price_color = Color("#ffcc00")
		
		if sell_percentage > 0:
			final_price = int(item_data.price * (sell_percentage / 100.0))
			prefix = "VENTA:"
			price_color = Color("#77ff77")
		else:
			if current_count > 0 and current_count < 3:
				sell_price_label.text = "EN POSESIÓN: %d/3" % current_count
				sell_price_label.modulate = Color.CYAN
				prefix = " | COSTO:"
			elif current_count >= 3:
				prefix = "MAXIMIZADO | "
				price_color = Color.RED
		
		var price_text = "%s %d€" % [prefix, final_price]
		if "EN POSESIÓN" in sell_price_label.text and sell_percentage == 0:
			var cost = int(item_data.price * (1.0 + (0.5 * current_count)))
			sell_price_label.text += "  COSTO: %d€" % cost
		else:
			sell_price_label.text = price_text
			
		if sell_percentage == 0:
			sell_price_label.modulate = price_color
		sell_price_label.show()
	else:
		sell_price_label.hide()

func hide_tooltip() -> void:
	hide()

# --- UTILS (CORREGIDO MATCH) ---

func _get_rarity_color(r: int) -> Color:
	match r:
		0: return Color("#bdc3c7")
		1: return Color("#3498db")
		2: return Color("#9b59b6")
		3: return Color("#f1c40f")
		_: return Color.WHITE

func _get_race_name(r: int) -> String:
	match r: 
		0: return "Nórdica"
		1: return "Japonesa"
		2: return "Europea"
		_: return "Clase"
		
func _get_rarity_name(r: int) -> String:
	match r: 
		0: return "Común"
		1: return "Raro"
		2: return "Épico"
		_: return "Legendario"

func _get_stat_name(type: int) -> String:
	match type:
		PassiveData.PassiveType.HEALTH_INCREASE: return "Vida Max"
		PassiveData.PassiveType.BASE_DAMAGE_INCREASE: return "Daño Base"
		PassiveData.PassiveType.ATTACK_SPEED_INCREASE: return "Vel. Ataque"
		PassiveData.PassiveType.CRITICAL_CHANCE_INCREASE: return "Prob. Crítico"
		PassiveData.PassiveType.CRITICAL_DAMAGE_INCREASE: return "Daño Crítico"
	return "Stat"

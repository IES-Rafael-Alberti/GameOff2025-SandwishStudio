extends PanelContainer

# References to nodes
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var description_label: RichTextLabel = $VBoxContainer/DescriptionLabel
@onready var sell_price_label: RichTextLabel = $VBoxContainer/SellPriceLabel

@export_group("Stat Icons")
@export var icon_health: Texture2D
@export var icon_damage: Texture2D
@export var icon_speed: Texture2D
@export var icon_crit_chance: Texture2D
@export var icon_crit_damage: Texture2D
@export var icon_size: int = 20 

# Referencia al propio panel
@onready var tooltip: PanelContainer = self 

# Estilo dinámico
var card_style: StyleBoxFlat
var units_grid: HBoxContainer = null

func _ready() -> void:
	if sell_price_label:
		sell_price_label.fit_content = true  # <--- Vital para que no tenga altura 0
		sell_price_label.bbcode_enabled = true # <--- Necesario para las negritas [b] y la imagen [img]
	add_to_group("tooltip")
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	top_level = true
	z_index = 4096
	
	# --- ESTILO VISUAL BASE ---
	card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.08, 0.1, 0.98)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.shadow_color = Color(0, 0, 0, 0.5)
	card_style.shadow_size = 10
	card_style.shadow_offset = Vector2(4, 4)
	card_style.content_margin_left = 16
	card_style.content_margin_right = 16
	card_style.content_margin_top = 12
	card_style.content_margin_bottom = 12
	
	add_theme_stylebox_override("panel", card_style)
	custom_minimum_size.x = 340 
	
	description_label.fit_content = true
	description_label.bbcode_enabled = true
	
	if has_node("VBoxContainer/ItemIcon"):
		get_node("VBoxContainer/ItemIcon").hide()

	_ensure_units_grid_exists()

func _ensure_units_grid_exists():
	if units_grid and is_instance_valid(units_grid): return
	if has_node("VBoxContainer/UnitsGrid"):
		units_grid = $VBoxContainer/UnitsGrid
	else:
		units_grid = HBoxContainer.new()
		units_grid.name = "UnitsGrid"
		units_grid.alignment = BoxContainer.ALIGNMENT_CENTER
		units_grid.add_theme_constant_override("separation", 6)
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_top", 15)
		margin.add_child(units_grid)
		$VBoxContainer.add_child(margin)

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

func hide_tooltip() -> void:
	hide()

# ==============================================================================
# 1. TOOLTIP ESTÁNDAR (Objeto individual)
# ==============================================================================
func show_tooltip(item_data: Resource, sell_percentage: int, current_count: int = 0) -> void:
	if not item_data: return
	if units_grid:
			for child in units_grid.get_children():
				child.queue_free()
	# --- A. BASIC DATA ---
	var title_text = "Item"
	if item_data.resource_name: title_text = item_data.resource_name
	if "piece_name" in item_data and not item_data.piece_name.is_empty(): title_text = item_data.piece_name
	elif "name_passive" in item_data and not item_data.name_passive.is_empty(): title_text = item_data.name_passive
	
	# --- B. COLORS ---
	var rarity_color = Color.WHITE
	var subtitle = ""
	var bg_tint = Color(0.05, 0.05, 0.07, 0.95)
	
	if item_data is PieceData and item_data.piece_origin:
		rarity_color = _get_rarity_color(item_data.piece_origin.rarity)
		subtitle = "%s • %s" % [_get_race_name(item_data.piece_origin.race), _get_rarity_name(item_data.piece_origin.rarity)]
		bg_tint = rarity_color.darkened(0.85); bg_tint.a = 0.95
	elif item_data is PassiveData:
		rarity_color = Color("#FFD700") 
		subtitle = "✦ Passive Upgrade ✦"
		bg_tint = Color(0.1, 0.1, 0.05, 0.95)

	# --- C. STYLES ---
	
	name_label.text = title_text.to_upper()
	var theme_font := get_theme_default_font() # Godot 4
	var ls := LabelSettings.new()
	ls.font = theme_font
	ls.font_color = rarity_color
	ls.font_size = 22
	ls.outline_size = 4
	name_label.label_settings = ls
	name_label.label_settings.font_color = rarity_color
	name_label.label_settings.font_size = 22
	name_label.label_settings.outline_size = 6
	name_label.label_settings.outline_color = Color(0, 0, 0, 1)
	name_label.label_settings.shadow_size = 4
	name_label.label_settings.shadow_color = Color(0, 0, 0, 0.5)
	
	if card_style:
		card_style.border_color = rarity_color
		card_style.bg_color = bg_tint

	# --- D. CONTENT ---
	var text = ""
	text += "[center][color=#cccccc][font_size=14]%s[/font_size][/color][/center]\n" % subtitle
	text += "[center][color=#444444]━━━━━━━━━━━━━━━━━━[/color][/center]\n"

	if item_data is PieceData and item_data.piece_origin:
		var origin = item_data.piece_origin
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
		if is_upgrade:
			var tier_display = tier_keys[next_tier_idx].replace("BRONCE", "BRONZE").replace("PLATA", "SILVER").replace("ORO", "GOLD")
			text += "[center][wave amp=25 freq=5][color=%s]★ UPGRADE TO %s ★[/color][/wave][/center]" % [tier_colors[next_tier_idx], tier_display]
		else:
			var tier_display = tier_keys[current_tier_idx].replace("BRONCE", "BRONZE").replace("PLATA", "SILVER").replace("ORO", "GOLD")
			text += "[center][color=%s]LEVEL: %s[/color][/center]" % [tier_colors[current_tier_idx], tier_display]

		var bar_visual = ""
		for i in range(3):
			if i < current_count: bar_visual += "[color=%s]◼[/color] " % tier_colors[current_tier_idx]
			else: bar_visual += "[color=#333333]◻[/color] "
		text += "[center][font_size=18]%s[/font_size][/center]\n" % bar_visual
		
		text += "[table=2]"
		var cur_uses = item_data.uses
		var max_uses = item_data.get_meta("max_uses") if item_data.has_meta("max_uses") else cur_uses
		var members = current_stats.get("members", 1)
		var next_members = next_stats.get("members", members)

		text += "[cell][color=#aaaaaa] 👥 [b]Units[/b][/color][/cell]"
		if is_upgrade and members != next_members: text += "[cell][color=#ffffff]%d[/color] [color=#00ff00]➞ %d[/color][/cell]" % [members, next_members]
		else: text += "[cell][b]%d[/b][/cell]" % members
			
		var u_color = "#ffffff"
		if cur_uses <= 1:
			u_color = "#ff5555"

		text += "[cell][color=#aaaaaa][b]🔋 Uses[/b][/color][/cell]"
		text += "[cell][color=%s][b]%d[/b] / [b]%d[/b][/color][/cell]" % [u_color, cur_uses, max_uses]
		text += "[cell] [/cell][cell] [/cell]"

		# --- UPDATED: FULL STAT NAMES WITH ICONS ---
		text += _row_table("%s Damage" % _get_icon_tag(icon_damage), current_stats["dmg"], next_stats["dmg"], is_upgrade, "#ff7675")
		text += _row_table("%s Health" % _get_icon_tag(icon_health), current_stats["hp"], next_stats["hp"], is_upgrade, "#55efc4")
		text += _row_table("%s Attack Speed" % _get_icon_tag(icon_speed), current_stats["aps"], next_stats["aps"], is_upgrade, "#ffeaa7")
		
		if next_stats["crit_chance"] > 0:
			text += _row_table("%s Crit Chance" % _get_icon_tag(icon_crit_chance), str(current_stats["crit_chance"]) + "%", str(next_stats["crit_chance"]) + "%", is_upgrade, "#ff9f43")
		if next_stats["crit_mult"] > 1.0:
			text += _row_table("%s Crit Damage" % _get_icon_tag(icon_crit_damage), "x" + str(current_stats["crit_mult"]), "x" + str(next_stats["crit_mult"]), is_upgrade, "#ff9f43")

		text += "[/table][/font_size]\n"
	
	elif item_data is PassiveData:
		text += "[font_size=16]\n"
		text += _get_passive_stats_string(item_data)
		text += "[/font_size]\n\n"

	if "description" in item_data and not item_data.description.is_empty():
		text += "[color=#888888][i]%s[/i][/color]" % item_data.description

	description_label.text = text

# --- E. PRICE ---
	if "price" in item_data and item_data.price > 0:
		var final_price = item_data.price
		var price_txt = ""
		# Definimos un color por defecto para asegurar que siempre tenga uno
		
		if sell_percentage > 0:
			# --- LÓGICA DE VENTA ---
			final_price = int(item_data.price * (sell_percentage / 100.0))
			price_txt = "[b]SELL[/b]: %d " % final_price
			price_txt += "[img=16x16]res://assets/Coin (1).png[/img]"
		else:
			# --- LÓGICA DE COMPRA ---
			var cost = final_price
			if item_data is PassiveData:
				if current_count > 0:
					cost = _calculate_price_logic(item_data, current_count)
					price_txt = "[b]OWNED[/b]: %d  |  [b]COST[/b]: %d " % [current_count, cost]
					price_txt += "[img=16x16]res://assets/Coin (1).png[/img]"
				else:
					price_txt = "[b]COST[/b]: %d " % cost
					price_txt += "[img=16x16]res://assets/Coin (1).png[/img]"
			else: 
				if current_count >= 3:
					price_txt = "MAXED OUT!"
				elif current_count > 0:
					cost = _calculate_price_logic(item_data, current_count)
					price_txt = "[b]OWNED[/b]: %d/3  |  [b]COST[/b]: %d " % [current_count, cost]
					price_txt += "[img=16x16]res://assets/Coin (1).png[/img]"
				else:
					price_txt = "[b]COST[/b]: %d " % cost
					price_txt += "[img=16x16]res://assets/Coin (1).png[/img]"
		
		# --- APLICACIÓN FINAL UNIFICADA ---
		sell_price_label.text = price_txt
		sell_price_label.show()
	else:
		sell_price_label.hide()
	
	show()
	await get_tree().process_frame
	size = Vector2.ZERO
# ==============================================================================
# 2. TOOLTIP DE SINERGIAS (CON FIX DE IMÁGENES)
# ==============================================================================
func show_synergy_tooltip(race_name: String, current_count: int, max_count: int, bonuses: Array, color_theme: Color, all_pieces: Array = [], active_ids: Array = []) -> void:
	_ensure_units_grid_exists()
	
	name_label.text = race_name.to_upper()
	var theme_font := get_theme_default_font() # Godot 4
	var ls := LabelSettings.new()
	ls.font = theme_font
	ls.font_size = 22
	ls.outline_size = 4
	name_label.label_settings = ls
	name_label.label_settings.font_color = color_theme
	name_label.label_settings.font_size = 24
	name_label.label_settings.outline_size = 6
	name_label.label_settings.outline_color = Color(0, 0, 0, 1)
	
	if card_style:
		card_style.border_color = color_theme
		card_style.bg_color = Color(0.08, 0.08, 0.1, 0.98) 

	var text = ""
	var count_color = "#ffffff" if current_count > 0 else "#777777"
	text += "[center][color=#aaaaaa]Sinergia Activa:[/color] [color=%s][b]%d / %d[/b] Unidades[/color][/center]\n" % [count_color, current_count, max_count]
	text += "[center][color=#444444]━━━━━━━━━━━━━━━━━━[/color][/center]\n"
	
	text += "[table=1]"
	for i in range(bonuses.size()):
		var bonus_data = bonuses[i] 
		var req = bonus_data["required"]
		var desc = bonus_data["desc"]
		if current_count >= req:
			text += "[cell][color=%s]✔ [b](%d) %s[/b][/color][/cell]" % [color_theme.to_html(), req, desc]
		else:
			text += "[cell][color=#555555]🔒 (%d) %s[/color][/cell]" % [req, desc]
	text += "[/table]"
	
	text += "\n[center][i][font_size=12][color=#666666]Colección:[/color][/font_size][/i][/center]"
	description_label.text = text
	
	for child in units_grid.get_children(): child.queue_free()
	
	if not all_pieces.is_empty():
		var processed_ids = {}
		for piece_res in all_pieces:
			if not piece_res: continue
			var p_id = piece_res.get("id")
			if p_id != null:
				if p_id in processed_ids: continue
				processed_ids[p_id] = true
			
			var card_frame = PanelContainer.new()
			card_frame.custom_minimum_size = Vector2(48, 48)
			
			var rarity = 0
			if "rarity" in piece_res: rarity = piece_res.rarity
			var rarity_col = _get_rarity_color(rarity)
			
			var is_active = false
			if p_id != null:
				for act_id in active_ids:
					if str(act_id) == str(p_id): is_active = true; break
			
			var frame_style = StyleBoxFlat.new()
			frame_style.bg_color = Color(0, 0, 0, 0.5)
			frame_style.border_width_left = 2; frame_style.border_width_top = 2
			frame_style.border_width_right = 2; frame_style.border_width_bottom = 2
			frame_style.corner_radius_top_left = 4; frame_style.corner_radius_top_right = 4
			frame_style.corner_radius_bottom_right = 4; frame_style.corner_radius_bottom_left = 4
			
			if is_active:
				frame_style.border_color = rarity_col
				card_frame.modulate = Color(1, 1, 1, 1)
			else:
				frame_style.border_color = Color(0.3, 0.3, 0.3, 1)
				card_frame.modulate = Color(0.4, 0.4, 0.4, 0.8)

			card_frame.add_theme_stylebox_override("panel", frame_style)
			
			var icon_rect = TextureRect.new()
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.custom_minimum_size = Vector2(40, 40)
			
			var final_texture = null
			
			# 1. Obtenemos el nombre de la pieza
			var p_name = piece_res.get("display_name")
			if p_name == null: p_name = piece_res.get("piece_name")
			
			# 2. Lógica FORZADA: Buscar solo en la carpeta "blanco"
			if p_name:
				# Construimos la ruta específica ignorando cualquier icono que tenga el recurso
				var path_attempt = "res://assets/piezas/blanco/" + p_name + ".png"
				
				if ResourceLoader.exists(path_attempt):
					final_texture = load(path_attempt)
				else:
					# (Opcional) Imprimir error si no existe la imagen en esa carpeta
					print("Tooltip: No se encontró imagen 'blanco' para: ", p_name)

			# 3. Asignar la textura
			if final_texture: 
				icon_rect.texture = final_texture
			else:
				# Fallback: Cuadrado rojo semitransparente si no se encontró la imagen
				var placeholder = PlaceholderTexture2D.new()
				placeholder.size = Vector2(40,40)
				icon_rect.texture = placeholder
				icon_rect.modulate = Color(1, 0, 0, 0.2)

			var margin = MarginContainer.new()
			margin.add_theme_constant_override("margin_top", 4); margin.add_theme_constant_override("margin_bottom", 4)
			margin.add_theme_constant_override("margin_left", 4); margin.add_theme_constant_override("margin_right", 4)
			
			margin.add_child(icon_rect)
			card_frame.add_child(margin)
			units_grid.add_child(card_frame)

	sell_price_label.hide()
	show()
	await get_tree().process_frame
	size = Vector2.ZERO

func show_passive_list_tooltip(active_passives: Dictionary) -> void:
	_ensure_units_grid_exists()
	for child in units_grid.get_children(): child.queue_free()
	
	# --- ESTILO DEL PANEL ---
	name_label.text = "ESTADÍSTICAS"
	var theme_font := get_theme_default_font() # Godot 4
	var ls := LabelSettings.new()
	ls.font = theme_font
	ls.font_size = 22
	ls.outline_size = 4
	name_label.label_settings = ls
	name_label.label_settings.font_color = Color("#FFD700") # Dorado
	name_label.label_settings.font_size = 24
	name_label.label_settings.outline_size = 6
	name_label.label_settings.outline_color = Color(0, 0, 0, 1)
	
	if card_style:
		card_style.border_color = Color("#FFD700")
		card_style.bg_color = Color(0.08, 0.08, 0.1, 0.98) # Fondo oscuro sólido

	var text = ""
	
	if active_passives.is_empty():
		text += "\n[center][color=#666666][i]Inventario vacío[/i][/color][/center]\n"
	else:
		text += "[center][color=#aaaaaa]Bonificaciones actuales:[/color][/center]\n"
		text += "[color=#444444]━━━━━━━━━━━━━━━━━━[/color]\n"
		
		# Tabla de 3 columnas: Icono+Nombre | Cantidad | Total
		text += "[table=3]"
		
		var keys = active_passives.keys()
		keys.sort()
		
		for key in keys:
			var entry = active_passives[key]
			var p_data = entry["data"]
			var count = entry["count"]
			
			if not p_data: continue
			
			# 1. SELECCIÓN DE ICONO REAL Y COLOR
			var icon_path = ""
			var name_color = "#ffffff"
			
			match p_data.type:
				PassiveData.PassiveType.HEALTH_INCREASE: 
					icon_path = "res://assets/inventario/VIDA.png"
					name_color = "#ff5555" # Rojo Vida
				PassiveData.PassiveType.CRITICAL_DAMAGE_INCREASE: 
					icon_path = "res://assets/inventario/CritDMG.png"
					name_color = "#ff9f43" # Naranja
				PassiveData.PassiveType.CRITICAL_CHANCE_INCREASE: 
					icon_path = "res://assets/inventario/Crit.png"
					name_color = "#fab1a0" # Salmón
				PassiveData.PassiveType.ATTACK_SPEED_INCREASE: 
					icon_path = "res://assets/inventario/ASPEED.png"
					name_color = "#feca57" # Amarillo
				PassiveData.PassiveType.BASE_DAMAGE_INCREASE: 
					icon_path = "res://assets/inventario/ADMG.png"
					name_color = "#ee5253" # Rojo Daño
			
			# Creamos el tag de imagen bbcode. [img=ancho]ruta[/img]
			var icon_bbcode = ""
			if ResourceLoader.exists(icon_path):
				# Ajusta el tamaño (24px) para que cuadre con el texto
				icon_bbcode = "[img=24]%s[/img]" % icon_path 
			else:
				icon_bbcode = "🔸" # Fallback si falla la carga
			
			# 2. COLUMNA 1: Icono + Nombre
			# Usamos [valign] si está disponible o simplemente el icono inline
			text += "[cell][font_size=18][color=%s] %s %s  [/color][/font_size][/cell]" % [name_color, icon_bbcode, p_data.name_passive]
			
			# 3. COLUMNA 2: Cantidad (Estilo Badge/Etiqueta)
			text += "[cell][center][color=#666666]x[/color][b][font_size=18][color=#ffffff]%d[/color][/font_size][/b][/center][/cell]" % count
			
			# 4. COLUMNA 3: Valor Total Calculado
			var base_val = float(p_data.value)
			var total_val = base_val * count
			var val_str = ""
			
			if p_data.type == PassiveData.PassiveType.CRITICAL_CHANCE_INCREASE:
				val_str = "+%d%%" % int(total_val)
			elif floor(total_val) == total_val:
				val_str = "+%d" % int(total_val)
			else:
				val_str = "+%.1f" % total_val
				
			text += "[cell][p align=right][b][font_size=18][color=#55efc4]%s[/color][/font_size][/b][/p][/cell]" % val_str
			
		text += "[/table]"
		text += "\n[color=#444444]━━━━━━━━━━━━━━━━━━[/color]"

	description_label.text = text
	sell_price_label.hide()
	show()

# --- HELPERS ---
func _row_table(label: String, val_old, val_new, show_upg: bool, color_hex: String) -> String:
	var row = "[cell][color=%s] %s[/color][/cell]" % [color_hex, label]
	if show_upg and str(val_old) != str(val_new):
		# CORREGIDO: Añadidas etiquetas [b] para negrita en ambos valores
		row += "[cell][color=#cccccc][b]%s[/b][/color] [color=#00ff00]➞ [b]%s[/b][/color][/cell]" % [str(val_old), str(val_new)]
	else:
		# Caso normal (ya tenía negrita)
		row += "[cell][b]%s[/b][/cell]" % str(val_new)
	return row

func _calculate_price_logic(data, count) -> int:
	return int(data.price * (1.0 + (0.5 * count)))

func _get_rarity_color(rarity_enum: int) -> Color:
	match rarity_enum:
		0: return Color("#b2bec3")
		1: return Color("#0984e3")
		2: return Color("#a55eea")
		3: return Color("#f1c40f")
		_: return Color.WHITE

func _get_race_name(race_enum: int) -> String:
	match race_enum:
		0: return "Nordic"
		1: return "Japanese"
		2: return "European"
		_: return "Class"
		
func _get_rarity_name(rarity_enum: int) -> String:
	match rarity_enum:
		0: return "Common"
		1: return "Rare"
		2: return "Epic"
		3: return "Legendary"
		_: return ""

# --- PASSIVE STATS WITH ICONS ---
func _get_passive_stats_string(data: PassiveData) -> String:
	var val = data.value
	match data.type:
		PassiveData.PassiveType.HEALTH_INCREASE: return "[color=#4ecdc4] Max health:[/color] [b]+%s[/b]" % val
		PassiveData.PassiveType.CRITICAL_DAMAGE_INCREASE: return "[color=#ff9f43] Crit. damage:[/color] [b]+%s[/b]" % val
		PassiveData.PassiveType.CRITICAL_CHANCE_INCREASE: return "[color=#ff9f43] Crit. chance:[/color] [b]+%s%%[/b]" % val
		PassiveData.PassiveType.ATTACK_SPEED_INCREASE: return "[color=#ffe66d] Atk. speed:[/color] [b]+%s[/b]" % val
		PassiveData.PassiveType.BASE_DAMAGE_INCREASE: return "[color=#ff6b6b] Base Damage:[/color] [b]+%s[/b]" % val
	return ""
func show_passive_summary(passive_counts: Dictionary, multiplier: float) -> void:
	if passive_counts.is_empty(): return 

	name_label.text = "UPGRADES SUMMARY"
	var theme_font := get_theme_default_font() # Godot 4
	var ls := LabelSettings.new()
	ls.font = theme_font
	ls.font_size = 22
	ls.outline_size = 4
	name_label.label_settings = ls
	name_label.label_settings.font_color = Color("#FFD700") 
	name_label.label_settings.font_size = 22
	name_label.label_settings.outline_size = 6
	name_label.label_settings.outline_color = Color(0, 0, 0, 1)
	
	if card_style:
		card_style.border_color = Color("#FFD700")
		card_style.bg_color = Color(0.1, 0.1, 0.05, 0.98) 

	var text = ""
	var mult_color = "#ffffff"
	if multiplier > 1.0: mult_color = "#00ff00"
	
	text += "[center][color=#aaaaaa]Empty Slot Multiplier:[/color] [b][color=%s]x%.2f[/color][/b][/center]\n" % [mult_color, multiplier]
	text += "[center][color=#444444]━━━━━━━━━━━━━━━━━━[/color][/center]\n"
	text += "[font_size=16]"
	
	for id in passive_counts:
		var entry = passive_counts[id]
		var data: PassiveData = entry["data"]
		var count: int = entry["count"]
		if not data: continue
		
		var total_value = (data.value * count) * multiplier
		var name_str = data.name_passive if not data.name_passive.is_empty() else "Passive"
		var stat_str = _get_passive_stat_label(data.type, total_value)
		
		text += "• [color=#ffcc00]%s[/color] [color=#888888](x%d)[/color]\n" % [name_str, count]
		text += "   └ %s\n" % stat_str
		
	text += "[/font_size]"
	description_label.text = text
	sell_price_label.hide()
	show()

func _get_passive_stat_label(type: int, total_val: float) -> String:
	var val_str = str(snapped(total_val, 0.1))
	match type:
		PassiveData.PassiveType.HEALTH_INCREASE:
			return "[color=#4ecdc4]%s +%s Max Health[/color]" % [_get_icon_tag(icon_health), val_str]
		PassiveData.PassiveType.CRITICAL_DAMAGE_INCREASE:
			return "[color=#ff9f43]%s +%s Crit Damage[/color]" % [_get_icon_tag(icon_crit_damage), val_str]
		PassiveData.PassiveType.CRITICAL_CHANCE_INCREASE:
			return "[color=#ff9f43]%s +%s%% Crit Chance[/color]" % [_get_icon_tag(icon_crit_chance), val_str]
		PassiveData.PassiveType.ATTACK_SPEED_INCREASE:
			return "[color=#ffe66d]%s +%s Attack Speed[/color]" % [_get_icon_tag(icon_speed), val_str]
		PassiveData.PassiveType.BASE_DAMAGE_INCREASE:
			return "[color=#ff6b6b]%s +%s Base Damage[/color]" % [_get_icon_tag(icon_damage), val_str]
	return ""
func _get_icon_tag(texture: Texture2D) -> String:
	if texture:
		return "[img=%dx%d]%s[/img]" % [icon_size, icon_size, texture.resource_path]
	return ""

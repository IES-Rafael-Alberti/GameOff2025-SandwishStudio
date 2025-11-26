extends PanelContainer

# --- REFERENCIAS A NODOS ---
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var description_label: RichTextLabel = $VBoxContainer/DescriptionLabel
@onready var sell_price_label: Label = $VBoxContainer/SellPriceLabel

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

# ==============================================================================
# CICLO DE VIDA
# ==============================================================================
func _ready() -> void:
	add_to_group("tooltip")
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	top_level = true
	z_index = 4096
	
	# --- ESTILO VISUAL BASE ---
	card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.05, 0.05, 0.07, 0.98) # Fondo oscuro moderno
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.corner_radius_top_left = 6
	card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_right = 6
	card_style.corner_radius_bottom_left = 6
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
# 1. TOOLTIP ESTÁNDAR (Piezas y Pasivas) - DISEÑO MODERNO V3
# ==============================================================================
func show_tooltip(item_data: Resource, sell_percentage: int, current_count: int = 0) -> void:
	if not item_data: return
	
	# Limpieza de iconos anteriores
	if units_grid:
		for child in units_grid.get_children():
			child.queue_free()

	# --- A. PREPARACIÓN DE DATOS ---
	var title_text = "Item"
	if item_data.resource_name: title_text = item_data.resource_name
	if "piece_name" in item_data and not item_data.piece_name.is_empty(): title_text = item_data.piece_name
	elif "name_passive" in item_data and not item_data.name_passive.is_empty(): title_text = item_data.name_passive
	
	var rarity_color = Color.WHITE
	# Fondo oscuro "plano" moderno
	var bg_tint = Color(0.05, 0.05, 0.07, 0.98) 

	if item_data is PieceData and item_data.piece_origin:
		rarity_color = _get_rarity_color(item_data.piece_origin.rarity)
	elif item_data is PassiveData:
		rarity_color = Color("#FFD700") 

	# Estilo del Panel (Borde fino)
	if card_style:
		card_style.border_color = rarity_color
		card_style.bg_color = bg_tint

	# --- B. CONSTRUCCIÓN DEL CONTENIDO ---
	var text = ""

	# 1. CABECERA (EXTERNA)
	var tier_suffix = ""
	if item_data is PieceData:
		var tier_keys = ["BRONCE", "PLATA", "ORO"]
		var idx = clampi(current_count, 1, 3) - 1
		if current_count == 0: idx = 0
		tier_suffix = tier_keys[idx]
	
	# Si es pasiva, no mostramos tier en el título
	if item_data is PieceData:
		name_label.text = "%s  |  %s" % [title_text.to_upper(), tier_suffix]
	else:
		name_label.text = title_text.to_upper()
	
	var ls = LabelSettings.new()
	ls.font_size = 20
	ls.font_color = rarity_color
	ls.shadow_size = 0 # Diseño flat
	name_label.label_settings = ls

	# 2. SUBTÍTULO + PRECIO (Tabla invisible alineada)
	var sub_str = "Objeto"
	if item_data is PieceData and item_data.piece_origin:
		sub_str = "%s • %s" % [_get_race_name(item_data.piece_origin.race), _get_rarity_name(item_data.piece_origin.rarity)]
	elif item_data is PassiveData:
		sub_str = "Pasiva"

	var price_bb = ""
	if "price" in item_data and item_data.price > 0:
		var cost = item_data.price
		if sell_percentage > 0:
			cost = int(item_data.price * (sell_percentage / 100.0))
			price_bb = "[color=#55efc4]Vender: %d€[/color]" % cost
		else:
			if current_count >= 3 and item_data is PieceData:
				price_bb = "[color=#ff5555]MAX[/color]"
			else:
				if current_count > 0: cost = _calculate_price_logic(item_data, current_count)
				price_bb = "[color=#ffcc00]Costo: %d€[/color]" % cost

	text += "[table=2]"
	text += "[cell][color=#888888][i]%s[/i][/color][/cell]" % sub_str
	text += "[cell][p align=right][b]%s[/b][/p][/cell]" % price_bb
	text += "[/table]"
	
	# SEPARADOR MODERNO
	text += _get_modern_separator()

	# 3. INFO DE JUEGO (UNIDADES | USOS)
	if item_data is PieceData:
		var cur_uses = item_data.uses
		var max_uses = item_data.get_meta("max_uses") if item_data.has_meta("max_uses") else cur_uses
		
		# Datos Stats
		var origin = item_data.piece_origin
		var tier_keys = ["BRONCE", "PLATA", "ORO"]
		var idx = clampi(current_count, 1, 3) - 1
		if current_count == 0: idx = 0
		
		var next_idx = idx
		var is_upg = (sell_percentage == 0 and current_count > 0 and current_count < 3)
		if is_upg: next_idx = idx + 1
		
		var cur_stats = origin.stats[tier_keys[idx]]
		var nxt_stats = origin.stats[tier_keys[next_idx]]
		var members = cur_stats.get("members", 1)
		var next_members = nxt_stats.get("members", members)

		text += "[table=2]"
		
		# Columna Izquierda: Unidades
		var mem_str = str(members)
		if is_upg and members != next_members:
			mem_str = "%d [color=#00ff00]➞ %d[/color]" % [members, next_members]
		text += "[cell][color=#bbbbbb]👥 Unidades:[/color] [b]%s[/b][/cell]" % mem_str
		
		# Columna Derecha: Usos
		var u_col = "#ffffff"
		if cur_uses <= 1: u_col = "#ff5555"
		text += "[cell][p align=right][color=#bbbbbb]🔋 Usos:[/color] [color=%s][b]%d[/b][/color]/%d[/p][/cell]" % [u_col, cur_uses, max_uses]
		text += "[/table]"
		
		text += "\n" # Espacio limpio

		# 4. ESTADÍSTICAS (Tabla limpia)
		text += "[table=2]"
		text += _row_modern("Daño", icon_damage, cur_stats["dmg"], nxt_stats["dmg"], is_upg, "#ff7675")
		text += _row_modern("Vida", icon_health, cur_stats["hp"], nxt_stats["hp"], is_upg, "#55efc4")
		text += _row_modern("Velocidad", icon_speed, cur_stats["aps"], nxt_stats["aps"], is_upg, "#ffeaa7")
		
		if nxt_stats["crit_chance"] > 0:
			var c1 = str(cur_stats["crit_chance"]) + "%"
			var c2 = str(nxt_stats["crit_chance"]) + "%"
			text += _row_modern("Crítico", icon_crit_chance, c1, c2, is_upg, "#ff9f43")
			
		if nxt_stats["crit_mult"] > 1.0:
			var m1 = "x" + str(cur_stats["crit_mult"])
			var m2 = "x" + str(nxt_stats["crit_mult"])
			text += _row_modern("Daño Crit", icon_crit_damage, m1, m2, is_upg, "#fab1a0")
		text += "[/table]"

	elif item_data is PassiveData:
		text += "\n[font_size=16]" + _get_passive_stats_string(item_data) + "[/font_size]\n"

	# Footer Descripción
	if "description" in item_data and not item_data.description.is_empty():
		text += _get_modern_separator()
		text += "[color=#666666][i]%s[/i][/color]" % item_data.description

	description_label.text = text
	sell_price_label.hide() # Ocultamos el label antiguo
	show()
	await get_tree().process_frame
	size = Vector2.ZERO 

# ==============================================================================
# 2. TOOLTIP DE SINERGIAS
# ==============================================================================
func show_synergy_tooltip(race_name: String, current_count: int, max_count: int, bonuses: Array, color_theme: Color, all_pieces: Array = [], active_ids: Array = []) -> void:
	_ensure_units_grid_exists()
	
	name_label.text = race_name.to_upper()
	name_label.label_settings = LabelSettings.new()
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
	text += _get_modern_separator()
	
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
	
	# Iconos de colección
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
					if str(act_id) == str(p_id): 
						is_active = true
						break
			
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
			if "icon" in piece_res and piece_res.icon: final_texture = piece_res.icon
			elif "frames" in piece_res and piece_res.frames:
				var frames = piece_res.frames
				var anims = frames.get_animation_names()
				var best_anim = ""
				if "idle" in anims: best_anim = "idle"
				elif "default" in anims: best_anim = "default"
				elif anims.size() > 0: best_anim = anims[0]
				if best_anim != "" and frames.get_frame_count(best_anim) > 0:
					final_texture = frames.get_frame_texture(best_anim, 0)

			if final_texture == null:
				var p_name = piece_res.get("display_name")
				if p_name == null: p_name = piece_res.get("piece_name")
				if p_name:
					var path_attempt = "res://assets/piezas/" + p_name + ".png"
					if ResourceLoader.exists(path_attempt): final_texture = load(path_attempt)

			if final_texture: icon_rect.texture = final_texture
			else:
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

# ==============================================================================
# 3. LISTA DE PASIVAS
# ==============================================================================
func show_passive_list_tooltip(active_passives: Dictionary) -> void:
	_ensure_units_grid_exists()
	for child in units_grid.get_children(): child.queue_free()
	
	name_label.text = "ESTADÍSTICAS"
	name_label.label_settings = LabelSettings.new()
	name_label.label_settings.font_color = Color("#FFD700") 
	name_label.label_settings.font_size = 24
	name_label.label_settings.outline_size = 6
	name_label.label_settings.outline_color = Color(0, 0, 0, 1)
	
	if card_style:
		card_style.border_color = Color("#FFD700")
		card_style.bg_color = Color(0.08, 0.08, 0.1, 0.98) 

	var text = ""
	
	if active_passives.is_empty():
		text += "\n[center][color=#666666][i]Inventario vacío[/i][/color][/center]\n"
	else:
		text += "[center][color=#aaaaaa]Bonificaciones actuales:[/color][/center]\n"
		text += _get_modern_separator()
		
		text += "[table=3]"
		
		var keys = active_passives.keys()
		keys.sort()
		
		for key in keys:
			var entry = active_passives[key]
			var p_data = entry["data"]
			var count = entry["count"]
			
			if not p_data: continue
			
			var icon_path = ""
			var name_color = "#ffffff"
			
			match p_data.type:
				PassiveData.PassiveType.HEALTH_INCREASE: 
					icon_path = "res://assets/inventario/VIDA.png"
					name_color = "#ff5555"
				PassiveData.PassiveType.CRITICAL_DAMAGE_INCREASE: 
					icon_path = "res://assets/inventario/CritDMG.png"
					name_color = "#ff9f43"
				PassiveData.PassiveType.CRITICAL_CHANCE_INCREASE: 
					icon_path = "res://assets/inventario/Crit.png"
					name_color = "#fab1a0"
				PassiveData.PassiveType.ATTACK_SPEED_INCREASE: 
					icon_path = "res://assets/inventario/ASPEED.png"
					name_color = "#feca57"
				PassiveData.PassiveType.BASE_DAMAGE_INCREASE: 
					icon_path = "res://assets/inventario/ADMG.png"
					name_color = "#ee5253"
			
			var icon_bbcode = ""
			if ResourceLoader.exists(icon_path):
				icon_bbcode = "[img=24]%s[/img]" % icon_path 
			else:
				icon_bbcode = "🔸"
			
			text += "[cell][font_size=18][color=%s] %s %s  [/color][/font_size][/cell]" % [name_color, icon_bbcode, p_data.name_passive]
			text += "[cell][center][color=#666666]x[/color][b][font_size=18][color=#ffffff]%d[/color][/font_size][/b][/center][/cell]" % count
			
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

	description_label.text = text
	sell_price_label.hide()
	show()

func show_passive_summary(passive_counts: Dictionary, multiplier: float) -> void:
	if passive_counts.is_empty(): return 

	name_label.text = "UPGRADES SUMMARY"
	name_label.label_settings = LabelSettings.new()
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
	text += _get_modern_separator()
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

# ==============================================================================
# FUNCIONES AUXILIARES
# ==============================================================================

# Genera una línea sólida fina usando un truco de fondo de fuente
func _get_modern_separator() -> String:
	# Ajusta la cantidad de espacios si tu tooltip es muy ancho.
	return "\n[font_size=2][bgcolor=#ffffff15]                                                                                                    [/bgcolor][/font_size]\n"

# Fila limpia para estadísticas
func _row_modern(label: String, icon: Texture2D, v1, v2, upg: bool, col: String) -> String:
	var ic = ""
	if icon: ic = "[img=18]%s[/img] " % icon.resource_path
	
	# Celda 1: Icono + Nombre (Gris suave)
	var row = "[cell][color=#aaaaaa]%s%s[/color][/cell]" % [ic, label]
	
	# Celda 2: Valor (Color vibrante)
	var val = ""
	if upg and str(v1) != str(v2):
		val = "[color=#888888]%s[/color] [color=#00ff00]➞ [b]%s[/b][/color]" % [str(v1), str(v2)]
	else:
		val = "[color=%s][b]%s[/b][/color]" % [col, str(v2)]
		
	row += "[cell][p align=right]%s[/p][/cell]" % val
	return row

func _calculate_price_logic(data, count) -> int:
	if "price" in data:
		return int(data.price * (1.0 + (0.5 * count)))
	return 0

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

func _get_passive_stats_string(data: PassiveData) -> String:
	var val = data.value
	match data.type:
		PassiveData.PassiveType.HEALTH_INCREASE: return "[color=#4ecdc4]✚ Vida Max:[/color] [b]+%s[/b]" % val
		PassiveData.PassiveType.CRITICAL_DAMAGE_INCREASE: return "[color=#ff9f43]💥 Daño Crítico:[/color] [b]+%s[/b]" % val
		PassiveData.PassiveType.CRITICAL_CHANCE_INCREASE: return "[color=#ff9f43]🎯 Prob. Crítico:[/color] [b]+%s%%[/b]" % val
		PassiveData.PassiveType.ATTACK_SPEED_INCREASE: return "[color=#ffe66d]⚡ Vel. Ataque:[/color] [b]+%s[/b]" % val
		PassiveData.PassiveType.BASE_DAMAGE_INCREASE: return "[color=#ff6b6b]⚔️ Daño Base:[/color] [b]+%s[/b]" % val
	return ""

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

extends PanelContainer

# Referencias a los nodos
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var description_label: RichTextLabel = $VBoxContainer/DescriptionLabel
@onready var sell_price_label: Label = $VBoxContainer/SellPriceLabel

# Referencia al propio panel
@onready var tooltip: PanelContainer = self 

# Estilo dinámico para la tarjeta
var card_style: StyleBoxFlat

# Referencia al contenedor de iconos de unidades
var units_grid: HBoxContainer = null

func _ready() -> void:
	add_to_group("tooltip")
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	top_level = true
	z_index = 4096
	
	# --- ESTILO VISUAL ---
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

	# Inicializamos el grid
	_ensure_units_grid_exists()

func _ensure_units_grid_exists():
	if units_grid and is_instance_valid(units_grid):
		return

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

# --- TOOLTIP PARA ITEMS NORMALES ---
func show_tooltip(item_data: Resource, sell_percentage: int, current_count: int = 0) -> void:
	if not item_data: return

	_ensure_units_grid_exists()
	for child in units_grid.get_children(): child.queue_free()

	# --- A. DATOS BÁSICOS ---
	var title_text = "Objeto"
	if "resource_name" in item_data and not item_data.resource_name.is_empty(): 
		title_text = item_data.resource_name
	if "piece_name" in item_data and not item_data.piece_name.is_empty(): 
		title_text = item_data.piece_name
	elif "name_passive" in item_data and not item_data.name_passive.is_empty(): 
		title_text = item_data.name_passive
	
	# --- B. COLORES ---
	var rarity_color = Color.WHITE
	var subtitle = ""
	var bg_tint = Color(0.05, 0.05, 0.07, 0.95) 
	
	if item_data is PieceData and item_data.piece_origin:
		rarity_color = _get_rarity_color(item_data.piece_origin.rarity)
		subtitle = "%s • %s" % [_get_race_name(item_data.piece_origin.race), _get_rarity_name(item_data.piece_origin.rarity)]
		bg_tint = rarity_color.darkened(0.85)
		bg_tint.a = 0.95
	elif item_data is PassiveData:
		rarity_color = Color("#FFD700") 
		subtitle = "✦ Mejora Pasiva ✦"
		bg_tint = Color(0.1, 0.1, 0.05, 0.95)

	# --- C. ESTILOS ---
	name_label.text = title_text.to_upper()
	name_label.label_settings = LabelSettings.new()
	name_label.label_settings.font_color = rarity_color
	name_label.label_settings.font_size = 22
	name_label.label_settings.outline_size = 4
	name_label.label_settings.outline_color = Color.BLACK
	
	if card_style:
		card_style.border_color = rarity_color
		card_style.bg_color = bg_tint

	# --- D. CONTENIDO ---
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
			text += "[center][wave amp=25 freq=5][color=%s]★ MEJORA A %s ★[/color][/wave][/center]" % [tier_colors[next_tier_idx], tier_keys[next_tier_idx]]
		else:
			text += "[center][color=%s]NIVEL: %s[/color][/center]" % [tier_colors[current_tier_idx], tier_keys[current_tier_idx]]

		var bar_visual = ""
		for i in range(3):
			if i < current_count:
				bar_visual += "[color=%s]◼[/color] " % tier_colors[current_tier_idx]
			else:
				bar_visual += "[color=#333333]◻[/color] "
		text += "[center][font_size=18]%s[/font_size][/center]\n" % bar_visual
		
		text += "[table=2]"
		var cur_uses = item_data.uses
		var max_uses = cur_uses
		if item_data.has_meta("max_uses"): max_uses = item_data.get_meta("max_uses")
		var members = current_stats.get("members", 1)
		var next_members = next_stats.get("members", members)

		text += "[cell][color=#aaaaaa] 👥 Tropas[/color][/cell]"
		if is_upgrade and members != next_members:
			text += "[cell][color=#ffffff]%d[/color] [color=#00ff00]➞ %d[/color][/cell]" % [members, next_members]
		else:
			text += "[cell][b]%d[/b][/cell]" % members
			
		var u_color = "#ffffff"
		if cur_uses <= 1: u_color = "#ff5555"
		text += "[cell][color=#aaaaaa] 🔋 Usos[/color][/cell]"
		text += "[cell][color=%s]%d[/color] / %d[/cell]" % [u_color, cur_uses, max_uses]
		text += "[cell] [/cell][cell] [/cell]" 

		text += _row_table("⚔️ Daño", current_stats["dmg"], next_stats["dmg"], is_upgrade, "#ff7675")
		text += _row_table("❤️ Vida", current_stats["hp"], next_stats["hp"], is_upgrade, "#55efc4")
		text += _row_table("⚡ Vel.", current_stats["aps"], next_stats["aps"], is_upgrade, "#ffeaa7")
		
		if next_stats.get("crit_chance", 0) > 0:
			text += _row_table("🎯 Crit%", str(current_stats.get("crit_chance", 0)) + "%", str(next_stats.get("crit_chance", 0)) + "%", is_upgrade, "#ff9f43")
		
		if next_stats.get("crit_mult", 1.0) > 1.0:
			text += _row_table("💥 CritDmg", "x" + str(current_stats.get("crit_mult", 1.0)), "x" + str(next_stats.get("crit_mult", 1.0)), is_upgrade, "#ff9f43")

		text += "[/table][/font_size]\n"
	
	elif item_data is PassiveData:
		text += "[font_size=16]\n" + _get_passive_stats_string(item_data) + "[/font_size]\n\n"

	if "description" in item_data and not item_data.description.is_empty():
		text += "[color=#888888][i]%s[/i][/color]" % item_data.description

	description_label.text = text

	# --- E. PRECIO ---
	if "price" in item_data and item_data.price > 0:
		var final_price = item_data.price
		var price_txt = ""
		var price_color = Color("#ffcc00") 
		
		if sell_percentage > 0:
			final_price = int(item_data.price * (sell_percentage / 100.0))
			price_txt = "VENTA: %d€" % final_price
			price_color = Color("#55efc4") 
		else:
			var cost = final_price
			if current_count > 0 and current_count < 3:
				cost = _calculate_price_logic(item_data, current_count)
				price_txt = "TIENES: %d/3  | COSTO: %d€" % [current_count, cost]
				sell_price_label.modulate = Color.CYAN
			elif current_count >= 3:
				price_txt = "¡MAXIMIZADO!"
				price_color = Color("#ff5555") 
			else:
				price_txt = "COSTO: %d€" % cost
		
		sell_price_label.text = price_txt
		if sell_percentage == 0 and current_count < 3:
			sell_price_label.modulate = price_color
		sell_price_label.show()
	else:
		sell_price_label.hide()

	show()
	
# --- TOOLTIP PARA SINERGIA (REFACORIZADO) ---
func show_synergy_tooltip(race_name: String, current_count: int, max_count: int, bonuses: Array, color_theme: Color, all_pieces: Array = [], active_ids: Array = []) -> void:
	_ensure_units_grid_exists()
	
	# 1. TÍTULO Y ESTILO GENERAL
	name_label.text = race_name.to_upper()
	name_label.label_settings = LabelSettings.new()
	name_label.label_settings.font_color = color_theme
	name_label.label_settings.font_size = 24
	name_label.label_settings.outline_size = 6
	name_label.label_settings.outline_color = Color(0, 0, 0, 1)
	
	if card_style:
		card_style.border_color = color_theme
		card_style.bg_color = Color(0.08, 0.08, 0.1, 0.98) 

	# 2. TEXTO DE BONIFICACIONES
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
			text += "[cell][color=#555555](%d) %s[/color][/cell]" % [req, desc]
	text += "[/table]"
	
	text += "\n[center][i][font_size=12][color=#666666]Colección:[/color][/font_size][/i][/center]"
	description_label.text = text
	
	# 3. RENDERIZADO DE CARTAS (GRID)
	# Limpiamos iconos anteriores
	for child in units_grid.get_children():
		child.queue_free()
	
	if all_pieces.is_empty():
		pass
	else:
		var processed_piece_ids = {}

		for piece_res in all_pieces:
			if not piece_res: continue
			
			# Evitar duplicados por ID
			var piece_id = piece_res.get("id")
			if piece_id != null:
				if piece_id in processed_piece_ids:
					continue 
				processed_piece_ids[piece_id] = true

			# --- A. CONTENEDOR MARCO ---
			var card_frame = PanelContainer.new()
			card_frame.custom_minimum_size = Vector2(48, 48)
			
			var rarity = 0
			if "rarity" in piece_res: rarity = piece_res.rarity
			var rarity_col = _get_rarity_color(rarity)
			
			var is_active = false
			if piece_id != null:
				for active_id in active_ids:
					if str(active_id) == str(piece_id):
						is_active = true
						break
			
			# Estilo del marco
			var frame_style = StyleBoxFlat.new()
			frame_style.bg_color = Color(0, 0, 0, 0.5)
			frame_style.border_width_left = 2
			frame_style.border_width_top = 2
			frame_style.border_width_right = 2
			frame_style.border_width_bottom = 2
			frame_style.corner_radius_top_left = 4
			frame_style.corner_radius_top_right = 4
			frame_style.corner_radius_bottom_right = 4
			frame_style.corner_radius_bottom_left = 4
			
			if is_active:
				frame_style.border_color = rarity_col
				card_frame.modulate = Color(1, 1, 1, 1)
			else:
				frame_style.border_color = Color(0.3, 0.3, 0.3, 1)
				card_frame.modulate = Color(0.4, 0.4, 0.4, 0.8)

			card_frame.add_theme_stylebox_override("panel", frame_style)
			
			# --- B. ICONO (EXTRACCIÓN INTELIGENTE) ---
			var icon_rect = TextureRect.new()
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.custom_minimum_size = Vector2(40, 40)
			
			var texture_found = null
			
			# CASO 1: Es un PieceData con icono simple
			if "icon" in piece_res and piece_res.icon:
				texture_found = piece_res.icon
				
			# CASO 2: Es un PieceRes con animaciones (SpriteFrames) [TU CASO]
			elif "frames" in piece_res and piece_res.frames:
				var frames: SpriteFrames = piece_res.frames
				# Intentamos sacar la "foto" de la animación idle o default
				var anim_name = "default"
				
				if frames.has_animation("idle"):
					anim_name = "idle"
				elif frames.has_animation("run"):
					anim_name = "run"
				elif not frames.has_animation("default"):
					# Si no tiene nombres estándar, cogemos la primera que haya
					var anim_list = frames.get_animation_names()
					if anim_list.size() > 0:
						anim_name = anim_list[0]
				
				# Sacamos el frame 0 de esa animación
				if frames.has_animation(anim_name) and frames.get_frame_count(anim_name) > 0:
					texture_found = frames.get_frame_texture(anim_name, 0)

			# Asignación final
			if texture_found:
				icon_rect.texture = texture_found
			else:
				# Si falla, ponemos un cuadro rojo semitransparente
				# Usamos display_name que es la variable correcta en PieceRes
				var p_name = piece_res.get("display_name")
				if p_name == null: p_name = "Desconocida"
				# print("Tooltip: No imagen para ", p_name) # Descomentar para depurar
				
				var placeholder = PlaceholderTexture2D.new()
				placeholder.size = Vector2(40,40)
				icon_rect.texture = placeholder
				icon_rect.modulate = Color(1, 0, 0, 0.3)

			# --- C. ENSAMBLAJE ---
			var margin_con = MarginContainer.new()
			margin_con.add_theme_constant_override("margin_top", 4)
			margin_con.add_theme_constant_override("margin_bottom", 4)
			margin_con.add_theme_constant_override("margin_left", 4)
			margin_con.add_theme_constant_override("margin_right", 4)
			
			margin_con.add_child(icon_rect)
			card_frame.add_child(margin_con)
			units_grid.add_child(card_frame)

	sell_price_label.hide()
	show()

func hide_tooltip() -> void:
	hide()

# --- HELPERS (CORREGIDOS PARA GD SCRIPT) ---

func _row_table(label: String, val_old, val_new, show_upg: bool, color_hex: String) -> String:
	var row = "[cell][color=%s] %s[/color][/cell]" % [color_hex, label]
	if show_upg and str(val_old) != str(val_new):
		row += "[cell][color=#cccccc]%s[/color] [color=#00ff00]➞ %s[/color][/cell]" % [str(val_old), str(val_new)]
	else:
		row += "[cell][b]%s[/b][/cell]" % str(val_new)
	return row

func _calculate_price_logic(data, count) -> int:
	return int(data.price * (1.0 + (0.5 * count)))

func _get_rarity_color(rarity_enum: int) -> Color:
	match rarity_enum:
		0:
			return Color("#b2bec3") # Común - Gris claro
		1:
			return Color("#0984e3") # Raro - Azul
		2:
			return Color("#a55eea") # Épico - Morado
		3:
			return Color("#f1c40f") # Legendario - Dorado
		_:
			return Color.WHITE

func _get_race_name(race_enum: int) -> String:
	match race_enum:
		0:
			return "Nórdica"
		1:
			return "Japonesa"
		2:
			return "Europea"
		_:
			return "Clase"
		
func _get_rarity_name(rarity_enum: int) -> String:
	match rarity_enum:
		0:
			return "Común"
		1:
			return "Raro"
		2:
			return "Épico"
		3:
			return "Legendario"
		_:
			return ""

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

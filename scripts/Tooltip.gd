extends PanelContainer

# References to nodes
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var description_label: RichTextLabel = $VBoxContainer/DescriptionLabel
@onready var sell_price_label: Label = $VBoxContainer/SellPriceLabel

# --- EXPORTED ICONS ---
@export_group("Stat Icons")
@export var icon_health: Texture2D
@export var icon_damage: Texture2D
@export var icon_speed: Texture2D
@export var icon_crit_chance: Texture2D
@export var icon_crit_damage: Texture2D
@export var icon_size: int = 20 

# Dynamic style for the card
var card_style: StyleBoxFlat

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# --- 1. LAYER CONFIGURATION ---
	top_level = true
	z_index = 4096
	
	# --- 2. "PREMIUM" VISUAL STYLE ---
	card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.05, 0.05, 0.07, 0.95) 
	
	# Borders and Corners
	card_style.border_width_left = 2; card_style.border_width_top = 2
	card_style.border_width_right = 2; card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 12; card_style.corner_radius_top_right = 12
	card_style.corner_radius_bottom_right = 12; card_style.corner_radius_bottom_left = 12
	
	# Shadow
	card_style.shadow_color = Color(0, 0, 0, 0.6)
	card_style.shadow_size = 8
	card_style.shadow_offset = Vector2(4, 4)
	
	# Margins
	card_style.content_margin_left = 20; card_style.content_margin_right = 20
	card_style.content_margin_top = 16; card_style.content_margin_bottom = 16
	
	add_theme_stylebox_override("panel", card_style)
	custom_minimum_size.x = 340 
	
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

func show_tooltip(item_data: Resource, sell_percentage: int, current_count: int = 0) -> void:
	if not item_data: return

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

		text += "[cell][color=#aaaaaa] 👥 Units[/color][/cell]"
		if is_upgrade and members != next_members: text += "[cell][color=#ffffff]%d[/color] [color=#00ff00]➞ %d[/color][/cell]" % [members, next_members]
		else: text += "[cell][b]%d[/b][/cell]" % members
			
		var u_color = "#ffffff"
		if cur_uses <= 1: u_color = "#ff5555" 
		text += "[cell][color=#aaaaaa] 🔋 Uses[/color][/cell]"
		text += "[cell][color=%s]%d[/color] / %d[/cell]" % [u_color, cur_uses, max_uses]
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
		var price_color = Color("#ffcc00") 
		
		if sell_percentage > 0:
			final_price = int(item_data.price * (sell_percentage / 100.0))
			price_txt = "SELL: %d€" % final_price
			price_color = Color("#55efc4")
		else:
			var cost = final_price
			if item_data is PassiveData:
				if current_count > 0:
					cost = _calculate_price_logic(item_data, current_count)
					price_txt = "OWNED: %d  |  COST: %d€" % [current_count, cost]
					sell_price_label.modulate = Color.CYAN
				else:
					price_txt = "COST: %d€" % cost
					sell_price_label.modulate = Color("#ffcc00")
			else: 
				if current_count >= 3:
					price_txt = "MAXED OUT!"
					price_color = Color("#ff5555")
				elif current_count > 0:
					cost = _calculate_price_logic(item_data, current_count)
					price_txt = "OWNED: %d/3  |  COST: %d€" % [current_count, cost]
					sell_price_label.modulate = Color.CYAN
				else:
					price_txt = "COST: %d€" % cost
					sell_price_label.modulate = Color("#ffcc00")
		
		sell_price_label.text = price_txt
		if sell_percentage == 0:
			if not (item_data is PieceData and current_count >= 3): pass 
			else: sell_price_label.modulate = price_color
		sell_price_label.show()
	else:
		sell_price_label.hide()
	
	show()
	await get_tree().process_frame
	size = Vector2.ZERO

# --- HELPER: Generates [img] tag ---
func _get_icon_tag(texture: Texture2D) -> String:
	if texture:
		return "[img=%dx%d]%s[/img]" % [icon_size, icon_size, texture.resource_path]
	return ""

func _row_table(label: String, val_old, val_new, show_upg: bool, color_hex: String) -> String:
	var row = ""
	# Columna 1: Etiqueta con color
	row += "[cell][color=%s] %s[/color][/cell]" % [color_hex, label]
	
	# Columna 2: Valor
	if show_upg and str(val_old) != str(val_new):
		# CORREGIDO: Añadidas etiquetas [b] para negrita en ambos valores
		row += "[cell][color=#cccccc][b]%s[/b][/color] [color=#00ff00]➞ [b]%s[/b][/color][/cell]" % [str(val_old), str(val_new)]
	else:
		# Caso normal (ya tenía negrita)
		row += "[cell][b]%s[/b][/cell]" % str(val_new)
	return row

func _calculate_price_logic(data, count) -> int:
	var base = data.price
	var mult = 1.0 + (0.5 * count)
	return int(base * mult)

func hide_tooltip() -> void:
	hide()

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
		PassiveData.PassiveType.HEALTH_INCREASE:
			return "[color=#4ecdc4]%s Max Health:[/color] [b]+%s[/b]" % [_get_icon_tag(icon_health), val]
		PassiveData.PassiveType.CRITICAL_DAMAGE_INCREASE:
			return "[color=#ff9f43]%s Crit Damage:[/color] [b]+%s[/b]" % [_get_icon_tag(icon_crit_damage), val]
		PassiveData.PassiveType.CRITICAL_CHANCE_INCREASE:
			return "[color=#ff9f43]%s Crit Chance:[/color] [b]+%s%%[/b]" % [_get_icon_tag(icon_crit_chance), val]
		PassiveData.PassiveType.ATTACK_SPEED_INCREASE:
			return "[color=#ffe66d]%s Attack Speed:[/color] [b]+%s[/b]" % [_get_icon_tag(icon_speed), val]
		PassiveData.PassiveType.BASE_DAMAGE_INCREASE:
			return "[color=#ff6b6b]%s Base Damage:[/color] [b]+%s[/b]" % [_get_icon_tag(icon_damage), val]
	return ""

# --- SUMMARY TOOLTIP WITH ICONS ---
func show_passive_summary(passive_counts: Dictionary, multiplier: float) -> void:
	if passive_counts.is_empty(): return 
	name_label.text = "Fruit Medley"

	var ls := LabelSettings.new()

	# MUY IMPORTANTE: darle una fuente válida.
	ls.font = get_theme_default_font()

	ls.font_color = Color("#FFD700")
	ls.font_size = 22
	ls.outline_size = 6
	ls.outline_color = Color(0, 0, 0, 1)

	name_label.label_settings = ls
	
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

extends Node2D

## ------------------------------------------------------------------
## Estado del Juego (FSM)
## ------------------------------------------------------------------
enum GameState {
	SHOP,      # Fase de Tienda
	ROULETTE,  # Fase de Ruleta
	SPINNING,  # Ruleta Girando
	COMBAT     # Combate en curso
}
var current_state: GameState
var current_round: int = 1
var current_day: int = 1
var gladiators_defeated: int = 0 
@onready var NextDayButton: TextureButton = $DayFinished/NextDayButton

# --- HABILIDAD ULTIMATE DEL JUGADOR ---
@export_group("Habilidad Ultimate")
@export var ultimate_max_charge: float = 100.0
@export var ultimate_charge_per_wave: float = 5.0 
@export var ultimate_damage: float = 150.0 
@export var ultimate_bar: Range          
@export var ultimate_button: BaseButton  

var current_ultimate_charge: float = 0.0
# ---------------------------------------------

# Nodos
@onready var buttonShop: Button = $elJetas/ButtonShop
@onready var sprite_show: Sprite2D = $elJetas/ButtonShop/EyeSprite
@onready var pupil: Sprite2D = $elJetas/ButtonShop/EyeSprite/Pupil
@onready var el_jetas_anim: AnimationPlayer = $elJetas/AnimationPlayer
@onready var piece_label: Label = $Store/piece_label
@onready var passive_label: Label = $Store/passive_label
@onready var coin_sprite: Sprite2D = $Store/Coin
@onready var mat = $Store/Sprite2D.material
@onready var anim = $Store/AnimationPlayer
@onready var gold_label: Label = $Store/gold_label
@onready var store: Control = $Store
@onready var inventory: Control = $inventory
@onready var roulette: Node2D = $Roulette
@onready var combat_scene: Node2D = $combat_scene

@onready var announcement_label: Label = get_node_or_null("AnnouncementLabel")
@onready var help_overlay: Control = get_node_or_null("CanvasLayer/HelpOverLay")
@onready var help_button: Button = get_node_or_null("CanvasLayer/HelpOverLay/HelpButton")
@onready var win_restart_button: Button = get_node_or_null("Win/RestartButton")
@onready var lose_restart_button: Button = get_node_or_null("GameOver/RestartButton")
@onready var win_label: Label = get_node_or_null("DayFinished/WinLabel")
@onready var lose_label: Label = get_node_or_null("DayFinished/LoseLabel")

@onready var fondo_texto: TextureRect = $DayFinished/FondoTexto
@onready var anfora_rota: TextureRect = $DayFinished/AnforaRota
var is_game_over_state: bool = false
@onready var comic_root: CanvasLayer = $Comic
@onready var Comic1: TextureRect = $Comic/Fondo/Frag1
@onready var Comic2: TextureRect = $Comic/Fondo/Frag2
@onready var Comic3: TextureRect = $Comic/Fondo/Frag3
@onready var start_button: TextureButton = $Comic/StartButton
@onready var comic_fondo: ColorRect = $Comic/Fondo 
@onready var fuego: TextureRect = $DayFinished/Fuego
@onready var estrellas: TextureRect = $DayFinished/Estrellas

@export_group("Cursores Personalizados")
@export var tex_grab: Texture2D  
@export var tex_click: Texture2D 
@export var cursor_hotspot: Vector2 = Vector2(0, 0) 

@export var gold_round_base: int = 100
@export var gold_day_mult: float = 1
@export var rounds_per_day: int = 10
@export var gladiators_per_day: int = 1
@export var gladiators_mult: int = 1
@export var max_days: int = 2

@onready var round_label: Label = $RoundLabel
@onready var day_label: Label = get_node_or_null("DayLabel")
@onready var gladiator_label: Label = $GladiatorLabel

@onready var day_finished_view: CanvasLayer = $DayFinished
@onready var next_day_image: TextureRect = $DayFinished/NextDayImage 
@onready var game_over_view: CanvasLayer = get_node_or_null("GameOver")
@onready var win_view: CanvasLayer = get_node_or_null("Win")

@onready var next_day_label: Label = $DayFinished/NextDayLabel
@onready var day_slider: TextureProgressBar = $DayFinished/HSlider
@onready var info_label: RichTextLabel = $DayFinished/InfoLabel
@onready var transition_rect: ColorRect = $DayFinished/TransitionRect
var _is_clicking: bool = false
var pupil_offset: Vector2
var original_eye_texture: Texture2D
var eye_closed_texture: Texture2D
var blink_timer := 0.0
var blink_interval_min := 2.0
var blink_interval_max := 5.0
var blink_time := 0.1
var options_scene: PackedScene = preload("res://scenes/options.tscn")
var options_instance: CanvasLayer = null
var options_animating: bool = false
var is_tended = true
var original_positions = {}
var blink_tween: Tween = null
var max_distance: float = 100
var is_shop_transitioning: bool = false

var daily_gold_salary: int = 0
var daily_gold_loot: int = 0

func _ready():
	add_to_group("game_manager")
	MusicManager.play_gameplay()
	_apply_default_cursors()
	
	if buttonShop: buttonShop.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if help_button: help_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_set_hand_cursor_recursively(store)
	
	daily_gold_salary = 0
	daily_gold_loot = 0
	pupil_offset = pupil.position
	eye_closed_texture = preload("res://assets/Oculta_retocada.png")
	original_eye_texture = sprite_show.texture

	for child in store.get_children():
		if child is CanvasItem:
			original_positions[child] = child.position
			child.modulate.a = 1.0

	if roulette.has_signal("roulette_spin_started"):
		roulette.roulette_spin_started.connect(_on_roulette_spin_started)
	
	GlobalSignals.combat_requested.connect(_on_combat_requested)
	
	if combat_scene and combat_scene.has_signal("combat_finished"):
		if combat_scene.combat_finished.is_connected(_on_combat_finished):
			combat_scene.combat_finished.disconnect(_on_combat_finished)
		combat_scene.combat_finished.connect(_on_combat_finished)

	anim.connect("animation_finished", Callable(self, "_on_animation_finished"))
	buttonShop.connect("pressed", Callable(self, "_on_shop_button_pressed"))
	buttonShop.connect("mouse_entered", Callable(self, "_on_shop_hover"))
	buttonShop.connect("mouse_exited", Callable(self, "_on_shop_exit"))
	
	if help_button:
		help_button.pressed.connect(_on_help_button_pressed)
	else:
		print("Info: HelpButton no encontrado o desactivado.")

	PlayerData.currency_changed.connect(_on_PlayerData_currency_changed)
	if inventory.has_signal("item_sold"):
		inventory.item_sold.connect(PlayerData.add_currency)

	blink_timer = randf_range(blink_interval_min, blink_interval_max)
	_on_PlayerData_currency_changed(PlayerData.get_current_currency())
	
	store.start_new_round()
	_update_ui_labels()
	
	# --- CONEXIÓN DEL ULTIMATE ---
	if ultimate_button:
		ultimate_button.pressed.connect(_on_ultimate_button_pressed)
	_update_ultimate_ui()
	# -----------------------------

	if current_round == 1:
		_give_initial_piece()
		set_state(GameState.ROULETTE)
		if el_jetas_anim: el_jetas_anim.play("intro")
	else:
		set_state(GameState.SHOP)
		
	if win_restart_button:
		win_restart_button.pressed.connect(_restart_game)

	if lose_restart_button:
		lose_restart_button.pressed.connect(_restart_game)

	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
		start_button.visible = false

	if current_day == 1 and current_round == 1:
		_play_simple_intro()
		if comic_root: comic_root.visible = true
		if comic_fondo: comic_fondo.modulate.a = 1.0
	else:
		if comic_root: comic_root.visible = false
		
	if NextDayButton:
			NextDayButton.disabled = false
	if transition_rect:
			transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

# --- FUNCIONES DE LA BARRA ULTIMATE ---
func add_ultimate_charge() -> void:
	if current_state != GameState.COMBAT: return
	
	current_ultimate_charge += ultimate_charge_per_wave
	if current_ultimate_charge > ultimate_max_charge:
		current_ultimate_charge = ultimate_max_charge
		
	_update_ultimate_ui()

func _update_ultimate_ui() -> void:
	if ultimate_bar:
		ultimate_bar.max_value = ultimate_max_charge
		var tw = create_tween()
		tw.tween_property(ultimate_bar, "value", current_ultimate_charge, 0.2).set_trans(Tween.TRANS_SINE)
		
	if ultimate_button:
		if current_ultimate_charge >= ultimate_max_charge:
			ultimate_button.disabled = false
			ultimate_button.modulate = Color(1.5, 1.5, 1.5) # Glow de que está listo
			ultimate_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			ultimate_button.disabled = true
			ultimate_button.modulate = Color(0.6, 0.6, 0.6) # Apagado
			ultimate_button.mouse_default_cursor_shape = Control.CURSOR_ARROW

func _on_ultimate_button_pressed() -> void:
	if current_state != GameState.COMBAT: return
	if current_ultimate_charge >= ultimate_max_charge:
		current_ultimate_charge = 0.0
		_update_ultimate_ui()
		
		if combat_scene and combat_scene.has_method("execute_player_ultimate"):
			combat_scene.execute_player_ultimate(ultimate_damage)
# --------------------------------------
	
func _process(_delta: float) -> void:
	blink_timer -= _delta
	if sprite_show.texture == original_eye_texture:
		pupil.visible = true
		_update_pupil_position()
	else:
		pupil.visible = false

	if blink_timer <= 0.0 and sprite_show.visible:
		await _toggle_eye_parpadeo()
		blink_timer = randf_range(blink_interval_min, blink_interval_max)

	if Input.is_action_just_pressed("pause"):
		pausar()

func _update_ui_labels() -> void:
	if is_instance_valid(day_label):
		day_label.text = "Day " + str(current_day) + " / " + str(max_days)
	if is_instance_valid(gladiator_label):
		gladiator_label.text = "%d/%d" % [gladiators_defeated, gladiators_per_day]
	if is_instance_valid(round_label):
		round_label.text = "Wave %d/%d" % [current_round, rounds_per_day]

func set_state(new_state: GameState):
	if current_state == new_state: return
	if anim.is_playing(): return

	print("Cambiando de estado: %s -> %s" % [GameState.keys()[current_state], GameState.keys()[new_state]])
	current_state = new_state
	_update_ui_labels()

	match current_state:
		GameState.SHOP:
			_toggle_store(false)
			buttonShop.disabled = false
			inventory.set_interactive(true)
		GameState.ROULETTE:
			_toggle_store(true)
			buttonShop.disabled = false
			inventory.set_interactive(true)
			roulette.set_interactive(true)
		GameState.SPINNING:
			buttonShop.disabled = true
			inventory.set_interactive(false)
			roulette.set_interactive(false)
		GameState.COMBAT:
			buttonShop.disabled = true
			inventory.set_interactive(false)
			roulette.set_interactive(false)

func _on_shop_button_pressed():
	if is_shop_transitioning: return
	if anim.is_playing(): return
		
	if current_state == GameState.SHOP:
		set_state(GameState.ROULETTE)
	elif current_state == GameState.ROULETTE:
		set_state(GameState.SHOP)

func _on_roulette_spin_started():
	set_state(GameState.SPINNING)

func _on_combat_requested(piece_resource: Resource, modifier: Dictionary = {}):
	if piece_resource and piece_resource is PieceRes:
		set_state(GameState.COMBAT)
	else:
		print("Giro en vacío. Pasando a siguiente ronda.")
		_on_combat_finished(false)

func _on_combat_finished(player_won: bool = false, loot_from_combat: int = 0):
	if roulette.has_method("reset_modifiers_state"):
		roulette.reset_modifiers_state()
		
	var round_income = int(gold_round_base * gold_day_mult)
	PlayerData.add_currency(round_income)
	
	daily_gold_salary += round_income
	daily_gold_loot += loot_from_combat
	
	print("Fin ronda. Base: %d, Loot: %d" % [round_income, loot_from_combat])

	if player_won:
		gladiators_defeated += 1
	
	if current_round >= rounds_per_day:
		print("¡Fin del Día %d! Verificando cuota..." % current_day)
		if gladiators_defeated >= gladiators_per_day:
			is_game_over_state = false 
			print("Cuota cumplida. Mostrando resumen.")
		else:
			is_game_over_state = true 
			print("Cuota NO cumplida. GAME OVER (Modo Resumen).")
		_show_day_finished_view()
	else:
		current_round += 1
		print("--- Empezando Ronda %d ---" % current_round)
		_update_ui_labels()
		
		store.start_new_round()
		set_state(GameState.SHOP)
		if player_won and combat_scene and combat_scene.has_method("spawn_enemy_one"):
			combat_scene.spawn_enemy_one()

func _show_day_finished_view() -> void:
	if not day_finished_view:
		_advance_to_next_day()
		return
		
	if is_game_over_state: MusicManager.play_lose()
	elif current_day >= max_days: MusicManager.play_win()
	else: MusicManager.play_day_finished()
		
	day_finished_view.visible = true
	buttonShop.disabled = true
	
	if NextDayButton:
		NextDayButton.visible = false
		NextDayButton.disabled = true 

	if is_game_over_state:
		if estrellas: estrellas.visible = false
		if fuego: fuego.visible = true
	else:
		if estrellas: estrellas.visible = true
		if fuego: fuego.visible = false

	if transition_rect: 
		transition_rect.visible = true 
		transition_rect.modulate.a = 0.0 
	
	var ui_elements = [fondo_texto, next_day_image, next_day_label, info_label, win_label, lose_label, day_slider, anfora_rota]
	for elem in ui_elements:
		if elem: elem.modulate.a = 0.0 

	if win_label: win_label.visible_characters = 0
	if lose_label: lose_label.visible_characters = 0
	
	if info_label:
		info_label.bbcode_enabled = true
		info_label.visible_characters = 0     
		info_label.text = build_day_summary_text() 

	if day_slider:
		day_slider.step = 0.0 
		day_slider.max_value = max_days
		day_slider.value = current_day - 1 

	if next_day_label:
		next_day_label.text = "Day %d Failed" % current_day if is_game_over_state else "Day %d Finished" % current_day

	var t = create_tween()
	if transition_rect:
		t.tween_property(transition_rect, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	t.chain()
	t.set_parallel(true)
	
	var fade_in_list = [fondo_texto, next_day_image, next_day_label, info_label]
	if day_slider: fade_in_list.append(day_slider)
	
	for elem in fade_in_list:
		if elem: t.tween_property(elem, "modulate:a", 1.0, 0.5)
	
	t.chain().tween_callback(func():
		var animation_tween : Tween
		if is_game_over_state: animation_tween = animate_amphora_break()
		else: animation_tween = animate_day_progressbar()

		if animation_tween: animation_tween.finished.connect(_start_text_animation)
		else: _start_text_animation()
	)

func _start_text_animation():
	var t2 = animate_info_text()
	if t2: t2.finished.connect(_wait_and_decide_flow)
	else: _wait_and_decide_flow()

func _wait_and_decide_flow() -> void:
	if is_game_over_state or current_day >= max_days:
		print("Esperando para mostrar resultado final...")
		get_tree().create_timer(3.0).timeout.connect(_decide_post_summary_flow)
	else:
		_decide_post_summary_flow()

func _decide_post_summary_flow() -> void:
	if is_game_over_state: _animate_lose_transition() 
	elif current_day >= max_days: _animate_win_transition()  
	else: reveal_next_day_button()   

func _animate_win_transition() -> void:
	var t = create_tween()
	if fuego: fuego.visible = false
	if estrellas: estrellas.visible = true
	t.set_parallel(true)
	if info_label: t.tween_property(info_label, "modulate:a", 0.0, 1.0)
	if day_slider: t.tween_property(day_slider, "modulate:a", 0.0, 1.0)
	if next_day_label: t.tween_property(next_day_label, "modulate:a", 0.0, 1.0)
	if fondo_texto: t.tween_property(fondo_texto, "modulate:a", 0.0, 1.0) 
	
	t.chain().tween_callback(func():
		if win_label:
			win_label.visible_characters = 0 
			win_label.modulate.a = 1.0       
	)
	
	if win_label:
		t.tween_property(win_label, "visible_characters", win_label.get_total_character_count(), 2.0)
	
	t.chain().tween_callback(reveal_next_day_button)

func _show_game_over_view() -> void:
	if game_over_view:
		game_over_view.visible = true
		buttonShop.disabled = true
	else: push_error("GameManager: No se encontró el nodo 'GameOver'.")

func _show_win_view() -> void:
	if win_view:
		win_view.visible = true
		buttonShop.disabled = true
	else: push_error("GameManager: No se encontró el nodo 'Win'.")

func _advance_to_next_day() -> void:
	if roulette.has_method("reset_modifiers_state"):
		roulette.reset_modifiers_state()
		
	MusicManager.play_gameplay()
	print("Iniciando Día %d..." % (current_day + 1))
	current_day += 1
	current_round = 1
	gladiators_defeated = 0 
	daily_gold_salary = 0
	daily_gold_loot = 0
	
	if day_finished_view: day_finished_view.visible = false
	buttonShop.disabled = false
	
	_update_ui_labels()
	set_state(GameState.SHOP)
	store.start_new_round()
	
	if combat_scene and combat_scene.has_method("reset_for_new_day"):
		combat_scene.reset_for_new_day()

func _give_initial_piece():
	if not inventory.has_method("get_random_initial_piece"): return
	var initial_piece: Resource = inventory.get_random_initial_piece()
	if initial_piece and inventory.can_add_item(initial_piece):
		inventory.add_item(initial_piece)
		
func _apply_default_cursors():
	if tex_click: Input.set_custom_mouse_cursor(tex_click, Input.CURSOR_POINTING_HAND, cursor_hotspot)
	if tex_grab:
		Input.set_custom_mouse_cursor(tex_grab, Input.CURSOR_DRAG, cursor_hotspot)
		Input.set_custom_mouse_cursor(tex_grab, Input.CURSOR_CAN_DROP, cursor_hotspot)

func _update_cursor_on_click():
	if _is_clicking:
		if tex_click:
			Input.set_custom_mouse_cursor(tex_click, Input.CURSOR_ARROW, cursor_hotspot)
			Input.set_custom_mouse_cursor(tex_click, Input.CURSOR_POINTING_HAND, cursor_hotspot)
			Input.set_custom_mouse_cursor(tex_click, Input.CURSOR_DRAG, cursor_hotspot)
	else:
		_apply_default_cursors()

func _set_hand_cursor_recursively(node: Node):
	for child in node.get_children():
		if child is Button or child is TextureButton:
			child.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if child.get_child_count() > 0:
			_set_hand_cursor_recursively(child)

func _toggle_store(close_store: bool):
	if is_shop_transitioning: return 
	is_shop_transitioning = true 
	
	is_tended = close_store
	_update_eye_state()
	
	if is_tended:
		if el_jetas_anim: el_jetas_anim.play("return_up")
	else:
		if el_jetas_anim: el_jetas_anim.play("hide_down")

	if not is_tended: roulette.visible = false

	var anim_duration = 1.0 
	if is_tended:
		_simple_items_fade(0.0, 0.2)
		await get_tree().create_timer(0.2).timeout
		anim.play("roll")
		var tween = create_tween()
		tween.tween_property(mat, "shader_parameter/roll_amount", 1.0, anim_duration)
		tween.tween_callback(func(): store.visible = false)
		
		tween.finished.connect(func(): 
			is_shop_transitioning = false
			if comic_root and comic_root.visible:
				return
			if roulette.has_method("check_and_roll_modifiers"):
				roulette.check_and_roll_modifiers()
		)
	else:
		store.visible = true
		_reset_items_visibility() 
		anim.play("unroll")
		var tween = create_tween()
		tween.tween_property(mat, "shader_parameter/roll_amount", 0.0, anim_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.chain().tween_callback(_animate_items_entry)
		tween.finished.connect(func(): is_shop_transitioning = false)
		
func _animate_items_entry():
	var tween = create_tween().set_parallel(true)
	var drop_height = 80.0
	var duration = 0.6
	var delay_step = 0.03
	var current_delay = 0.0
	
	for item in _get_animatable_store_items():
		if is_instance_valid(item):
			item.modulate.a = 0.0
			var final_pos = item.position
			if original_positions.has(item): final_pos = original_positions[item]
			item.position = final_pos - Vector2(0, drop_height)
			tween.tween_property(item, "position", final_pos, duration).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(current_delay)
			tween.tween_property(item, "modulate:a", 1.0, duration * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(current_delay)
			current_delay += delay_step
		
func _reset_items_visibility():
	for item in _get_animatable_store_items():
		if is_instance_valid(item):
			item.modulate.a = 0.0
			item.scale = Vector2.ONE 
			if original_positions.has(item):
				item.position = original_positions[item]

func _simple_items_fade(target_alpha: float, duration: float):
	var tween = create_tween().set_parallel(true)
	for item in _get_animatable_store_items():
		if is_instance_valid(item):
			tween.tween_property(item, "modulate:a", target_alpha, duration)

func _get_animatable_store_items() -> Array:
	var items = []
	if store.has_node("piece_zone"):
		for child in store.piece_zone.get_children(): items.append(child)
	if store.has_node("passive_zone"):
		for child in store.passive_zone.get_children(): items.append(child)
	if store.has_node("Reroll"): items.append(store.get_node("Reroll"))
	if store.has_node("Lock"): items.append(store.get_node("Lock"))
	if coin_sprite: items.append(coin_sprite)
	if gold_label: items.append(gold_label)
	if piece_label: items.append(piece_label)    
	if passive_label: items.append(passive_label)
	return items
		
func _on_animation_finished(anim_name: String):
	roulette.visible = is_tended
	if anim_name == "roll": store.visible = false

func _on_PlayerData_currency_changed(new_amount: int) -> void:
	if gold_label: gold_label.text = str(new_amount)

func _toggle_eye_parpadeo() -> void:
	sprite_show.texture = eye_closed_texture
	pupil.visible = false
	await get_tree().create_timer(0.07).timeout
	sprite_show.texture = original_eye_texture
	pupil.visible = true

func _update_pupil_position():
	if not pupil.visible or not sprite_show.visible: return
	var mouse_global = get_global_mouse_position()
	var dir = mouse_global - sprite_show.global_position
	if dir.length() > max_distance: dir = dir.normalized() * max_distance
	pupil.position = pupil_offset + dir

func _on_shop_hover():
	if blink_tween and blink_tween.is_valid(): blink_tween.kill()
	blink_tween = create_tween()
	blink_tween.tween_property(sprite_show, "modulate:a", 0.5, 0.12)
	blink_tween.tween_property(sprite_show, "modulate:a", 1.0, 0.12)

func _on_shop_exit():
	if blink_tween and blink_tween.is_valid(): blink_tween.kill()
	sprite_show.modulate.a = 1.0

func _update_eye_state():
	sprite_show.texture = original_eye_texture
	pupil.visible = true

func start_unroll():
	anim.play("unroll")
	store.visible = true
	roulette.visible = false
	animate_store(false)
	var tween = create_tween()
	tween.tween_property(mat, "shader_parameter/roll_amount", 0.0, 0.6)

func animate_store(hide: bool, callback: Callable = Callable()):
	var tween = get_tree().create_tween()
	var delay = 0.0
	for child in store.get_children():
		if not (child is CanvasItem): continue
		var orig_pos = original_positions.get(child, child.position)
		var offset = Vector2(200, 0)
		var target_pos = orig_pos + offset if hide else orig_pos
		var target_alpha = 0.0 if hide else 1.0
		tween.parallel().tween_property(child, "position", target_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT).set_delay(delay)
		tween.parallel().tween_property(child, "modulate:a", target_alpha, 0.5).set_delay(delay)
		delay += 0.05
	if callback.is_valid(): tween.tween_callback(callback)

func _on_store_hidden(): store.visible = false

func pausar() -> void:
	if options_animating: return
	if is_instance_valid(options_instance):
		options_animating = true
		options_instance.close_with_anim()
		options_instance = null
		options_animating = false
		return

	print("PAUSAR() llamada -> creando options como menú de pausa")
	options_animating = true
	options_instance = options_scene.instantiate() as CanvasLayer
	options_instance.name = "OptionsPause"
	var root := get_tree().root
	root.add_child(options_instance)
	root.move_child(options_instance, root.get_child_count() - 1)

	if options_instance.has_method("set_as_pause_menu"):
		options_instance.set_as_pause_menu(true)
	else:
		get_tree().paused = true

	options_animating = false
	
func get_inventory_piece_count(resource_to_check: Resource) -> int:
	var item_to_search = resource_to_check
	if resource_to_check is PieceData: item_to_search = resource_to_check.piece_origin
	if inventory and inventory.has_method("get_item_count"):
		return inventory.get_item_count(item_to_search)
	return 0

func _on_help_button_pressed() -> void:
	print("HELP BUTTON PULSADO")
	if not is_instance_valid(help_overlay): return
	help_overlay.toggle_overlay()

func get_active_unit_ids_for_race(target_race_enum: int) -> Array:
	var active_ids = []
	if not roulette or not roulette.has_node("SpriteRuleta/SlotsContainer"):
		return []

	var slots_container = roulette.get_node("SpriteRuleta/SlotsContainer")
	for slot_root in slots_container.get_children():
		if not slot_root.has_node("slot"): continue
		var actual_slot = slot_root.get_node("slot")
		if "current_piece_data" in actual_slot and actual_slot.current_piece_data:
			var piece = actual_slot.current_piece_data
			if "piece_origin" in piece and piece.piece_origin:
				var origin = piece.piece_origin
				if origin.race == target_race_enum:
					if not active_ids.has(origin.id):
						active_ids.append(origin.id)
	return active_ids

func get_all_pieces_for_race(race_name: String) -> Array:
	var list = []
	var registry_script = load("res://scripts/piece_Registry.gd")
	if not registry_script: return []
	
	var registry = registry_script.new()
	var prefix = race_name.to_lower() + "."
	for key in registry._map.keys():
		if key.begins_with(prefix):
			var path = registry._map[key]
			var res = load(path)
			if res: list.append(res)
	
	registry.free()
	return list

func get_race_enum_from_name(race_name: String) -> int:
	match race_name:
		"European": return 2 
		"Japanese": return 1 
		"Nordic": return 0 
	return -1
	
func get_active_synergies() -> Dictionary:
	var result = { "jap": 0, "nor": 0, "eur": 0 }
	if not roulette or not roulette.has_node("SpriteRuleta/SlotsContainer"):
		push_warning("GameManager: No se encontró el contenedor de slots en la ruleta.")
		return result

	var slots_container = roulette.get_node("SpriteRuleta/SlotsContainer")
	var unique_ids_jap = {}
	var unique_ids_nor = {}
	var unique_ids_eur = {}
	
	for slot_root in slots_container.get_children():
		if not slot_root.has_node("slot"): continue
		var actual_slot = slot_root.get_node("slot")
		if "current_piece_data" in actual_slot and actual_slot.current_piece_data:
			var piece_data = actual_slot.current_piece_data
			if "piece_origin" in piece_data and piece_data.piece_origin is PieceRes:
				var res = piece_data.piece_origin
				var id = res.id
				match res.race:
					PieceRes.PieceRace.JAPANESE: unique_ids_jap[id] = true
					PieceRes.PieceRace.NORDIC: unique_ids_nor[id] = true
					PieceRes.PieceRace.EUROPEAN: unique_ids_eur[id] = true

	var count_jap = unique_ids_jap.size()
	if count_jap >= 4: result["jap"] = 2
	elif count_jap >= 2: result["jap"] = 1
		
	var count_nor = unique_ids_nor.size()
	if count_nor >= 4: result["nor"] = 2
	elif count_nor >= 2: result["nor"] = 1
		
	var count_eur = unique_ids_eur.size()
	if count_eur >= 4: result["eur"] = 2
	elif count_eur >= 2: result["eur"] = 1
	
	return result

func animate_day_progressbar():
	if not day_slider: return null
	var target_value = current_day
	var tween := create_tween()
	tween.tween_interval(0.3)
	tween.tween_property(day_slider, "value", target_value, 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tween

func animate_info_text():
	if not info_label: return
	info_label.visible_characters = 0
	var tween := create_tween()
	tween.tween_property(info_label, "visible_characters", info_label.get_total_character_count(), 1)
	return tween

func reveal_next_day_button():
	if not NextDayButton: return
	if NextDayButton.pressed.is_connected(_advance_to_next_day): NextDayButton.pressed.disconnect(_advance_to_next_day)
	if not NextDayButton.pressed.is_connected(_on_next_day_button_pressed): NextDayButton.pressed.connect(_on_next_day_button_pressed)
		
	NextDayButton.visible = true
	NextDayButton.modulate.a = 0.0
	NextDayButton.move_to_front()
	NextDayButton.disabled = false 
	NextDayButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var tween := create_tween()
	tween.tween_property(NextDayButton, "modulate:a", 1.0, 1.0)

func build_day_summary_text() -> String:
	var rounds_count = rounds_per_day
	var round_unit_price = daily_gold_salary / rounds_count if rounds_count > 0 else 0
	var glad_count = gladiators_defeated
	var glad_unit_price = daily_gold_loot / glad_count if glad_count > 0 else 0
	var total_day = daily_gold_salary + daily_gold_loot

	var text := ""
	text += "[center][b]SUMMARY OF THE DAY[/b][/center]\n\n"
	text += "[img=24x24]res://assets/Coin (1).png[/img]  "
	text += "[b]Rounds:[/b] %d × %d = [b]%d gold[/b]\n" % [round_unit_price, rounds_count, daily_gold_salary]
	text += "[img=24x24]res://assets/GladsIcon (1).png[/img]  "
	text += "[b]Gladiators:[/b] %d × %d = [b]%d gold[/b]\n" % [glad_unit_price, glad_count, daily_gold_loot]
	text += "\n\n"
	text += "[center][b]TOTAL: %d gold[/b][/center]" % total_day
	return text

func _restart_game() -> void:
	print("Volviendo al menú principal...")
	get_tree().paused = false
	PlayerData.reset_player_data()
	if has_node("/root/GlobalStats"): GlobalStats.update_stats({}) 
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	
func _on_next_day_button_pressed() -> void:
	NextDayButton.disabled = true
	if is_game_over_state or current_day >= max_days:
		var t = create_tween()
		t.set_parallel(true)
		if transition_rect: 
			transition_rect.visible = true
			transition_rect.color = Color.BLACK 
			t.tween_property(transition_rect, "modulate:a", 1.0, 1.5) 
			
		var ui_to_hide = [fondo_texto, next_day_label, info_label, win_label, lose_label, day_slider, anfora_rota, NextDayButton, next_day_image]
		for elem in ui_to_hide:
			if elem: t.tween_property(elem, "modulate:a", 0.0, 0.5)
			
		await t.finished
		_restart_game()
	else:
		var t = create_tween()
		t.set_parallel(true)
		for child in day_finished_view.get_children():
			if child is CanvasItem:
				t.tween_property(child, "modulate:a", 0.0, 0.5)
				
		t.chain().tween_callback(func():
			NextDayButton.disabled = false 
			_advance_to_next_day()
		)

func animate_amphora_break():
	if not day_slider or not anfora_rota: return null
	day_slider.max_value = max_days
	day_slider.value = current_day - 1
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(func(): anfora_rota.visible = true)
	tween.set_parallel(true)
	tween.tween_property(day_slider, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(anfora_rota, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	return tween

func _animate_lose_transition() -> void:
	var t = create_tween()
	t.set_parallel(true)
	if info_label: t.tween_property(info_label, "modulate:a", 0.0, 1.0)
	if next_day_label: t.tween_property(next_day_label, "modulate:a", 0.0, 1.0)
	if fondo_texto: t.tween_property(fondo_texto, "modulate:a", 0.0, 1.0)
	if anfora_rota: t.tween_property(anfora_rota, "modulate:a", 0.0, 1.0)
	if day_slider: t.tween_property(day_slider, "modulate:a", 0.0, 1.0)
	
	t.chain().tween_callback(func():
		if lose_label:
			lose_label.visible_characters = 0 
			lose_label.modulate.a = 1.0       
	)
	if lose_label:
		t.tween_property(lose_label, "visible_characters", lose_label.get_total_character_count(), 2.0)
	t.chain().tween_callback(reveal_next_day_button)

func _play_simple_intro():
	comic_root.visible = true
	if comic_fondo: comic_fondo.modulate.a = 1.0
	buttonShop.disabled = true 
	
	var pos1 = Comic1.position
	var pos2 = Comic2.position
	var pos3 = Comic3.position
	var screen_size = get_viewport_rect().size
	
	Comic1.position.x = -Comic1.size.x - 50      
	Comic2.position.x = screen_size.x + 50       
	Comic3.position.y = screen_size.y + 50       
	
	var t = create_tween()
	t.tween_property(Comic1, "position", pos1, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_interval(1) 
	t.tween_property(Comic2, "position", pos2, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_interval(1) 
	t.tween_property(Comic3, "position", pos3, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_interval(1) 
	
	t.tween_callback(func(): 
		if start_button:
			start_button.visible = true
			start_button.modulate.a = 0.0
	)
	if start_button:
		t.tween_property(start_button, "modulate:a", 1.0, 0.5)

func _on_start_button_pressed():
	buttonShop.disabled = false
	var t = create_tween()
	t.set_parallel(true) 
	if comic_fondo: t.tween_property(comic_fondo, "modulate:a", 0.0, 0.5) 
	if start_button: t.tween_property(start_button, "modulate:a", 0.0, 0.5)
	t.chain().tween_callback(func(): 
		comic_root.visible = false
		if roulette.has_method("check_and_roll_modifiers"):
			roulette.check_and_roll_modifiers()
	)

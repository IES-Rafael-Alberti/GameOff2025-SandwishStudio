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

## ------------------------------------------------------------------
## Nodos
## ------------------------------------------------------------------
@onready var buttonShop: Button = $elJetas/ButtonShop
@onready var sprite_show: Sprite2D = $elJetas/ButtonShop/EyeSprite
@onready var pupil: Sprite2D = $elJetas/ButtonShop/EyeSprite/Pupil
# Referencia al AnimationPlayer de elJetas
@onready var el_jetas_anim: AnimationPlayer = $elJetas/AnimationPlayer

@onready var mat = $Store/Sprite2D.material
@onready var anim = $Store/AnimationPlayer
@onready var gold_label: Label = $Store/gold_label
@onready var store: Control = $Store
@onready var inventory: Control = $inventory
@onready var roulette: Node2D = $Roulette
@onready var combat_scene: Node2D = $combat_scene
@onready var announcement_label: Label = $AnnouncementLabel
# --- CONFIGURACIÓN ---
@export var gold_round_base: int = 100
@export var gold_day_mult: float = 1
@export var rounds_per_day: int = 10
@export var gladiators_per_day: int = 1
@export var gladiators_mult: int = 1
@export var max_days: int = 2


# --- UI LABELS ---
@onready var round_label: Label = $RoundLabel
@onready var day_label: Label = $DayLabel
@onready var gladiator_label: Label = $GladiatorLabel

# --- VISTAS (UI) ---
@onready var day_finished_view: CanvasLayer = $DayFinished
@onready var next_day_image: TextureRect = $DayFinished/NextDayImage 
@onready var game_over_view: CanvasLayer = $GameOver
@onready var win_view: CanvasLayer = $Win

# --- Referencias NUEVAS para DayFinished ---
@onready var next_day_label: Label = $DayFinished/NextDayLabel
@onready var day_slider: HSlider = $DayFinished/HSlider
@onready var info_label: Label = $DayFinished/InfoLabel

var pupil_offset: Vector2
var original_eye_texture: Texture2D
var eye_closed_texture: Texture2D
var blink_timer := 0.0
var blink_interval_min := 2.0
var blink_interval_max := 5.0
var blink_time := 0.1
var pause_scene = preload("res://scenes/pause.tscn")
var is_tended = true
var original_positions = {}
var blink_tween: Tween = null
var max_distance: float = 100

# Variable acumuladora para el oro ganado EXCLUSIVAMENTE en el día
var daily_gold_salary: int = 0
var daily_gold_loot: int = 0

## ------------------------------------------------------------------
## Funciones de Godot
## ------------------------------------------------------------------

func _ready():
	# IMPORTANTE: Añadir al grupo para que SynergyIcon pueda encontrarnos
	add_to_group("game_manager")
	
	daily_gold_salary = 0
	daily_gold_loot = 0
	pupil_offset = pupil.position
	eye_closed_texture = preload("res://assets/Oculta_retocada.png")
	original_eye_texture = sprite_show.texture

	for child in store.get_children():
		if child is CanvasItem:
			original_positions[child] = child.position
			child.modulate.a = 1.0

	# --- Conexiones ---
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
	PlayerData.currency_changed.connect(_on_PlayerData_currency_changed)
	if inventory.has_signal("item_sold"):
		inventory.item_sold.connect(PlayerData.add_currency)
		
	if next_day_image:
		next_day_image.gui_input.connect(_on_next_day_image_input)

	blink_timer = randf_range(blink_interval_min, blink_interval_max)
	_on_PlayerData_currency_changed(PlayerData.get_current_currency())
	
	store.start_new_round()
	_update_ui_labels()

	if current_round == 1:
		_give_initial_piece()
		set_state(GameState.ROULETTE)
		# --- CAMBIO AQUI: Forzamos la animación de entrada al inicio ---
		if el_jetas_anim: el_jetas_anim.play("intro")
	else:
		set_state(GameState.SHOP)

func _process(delta: float) -> void:
	# Gestionamos el temporizador del parpadeo
	blink_timer -= delta
	
	# Solo mostramos/movemos la pupila si el ojo está ABIERTO (textura original)
	if sprite_show.texture == original_eye_texture:
		pupil.visible = true
		_update_pupil_position()
	else:
		# Si está parpadeando (textura cerrada), ocultamos la pupila
		pupil.visible = false

	# Ejecutar parpadeo aleatorio cuando toca
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

		var state_text = ""	
		round_label.text = "Wave %d/%d" % [current_round, rounds_per_day]


## ------------------------------------------------------------------
## Máquina de Estados
## ------------------------------------------------------------------

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

## ------------------------------------------------------------------
## Lógica Principal
## ------------------------------------------------------------------

func _on_shop_button_pressed():
	if anim.is_playing():
		return
		
	if current_state == GameState.SHOP:
		set_state(GameState.ROULETTE)
	elif current_state == GameState.ROULETTE:
		set_state(GameState.SHOP)

func _on_roulette_spin_started():
	set_state(GameState.SPINNING)


func _on_combat_requested(piece_resource: Resource):
	if piece_resource and piece_resource is PieceRes:
		set_state(GameState.COMBAT)
	else:
		print("Giro en vacío. Pasando a siguiente ronda.")
		_on_combat_finished(false)

func _on_combat_finished(player_won: bool = false, loot_from_combat: int = 0):
	# 1. Ingreso Base (Salario por ronda)
	var round_income = int(gold_round_base * gold_day_mult)
	
	# 2. Sumamos al jugador el salario (el loot ya se lo dio combat_scene)
	PlayerData.add_currency(round_income)
	
	# 3. Acumulamos por separado para el desglose
	daily_gold_salary += round_income
	daily_gold_loot += loot_from_combat
	
	print("Fin ronda. Base: %d, Loot: %d" % [round_income, loot_from_combat])

	if player_won:
		gladiators_defeated += 1
	
	# COMPROBAMOS SI SE ACABÓ EL DÍA
	if current_round >= rounds_per_day:
		print("¡Fin del Día %d! Verificando cuota..." % current_day)
		
		if gladiators_defeated >= gladiators_per_day:
			if current_day >= max_days:
				print("¡Juego Completado! Victoria.")
				_show_win_view()
			else:
				print("Cuota cumplida. Pasando a Siguiente Día.")
				_show_day_finished_view()
		else:
			print("Cuota NO cumplida (%d/%d). GAME OVER." % [gladiators_defeated, gladiators_per_day])
			_show_game_over_view()
			
	else:
		current_round += 1
		print("--- Empezando Ronda %d ---" % current_round)
		_update_ui_labels()
		set_state(GameState.SHOP)
		store.start_new_round()
		if combat_scene:
			combat_scene.spawn_enemy_one()

func _show_day_finished_view() -> void:
	if day_finished_view:
		if next_day_label:
			next_day_label.text = "Día %d Finalizado" % current_day
		
		if day_slider:
			day_slider.min_value = 0
			day_slider.max_value = max_days
			day_slider.value = current_day
			day_slider.editable = false 
		
		if info_label:
			var rounds_count = rounds_per_day 
			var round_unit_price = 0
			if rounds_count > 0:
				round_unit_price = daily_gold_salary / rounds_count
			
			var glad_count = gladiators_defeated
			var glad_unit_price = 0
			if glad_count > 0:
				glad_unit_price = daily_gold_loot / glad_count
			
			var total_day = daily_gold_salary + daily_gold_loot
			
			var info_text = "RESUMEN DEL DÍA:\n\n"
			info_text += "Rondas (%d oro) x%d: %d oro\n" % [round_unit_price, rounds_count, daily_gold_salary]
			info_text += "Gladiadores (%d oro) x%d: %d oro\n" % [glad_unit_price, glad_count, daily_gold_loot]
			info_text += "\n--------------------------\n"
			info_text += "TOTAL: %d oro" % total_day
			
			info_label.text = info_text

		day_finished_view.visible = true
		buttonShop.disabled = true
	else:
		_advance_to_next_day()
		
func _show_game_over_view() -> void:
	if game_over_view:
		game_over_view.visible = true
		buttonShop.disabled = true
	else:
		push_error("GameManager: No se encontró el nodo 'GameOver'.")

func _show_win_view() -> void:
	if win_view:
		win_view.visible = true
		buttonShop.disabled = true
	else:
		push_error("GameManager: No se encontró el nodo 'Win'.")

func _on_next_day_image_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Click en imagen de Siguiente Día recibido.")
		_advance_to_next_day()

func _advance_to_next_day() -> void:
	print("Iniciando Día %d..." % (current_day + 1))
	current_day += 1
	current_round = 1
	gladiators_defeated = 0 
	
	daily_gold_salary = 0
	daily_gold_loot = 0
	
	if day_finished_view:
		day_finished_view.visible = false
	
	buttonShop.disabled = false
	
	_update_ui_labels()
	set_state(GameState.SHOP)
	store.generate()
	store.start_new_round()
	if combat_scene:
		combat_scene.spawn_enemy_one()

func _give_initial_piece():
	if not inventory.has_method("get_random_initial_piece"): return
	var initial_piece: Resource = inventory.get_random_initial_piece()
	if initial_piece and inventory.can_add_item(initial_piece):
		inventory.add_item(initial_piece)

func _toggle_store(close_store: bool):
	if anim.is_playing(): return
	is_tended = close_store
	_update_eye_state()
	
	# Animaciones del Jetas
	if is_tended:
		if el_jetas_anim: el_jetas_anim.play("return_up")
	else:
		if el_jetas_anim: el_jetas_anim.play("hide_down")

	if not is_tended: roulette.visible = false
	
	# CORRECCIÓN: 1.0s exacto para coincidir con la animación de la alfombra
	var anim_duration = 1.0 
	
	if is_tended:
		# --- CERRAR ---
		# 1. Ocultar items inmediatamente (simple fade out rápido)
		_simple_items_fade(0.0, 0.2)
		
		# 2. Esperar un instante para que no se vea feo
		await get_tree().create_timer(0.2).timeout
		
		# 3. Enrollar alfombra
		anim.play("roll")
		var tween = create_tween()
		tween.tween_property(mat, "shader_parameter/roll_amount", 1.0, anim_duration)
		
		# 4. Ocultar la tienda SOLO al terminar la animación completa
		tween.tween_callback(func(): store.visible = false)
		
	else:
		# --- ABRIR ---
		store.visible = true
		# 1. Asegurar que los items sean invisibles antes de abrir
		_reset_items_visibility()
		
		# 2. Desenrollar alfombra
		anim.play("unroll")
		var tween = create_tween()
		tween.tween_property(mat, "shader_parameter/roll_amount", 0.0, anim_duration)
		
		# 3. Mostrar items suavemente cuando la alfombra casi termina (al 80% del camino)
		tween.tween_callback(func(): _simple_items_fade(1.0, 0.3)).set_delay(anim_duration * 0.8)
		
func _reset_items_visibility():
	# Pone todo transparente y resetea la escala por si acaso
	for item in _get_animatable_store_items():
		if is_instance_valid(item):
			item.modulate.a = 0.0
			item.scale = Vector2.ONE # Reseteamos escala por seguridad
			# Restauramos posición original si existe
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
	return items
		
func _on_animation_finished(anim_name: String):
	roulette.visible = is_tended
	if anim_name == "roll": store.visible = false

func _on_PlayerData_currency_changed(new_amount: int) -> void:
	if gold_label: gold_label.text = str(new_amount) + "€"

func _toggle_eye_parpadeo() -> void:
	# Parpadeo: Cambio textura a cerrada y oculto pupila temporalmente
	# NOTA: Hemos quitado el chequeo "if not is_tended" para que parpadee siempre
	sprite_show.texture = eye_closed_texture
	pupil.visible = false
	
	await get_tree().create_timer(0.07).timeout
	
	# Restaurar ojo abierto y pupila
	sprite_show.texture = original_eye_texture
	pupil.visible = true

func _update_pupil_position():
	if not pupil.visible or not sprite_show.visible: return
	var mouse_global = get_global_mouse_position()
	var dir = mouse_global - sprite_show.global_position
	if dir.length() > max_distance: dir = dir.normalized() * max_distance
	pupil.position = pupil_offset + dir

func _on_shop_hover():
	# Mantenemos este efecto visual de parpadeo (alpha) al pasar el ratón
	if blink_tween and blink_tween.is_valid(): blink_tween.kill()
	blink_tween = create_tween()
	blink_tween.tween_property(sprite_show, "modulate:a", 0.5, 0.12)
	blink_tween.tween_property(sprite_show, "modulate:a", 1.0, 0.12)

func _on_shop_exit():
	if blink_tween and blink_tween.is_valid(): blink_tween.kill()
	sprite_show.modulate.a = 1.0

func _update_eye_state():
	# Estado base: Ojo abierto y pupila visible (para vigilar)
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

func pausar():
	var pause_instance = pause_scene.instantiate()
	add_child(pause_instance)
	get_tree().paused = true
	
func get_inventory_piece_count(resource_to_check: Resource) -> int:
	var item_to_search = resource_to_check
	if resource_to_check is PieceData: item_to_search = resource_to_check.piece_origin
	if inventory and inventory.has_method("get_item_count"):
		return inventory.get_item_count(item_to_search)
	return 0

## ------------------------------------------------------------------
## SISTEMA DE SINERGIAS
## ------------------------------------------------------------------
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
				# Comprobamos si es la raza que buscamos
				if origin.race == target_race_enum:
					# Evitamos duplicados (si tienes 2 sátiros, solo cuenta 1 para la lista visual)
					if not active_ids.has(origin.id):
						active_ids.append(origin.id)
	
	return active_ids

# --- NUEVA FUNCIÓN: Obtener todas las piezas de una raza (para el tooltip) ---
func get_all_pieces_for_race(race_name: String) -> Array:
	var list = []
	# Instanciamos el registro para consultar el mapa
	# Asumimos que PieceRegistry es un script accesible.
	var registry_script = load("res://scripts/piece_Registry.gd")
	if not registry_script:
		return []
	
	var registry = registry_script.new()
	var prefix = race_name.to_lower() + "."
	# Iteramos sobre las claves del mapa (ej: "europea.satiro")
	for key in registry._map.keys():
		if key.begins_with(prefix):
			var path = registry._map[key]
			var res = load(path)
			if res:
				list.append(res)
	
	registry.free()
	return list

func get_race_enum_from_name(race_name: String) -> int:
	match race_name:
		"Europea": return 2 # PieceRes.PieceRace.EUROPEA
		"Japonesa": return 1 # PieceRes.PieceRace.JAPONESA
		"Nordica": return 0 # PieceRes.PieceRace.NORDICA
	return -1
	
func get_active_synergies() -> Dictionary:
	var result = {
		"jap": 0, # Tier Japonés
		"nor": 0, # Tier Nórdico
		"eur": 0  # Tier Europeo
	}
	
	if not roulette or not roulette.has_node("SpriteRuleta/SlotsContainer"):
		push_warning("GameManager: No se encontró el contenedor de slots en la ruleta.")
		return result

	var slots_container = roulette.get_node("SpriteRuleta/SlotsContainer")
	
	var unique_ids_jap = {}
	var unique_ids_nor = {}
	var unique_ids_eur = {}
	
	for slot_root in slots_container.get_children():
		if not slot_root.has_node("slot"):
			continue
			
		var actual_slot = slot_root.get_node("slot")
		
		if "current_piece_data" in actual_slot and actual_slot.current_piece_data:
			var piece_data = actual_slot.current_piece_data
			
			if "piece_origin" in piece_data and piece_data.piece_origin is PieceRes:
				var res = piece_data.piece_origin
				var id = res.id
				
				match res.race:
					PieceRes.PieceRace.JAPONESA:
						unique_ids_jap[id] = true
					PieceRes.PieceRace.NORDICA:
						unique_ids_nor[id] = true
					PieceRes.PieceRace.EUROPEA:
						unique_ids_eur[id] = true
					
					

	# --- CÁLCULO DE TIERS ---
	var count_jap = unique_ids_jap.size()
	if count_jap >= 4:
		result["jap"] = 2
	elif count_jap >= 2:
		result["jap"] = 1
		
	var count_nor = unique_ids_nor.size()
	if count_nor >= 4:
		result["nor"] = 2
	elif count_nor >= 2:
		result["nor"] = 1
		
	var count_eur = unique_ids_eur.size()
	if count_eur >= 4:
		result["eur"] = 2
	elif count_eur >= 2:
		result["eur"] = 1
	
	return result

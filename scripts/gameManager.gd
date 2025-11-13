# game.gd
# (El que extiende Node2D)
extends Node2D

@onready var carpet_area = $Area2D
@onready var mat =  $Store/Sprite2D.material
@onready var anim =  $Store/AnimationPlayer
@onready var gold_label: Label = $gold_label
@onready var store: Control = $Store
@onready var inventory: Control = $inventory
@onready var roulette: Node2D = $Roulette

var pause_scene = preload("res://scenes/pause.tscn")
var is_tended = false
var anim_playing = false 
var original_positions = {}

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		pausar()

func _ready():
	for child in store.get_children():
		if child is CanvasItem:
			original_positions[child] = child.position
			child.modulate.a = 1.0
	anim.connect("animation_finished", Callable(self, "_on_animation_finished"))
	carpet_area.input_pickable = true
	carpet_area.connect("input_event", Callable(self, "_on_area_input"))
	PlayerData.currency_changed.connect(_on_PlayerData_currency_changed)
	if inventory.has_signal("item_sold"):
		inventory.item_sold.connect(PlayerData.add_currency)
	else:
		push_warning("game.gd: El nodo de inventario no tiene la señal 'item_sold'.")
			
	_on_PlayerData_currency_changed(PlayerData.get_current_currency())
	store.generate()

# --- Funciones de Señales ---

## Esta función se llama AUTOMÁTICAMENTE cuando PlayerData emite 'currency_changed'
func _on_PlayerData_currency_changed(new_amount: int) -> void:
	if gold_label:
		gold_label.text = str(new_amount) + "€"

func _on_area_input(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		if not anim_playing:
			toggle_roll()

func toggle_roll():
	is_tended = !is_tended
	anim_playing = true

	if is_tended:
		anim.play("roll")
		animate_store(true, Callable(self, "_on_store_hidden"))
	else:
		start_unroll()

	var target = 1.0 if is_tended else 0.0
	var tween = create_tween()
	tween.tween_property(mat, "shader_parameter/roll_amount", target, 1.0)
	tween.connect("finished", Callable(self, "_update_collision"))

func _on_store_hidden():
	store.visible = false
	roulette.visible = true

func start_unroll():
	anim.play("unroll")
	store.visible = true
	roulette.visible = false
	animate_store(false) 

	var tween = create_tween()
	tween.tween_property(mat, "shader_parameter/roll_amount", 0.0, 1.0)
	tween.connect("finished", Callable(self, "_update_collision"))

func _on_animation_finished(anim_name):
	anim_playing = false

func animate_store(hide: bool, callback: Callable = Callable()):
	var tween = get_tree().create_tween()
	var delay = 0.0
	for child in store.get_children():
		if not (child is CanvasItem):
			continue
		var orig_pos = original_positions.get(child, child.position)
		var offset = Vector2(200, 0)
		var target_pos = orig_pos + offset if hide else orig_pos
		var target_alpha = 0.0 if hide else 1.0
		tween.parallel().tween_property(child, "position", target_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT).set_delay(delay)
		tween.parallel().tween_property(child, "modulate:a", target_alpha, 0.5).set_delay(delay)
		delay += 0.05

	if callback.is_valid():
		tween.tween_callback(callback)
		
func pausar():
	var pause_instance = pause_scene.instantiate()

	add_child(pause_instance)
	
	get_tree().paused = true

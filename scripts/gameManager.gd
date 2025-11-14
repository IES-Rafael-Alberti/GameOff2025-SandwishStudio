# game.gd
# (El que extiende Node2D)
extends Node2D

@onready var gold_label: Label = $gold_label
@onready var store: Control = $Store
@onready var inventory: Control = $inventory
@onready var roulette: Node2D = $Roulette
var pause_scene = preload("res://scenes/pause.tscn")

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		pausar()

func _ready():
	
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


func change_mode() -> void:
	if store.visible == true:
		store.visible = false
		roulette.visible = true
	else:
		store.visible = true
		roulette.visible = false
		
func pausar():
	var pause_instance = pause_scene.instantiate()

	add_child(pause_instance)
	
	get_tree().paused = true

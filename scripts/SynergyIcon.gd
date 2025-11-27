extends Control
class_name SynergyIcon

# --- NUEVO: Referencia al nodo que muestra la imagen ---
@export var icon_display: TextureRect

@export_enum("European", "Japanese", "Nordic") var race_name: String = "European"
@export var theme_color: Color = Color.WHITE

@export_group("tier Icons")
@export var sinergia0: Texture2D
@export var sinergia1: Texture2D
@export var sinergia2: Texture2D

var tooltip_ref: PanelContainer 

var synergy_definitions = {
	"European": [
		{"required": 2, "desc": "Max health + 25%"},
		{"required": 4, "desc": "Max health + 50%"}
	],
	"Japanese": [
		{"required": 2, "desc": "For each three attacks deal +50% dmg"},
		{"required": 4, "desc": "For each three attacks deal +100% dmg"}
	],
	"Nordic": [
		{"required": 2, "desc": "When troops reach 25% health, they heal up to 50%."},
		{"required": 4, "desc": "When troops reach 25% health, they heal up to 75%."}
	]
}

var current_count: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_ref = get_tree().get_first_node_in_group("tooltip")
	
	# Inicializar con el icono de bronce si existe la referencia
	if icon_display and not icon_display.texture:
		icon_display.texture = sinergia0
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if GlobalSignals:
		GlobalSignals.synergy_update_requested.connect(_on_synergy_update_requested)
	call_deferred("_on_synergy_update_requested")
func _on_synergy_update_requested() -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	var new_count = 0
	
	if game_manager:
		# Usamos la lógica que ya tenías para obtener los IDs activos de esta raza
		if game_manager.has_method("get_race_enum_from_name") and game_manager.has_method("get_active_unit_ids_for_race"):
			var race_enum = game_manager.get_race_enum_from_name(race_name)
			var active_ids = game_manager.get_active_unit_ids_for_race(race_enum)
			new_count = active_ids.size()
	
	current_count = new_count
	update_synergy_count(current_count)
func update_synergy_count(count: int):	
	# --- 1. LÓGICA DE TEXTURAS (Nueva) ---
	if icon_display:
		if count >= 4:
			icon_display.texture = sinergia2   
		elif count >= 2:
			icon_display.texture = sinergia1 
		else:
			icon_display.texture = sinergia0 
	

func _on_mouse_entered():
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	var all_pieces = []
	var active_ids = []
	
	if game_manager:
		if game_manager.has_method("get_all_pieces_for_race"):
			all_pieces = game_manager.get_all_pieces_for_race(race_name)
		
		if game_manager.has_method("get_race_enum_from_name") and game_manager.has_method("get_active_unit_ids_for_race"):
			var race_enum = game_manager.get_race_enum_from_name(race_name)
			active_ids = game_manager.get_active_unit_ids_for_race(race_enum)
	
	# Usamos la cuenta real de piezas activas si es posible
	var real_count_for_tooltip = current_count
	if game_manager: 
		real_count_for_tooltip = active_ids.size()
	
	if tooltip_ref and tooltip_ref.has_method("show_synergy_tooltip"):
		var defs = synergy_definitions.get(race_name, [])
		tooltip_ref.show_synergy_tooltip(race_name, real_count_for_tooltip, 4, defs, theme_color, all_pieces, active_ids)

func _on_mouse_exited():
	if tooltip_ref and tooltip_ref.has_method("hide_tooltip"):
		tooltip_ref.hide_tooltip()

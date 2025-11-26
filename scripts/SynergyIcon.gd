# Actualización completa de SynergyIcon.gd
extends Control
class_name SynergyIcon

# ¡IMPORTANTE!: En el editor de Godot, selecciona cada icono y cambia esto a "Japonesa" o "Nordica"
@export_enum("Europea", "Japonesa", "Nordica") var race_name: String = "Europea"
@export var theme_color: Color = Color.WHITE

var tooltip_ref: PanelContainer 

var synergy_definitions = {
	"Europea": [
		{"required": 2, "desc": "+15% Probabilidad Crítico"},
		{"required": 4, "desc": "+30% Prob. Crítico y +50% Daño Crítico"}
	],
	"Japonesa": [
		{"required": 2, "desc": "+20% Velocidad de Ataque"},
		{"required": 4, "desc": "+45% Velocidad de Ataque"}
	],
	"Nordica": [
		{"required": 2, "desc": "+200 Vida Máxima"},
		{"required": 4, "desc": "+500 Vida y Regeneración de Salud"}
	]
}

var current_count: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_ref = get_tree().get_first_node_in_group("tooltip")
	
	# Debug para ver si se inicializa bien
	# print("SynergyIcon listo. Raza: ", race_name) 

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func update_synergy_count(count: int):
	current_count = count
	if count >= 2:
		modulate = Color.WHITE 
	elif count > 0:
		modulate = Color(0.8, 0.8, 0.8, 0.9)
	else:
		modulate = Color(0.5, 0.5, 0.5, 0.6) 

func _on_mouse_entered():
	# 1. Buscamos el GameManager
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	var all_pieces = []
	var active_ids = []
	
	if game_manager:
		# 2. Pedimos TODAS las piezas de esta raza (para mostrar la colección en gris/color)
		if game_manager.has_method("get_all_pieces_for_race"):
			all_pieces = game_manager.get_all_pieces_for_race(race_name)
		
		# 3. Pedimos qué piezas están ACTIVAS en la ruleta
		if game_manager.has_method("get_race_enum_from_name") and game_manager.has_method("get_active_unit_ids_for_race"):
			var race_enum = game_manager.get_race_enum_from_name(race_name)
			active_ids = game_manager.get_active_unit_ids_for_race(race_enum)
	
	# --- CORRECCIÓN ---
	# Calculamos la cantidad real basada en los IDs activos que acabamos de buscar.
	# Si active_ids tiene datos, usamos su tamaño. Si no (quizás no encontró el GM), usamos el guardado.
	var real_count_for_tooltip = current_count
	if game_manager: # Si tenemos game_manager, la lista active_ids es la "verdad absoluta"
		real_count_for_tooltip = active_ids.size()
	
	# 4. Mostramos el Tooltip usando real_count_for_tooltip en lugar de current_count
	if tooltip_ref and tooltip_ref.has_method("show_synergy_tooltip"):
		var defs = synergy_definitions.get(race_name, [])
		tooltip_ref.show_synergy_tooltip(race_name, real_count_for_tooltip, 4, defs, theme_color, all_pieces, active_ids)

func _on_mouse_exited():
	if tooltip_ref and tooltip_ref.has_method("hide_tooltip"):
		tooltip_ref.hide_tooltip()

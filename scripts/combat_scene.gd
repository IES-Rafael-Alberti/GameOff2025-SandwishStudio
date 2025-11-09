extends Node2D

const NPC_SCENE := preload("res://scenes/npc.tscn")
const RES_LIST := [
	preload("res://resourses/warrior/black_warrior.tres"),
	preload("res://resourses/warrior/blue_warrior.tres"),
	preload("res://resourses/warrior/red_warrior.tres"),
	preload("res://resourses/warrior/yellow_warrior.tres")
]

@onready var enemy_spawn: Marker2D = $EnemySpawn
@onready var btn_start: Button = $BtnStart
@onready var btn_enemy: Button = $BtnEnemy
@onready var btn_ally: Button = $BtnAlly
@onready var inventory = get_node("/root/game/inventory")

# Asigna en el editor el nodo Inventory (o cámbialo por la ruta directa con get_node())

# Crea un array para guardar los marcadores AllySpawn1...6
@onready var ally_spawns: Array[Marker2D] = [
	$AllySpawn1, $AllySpawn2, $AllySpawn3,
	$AllySpawn4, $AllySpawn5, $AllySpawn6
]

var ally_npcs: Array = []  # lista de aliados activos
var enemy_npc: npc = null

var combat_running := false
var start_timer: Timer
var ally_timers: Array = []
var enemy_timer: Timer

func _ready() -> void:
	randomize()

	# Resuelve la referencia al Inventory (instancia real)


	btn_ally.pressed.connect(spawn_allies_from_inventory)
	btn_enemy.pressed.connect(spawn_enemy)
	btn_start.pressed.connect(_on_start_pressed)

	start_timer = Timer.new()
	start_timer.one_shot = true
	add_child(start_timer)
	start_timer.timeout.connect(_begin_combat)

	_update_start_btn_state()

# -----------------------------------------------------------------
# Spawnea aliados según el número TOTAL de piezas en el inventario
# -----------------------------------------------------------------
func spawn_allies_from_inventory() -> void:
	if ally_npcs.size() > 0:
		print("Ya hay aliados en el campo.")
		return

	if not is_instance_valid(inventory):
		push_error("No se encontró el nodo Inventory. Verifica la ruta en get_node().")
		return

	# Verificamos que inventory tenga la propiedad 'piece_counts'
	if not inventory.has_meta("piece_counts") and not "piece_counts" in inventory:
		if not inventory.has_method("get_piece_counts") and not "piece_counts" in inventory:
			push_error("El nodo Inventory no contiene 'piece_counts'.")
			return

	# Intentamos obtener el diccionario (según cómo lo tengas definido)
	var piece_counts_dict: Dictionary = {}

	if "piece_counts" in inventory:
		piece_counts_dict = inventory.piece_counts
	elif inventory.has_method("get_piece_counts"):
		piece_counts_dict = inventory.get_piece_counts()
	else:
		push_error("No se pudo acceder a piece_counts en Inventory.")
		return

	# Calcula el total de piezas
	var total_pieces := 0
	for key in piece_counts_dict.keys():
		var entry = piece_counts_dict[key]
		if typeof(entry) == TYPE_DICTIONARY and entry.has("count"):
			total_pieces += int(entry["count"])
		elif typeof(entry) == TYPE_INT:
			total_pieces += entry

	if total_pieces == 0:
		print("No hay piezas en el inventario.")
		return

	var max_allies = min(total_pieces, ally_spawns.size())
	print("Generando %d aliados basados en el inventario (total_pieces=%d)..." % [max_allies, total_pieces])

	for i in range(max_allies):
		var spawn_marker: Marker2D = ally_spawns[i]
		if spawn_marker:
			var ally = _spawn_npc(npc.Team.ALLY, spawn_marker.position)
			ally_npcs.append(ally)

	btn_ally.disabled = true
	_update_start_btn_state()

# -----------------------------------------------------------------
func spawn_enemy() -> void:
	if is_instance_valid(enemy_npc):
		print("Ya hay un enemigo")
		return

	var pos := enemy_spawn.position
	enemy_npc = _spawn_npc(npc.Team.ENEMY, pos)
	btn_enemy.disabled = true
	_update_start_btn_state()

# -----------------------------------------------------------------
func _spawn_npc(team: int, pos: Vector2) -> npc:
	var n: npc = NPC_SCENE.instantiate()
	n.team = team
	n.position = pos
	n.npc_res = RES_LIST[randi() % RES_LIST.size()]
	add_child(n)
	
	n.tree_exited.connect(func ():
		if team == npc.Team.ALLY:
			ally_npcs.erase(n)
			if ally_npcs.is_empty():
				btn_ally.disabled = false
		else:
			enemy_npc = null
			btn_enemy.disabled = false

		if combat_running:
			_stop_combat()
		_update_start_btn_state()
	)
	return n

# -----------------------------------------------------------------
func _on_start_pressed() -> void:
	if combat_running:
		return
	if ally_npcs.is_empty() or not is_instance_valid(enemy_npc):
		print("Necesitas aliados y un enemigo para comenzar.")
		return

	combat_running = true
	btn_start.disabled = true
	btn_ally.disabled = true
	btn_enemy.disabled = true

	print("Comienza en 3 segundos")
	start_timer.start(3.0)

# -----------------------------------------------------------------
func _begin_combat() -> void:
	print("Comienza el combate")

	# Un timer por aliado
	for ally in ally_npcs:
		if is_instance_valid(ally):
			var t = _make_attack_timer(ally, enemy_npc)
			ally_timers.append(t)

	# Hacemos que el enemigo pueda elegir un aliado aleatorio y vivo
	if not ally_npcs.is_empty():
		enemy_timer = _make_attack_timer(enemy_npc, ally_npcs)  # le pasamos la lista completa

# -----------------------------------------------------------------
func _make_attack_timer(attacker: npc, defender) -> Timer:
	var t := Timer.new()
	t.one_shot = false
	var aps = 1.0
	if is_instance_valid(attacker) and attacker.npc_res:
		aps = max(0.01, attacker.npc_res.atack_speed)
	t.wait_time = 1.0 / aps
	add_child(t)
	
	t.timeout.connect(func () -> void:
		if not is_instance_valid(attacker):
			_stop_combat()
			return

		var current_defender = defender

		# Si el defensor es una lista, filtrar los válidos y elegir uno aleatorio
		if current_defender is Array:
			var valids := []
			for d in current_defender:
				if is_instance_valid(d):
					valids.append(d)
			if valids.is_empty():
				_stop_combat()
				return
			current_defender = valids[randi() % valids.size()]

		if not is_instance_valid(current_defender):
			_stop_combat()
			return

		_do_attack(attacker, current_defender)
	)
	t.start()
	return t

# -----------------------------------------------------------------
func _do_attack(attacker: npc, defender: npc) -> void:
	if not attacker.can_damage(defender):
		return
	var res := attacker.npc_res
	if res == null:
		return
	var dmg: float = res.damage
	var crit := randf() < float(res.critical_chance) / 100.0
	if crit:
		var mult := (res.critical_damage if res.critical_damage < 0.0 else 1.25)
		dmg *= mult
	defender.take_damage(dmg)

# -----------------------------------------------------------------
func _stop_combat() -> void:
	for t in ally_timers:
		if is_instance_valid(t):
			t.stop()
			t.queue_free()
	ally_timers.clear()

	if is_instance_valid(enemy_timer):
		enemy_timer.stop()
		enemy_timer.queue_free()
	enemy_timer = null

	combat_running = false

	if ally_npcs.is_empty():
		btn_ally.disabled = false
	if not is_instance_valid(enemy_npc):
		btn_enemy.disabled = false

	_update_start_btn_state()
	print("Combate detenido")

# -----------------------------------------------------------------
func _update_start_btn_state() -> void:
	btn_start.disabled = combat_running or ally_npcs.is_empty() or not is_instance_valid(enemy_npc)

# combat_scene.gd
extends Node2D

signal combat_finished

const NPC_SCENE := preload("res://scenes/npc.tscn")
const PieceAdapter := preload("res://scripts/piece_adapter.gd")

@export var enemy_res: Array[npcRes] = []
const ALLY_LIMIT := 14
const ENEMY_LIMIT := 1

@onready var enemy_spawn: Marker2D = $GladiatorSpawn
@onready var round_message: Label = $RoundMessage
@onready var ally_entry_spawn: Marker2D = $AlliesSpawn
@onready var enemy_wait_slot: Marker2D = $EnemySlots/EnemyWaitSlot
@onready var enemy_battle_slot: Marker2D = $EnemySlots/EnemyBattleSlot

const ALLY_BATTLE_OFSET := Vector2(-880, 0)

@onready var ally_final_slots: Array[Marker2D] = [
	$AllyFinalSlots/AllyFinalSlot1, $AllyFinalSlots/AllyFinalSlot2,
	$AllyFinalSlots/AllyFinalSlot3, $AllyFinalSlots/AllyFinalSlot4,
	$AllyFinalSlots/AllyFinalSlot5, $AllyFinalSlots/AllyFinalSlot6,
	$AllyFinalSlots/AllyFinalSlot7, $AllyFinalSlots/AllyFinalSlot8,
	$AllyFinalSlots/AllyFinalSlot9, $AllyFinalSlots/AllyFinalSlot10,
	$AllyFinalSlots/AllyFinalSlot11, $AllyFinalSlots/AllyFinalSlot12,
	$AllyFinalSlots/AllyFinalSlot13, $AllyFinalSlots/AllyFinalSlot14
]

var ally_npcs: Array[npc] = []
var enemy_npcs: Array[npc] = []

var combat_running := false
var start_timer: Timer
var ally_timers: Array[Timer] = []
var enemy_timers: Array[Timer] = []
var enemy_hp_round_start: float = 0.0
var enemy_gold_round_start: int = 0
var round_number := 0

func _ready() -> void:
	randomize()
	GlobalSignals.combat_requested.connect(on_roulette_combat_requested)

	start_timer = Timer.new()
	start_timer.one_shot = true
	add_child(start_timer)
	start_timer.timeout.connect(_begin_combat)
	
	# Spawnea el primer enemigo en cuanto la escena está lista.
	spawn_enemy_one()

func on_roulette_combat_requested(piece_resource: Resource) -> void:
	
	# --- CASO 1: Giro en VACÍO ---
	if not piece_resource or not piece_resource is PieceRes:
		push_error("on_roulette_combat_requested: Recurso nulo o inválido. Saltando combate.")
		
		# Limpiamos aliados de la ronda anterior
		_cleanup_allies_and_reset()
		
		# Movemos al enemigo de vuelta SI ESTABA LUCHANDO
		if enemy_npcs.size() > 0 and is_instance_valid(enemy_npcs[0]):
			var g := enemy_npcs[0]
			if g.position == enemy_battle_slot.position:
				_move_with_tween(g, enemy_wait_slot.position, 0.5)
		
		return
		
	print("Señal de combate global recibida. Aliado: ", piece_resource.display_name)
	
	# --- CASO 2: Combate Normal ---
	
	# 1. Limpiar aliados de la ronda anterior
	_cleanup_allies_and_reset()
	
	# 2. Spawnear nuevos aliados
	spawn_piece(npc.Team.ALLY, piece_resource)
	
	# 3. Spawmear enemigo (Si no hay uno)
	var enemy_alive := false
	for e in enemy_npcs:
		if is_instance_valid(e) and e.health > 0.0:
			enemy_alive = true
			break
			
	if not enemy_alive:
		print("No hay Gladiador vivo. Spawneando uno nuevo.")
		for e in enemy_npcs:
			if is_instance_valid(e):
				e.queue_free()
		enemy_npcs.clear()
		spawn_enemy_one()
	else:
		print("Gladiador de la ronda anterior sigue vivo. Reutilizándolo.")
		# Aseguramos que esté en la posición de espera
		if enemy_npcs.size() > 0 and is_instance_valid(enemy_npcs[0]):
			var g := enemy_npcs[0]
			if g.position != enemy_wait_slot.position:
				_move_with_tween(g, enemy_wait_slot.position, 0.5)

	# 4. Iniciar secuencia
	_start_pre_battle_sequence()

func _stop_combat() -> void:
	if enemy_npcs.size() > 0 and ally_npcs.is_empty():
		var w: npc = enemy_npcs[0]
		if is_instance_valid(w) and w.health > 0.0:
			var hp_lost: float = max(0.0, enemy_hp_round_start - w.health)
			var damage_frac: float = clamp(hp_lost / w.max_health, 0.0, 1.0)
			var base_gold: int = enemy_gold_round_start
			var payout: int = int(floor(base_gold * damage_frac))
			payout = clamp(payout, 0, int(w.gold_pool))

			if payout > 0:
				PlayerData.add_currency(payout)
				w.gold_pool = int(w.gold_pool) - payout
				print("Round reward: +", payout, " gold. Remaining pool=", w.gold_pool)
	
	for t in ally_timers:
		if is_instance_valid(t):
			t.stop()
			t.queue_free()
	ally_timers.clear()

	for t in enemy_timers:
		if is_instance_valid(t):
			t.stop()
			t.queue_free()
	enemy_timers.clear()
	
	var enemy_alive := false
	for e in enemy_npcs:
		if is_instance_valid(e) and e.health > 0.0:
			enemy_alive = true
			break
	var allies_alive := false
	for a in ally_npcs:
		if is_instance_valid(a) and a.health > 0.0:
			allies_alive = true
			break
	
	combat_running = false
	var msg_timer: Timer = null
	
	if (not enemy_alive) and allies_alive:
		msg_timer = _show_round_message("Ronda terminada: ¡Victoria!")
		msg_timer.timeout.connect(_cleanup_allies_and_reset)

	elif enemy_alive and (not allies_alive):
		msg_timer = _show_round_message("Ronda terminada: El gladiador sobrevivió.")
		if enemy_npcs.size() > 0 and is_instance_valid(enemy_npcs[0]):
			_move_with_tween(enemy_npcs[0], enemy_wait_slot.position, 0.5)
		msg_timer.timeout.connect(_cleanup_allies_and_reset)

	elif (not enemy_alive) and (not allies_alive):
		msg_timer = _show_round_message("Ronda terminada: doble KO.")
		msg_timer.timeout.connect(_cleanup_allies_and_reset)
	else:
		msg_timer = _show_round_message("Ronda terminada.")
		msg_timer.timeout.connect(_cleanup_allies_and_reset)
	
	if msg_timer:
		msg_timer.timeout.connect(func(): combat_finished.emit())
	else:
		_cleanup_allies_and_reset()
		combat_finished.emit()
		
	print("Battle stopped")

func spawn_enemy_one() -> void:
	if enemy_npcs.size() >= ENEMY_LIMIT:
		return

	if enemy_res.is_empty():
		push_error("enemy_res está vacío en combat_scene.gd.")
		return

	var pos := enemy_spawn.position
	var war_res: npcRes = enemy_res[randi() % enemy_res.size()]

	var e := _spawn_npc(npc.Team.ENEMY, pos, war_res)
	if e:
		enemy_npcs.append(e)
		_move_with_tween(e, enemy_wait_slot.position, 0.8)

func _spawn_npc(team: int, pos: Vector2, res_override: npcRes = null) -> npc:
	var n: npc = NPC_SCENE.instantiate()
	n.team = team
	n.position = pos
	n.npc_res = res_override
	
	# Aplicar bonos globales (GlobalStats)
	if team == npc.Team.ALLY and has_node("/root/GlobalStats"):
		var health_bonus = GlobalStats.get_health_bonus()
		var damage_bonus = GlobalStats.get_damage_bonus()
		var speed_bonus = GlobalStats.get_speed_bonus()
		var crit_chance_bonus = GlobalStats.get_crit_chance_bonus()
		var crit_damage_bonus = GlobalStats.get_crit_damage_bonus()
		if n.has_method("apply_passive_bonuses"):
			n.apply_passive_bonuses(
				health_bonus,
				damage_bonus,
				speed_bonus,
				crit_chance_bonus,
				crit_damage_bonus
			)
			
	# --- APLICAR SINERGIAS DE RULETA (¡NUEVO!) ---
	if team == npc.Team.ALLY:
		# Buscamos al GameManager para pedir las sinergias
		var game_manager = get_parent() # Asumiendo que CombatScene es hijo de Game
		if game_manager and game_manager.has_method("get_active_synergies"):
			var active_synergies = game_manager.get_active_synergies()
			
			if n.has_method("apply_synergies"):
				n.apply_synergies(active_synergies)
			else:
				push_warning("NPC no tiene metodo apply_synergies")
	# ---------------------------------------------
	
	add_child(n)
	
	if team == npc.Team.ENEMY:
		n.gold_pool = int(n.npc_res.gold)
	
	n.died.connect(_on_npc_died)
	n.tree_exited.connect(_on_npc_exited.bind(n))
	return n

func _move_with_tween(n: npc, target_pos: Vector2, duration: float = 1.8) -> void:
	if not is_instance_valid(n):
		return
	var tween := create_tween()
	tween.tween_property(n, "position", target_pos, duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)

func _get_free_ally_slots() -> Array[Marker2D]:
	var free: Array[Marker2D] = []
	for slot in ally_final_slots:
		if slot == null:
			continue
		var occupied := false
		for a in ally_npcs:
			if is_instance_valid(a) and a.position == slot.position:
				occupied = true
				break
		if not occupied:
			free.append(slot)
	return free
	
func _get_piece_copies_owned(piece_data: Resource) -> int:
	var game_manager = get_parent()
	if game_manager and game_manager.has_method("get_inventory_piece_count"):
		var count = game_manager.get_inventory_piece_count(piece_data)
		return max(1, count)
	return 1 

func spawn_piece(team: int, piece: PieceRes) -> void:
	if piece == null:
		return
		
	var num_copies: int = 1 
	var gold_per_enemy: int = 0 
	if team == npc.Team.ALLY:
		num_copies = _get_piece_copies_owned(piece)

	var pack: Dictionary = PieceAdapter.to_npc_res(piece, num_copies, gold_per_enemy)
	var npc_template: npcRes = pack["res"]
	var members: int = int(pack["members"])

	if team == npc.Team.ALLY:
		var free_slots_limit := ALLY_LIMIT - ally_npcs.size()
		if free_slots_limit <= 0:
			print("ALLY_LIMIT alcanzado, no se spawnea nada.")
			return
		var free_markers: Array[Marker2D] = _get_free_ally_slots()
		if free_markers.is_empty():
			print("No hay slots libres en los aliados")
			return
		var to_spawn: int = min(members, free_slots_limit, free_markers.size())
		for i in range(to_spawn):
			var idx: int = randi() % free_markers.size()
			var slot: Marker2D = free_markers[idx]
			free_markers.remove_at(idx)
			var n: npc = _spawn_npc(team, ally_entry_spawn.position, npc_template)
			if n:
				if piece.display_name != "":
					n.set_display_name(piece.display_name)
				ally_npcs.append(n)
				_place_ally_in_slot_with_tween(n, slot.position)

func _place_ally_in_slot_with_tween(n: npc, target_pos: Vector2) -> void:
	n.position = ally_entry_spawn.position
	_move_with_tween(n, target_pos, 0.8)

func _on_npc_died(n: npc) -> void:
	if n.team == npc.Team.ENEMY:
		var amount: int = int(max(0, n.gold_pool))
		if amount > 0:
			PlayerData.add_currency(amount)
			print("Reward (death): +", amount, " gold.")
		n.gold_pool = 0
		print("¡Gladiador murió! Reemplazando...")
		spawn_enemy_one()

func _on_npc_exited(n: npc) -> void:
	if n.team == npc.Team.ALLY:
		ally_npcs.erase(n)
	else:
		enemy_npcs.erase(n)
	if combat_running and ( ally_npcs.is_empty() or enemy_npcs.is_empty() ):
		_stop_combat()

func _on_start_pressed() -> void:
	if combat_running:
		return
	if ally_npcs.is_empty() or enemy_npcs.is_empty():
		print("You need allies and enemies to start.")
		return
	combat_running = true
	print("Battle starts in 3 seconds")
	start_timer.start(3.0)

func _begin_combat() -> void:
	print("Battle begins")
	if enemy_npcs.size() > 0 and is_instance_valid(enemy_npcs[0]):
		var w: npc = enemy_npcs[0]
		enemy_hp_round_start = w.health
		enemy_gold_round_start = int(w.gold_pool)

	for a in ally_npcs:
		if is_instance_valid(a):
			var t := _make_attack_timer(a, enemy_npcs)
			ally_timers.append(t)
	for e in enemy_npcs:
		if is_instance_valid(e):
			var t := _make_attack_timer(e, ally_npcs)
			enemy_timers.append(t)

func _make_attack_timer(attacker: npc, defender: Variant) -> Timer:
	var t := Timer.new()
	t.one_shot = false
	var aps := 1.0
	if is_instance_valid(attacker):
		aps = max(0.01, attacker.get_attack_speed())
	t.wait_time = 1.0 / aps
	add_child(t)

	t.timeout.connect(func () -> void:
		if not is_instance_valid(attacker):
			t.stop()
			t.queue_free()
			return
		var target: Variant = defender
		if target is Array:
			var alive: Array = []
			for d in target:
				if is_instance_valid(d):
					alive.append(d)
			if alive.is_empty():
				_stop_combat()
				return
			target = alive[randi() % alive.size()]
		if not is_instance_valid(target):
			return
		_do_attack(attacker, target)
	)
	t.start()
	return t

func _show_round_message(msg: String, duration := 2.5) -> Timer:
	if not round_message:
		return null
	round_message.text = msg
	round_message.visible = true
	var msg_timer := Timer.new()
	msg_timer.one_shot = true
	msg_timer.wait_time = duration
	add_child(msg_timer)
	msg_timer.timeout.connect(func ():
		if is_instance_valid(round_message):
			round_message.visible = false
		msg_timer.queue_free()
	)
	msg_timer.start()
	return msg_timer

func _num(x: float, d: int = 2) -> String:
	return String.num(x, d)

func _team_to_str(t: int) -> String:
	if t == npc.Team.ALLY:
		return "ALLY"
	else:
		return "ENEMY"

func _cleanup_allies_and_reset() -> void:
	for a in ally_npcs:
		if is_instance_valid(a):
			a.queue_free()
	ally_npcs.clear()
	print("Limpiando aliados...")

func _do_attack(attacker: npc, defender: npc) -> void:
	if not attacker.can_damage(defender):
		return
	if attacker.npc_res == null:
		return
	attacker.notify_before_attack(defender)
	var base := attacker.get_damage(defender)
	var dmg := base
	var crit_chance := float(attacker.get_crit_chance(defender))
	var crit := randf() < (crit_chance / 100.0)
	var mult := attacker.get_crit_mult(defender) if crit else 1.0
	dmg *= mult
	var before_hp := defender.health
	var target_max_hp := defender.max_health
	var target_name := _who(defender)
	defender.take_damage(dmg, attacker)
	var after_hp := 0.0
	if is_instance_valid(defender):
		after_hp = defender.health
	attacker.notify_after_attack(defender, dmg, crit)
	if (not is_instance_valid(defender)) or after_hp <= 0.0:
		attacker.notify_kill(defender)
	
	# LOG
	# var crit_text := " (no crit)"
	# if crit: crit_text = " CRIT x" + _num(mult)
	# print("[HIT] ", _team_to_str(attacker.team), " -> ", target_name, " | dmg=", _num(dmg))

func _who(n: npc) -> String:
	if not is_instance_valid(n):
		return "[null]"
	var res_name := ""
	if n.npc_res and n.npc_res.resource_path != "":
		res_name = n.npc_res.resource_path.get_file().get_basename()
	else:
		res_name = "Unknown"
	return "%s (%s)" % [res_name, _team_to_str(n.team)]
	
func _start_pre_battle_sequence() -> void:
	if ally_npcs.is_empty():
		print("No hay aliados para combatir. Terminando ronda.")
		_stop_combat()
		return
	
	if enemy_npcs.is_empty():
		print("No hay enemigo. Esperando reaparición...")
		await get_tree().create_timer(0.1).timeout
		if enemy_npcs.is_empty():
			print("¡El enemigo no reapareció! Forzando spawn.")
			spawn_enemy_one()
			await get_tree().create_timer(0.1).timeout 
		
		if enemy_npcs.is_empty():
			push_error("¡Fallo crítico al reaparecer enemigo!")
			_stop_combat()
			return

	var t:= Timer.new()
	t.one_shot = true
	t.wait_time = 1.0
	add_child(t)
	t.timeout.connect(_advance_to_battle_and_start)
	t.start()
	
func _advance_to_battle_and_start() -> void:
	if enemy_npcs.size() > 0 and is_instance_valid(enemy_npcs[0]):
		var g := enemy_npcs[0]
		_move_with_tween(g, enemy_battle_slot.position, 0.8)
	
	for a in ally_npcs:
		if is_instance_valid(a):
			var target := a.position + ALLY_BATTLE_OFSET
			_move_with_tween(a, target, 0.8)
	
	if not combat_running:
		combat_running = true
		start_timer.start(0.8)

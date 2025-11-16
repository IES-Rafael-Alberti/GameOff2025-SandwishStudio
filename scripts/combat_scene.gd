extends Node2D

const NPC_SCENE := preload("res://scenes/npc.tscn")
const PieceAdapter := preload("res://scripts/piece_adapter.gd")

# Enemy pool: only warriors
const ENEMY_RES := [
	preload("res://resources/warrior/black_warrior.tres"),
	preload("res://resources/warrior/blue_warrior.tres"),
	preload("res://resources/warrior/red_warrior.tres"),
	preload("res://resources/warrior/yellow_warrior.tres")
]
const ALLY_LIMIT := 14  # max allys on field (14)

const ENEMY_LIMIT := 1  # max enemies on field (1 warrior)

@onready var enemy_spawn: Marker2D = $GladiatorSpawn
@onready var round_message: Label = $RoundMessage
@onready var round_counter: Label = $RoundCounter
@onready var ally_entry_spawn: Marker2D = $AlliesSpawn
@onready var enemy_wait_slot: Marker2D = $EnemySlots/EnemyWaitSlot
@onready var enemy_battle_slot: Marker2D = $EnemySlots/EnemyBattleSlot

const ALLY_BATTLE_OFSET := Vector2(-880, 0)

# Ally spawn points (6)
@onready var ally_final_slots: Array[Marker2D] = [
	$AllyFinalSlots/AllyFinalSlot1, 
	$AllyFinalSlots/AllyFinalSlot2,
	 $AllyFinalSlots/AllyFinalSlot3,
	$AllyFinalSlots/AllyFinalSlot4, 
	$AllyFinalSlots/AllyFinalSlot5, 
	$AllyFinalSlots/AllyFinalSlot6, 
	$AllyFinalSlots/AllyFinalSlot7, 
	$AllyFinalSlots/AllyFinalSlot8,
	$AllyFinalSlots/AllyFinalSlot9, 
	$AllyFinalSlots/AllyFinalSlot10, 
	$AllyFinalSlots/AllyFinalSlot11, 
	$AllyFinalSlots/AllyFinalSlot12, 
	$AllyFinalSlots/AllyFinalSlot13, 
	$AllyFinalSlots/AllyFinalSlot14
]

var ally_npcs: Array[npc] = []    # active allies
var enemy_npcs: Array[npc] = []   # active enemies (1 warrior)

var combat_running := false
var start_timer: Timer
var ally_timers: Array[Timer] = []
var enemy_timers: Array[Timer] = []
var enemy_hp_round_start: float = 0.0
var enemy_gold_round_start: int = 0
var round_number := 0

func _ready() -> void:
	randomize()
	_update_round_counter()
	# Esta es ahora la ÚNICA forma de iniciar un combate
	GlobalSignals.combat_requested.connect(on_roulette_combat_requested)

	start_timer = Timer.new()
	start_timer.one_shot = true
	add_child(start_timer)
	start_timer.timeout.connect(_begin_combat)

func _update_round_counter() -> void:
	if is_instance_valid(round_counter):
		round_counter.text = "Wave: %d" % round_number

func _advance_round() -> void:
	print("next round")
	round_number += 1
	_update_round_counter()

# Spawn 1 enemy.
func spawn_enemy_one() -> void:
	if enemy_npcs.size() >= ENEMY_LIMIT:
		print("Enemy limit reached (%d)." % ENEMY_LIMIT)
		return

	# single warrior at GladiatorSpawn
	var pos := enemy_spawn.position
	var war_res: npcRes = ENEMY_RES[randi() % ENEMY_RES.size()]
	var e := _spawn_npc(npc.Team.ENEMY, pos, war_res)
	if e:
		enemy_npcs.append(e)
		print("Enemy spawned at GladiatorSpawn -> %s" % war_res.resource_path.get_file().get_basename())
		_move_with_tween(e, enemy_wait_slot.position, 0.8)

# Optional resource override lets us force a specific npcRes (used here for both sides)
func _spawn_npc(team: int, pos: Vector2, res_override: npcRes = null) -> npc:
	var n: npc = NPC_SCENE.instantiate()
	n.team = team
	n.position = pos
	n.npc_res = res_override
	add_child(n)
	
	# --- INICIO DE CÓDIGO NUEVO ---
	# Si es un aliado y el singleton existe, aplicamos bonificaciones
	if team == npc.Team.ALLY and has_node("/root/GlobalStats"):
		
		# Obtenemos las bonificaciones desde el singleton
		var health_bonus = GlobalStats.get_health_bonus()
		var damage_bonus = GlobalStats.get_damage_bonus()
		var speed_bonus = GlobalStats.get_speed_bonus()
		var crit_chance_bonus = GlobalStats.get_crit_chance_bonus()
		var crit_damage_bonus = GlobalStats.get_crit_damage_bonus()

		# Asumimos que 'npc.gd' tendrá una función para aplicar esto.
		# (Ver Paso 4 - Tendrás que crear esta función en 'npc.gd')
		if n.has_method("apply_passive_bonuses"):
			n.apply_passive_bonuses(
				health_bonus,
				damage_bonus,
				speed_bonus,
				crit_chance_bonus,
				crit_damage_bonus
			)
		else:
			push_warning("npc.gd no tiene el método 'apply_passive_bonuses'. No se aplicarán las pasivas.")
	# --- FIN DE CÓDIGO NUEVO ---
	
	# if is ENEMY (warrior), the gold pool is = to resource
	if team == npc.Team.ENEMY:
		n.gold_pool = int(n.npc_res.gold)
	
	# connect gold handling on death and slot freeing on exit
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

func spawn_piece(team: int, piece: PieceRes) -> void:
	if piece == null:
		return

	var pack: Dictionary = PieceAdapter.to_npc_res(piece)
	var npc_template: npcRes = pack["res"]
	var members: int = int(pack["members"])

	if team == npc.Team.ALLY:
		# Respeta el límite total de aliados
		var free_slots_limit := ALLY_LIMIT - ally_npcs.size()
		if free_slots_limit <= 0:
			print("ALLY_LIMIT alcanzado, no se spawnea nada.")
			return

		# Array de puntos libres
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

# Pay full remaining gold if the enemy (warrior) dies
func _on_npc_died(n: npc) -> void:
	if n.team == npc.Team.ENEMY:
		var amount: int = int(max(0, n.gold_pool))
		if amount > 0:
			PlayerData.add_currency(amount)
			print("Reward (death): +", amount, " gold (remaining pool paid).")
		n.gold_pool = 0

func _on_npc_exited(n: npc) -> void:
	if n.team == npc.Team.ALLY:
		ally_npcs.erase(n)
	else:
		enemy_npcs.erase(n)

	# Stop combat if one side is empty
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
	# Estado inicial de la ronda para el warrior (si existe)
	if enemy_npcs.size() > 0 and is_instance_valid(enemy_npcs[0]):
		var w: npc = enemy_npcs[0]
		enemy_hp_round_start = w.health
		enemy_gold_round_start = int(w.gold_pool)

	# One timer per ally hitting a random alive enemy
	for a in ally_npcs:
		if is_instance_valid(a):
			var t := _make_attack_timer(a, enemy_npcs)  # pass the list of enemies
			ally_timers.append(t)

	# One timer per enemy hitting a random alive ally
	for e in enemy_npcs:
		if is_instance_valid(e):
			var t := _make_attack_timer(e, ally_npcs)
			enemy_timers.append(t)

func _make_attack_timer(attacker: npc, defender: Variant) -> Timer:
	var t := Timer.new()
	t.one_shot = false

	# atack_speed = attacks per second
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
			# filters alive from the defending side
			var alive: Array = []
			for d in target:
				if is_instance_valid(d):
					alive.append(d)

			# If there are no living objectives on that side -> the combat is over
			if alive.is_empty():
				_stop_combat()
				return

			# Choose one alive objetive
			target = alive[randi() % alive.size()]

		# If the objetive is invalid ignore
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

# Pretty-print helper (2 decimals)
func _num(x: float, d: int = 2) -> String:
	return String.num(x, d)

# Team to string (for logs)
func _team_to_str(t: int) -> String:
	if t == npc.Team.ALLY:
		return "ALLY"
	else:
		return "ENEMY"

func _cleanup_allies_and_reset() -> void:
	# Clean allys form the tree
	for a in ally_npcs:
		if is_instance_valid(a):
			a.queue_free()
	ally_npcs.clear()
	
	print("Battle stopped")

func _do_attack(attacker: npc, defender: npc) -> void:
	if not attacker.can_damage(defender):
		return
	if attacker.npc_res == null:
		return

	attacker.notify_before_attack(defender)

	var base := attacker.get_damage(defender)
	var dmg := base

	# Crit
	var crit_chance := float(attacker.get_crit_chance(defender))
	var crit := randf() < (crit_chance / 100.0)
	var mult := attacker.get_crit_mult(defender) if crit else 1.0
	dmg *= mult

	var before_hp := defender.health
	# (opcional) guarda también nombre/HP máx para logs ANTES del daño
	var target_max_hp := defender.max_health
	var target_name := _who(defender)
	
	defender.take_damage(dmg, attacker)
	
	# tras el daño, puede haberse liberado:
	var after_hp := 0.0
	if is_instance_valid(defender):
		after_hp = defender.health
	
	attacker.notify_after_attack(defender, dmg, crit)
	
	# si ya no existe o quedó a 0 => cuenta kill
	if (not is_instance_valid(defender)) or after_hp <= 0.0:
		attacker.notify_kill(defender)
	
	# print seguro usando valores guardados
	var crit_text := " (no crit)"
	if crit:
		crit_text = " CRIT x" + _num(mult)

	print(
		"[HIT] ", _team_to_str(attacker.team), " -> ", _team_to_str(defender.team),
		" | base=", _num(base), crit_text,
		" | final=", _num(dmg),
		" | target HP ", _num(before_hp), " -> ", _num(after_hp), "/", _num(target_max_hp),
		" | target=", target_name
)

func _stop_combat() -> void:
	# if round ends because all allys dies and the warrior is alive,
	# player gain monney % to the damage deal in the round only if they loose 
	if enemy_npcs.size() > 0 and ally_npcs.is_empty():
		var w: npc = enemy_npcs[0]
		if is_instance_valid(w) and w.health > 0.0:
			var hp_lost: float = max(0.0, enemy_hp_round_start - w.health)
			var damage_frac: float = clamp(hp_lost / w.max_health, 0.0, 1.0)

			# base gold in this round = pool they have in the begin of the round
			var base_gold: int = enemy_gold_round_start
			var payout: int = int(floor(base_gold * damage_frac))

			# avoid paying more than what is left in the current pool
			payout = clamp(payout, 0, int(w.gold_pool))

			if payout > 0:
				PlayerData.add_currency(payout)
				w.gold_pool = int(w.gold_pool) - payout
				print("Round reward: +", payout, " gold (", int(damage_frac * 100), "% dmg this round). Remaining pool=", w.gold_pool)
	
	# Stop timers
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
	
	_advance_round()
	
	if (not enemy_alive) and allies_alive:
		# Victoriy goblings: show msg and clean 2.5s 
		var t := _show_round_message("Ronda terminada: ¡Victoria!")
		if t:
			t.timeout.connect(func ():
				_cleanup_allies_and_reset()
			)
		else:
			# Just in case if there is no label, we clean
			_cleanup_allies_and_reset()

	elif enemy_alive and (not allies_alive):
		# Gladiator is alive
		_cleanup_allies_and_reset()
		_show_round_message("Ronda terminada: El gladiador sobrevivió.")

	elif (not enemy_alive) and (not allies_alive):
		# Doble KO
		_cleanup_allies_and_reset()
		_show_round_message("Ronda terminada: doble KO.")
	else:
		# Impossible case but covered
		_cleanup_allies_and_reset()
		_show_round_message("Ronda terminada.")
	
	print("Battle stopped")

func _who(n: npc) -> String:
	if not is_instance_valid(n):
		return "[null]"
	var res_name := ""
	if n.npc_res and n.npc_res.resource_path != "":
		res_name = n.npc_res.resource_path.get_file().get_basename()
	else:
		res_name = "Unknown"

	return "%s (%s)" % [res_name, _team_to_str(n.team)]
	
func on_roulette_combat_requested(piece_resource: Resource) -> void:
	# Verificamos que sea un PieceRes
	if not piece_resource is PieceRes:
		push_error("on_roulette_combat_requested: El recurso recibido no es un 'PieceRes'.")
		return
		
	print("Señal de combate global recibida. Aliado: ", piece_resource.display_name)
	
	_cleanup_allies_and_reset()
	spawn_piece(npc.Team.ALLY, piece_resource)
	spawn_enemy_one()
	_start_pre_battle_sequence()

func _start_pre_battle_sequence() -> void:
	if ally_npcs.is_empty() or enemy_npcs.is_empty():
		return
		
	var t:= Timer.new()
	t.one_shot = true
	t.wait_time = 1.0
	add_child(t)
	t.timeout.connect(_advance_to_battle_and_start)
	t.start()
	
func _advance_to_battle_and_start() -> void:
	# Move gladiator
	if enemy_npcs.size() > 0 and is_instance_valid(enemy_npcs[0]):
		var g := enemy_npcs[0]
		_move_with_tween(g, enemy_battle_slot.position, 0.8)
	
	# Move allies 
	for a in ally_npcs:
		if is_instance_valid(a):
			var target := a.position +ALLY_BATTLE_OFSET
			_move_with_tween(a, target, 0.8)
	
	# When they finish they movement, battle starts
	if not combat_running:
		combat_running = true
		start_timer.start(0.8)

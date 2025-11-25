extends Node2D

# Señal que indica si el jugador ganó la ronda (mató al gladiador)
# Devuelve bool (victoria) y int (oro obtenido en la ronda)
signal combat_finished(player_won: bool, gold_looted: int)

const NPC_SCENE := preload("res://scenes/npc.tscn")
const PieceAdapter := preload("res://scripts/piece_adapter.gd")

@export_group("Configuración de Enemigos")
@export var enemy_res: Array[npcRes] = []
const ALLY_LIMIT := 14
const ENEMY_LIMIT := 1

var round_gold_loot: int = 0
# Animacion de golpear 
@export_group("Animación de Ataque")
@export_subgroup("Aliados (PieceRes)")
@export var ally_attack_offset: Vector2 = Vector2(-125, -35) # Movimiento izquierda + salto
@export var ally_attack_rotation_deg: float = -8.0          # Gira hacia la izquierda/abajo

@export_subgroup("Gladiador (npcRes)")
@export var enemy_attack_offset: Vector2 = Vector2(25, 10)  # Derecha + un pelín hacia abajo
@export var enemy_attack_rotation_deg: float = 8.0          # Gira hacia la derecha/abajo

@export_subgroup("Tiempos")
@export var attack_lunge_duration: float = 0.08             # Ida
@export var attack_return_duration: float = 0.12            # Vuelta

# Variables de Escalado Diario (Scaling)
@export_group("Escalado de Dificultad (Por Día)")
@export_subgroup("Crecimiento Exponencial")
@export var scaling_hp_mult: float = 1.4      
@export var scaling_damage_mult: float = 1.2 

@export_subgroup("Crecimiento Lineal (Plano)")
@export var scaling_speed_flat: float = 0.1   
@export var scaling_crit_chance_flat: float = 5.0
@export var scaling_crit_dmg_flat: float = 0.05   

@onready var enemy_spawn: Marker2D = $GladiatorSpawn
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
var pre_battle_wait_time: float = 1.0
var ally_spawn_order_counter: int = 0

var combat_running := false
var start_timer: Timer
var ally_timers: Array[Timer] = []
var enemy_timers: Array[Timer] = []
var enemy_hp_round_start: float = 0.0
var enemy_gold_round_start: int = 0
var round_number := 0

func _ready() -> void:
	randomize()
	if GlobalSignals:
		GlobalSignals.combat_requested.connect(on_roulette_combat_requested)

	start_timer = Timer.new()
	start_timer.one_shot = true
	add_child(start_timer)
	start_timer.timeout.connect(_begin_combat)
	
	spawn_enemy_one()

func _advance_round() -> void:
	pass

func on_roulette_combat_requested(piece_resource: Resource) -> void:
	# --- CASO 1: Giro en VACÍO ---
	if not piece_resource or not piece_resource is PieceRes:
		push_error("on_roulette_combat_requested: Recurso nulo o inválido. Saltando combate.")
		_cleanup_allies_and_reset()
		
		if enemy_npcs.size() > 0 and is_instance_valid(enemy_npcs[0]):
			var g := enemy_npcs[0]
			if g.position == enemy_battle_slot.position:
				_move_with_tween(g, enemy_wait_slot.position, 0.5)
		
		return
		
	print("Señal de combate global recibida. Aliado: ", piece_resource.display_name)
	
	# Combate Normal
	_cleanup_allies_and_reset()
	spawn_piece(npc.Team.ALLY, piece_resource)
	
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
		if enemy_npcs.size() > 0 and is_instance_valid(enemy_npcs[0]):
			var g := enemy_npcs[0]
			if g.position != enemy_wait_slot.position:
				_move_with_tween(g, enemy_wait_slot.position, 0.5)

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

				round_gold_loot += payout # NUEVO: Registramos el pago parcial
				print("Round reward (partial): +", payout)
	
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

	# Comprobar quién sigue vivo
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

	var player_won_round = not enemy_alive
	
	# Resultado de la ronda
	# Si el gladiador sobrevive, lo mandamos al slot de espera
	if not player_won_round:
		if enemy_npcs.size() > 0 and is_instance_valid(enemy_npcs[0]):
			_move_with_tween(enemy_npcs[0], enemy_wait_slot.position, 0.5)

	# MODIFICADO: Esperamos un poco y enviamos la señal directamente sin _show_round_message
	await get_tree().create_timer(1.0).timeout
	
	_cleanup_allies_and_reset()
	combat_finished.emit(player_won_round, round_gold_loot)
		
	print("Battle stopped. Player won: ", player_won_round, " Loot: ", round_gold_loot)

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
	
	if n is AnimatedSprite2D:
		if team == npc.Team.ALLY:
			n.flip_h = true
		else:
			n.flip_h = false
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
			
	# APLICAR SINERGIAS DE RULETA 
	if team == npc.Team.ALLY:
		# Buscamos al GameManager para pedir las sinergias
		var game_manager = get_parent() # Asumiendo que CombatScene es hijo de Game
		if game_manager and game_manager.has_method("get_active_synergies"):
			var active_synergies = game_manager.get_active_synergies()
			
			if n.has_method("apply_synergies"):
				n.apply_synergies(active_synergies)
			else:
				push_warning("NPC no tiene metodo apply_synergies")
	
	get_node("npcs").add_child(n)


	# APLICAR BONUS A ENEMIGOS (Scaling Diario)
	if team == npc.Team.ENEMY:
		n.gold_pool = int(n.npc_res.gold)
		_apply_enemy_daily_scaling(n)
	
	n.died.connect(_on_npc_died)
	n.tree_exited.connect(_on_npc_exited.bind(n))
	return n

# Cálculos de Escalado
func _apply_enemy_daily_scaling(n: npc) -> void:
	# Intentamos obtener el día actual del GameManager (Padre)
	var gm = get_parent()
	if not gm or not "current_day" in gm:
		return
	
	# El día 1 es índice 0 (sin bonus). Día 2 es índice 1, etc.
	var day_index = max(0, gm.current_day - 1)
	
	if day_index == 0:
		return # No hay escalado en el día 1
		
	# CÁLCULO DE MULTIPLICADORES Y SUMAS
	# Exponencial: Base * (Multiplicador ^ Dias)
	var total_hp_mult = pow(scaling_hp_mult, day_index)
	var total_dmg_mult = pow(scaling_damage_mult, day_index)
	
	# Lineal: Base + (Incremento * Dias)
	var added_speed = scaling_speed_flat * day_index
	var added_crit_chance = scaling_crit_chance_flat * day_index
	var added_crit_dmg = scaling_crit_dmg_flat * day_index
	
	# Convertimos el multiplicador a porcentaje de bonus (ej. 1.4 -> +40%)
	var bonus_hp_percent = (total_hp_mult - 1.0) * 100.0
	var bonus_dmg_percent = (total_dmg_mult - 1.0) * 100.0
	
	if n.has_method("apply_passive_bonuses"):
		n.apply_passive_bonuses(
			bonus_hp_percent,
			bonus_dmg_percent,
			added_speed,
			added_crit_chance,
			added_crit_dmg
		)
		# Actualizamos la vida actual al nuevo máximo
		n.health = n.max_health
		
		print("Enemy Scaled (Day %d): HP +%d%%, DMG +%d%%, SPD +%.2f" % [gm.current_day, int(bonus_hp_percent), int(bonus_dmg_percent), added_speed])
	else:
		# Fallback por si no tiene el método (modificamos HP manualmente al menos)
		n.max_health *= total_hp_mult
		n.health = n.max_health

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
		print(_get_piece_copies_owned(piece))

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
		var delay_per_ally := 0.10
		var move_segment_time := 0.4
		var total_move_time := move_segment_time * 2.0

		for i in range(to_spawn):
			var idx: int = randi() % free_markers.size()
			var slot: Marker2D = free_markers[idx]
			free_markers.remove_at(idx)

			var n: npc = _spawn_npc(team, ally_entry_spawn.position, npc_template)
			if n:
				ally_npcs.append(n)

				# USAMOS EL CONTADOR GLOBAL
				var order_index := ally_spawn_order_counter
				ally_spawn_order_counter += 1

				_place_ally_in_slot_with_tween(n, slot.position, order_index)

		if ally_spawn_order_counter > 0:
			# El último que saldrá tiene índice ally_spawn_order_counter - 1
			var last_index := ally_spawn_order_counter - 1
			pre_battle_wait_time = last_index * delay_per_ally + total_move_time + 0.2
		else:
			pre_battle_wait_time = 0.5

		return

	# Enemigos:
	var e := _spawn_npc(team, enemy_spawn.position, npc_template)
	if e:
		enemy_npcs.append(e)

func _place_ally_in_slot_with_tween(n: npc, final_pos: Vector2, order_index: int) -> void:
	n.position = ally_entry_spawn.position

	var delay_per_ally := 0.10

	var mid_pos := Vector2(final_pos.x, ally_entry_spawn.position.y)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.tween_interval(order_index * delay_per_ally)

	tween.tween_property(n, "position", mid_pos, 0.5)
	tween.tween_property(n, "position", final_pos, 0.5)

func _on_npc_died(n: npc) -> void:
	if n.team == npc.Team.ENEMY:
		var amount: int = int(max(0, n.gold_pool))
		if amount > 0:
			PlayerData.add_currency(amount)
			round_gold_loot += amount # NUEVO: Sumamos al acumulador local
			print("Reward (death): +", amount, " gold.")
		n.gold_pool = 0
		print("¡Gladiador murió!")

func _on_npc_exited(n: npc) -> void:
	if n.team == npc.Team.ALLY:
		ally_npcs.erase(n)
	else:
		enemy_npcs.erase(n)
	if combat_running and ( ally_npcs.is_empty() or enemy_npcs.is_empty() ):
		_stop_combat()

func _on_start_pressed() -> void:
	if combat_running: return
	if ally_npcs.is_empty() or enemy_npcs.is_empty(): return
	combat_running = true
	print("Battle starts in 3 seconds")
	start_timer.start(3.0)

func _begin_combat() -> void:
	print("Battle begins")
	round_gold_loot = 0 # NUEVO: Reiniciamos el loot al comenzar ronda
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

func _num(x: float, d: int = 2) -> String:
	return String.num(x, d)

func _team_to_str(t: int) -> String:
	return "ALLY" if t == npc.Team.ALLY else "ENEMY"

func _cleanup_allies_and_reset() -> void:
	for a in ally_npcs:
		if is_instance_valid(a):
			a.queue_free()
	ally_npcs.clear()
	ally_spawn_order_counter = 0

func _play_attack_anim(attacker: npc) -> void:
	if not is_instance_valid(attacker):
		return

	var original_pos: Vector2 = attacker.position
	var original_rot_deg: float = attacker.rotation_degrees

	# Limpiar tween anterior si existe
	if attacker.has_meta("attack_tween"):
		var old_tween: Tween = attacker.get_meta("attack_tween")
		if is_instance_valid(old_tween):
			old_tween.kill()

	var tween := create_tween()
	attacker.set_meta("attack_tween", tween)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	#   ANIMACIÓN ALIADOS
	if attacker.team == npc.Team.ALLY:
		# POSICIÓN EN EL "AIRE"
		var jump_pos := original_pos + ally_attack_offset
		var target_rot_deg := original_rot_deg + ally_attack_rotation_deg

		# Salto hacia la izquierda
		tween.tween_property(attacker, "position", jump_pos, attack_lunge_duration)

		# En el aire, girar hasta la rotación de golpe
		tween.chain().tween_property(attacker, "rotation_degrees", target_rot_deg, attack_lunge_duration)

		# Siguen en el aire, volver a la rotación normal
		tween.chain().tween_property(attacker, "rotation_degrees", original_rot_deg, attack_lunge_duration)

		# Caer de vuelta a su posición original
		tween.chain().tween_property(attacker, "position", original_pos, attack_return_duration)

		return
	#ANIMACIÓN GLADIADORES
	var offset := enemy_attack_offset
	var target_rot_deg := original_rot_deg + enemy_attack_rotation_deg
	var forward_pos := original_pos + offset

	# 1) Empuje hacia delante + giro
	tween.tween_property(attacker, "position", forward_pos, attack_lunge_duration)
	tween.parallel().tween_property(attacker, "rotation_degrees", target_rot_deg, attack_lunge_duration)

	# 2) Volver a sitio y rotación original
	tween.chain().tween_property(attacker, "position", original_pos, attack_return_duration)
	tween.parallel().tween_property(attacker, "rotation_degrees", original_rot_deg, attack_return_duration)

func _do_attack(attacker: npc, defender: npc) -> void:
	if not attacker.can_damage(defender): return
	if attacker.npc_res == null: return
	
	# Mostrar animacion
	_play_attack_anim(attacker)
	
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
	
	# SOLO UNA LLAMADA A TAKE_DAMAGE (Aquí estaba el bug que lo llamaba dos veces)
	defender.take_damage(dmg, attacker, crit)

	var after_hp := 0.0
	if is_instance_valid(defender):
		after_hp = defender.health
	
	attacker.notify_after_attack(defender, dmg, crit)
	
	if (not is_instance_valid(defender)) or after_hp <= 0.0:
		attacker.notify_kill(defender)
	
	var crit_text := " (no crit)"
	if crit: crit_text = " CRIT x" + _num(mult)
	print("[HIT] ", _team_to_str(attacker.team), " -> ", _team_to_str(defender.team), " | final=", _num(dmg), crit_text)

func _who(n: npc) -> String:
	if not is_instance_valid(n): return "[null]"
	var res_name := "Unknown"
	if n.npc_res and n.npc_res.resource_path != "":
		res_name = n.npc_res.resource_path.get_file().get_basename()
	return "%s (%s)" % [res_name, _team_to_str(n.team)]
	
func _start_pre_battle_sequence() -> void:
	if ally_npcs.is_empty():
		_stop_combat()
		return
	
	if enemy_npcs.is_empty():
		await get_tree().create_timer(0.1).timeout
		if enemy_npcs.is_empty():
			spawn_enemy_one()
			await get_tree().create_timer(0.1).timeout 
		
		if enemy_npcs.is_empty():
			_stop_combat()
			return

	var t:= Timer.new()
	t.one_shot = true
	t.wait_time = pre_battle_wait_time
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

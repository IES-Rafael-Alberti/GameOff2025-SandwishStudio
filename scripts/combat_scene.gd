extends Node2D

const NPC_SCENE := preload("res://scenes/npc.tscn")

# Allies pool: only warriors
const RES_LIST := [
	preload("res://resourses/warrior/black_warrior.tres"),
	preload("res://resourses/warrior/blue_warrior.tres"),
	preload("res://resourses/warrior/red_warrior.tres"),
	preload("res://resourses/warrior/yellow_warrior.tres")
]

# Enemy pool: always red goblin
const ENEMY_RES := preload("res://resourses/gobling/red_gobling.tres")

const ENEMY_LIMIT := 1  # max enemies on field 
# Ally limit is implicitly the number of AllySpawn markers (6)

@onready var enemy_spawn: Marker2D = $EnemySpawn
@onready var btn_start: Button = $BtnStart
@onready var btn_enemy: Button = $BtnEnemy
@onready var btn_ally: Button = $BtnAlly
@onready var inventory = get_node("/root/game/inventory")

# Ally spawn points (6)
@onready var ally_spawns: Array[Marker2D] = [
	$AllySpawn1, $AllySpawn2, $AllySpawn3,
	$AllySpawn4, $AllySpawn5, $AllySpawn6
]

var ally_npcs: Array[npc] = []    # active allies
var enemy_npcs: Array[npc] = []   # active enemies

var combat_running := false
var start_timer: Timer
var ally_timers: Array[Timer] = []
var enemy_timers: Array[Timer] = []

func _ready() -> void:
	randomize()

	btn_ally.pressed.connect(spawn_allies_from_inventory)
	btn_enemy.pressed.connect(spawn_enemy_one)
	btn_start.pressed.connect(_on_start_pressed)

	start_timer = Timer.new()
	start_timer.one_shot = true
	add_child(start_timer)
	start_timer.timeout.connect(_begin_combat)

	_update_start_btn_state()


# Spawn allies using the inventory, up to available AllySpawn markers
func spawn_allies_from_inventory() -> void:
	if ally_npcs.size() > 0:
		print("Allies already present.")
		return

	if not is_instance_valid(inventory):
		push_error("Inventory node not found at /root/game/inventory")
		return

	# Try to read a Dictionary with piece counts
	var piece_counts_dict: Dictionary = {}
	if "piece_counts" in inventory:
		piece_counts_dict = inventory.piece_counts
	elif inventory.has_method("get_piece_counts"):
		piece_counts_dict = inventory.get_piece_counts()
	else:
		push_error("Inventory does not expose 'piece_counts' or 'get_piece_counts()'.")
		return

	# Sum total pieces
	var total_pieces := 0
	for key in piece_counts_dict.keys():
		var entry = piece_counts_dict[key]
		if typeof(entry) == TYPE_DICTIONARY and entry.has("count"):
			total_pieces += int(entry["count"])
		elif typeof(entry) == TYPE_INT:
			total_pieces += entry

	if total_pieces <= 0:
		print("No troops in inventory.")
		return

	var max_allies: int = min(total_pieces, ally_spawns.size())
	print("Spawning %d allies from inventory (total=%d)" % [max_allies, total_pieces])

	for i in range(max_allies):
		var m: Marker2D = ally_spawns[i]
		if m:
			var a := _spawn_npc(npc.Team.ALLY, m.position)  # uses warrior pool
			if a:
				ally_npcs.append(a)

	# Disable button if we filled all ally slots
	btn_ally.disabled = ally_npcs.size() >= ally_spawns.size()
	_update_start_btn_state()

# Spawn 1 enemy.
func spawn_enemy_one() -> void:
	if enemy_npcs.size() >= ENEMY_LIMIT:
		print("Enemy limit reached (%d)." % ENEMY_LIMIT)
		return

	var positions := _enemy_positions(enemy_spawn.position)
	var idx := enemy_npcs.size()
	var pos := positions[idx]
	var e := _spawn_npc(npc.Team.ENEMY, pos, ENEMY_RES)
	if e:
		enemy_npcs.append(e)

	# Disable button when at limit
	btn_enemy.disabled = enemy_npcs.size() >= ENEMY_LIMIT
	_update_start_btn_state()

# Simple helper to arrange up to 3 enemies around the spawn point
func _enemy_positions(origin: Vector2) -> Array[Vector2]:
	return [
		origin,
		origin + Vector2( 60, -24),
		origin + Vector2( 60,  24),
	]

# Optional resource override lets us force a specific npcRes (used for enemies)
func _spawn_npc(team: int, pos: Vector2, res_override: npcRes = null) -> npc:
	var n: npc = NPC_SCENE.instantiate()
	n.team = team
	n.position = pos

	# Allies → random warrior from RES_LIST. Enemies → ENEMY_RES override.
	if res_override != null:
		n.npc_res = res_override
	else:
		n.npc_res = RES_LIST[randi() % RES_LIST.size()]

	add_child(n)

	n.tree_exited.connect(func ():
		if team == npc.Team.ALLY:
			ally_npcs.erase(n)
			# Re-enable ally button if we now have free slots
			btn_ally.disabled = ally_npcs.size() >= ally_spawns.size()
		else:
			enemy_npcs.erase(n)
			# Re-enable enemy button if below limit
			btn_enemy.disabled = enemy_npcs.size() >= ENEMY_LIMIT

		# Stop combat if one side is empty
		if combat_running and (ally_npcs.is_empty() or enemy_npcs.is_empty()):
			_stop_combat()
		_update_start_btn_state()
	)
	return n

func _on_start_pressed() -> void:
	if combat_running:
		return
	if ally_npcs.is_empty() or enemy_npcs.is_empty():
		print("You need allies and enemies to start.")
		return

	combat_running = true
	btn_start.disabled = true
	btn_ally.disabled = true
	btn_enemy.disabled = true

	print("Battle starts in 3 seconds")
	start_timer.start(3.0)

func _begin_combat() -> void:
	print("Battle begins")

	# One timer per ally hitting a random alive enemy
	for a in ally_npcs:
		if is_instance_valid(a):
			var t := _make_attack_timer(a, enemy_npcs)  # pass the list of enemies
			ally_timers.append(t)

	# One timer per enemy hitting a random alive ally
	for e in enemy_npcs:
		if is_instance_valid(e):
			var t := _make_attack_timer(e, ally_npcs)   # pass the list of allies
			enemy_timers.append(t)

# 'defender' can be an npc or an Array[npc]
func _make_attack_timer(attacker: npc, defender: Variant) -> Timer:
	var t := Timer.new()
	t.one_shot = false

	# atack_speed = attacks per second
	var aps := 1.0
	if is_instance_valid(attacker) and attacker.npc_res:
		aps = max(0.01, attacker.npc_res.atack_speed)
	t.wait_time = 1.0 / aps
	add_child(t)

	t.timeout.connect(func () -> void:
		if not is_instance_valid(attacker):
			_stop_combat()
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
			_stop_combat()
			return

		_do_attack(attacker, target)
	)
	t.start()
	return t

# Pretty-print helper (2 decimals)
func _num(x: float, d: int = 2) -> String:
	return String.num(x, d)

# Team to string (for logs)
func _team_to_str(t: int) -> String:
	if t == npc.Team.ALLY:
		return "ALLY"
	else:
		return "ENEMY"

func _do_attack(attacker: npc, defender: npc) -> void:
	if not attacker.can_damage(defender):
		return
	var res := attacker.npc_res
	if res == null:
		return

	# Gather base data
	var base: float = res.damage
	var dmg: float = base
	var before_hp: float = defender.health

	# Crit check
	var crit := randf() < float(res.critical_chance) / 100.0
	var mult := 1.0
	if crit:
		mult = res.critical_damage if res.critical_damage > 0.0 else 1.25
		dmg *= mult

	# Apply damage
	defender.take_damage(dmg)
	var after_hp: float = defender.health

	# Build log text
	var crit_text := " (no crit)"
	if crit:
		crit_text = " CRIT x" + _num(mult)

	print(
		"[HIT] ", _team_to_str(attacker.team), " -> ", _team_to_str(defender.team),
		" | base=", _num(base), crit_text,
		" | final=", _num(dmg),
		" | target HP ", _num(before_hp), " -> ", _num(after_hp), "/", _num(defender.max_health)
	)
	
func _stop_combat() -> void:
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

	combat_running = false

	# Re-enable spawn buttons if there is room
	btn_ally.disabled = ally_npcs.size() >= ally_spawns.size()
	btn_enemy.disabled = enemy_npcs.size() >= ENEMY_LIMIT

	_update_start_btn_state()
	print("Battle stopped")

func _update_start_btn_state() -> void:
	# Start is enabled only when we have at least 1 ally and 1 enemy and no battle is running
	btn_start.disabled = combat_running or ally_npcs.is_empty() or enemy_npcs.is_empty()

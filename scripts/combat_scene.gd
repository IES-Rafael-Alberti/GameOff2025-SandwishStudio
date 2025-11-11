extends Node2D

const NPC_SCENE := preload("res://scenes/npc.tscn")

# Allies pool: only goblings
const RES_LIST := [
	preload("res://resources/gobling/blue_gobling.tres"),
	preload("res://resources/gobling/red_gobling.tres"),
	preload("res://resources/gobling/yellow_gobling.tres"),
	preload("res://resources/gobling/purple_gobling.tres")
]

# Enemy pool: only warriors
const ENEMY_RES := [
	preload("res://resources/warrior/black_warrior.tres"),
	preload("res://resources/warrior/blue_warrior.tres"),
	preload("res://resources/warrior/red_warrior.tres"),
	preload("res://resources/warrior/yellow_warrior.tres")
]

const ENEMY_LIMIT := 1  # max enemies on field (1 warrior)
# Ally limit is implicitly the number of AllySpawn markers (6)

@onready var enemy_spawn: Marker2D = $BeastSpawn
@onready var btn_start: Button = $BtnStart
@onready var btn_enemy: Button = $BtnEnemy
@onready var btn_ally: Button = $BtnAlly
@onready var round_message: Label = $RoundMessage
@onready var inventory = get_node("/root/game/inventory")

# Log 
@onready var panel_container: PanelContainer = $PanelContainer
@onready var box_container: VBoxContainer = $PanelContainer/BoxContainer
@onready var h_box_container: HBoxContainer = $PanelContainer/BoxContainer/HBoxContainer
@onready var label: Label = $PanelContainer/BoxContainer/HBoxContainer/Label
@onready var scroll_container: ScrollContainer = $PanelContainer/BoxContainer/ScrollContainer
@onready var rich_text_label: RichTextLabel = $PanelContainer/BoxContainer/ScrollContainer/RichTextLabel
@onready var btn_clear_log: Button = $PanelContainer/BoxContainer/HBoxContainer.get_node_or_null("BtnClearLog") as Button

const MAX_LOG_LINES := 200 

# Ally spawn points (6)
@onready var ally_spawns: Array[Marker2D] = [
	$WarriorSpawn1, $WarriorSpawn2, $WarriorSpawn3,
	$WarriorSpawn4, $WarriorSpawn5, $WarriorSpawn6
]

var ally_npcs: Array[npc] = []    # active allies (goblins)
var enemy_npcs: Array[npc] = []   # active enemies (1 warrior)

var combat_running := false
var start_timer: Timer
var ally_timers: Array[Timer] = []
var enemy_timers: Array[Timer] = []
var enemy_hp_round_start: float = 0.0
var enemy_gold_round_start: int = 0


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
	# --- Log setup ---
	if rich_text_label:
		# No dependemos de BBCode; autowrap para que el texto no se salga.
		rich_text_label.bbcode_enabled = false
		rich_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		rich_text_label.fit_content = true
		rich_text_label.text = ""
		# Smoke test: si esto no se ve, el problema es de layout/visibilidad.
		rich_text_label.append_text("⟶ Log inicial OK\n")

	if btn_clear_log:
		btn_clear_log.pressed.connect(_clear_log)

	# Mensaje de bienvenida
	_log_line("Battle log ready", Color.DIM_GRAY)


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

	# up to 6 goblins, limited by inventory and spawn points
	var max_allies: int = min(total_pieces, ally_spawns.size())
	print("Spawning %d allies from inventory (total=%d)" % [max_allies, total_pieces])

	for i in range(max_allies):
		var m: Marker2D = ally_spawns[i]
		if not m:
			continue
		var gob_res: npcRes = RES_LIST[randi() % RES_LIST.size()]
		var a := _spawn_npc(npc.Team.ALLY, m.position, gob_res)
		if a:
			ally_npcs.append(a)
			_log_line("ALLY spawned at %s -> %s" % [m.name, _who(a)], Color.SEA_GREEN)

	# Disable button if we filled all ally slots
	btn_ally.disabled = ally_npcs.size() >= ally_spawns.size()
	_update_start_btn_state()

# Spawn 1 enemy.
func spawn_enemy_one() -> void:
	if enemy_npcs.size() >= ENEMY_LIMIT:
		print("Enemy limit reached (%d)." % ENEMY_LIMIT)
		return

	# single warrior at BeastSpawn
	var pos := enemy_spawn.position
	var war_res: npcRes = ENEMY_RES[randi() % ENEMY_RES.size()]
	var e := _spawn_npc(npc.Team.ENEMY, pos, war_res)
	if e:
		enemy_npcs.append(e)
		print("Enemy spawned at BeastSpawn -> %s" % war_res.resource_path.get_file().get_basename())
		_log_line("ENEMY spawned at BeastSpawn -> %s" % _who(e), Color.SALMON)

	# Disable button when at limit
	btn_enemy.disabled = enemy_npcs.size() >= ENEMY_LIMIT
	_update_start_btn_state()

# Optional resource override lets us force a specific npcRes (used here for both sides)
func _spawn_npc(team: int, pos: Vector2, res_override: npcRes = null) -> npc:
	var n: npc = NPC_SCENE.instantiate()
	n.team = team
	n.position = pos
	if res_override != null:
		n.npc_res = res_override
	else:
		# fallback: allies use goblin pool by default
		n.npc_res = RES_LIST[randi() % RES_LIST.size()]
	add_child(n)
	
	# if is ENEMY (warrior), the gold pool is = to resource
	if team == npc.Team.ENEMY:
		n.gold_pool = int(n.npc_res.gold)

	# connect gold handling on death and slot freeing on exit
	n.died.connect(_on_npc_died)
	n.tree_exited.connect(_on_npc_exited.bind(n))
	return n

# Pay full remaining gold if the enemy (warrior) dies
func _on_npc_died(n: npc) -> void:
	_log_line("%s died -> %s" % [("ENEMY" if n.team == npc.Team.ENEMY else "ALLY"), _who(n)], Color.ORANGE_RED)
	if n.team == npc.Team.ENEMY:
		var amount: int = int(max(0, n.gold_pool))
		if amount > 0:
			PlayerData.add_currency(amount)
			print("Reward (death): +", amount, " gold (remaining pool paid).")
			_log_line("Reward (death): +%d gold (remaining pool paid)." % amount, Color.GOLD)
		n.gold_pool = 0

func _on_npc_exited(n: npc) -> void:
	if n.team == npc.Team.ALLY:
		ally_npcs.erase(n)
		# Re-enable ally button if we now have free slots
		btn_ally.disabled = ally_npcs.size() >= ally_spawns.size()
	else:
		enemy_npcs.erase(n)
		# Re-enable enemy button if below limit
		btn_enemy.disabled = enemy_npcs.size() >= ENEMY_LIMIT

	# Stop combat if one side is empty
	if combat_running and ( ally_npcs.is_empty() or enemy_npcs.is_empty() ):
		_stop_combat()
	_update_start_btn_state()

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
	_log_line("[b]Battle starts in 3 seconds[/b]", Color.DODGER_BLUE)
	start_timer.start(3.0)

func _begin_combat() -> void:
	print("Battle begins")
	_log_line("[b]Battle begins[/b]", Color.DODGER_BLUE)
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
	if is_instance_valid(attacker) and attacker.npc_res:
		aps = max(0.01, attacker.npc_res.atack_speed)
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

func _show_round_message() -> void:
	if round_message:
		round_message.text = "¡Ronda superada!"
		round_message.visible = true
		
		var msg_timer := Timer.new()
		msg_timer.one_shot = true
		msg_timer.wait_time = 2.5
		add_child(msg_timer)
		msg_timer.timeout.connect(func ():
			if is_instance_valid(round_message):
				round_message.visible = false
			msg_timer.queue_free()
		)
		msg_timer.start()

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

	# Además, escribirlo en el panel de log
	_log_hit(attacker, defender, base, dmg, crit, before_hp, after_hp)

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
				_log_line("Round reward: +%d gold (%d%% dmg this round). Remaining pool=%d"
					% [payout, int(damage_frac * 100), w.gold_pool], Color.GOLD)
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
	# Clean the wave
	for a in ally_npcs:
		if is_instance_valid(a):
			a.queue_free()
	# Clean array before tree_exited
	ally_npcs.clear()
	
	# Re-enable spawn buttons if there is room
	btn_ally.disabled = ally_npcs.size() >= ally_spawns.size()
	btn_enemy.disabled = enemy_npcs.size() >= ENEMY_LIMIT

	_update_start_btn_state()
	print("Battle stopped")
	_log_line("[b]Battle stopped[/b]", Color.DIM_GRAY)
		# msg -> Round complete
	if enemy_npcs.size() > 0 and ally_npcs.is_empty():
		_show_round_message()


func _update_start_btn_state() -> void:
	# Start is enabled only when we have at least 1 ally and 1 enemy and no battle is running
	btn_start.disabled = combat_running or ally_npcs.is_empty() or enemy_npcs.is_empty()

func _color_to_hex(c: Color) -> String:
	return "#%02x%02x%02x" % [int(c.r * 255.0), int(c.g * 255.0), int(c.b * 255.0)]

func _log_line(text: String, color: Color = Color.WHITE) -> void:
	if not is_instance_valid(rich_text_label):
		print(text)
		return

	# --- recorte si hay demasiadas líneas ---
	var lines: PackedStringArray = rich_text_label.text.split("\n")
	if lines.size() > MAX_LOG_LINES:
		var keep_from: int = int(MAX_LOG_LINES * 0.6)  # conserva ~60%
		var start: int = max(0, lines.size() - keep_from)
		var trimmed: PackedStringArray = lines.slice(start)
		rich_text_label.text = "\n".join(trimmed)

	# escribir línea nueva (sin BBCode para evitar más variables)
	rich_text_label.push_color(color)
	rich_text_label.append_text(text + "\n")
	rich_text_label.pop()

	# autoscroll al final (seguro aunque la escena esté saliendo del árbol)
	var tree := get_tree()
	if tree != null:
		await tree.process_frame

	if is_instance_valid(scroll_container):
		var sb := scroll_container.get_v_scroll_bar()
		if sb != null:
			sb.value = sb.max_value


func _who(n: npc) -> String:
	return n.npc_res.resource_path.get_file().get_basename() if (n and n.npc_res) else "???"

func _log_hit(attacker: npc, defender: npc, base: float, final_dmg: float, crit: bool, before_hp: float, after_hp: float) -> void:
	var side_a := ("ALLY" if attacker.team == npc.Team.ALLY else "ENEMY")
	var side_d := ("ALLY" if defender.team == npc.Team.ALLY else "ENEMY")
	var crit_txt := " [b]CRIT[/b]" if crit else ""
	var txt := "%s(%s) -> %s(%s) | base=%.2f%s | final=%.2f | %s HP %.2f -> %.2f / %.2f" % [
		side_a, _who(attacker),
		side_d, _who(defender),
		base, crit_txt, final_dmg,
		side_d, before_hp, after_hp, defender.max_health
	]
	_log_line(txt, Color.YELLOW if crit else Color.WHITE)

func _clear_log() -> void:
	if rich_text_label:
		rich_text_label.text = ""

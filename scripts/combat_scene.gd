extends Node2D

const NPC_SCENE := preload("res://scenes/npc.tscn")
const RES_LIST := [
	preload("res://resourses/warrior/black_warrior.tres"),
	preload("res://resourses/warrior/blue_warrior.tres"),
	preload("res://resourses/warrior/red_warrior.tres"),
	preload("res://resourses/warrior/yellow_warrior.tres")
]

@onready var camera_2d: Camera2D = $Camera2D
@onready var btn_ally: Button = $UI/Control/BoxContainer/BtnAlly
@onready var btn_enemy: Button = $UI/Control/BoxContainer/BtnEnemy
@onready var btn_start: Button = $UI/Control/BoxContainer/BtnStart

var ally_npc: npc = null
var enemy_npc: npc = null

var combat_running := false
var start_timer: Timer
var ally_timer: Timer
var enemy_timer: Timer

func _ready() -> void:
	randomize()
	btn_ally.pressed.connect(spawn_ally)
	btn_enemy.pressed.connect(spawn_enemy)
	btn_start.pressed.connect(_on_start_pressed)
	
	# Timer 3 seconds
	start_timer = Timer.new()
	start_timer.one_shot = true
	add_child(start_timer)
	start_timer.timeout.connect(_begin_combat)
	
	_update_start_btn_state()

func spawn_ally() -> void:
	if is_instance_valid(ally_npc):
		print("Ya hay un aliado")
		return
	# Position of the ally in the left
	var pos := camera_2d.global_position + Vector2(-200, 0)
	ally_npc = _spawn_npc(npc.Team.ALLY, pos)
	btn_ally.disabled = true
	_update_start_btn_state()

func spawn_enemy() -> void:
	if is_instance_valid(enemy_npc):
		print("Ya hay un enemigo")
		return
	# Position of the enemy in the right
	var pos := camera_2d.global_position + Vector2(200, 0)
	enemy_npc = _spawn_npc(npc.Team.ENEMY, pos)
	btn_enemy.disabled =true
	_update_start_btn_state()

func _spawn_npc(team: int, pos: Vector2) -> npc:
	var n: npc = NPC_SCENE.instantiate()
	n.team = team
	n.position = pos
	# Put a random warrior for now
	n.npc_res = RES_LIST[randi()% RES_LIST.size()]
	add_child(n)
	
	n.tree_exited.connect(func ():
		if team == npc.Team.ALLY:
			ally_npc = null
			btn_ally.disabled = false
		else:
			enemy_npc = null
			btn_enemy.disabled = false
		if combat_running:
			_stop_combat()
		_update_start_btn_state()
	)
	return n

func _on_start_pressed() -> void:
	if combat_running:
		return
	if not is_instance_valid(ally_npc) or not is_instance_valid(enemy_npc):
		print("Necesitas un alidado y un enmigo para comenzar")
		return
	combat_running = true
	btn_start.disabled = true
	# In the battle you cant generate new warriors
	btn_ally.disabled = true
	btn_enemy.disabled = true
	print("Comienza en 3 segundos")
	start_timer.start(3.0)
	
func _begin_combat() -> void:
	print("Comienza el combate")
	# Timer for atack speed
	ally_timer = _make_attack_timer(ally_npc, enemy_npc)
	enemy_timer = _make_attack_timer(enemy_npc, ally_npc)

func _make_attack_timer(attacker: npc, defender: npc) -> Timer:
	var t:= Timer.new()
	t.one_shot = false
	# aps = atacks per seconds
	var aps = 1.0
	if is_instance_valid(attacker) and attacker.npc_res:
		aps = max(0.01,attacker.npc_res.atack_speed)
	t.wait_time = 1.0 / aps
	add_child(t)
	
	t.timeout.connect( func ():
		if not is_instance_valid(attacker) or not is_instance_valid(defender):
			_stop_combat()
			return
		_do_attack(attacker, defender)
	)
	t.start()
	return t

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
	# If defender die, him timer gets off 

func _stop_combat() -> void:
	# Finish the combat and delete atack timers
	if is_instance_valid(ally_timer):
		ally_timer.stop()
		ally_timer.queue_free()
	ally_timer = null
	
	if is_instance_valid(enemy_timer):
		enemy_timer.stop()
		enemy_timer.queue_free()
	enemy_timer = null
	
	combat_running = false
	
	if not is_instance_valid(ally_npc):
		btn_ally.disabled = false
	if not is_instance_valid(enemy_npc):
		btn_enemy.disabled = false
	
	_update_start_btn_state()
	print("Comabte detenido")
	
func _update_start_btn_state() -> void:
	# Start only if all teams have npc and they are not fighting
	btn_start.disabled = combat_running or not (is_instance_valid(ally_npc) and is_instance_valid(enemy_npc))

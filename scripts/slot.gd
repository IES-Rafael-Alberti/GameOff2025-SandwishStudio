extends Area2D

@export var max_glow_alpha := 0.7
@export var max_scale := 1.0
@export var min_scale := 0.6
@export var attraction_radius := 120.0
@export var highlight_speed := 10.0

var glow_sprite: Sprite2D
var particles: CPUParticles2D
var piece_over: Node = null
var occupied := false

func _ready():
	if not has_node("Highlight"):
		var h = Node2D.new()
		h.name = "Highlight"
		add_child(h)
		h.z_index = 10
		glow_sprite = Sprite2D.new()
		glow_sprite.centered = true
		glow_sprite.modulate = Color(1,1,0,0)
		glow_sprite.scale = Vector2(min_scale,min_scale)
		h.add_child(glow_sprite)
		particles = CPUParticles2D.new()
		particles.amount = 6
		particles.one_shot = false
		particles.emitting = false
		h.add_child(particles)
	else:
		glow_sprite = get_node("Highlight/Glow")
		particles = get_node("Highlight/Particles")

func _process(delta):
	if piece_over:
		var dist = piece_over.global_position.distance_to(global_position)
		var factor = clamp(1.0 - float(dist) / float(attraction_radius), 0.0, 1.0)
		glow_sprite.modulate.a = lerp(float(glow_sprite.modulate.a), max_glow_alpha * factor, delta * highlight_speed)
		var target_scale = lerp(float(min_scale), float(max_scale), factor)
		glow_sprite.scale = glow_sprite.scale.lerp(Vector2(target_scale, target_scale), delta * highlight_speed)

		particles.emitting = factor > 0.3
	else:
		glow_sprite.modulate.a = lerp(float(glow_sprite.modulate.a), 0.0, delta * highlight_speed)
		glow_sprite.scale = glow_sprite.scale.lerp(Vector2(min_scale, min_scale), delta * highlight_speed)
		particles.emitting = false

func piece_enter(piece: Node):
	piece_over = piece

func piece_exit(piece: Node):
	if piece_over == piece:
		piece_over = null

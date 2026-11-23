extends Node3D
## Floor 1 prototype: a floating island arena. Keeps a few enemies alive
## around the player and counts kills.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

## Every enemy uses the same model, just a different colour and name.
const ENEMY_TYPES := [
	{"name": "Crimson Husk", "color": Color(0.85, 0.15, 0.15)},
	{"name": "Verdant Husk", "color": Color(0.2, 0.7, 0.25)},
	{"name": "Azure Husk", "color": Color(0.2, 0.4, 0.95)},
	{"name": "Violet Husk", "color": Color(0.6, 0.25, 0.85)},
	{"name": "Amber Husk", "color": Color(0.95, 0.6, 0.1)},
]

@export var max_enemies := 3
@export var spawn_delay := 1.5
@export var spawn_distance_min := 6.0
@export var spawn_distance_max := 10.0
@export var island_radius := 13.0

var kills := 0
var _spawn_timer := 1.0

@onready var player: Player = $Player
@onready var enemies: Node3D = $Enemies
@onready var kill_board: Label3D = $KillBoard


func _ready() -> void:
	_build_pillars()
	_update_board()


func _physics_process(delta: float) -> void:
	if get_tree().get_nodes_in_group("enemies").size() < max_enemies:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			spawn_enemy()
			_spawn_timer = spawn_delay


func spawn_enemy() -> Node3D:
	var type: Dictionary = ENEMY_TYPES.pick_random()
	var enemy := ENEMY_SCENE.instantiate()
	enemy.display_name = type["name"]
	enemy.body_color = type["color"]
	enemy.player = player

	# Pick a spot a few metres from the player that's still on the island.
	var center := player.get_head_position()
	var pos := Vector3.ZERO
	for i in 10:
		var angle := randf() * TAU
		var dist := randf_range(spawn_distance_min, spawn_distance_max)
		pos = Vector3(center.x + cos(angle) * dist, 0.05, center.z + sin(angle) * dist)
		if Vector2(pos.x, pos.z).length() < island_radius:
			break
	var flat := Vector2(pos.x, pos.z).limit_length(island_radius)
	enemy.position = Vector3(flat.x, 0.05, flat.y)

	enemy.died.connect(_on_enemy_died)
	enemies.add_child(enemy)
	return enemy


func _on_enemy_died(_enemy: Node3D) -> void:
	kills += 1
	_update_board()


func _update_board() -> void:
	kill_board.text = "Kills: %d" % kills


func _build_pillars() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.6, 0.58)
	mat.roughness = 0.95
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.45
	mesh.bottom_radius = 0.55
	mesh.height = 4.0
	mesh.radial_segments = 12
	mesh.material = mat
	var shape := CylinderShape3D.new()
	shape.radius = 0.55
	shape.height = 4.0
	for i in 8:
		var angle := TAU * i / 8.0
		var body := StaticBody3D.new()
		body.position = Vector3(cos(angle) * 13.8, 2.0, sin(angle) * 13.8)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		add_child(body)

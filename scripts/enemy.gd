extends CharacterBody3D
## A simple enemy: walks toward the player, winds up (glows), then lunges.
## Hitting it while it winds up staggers it and cancels the attack.

signal died(enemy: Node3D)

enum State { SPAWNING, CHASE, WINDUP, RECOVER, DEAD }

@export var display_name := "Husk"
@export var body_color := Color(0.85, 0.15, 0.15)
@export var max_hp := 100
@export var move_speed := 1.1
@export var attack_range := 1.2       ## Starts winding up when this close (metres).
@export var attack_damage := 10
@export var windup_time := 0.9
@export var recover_time := 1.4

const HP_BAR_WIDTH := 0.6

var player: Node3D   ## Set by main.gd when spawning.
var hp := 0
var state := State.SPAWNING

var _state_timer := 0.0
var _knockback := Vector3.ZERO
var _walk_time := 0.0
var _flash := 0.0
var _glow := 0.0
var _material: StandardMaterial3D
var _hp_material: StandardMaterial3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var model: Node3D = $Model
@onready var hp_bar: Node3D = $HPBar
@onready var hp_fill: MeshInstance3D = $HPBar/Fill
@onready var name_label: Label3D = $NameLabel
@onready var shatter: CPUParticles3D = $Shatter


func _ready() -> void:
	hp = max_hp

	# Same model for every enemy, but each gets its own colour.
	_material = StandardMaterial3D.new()
	_material.albedo_color = body_color
	_material.roughness = 0.7
	_material.emission_enabled = true
	_material.emission = body_color
	_material.emission_energy_multiplier = 0.0
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = _material

	_hp_material = StandardMaterial3D.new()
	_hp_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hp_fill.material_override = _hp_material

	name_label.text = "%s  Lv.1" % display_name
	name_label.modulate = body_color.lightened(0.5)
	shatter.color = body_color
	_update_hp_bar()

	# Pop into existence.
	model.scale = Vector3.ONE * 0.01
	var t := create_tween()
	t.tween_property(model, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): if state == State.SPAWNING: state = State.CHASE)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var move := Vector3.ZERO
	if player:
		var target: Vector3 = player.get_head_position()
		var to := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
		var dist := to.length()
		if dist > 0.05:
			# The model's front is +Z, so this turns it to face the player.
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 1.0 - exp(-8.0 * delta))

		_state_timer -= delta
		match state:
			State.CHASE:
				if dist > attack_range:
					move = to / dist * move_speed
					_walk_time += delta
				else:
					state = State.WINDUP
					_state_timer = windup_time
			State.WINDUP:
				_glow = 1.0 - clampf(_state_timer / windup_time, 0.0, 1.0)
				if _state_timer <= 0.0:
					_lunge(dist)
			State.RECOVER:
				if _state_timer <= 0.0:
					state = State.CHASE

	velocity.x = move.x + _knockback.x
	velocity.z = move.z + _knockback.z
	_knockback = _knockback.move_toward(Vector3.ZERO, 8.0 * delta)
	move_and_slide()

	if global_position.y < -10.0:
		_die(false)   # Knocked off the island!


func _process(delta: float) -> void:
	if state == State.DEAD:
		return
	# The model has no skeleton, so "animate" it by bobbing and leaning.
	model.position.y = absf(sin(_walk_time * 7.0)) * 0.06
	model.rotation.z = sin(_walk_time * 7.0) * 0.07
	var lean := -0.3 * _glow if state == State.WINDUP else 0.0
	model.rotation.x = lerpf(model.rotation.x, lean, 1.0 - exp(-10.0 * delta))

	_flash = maxf(_flash - delta * 6.0, 0.0)
	if state != State.WINDUP:
		_glow = move_toward(_glow, 0.0, delta * 3.0)
	_material.albedo_color = body_color.lerp(Color.WHITE, _flash)
	_material.emission = body_color.lerp(Color.WHITE, _flash)
	_material.emission_energy_multiplier = _glow * 1.5 + _flash * 2.0


func take_hit(damage: int, direction: Vector3, hit_point: Vector3) -> void:
	if state == State.DEAD:
		return
	hp -= damage
	DamageNumber.spawn(get_tree().current_scene, hit_point, damage)
	_flash = 1.0

	# Push the enemy along the swing, plus a little away from the player.
	var push := Vector3(direction.x, 0.0, direction.z)
	if player:
		var away: Vector3 = global_position - player.get_head_position()
		away.y = 0.0
		push += away.normalized() * 0.5
	if push.length() > 0.01:
		_knockback = push.normalized() * clampf(damage * 0.06, 0.8, 5.0)

	_update_hp_bar()
	if hp <= 0:
		_die(true)
	else:
		state = State.RECOVER   # Stagger: cancels any attack wind-up.
		_state_timer = 0.5


func _lunge(dist: float) -> void:
	model.rotation.x = 0.5
	_glow = 0.0
	_knockback = global_basis.z * 2.0
	if dist <= attack_range + 0.5 and player and player.has_method("take_damage"):
		player.take_damage(attack_damage)
	state = State.RECOVER
	_state_timer = recover_time


func _die(with_effect: bool) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	hp_bar.visible = false
	name_label.visible = false
	died.emit(self)
	if not with_effect:
		queue_free()
		return
	# Topple backwards, then shatter into pieces.
	var t := create_tween()
	t.tween_property(model, "rotation:x", -1.4, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		model.visible = false
		shatter.emitting = true)
	t.tween_interval(shatter.lifetime + 0.2)
	t.tween_callback(queue_free)


func _update_hp_bar() -> void:
	var ratio := clampf(float(hp) / max_hp, 0.0, 1.0)
	hp_fill.scale.x = maxf(ratio, 0.001)
	hp_fill.position.x = -HP_BAR_WIDTH * (1.0 - ratio) * 0.5
	if ratio > 0.5:
		_hp_material.albedo_color = Color(0.3, 0.9, 0.3)
	elif ratio > 0.25:
		_hp_material.albedo_color = Color(0.95, 0.8, 0.2)
	else:
		_hp_material.albedo_color = Color(0.95, 0.25, 0.2)

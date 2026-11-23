class_name Sword
extends Node3D
## A sword that hurts enemies. Damage depends on how FAST the blade is moving,
## so a hard swing hits hard and a gentle tap does nothing.

@export var min_hit_speed := 1.5      ## m/s. Slower than this does no damage.
@export var damage_per_speed := 6.0   ## Damage for every m/s of blade speed.
@export var max_damage := 80
@export var hit_cooldown := 0.4       ## Seconds before the same enemy can be hit again.

## Speed is measured relative to this node (the player), so walking or
## snap-turning with the thumbsticks doesn't count as "swinging".
var reference: Node3D
## Controller to vibrate when we hit something (VR only).
var haptics: XRController3D

var speed := 0.0                 ## Current blade speed in m/s.
var velocity := Vector3.ZERO     ## Current blade velocity (world space).

var _last_local := Vector3.ZERO
var _has_last := false
var _cooldowns := {}
var _blade_material: StandardMaterial3D

@onready var hitbox: Area3D = $Hitbox
@onready var sweet_spot: Marker3D = $SweetSpot
@onready var blade: MeshInstance3D = $Blade


func _ready() -> void:
	_blade_material = blade.get_active_material(0)


func reset_tracking() -> void:
	_has_last = false
	speed = 0.0


func _physics_process(delta: float) -> void:
	_measure_speed(delta)

	# Blade glows when you swing hard enough to do damage.
	if _blade_material:
		var power := clampf((speed - min_hit_speed) / 6.0, 0.0, 1.0)
		_blade_material.emission_energy_multiplier = power * 2.5

	for id in _cooldowns.keys():
		_cooldowns[id] -= delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)

	if speed < min_hit_speed:
		return
	for body in hitbox.get_overlapping_bodies():
		if not body.has_method("take_hit"):
			continue
		var id := body.get_instance_id()
		if _cooldowns.has(id):
			continue
		_cooldowns[id] = hit_cooldown
		var damage := int(clampf(speed * damage_per_speed, 1.0, max_damage))
		body.take_hit(damage, velocity.normalized(), sweet_spot.global_position)
		if haptics:
			haptics.trigger_haptic_pulse("haptic", 0.0, clampf(damage / 40.0, 0.3, 1.0), 0.1, 0.0)


func _measure_speed(delta: float) -> void:
	var ref := reference.global_transform if reference else Transform3D.IDENTITY
	var local := ref.affine_inverse() * sweet_spot.global_position
	if _has_last and delta > 0.0:
		var local_velocity := (local - _last_local) / delta
		velocity = ref.basis * local_velocity
		speed = lerpf(speed, local_velocity.length(), 0.6)
	_last_local = local
	_has_last = true

class_name Player
extends XROrigin3D
## The player. In VR: your headset + two controllers, sword in your right hand.
## With no headset it falls back to mouse & keyboard so you can test on a PC:
##   WASD = move, mouse = look, left click = swing, Esc = free the mouse.

@export var move_speed := 2.5          ## Metres per second (left thumbstick / WASD).
@export var snap_turn_degrees := 30.0  ## Right thumbstick turn step.
@export var max_hp := 100
@export var arena_radius := 13.5       ## Keeps you on the island.

const MOUSE_SENSITIVITY := 0.0025

var hp := 0
var vr_mode := false

var _snap_ready := true
var _pose_fixed := {}
var _message_timer := 0.0
var _desktop_hand: Node3D
var _pitch := 0.0
var _swing_tween: Tween
var _swing_side := 1.0

@onready var camera: XRCamera3D = $XRCamera3D
@onready var left_hand: XRController3D = $LeftHand
@onready var right_hand: XRController3D = $RightHand
@onready var sword: Sword = $RightHand/Sword
@onready var hp_label: Label3D = $LeftHand/HPLabel
@onready var message_label: Label3D = $XRCamera3D/MessageLabel


func _ready() -> void:
	hp = max_hp
	var xr := XRServer.find_interface("OpenXR")
	if xr and xr.is_initialized():
		vr_mode = true
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		sword.haptics = right_hand
	else:
		print("No VR headset found - using mouse & keyboard mode.")
		_setup_desktop()
	sword.reference = self
	_update_hp_label()
	show_message("Swing FAST to deal damage!", 4.0)


func get_head_position() -> Vector3:
	return camera.global_position


func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	hp = maxi(hp - amount, 0)
	_update_hp_label()
	if vr_mode:
		left_hand.trigger_haptic_pulse("haptic", 0.0, 1.0, 0.25, 0.0)
		right_hand.trigger_haptic_pulse("haptic", 0.0, 1.0, 0.25, 0.0)
	if hp == 0:
		show_message("DEFEATED\nRespawning...", 2.5)
		global_position = Vector3.ZERO
		sword.reset_tracking()
		hp = max_hp
		_update_hp_label()


func show_message(text: String, seconds: float) -> void:
	message_label.text = text
	_message_timer = seconds


func _process(delta: float) -> void:
	if vr_mode:
		for c: XRController3D in [left_hand, right_hand]:
			if not _pose_fixed.get(c.name, false):
				_try_fix_pose(c)
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			message_label.text = ""


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if vr_mode:
		input = left_hand.get_vector2("primary")
		_handle_snap_turn(right_hand.get_vector2("primary").x)
	else:
		input.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		input.y = float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))

	if input.length() > 0.15:
		input = input.limit_length(1.0)
		var forward := -camera.global_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var right := camera.global_basis.x
		right.y = 0.0
		right = right.normalized()
		global_position += (forward * input.y + right * input.x) * move_speed * delta

	# Stay on the island.
	var flat := Vector2(camera.global_position.x, camera.global_position.z)
	if flat.length() > arena_radius:
		var push := flat.normalized() * (flat.length() - arena_radius)
		global_position -= Vector3(push.x, 0.0, push.y)


func _handle_snap_turn(x: float) -> void:
	if absf(x) > 0.7 and _snap_ready:
		_snap_ready = false
		# Rotate around your head, not around the play-area centre.
		var pivot := camera.global_position
		var t := global_transform
		t.origin -= pivot
		t = t.rotated(Vector3.UP, -signf(x) * deg_to_rad(snap_turn_degrees))
		t.origin += pivot
		global_transform = t
	elif absf(x) < 0.3:
		_snap_ready = true


func _try_fix_pose(c: XRController3D) -> void:
	# Different Godot versions name the "held object" pose differently.
	var tracker := XRServer.get_tracker(c.tracker) as XRPositionalTracker
	if tracker == null:
		return
	for pose_name: StringName in [&"grip", &"grip_pose"]:
		if tracker.has_pose(pose_name):
			c.pose = pose_name
			_pose_fixed[c.name] = true
			return


func _update_hp_label() -> void:
	hp_label.text = "HP %d / %d" % [hp, max_hp]
	var ratio := float(hp) / max_hp
	hp_label.modulate = Color(0.95, 0.25, 0.2).lerp(Color(0.4, 1.0, 0.4), ratio)


# ---------------------------------------------------------------------------
# Mouse & keyboard fallback (for testing without a headset)
# ---------------------------------------------------------------------------

func _setup_desktop() -> void:
	camera.position = Vector3(0.0, 1.7, 0.0)
	_desktop_hand = Node3D.new()
	_desktop_hand.name = "DesktopHand"
	camera.add_child(_desktop_hand)
	_desktop_hand.position = Vector3(0.28, -0.32, -0.3)
	_desktop_hand.rotation = Vector3(-0.15, deg_to_rad(35.0), 0.0)
	sword.reparent(_desktop_hand, false)
	sword.transform = Transform3D.IDENTITY
	hp_label.reparent(camera, false)
	hp_label.position = Vector3(-0.5, -0.32, -0.9)
	left_hand.visible = false
	right_hand.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if vr_mode:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, -1.3, 1.3)
		camera.rotation.x = _pitch
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_LEFT:
			desktop_swing()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Plays a horizontal slash, alternating right-to-left and left-to-right.
func desktop_swing() -> void:
	if _desktop_hand == null or (_swing_tween and _swing_tween.is_running()):
		return
	var start := deg_to_rad(-70.0) * _swing_side
	var finish := deg_to_rad(80.0) * _swing_side
	_swing_side = -_swing_side
	_swing_tween = create_tween()
	_swing_tween.tween_property(_desktop_hand, "rotation", Vector3(-0.25, start, 0.0), 0.08)
	_swing_tween.tween_property(_desktop_hand, "rotation", Vector3(-0.25, finish, 0.0), 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_swing_tween.tween_property(_desktop_hand, "rotation", Vector3(-0.15, deg_to_rad(35.0), 0.0), 0.25)

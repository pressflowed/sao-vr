class_name DamageNumber
extends Label3D
## Floating number that pops up where you hit an enemy, then drifts up and fades.


static func spawn(parent: Node, at: Vector3, amount: int) -> void:
	var n := DamageNumber.new()
	n.text = str(amount) + ("!" if amount >= 50 else "")
	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.no_depth_test = true
	n.pixel_size = 0.003
	n.font_size = 48 + mini(amount, 80) / 2
	n.outline_size = 14
	n.outline_modulate = Color(0, 0, 0, 0.8)
	if amount >= 50:
		n.modulate = Color(1.0, 0.35, 0.2)   # big hit: red-orange
	elif amount >= 25:
		n.modulate = Color(1.0, 0.85, 0.2)   # good hit: yellow
	else:
		n.modulate = Color.WHITE
	parent.add_child(n)
	n.global_position = at + Vector3(randf_range(-0.1, 0.1), 0.1, randf_range(-0.1, 0.1))

	var t := n.create_tween().set_parallel()
	t.tween_property(n, "global_position:y", n.global_position.y + 0.5, 0.9) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(n, "modulate:a", 0.0, 0.5).set_delay(0.4)
	t.tween_property(n, "outline_modulate:a", 0.0, 0.5).set_delay(0.4)
	t.chain().tween_callback(n.queue_free)

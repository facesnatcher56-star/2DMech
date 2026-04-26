class_name CombatEffects
extends Node

signal player_tracer_done(hit_zone: String, damage_scale: float, hit_point: Vector2)
signal enemy_tracer_done()

var _shell: Node2D
var _enemy_shell: Node2D
var _muzzle_flash: Node2D
var _impact_flash: CanvasItem
var _enemy_impact_flash: CanvasItem
var _player_mech: Node2D
var _player_muzzle: CanvasItem
var _enemy_muzzle: CanvasItem
var _floating_layer: Node2D

func setup(shell: Node2D, enemy_shell: Node2D, muzzle_flash: Node2D,
		impact_flash: CanvasItem, enemy_impact_flash: CanvasItem,
		player_mech: Node2D, player_muzzle: CanvasItem, enemy_muzzle: CanvasItem,
		floating_layer: Node2D) -> void:
	_shell = shell
	_enemy_shell = enemy_shell
	_muzzle_flash = muzzle_flash
	_impact_flash = impact_flash
	_enemy_impact_flash = enemy_impact_flash
	_player_mech = player_mech
	_player_muzzle = player_muzzle
	_enemy_muzzle = enemy_muzzle
	_floating_layer = floating_layer
	_shell.hide()
	_enemy_shell.hide()
	_impact_flash.hide()
	_enemy_impact_flash.hide()
	_muzzle_flash.hide()

func fire_player_tracer(target: Vector2, hit_zone: String, damage_scale: float) -> void:
	_muzzle_flash.global_position = _player_muzzle.global_position
	_muzzle_flash.show()
	var original_x = _player_mech.position.x
	var recoil = create_tween()
	recoil.tween_property(_player_mech, "position:x", original_x - 20, 0.05)
	recoil.tween_property(_player_mech, "position:x", original_x, 0.15)

	_shell.global_position = _player_muzzle.global_position
	_shell.show()
	_shell.look_at(target)
	var tracer = create_tween()
	tracer.tween_property(_shell, "global_position", target, 0.1)
	tracer.tween_callback(func(): _on_player_shell_arrived(target, hit_zone, damage_scale))

	var flash_hide = create_tween()
	flash_hide.tween_interval(0.1)
	flash_hide.tween_callback(_muzzle_flash.hide)

func _on_player_shell_arrived(pos: Vector2, hit_zone: String, damage_scale: float) -> void:
	_shell.hide()
	_show_impact(_impact_flash, pos)
	player_tracer_done.emit(hit_zone, damage_scale, pos)

func fire_enemy_tracer(target: Vector2) -> void:
	_enemy_shell.global_position = _enemy_muzzle.global_position
	_enemy_shell.show()
	var tracer = create_tween()
	tracer.tween_property(_enemy_shell, "global_position", target, 0.3)
	tracer.tween_callback(func(): _on_enemy_shell_arrived(target))

func _on_enemy_shell_arrived(pos: Vector2) -> void:
	_enemy_shell.hide()
	_show_impact(_enemy_impact_flash, pos)
	enemy_tracer_done.emit()

func spawn_text(text: String, pos: Vector2, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = pos + Vector2(randf_range(-20, 20), -40)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	_floating_layer.add_child(label)
	var t = label.create_tween()
	t.set_parallel(true)
	t.tween_property(label, "position:y", label.position.y - 80, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.2)
	t.set_parallel(false)
	t.tween_callback(label.queue_free)

func _show_impact(flash: CanvasItem, pos: Vector2) -> void:
	flash.global_position = pos
	flash.modulate.a = 1.0
	flash.show()
	create_tween().tween_property(flash, "modulate:a", 0.0, 0.15).finished.connect(flash.hide)

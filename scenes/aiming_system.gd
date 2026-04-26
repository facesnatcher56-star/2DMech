class_name AimingSystem
extends Node

signal shot_committed(hit_point: Vector2, power_value: float)
signal power_changed(value: float)

var is_charging: bool = false
var power_value: float = 0.0
var projected_hit_point: Vector2 = Vector2.ZERO

var _selected_zone: String = "TORSO"
var _ammo_config: Dictionary
var _firing_line: Line2D
var _aim_reticle: Node2D
var _player_muzzle: CanvasItem
var _zones_container: Node2D
var _enemy_torso: Node2D

const BASE_CHARGE_TIME: float = 2.0

func setup(firing_line: Line2D, aim_reticle: Node2D, player_muzzle: CanvasItem, zones_container: Node2D, enemy_torso: Node2D) -> void:
	_firing_line = firing_line
	_aim_reticle = aim_reticle
	_player_muzzle = player_muzzle
	_zones_container = zones_container
	_enemy_torso = enemy_torso
	_firing_line.hide()
	_aim_reticle.hide()

func set_target_zone(zone: String) -> void:
	_selected_zone = zone
	_highlight_zone(zone)

func start_charging(ammo_config: Dictionary) -> void:
	_ammo_config = ammo_config
	is_charging = true
	power_value = 0.0

func release() -> void:
	if not is_charging: return
	is_charging = false
	_firing_line.hide()
	_aim_reticle.hide()
	shot_committed.emit(projected_hit_point, power_value)

func _process(delta: float) -> void:
	if not is_charging: return
	power_value += delta / (BASE_CHARGE_TIME / _ammo_config.charge_mult)
	power_value = clamp(power_value, 0.0, 1.0)
	power_changed.emit(power_value)

	var time = Time.get_ticks_msec() / 1000.0
	var max_amp = 150.0 * _ammo_config.wobble_mult
	var amp = lerp(8.0, max_amp, power_value * power_value)
	var wobble = (sin(time * lerp(1.2, 5.5, power_value)) * amp
		+ sin(time * lerp(2.0, 9.0, power_value)) * (amp * 0.4)
		+ sin(time * 0.5) * (amp * 0.2))
	projected_hit_point = get_zone_center(_selected_zone) + Vector2(0, wobble)

	_firing_line.show()
	_firing_line.set_point_position(0, _player_muzzle.global_position)
	_firing_line.set_point_position(1, projected_hit_point)
	_aim_reticle.show()
	_aim_reticle.global_position = projected_hit_point

	var r_color = Color(0.2, 0.8, 0.2)
	if power_value > 0.6:  r_color = Color(1.0, 0.9, 0.2)
	if power_value > 0.85: r_color = Color(1.0, 0.2, 0.1)
	_aim_reticle.get_node("Circle").modulate = r_color

func check_collision(pos: Vector2) -> String:
	for zone in _zones_container.get_children():
		var size = zone.size
		var xf = zone.get_global_transform()
		var poly = PackedVector2Array([xf * Vector2.ZERO, xf * Vector2(size.x, 0), xf * size, xf * Vector2(0, size.y)])
		if Geometry2D.is_point_in_polygon(pos, poly): return zone.name.replace("Zone", "").to_upper()
	return ""

func get_zone_center(zone_name: String) -> Vector2:
	var node = _zones_container.get_node_or_null(zone_name.capitalize() + "Zone")
	if node: return node.get_global_transform() * (node.size / 2.0)
	return _enemy_torso.global_position

func _highlight_zone(zone_name: String) -> void:
	for zone in _zones_container.get_children():
		zone.visible = zone.name.replace("Zone", "").to_upper() == zone_name
		zone.modulate = Color(1, 1, 1, 0.4)

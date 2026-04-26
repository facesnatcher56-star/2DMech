extends Node2D

@onready var player_hp_bar = $HUD/Controls/TopUI/PlayerHP/ProgressBar
@onready var enemy_hp_bar = $HUD/Controls/TopUI/EnemyHP/ProgressBar
@onready var enemy_aim_bar = $HUD/Controls/TopUI/EnemyHP/AimBar
@onready var ammo_buttons_container = $HUD/Controls/BottomUI/HBox/AmmoSection/AmmoButtons

@onready var aiming_panel = $HUD/Controls/AimingFeedback/AimingPanel
@onready var aiming_instr = $HUD/Controls/AimingFeedback/AimingPanel/VBox/Instruction
@onready var power_bar = $HUD/Controls/AimingFeedback/AimingPanel/VBox/GaugeBox/PowerBar
@onready var result_label = $HUD/Controls/AimingFeedback/ResultLabel
@onready var debug_label = $HUD/Controls/AimingFeedback/DebugLabel
@onready var target_label = $HUD/Controls/AimingFeedback/TargetLabel

@onready var firing_line = $FiringLine
@onready var aim_reticle = $AimReticle
@onready var shell = $Shell
@onready var impact_flash = $ImpactFlash
@onready var enemy_shell = $EnemyShell
@onready var enemy_impact_flash = $EnemyImpactFlash
@onready var muzzle_flash = $MuzzleFlash
@onready var player_mech = $Mechs/PlayerMech
@onready var player_muzzle = $Mechs/PlayerMech/MainCannon/Barrel/Muzzle
@onready var player_torso = $Mechs/PlayerMech/Torso
@onready var enemy_muzzle = $Mechs/EnemyMech/TwinGuns/G1/Muzzle
@onready var enemy_torso = $Mechs/EnemyMech/Torso
@onready var enemy_zones_container = $Mechs/EnemyMech/Zones

# Configuration
const AMMO_CONFIG = {
	"STANDARD": { "charge_mult": 1.0, "dmg_mult": 1.0, "wobble_mult": 1.0, "damage": { "TORSO": 10, "LEGS": 10, "WEAPON": 10, "SYSTEMS": 10 } },
	"AP": { "charge_mult": 1.0, "dmg_mult": 1.1, "wobble_mult": 1.2, "damage": { "TORSO": 16, "LEGS": 7, "WEAPON": 9, "SYSTEMS": 9 } },
	"HE": { "charge_mult": 0.7, "dmg_mult": 1.0, "wobble_mult": 0.8, "damage": { "TORSO": 8, "LEGS": 14, "WEAPON": 11, "SYSTEMS": 11 } },
	"SABOT": { "charge_mult": 1.5, "dmg_mult": 1.0, "wobble_mult": 1.5, "damage": { "TORSO": 13, "LEGS": 6, "WEAPON": 14, "SYSTEMS": 10 } }
}

# State variables
var selected_ammo: String = "STANDARD"
var selected_target_zone: String = "TORSO"
var player_hp: float = 100.0
var enemy_hp: float = 100.0
var battle_over: bool = false

# Pressure System State
var is_charging: bool = false
var power_value: float = 0.0
var base_charge_time: float = 2.0
var projected_hit_point: Vector2 = Vector2.ZERO
var shot_resolving: bool = false

# Enemy AI
var enemy_aim_timer: float = 0.0
var enemy_aim_duration: float = 5.0

func _ready() -> void:
	_reset_ui()
	player_hp_bar.value = player_hp
	enemy_hp_bar.value = enemy_hp
	_start_enemy_aim_cycle()
	_update_target_visuals()
	_on_ammo_type_pressed("STANDARD")

func _reset_ui():
	aiming_panel.hide()
	result_label.text = ""
	firing_line.hide()
	aim_reticle.hide()
	shell.hide()
	impact_flash.hide()
	enemy_shell.hide()
	enemy_impact_flash.hide()
	muzzle_flash.hide()
	target_label.hide()

func _input(event: InputEvent) -> void:
	if battle_over or is_charging: return
	if event is InputEventMouseButton and event.pressed:
		var hit = _check_collision_point(get_global_mouse_position())
		if hit != "":
			selected_target_zone = hit
			_update_target_visuals()

func _process(delta: float) -> void:
	if battle_over: return
	if is_charging: _update_aiming_logic(delta)
	_update_enemy_ai(delta)

func _update_aiming_logic(delta: float):
	var config = AMMO_CONFIG[selected_ammo]
	power_value += delta / (base_charge_time / config.charge_mult)
	power_value = clamp(power_value, 0.0, 1.0)
	power_bar.value = power_value
	
	aiming_instr.visible = power_value > 0.85
	
	var time = Time.get_ticks_msec() / 1000.0
	var max_amp = 150.0 * config.wobble_mult
	var amp = lerp(8.0, max_amp, power_value * power_value)
	var speed_a = lerp(1.2, 5.5, power_value)
	var speed_b = lerp(2.0, 9.0, power_value)
	var speed_drift = 0.5 
	
	var wobble = sin(time * speed_a) * amp 
	wobble += sin(time * speed_b) * (amp * 0.4)
	wobble += sin(time * speed_drift) * (amp * 0.2)
	
	var base_target = _get_zone_center(selected_target_zone)
	projected_hit_point = base_target + Vector2(0, wobble)
	
	firing_line.show()
	firing_line.set_point_position(0, player_muzzle.global_position)
	firing_line.set_point_position(1, projected_hit_point)
	
	aim_reticle.show()
	aim_reticle.global_position = projected_hit_point
	
	var r_color = Color(0.2, 0.8, 0.2)
	if power_value > 0.6: r_color = Color(1.0, 0.9, 0.2)
	if power_value > 0.85: r_color = Color(1.0, 0.2, 0.1)
	aim_reticle.get_node("Circle").modulate = r_color

func _on_fire_down():
	if battle_over or shot_resolving: return
	is_charging = true
	power_value = 0.0
	aiming_panel.show()
	target_label.show()
	target_label.text = "TARGET: " + selected_target_zone

func _on_fire_up():
	if not is_charging: return
	is_charging = false
	aiming_panel.hide()
	target_label.hide()
	firing_line.hide()
	aim_reticle.hide()
	_resolve_player_shot()

func _resolve_player_shot():
	shot_resolving = true
	var mult = _get_power_multiplier(power_value)
	var final_mult = mult * AMMO_CONFIG[selected_ammo].dmg_mult
	var hit_zone = _check_collision_point(projected_hit_point)
	_fire_tracer(projected_hit_point, hit_zone, final_mult)

func _get_power_multiplier(val: float) -> float:
	if val < 0.25: return 0.65
	if val < 0.60: return 1.00
	if val < 0.85: return 1.35
	return 1.75

func _fire_tracer(target: Vector2, hit_zone: String, scale: float):
	muzzle_flash.global_position = player_muzzle.global_position
	muzzle_flash.show()
	var original_pos = player_mech.position
	var t = create_tween()
	t.tween_property(player_mech, "position:x", original_pos.x - 20, 0.05)
	t.tween_property(player_mech, "position:x", original_pos.x, 0.15)
	
	shell.global_position = player_muzzle.global_position
	shell.show()
	shell.look_at(target)
	
	var bt = create_tween()
	bt.tween_property(shell, "global_position", target, 0.1)
	bt.tween_callback(func(): _on_impact(target, hit_zone, scale))
	
	var ft = create_tween()
	ft.tween_interval(0.1)
	ft.tween_callback(muzzle_flash.hide)

func _on_impact(pos: Vector2, hit_zone: String, scale: float):
	shell.hide()
	_show_impact(impact_flash, pos)
	if hit_zone != "":
		var base = AMMO_CONFIG[selected_ammo].damage[hit_zone]
		var total = max(1.0, base * scale)
		var prefix = "OVERPOWER " if power_value > 0.85 else ""
		if selected_ammo == "HE": total += 4
		enemy_hp -= total
		enemy_hp_bar.value = enemy_hp
		result_label.text = prefix + "HIT " + hit_zone + " - " + str(int(total)) + " DMG"
		if enemy_hp <= 0: battle_over = true
	else:
		result_label.text = "MISS"
	shot_resolving = false

func _check_collision_point(pos: Vector2) -> String:
	for zone in enemy_zones_container.get_children():
		var size = zone.size
		var xf = zone.get_global_transform()
		var poly = PackedVector2Array([xf * Vector2.ZERO, xf * Vector2(size.x, 0), xf * size, xf * Vector2(0, size.y)])
		if Geometry2D.is_point_in_polygon(pos, poly): return zone.name.replace("Zone", "").to_upper()
	return ""

func _get_zone_center(zone_name: String) -> Vector2:
	var node = enemy_zones_container.get_node(zone_name.capitalize() + "Zone")
	if node: return node.get_global_transform() * (node.size / 2.0)
	return enemy_torso.global_position

func _update_target_visuals():
	for zone in enemy_zones_container.get_children():
		var zn = zone.name.replace("Zone", "").to_upper()
		if zn == selected_target_zone:
			zone.visible = true
			zone.modulate = Color(1, 1, 1, 0.4)
		else:
			zone.visible = false
			zone.modulate = Color(1, 1, 1, 0.3)

func _update_enemy_ai(delta):
	if battle_over: return
	enemy_aim_timer += delta
	enemy_aim_bar.value = enemy_aim_timer / enemy_aim_duration
	if enemy_aim_timer >= enemy_aim_duration: _fire_enemy_shell()

func _start_enemy_aim_cycle():
	enemy_aim_timer = 0.0
	enemy_aim_duration = randf_range(4.0, 8.0)

func _fire_enemy_shell():
	_start_enemy_aim_cycle()
	var tween = create_tween()
	enemy_shell.global_position = enemy_muzzle.global_position
	enemy_shell.show()
	tween.tween_property(enemy_shell, "global_position", player_torso.global_position, 0.3)
	tween.tween_callback(func():
		enemy_shell.hide()
		_show_impact(enemy_impact_flash, player_torso.global_position)
		player_hp -= 10
		player_hp_bar.value = player_hp
		if player_hp <= 0: battle_over = true
	)

func _show_impact(flash: Control, pos: Vector2):
	flash.global_position = pos
	flash.modulate.a = 1.0
	flash.show()
	create_tween().tween_property(flash, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).finished.connect(flash.hide)

func _on_ammo_type_pressed(type: String):
	selected_ammo = type
	var ammo_label = $HUD/Controls/BottomUI/HBox/AmmoSection/SelectedAmmoLabel
	if ammo_label: ammo_label.text = "SELECTED: " + type
	for button in ammo_buttons_container.get_children():
		if button is Button:
			button.modulate = Color(1.6, 1.6, 1.2) if button.name.to_upper() == type else Color(1, 1, 1)

func _on_brace_pressed(): pass

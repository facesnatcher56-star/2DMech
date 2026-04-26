extends Node2D

@onready var selected_ammo_label = $HUD/Controls/BottomUI/HBox/AmmoSection/SelectedAmmoLabel
@onready var ammo_buttons_container = $HUD/Controls/BottomUI/HBox/AmmoSection/AmmoButtons
@onready var player_hp_bar = $HUD/Controls/TopUI/PlayerHP/ProgressBar
@onready var enemy_hp_bar = $HUD/Controls/TopUI/EnemyHP/ProgressBar
@onready var enemy_aim_bar = $HUD/Controls/TopUI/EnemyHP/AimBar
@onready var charge_bar = $HUD/Controls/BottomUI/HBox/FireContainer/ChargeBar
@onready var debug_label = $HUD/Controls/DebugLabel

@onready var shell = $Shell
@onready var impact_flash = $ImpactFlash
@onready var enemy_shell = $EnemyShell
@onready var enemy_impact_flash = $EnemyImpactFlash
@onready var aim_arc = $AimArc
@onready var landing_indicator = $LandingIndicator
@onready var hit_marker = $HitMarker

@onready var player_muzzle = $Mechs/PlayerMech/MainCannon/Barrel/Muzzle
@onready var player_torso = $Mechs/PlayerMech/Torso
@onready var enemy_muzzle = $Mechs/EnemyMech/TwinGuns/G1/Muzzle
@onready var enemy_torso = $Mechs/EnemyMech/Torso
@onready var enemy_zones_container = $Mechs/EnemyMech/Zones

# Ammo Data
const AMMO_CONFIG = {
	"STANDARD": {
		"vel_mult": 1.0,
		"damage": { "TORSO": 10.0, "LEGS": 10.0, "WEAPON": 10.0, "SYSTEMS": 10.0 }
	},
	"AP": {
		"vel_mult": 1.0,
		"damage": { "TORSO": 16.0, "LEGS": 7.0, "WEAPON": 9.0, "SYSTEMS": 9.0 }
	},
	"HE": {
		"vel_mult": 0.9,
		"damage": { "TORSO": 8.0, "LEGS": 14.0, "WEAPON": 11.0, "SYSTEMS": 11.0 }
	},
	"SABOT": {
		"vel_mult": 1.2,
		"damage": { "TORSO": 13.0, "LEGS": 6.0, "WEAPON": 14.0, "SYSTEMS": 10.0 }
	}
}

# State variables
var selected_ammo: String = "STANDARD"
var player_hp: float = 100.0
var enemy_hp: float = 100.0
var battle_over: bool = false
var show_debug_zones: bool = true

# Player projectile (Ballistic)
var shell_in_flight: bool = false
var shell_velocity: Vector2 = Vector2.ZERO
var shell_gravity: float = 1200.0

# Charging
var is_charging: bool = false
var charge_value: float = 0.0
var charge_time: float = 1.5
var max_launch_velocity: float = 1600.0

# Enemy projectile (Existing Tween-based)
var enemy_shell_in_flight: bool = false
var enemy_aim_timer: float = 0.0
var enemy_aim_duration: float = 5.0

func _ready() -> void:
	_update_ammo_display()
	_highlight_selected_button()
	
	shell.hide()
	impact_flash.hide()
	enemy_shell.hide()
	enemy_impact_flash.hide()
	aim_arc.hide()
	landing_indicator.hide()
	hit_marker.hide()
	
	player_hp_bar.value = player_hp
	enemy_hp_bar.value = enemy_hp
	charge_bar.value = 0.0
	
	for zone in enemy_zones_container.get_children():
		zone.visible = show_debug_zones
	
	_start_enemy_aim_cycle()

func _process(delta: float) -> void:
	if battle_over:
		aim_arc.hide()
		landing_indicator.hide()
		return
	
	if is_charging:
		charge_value += delta / charge_time
		charge_value = clamp(charge_value, 0.0, 1.0)
		charge_bar.value = charge_value
		_update_aim_preview()
	else:
		aim_arc.hide()
		landing_indicator.hide()
	
	if shell_in_flight:
		var prev_pos = shell.global_position
		shell_velocity.y += shell_gravity * delta
		var next_pos = prev_pos + (shell_velocity * delta)
		
		var hit_data = _check_collision_detailed(prev_pos, next_pos)
		if hit_data.hit:
			shell.global_position = hit_data.pos
			_on_player_shell_impact(hit_data.zone_name, hit_data.pos)
		elif next_pos.y >= 520:
			shell.global_position = next_pos
			_on_player_shell_impact("", next_pos)
		elif next_pos.x > 1500 or next_pos.x < -300:
			shell_in_flight = false
			shell.hide()
		else:
			shell.global_position = next_pos
			shell.rotation = shell_velocity.angle()

	if enemy_hp > 0 and player_hp > 0:
		enemy_aim_timer += delta
		enemy_aim_bar.value = enemy_aim_timer / enemy_aim_duration
		if enemy_aim_timer >= enemy_aim_duration:
			_fire_enemy_shell()

func _get_zone_polygon(zone: ColorRect) -> PackedVector2Array:
	var size = zone.size
	var xf = zone.get_global_transform()
	return PackedVector2Array([
		xf * Vector2.ZERO,
		xf * Vector2(size.x, 0),
		xf * size,
		xf * Vector2(0, size.y)
	])

func _check_collision_detailed(from: Vector2, to: Vector2) -> Dictionary:
	var best_hit = {"hit": false, "zone_name": "", "pos": Vector2.ZERO, "dist": 99999.0}
	for zone in enemy_zones_container.get_children():
		if zone is ColorRect:
			var poly = _get_zone_polygon(zone)
			var zone_name = zone.name.replace("Zone", "").to_upper()
			for i in range(4):
				var inter = Geometry2D.segment_intersects_segment(from, to, poly[i], poly[(i + 1) % 4])
				if inter:
					var d = from.distance_to(inter)
					if d < best_hit.dist:
						best_hit = {"hit": true, "zone_name": zone_name, "pos": inter, "dist": d}
			if Geometry2D.is_point_in_polygon(from, poly) or Geometry2D.is_point_in_polygon(to, poly):
				if 0.0 < best_hit.dist:
					best_hit = {"hit": true, "zone_name": zone_name, "pos": to, "dist": 0.0}
	return best_hit

func _update_aim_preview() -> void:
	aim_arc.clear_points()
	aim_arc.show()
	var pos = player_muzzle.global_position
	var angle = deg_to_rad(-20)
	var config = AMMO_CONFIG[selected_ammo]
	var power = lerp(400.0, max_launch_velocity, charge_value) * config.vel_mult
	var vel = Vector2(cos(angle), sin(angle)) * power
	var dt = 0.05
	var max_steps = 40
	aim_arc.add_point(pos)
	var hit_something = false
	for i in range(1, max_steps):
		var prev_p = pos
		vel.y += shell_gravity * dt
		pos += vel * dt
		aim_arc.add_point(pos)
		var hit_data = _check_collision_detailed(prev_p, pos)
		if hit_data.hit:
			landing_indicator.global_position = hit_data.pos
			landing_indicator.show()
			hit_something = true
			break
		if pos.y >= 520:
			landing_indicator.global_position = Vector2(pos.x, 520)
			landing_indicator.show()
			hit_something = true
			break
		if pos.x > 1280 or pos.x < 0: break
	if not hit_something: landing_indicator.hide()

func _on_fire_down() -> void:
	if shell_in_flight or battle_over: return
	is_charging = true
	charge_value = 0.0

func _on_fire_up() -> void:
	if not is_charging: return
	is_charging = false
	_launch_player_shell()

func _launch_player_shell() -> void:
	shell_in_flight = true
	shell.global_position = player_muzzle.global_position
	shell.show()
	var angle = deg_to_rad(-20)
	var config = AMMO_CONFIG[selected_ammo]
	var power = lerp(400.0, max_launch_velocity, charge_value) * config.vel_mult
	shell_velocity = Vector2(cos(angle), sin(angle)) * power
	charge_value = 0.0
	charge_bar.value = 0.0

func _on_player_shell_impact(hit_zone: String, impact_pos: Vector2) -> void:
	shell_in_flight = false
	shell.hide()
	hit_marker.global_position = impact_pos
	hit_marker.show()
	_show_impact(impact_flash, impact_pos)
	
	if hit_zone != "":
		var config = AMMO_CONFIG[selected_ammo]
		var dmg = config.damage.get(hit_zone, 10.0)
		print("HIT ", hit_zone, " WITH ", selected_ammo, " FOR ", dmg)
		
		var total_dmg = dmg
		if selected_ammo == "HE":
			total_dmg += 4.0
			print("HE SPLASH +4")
			
		debug_label.text = "LAST IMPACT: " + hit_zone + " (" + str(total_dmg) + " dmg) at " + str(impact_pos.snapped(Vector2.ONE))
		enemy_hp -= total_dmg
		enemy_hp_bar.value = enemy_hp
		if enemy_hp <= 0:
			enemy_hp = 0
			battle_over = true
			print("Enemy defeated! VICTORY")
	else:
		print("HIT RESULT: MISS")
		debug_label.text = "LAST IMPACT: MISS at " + str(impact_pos.snapped(Vector2.ONE))

func _fire_enemy_shell() -> void:
	if enemy_shell_in_flight or battle_over: return
	enemy_shell_in_flight = true
	enemy_shell.global_position = enemy_muzzle.global_position
	enemy_shell.show()
	var tween = create_tween()
	tween.tween_property(enemy_shell, "global_position", player_torso.global_position, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_enemy_shell_impact)
	_start_enemy_aim_cycle()

func _on_enemy_shell_impact() -> void:
	enemy_shell.hide()
	_show_impact(enemy_impact_flash, enemy_shell.global_position)
	player_hp -= 10.0
	player_hp_bar.value = player_hp
	enemy_shell_in_flight = false
	if player_hp <= 0:
		player_hp = 0
		battle_over = true
		print("Player defeated! DEFEAT")

func _start_enemy_aim_cycle() -> void:
	enemy_aim_timer = 0.0
	enemy_aim_duration = randf_range(4.0, 8.0)
	enemy_aim_bar.value = 0.0

func _show_impact(flash: Control, pos: Vector2) -> void:
	flash.global_position = pos
	flash.modulate.a = 1.0
	flash.show()
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.15)
	flash_tween.tween_callback(flash.hide)

func _on_ammo_type_pressed(type: String) -> void:
	selected_ammo = type
	_update_ammo_display()
	_highlight_selected_button()

func _on_brace_pressed() -> void:
	print("ACTION: BRACE")

func _update_ammo_display() -> void:
	if selected_ammo_label: selected_ammo_label.text = "SELECTED: " + selected_ammo

func _highlight_selected_button() -> void:
	for button in ammo_buttons_container.get_children():
		if button is Button:
			if button.name.to_upper() == selected_ammo: button.modulate = Color(1.6, 1.6, 1.2, 1.0)
			else: button.modulate = Color(1.0, 1.0, 1.0, 1.0)

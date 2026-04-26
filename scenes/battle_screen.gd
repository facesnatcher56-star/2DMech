extends Node2D

enum CombatState { PLAYER_TURN, PLAYER_AIMING, PLAYER_RESOLVING, ENEMY_TURN, ENEMY_RESOLVING, BATTLE_OVER }

const AmmoData = preload("res://scenes/ammo_data.gd")

@onready var hud = $HUD
@onready var aiming_system = $AimingSystem
@onready var combat_effects = $CombatEffects
@onready var enemy_ai = $EnemyAI
@onready var player_torso = $Mechs/PlayerMech/Torso

var current_state = CombatState.PLAYER_TURN
var selected_ammo: String = "STANDARD"
var selected_target_zone: String = "TORSO"
var player_hp: float = 100.0
var enemy_hp: float = 100.0
var current_round: int = 1
var player_bracing: bool = false

func _ready() -> void:
	aiming_system.setup(
		$FiringLine, $AimReticle,
		$Mechs/PlayerMech/MainCannon/Barrel/Muzzle,
		$Mechs/EnemyMech/Zones,
		$Mechs/EnemyMech/Torso
	)
	aiming_system.shot_committed.connect(_on_shot_committed)
	aiming_system.power_changed.connect(hud.set_power)

	combat_effects.setup(
		$Shell, $EnemyShell, $MuzzleFlash,
		$ImpactFlash, $EnemyImpactFlash,
		$Mechs/PlayerMech,
		$Mechs/PlayerMech/MainCannon/Barrel/Muzzle,
		$Mechs/EnemyMech/TwinGuns/G1/Muzzle,
		$FloatingTextLayer
	)
	combat_effects.player_tracer_done.connect(_on_player_tracer_done)
	combat_effects.enemy_tracer_done.connect(_on_enemy_tracer_done)

	enemy_ai.fire_decided.connect(_on_enemy_fire_decided)

	hud.set_turn("player", current_round)
	hud.set_player_hp(player_hp)
	hud.set_enemy_hp(enemy_hp)
	hud.set_ammo_highlight(selected_ammo)
	aiming_system.set_target_zone(selected_target_zone)

func _input(event: InputEvent) -> void:
	if current_state != CombatState.PLAYER_TURN or aiming_system.is_charging: return
	if event is InputEventMouseButton and event.pressed:
		var hit = aiming_system.check_collision(get_global_mouse_position())
		if hit != "":
			selected_target_zone = hit
			aiming_system.set_target_zone(hit)

# --- Button callbacks (wired via .tscn) ---

func _on_fire_down() -> void:
	if current_state != CombatState.PLAYER_TURN: return
	current_state = CombatState.PLAYER_AIMING
	hud.show_aiming_ui(selected_target_zone)
	aiming_system.start_charging(AmmoData.CONFIG[selected_ammo])

func _on_fire_up() -> void:
	if not aiming_system.is_charging: return
	hud.hide_aiming_ui()
	aiming_system.release()

func _on_brace_pressed() -> void:
	if current_state != CombatState.PLAYER_TURN: return
	player_bracing = true
	combat_effects.spawn_text("BRACING", player_torso.global_position, Color.CYAN)
	_end_player_turn()

func _on_ammo_type_pressed(type: String) -> void:
	if current_state != CombatState.PLAYER_TURN: return
	selected_ammo = type
	hud.set_ammo_highlight(type)

# --- Signal handlers ---

func _on_shot_committed(hit_point: Vector2, power_value: float) -> void:
	current_state = CombatState.PLAYER_RESOLVING
	var hit_zone = aiming_system.check_collision(hit_point)
	var damage_scale = _get_power_multiplier(power_value) * AmmoData.CONFIG[selected_ammo].dmg_mult
	combat_effects.fire_player_tracer(hit_point, hit_zone, damage_scale)

func _on_player_tracer_done(hit_zone: String, damage_scale: float, hit_point: Vector2) -> void:
	if hit_zone != "":
		var base = AmmoData.CONFIG[selected_ammo].damage[hit_zone]
		var total = max(1.0, base * damage_scale)
		if selected_ammo == "HE": total += 4
		enemy_hp -= total
		hud.set_enemy_hp(enemy_hp)
		combat_effects.spawn_text("-" + str(int(total)), hit_point, Color.ORANGE)
		hud.set_result("HIT " + hit_zone + " - " + str(int(total)) + " DMG")
		if enemy_hp <= 0:
			_end_battle(true)
			return
	else:
		combat_effects.spawn_text("MISS", hit_point, Color.GRAY)
		hud.set_result("MISS")
	_end_player_turn()

func _end_player_turn() -> void:
	current_state = CombatState.ENEMY_TURN
	hud.set_turn("enemy", current_round)
	get_tree().create_timer(1.2).timeout.connect(_start_enemy_turn)

func _start_enemy_turn() -> void:
	if current_state != CombatState.ENEMY_TURN: return
	current_state = CombatState.ENEMY_RESOLVING
	enemy_ai.start_turn()

func _on_enemy_fire_decided() -> void:
	combat_effects.fire_enemy_tracer(player_torso.global_position)

func _on_enemy_tracer_done() -> void:
	var damage = 10.0
	var text = "-" + str(int(damage))
	var color = Color.RED
	if player_bracing:
		damage *= 0.5
		text = "BRACED -" + str(int(damage))
		color = Color.CYAN
		player_bracing = false
	player_hp -= damage
	hud.set_player_hp(player_hp)
	combat_effects.spawn_text(text, player_torso.global_position, color)
	if player_hp <= 0:
		_end_battle(false)
		return
	current_round += 1
	current_state = CombatState.PLAYER_TURN
	hud.set_turn("player", current_round)

func _end_battle(victory: bool) -> void:
	current_state = CombatState.BATTLE_OVER
	hud.set_turn("over", current_round)
	hud.set_result("VICTORY!" if victory else "DEFEAT")

func _get_power_multiplier(val: float) -> float:
	if val < 0.25: return 0.65
	if val < 0.60: return 1.00
	if val < 0.85: return 1.35
	return 1.75

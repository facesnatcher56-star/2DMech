class_name CombatHUD
extends CanvasLayer

@onready var player_hp_bar = $Controls/TopUI/PlayerHP/ProgressBar
@onready var enemy_hp_bar = $Controls/TopUI/EnemyHP/ProgressBar
@onready var round_label = $Controls/TopUI/CenterBox/RoundLabel
@onready var turn_label = $Controls/TopUI/CenterBox/TurnLabel
@onready var ammo_buttons = $Controls/BottomUI/HBox/AmmoSection/AmmoButtons
@onready var selected_ammo_label = $Controls/BottomUI/HBox/AmmoSection/SelectedAmmoLabel
@onready var aiming_panel = $Controls/AimingFeedback/AimingPanel
@onready var aiming_instr = $Controls/AimingFeedback/AimingPanel/VBox/Instruction
@onready var power_bar = $Controls/AimingFeedback/AimingPanel/VBox/GaugeBox/PowerBar
@onready var result_label = $Controls/AimingFeedback/ResultLabel
@onready var target_label = $Controls/AimingFeedback/TargetLabel

func _ready() -> void:
	aiming_panel.hide()
	target_label.hide()
	result_label.text = ""

func set_turn(state: String, round: int) -> void:
	round_label.text = "ROUND " + str(round)
	match state:
		"player": turn_label.text = "PLAYER TURN"; turn_label.modulate = Color(0.6, 0.8, 1.0)
		"enemy":  turn_label.text = "ENEMY TURN";  turn_label.modulate = Color(1.0, 0.4, 0.4)
		"over":   turn_label.text = "BATTLE OVER"; turn_label.modulate = Color(1, 1, 1)
		_:        turn_label.text = ""

func set_player_hp(val: float) -> void:
	player_hp_bar.value = val

func set_enemy_hp(val: float) -> void:
	enemy_hp_bar.value = val

func set_ammo_highlight(type: String) -> void:
	selected_ammo_label.text = "SELECTED: " + type
	for btn in ammo_buttons.get_children():
		if btn is Button:
			btn.modulate = Color(1.6, 1.6, 1.2) if btn.name.to_upper() == type else Color(1, 1, 1)

func set_result(text: String) -> void:
	result_label.text = text

func show_aiming_ui(zone: String) -> void:
	aiming_panel.show()
	target_label.show()
	target_label.text = "TARGET: " + zone

func hide_aiming_ui() -> void:
	aiming_panel.hide()
	target_label.hide()

func set_power(val: float) -> void:
	power_bar.value = val
	aiming_instr.visible = val > 0.85

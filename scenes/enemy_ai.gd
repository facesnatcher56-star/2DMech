class_name EnemyAI
extends Node

signal fire_decided()

func start_turn() -> void:
	fire_decided.emit()

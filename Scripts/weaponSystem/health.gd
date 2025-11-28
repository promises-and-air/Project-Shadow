# health.gd
extends Node
class_name Health

signal health_changed(current: float, max_value: float)
signal died

@export var max_health: float = 100.0

var current_health: float


func _ready() -> void:
	current_health = max_health
	print("✅ Health initialized: ", current_health, "/", max_health)


func take_damage(amount: float) -> void:
	var old_health = current_health
	current_health = max(0, current_health - amount)
	
	print("💔 Take damage: ", amount)
	print("   Before: ", old_health)
	print("   After: ", current_health)
	
	# ✅ Эмитим сигнал ВСЕГДА (даже если не подключен)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		print("☠️ Health depleted - emitting died signal")
		died.emit()


func heal(amount: float) -> void:
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

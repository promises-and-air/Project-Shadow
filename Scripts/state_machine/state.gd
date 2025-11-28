extends Node
class_name State

# Ссылка на игрока - инициализируется через initialize()
var player: PlayerMovement

# Вызывается StateMachine для установки связи с игроком
func initialize(player_ref: PlayerMovement) -> void:
	player = player_ref
	assert(player != null, "State requires PlayerMovement reference")

# Вызывается при входе в состояние
# msg: опциональные данные от предыдущего состояния
func enter(_msg: Dictionary = {}) -> void:
	pass

# Вызывается при выходе из состояния
func exit() -> void:
	pass

# Вызывается каждый кадр (_process)
# Используется для визуальных эффектов, не влияющих на физику
func update(_delta: float) -> void:
	pass

# Вызывается каждый физический кадр (_physics_process)
# ВСЁ движение и физика должны быть здесь
func physics_update(_delta: float) -> void:
	pass

# Проверка условий для перехода в другие состояния
# Возвращает State объект для перехода или null если остаемся в текущем
func check_transitions() -> State:
	return null  # По умолчанию - нет перехода

# Вспомогательный метод для получения имени состояния
func get_state_name() -> String:
	return name

# Debug информация
func _to_string() -> String:
	return "[State: %s]" % name

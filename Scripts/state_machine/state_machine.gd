extends Node
class_name StateMachine

# Начальное состояние - ОБЯЗАТЕЛЬНО назначьте в Inspector!
@export var initial_state: State = null

var current_state: State
var states: Dictionary = {}

# Debug
@export var debug_transitions: bool = false


func _ready() -> void:
	# Проверка, что StateMachine дочерний узел PlayerMovement
	var player_ref = get_parent()
	assert(player_ref is PlayerMovement, "StateMachine must be child of PlayerMovement")
	
	# Инициализация всех State детей через initialize()
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.initialize(player_ref)
	
	# Установка начального состояния
	if initial_state:
		current_state = initial_state
	else:
		push_error("StateMachine: initial_state not set! Defaulting to first state.")
		if states.size() > 0:
			current_state = states.values()[0]
	
	# Входим в начальное состояние
	if current_state:
		current_state.enter()
	else:
		push_error("StateMachine: No states found!")


func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if not current_state:
		return
	
	# ПРАВИЛЬНЫЙ ПОРЯДОК:
	# 1. Обновляем физику текущего состояния (изменяет velocity)
	current_state.physics_update(delta)
	
	# 2. КРИТИЧНО: Применяем движение ОДИН РАЗ
	get_parent().move_and_slide()
	
	# 3. Проверяем переходы ПОСЛЕ обновления физики и move_and_slide()
	_check_transition()


func _check_transition() -> void:
	var next_state = current_state.check_transitions()
	
	# Если вернули State объект (не null) и это другое состояние
	if next_state and next_state != current_state:
		transition_to_state(next_state)


# Принимает State объект для перехода
func transition_to_state(next_state: State, msg: Dictionary = {}) -> void:
	if not next_state or next_state == current_state:
		return
	
	# Выходим из текущего состояния
	if current_state:
		current_state.exit()
	
	# Переходим в новое состояние
	current_state = next_state
	current_state.enter(msg)


# LEGACY МЕТОД: для обратной совместимости со String переходами
# Используйте transition_to_state() вместо этого
func transition_to(state_name: String) -> void:
	var next_state = states.get(state_name.to_lower())
	if next_state:
		transition_to_state(next_state)
	else:
		push_warning("StateMachine: State '%s' not found!" % state_name)

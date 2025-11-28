extends State
class_name DashState

const DASH_SPEED: float = 30.0
const DASH_DURATION: float = 0.15
const DASH_COOLDOWN: float = 1.2

var dash_time: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO


func enter(_msg: Dictionary = {}) -> void:
	dash_time = 0.0
	(player as CharacterBody3D).floor_snap_length = 0.0
	
	# Emit signal for viewmodel animation
	player.start_dash.emit()
	
	# Определяем направление dash на основе input
	var h_input = Input.get_action_strength("right") - Input.get_action_strength("left")
	var f_input = Input.get_action_strength("backward") - Input.get_action_strength("forward")
	
	var input_dir = Vector3(h_input, 0, f_input)
	
	# Если есть input - dash в направлении движения, иначе - вперед
	if input_dir.length() > 0.1:
		dash_direction = input_dir.rotated(Vector3.UP, player.global_rotation.y).normalized()
	else:
		# Dash вперед (направление камеры)
		dash_direction = -player.global_transform.basis.z
	
	# Устанавливаем скорость dash (только горизонтально)
	player.velocity.x = dash_direction.x * DASH_SPEED
	player.velocity.z = dash_direction.z * DASH_SPEED
	
	# Если в воздухе - обнуляем падение или сохраняем восходящий momentum
	if not player.is_on_floor():
		player.velocity.y = max(player.velocity.y, 0.0)
	
	# Устанавливаем cooldown
	player.dash_cooldown = DASH_COOLDOWN


func exit() -> void:
	player.end_dash.emit()
	player.fall_speed = 0.0
	
	if player.is_on_floor():
		(player as CharacterBody3D).floor_snap_length = 0.4  # ← Восстанавливаем ground snap
	else:
		(player as CharacterBody3D).floor_snap_length = 0.0


func physics_update(delta: float) -> void:
	dash_time += delta
	
	# Постепенное замедление (100% → 70%)
	var speed_multiplier = 1.0 - (dash_time / DASH_DURATION * 0.3)
	var target_speed = DASH_SPEED * speed_multiplier
	
	# Применяем горизонтальную скорость
	player.velocity.x = dash_direction.x * target_speed
	player.velocity.z = dash_direction.z * target_speed
	
	if player.is_on_floor():
		player.velocity.y = 0.0
	else:
		player.velocity.y -= player.gravity * delta * 0.5


func check_transitions() -> State:
	var state_machine = get_parent() as StateMachine
	if not state_machine:
		return null
	
	# Dash завершен - переходим в соответствующее состояние
	if dash_time >= DASH_DURATION:
		if player.is_on_floor():
			# Если присели и есть скорость - переход в slide
			if player.is_crouching and player.velocity.length() > player.walk_start_threshold:
				player.start_slide.emit()
				return state_machine.states.get("slidestate")
			else:
				return state_machine.states.get("groundstate")
		else:
			# В воздухе - переход в AirState
			return state_machine.states.get("airstate")
	
	# Dash продолжается
	return null

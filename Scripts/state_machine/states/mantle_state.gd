extends State
class_name MantleState

@export var mantle_duration: float = 0.4
@export var mantle_height_boost: float = 1.2

var target_position: Vector3
var start_position: Vector3
var mantle_timer: float = 0.0
var wall_direction: Vector3


func enter(_msg: Dictionary = {}) -> void:
	player.start_mantle.emit()
	
	var mantle_info = player.get_mantle_info()
	
	if not mantle_info.can_mantle:
		return
	
	target_position = mantle_info.landing_position
	start_position = player.global_position
	mantle_timer = 0.0
	
	wall_direction = (target_position - start_position)
	wall_direction.y = 0
	wall_direction = wall_direction.normalized()
	
	
	var direction = (target_position - start_position).normalized()
	var distance = start_position.distance_to(target_position)
	var needed_speed = distance / mantle_duration
	player.velocity = direction * needed_speed * mantle_height_boost
	
	# Reset fall speed to prevent unwanted landing bob
	player.fall_speed = 0.0


func exit() -> void:
	
	player.end_mantle.emit()
	
	# Crouch boost после mantle
	if Input.is_action_pressed("crouch"):
		var forward = -player.global_transform.basis.z
		forward.y = 0
		
		if forward.length() > 0:
			forward = forward.normalized()
			player.velocity = Vector3(
				forward.x * player.speed * 1.2,
				1.5,
				forward.z * player.speed * 1.2
			)
	else:
		# ✅ НОВОЕ: Обнуляем вертикальную скорость
		player.velocity.y = 0.0

	
	player.can_jump = true
	
	# Reset fall speed to prevent land bob
	player.fall_speed = 0.0
	
	# ✅ НОВОЕ: Принудительно ставим на землю
	(player as CharacterBody3D).floor_snap_length = 0.4



func physics_update(delta: float) -> void:
	mantle_timer += delta
	
	var progress = clamp(mantle_timer / mantle_duration, 0.0, 1.0)
	var eased_progress = 1.0 - pow(1.0 - progress, 3.0)
	
	var current_target = start_position.lerp(target_position, eased_progress)
	var direction_to_target = current_target - player.global_position
	
	if progress < 0.95:
		var time_left = max(mantle_duration - mantle_timer, delta)
		var needed_velocity = direction_to_target / time_left
		player.velocity = needed_velocity
	else:
		player.velocity = player.velocity.lerp(Vector3.ZERO, delta * 15.0)


func check_transitions() -> State:
	var state_machine = get_parent() as StateMachine
	if not state_machine:
		return null
	
	var h_rot = player.global_transform.basis.get_euler().y
	var f_input = Input.get_axis("forward", "backward")
	var h_input = Input.get_action_strength("right") - Input.get_action_strength("left")
	var input_direction = Vector3(h_input, 0, f_input).rotated(Vector3.UP, h_rot)
	
	# Отмена mantle при движении назад
	if Input.is_action_pressed("backward"):
		if input_direction.length() > 0.3:
			input_direction = input_direction.normalized()
			var angle = rad_to_deg(input_direction.angle_to(wall_direction))
			if angle > 90.0:
				return state_machine.states.get("airstate")
	
	# Mantle завершён по времени
	if mantle_timer >= mantle_duration:
		return state_machine.states.get("groundstate")
	
	# Mantle завершён при достижении цели
	var distance_to_target = player.global_position.distance_to(target_position)
	if distance_to_target < 0.3 and mantle_timer > mantle_duration * 0.6:
		return state_machine.states.get("groundstate")
	
	return null

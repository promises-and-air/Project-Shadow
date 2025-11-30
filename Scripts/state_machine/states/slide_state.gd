extends State
class_name SlideState

var slide_curve_point: float = 0.0
const SLIDE_DURATION: float = 0.6
const MIN_SLIDE_SPEED: float = 11.0


func enter(_msg: Dictionary = {}) -> void:
	(player as CharacterBody3D).floor_snap_length = 0.4  # Встроенное свойство CharacterBody3D
	slide_curve_point = 0.0
	player.start_slide.emit()


func exit() -> void:
	slide_curve_point = 0.0
	player.end_slide.emit()


func physics_update(delta: float) -> void:
	player.is_crouching = player.handle_crouch(delta, true)
	
	if slide_curve_point < 1.0:
		slide_curve_point += delta / SLIDE_DURATION
	else:
		slide_curve_point = 1.0
	
	var is_slide_downward = player.velocity.dot(player.get_floor_normal()) > 0
	
	var angle_curve_sample_point = 0.0
	if is_slide_downward:
		angle_curve_sample_point = player.get_floor_angle() / player.floor_max_angle
	
	if is_slide_downward and player.velocity.length() < 25.0:
		player.apply_force(player.velocity.normalized() * delta * 4.0)
	
	var drag_multiplier = 1.0
	if slide_curve_point < 0.2:
		drag_multiplier = 0.3
	
	var slide_drag = 1.0
	if player.slide_drag_curve and player.slope_angle_drag_curve:
		slide_drag = player.slide_drag_curve.sample(slide_curve_point) * player.slope_angle_drag_curve.sample(angle_curve_sample_point) * drag_multiplier
	
	var horizontal_velocity = Vector3(player.velocity.x, 0, player.velocity.z)
	var wish_vel = player.direction * player.speed
	
	if player.direction.length() > 0:
		var new_vel_length = lerp(horizontal_velocity, Vector3.ZERO, slide_drag * delta).length()
		var new_vel_dir = lerp(horizontal_velocity.normalized(), wish_vel.normalized(), 0.8 * delta)
		horizontal_velocity = new_vel_dir.normalized() * new_vel_length
	else:
		horizontal_velocity = lerp(horizontal_velocity, Vector3.ZERO, slide_drag * delta)
	
	player.velocity.x = horizontal_velocity.x
	player.velocity.z = horizontal_velocity.z


func check_transitions() -> State:
	var state_machine = get_parent() as StateMachine
	if not state_machine:
		return null
	
	if Input.is_action_just_pressed("demon_dash") and player.can_dash:
		player.can_dash = false
		player.dash_cooldown = 1.2
		return state_machine.states.get("dashstate")
	
	if Input.is_action_just_pressed("jump"):
		player.can_jump = false
		player.coyote_timer = 0.0
		player.velocity.y = player.jump_velocity
		
		player.did_jump_from_ground = true
		
		# ✅ ИСПРАВЛЕНО: используем jump_kick вместо land_bob
		if is_instance_valid(player.viewmodel_camera) and player.viewmodel_camera.has_method("jump_kick"):
			player.viewmodel_camera.jump_kick(0.1)  # ← Slide jump чуть выразительнее
		
		player.just_jumped.emit()
		return state_machine.states.get("airstate")
	
	if not player.is_on_floor():
		return state_machine.states.get("airstate")
	
	if player.velocity.length() < MIN_SLIDE_SPEED:
		return state_machine.states.get("groundstate")
	
	return null

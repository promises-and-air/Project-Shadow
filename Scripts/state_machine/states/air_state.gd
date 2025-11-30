extends State
class_name AirState

var jump_count: int = 0
const MAX_JUMPS: int = 2

var was_on_wall: bool = false
var current_wall_side: bool = false


func enter(_msg: Dictionary = {}) -> void:
	(player as CharacterBody3D).floor_snap_length = 0.1  # Встроенное свойство CharacterBody3D
	
	if player.did_jump_from_ground:
		jump_count = 1
		player.did_jump_from_ground = false
	else:
		jump_count = 0
	
	was_on_wall = false
	current_wall_side = false


func exit() -> void:
	if was_on_wall:
		player.end_wall_run.emit(current_wall_side)
		was_on_wall = false


func physics_update(delta: float) -> void:
	player.is_crouching = player.handle_crouch(delta, false, true)
	
	if not player.is_on_floor():
		player.fall_speed = min(player.fall_speed, player.velocity.y)
	
	player.velocity.y -= player.gravity * delta
	
	var h_rot = player.global_transform.basis.get_euler().y
	var f_input = Input.get_axis("forward", "backward")
	var h_input = Input.get_action_strength("right") - Input.get_action_strength("left")
	var direction = Vector3(h_input, 0, f_input).rotated(Vector3.UP, h_rot).normalized()
	
	var wish_vel = direction * player.air_speed
	
	if direction.length() > 0 and player.velocity.length() > 0:
		var horizontal_velocity = Vector3(player.velocity.x, 0, player.velocity.z)
		var angle_diff = rad_to_deg(abs(horizontal_velocity.angle_to(wish_vel)))
		var sample_point = (angle_diff - player.min_strafe_angle) / (player.max_strafe_angle - player.min_strafe_angle)
		sample_point = clamp(sample_point, 0.0, 1.0)
		
		if player.air_strafe_curve:
			wish_vel *= 1.0 + (player.air_strafe_curve.sample(sample_point) * player.air_strafe_modifier)
	
	var horizontal_velocity = Vector3(player.velocity.x, 0, player.velocity.z)
	
	if direction.length() > 0:
		horizontal_velocity = lerp(horizontal_velocity, wish_vel, player.air_accel * delta)
	else:
		horizontal_velocity = lerp(horizontal_velocity, Vector3.ZERO, player.air_drag * delta)
	
	player.velocity.x = horizontal_velocity.x
	player.velocity.z = horizontal_velocity.z
	
	var state_machine = get_parent() as StateMachine
	if not state_machine:
		return
	
	var is_mantling = (state_machine.current_state.name == "MantleState")
	
	if not is_mantling:
		var is_on_wall = player.is_on_wall_only() and player.get_slide_collision_count() > 0
		
		if is_on_wall:
			var collision_point = player.get_last_slide_collision().get_position()
			var is_left_wall = player.is_wall_running_left(collision_point)
			
			if not was_on_wall or current_wall_side != is_left_wall:
				player.start_wall_run.emit(is_left_wall)
				current_wall_side = is_left_wall
			
			was_on_wall = true
		else:
			if was_on_wall:
				player.end_wall_run.emit(current_wall_side)
			was_on_wall = false
	else:
		if was_on_wall:
			player.end_wall_run.emit(current_wall_side)
			was_on_wall = false
	
	if is_instance_valid(player.viewmodel_camera) and player.viewmodel_camera.has_method("free_fall"):
		player.viewmodel_camera.free_fall(player.velocity.y, delta)


func check_transitions() -> State:
	var state_machine = get_parent() as StateMachine
	if not state_machine:
		return null
	
	if Input.is_action_just_pressed("demon_dash") and player.can_dash:
		player.can_dash = false
		player.dash_cooldown = 1.2
		return state_machine.states.get("dashstate")
	
	if player.is_on_floor():
		# Landing impact calculation
		if is_instance_valid(player.viewmodel_camera) and abs(player.fall_speed) > 0.01:
			if player.viewmodel_camera.has_method("land_bob"):
				var impact_strength = clamp(abs(player.fall_speed) * 0.005, 0.008, 0.24)
				player.viewmodel_camera.land_bob(impact_strength)
			if player.viewmodel_camera.has_method("reset_free_fall"):
				player.viewmodel_camera.reset_free_fall()
		
		player.fall_speed = 0.0
		player.can_jump = true
		jump_count = 0
		player.just_landed.emit()
		
		# Check if should slide on landing
		if player.is_crouching and player.velocity.length() > player.walk_start_threshold:
			player.start_slide.emit()
			return state_machine.states.get("slidestate")
		else:
			return state_machine.states.get("groundstate")
	
	if Input.is_action_pressed("jump"):
		var mantle_data = player.get_mantle_info()
		if mantle_data.can_mantle:
			var mantle_state = state_machine.states.get("mantlestate")
			if mantle_state:
				mantle_state.target_position = mantle_data.landing_position
				return mantle_state
	
	if Input.is_action_just_pressed("jump") and jump_count < MAX_JUMPS and not player.is_on_wall_only():
		jump_count += 1
		player.velocity.y = player.jump_velocity * 0.8
		player.coyote_timer = 0.0
		
		if is_instance_valid(player.viewmodel_camera) and player.viewmodel_camera.has_method("jump_kick"):
			player.viewmodel_camera.jump_kick(0.07)
		
		player.just_jumped.emit()
		return null
	
	if Input.is_action_just_pressed("jump") and player.is_on_wall_only() and player.get_slide_collision_count() > 0:
		var wall_normal = player.get_wall_normal()
		
		var jump_direction = (Vector3.UP + wall_normal).normalized()
		var base_jump = jump_direction * player.jump_velocity * player.wall_jump_multiplier
		
		var current_horizontal = Vector3(player.velocity.x, 0, player.velocity.z)
		var wall_tangent = current_horizontal - wall_normal * current_horizontal.dot(wall_normal)
		
		player.velocity = base_jump + wall_tangent * player.wall_jump_momentum_keep
		
		jump_count = 0
		
		if is_instance_valid(player.viewmodel_camera) and player.viewmodel_camera.has_method("jump_kick"):
			player.viewmodel_camera.jump_kick(0.1)
		
		player.just_jumped.emit()
		return null
	
	if Input.is_action_just_pressed("jump"):
		player.queue_jump()
	
	return null

extends State
class_name GroundState


func enter(_msg: Dictionary = {}) -> void:
	(player as CharacterBody3D).floor_snap_length = 0.4
	player.can_jump = true
	player.coyote_timer = 0.0
	player.did_jump_from_ground = false


func exit() -> void:
	(player as CharacterBody3D).floor_snap_length = 0.0


func physics_update(delta: float) -> void:
	player.is_crouching = player.handle_crouch(delta)
	
	var will_slide = player.is_crouching and player.velocity.length() > player.walk_start_threshold
	if will_slide:
		return
	
	var accel = player.floor_accel if not player.is_crouching else player.crouch_accel
	var drag = player.floor_drag
	
	player.move(delta, accel, drag)
	
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta


func check_transitions() -> State:
	var state_machine = get_parent() as StateMachine
	if not state_machine:
		return null
	
	if Input.is_action_just_pressed("demon_dash") and player.can_dash:
		player.can_dash = false
		player.dash_cooldown = 1.2
		return state_machine.states.get("dashstate")
	
	if Input.is_action_just_pressed("jump") and player.can_jump:
		var mantle_data = player.get_mantle_info()
		if mantle_data.can_mantle:
			var mantle_state = state_machine.states.get("mantlestate")
			if mantle_state:
				mantle_state.target_position = mantle_data.landing_position
				return mantle_state
		
		var horizontal_velocity = Vector3(player.velocity.x, 0, player.velocity.z)
		var current_speed = horizontal_velocity.length()
		
		player.can_jump = false
		player.coyote_timer = 0.0
		player.velocity.y = player.jump_velocity
		
		if current_speed > player.speed:
			var boost_multiplier = player.bunny_hop_boost
			var new_speed = min(current_speed * boost_multiplier, player.max_bunny_hop_speed)
			var direction = horizontal_velocity.normalized()
			
			player.velocity.x = direction.x * new_speed
			player.velocity.z = direction.z * new_speed
		
		player.did_jump_from_ground = true
		
		if is_instance_valid(player.viewmodel_camera) and player.viewmodel_camera.has_method("jump_kick"):
			player.viewmodel_camera.jump_kick(0.12)
		
		player.just_jumped.emit()
		return state_machine.states.get("airstate")
	
	if player.is_crouching and player.velocity.length() > player.walk_start_threshold:
		player.start_slide.emit()
		return state_machine.states.get("slidestate")
	
	if not player.is_on_floor():
		player.queue_jump()
		return state_machine.states.get("airstate")
	
	return null

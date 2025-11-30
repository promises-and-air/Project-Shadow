extends CharacterBody3D
class_name PlayerMovement

# ========== EXPORT PHYSICS CONSTANTS ==========
@export_group("Movement Physics")
@export var speed: float = 15.0
@export var gravity: float = 20.0
@export var jump_velocity: float = 12.0
@export var air_speed: float = 16.0
@export var crouch_speed: float = 8.0
@export var melee_speed_multiplier: float = 0.6
@export_group("Acceleration & Drag")
@export var floor_accel: float = 7.0
@export var floor_drag: float = 8.0
@export var air_accel: float = 0.5
@export var air_drag: float = 0.1
@export var crouch_accel: float = 4.0
@export var height_lerp_speed: float = 10.0

@export_group("Thresholds")
@export var walk_start_threshold: float = 13.0
@export var walk_stop_threshold: float = 5.0
@export var input_deadzone: float = 0.15
@export var shake_max_speed: float = 20.0
@export var coyote_time: float = 0.2

@export_group("Bunny Hop Settings")
@export var bunny_hop_boost: float = 1.02
@export var max_bunny_hop_speed: float = 30.0

@export_group("Air Strafe & Curves")
@export var min_strafe_angle: float = 0.0
@export var max_strafe_angle: float = 180.0
@export var air_strafe_modifier: float = 1.0
@export var air_strafe_curve: Curve
@export var slide_drag_curve: Curve
@export var slope_angle_drag_curve: Curve
@export var wallrun_curve: Curve

@export_group("Node References")
@export var head: Node3D
@export var camera_holder: Node3D
@export var collider: CollisionShape3D
@export var camera: Camera3D
@export var real_camera: Camera3D
@export var ceiling_check: ShapeCast3D
@export var raycast_mantle_lower: RayCast3D
@export var raycast_mantle_upper: RayCast3D
# @export var weapon_manager: WeaponManager # TODO: FIX: Старый менеджер удален

@export_group("Camera Settings")
@export var mouse_sense: float = 0.1
@export var cam_accel: float = 40.0
@export var fov: float = 95.0
@export var speed_fov_increase: float = 5.0
@export var fov_lerp_speed: float = 5.0

@export_group("Mantle Settings")
@export var mantle_max_height: float = 4.0
@export var mantle_min_height: float = 0.2
@export var player_capsule_radius: float = 0.5
@export var player_capsule_height: float = 2.0

@export_group("Wall Jump Settings")
@export var wall_jump_multiplier: float = 1.1
@export var wall_jump_momentum_keep: float = 0.7

# ========== MOVEMENT VARIABLES ==========
var direction: Vector3 = Vector3.ZERO
var can_jump: bool = true
var jump_queued: bool = false
var coyote_timer: float = 0.0
var did_jump_from_ground: bool = false

# Crouch
var is_crouching: bool = false
var is_melee_attacking: bool = false
var full_height: float
var crouch_height: float
var head_offset: float

# Dash
var dash_cooldown: float = 0.0
var can_dash: bool = true

# Fall tracking
var fall_speed: float = 0.0

# ========== ONREADY VARIABLES ==========
@onready var viewmodel_camera: Camera3D = $Head/CameraHolder/CameraShaker/Camera/SubViewportContainer/SubViewport/viewmodel_camera
# TODO: FIX: Удалена старая модель PLA и AnimationTree. Пока ставим null, чтобы не крашилось.
# @onready var animation_tree: AnimationTree = $Head/CameraHolder/CameraShaker/Camera/SubViewportContainer/SubViewport/viewmodel_camera/PLA/AnimationTree
# @onready var state_machine_anim: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback") if animation_tree else null

@onready var camera_shaker: ShakerComponent3D = $Head/CameraHolder/CameraShaker/ShakerComponent3D
@onready var head_bob_shaker: ShakerComponent3D = $Head/CameraHolder/CameraShaker/ShakerComponent3D2
@onready var state_machine_node: StateMachine = $StateMachine
@onready var interaction_ray: RayCast3D = $Head/InteractionRayCast
@onready var interaction_label: Label = null #

# ========== SIGNALS ==========
signal just_jumped
signal just_landed
signal start_slide
signal end_slide
signal start_wall_run(is_left: bool)
signal end_wall_run(is_left: bool)
signal start_mantle
signal end_mantle
signal start_dash
signal end_dash

# Debug
const DEBUG_MANTLE = false

# Constants
const EPSILON: float = 0.01

func _ready() -> void:
	add_to_group("player")
	
	if head == null: push_warning("Head node not found")
	if camera == null: push_warning("Camera node not found")
	if collider == null: push_warning("CollisionShape3D not found")
	
	if collider:
		full_height = collider.shape.height
		crouch_height = full_height / 2.0
	
	if head:
		head_offset = head.position.y
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	var viewport = $Head/CameraHolder/CameraShaker/Camera/SubViewportContainer/SubViewport
	if is_instance_valid(viewport):
		viewport.size = DisplayServer.window_get_size()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Camera rotation
		rotate_y(deg_to_rad(-event.relative.x * mouse_sense))
		if head:
			head.rotate_x(deg_to_rad(-event.relative.y * mouse_sense))
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
		
		# Viewmodel sway
		if is_instance_valid(viewmodel_camera) and viewmodel_camera.has_method("sway"):
			viewmodel_camera.sway(Vector2(event.relative.x, event.relative.y))


func _process(delta: float) -> void:
	update_timers(delta)
	update_camera(delta)
	update_effects(delta)
	# _handle_interaction() # TODO: FIX: Временно отключено, пока нет weapon_manager

func _physics_process(delta: float) -> void:
	# Viewmodel sync
	if is_instance_valid(viewmodel_camera) and is_instance_valid(camera):
		viewmodel_camera.global_transform = camera.global_transform


# ========== CAMERA & EFFECTS ==========
func update_camera(delta: float) -> void:
	if not is_instance_valid(camera_holder) or not is_instance_valid(head):
		return
	
	camera_holder.top_level = true
	var lerp_speed = clamp(cam_accel * delta, 0.0, 1.0)
	camera_holder.global_transform.origin = lerp(
		camera_holder.global_transform.origin,
		head.global_transform.origin,
		lerp_speed
	)
	camera_holder.rotation.y = rotation.y
	camera_holder.rotation.x = head.rotation.x


func update_effects(delta: float) -> void:
	if not state_machine_node or not state_machine_node.current_state:
		return
	
	var current_state = state_machine_node.current_state
	var is_mantling = (current_state.name == "MantleState")
	
	# Camera shake
	if not is_mantling:
		if not is_on_floor():
			camera_shaker.intensity = clamp(velocity.length() / shake_max_speed, 0, 1) if shake_max_speed > 0 else 0
		else:
			camera_shaker.intensity = lerp(camera_shaker.intensity, 0.0, 10.0 * delta)
	else:
		camera_shaker.intensity = 0.0
	
	# Head bob shake
	if not is_mantling:
		if is_on_floor() or is_on_wall():
			head_bob_shaker.intensity = clamp(velocity.length() / shake_max_speed, 0, 1) if shake_max_speed > 0 else 0
		else:
			head_bob_shaker.intensity = lerp(head_bob_shaker.intensity, 0.0, 10.0 * delta)
	else:
		head_bob_shaker.intensity = 0.0
	
	# Viewmodel bob
	if is_instance_valid(viewmodel_camera) and is_on_floor() and not is_mantling:
		if viewmodel_camera.has_method("bob"):
			viewmodel_camera.bob(velocity.length(), delta)
	
	# FOV scaling
	if not is_mantling and is_instance_valid(real_camera):
		var speed_factor = min(velocity.length() / shake_max_speed, 1.0) if shake_max_speed > 0 else 0
		var target_fov = lerp(fov, fov + speed_fov_increase, speed_factor)
		real_camera.fov = lerp(real_camera.fov, target_fov, fov_lerp_speed * delta)


# ========== TIMERS ==========
func update_timers(delta: float) -> void:
	# Dash cooldown
	if dash_cooldown > 0:
		dash_cooldown -= delta
		if dash_cooldown <= 0:
			can_dash = true
	
	# Coyote time
	if coyote_timer > 0:
		coyote_timer -= delta
		if coyote_timer <= 0 and not is_on_floor():
			can_jump = false


# ========== JUMP HELPERS ==========
func queue_jump() -> void:
	jump_queued = true
	coyote_timer = coyote_time


func reset_coyote_timer() -> void:
	coyote_timer = 0.0
	can_jump = false


# ========== MOVEMENT ==========
func apply_force(force: Vector3) -> void:
	velocity += force


func move(delta: float, accel: float, drag: float, move_speed: float = speed) -> void:
	
	var current_move_speed = move_speed
	if is_melee_attacking:
		current_move_speed *= melee_speed_multiplier
	
	direction = Vector3.ZERO
	var h_rot: float = global_transform.basis.get_euler().y
	var f_input: float = Input.get_axis("forward", "backward")
	var h_input: float = Input.get_action_strength("right") - Input.get_action_strength("left")
	direction = Vector3(h_input, 0, f_input).rotated(Vector3.UP, h_rot).normalized()
	
	var wish_vel: Vector3 = direction * current_move_speed 
	if is_crouching and is_on_floor():
		wish_vel = direction * (crouch_speed * melee_speed_multiplier if is_melee_attacking else crouch_speed)
	
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	var horizontal_wish = Vector3(wish_vel.x, 0, wish_vel.z)
	
	if direction.length() > 0:
		horizontal_velocity = lerp(horizontal_velocity, horizontal_wish, accel * delta)
	else:
		horizontal_velocity = lerp(horizontal_velocity, horizontal_wish, drag * delta)
	
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


# ========== CROUCH ==========
func handle_crouch(delta: float, force_crouch: bool = false, force_uncrouch: bool = false) -> bool:
	var height: float = collider.shape.height
	var crouching: bool = Input.is_action_pressed("crouch") or (height < full_height - 0.1 and ceiling_check.is_colliding()) or force_crouch
	crouching = false if force_uncrouch else crouching
	
	if not is_equal_approx(height, full_height) or not is_equal_approx(height, crouch_height):
		collider.shape.height = lerp(collider.shape.height, crouch_height if crouching else full_height, delta * height_lerp_speed)
		head.position.y = lerp(head.position.y, head_offset if not crouching else head_offset / 2, delta * height_lerp_speed)
	
	is_crouching = crouching
	return crouching


# ========== WALL HELPERS ==========
func is_wall_running_left(collision_point: Vector3) -> bool:
	var local_collision: Vector3 = head.to_local(collision_point)
	return local_collision.x < 0


func get_horizontal_angle(vec1: Vector3, vec2: Vector3) -> float:
	vec1.y = 0
	vec2.y = 0
	return abs(vec1.angle_to(vec2))


# ========== MANTLE SYSTEM ==========
func get_mantle_info() -> Dictionary:
	if not raycast_mantle_lower.is_colliding():
		return {"can_mantle": false}
	
	var lower_collision_point = raycast_mantle_lower.get_collision_point()
	var wall_normal = raycast_mantle_lower.get_collision_normal()
	
	if raycast_mantle_upper.is_colliding():
		return {"can_mantle": false}
	
	var forward = -global_transform.basis.z
	var angle_to_wall = rad_to_deg(forward.angle_to(-wall_normal))
	
	if angle_to_wall > 70.0:
		return {"can_mantle": false}
	
	var upper_ray_origin = raycast_mantle_upper.global_position
	var upper_ray_end = upper_ray_origin + raycast_mantle_upper.target_position.rotated(Vector3.UP, rotation.y)
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		upper_ray_end + Vector3.UP * 0.2,
		upper_ray_end + Vector3.DOWN * 3.0
	)
	query.exclude = [self]
	query.collision_mask = raycast_mantle_lower.collision_mask
	
	var result = space_state.intersect_ray(query)
	
	if not result:
		return {"can_mantle": false}
	
	var ledge_top = result.position
	var player_head_height = global_position.y + 0.8
	var ledge_height = ledge_top.y - player_head_height
	
	if ledge_height < mantle_min_height or ledge_height > mantle_max_height:
		return {"can_mantle": false}
	
	var landing_pos = ledge_top
	landing_pos += -wall_normal * 1.5
	landing_pos.y = ledge_top.y + (player_capsule_height / 2.0)
		
	return {
		"can_mantle": true,
		"landing_position": landing_pos
	}


func can_mantle() -> bool:
	return get_mantle_info().can_mantle
	
func apply_melee_lunge(lunge_direction: Vector3, lunge_force: float):
	var horizontal_lunge = lunge_direction
	horizontal_lunge.y = 0
	horizontal_lunge = horizontal_lunge.normalized()

	velocity.x += horizontal_lunge.x * lunge_force
	velocity.z += horizontal_lunge.z * lunge_force

	if not is_on_floor():
		velocity.y = max(velocity.y * 0.5, lunge_force * 0.5)
		
# func _handle_interaction() -> void:
# 	if not weapon_manager: return
# 	if interaction_ray.is_colliding():
# 		var collider = interaction_ray.get_collider()
# 		if collider is WeaponPickup:
# 			var pickup = collider as WeaponPickup
# 			_show_pickup_prompt(pickup.weapon_data.weapon_name)
# 			if Input.is_action_just_pressed("interact"):
# 				weapon_manager.try_pickup_weapon(pickup)
# 		else:
# 			_hide_pickup_prompt()
# 	else:
# 		_hide_pickup_prompt()

func _show_pickup_prompt(item_name: String) -> void:
	print("Вижу предмет: ", item_name) 

func _hide_pickup_prompt() -> void:
	pass

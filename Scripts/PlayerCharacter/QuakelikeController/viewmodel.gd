extends Camera3D


signal on_attack_point
@onready var pla: Node3D = $PLA 

@onready var player: PlayerMovement = null
@onready var state_machine: StateMachine = null

var pla_base_position: Vector3
var pla_base_rotation: Vector3

# Consolidated offset tracking
var offsets := {
	"bob_x": 0.0,
	"bob_y": 0.0,
	"land": 0.0,
	"fall": 0.0,
	"walk_y": 0.0,
	"walk_sway": 0.0,
	"slide_y": 0.0,
	"crouch_x": 0.0,
	"crouch_y": 0.0,
	"dash_z": 0.0,
	"mantle_y": 0.0,
}

var rotations := {
	"walk_tilt": 0.0,
	"walk_roll": 0.0,
	"slide_tilt": 0.0,
	"slide_roll": 0.0,
	"crouch_tilt": 0.0,
	"crouch_roll": 0.0,
	"dash_tilt": 0.0,
	"dash_roll": 0.0,
	"mantle_tilt": 0.0,
}

# State flags
var state_flags := {
	"sliding": false,
	"crouching": false,
	"dashing": false,
	"mantling": false,
}

# Timers
var bob_timer: float = 0.0
var land_time: float = 0.0
var land_strength: float = 0.0
var dash_timer: float = 0.0
var mantle_progress: float = 0.0

# Constants
const LAND_DURATION: float = 0.2
const LERP_SPEED_FAST: float = 15.0
const LERP_SPEED_MEDIUM: float = 10.0
const LERP_SPEED_SLOW: float = 5.0

@export_group("Head Bob Settings")
@export_range(0.0, 1.00, 0.0001) var bob_vertical_intensity: float = 0.0002
@export_range(0.0, 1.00, 0.0001) var bob_horizontal_intensity: float = 0.0001
@export_range(1.0, 20.0, 0.1) var bob_speed: float = 12.0

@export_group("Walk Animation Settings")
@export_range(0.0, 1.00, 0.001) var walk_lower_amount: float = 0.0
@export_range(0.0, 1.00, 0.001) var walk_tilt_amount: float = 0.05
@export_range(0.0, 1.00, 0.001) var walk_roll_amount: float = 0.02
@export_range(0.0, 1.00, 0.0001) var walk_sway_amount: float = 0.0008

@export_group("Slide Animation Settings")
@export_range(0.0, 0.3, 0.001) var slide_tilt_amount: float = 0.08
@export_range(0.0, 0.2, 0.001) var slide_roll_amount: float = 0.05
@export_range(0.0, 0.15, 0.001) var slide_lower_amount: float = 0.06

@export_group("Crouch Animation Settings")
@export_range(0.0, 0.2, 0.001) var crouch_tilt_amount: float = 0.04
@export_range(0.0, 0.1, 0.001) var crouch_roll_amount: float = 0.02
@export_range(0.0, 0.15, 0.001) var crouch_lower_amount: float = 0.05
@export_range(0.0, 0.1, 0.001) var crouch_center_amount: float = 0.03

@export_group("Dash Animation Settings")
@export_range(0.0, 0.5, 0.001) var dash_tilt_back: float = 0.15
@export_range(0.0, 0.2, 0.001) var dash_roll_amount: float = 0.04
@export_range(0.0, 0.5, 0.001) var dash_zoom_amount: float = 0.15
@export_range(0.05, 0.3, 0.01) var dash_zoom_time: float = 0.15
@export_range(0.2, 1.0, 0.05) var dash_return_time: float = 0.4

@export_group("Mantle Animation Settings")
@export_range(0.0, 0.3, 0.001) var mantle_tilt_forward: float = 0.12
@export_range(0.0, 0.8, 0.001) var mantle_lower_max: float = 0.6
@export var mantle_animation_curve: Curve


func _ready() -> void:
	# assert(pla != null, "PLA node not found in viewmodel camera!")
	
	if pla:
		pla_base_position = pla.position
		pla_base_rotation = pla.rotation
	
	# Deferred player reference to avoid race condition
	call_deferred("_setup_player_reference")
	
	_initialize_mantle_curve()


func _setup_player_reference() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player:
		state_machine = player.get_node_or_null("StateMachine")
		
		# Signal connections
		if player.start_slide.connect(_on_slide_start) != OK:
			push_warning("Failed to connect start_slide signal")
		if player.end_slide.connect(_on_slide_end) != OK:
			push_warning("Failed to connect end_slide signal")
		if player.has_signal("start_mantle"):
			player.start_mantle.connect(_on_mantle_start)
		if player.has_signal("end_mantle"):
			player.end_mantle.connect(_on_mantle_end)
		if player.has_signal("start_dash"):
			player.start_dash.connect(_on_dash_start)
		if player.has_signal("end_dash"):
			player.end_dash.connect(_on_dash_end)
	else:
		push_error("Player node not found in 'player' group!")


func _initialize_mantle_curve() -> void:
	if not mantle_animation_curve:
		mantle_animation_curve = Curve.new()
		mantle_animation_curve.add_point(Vector2(0.0, 0.0))
		mantle_animation_curve.add_point(Vector2(0.5, 1.0))
		mantle_animation_curve.add_point(Vector2(0.8, 0.8))
		mantle_animation_curve.add_point(Vector2(1.0, 0.0))


func _process(delta: float) -> void:
	if not is_instance_valid(pla):
		return
	
	_update_state_flags()
	_update_all_animations(delta)
	_apply_transforms(delta)


func _update_state_flags() -> void:
	if not player or not is_instance_valid(player):
		return
	
	state_flags.crouching = player.is_crouching
	
	# State machine checks (fallback if no signals)
	if state_machine and is_instance_valid(state_machine) and state_machine.current_state:
		var current_state = state_machine.current_state
		var state_name = current_state.name
		
		# Only update if signals didn't already set the flags
		if not player.has_signal("start_mantle"):
			state_flags.mantling = (state_name == "MantleState")
		if not player.has_signal("start_dash"):
			state_flags.dashing = (state_name == "DashState")


func _update_all_animations(delta: float) -> void:
	_update_land_bob(delta)
	_update_fall_offset(delta)
	_update_slide_animation(delta)
	_update_crouch_animation(delta)
	_update_dash_animation(delta)
	_update_mantle_animation(delta)


func _apply_transforms(delta: float) -> void:
	var y_offset = _calculate_y_offset()
	# Unified position update
	var target_pos := Vector3(
		pla_base_position.x + offsets.bob_x + offsets.walk_sway + offsets.crouch_x,
		pla_base_position.y + _calculate_y_offset(),
		pla_base_position.z + offsets.dash_z
	)
	
		
	pla.position = pla.position.lerp(target_pos, LERP_SPEED_SLOW * delta)
	
	# Unified rotation update
	pla.rotation = Vector3(
		pla_base_rotation.x + rotations.walk_tilt + rotations.slide_tilt + 
		rotations.crouch_tilt + rotations.dash_tilt + rotations.mantle_tilt,
		pla_base_rotation.y,
		pla_base_rotation.z + rotations.walk_roll + rotations.slide_roll + 
		rotations.crouch_roll + rotations.dash_roll
	)



func _calculate_y_offset() -> float:
	var base_offset: float = offsets.land + offsets.slide_y + offsets.crouch_y
	if state_flags.mantling:
		return base_offset + offsets.mantle_y
	
	# In air - use fall offset
	if not player.is_on_floor():
		return base_offset + offsets.fall
	
	# On ground - use walk/bob
	return base_offset + offsets.walk_y + offsets.bob_y

func sway(sway_amount: Vector2) -> void:
	if not is_instance_valid(pla):
		return
	pla.position.x -= sway_amount.x * 0.0001
	pla.position.y += sway_amount.y * 0.00014


func bob(speed: float, delta: float) -> void:
	if not is_instance_valid(pla):
		return
	
	if state_flags.sliding or state_flags.dashing or state_flags.mantling:
		_reset_bob_smoothly(delta)
		return
	
	if speed > 0.1:
		bob_timer += delta * bob_speed
		var speed_normalized = clamp(speed / 15.0, 0.0, 1.0)
		var crouch_mult = 0.5 if state_flags.crouching else 1.0
		
		var intensity_y = bob_vertical_intensity * clamp(speed / 10.0, 0.5, 1.5) * crouch_mult
		var intensity_x = bob_horizontal_intensity * clamp(speed / 10.0, 0.5, 1.5) * crouch_mult
		
		# Accumulate instead of direct modification
		offsets.bob_y = sin(bob_timer) * intensity_y
		offsets.bob_x = sin(bob_timer * 0.5) * intensity_x
		
		rotations.walk_tilt = lerp(rotations.walk_tilt, walk_tilt_amount * speed_normalized, delta * 15.0)
		rotations.walk_roll = lerp(rotations.walk_roll, sin(bob_timer * 0.5) * walk_roll_amount * speed_normalized, delta * 8.0)
		offsets.walk_y = lerp(offsets.walk_y, -walk_lower_amount * speed_normalized, delta * 5.0)
		offsets.walk_sway = lerp(offsets.walk_sway, sin(bob_timer * 0.5) * walk_sway_amount * speed_normalized, delta * 8.0)
	else:
		_reset_bob_smoothly(delta)


func _reset_bob_smoothly(delta: float) -> void:
	bob_timer = lerp(bob_timer, 0.0, delta * 5.0)
	offsets.bob_y = lerp(offsets.bob_y, 0.0, delta * 8.0)
	offsets.bob_x = lerp(offsets.bob_x, 0.0, delta * 8.0)
	rotations.walk_tilt = lerp(rotations.walk_tilt, 0.0, delta * 8.0)
	rotations.walk_roll = lerp(rotations.walk_roll, 0.0, delta * 8.0)
	offsets.walk_y = lerp(offsets.walk_y, 0.0, delta * 8.0)
	offsets.walk_sway = lerp(offsets.walk_sway, 0.0, delta * 8.0)


func _update_slide_animation(delta: float) -> void:
	if state_flags.sliding:
		rotations.slide_tilt = lerp(rotations.slide_tilt, slide_tilt_amount, delta * 6.0)
		rotations.slide_roll = lerp(rotations.slide_roll, slide_roll_amount, delta * 6.0)
		offsets.slide_y = lerp(offsets.slide_y, -slide_lower_amount, delta * 6.0)
	else:
		if is_zero_approx(rotations.slide_tilt) and is_zero_approx(rotations.slide_roll) and is_zero_approx(offsets.slide_y):
			return
		rotations.slide_tilt = lerp(rotations.slide_tilt, 0.0, delta * 8.0)
		rotations.slide_roll = lerp(rotations.slide_roll, 0.0, delta * 8.0)
		offsets.slide_y = lerp(offsets.slide_y, 0.0, delta * 8.0)


func _update_crouch_animation(delta: float) -> void:
	if state_flags.crouching and not state_flags.sliding:
		rotations.crouch_tilt = lerp(rotations.crouch_tilt, crouch_tilt_amount, delta * 8.0)
		rotations.crouch_roll = lerp(rotations.crouch_roll, crouch_roll_amount, delta * 8.0)
		offsets.crouch_y = lerp(offsets.crouch_y, -crouch_lower_amount, delta * 8.0)
		offsets.crouch_x = lerp(offsets.crouch_x, crouch_center_amount, delta * 8.0)
	else:
		if is_zero_approx(rotations.crouch_tilt) and is_zero_approx(offsets.crouch_y):
			return
		rotations.crouch_tilt = lerp(rotations.crouch_tilt, 0.0, delta * 10.0)
		rotations.crouch_roll = lerp(rotations.crouch_roll, 0.0, delta * 10.0)
		offsets.crouch_y = lerp(offsets.crouch_y, 0.0, delta * 10.0)
		offsets.crouch_x = lerp(offsets.crouch_x, 0.0, delta * 10.0)


func _update_dash_animation(delta: float) -> void:
	if state_flags.dashing:
		dash_timer += delta
		var zoom_progress = min(dash_timer / dash_zoom_time, 1.0)
		var eased_zoom = ease(zoom_progress, -2.0)
		
		rotations.dash_tilt = dash_tilt_back * eased_zoom
		rotations.dash_roll = dash_roll_amount * eased_zoom
		offsets.dash_z = dash_zoom_amount * eased_zoom
	else:
		if is_zero_approx(rotations.dash_tilt) and is_zero_approx(offsets.dash_z):
			return
		rotations.dash_tilt = lerp(rotations.dash_tilt, 0.0, delta * (1.0 / dash_return_time) * 5.0)
		rotations.dash_roll = lerp(rotations.dash_roll, 0.0, delta * (1.0 / dash_return_time) * 5.0)
		offsets.dash_z = lerp(offsets.dash_z, 0.0, delta * (1.0 / dash_return_time) * 5.0)


func _update_fall_offset(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return
	
	var velocity_y = player.velocity.y
	# Reset fall offset when mantling
	if state_flags.mantling:
		offsets.fall = lerp(offsets.fall, 0.0, delta * LERP_SPEED_FAST)
		return
	
	if velocity_y < -1.0:
		var fall_amount = clamp(-velocity_y * 0.014, 0.0, 0.5)
		offsets.fall = lerp(offsets.fall, fall_amount, delta * 1.0)
	elif velocity_y > 0.5:
		var jump_amount = clamp(-velocity_y * 0.01, -0.1, 0.0)
		offsets.fall = lerp(offsets.fall, jump_amount, delta * 2.0)
	else:
		offsets.fall = lerp(offsets.fall, 0.0, delta * 5.0)


func _update_mantle_animation(delta: float) -> void:
	if not state_flags.mantling:
		# Synchronized reset speed with position lerp
		if is_zero_approx(rotations.mantle_tilt) and is_zero_approx(offsets.mantle_y):
			mantle_progress = 0.0
			return
		rotations.mantle_tilt = lerp(rotations.mantle_tilt, 0.0, delta * LERP_SPEED_SLOW)
		offsets.mantle_y = lerp(offsets.mantle_y, 0.0, delta * LERP_SPEED_SLOW)
		mantle_progress = 0.0
		return
	
	if not state_machine or not is_instance_valid(state_machine) or not state_machine.current_state:
		return
	
	var mantle_state = state_machine.current_state
	if mantle_state.name != "MantleState":
		return
	
	# Safe property access using get() instead of has()
	var timer = mantle_state.get("mantle_timer")
	var duration = mantle_state.get("mantle_duration")
	
	# Check if properties exist (get() returns null if missing)
	if timer == null or duration == null:
		return
	
	if duration > 0.0:
		mantle_progress = clamp(timer / duration, 0.0, 1.0)
	
	var curve_value = mantle_animation_curve.sample(mantle_progress) if mantle_animation_curve else mantle_progress
	
	rotations.mantle_tilt = mantle_tilt_forward * curve_value
	offsets.mantle_y = -mantle_lower_max * curve_value



func land_bob(intensity: float) -> void:
	land_strength = clamp(intensity * 3.0, 0.01, 0.7)
	land_time = 0.0



func _update_land_bob(delta: float) -> void:
	if land_time < LAND_DURATION:
		land_time += delta
		var t = min(land_time / LAND_DURATION, 1.0)
		offsets.land = -sin(t * PI) * land_strength
	elif not is_zero_approx(offsets.land):
		offsets.land = 0.0


func free_fall(velocity_y: float, _delta: float) -> void:
	# Deprecated - now handled in _update_fall_offset
	pass


func reset_free_fall() -> void:
	offsets.fall = 0.0


# Signal handlers
func _on_slide_start() -> void:
	state_flags.sliding = true


func _on_slide_end() -> void:
	state_flags.sliding = false


func _on_mantle_start() -> void:
	state_flags.mantling = true
	# Force reset conflicting offsets
	offsets.fall = 0.0
	offsets.land = 0.0
	land_time = LAND_DURATION


func _on_mantle_end() -> void:
	state_flags.mantling = false
	# Suppress land bob on next landing
	land_time = LAND_DURATION


func _on_dash_start() -> void:
	state_flags.dashing = true
	dash_timer = 0.0


func _on_dash_end() -> void:
	state_flags.dashing = false
	
	
func jump_kick(intensity: float = 0.08) -> void:
	# Легкий толчок рук вниз при прыжке
	land_strength = intensity
	land_time = 0.0
	
func anim_event_spawn():
	print("🔥 АНИМАЦИЯ ВЫЗВАЛА ФУНКЦИЮ!") # <-- ПРОВЕРКА 4
	on_attack_point.emit()

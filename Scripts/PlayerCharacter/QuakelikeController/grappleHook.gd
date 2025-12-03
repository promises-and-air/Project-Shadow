extends Node
class_name GrappleHook

# ==============================================================================
# 🔗 ССЫЛКИ
# ==============================================================================
@export_group("References - Core")
@export var player: CharacterBody3D
@export var ray: RayCast3D
@export var hook_origin: Node3D         # Marker3D в РУКЕ ИГРОКА

@export_group("References - Cameras")
@export var main_camera: Camera3D       # Основная камера
@export var view_model_camera: Camera3D # Камера рук

# ==============================================================================
# 🎨 ВИЗУАЛ
# ==============================================================================
@export_group("Visuals")
@export var beam_scene: PackedScene
@export var hand_scene: PackedScene
@export var impact_vfx: PackedScene

# ==============================================================================
# ⚙️ ФИЗИКА
# ==============================================================================
@export_group("Physics")
@export var stiffness: float = 15.0
@export var maxRestFraction: float = 0.9
@export var minRestFraction: float = 0.1
@export var restLengthCurve: ProceduralCurve
@export var projectile_speed: float = 70.0 

# ==============================================================================
# 🎥 СОЧНЫЕ ЭФФЕКТЫ (JUICE) - НОВОЕ!
# ==============================================================================
@export_group("Camera Juice")
@export var launch_fov_add: float = 15.0    # Насколько расширить FOV при полете
@export var launch_roll: float = 2.5        # Наклон камеры (градусы) при полете
@export var recoil_angle: float = 4.0       # Кивок вверх при УДАРЕ
@export var impact_shake: float = 0.1       # Тряска при ударе

# ==============================================================================
# 🔧 ВНУТРЕННИЕ ПЕРЕМЕННЫЕ
# ==============================================================================
var launched: bool = false
var is_flying: bool = false
var target: Vector3 = Vector3.ZERO
var restLength: float = 5.0
var _default_fov: float = 75.0

# Инстансы
var _current_beam_instance: Node3D = null
var _current_hand_instance: Node3D = null

# Твины для эффектов
var _cam_tween: Tween

func _ready() -> void:
	process_priority = 100
	if main_camera:
		_default_fov = main_camera.fov

func _physics_process(delta: float) -> void:
	if is_flying:
		_handle_projectile_flight(delta)
	elif launched:
		_handle_pulling_physics(delta)

func _process(_delta: float) -> void:
	if is_flying or launched:
		_update_visuals()

# ==============================================================================
# 🎮 ЛОГИКА
# ==============================================================================
func launch() -> void:
	ray.force_raycast_update()
	
	if ray.is_colliding():
		target = ray.get_collision_point()
		is_flying = true
		launched = false
		
		_spawn_visuals()
		
		# --- ЭФФЕКТ ЗАПУСКА ---
		# Не делаем отдачу здесь! Только искажение скорости.
		_apply_launch_feedback()

func retract() -> void:
	if not (launched or is_flying): return
	launched = false
	is_flying = false
	player.floor_snap_length = 0.4
	_cleanup_visuals()
	
	# Плавный возврат камеры в норму
	_reset_camera_feedback()

func isLaunched() -> bool:
	return launched or is_flying

func can_hook() -> bool:
	ray.force_raycast_update()
	return ray.is_colliding()

# ==============================================================================
# ✈️ ПОЛЕТ РУКИ (ИСПРАВЛЕНО)
# ==============================================================================
func _handle_projectile_flight(delta: float) -> void:
	if not is_instance_valid(_current_hand_instance):
		retract()
		return

	var current_pos = _current_hand_instance.global_position
	
	# Сначала проверяем дистанцию. Если мы уже почти там - сразу засчитываем попадание.
	# Это предотвращает попытку move_toward или look_at в ту же самую точку.
	if current_pos.distance_to(target) < 0.2: # Чуть увеличил порог для надежности
		_current_hand_instance.global_position = target # Доводим до идеала
		_on_hook_hit()
		return # ВАЖНО: Выходим из функции, чтобы не выполнять код ниже

	# Если мы еще далеко - летим
	var next_pos = current_pos.move_toward(target, projectile_speed * delta)
	_current_hand_instance.global_position = next_pos
	
	# Безопасный поворот: смотрим на цель, только если до нее больше 1 см
	if next_pos.distance_to(target) > 0.01:
		_current_hand_instance.look_at(target)

func _on_hook_hit() -> void:
	is_flying = false
	launched = true 
	
	# Физика
	player.floor_snap_length = 0.0
	var dist = player.global_position.distance_to(target)
	restLength = dist * maxRestFraction
	if restLengthCurve:
		restLengthCurve.set_targets(dist * minRestFraction, restLength)
		restLengthCurve.start()

	# --- ЭФФЕКТ УДАРА ---
	# Вот тут мы даем отдачу, когда игрок чувствует "сцепку"
	_apply_impact_feedback()

	# VFX
	if impact_vfx:
		var vfx = impact_vfx.instantiate()
		get_tree().current_scene.add_child(vfx)
		vfx.global_position = target
		var normal = ray.get_collision_normal()
		if normal.length() > 0.01:
			vfx.look_at(target + normal)

# ==============================================================================
# 🧲 ФИЗИКА ТЯГИ
# ==============================================================================
func _handle_pulling_physics(delta: float) -> void:
	var target_dir = player.global_position.direction_to(target)
	var current_dist = player.global_position.distance_to(target)
	
	if restLengthCurve:
		if restLengthCurve.is_running():
			restLength = restLengthCurve.step(delta)
		elif "min" in restLengthCurve.targets:
			restLength = restLengthCurve.targets["min"]
	
	var displacement = current_dist - restLength
	var magnitude = max(0.0, displacement * stiffness)
	var force = target_dir * magnitude
	player.velocity += force * delta

# ==============================================================================
# 🎥 CINE-JUICE (Эффекты камеры)
# ==============================================================================

# 1. ЗАПУСК: Экран отдаляется, камера кренится
func _apply_launch_feedback() -> void:
	if not main_camera: return
	if _cam_tween: _cam_tween.kill()
	_cam_tween = create_tween().set_parallel(true)
	
	# Увеличиваем FOV (Эффект варп-скорости)
	_cam_tween.tween_property(main_camera, "fov", _default_fov + launch_fov_add, 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Наклоняем камеру (Roll) немного влево (так как левая рука)
	_cam_tween.tween_property(main_camera, "rotation_degrees:z", launch_roll, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# 2. УДАР: Резкий рывок вверх, сброс FOV
func _apply_impact_feedback() -> void:
	if not main_camera: return
	if _cam_tween: _cam_tween.kill()
	_cam_tween = create_tween().set_parallel(true)
	
	# Резкий возврат FOV (с небольшим овершутом для удара)
	_cam_tween.tween_property(main_camera, "fov", _default_fov, 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Возврат наклона (Roll) в 0
	_cam_tween.tween_property(main_camera, "rotation_degrees:z", 0.0, 0.2)
	
	# --- ОТДАЧА (RECOIL) ---
	# Создаем последовательный твин для кивка (не параллельный)
	var recoil_tween = create_tween()
	# Резко вверх
	recoil_tween.tween_property(main_camera, "rotation_degrees:x", main_camera.rotation_degrees.x + recoil_angle, 0.05)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# Плавно обратно
	recoil_tween.chain().tween_property(main_camera, "rotation_degrees:x", main_camera.rotation_degrees.x, 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# 3. ВОЗВРАТ: Если отпустили крюк раньше времени
func _reset_camera_feedback() -> void:
	if not main_camera: return
	if _cam_tween: _cam_tween.kill()
	_cam_tween = create_tween().set_parallel(true)
	
	_cam_tween.tween_property(main_camera, "fov", _default_fov, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_property(main_camera, "rotation_degrees:z", 0.0, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# ==============================================================================
# 🎨 ВИЗУАЛ
# ==============================================================================
func _get_player_hand_position() -> Vector3:
	if hook_origin and main_camera and view_model_camera:
		var screen_pos = view_model_camera.unproject_position(hook_origin.global_position)
		return main_camera.project_position(screen_pos, 0.5)
	if hook_origin: return hook_origin.global_position
	return player.global_position

func _update_visuals() -> void:
	if not is_instance_valid(_current_beam_instance): return
	
	var start_pos = _get_player_hand_position()
	var end_pos = target
	if is_instance_valid(_current_hand_instance):
		end_pos = _current_hand_instance.global_position
		if launched:
			_current_hand_instance.look_at(start_pos)

	_current_beam_instance.global_position = start_pos
	_current_beam_instance.look_at(end_pos)
	
	var dist = start_pos.distance_to(end_pos)
	_current_beam_instance.scale = Vector3(1.0, 1.0, dist)
	
	if _current_beam_instance is GeometryInstance3D:
		_current_beam_instance.set_instance_shader_parameter("beam_length", dist)

func _spawn_visuals() -> void:
	if hand_scene:
		_current_hand_instance = hand_scene.instantiate()
		get_tree().current_scene.add_child(_current_hand_instance)
		_current_hand_instance.global_position = _get_player_hand_position()
		_current_hand_instance.look_at(target)

	if beam_scene:
		_current_beam_instance = beam_scene.instantiate()
		get_tree().current_scene.add_child(_current_beam_instance)

func _cleanup_visuals() -> void:
	if is_instance_valid(_current_hand_instance):
		_current_hand_instance.queue_free()
		_current_hand_instance = null
	if is_instance_valid(_current_beam_instance):
		_current_beam_instance.queue_free()
		_current_beam_instance = null

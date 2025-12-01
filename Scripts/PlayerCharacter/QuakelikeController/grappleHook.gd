extends Node
class_name GrappleHook

# ==============================================================================
# 🔗 ССЫЛКИ (ОБЯЗАТЕЛЬНО ЗАПОЛНИТЬ В ИНСПЕКТОРЕ)
# ==============================================================================
@export_group("References - Core")
@export var player: CharacterBody3D
@export var ray: RayCast3D
@export var hook_origin: Node3D         # Marker3D внутри BoneAttachment (в руках)

@export_group("References - Cameras (Fix for ViewModel)")
@export var main_camera: Camera3D       # Твоя основная камера мира
@export var view_model_camera: Camera3D # Камера, которая рендерит руки

# ==============================================================================
# 🎨 ВИЗУАЛ (SCENES)
# ==============================================================================
@export_group("Visuals - Scenes")
@export var beam_scene: PackedScene     # Сцена веревки/луча
@export var hand_scene: PackedScene     # Сцена "клешни" (летит в стену)
@export var impact_vfx: PackedScene     # Искры при ударе

# ==============================================================================
# ⚙️ НАСТРОЙКИ ФИЗИКИ
# ==============================================================================
@export_group("Physics Settings")
@export var stiffness: float = 15.0     # Сила пружины. Ставь больше (10-20) для резкого рывка
@export var maxRestFraction: float = 0.9
@export var minRestFraction: float = 0.1 # 0.1 = притягивать почти вплотную
@export var restLengthCurve: ProceduralCurve # Твой ресурс кривой

# ==============================================================================
# 🔧 ВНУТРЕННИЕ ПЕРЕМЕННЫЕ
# ==============================================================================
var launched: bool = false
var target: Vector3 = Vector3.ZERO
var restLength: float = 5.0

# Инстансы визуалов
var _current_beam_instance: Node3D = null
var _current_hand_instance: Node3D = null

# ==============================================================================
# 🚀 ИНИЦИАЛИЗАЦИЯ
# ==============================================================================
func _ready() -> void:
	# ОЧЕНЬ ВАЖНО: Ставим высокий приоритет, чтобы веревка обновлялась
	# ПОСЛЕ того, как анимация рук передвинет кости. Это убирает дрожание.
	process_priority = 100 

func _physics_process(delta: float) -> void:
	if launched:
		_handle_physics(delta)

func _process(_delta: float) -> void:
	# Обновляем визуал каждый кадр (даже между физическими шагами) для плавности
	if launched:
		_update_visuals()

# ==============================================================================
# 🎮 ЛОГИКА (Launch / Retract)
# ==============================================================================
func launch() -> void:
	ray.force_raycast_update()
	
	if ray.is_colliding():
		target = ray.get_collision_point()
		launched = true
		
		# Чтобы крюк мог оторвать игрока от земли мгновенно
		player.floor_snap_length = 0.0
		
		# --- ФИЗИКА ---
		var dist = player.global_position.distance_to(target)
		restLength = dist * maxRestFraction
		
		# Запуск твоей кривой
		if restLengthCurve:
			restLengthCurve.set_targets(dist * minRestFraction, restLength)
			restLengthCurve.start()
		
		# --- СПАВН ЭФФЕКТОВ ---
		_spawn_visuals()

func retract() -> void:
	if not launched: return
	launched = false
	player.floor_snap_length = 0.4 # Возвращаем прилипание к полу (для лестниц/спусков)
	
	_cleanup_visuals()

func isLaunched() -> bool:
	return launched

func can_hook() -> bool:
	ray.force_raycast_update()
	return ray.is_colliding()

# ==============================================================================
# 🧲 ФИЗИКА (РАБОЧАЯ ВЕРСИЯ С КРИВОЙ)
# ==============================================================================
func _handle_physics(delta: float) -> void:
	var target_dir = player.global_position.direction_to(target)
	var current_dist = player.global_position.distance_to(target)
	
	# Обновляем длину веревки через ProceduralCurve
	if restLengthCurve:
		if restLengthCurve.is_running():
			restLength = restLengthCurve.step(delta)
		elif "min" in restLengthCurve.targets:
			restLength = restLengthCurve.targets["min"]
	
	# Закон Гука (Пружина)
	var displacement = current_dist - restLength
	var magnitude = 0.0
	
	if displacement > 0:
		magnitude = displacement * stiffness
	
	var force = target_dir * magnitude
	
	# Применяем силу к скорости игрока
	player.velocity += force * delta

# ==============================================================================
# 🎨 ВИЗУАЛ (С ИСПРАВЛЕНИЕМ FOV)
# ==============================================================================
func _update_visuals() -> void:
	if not is_instance_valid(_current_beam_instance):
		return

	# --- 1. ВЫЧИСЛЕНИЕ ТОЧКИ НАЧАЛА (Dual Camera Fix) ---
	var final_start_pos: Vector3
	
	# Если у нас есть обе камеры и точка привязки
	if hook_origin and main_camera and view_model_camera:
		# Берем 3D точку на оружии -> Превращаем в 2D пиксель экрана (через камеру рук)
		var screen_pos = view_model_camera.unproject_position(hook_origin.global_position)
		
		# Берем этот 2D пиксель -> Превращаем обратно в 3D точку мира (через главную камеру)
		# 0.5 - это глубина (расстояние от глаз). Если веревка проходит сквозь камеру, увеличь до 1.0
		final_start_pos = main_camera.project_position(screen_pos, 0.5)
	else:
		# Если камер нет, просто берем позицию игрока или маркера (как раньше)
		final_start_pos = player.global_position
		if hook_origin: final_start_pos = hook_origin.global_position

	var end_pos = target

	# --- 2. ОБНОВЛЕНИЕ ЛУЧА ---
	_current_beam_instance.global_position = final_start_pos
	_current_beam_instance.look_at(end_pos)
	
	var dist = final_start_pos.distance_to(end_pos)
	
	# Растягиваем веревку (Scale Z)
	_current_beam_instance.scale = Vector3(1.0, 1.0, dist)
	
	# Если используется ShaderMaterial
	if _current_beam_instance is GeometryInstance3D:
		_current_beam_instance.set_instance_shader_parameter("beam_length", dist)

	# --- 3. ОБНОВЛЕНИЕ КЛЕШНИ НА СТЕНЕ ---
	if is_instance_valid(_current_hand_instance):
		# Клешня смотрит на веревку
		_current_hand_instance.look_at(final_start_pos)

# ==============================================================================
# ✨ ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ СПАВНА
# ==============================================================================
func _spawn_visuals() -> void:
	# Спавн клешни
	if hand_scene:
		_current_hand_instance = hand_scene.instantiate()
		get_tree().current_scene.add_child(_current_hand_instance)
		_current_hand_instance.global_position = target
		# Изначально смотрит на игрока
		_current_hand_instance.look_at(player.global_position)

	# Спавн веревки
	if beam_scene:
		_current_beam_instance = beam_scene.instantiate()
		get_tree().current_scene.add_child(_current_beam_instance)
		
	# Спавн искр (один раз)
	if impact_vfx:
		var vfx = impact_vfx.instantiate()
		get_tree().current_scene.add_child(vfx)
		vfx.global_position = target
		var normal = ray.get_collision_normal()
		if normal.length() > 0.01:
			vfx.look_at(target + normal)

func _cleanup_visuals() -> void:
	if is_instance_valid(_current_hand_instance):
		_current_hand_instance.queue_free()
		_current_hand_instance = null
	if is_instance_valid(_current_beam_instance):
		_current_beam_instance.queue_free()
		_current_beam_instance = null

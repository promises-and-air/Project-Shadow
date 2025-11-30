extends Node
class_name DemonCombatSystem

# ==============================================================================
# 🛠 НАСТРОЙКИ И ССЫЛКИ
# ==============================================================================
@export_group("References")
@export var animation_tree: AnimationTree
@export var grapple_controller: GrappleHook
@export var player_camera: Camera3D 
@export var camera_shaker: Node3D 
@export var viewmodel_node: Node3D
@export_group("Magic System")
@export var current_spell: SpellConfig  # <--- Твой ресурс заклинания (FireMagic.tres)
@export var magic_origin: Node3D        # Точка вылета (рука)
@export var shot_delay: float = 0.1
# ==============================================================================
# ⚙️ ВНУТРЕННИЕ ПЕРЕМЕННЫЕ
# ==============================================================================
# Имена анимаций в StateMachine (Точно как ты просил)
const ANIM_CHARGE_START = "fire_hold"    # Начало замаха
const ANIM_CHARGE_LOOP  = "fire_idle"    # Удержание (Loop)
const ANIM_ATTACK       = "fire_release" # Выстрел
# Анимации левой руки
const ANIM_HOOK_THROW   = "hook_throw"
const ANIM_HOOK_RETRACT = "hook_release"
const ANIM_DASH         = "dash"

# Пути в AnimationTree
const RIGHT_HAND_PATH = "parameters/RightHand_SM/playback"
const LEFT_HAND_PATH = "parameters/LeftHand_SM/playback"

var right_hand_playback: AnimationNodeStateMachinePlayback
var left_hand_playback: AnimationNodeStateMachinePlayback

# Состояния логики
var is_hooking: bool = false
var is_charging_magic: bool = false
var magic_charge_start_time: float = 0.0
signal magic_ui_update(charge_ratio: float, cooldown_ratio: float)
# Данные для следующего выстрела (храним между отпусканием кнопки и спавном)
var _next_shot_data: ProjectileData = null 

# Камера и Твины
var fov_tween: Tween
var camera_tween: Tween
var default_fov: float = 75.0
var default_camera_rot_x: float = 0.0 # Для возврата отдачи

# ==============================================================================
# 🔄 БАЗОВЫЕ МЕТОДЫ (READY / PROCESS)
# ==============================================================================
func _ready() -> void:
	# Ждем кадр, чтобы дерево инициализировалось
	await get_tree().process_frame
	print("🔍 ПОИСК VIEWMODEL...") # <-- ПРОВЕРКА 1
	if animation_tree:
		right_hand_playback = animation_tree.get(RIGHT_HAND_PATH)
		left_hand_playback = animation_tree.get(LEFT_HAND_PATH)
	
	if player_camera:
		default_fov = player_camera.fov
		default_camera_rot_x = player_camera.rotation_degrees.x
	else:
		push_warning("⚠️ DemonCombatSystem: Не назначена камера!")
	if viewmodel_node:
		print("✅ VIEWMODEL НАЙДЕНА!") # <-- ПРОВЕРКА 2
		if viewmodel_node.has_signal("on_attack_point"):
			viewmodel_node.on_attack_point.connect(spawn_projectile_event)
			print("✅ СИГНАЛ ПОДКЛЮЧЕН УСПЕШНО") # <-- ПРОВЕРКА 3
		else:
			print("❌ ОШИБКА: У ViewModel нет сигнала on_attack_point!")
	else:
		print("❌ ОШИБКА: Переменная viewmodel_node ПУСТАЯ! (Не назначена в Инспекторе)")
		
		
func _process(delta: float) -> void:
	_handle_input()
	
	# Логика отпускания кнопок
	if Input.is_action_just_released("fire_attack"):
		_finish_charging_magic()
		
	if Input.is_action_just_released("hook_shot"):
		_release_hook()
	_update_ui_signals()
	
func _handle_input() -> void:
	# Логика нажатия кнопок
	if Input.is_action_just_pressed("fire_attack"):
		_start_charging_magic()
		
	if Input.is_action_just_pressed("hook_shot"):
		_try_hook()
		
	if Input.is_action_just_pressed("demon_dash"):
		_try_dash()

# ==============================================================================
# 🔥 ЛОГИКА МАГИИ (CHARGE -> RELEASE)
# ==============================================================================

func _start_charging_magic() -> void:
	if not current_spell: return
	
	is_charging_magic = true
	magic_charge_start_time = Time.get_ticks_msec() / 1000.0
	
	# 1. Запускаем анимацию ЗАМАХА (fire_hold)
	# Дерево само перейдет в fire_idle по окончании анимации (Switch Mode: AtEnd)
	right_hand_playback.travel(ANIM_CHARGE_START)
	
	# 2. Начинаем плавный зум
	_start_fov_zoom(current_spell.fov_zoom_amount, current_spell.charge_duration)

func _finish_charging_magic() -> void:
	if not is_charging_magic or not current_spell: return
	
	is_charging_magic = false
	var hold_duration = (Time.get_ticks_msec() / 1000.0) - magic_charge_start_time
	
	# 1. Выбираем снаряд
	var is_charged = hold_duration >= current_spell.charge_time_required
	if is_charged:
		_next_shot_data = current_spell.heavy_shot
	else:
		_next_shot_data = current_spell.light_shot
		
	_end_fov_zoom(is_charged)
	
	# 2. Запускаем анимацию
	if right_hand_playback:
		right_hand_playback.travel(ANIM_ATTACK)
	
	# 3. 💥 ВМЕСТО Call Method Track: Создаем одноразовый таймер
	# Он вызовет функцию спавна ровно через shot_delay секунд
	get_tree().create_timer(shot_delay).timeout.connect(spawn_projectile_event)

# 🛠️ ГЛАВНАЯ ФУНКЦИЯ - Вызывается из AnimationPlayer (Call Method Track)
func spawn_projectile_event() -> void:
	# Проверка безопасности: если мы вдруг умерли или сменили оружие за эти 0.15 сек
	if not is_instance_valid(magic_origin): return 
	if not _next_shot_data: return
	
	# ... (Тут весь твой код спавна, который уже был) ...
	print("🚀 ВЫСТРЕЛ ПО ТАЙМЕРУ!") # Для проверки
	
	# 1. Эффекты
	_play_camera_shake(_next_shot_data.camera_shake_name)
	_apply_recoil(_next_shot_data.recoil_amount, _next_shot_data.recoil_time)
	
	# 2. Спавн
	if _next_shot_data.projectile_scene:
		var proj = _next_shot_data.projectile_scene.instantiate()
		get_tree().current_scene.add_child(proj)
		proj.global_position = magic_origin.global_position
		proj.look_at(_get_crosshair_target())
		if proj.has_method("setup"):
			proj.setup(_next_shot_data)

# ==============================================================================
# 🎥 ЭФФЕКТЫ КАМЕРЫ (FOV, RECOIL, SHAKE)
# ==============================================================================

func _apply_recoil(amount: float, time: float) -> void:
	if not player_camera: return
	
	# Резкий кивок вверх и плавный возврат
	var tween = create_tween()
	# Кивок вверх (очень быстро)
	tween.tween_property(player_camera, "rotation_degrees:x", default_camera_rot_x + amount, 0.05)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Возврат
	tween.chain().tween_property(player_camera, "rotation_degrees:x", default_camera_rot_x, time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _start_fov_zoom(amount: float, duration: float) -> void:
	if not player_camera: return
	if fov_tween and fov_tween.is_valid(): fov_tween.kill()
	fov_tween = create_tween()
	
	var target_fov = default_fov - amount
	fov_tween.tween_property(player_camera, "fov", target_fov, duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _end_fov_zoom(is_charged: bool) -> void:
	if not player_camera: return
	if fov_tween and fov_tween.is_valid(): fov_tween.kill()
	fov_tween = create_tween()
	
	# Если заряжен - возврат резче (отдача)
	var dur = 0.2 if is_charged else 0.25
	var trans = Tween.TRANS_BACK if is_charged else Tween.TRANS_CUBIC
	
	fov_tween.tween_property(player_camera, "fov", default_fov, dur)\
		.set_trans(trans).set_ease(Tween.EASE_OUT)

func _play_camera_shake(anim_name: String) -> void:
	if not camera_shaker: return
	
	if camera_tween and camera_tween.is_valid(): camera_tween.kill()
	camera_tween = get_tree().create_tween()
	
	# Простые процедурные анимации тряски
	match anim_name:
		"magic_light":
			camera_tween.tween_property(camera_shaker, "position", Vector3(0, 0, 0.05), 0.05)
			camera_tween.chain().tween_property(camera_shaker, "position", Vector3.ZERO, 0.2)
		"magic_heavy":
			camera_tween.tween_property(camera_shaker, "position", Vector3(0, 0, 0.2), 0.1).set_trans(Tween.TRANS_BOUNCE)
			camera_tween.parallel().tween_property(camera_shaker, "rotation_degrees", Vector3(2.0, 0, 0), 0.1)
			camera_tween.chain().tween_property(camera_shaker, "position", Vector3.ZERO, 0.4)
			camera_tween.parallel().tween_property(camera_shaker, "rotation_degrees", Vector3.ZERO, 0.4)
			
func _update_ui_signals() -> void:
	var charge_val: float = 0.0
	var cd_val: float = 0.0
	
	# Расчет заряда (если сейчас заряжаем)
	if is_charging_magic and current_spell:
		var time_held = (Time.get_ticks_msec() / 1000.0) - magic_charge_start_time
		# Считаем от 0.0 до 1.0 (заполнено)
		charge_val = clamp(time_held / current_spell.charge_time_required, 0.0, 1.0)
	
	# Расчет кулдауна (если он у тебя есть, пока передаем 0.0)
	# Если добавишь таймер кулдауна, считай его тут: cd_val = timer.time_left / timer.wait_time
	
	# Отправляем данные в UI
	magic_ui_update.emit(charge_val, cd_val)
# ==============================================================================
# 🎯 ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (HOOK & AIM)
# ==============================================================================

func _get_crosshair_target() -> Vector3:
	if not player_camera:
		if magic_origin: return magic_origin.global_position - magic_origin.global_transform.basis.z * 10.0
		return Vector3.ZERO
		
	var viewport_center = get_viewport().get_visible_rect().size / 2.0
	var from = player_camera.project_ray_origin(viewport_center)
	var dir = player_camera.project_ray_normal(viewport_center)
	var to = from + dir * 1000.0
	
	var space = get_parent().get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self, get_parent()] 
	
	var result = space.intersect_ray(query)
	if result: return result.position
	else: return to

func _try_hook() -> void:
	if not grapple_controller: return
	if not grapple_controller.can_hook(): return
	is_hooking = true
	if left_hand_playback:
		left_hand_playback.travel(ANIM_HOOK_THROW)
		# Тут можно оставить таймер, так как это не боевая магия
		await get_tree().create_timer(0.16).timeout
		if Input.is_action_pressed("hook_shot") and is_hooking:
			grapple_controller.launch()

func _release_hook() -> void:
	if not is_hooking: return
	is_hooking = false
	if grapple_controller and grapple_controller.isLaunched(): grapple_controller.retract()
	if left_hand_playback: left_hand_playback.travel(ANIM_HOOK_RETRACT)

func _try_dash() -> void:
	if left_hand_playback: left_hand_playback.travel(ANIM_DASH)

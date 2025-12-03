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
@export var combat_ui: CanvasLayer # Ссылка на UI (CombatHUD)

@export_group("Magic System")
@export var available_spells: Array[SpellConfig] # 👈 Перетащи сюда FireMagic.tres и LightningMagic.tres
@export var magic_origin: Node3D                 # Точка вылета (рука)
@export var shot_delay: float = 0.1              # Задержка перед спавном

# ==============================================================================
# ⚙️ ВНУТРЕННИЕ ПЕРЕМЕННЫЕ
# ==============================================================================
# Текущий активный спелл
var current_spell: SpellConfig

# Пути в AnimationTree
const RIGHT_HAND_PATH = "parameters/RightHand_SM/playback"
const LEFT_HAND_PATH = "parameters/LeftHand_SM/playback"
var right_hand_playback: AnimationNodeStateMachinePlayback
var left_hand_playback: AnimationNodeStateMachinePlayback

# Анимации левой руки (всегда одинаковые)
const ANIM_HOOK_THROW   = "hook_throw"
const ANIM_HOOK_RETRACT = "hook_release"
const ANIM_DASH         = "dash"

# Состояния
var is_hooking: bool = false
var is_charging_magic: bool = false
var magic_charge_start_time: float = 0.0

# Сигналы
signal magic_ui_update(charge_ratio: float, cooldown_ratio: float)

# Данные выстрела и эффекты
var _next_shot_data: ProjectileData = null 
var _active_charge_vfx: Node3D = null

var fov_tween: Tween
var camera_tween: Tween
var default_fov: float = 75.0
var default_camera_rot_x: float = 0.0 

# ==============================================================================
# 🔄 БАЗОВЫЕ МЕТОДЫ
# ==============================================================================
func _ready() -> void:
	await get_tree().process_frame
	
	if animation_tree:
		right_hand_playback = animation_tree.get(RIGHT_HAND_PATH)
		left_hand_playback = animation_tree.get(LEFT_HAND_PATH)
	
	if player_camera:
		default_fov = player_camera.fov
		default_camera_rot_x = player_camera.rotation_degrees.x

	if viewmodel_node:
		if viewmodel_node.has_signal("on_attack_point"):
			viewmodel_node.on_attack_point.connect(spawn_projectile_event)
			
	# Выбираем первый спелл при старте
	equip_spell(0)

func _process(delta: float) -> void:
	# Используем polling для стрельбы (надежнее для FPS)
	_handle_combat_input()
	_update_ui_signals()

func _unhandled_input(event: InputEvent) -> void:
	# Переключение оружия (1 и 2)
	if event.is_action_pressed("weapon_1"):
		equip_spell(0)
	if event.is_action_pressed("weapon_2"):
		equip_spell(1)

func _handle_combat_input() -> void:
	# --- МАГИЯ (Правая рука) ---
	if Input.is_action_just_pressed("fire_attack"):
		_start_charging_magic()
		
	if Input.is_action_just_released("fire_attack"):
		_finish_charging_magic()
		
	# --- КРЮК (Левая рука) ---
	if Input.is_action_just_pressed("hook_shot"):
		_try_hook()
		
	if Input.is_action_just_released("hook_shot"):
		_release_hook()
		
	# --- ДЭШ ---
	if Input.is_action_just_pressed("demon_dash"):
		_try_dash()

# ==============================================================================
# ⚔️ СМЕНА ОРУЖИЯ
# ==============================================================================
func equip_spell(index: int) -> void:
	if index < 0 or index >= available_spells.size(): return
	if current_spell == available_spells[index]: return # Уже надето
	
	# Сброс текущей зарядки, если меняем во время каста
	if is_charging_magic:
		is_charging_magic = false
		if is_instance_valid(_active_charge_vfx): _active_charge_vfx.queue_free()
		_end_fov_zoom(false)
		if right_hand_playback: right_hand_playback.stop() # Или переходим в Idle

	current_spell = available_spells[index]
	print("Equipped spell: ", current_spell)
	
	# Обновляем UI иконок
	if combat_ui and combat_ui.has_method("update_selection"):
		combat_ui.update_selection(index)

# ==============================================================================
# 🔥 ЛОГИКА МАГИИ (CHARGE -> RELEASE)
# ==============================================================================
func _start_charging_magic() -> void:
	if not current_spell: return
	
	is_charging_magic = true
	magic_charge_start_time = Time.get_ticks_msec() / 1000.0
	
	# ✅ ИГРАЕМ АНИМАЦИЮ ИЗ РЕСУРСА
	if right_hand_playback and current_spell.anim_name_start != "":
		right_hand_playback.travel(current_spell.anim_name_start)
		
	_start_fov_zoom(current_spell.fov_zoom_amount, current_spell.charge_duration)
	
	# VFX зарядки
	if current_spell.charge_vfx_scene and magic_origin:
		if is_instance_valid(_active_charge_vfx): _active_charge_vfx.queue_free()
		_active_charge_vfx = current_spell.charge_vfx_scene.instantiate()
		magic_origin.add_child(_active_charge_vfx)
		_active_charge_vfx.scale = Vector3.ZERO

func _finish_charging_magic() -> void:
	if not is_charging_magic or not current_spell: return
	
	if is_instance_valid(_active_charge_vfx):
		_active_charge_vfx.queue_free()
		_active_charge_vfx = null
		
	is_charging_magic = false
	var hold_duration = (Time.get_ticks_msec() / 1000.0) - magic_charge_start_time
	
	# Выбираем Light или Heavy версию снаряда
	var is_charged = hold_duration >= current_spell.charge_time_required
	if is_charged:
		_next_shot_data = current_spell.heavy_shot
	else:
		_next_shot_data = current_spell.light_shot
		
	_end_fov_zoom(is_charged)
	
	# ✅ АНИМАЦИЯ ВЫСТРЕЛА ИЗ РЕСУРСА
	if right_hand_playback and current_spell.anim_name_release != "":
		right_hand_playback.travel(current_spell.anim_name_release)
	
	# Таймер
	get_tree().create_timer(shot_delay).timeout.connect(spawn_projectile_event)

# 🛠️ СПАВН СНАРЯДА
func spawn_projectile_event() -> void:
	if not is_instance_valid(magic_origin) or not _next_shot_data: return
	
	_play_camera_shake(_next_shot_data.camera_shake_name)
	_apply_recoil(_next_shot_data.recoil_amount, _next_shot_data.recoil_time)
	
	if _next_shot_data.projectile_scene:
		var proj = _next_shot_data.projectile_scene.instantiate()
		get_tree().current_scene.add_child(proj)
		proj.global_position = magic_origin.global_position
		proj.look_at(_get_crosshair_target())
		
		if proj.has_method("setup"):
			proj.setup(_next_shot_data)

# ==============================================================================
# 🎥 ЭФФЕКТЫ (FOV, Recoil, Shake)
# ==============================================================================
func _apply_recoil(amount: float, time: float) -> void:
	if not player_camera: return
	var tween = create_tween()
	tween.tween_property(player_camera, "rotation_degrees:x", default_camera_rot_x + amount, 0.05)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
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
	var dur = 0.2 if is_charged else 0.25
	var trans = Tween.TRANS_BACK if is_charged else Tween.TRANS_CUBIC
	fov_tween.tween_property(player_camera, "fov", default_fov, dur)\
		.set_trans(trans).set_ease(Tween.EASE_OUT)

func _play_camera_shake(anim_name: String) -> void:
	if not camera_shaker: return
	if camera_tween and camera_tween.is_valid(): camera_tween.kill()
	
	camera_shaker.position = Vector3.ZERO
	camera_shaker.rotation_degrees = Vector3.ZERO
	camera_tween = get_tree().create_tween()
	
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
	
	if is_charging_magic and current_spell:
		var time_held = (Time.get_ticks_msec() / 1000.0) - magic_charge_start_time
		charge_val = clamp(time_held / current_spell.charge_time_required, 0.0, 1.0)
		
		if is_instance_valid(_active_charge_vfx):
			var target_scale = Vector3.ONE * charge_val 
			if charge_val >= 1.0:
				target_scale += Vector3.ONE * sin(Time.get_ticks_msec() * 0.01) * 0.1
			_active_charge_vfx.scale = target_scale
	
	magic_ui_update.emit(charge_val, cd_val)

# ==============================================================================
# 🎯 ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
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
	if not grapple_controller or not grapple_controller.can_hook(): return
	is_hooking = true
	if left_hand_playback:
		left_hand_playback.travel(ANIM_HOOK_THROW)
		await get_tree().create_timer(0.2).timeout
		if Input.is_action_pressed("hook_shot") and is_hooking:
			grapple_controller.launch()

func _release_hook() -> void:
	if not is_hooking: return
	is_hooking = false
	if grapple_controller and grapple_controller.isLaunched(): grapple_controller.retract()
	if left_hand_playback: left_hand_playback.travel(ANIM_HOOK_RETRACT)

func _try_dash() -> void:
	if left_hand_playback: left_hand_playback.travel(ANIM_DASH)

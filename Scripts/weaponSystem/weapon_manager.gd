extends Node3D
class_name WeaponManager

# ==============================================================================
# 📡 СИГНАЛЫ
# ==============================================================================
signal magic_ui_update(charge_ratio: float, cooldown_ratio: float)
signal inventory_changed(slots: Array, active_index: int)

# ==============================================================================
# 🛠 ЭКСПОРТЫ (НАСТРОЙКИ)
# ==============================================================================
@export_group("References")
@export var anim_tree: AnimationTree
@export var hitbox_sync: WeaponHitboxSync
@export var camera_shaker: Node3D
@export var weapon_slot: BoneAttachment3D

@export_group("Starting Loadout")
@export var starting_weapon_1: WeaponData
@export var starting_weapon_2: WeaponData

@export_group("Magic Settings")
@export var magic_projectile_scene: PackedScene
@export var magic_cooldown: float = 0.1
@export var magic_charged_cooldown_mult: float = 5.0 # Множитель кулдауна для сильного удара

@export_group("Camera FX (Zoom)")
@export var charge_fov_amount: float = 15.0 
@export var charge_duration: float = 1.5 

# ==============================================================================
# ⚙️ ВНУТРЕННИЕ ПЕРЕМЕННЫЕ
# ==============================================================================
# --- Логика Магии ---
var can_cast_magic: bool = true # (Можно удалить, т.к. используем таймер, но оставим для совместимости)
var magic_charge_start_time: float = 0.0
const MAGIC_CHARGE_THRESHOLD: float = 0.6
var is_charging_magic: bool = false 
var magic_next_attack_time: float = 0.0 
var last_cooldown_duration: float = 1.0 

# --- Логика Камеры ---
var default_world_fov: float = 75.0
var fov_tween: Tween
var world_camera: Camera3D 
var camera_tween: Tween

# --- Логика Оружия ---
var root_playback: AnimationNodeStateMachinePlayback
var armed_playback: AnimationNodeStateMachinePlayback

const INPUT_ATTACK = "attack"
const INPUT_WEAPON_1 = "weapon_1"
const INPUT_WEAPON_2 = "weapon_2"
const INPUT_WEAPON_3 = "weapon_3" 
const INPUT_DROP = "drop"
const WEAPON_PICKUP_SCENE = preload("res://Scenes/weapons/weapon_pickup.tscn")

const INVENTORY_SIZE: int = 3
var weapon_slots: Array[WeaponData] = []
var current_slot_index: int = 0
var current_weapon_data: WeaponData = null
var current_weapon_node = null
var queued_weapon_data: WeaponData = null

# --- Комбо система ---
var can_combo: bool = false
var attack_buffered: bool = false
var current_combo_step: int = 0
@onready var buffer_timer: Timer = $BufferTimer


# ==============================================================================
# 🔄 БАЗОВЫЕ МЕТОДЫ GODOT
# ==============================================================================
func _ready() -> void:
	weapon_slots.resize(INVENTORY_SIZE)
	weapon_slots[0] = starting_weapon_1
	weapon_slots[1] = starting_weapon_2
	weapon_slots[2] = null 
	current_slot_index = 0
	
	await get_tree().process_frame
	root_playback = anim_tree.get("parameters/playback")
	
	_find_world_camera()
	
	if weapon_slots[0]:
		current_weapon_data = weapon_slots[0]
		try_equip_weapon(current_weapon_data)
	
	inventory_changed.emit(weapon_slots, current_slot_index)


func _process(_delta: float) -> void:
	# 1. ВСЕГДА обновляем UI (даже если анимация не готова)
	_update_magic_ui()

	# 2. Проверка анимаций
	if armed_playback == null:
		if root_playback.get_current_node() == "Armed_Stance":
			armed_playback = anim_tree.get("parameters/Armed_Stance/playback")
		else:
			# Даже если не в стойке, читаем инпут (для смены оружия и т.д.)
			_read_input()
			return

	if root_playback.get_current_node() != "Armed_Stance":
		armed_playback = null
		return

	# 3. Логика комбо
	var current_state = armed_playback.get_current_node()
	if current_state == "Sword_Idle":
		if current_combo_step != 0:
			_reset_combo_state()
		if attack_buffered:
			try_attack()
	
	# 4. Чтение ввода
	_read_input()


# ==============================================================================
# 🎮 ЛОГИКА ВВОДА
# ==============================================================================
func _read_input() -> void:
	var time_now = Time.get_ticks_msec() / 1000.0
	var on_cooldown = time_now < magic_next_attack_time
	
	# --- АТАКА / МАГИЯ ---
	if Input.is_action_just_pressed(INPUT_ATTACK):
		# Если есть меч -> Бьем мечом
		if current_weapon_data != null:
			try_attack() 
		
		# Если нет меча -> Магия
		elif current_weapon_data == null:
			if on_cooldown: return # Ждем кулдаун
			
			is_charging_magic = true
			magic_charge_start_time = time_now
			
			_start_fov_zoom() # Запускаем зум

	if Input.is_action_just_released(INPUT_ATTACK):
		if current_weapon_data == null:
			if not is_charging_magic: return # Игнорируем, если зарядка не начиналась
			
			is_charging_magic = false 
			var hold_duration = time_now - magic_charge_start_time
			var is_charged = hold_duration >= MAGIC_CHARGE_THRESHOLD
			
			_end_fov_zoom(is_charged) # Возвращаем зум
			cast_magic(is_charged)

	# --- ИНВЕНТАРЬ ---
	if Input.is_action_just_pressed(INPUT_WEAPON_1): switch_to_slot(0)
	if Input.is_action_just_pressed(INPUT_WEAPON_2): switch_to_slot(1)
	if Input.is_action_just_pressed(INPUT_WEAPON_3): switch_to_slot(2)
	if Input.is_action_just_pressed(INPUT_DROP): drop_current_weapon()


func _update_magic_ui() -> void:
	var time_now = Time.get_ticks_msec() / 1000.0
	
	# Расчет зарядки (0.0 -> 1.0)
	var charge_ratio = 0.0
	if is_charging_magic:
		var hold_time = time_now - magic_charge_start_time
		charge_ratio = clamp(hold_time / MAGIC_CHARGE_THRESHOLD, 0.0, 1.0)
	
	# Расчет кулдауна (1.0 -> 0.0)
	var cooldown_ratio = 0.0
	if time_now < magic_next_attack_time:
		var time_left = magic_next_attack_time - time_now
		cooldown_ratio = clamp(time_left / last_cooldown_duration, 0.0, 1.0)
		
	magic_ui_update.emit(charge_ratio, cooldown_ratio)


# ==============================================================================
# ✨ СИСТЕМА МАГИИ
# ==============================================================================
func cast_magic(is_charged: bool) -> void:
	if not magic_projectile_scene: return
	
	# Визуал камеры
	if is_charged:
		_play_camera_shake("magic_heavy") 
		print("🔥 BIG FIREBALL!")
	else:
		_play_camera_shake("magic_light") 
		print("✨ Small fireball")

	# Спавн снаряда
	var projectile = magic_projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	
	var spawn_ref = world_camera if world_camera else get_viewport().get_camera_3d()
	var spawn_pos = spawn_ref.global_position - (spawn_ref.global_transform.basis.z * 1.0)
	projectile.global_position = spawn_pos
	projectile.global_rotation = spawn_ref.global_rotation
	
	if projectile.has_method("setup_projectile"):
		projectile.setup_projectile(is_charged)

	# --- РАСЧЕТ КУЛДАУНА ---
	var current_cd = magic_cooldown 
	if is_charged:
		current_cd = magic_cooldown * magic_charged_cooldown_mult
	
	last_cooldown_duration = current_cd
	magic_next_attack_time = (Time.get_ticks_msec() / 1000.0) + current_cd


# ==============================================================================
# 🎥 ЭФФЕКТЫ КАМЕРЫ (FOV и Shake)
# ==============================================================================
func _start_fov_zoom() -> void:
	if not world_camera: return
	if fov_tween and fov_tween.is_valid(): fov_tween.kill()
	
	fov_tween = create_tween()
	var current_fov = world_camera.fov
	var target_fov = default_world_fov + charge_fov_amount
	var distance = abs(target_fov - current_fov)
	var max_distance = charge_fov_amount
	
	var real_duration = clamp((distance / max_distance) * charge_duration, 0.2, charge_duration)
	
	fov_tween.tween_property(world_camera, "fov", target_fov, real_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _end_fov_zoom(is_charged: bool) -> void:
	if not world_camera: return
	if fov_tween and fov_tween.is_valid(): fov_tween.kill()
	fov_tween = create_tween()
	
	if is_charged:
		fov_tween.tween_property(world_camera, "fov", default_world_fov, 0.4)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		fov_tween.tween_property(world_camera, "fov", default_world_fov + 2.5, 0.05)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fov_tween.chain().tween_property(world_camera, "fov", default_world_fov, 0.25)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _play_camera_shake(animation_name: StringName) -> void:
	if not camera_shaker: return
	if camera_tween and camera_tween.is_valid(): camera_tween.kill()
	camera_tween = get_tree().create_tween()
	
	match animation_name:
		&"magic_light":
			camera_tween.tween_property(camera_shaker, "position", Vector3(0, 0, 0.05), 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			camera_tween.parallel().tween_property(camera_shaker, "rotation_degrees", Vector3(1.0, 0, 0), 0.05)
			camera_tween.chain().tween_property(camera_shaker, "position", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			camera_tween.parallel().tween_property(camera_shaker, "rotation_degrees", Vector3.ZERO, 0.2)
		&"magic_heavy":
			camera_tween.tween_property(camera_shaker, "position", Vector3(0, 0, 0.25), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			camera_tween.parallel().tween_property(camera_shaker, "rotation_degrees", Vector3(4.0, 0, 0), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			camera_tween.chain().tween_property(camera_shaker, "position", Vector3.ZERO, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			camera_tween.parallel().tween_property(camera_shaker, "rotation_degrees", Vector3.ZERO, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# ... твои старые анимации ударов ...


# ==============================================================================
# 🔧 ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ==============================================================================
func _find_world_camera() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player: return
	world_camera = _find_camera_recursive(player)
	if world_camera:
		default_world_fov = world_camera.fov

func _find_camera_recursive(node: Node) -> Camera3D:
	for child in node.get_children():
		if child is Camera3D:
			if child.get_script() and "playerCamera" in child.get_script().resource_path:
				return child
			return child
		var result = _find_camera_recursive(child)
		if result: return result
	return null

# ==============================================================================
# ⚔️ ЛОГИКА ОРУЖИЯ И ИНВЕНТАРЯ
# ==============================================================================
func switch_to_slot(index: int) -> void:
	var target_data = weapon_slots[index]
	if current_weapon_data == target_data:
		if root_playback.get_current_node() == "Armed_Stance": return
		elif root_playback.get_current_node() == "Equipping" and queued_weapon_data == target_data: return
	if target_data == null and current_weapon_data == null:
		if root_playback.get_current_node() != "Equipping": return
			
	current_slot_index = index
	if target_data == null: try_unequip_weapon()
	else: try_equip_weapon(target_data)
	inventory_changed.emit(weapon_slots, current_slot_index)

func try_attack() -> void:
	if armed_playback == null: return
	var current_state = armed_playback.get_current_node()
	if current_state == "Sword_Idle":
		buffer_timer.stop()
		armed_playback.travel("Light_Attack")
		current_combo_step = 1
		can_combo = false
		attack_buffered = false
	elif can_combo:
		buffer_timer.stop()
		can_combo = false
		attack_buffered = false
		if current_combo_step == 1:
			armed_playback.travel("Medium_Attack")
			current_combo_step = 2
		elif current_combo_step == 2:
			armed_playback.travel("Heavy_Attack")
			current_combo_step = 3
		elif current_combo_step == 3:
			armed_playback.travel("Light_Attack")
			current_combo_step = 1
	elif current_state.begins_with("Light") or current_state.begins_with("Medium") or current_state.begins_with("Heavy"):
		attack_buffered = true
		buffer_timer.start()

func try_equip_weapon(weapon_to_equip: WeaponData) -> void:
	var current_root_state = root_playback.get_current_node()
	if queued_weapon_data == weapon_to_equip and current_root_state == "Equipping": return
	queued_weapon_data = weapon_to_equip
	if hitbox_sync: hitbox_sync.set_weapon_data(queued_weapon_data)
	if current_root_state == "Armed_Stance":
		_destroy_weapon_mesh()
		current_weapon_data = null
		root_playback.travel("Equipping")
	elif current_root_state != "Equipping":
		root_playback.travel("Equipping")
	elif current_root_state == "Equipping":
		root_playback.travel("Equipping")

func try_unequip_weapon() -> void:
	var current_root_state = root_playback.get_current_node()
	if queued_weapon_data == null and current_root_state == "Unequipping": return
	queued_weapon_data = null
	if hitbox_sync: hitbox_sync.set_weapon_data(null)
	root_playback.travel("Unequipping")

func _on_equip_animation_finished() -> void:
	_destroy_weapon_mesh()
	if not queued_weapon_data:
		current_weapon_data = null
		weapon_slots[current_slot_index] = null
		inventory_changed.emit(weapon_slots, current_slot_index)
		return
	current_weapon_node = queued_weapon_data.weapon_scene.instantiate()
	weapon_slot.add_child(current_weapon_node)
	current_weapon_data = queued_weapon_data
	weapon_slots[current_slot_index] = queued_weapon_data
	queued_weapon_data = null
	inventory_changed.emit(weapon_slots, current_slot_index)

func _on_unequip_animation_started() -> void:
	_destroy_weapon_mesh()
	current_weapon_data = null
	weapon_slots[current_slot_index] = null
	inventory_changed.emit(weapon_slots, current_slot_index)
	if queued_weapon_data != null and root_playback.get_current_node() == "Unequipping":
		root_playback.travel("Equipping")

func _on_combo_window_open() -> void:
	can_combo = true
	if attack_buffered:
		buffer_timer.stop()
		try_attack()

func _on_combo_window_close() -> void:
	can_combo = false

func _on_hitbox_activate(damage_mult: float, hit_stop: float, shake: float, knockback: float) -> void:
	if hitbox_sync:
		hitbox_sync.activate_hitbox(current_combo_step, damage_mult, hit_stop, shake, knockback)

func _on_hitbox_deactivate() -> void:
	if hitbox_sync: hitbox_sync.deactivate_hitbox()

func drop_current_weapon() -> void:
	var data_to_drop = current_weapon_data
	if data_to_drop == null: return
	var pickup = WEAPON_PICKUP_SCENE.instantiate() as WeaponPickup
	pickup.weapon_data = data_to_drop
	var player_body = get_tree().get_first_node_in_group("player")
	var player_node = player_body as PlayerMovement
	var final_drop_position: Vector3
	if not is_instance_valid(player_node) or not player_node.is_inside_tree():
		final_drop_position = self.global_position + (self.global_transform.basis.z * -2.0)
	else:
		var fwd_dir = player_node.global_transform.basis.z
		fwd_dir.y = 0
		fwd_dir = fwd_dir.normalized()
		var ray_start = player_node.global_position + (fwd_dir * -1.5) + (Vector3.UP * 2.0)
		var ray_end = ray_start + (Vector3.DOWN * 100.0)
		var space = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.exclude = [player_node]
		query.collision_mask = 4 
		var result = space.intersect_ray(query)
		if result: final_drop_position = result.position
		else: final_drop_position = player_node.global_position + (fwd_dir * -1.5)
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = final_drop_position
	weapon_slots[current_slot_index] = null
	try_unequip_weapon() 
	inventory_changed.emit(weapon_slots, current_slot_index)

func try_pickup_weapon(pickup: WeaponPickup) -> void:
	if not pickup or not pickup.weapon_data: return
	var data_to_pickup = pickup.weapon_data
	var data_to_drop = weapon_slots[current_slot_index] 
	weapon_slots[current_slot_index] = data_to_pickup
	try_equip_weapon(data_to_pickup)
	if data_to_drop:
		var new_pickup = WEAPON_PICKUP_SCENE.instantiate() as WeaponPickup
		new_pickup.weapon_data = data_to_drop
		get_tree().current_scene.add_child(new_pickup)
		new_pickup.global_position = pickup.global_position
	pickup.queue_free()
	inventory_changed.emit(weapon_slots, current_slot_index)

func _destroy_weapon_mesh() -> void:
	if current_weapon_node and is_instance_valid(current_weapon_node):
		current_weapon_node.queue_free()
		current_weapon_node = null
	for child in weapon_slot.get_children():
		child.queue_free()

func _reset_combo_state() -> void:
	can_combo = false
	attack_buffered = false 
	current_combo_step = 0
	buffer_timer.stop()

func _on_buffer_timer_timeout() -> void:
	attack_buffered = false

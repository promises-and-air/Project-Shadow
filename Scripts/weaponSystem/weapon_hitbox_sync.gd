extends Node3D
class_name WeaponHitboxSync

# ==============================================================================
# ⬇️ Свойства с @onready
# ==============================================================================
@onready var hitbox: Area3D = $Hitbox
@onready var camera: Camera3D = get_viewport().get_camera_3d()

# ==============================================================================
# ⬇️ Внутренние переменные
# ==============================================================================
var current_weapon_data: WeaponData = null # 💡 Используем WeaponData
var is_attacking: bool = false
var hitbox_shape: CollisionShape3D = null
var hit_enemies: Array[Node] = []
var player_node: PlayerMovement = null
var current_combo_index: int = -1

var current_damage_mult: float = 1.0
var current_hit_stop: float = 0.0
var current_shake: float = 1.0
var current_knockback: float = 1.0

const DAMAGE_NUMBER = preload("res://Scenes/UI scenes/damage_number.tscn")
var damage_number_parent: Node = null

# ==============================================================================
# ⬇️ НАСТРОЙКИ (Константы и Экспорты)
# ==============================================================================
@export_group("Combat Settings")
@export var base_damage: int = 10 # 💡 Используется, если WeaponData не задан
@export var base_knockback_force: float = 5.0

@export_group("Damage Numbers")
@export var damage_number_offset: Vector3 = Vector3(0, 1.5, 0)
@export var damage_number_enabled: bool = true

@export_group("Debug")
@export var debug_mode: bool = false
@export var debug_draw_hitbox: bool = false
@export var debug_print_hits: bool = true

# ==============================================================================
# ⬇️ Godot Lifecycle Methods
# ==============================================================================

func _ready() -> void:
	player_node = get_tree().get_first_node_in_group("player") as PlayerMovement

	if not player_node:
		push_error("WeaponHitboxSync: PlayerMovement not found!")
	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_area_entered, CONNECT_DEFERRED)
		hitbox.monitoring = false
		print("DEBUG: WeaponHitboxSync УСПЕШНО ЗАГРУЖЕН.") # DEBUG
	else:
		push_error("❌ Hitbox Area3D not found!")
	
	if not camera:
		push_warning("⚠️ Camera not found in Viewport!")
	
	damage_number_parent = get_tree().current_scene
	if not damage_number_parent:
		damage_number_parent = get_tree().root.get_child(0)
	
	if debug_draw_hitbox:
		_create_debug_mesh()

func _physics_process(_delta: float) -> void:
	if not camera:
		return
	global_position = camera.global_position
	global_rotation = camera.global_rotation

# ==============================================================================
# ⬇️ Public API
# ==============================================================================

# 💡 Принимаем WeaponData
func set_weapon_data(data: WeaponData) -> void:
	current_weapon_data = data
	
	if data:
		_create_hitbox_for_weapon()
		if debug_mode: print("✅ Weapon data set: ", data.weapon_name)
	else:
		_clear_hitbox()

func activate_hitbox(combo_index: int, damage_mult: float, hit_stop: float, shake: float, knockback: float) -> void:
	if is_attacking:
		push_warning("Attempted to activate hitbox while already attacking.")
		return
		
	is_attacking = true
	if is_instance_valid(player_node):
		player_node.is_melee_attacking = true
	current_combo_index = combo_index
	
	current_damage_mult = damage_mult
	current_hit_stop = hit_stop
	current_shake = shake
	current_knockback = knockback
	
	if hitbox:
		print("DEBUG: Хитбокс ВКЛЮЧЕН (monitoring = true). Жду попаданий...") # DEBUG
		hitbox.monitoring = true
	
	hit_enemies.clear()

func deactivate_hitbox() -> void:
	if not is_attacking:
		return
		
	is_attacking = false
	if is_instance_valid(player_node):
		player_node.is_melee_attacking = false
	if hitbox:
		print("DEBUG: Хитбокс ВЫКЛЮЧЕН (monitoring = false)") # DEBUG
		hitbox.monitoring = false
	print("==========================================") # DEBUG

# ==============================================================================
# ⬇️ Private Methods - Hitbox Management
# ==============================================================================
func _create_hitbox_for_weapon() -> void:
	_clear_hitbox()
	var attack_range = 1.5
	
	if current_weapon_data:
		attack_range = current_weapon_data.attack_range
	
	hitbox_shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = attack_range
	hitbox_shape.shape = sphere
	hitbox_shape.position = Vector3(0, 0, -attack_range * 0.5) 
	
	hitbox.add_child(hitbox_shape)
	print("DEBUG: CollisionShape3D СОЗДАН. (Range: %f)" % attack_range) # DEBUG
	
	if debug_draw_hitbox:
		var debug_mesh: MeshInstance3D = hitbox.get_node_or_null("DebugHitbox")
		if debug_mesh and debug_mesh.mesh is SphereMesh:
			var sphere_mesh: SphereMesh = debug_mesh.mesh
			sphere_mesh.radius = attack_range
			if debug_mesh.get_parent() == hitbox:
				debug_mesh.position = hitbox_shape.position

func _clear_hitbox() -> void:
	if hitbox_shape and is_instance_valid(hitbox_shape):
		hitbox_shape.queue_free()
		hitbox_shape = null

func _create_debug_mesh() -> void:
	if hitbox.has_node("DebugHitbox"): return
	var debug_mesh = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 1.5 
	debug_mesh.mesh = sphere_mesh
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 0, 0, 0.3)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	debug_mesh.material_override = mat
	
	debug_mesh.name = "DebugHitbox"
	hitbox.add_child(debug_mesh)

# ==============================================================================
# ⬇️ Private Methods - Timers and Hit Stop (Без изменений)
# ==============================================================================

func _apply_local_hit_stop(duration: float) -> void:
	if duration <= 0: return
	await get_tree().create_timer(duration, true, false, true).timeout

func _apply_knockback_delayed(enemy: Node, multiplier: float, delay: float) -> void:
	var enemy_ref = weakref(enemy)
	var camera_ref = weakref(camera)
	
	await get_tree().create_timer(delay, true, false, true).timeout
	
	var enemy_node = enemy_ref.get_ref()
	var camera_node = camera_ref.get_ref()
	
	if not enemy_node or not camera_node:
		return
	
	if enemy_node.has_method("apply_knockback"):
		var knockback_dir = (enemy_node.global_position - camera_node.global_position).normalized()
		var knockback_force = base_knockback_force * multiplier
		enemy_node.apply_knockback(knockback_dir, knockback_force)

# ==============================================================================
# ⬇️ Private Methods - Hit Processing
# ==============================================================================

func _on_hitbox_area_entered(area: Area3D) -> void:
	print("DEBUG: Хитбокс что-то задел! -> " + area.name) # DEBUG
	
	if not is_attacking:
		print("DEBUG: Но is_attacking == false. Игнор.") # DEBUG
		return
		
	if not area.is_in_group("hurtbox"):
		print("DEBUG: Но у " + area.name + " нет группы 'hurtbox'. Игнор.") # DEBUG
		return
	
	var enemy: Node = area.get_parent()
	if not enemy:
		print("DEBUG: У " + area.name + " нет родителя. Игнор.") # DEBUG
		return
		
	if enemy in hit_enemies:
		print("DEBUG: Мы уже попали по " + enemy.name + " этим ударом. Игнор.") # DEBUG
		return
		
	if not is_instance_valid(player_node):
		push_error("Player node is invalid, cannot lunge.")
		return
		
	hit_enemies.append(enemy)
	print("DEBUG: Засчитано попадание по " + enemy.name) # DEBUG
	var lunge_dir = (enemy.global_position - player_node.global_position).normalized()
	# Силу можно вынести в @export
	var lunge_force: float = 2.0 

	player_node.apply_melee_lunge(lunge_dir, lunge_force)
	var health: Health = enemy.get_node_or_null("Health") as Health
	if not health:
		print("DEBUG: ОШИБКА! У " + enemy.name + " нет узла 'Health'. Урон не нанесен.") # DEBUG
		return
		
	# --- Расчёт урона ---
	var weapon_base_damage = base_damage
	
	if current_weapon_data:
		weapon_base_damage = current_weapon_data.damage
	
	var final_damage = int(weapon_base_damage * current_damage_mult)
	
	print("DEBUG: Наношу " + str(final_damage) + " урона!") # DEBUG
	
	# --- ЭФФЕКТЫ ---
	_apply_local_hit_stop(current_hit_stop) 
	
	if camera and camera.has_method("start_hit_shake"):
		camera.start_hit_shake(current_shake) 
	
	if enemy.has_method("apply_stun"):
		enemy.apply_stun(current_hit_stop)
	
	health.take_damage(final_damage)
	
	_apply_knockback_delayed(enemy, current_knockback, current_hit_stop)
	
	_spawn_damage_number(area.global_position, final_damage)

func _spawn_damage_number(pos: Vector3, damage: int) -> void:
	if not damage_number_enabled: return
	
	if not is_instance_valid(damage_number_parent):
		push_error("Damage number parent invalid!")
		damage_number_parent = get_tree().root.get_child(0)
		if not is_instance_valid(damage_number_parent): return
	
	var dmg_number = DAMAGE_NUMBER.instantiate()
	damage_number_parent.add_child(dmg_number)
	dmg_number.global_position = pos + damage_number_offset
	
	if dmg_number.has_method("set_damage"):
		dmg_number.set_damage(damage)

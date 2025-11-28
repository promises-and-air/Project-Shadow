# enemy.gd
extends CharacterBody3D
class_name Enemy

@onready var health: Health = $Health
@onready var hurtbox: Area3D = $Hurtbox

# Параметры движения
const GRAVITY: float = 9.8 

@export var knockback_friction: float = 12.0 # Трение для замедления нокбэка
var pending_knockback: Vector3 = Vector3.ZERO # Импульс, ожидающий применения в _physics_process

# Параметры оглушения (Stun)
var is_stunned: bool = false
var stun_timer: float = 0.0

# Визуальные данные (Flash)
var mesh_data: Array = []
var is_flashing: bool = false
var red_flash_material: StandardMaterial3D = null

var is_burning: bool = false
var burn_timer: float = 0.0
var burn_tick_timer: float = 0.0
var burn_damage_per_tick: int = 5

func _ready() -> void:
	if health:
		health.died.connect(_on_died)
		health.health_changed.connect(_on_health_changed)
		if Engine.is_editor_hint(): return
		print("✅ Enemy spawned: ", name, " | HP: ", health.max_health)
	
	_store_mesh_materials()
	_create_flash_material()

func _physics_process(delta: float) -> void:
	
	# 1. ОБРАБОТКА ОГЛУШЕНИЯ (STUN)
	if is_stunned:
		stun_timer -= delta
		if stun_timer <= 0:
			is_stunned = false
			print("🔓 Enemy unstunned")
		
		# Применяем гравитацию, если в воздухе (чтобы не зависать после вертикального нокбэка)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		else:
			velocity = Vector3.ZERO # Полностью останавливаем на земле
			
		move_and_slide()
		return # Выходим, если оглушен
	
	# 2. ПРИМЕНЕНИЕ PENDING KNOCKBACK ИМПУЛЬСА
	if pending_knockback != Vector3.ZERO:
		velocity += pending_knockback # Применяем импульс к основному вектору
		pending_knockback = Vector3.ZERO
	
	# 3. ПРИМЕНЕНИЕ ГОРИЗОНТАЛЬНОГО ТРЕНИЯ/ТОРМОЖЕНИЯ (для нокбэка)
	var horizontal_velocity: Vector3 = velocity * Vector3(1, 0, 1)
	
	if horizontal_velocity.length_squared() > 0.001:
		# Используем move_toward для замедления горизонтального движения
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, knockback_friction * delta)
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z
	else:
		# Если скорость почти нулевая, обнуляем ее для стабильности
		velocity.x = 0
		velocity.z = 0
		
	# 4. ПРИМЕНЕНИЕ ГРАВИТАЦИИ
	if is_on_floor():
		velocity.y = 0 # Сброс Y-скорости на земле
	else:
		velocity.y -= GRAVITY * delta

	# 5. ДВИЖЕНИЕ
	move_and_slide()

	if is_burning:
		burn_timer -= delta
		burn_tick_timer -= delta
		
		# Каждые 0.5 секунды наносим урон
		if burn_tick_timer <= 0:
			burn_tick_timer = 0.5
			if health:
				health.take_damage(burn_damage_per_tick)
				print("🔥 Enemy burns! HP: ", health.current_health)
				_flash_red() # Используем твою вспышку для визуализации
		
		if burn_timer <= 0:
			is_burning = false
			print("💧 Enemy stopped burning")
# ==============================================================================
# ⬇️ Public API
# ==============================================================================
func apply_burn(duration: float, damage: int) -> void:
	is_burning = true
	burn_timer = duration
	burn_damage_per_tick = damage
	print("🔥 Enemy set on FIRE for ", duration, "s")
	
func apply_stun(duration: float) -> void:
	is_stunned = true
	stun_timer = duration
	velocity = Vector3.ZERO        # Сброс основного вектора
	pending_knockback = Vector3.ZERO # Сброс ожидающего импульса
	
	print("🔒 Enemy stunned for ", duration, "s")

func apply_knockback(direction: Vector3, force: float) -> void:
	# Нокбэк должен применяться, даже если is_stunned = true. 
	# Он будет обработан в _physics_process после окончания stun.
	var kb = direction.normalized() * force
	pending_knockback = kb
	
	print("⬅️ Knockback applied: ", kb)

# ==============================================================================
# ⬇️ Signal Handlers & Visuals (Skipped for brevity, identical to last correction)
# ==============================================================================

func _on_health_changed(current: float, max_value: float) -> void:
	print("💔 Enemy HP: ", current, "/", max_value, " (", int(current/max_value*100), "%)")
	_flash_red()

func _on_died() -> void:
	print("💀 Enemy died: ", name)
	queue_free()

func _create_flash_material() -> void:
	red_flash_material = StandardMaterial3D.new()
	red_flash_material.albedo_color = Color(1.0, 0.2, 0.2)
	red_flash_material.emission_enabled = true
	red_flash_material.emission = Color(1.0, 0.0, 0.0)
	red_flash_material.emission_energy = 1.5
	red_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func _store_mesh_materials() -> void:
	mesh_data.clear()
	_recursive_store_materials(self)

func _recursive_store_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var materials: Array = []
		for i in range(node.mesh.get_surface_count()):
			var mat = node.get_surface_override_material(i)
			if not mat:
				mat = node.mesh.surface_get_material(i)
			materials.append(mat)
		
		mesh_data.append({
			"mesh": node,
			"original_materials": materials
		})
	
	for child in node.get_children():
		_recursive_store_materials(child)

func _flash_red() -> void:
	if is_flashing: return
	
	is_flashing = true
	
	for data in mesh_data:
		var mesh: MeshInstance3D = data["mesh"]
		if not is_instance_valid(mesh): continue
		for i in range(mesh.mesh.get_surface_count()):
			mesh.set_surface_override_material(i, red_flash_material)
	
	var timer = get_tree().create_timer(0.15)
	await timer.timeout
	
	if not is_instance_valid(self): return
	if is_queued_for_deletion(): return
	if not is_inside_tree(): return
	
	for data in mesh_data:
		var mesh: MeshInstance3D = data["mesh"]
		if not is_instance_valid(mesh): continue
		
		var materials: Array = data["original_materials"]
		for i in range(materials.size()):
			mesh.set_surface_override_material(i, materials[i])
	
	is_flashing = false

func _exit_tree() -> void:
	if red_flash_material:
		red_flash_material = null

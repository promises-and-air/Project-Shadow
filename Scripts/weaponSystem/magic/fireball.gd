extends Node3D

# Базовые параметры
var speed: float = 25.0
var damage: int = 35
var knockback_force: float = 10.0
var lifetime: float = 5.0

# Параметры заряда
var is_charged: bool = false # Заряжен ли выстрел?

const DAMAGE_NUMBER_SCENE = preload("res://Scenes/UI scenes/damage_number.tscn")
var hit_objects = []

func _ready() -> void:
	pass

# 🛠️ ФУНКЦИЯ НАСТРОЙКИ (вызывается из WeaponManager перед запуском)
func setup_projectile(_is_charged: bool) -> void:
	is_charged = _is_charged
	
	if is_charged:
		# Если заряжен: Большой, медленный, больно бьет + ПОДЖИГАЕТ
		scale = Vector3(2.5, 2.5, 2.5) # Увеличиваем модель в 2.5 раза
		damage = 70
		speed = 18.0
		knockback_force = 25.0
	else:
		# Если клик: Маленький, быстрый, обычный урон
		scale = Vector3(1.0, 1.0, 1.0)
		damage = 30
		speed = 30.0
		knockback_force = 8.0

func _process(delta: float) -> void:
	global_position -= global_transform.basis.z * speed * delta
	lifetime -= delta
	if lifetime <= 0: queue_free()

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("hurtbox"):
		_try_deal_damage(area.get_parent(), area.global_position)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"): return
	if body is Enemy:
		_try_deal_damage(body, global_position)
	else:
		queue_free()

func _try_deal_damage(target: Node, hit_pos: Vector3) -> void:
	if target in hit_objects: return
	hit_objects.append(target)
	
	# 1. Наносим мгновенный урон
	var health_node = target.get_node_or_null("Health")
	if health_node:
		health_node.take_damage(damage)
		_spawn_damage_number(hit_pos, damage)
	
	# 2. Толкаем
	if target.has_method("apply_knockback"):
		var dir = -global_transform.basis.z.normalized()
		target.apply_knockback(dir, knockback_force)
	
	# 3. 🔥 ЕСЛИ ЗАРЯЖЕН — ПОДЖИГАЕМ!
	if is_charged and target.has_method("apply_burn"):
		# Горит 4 секунды, по 5 урона за тик
		target.apply_burn(4.0, 10)
		_spawn_damage_number(hit_pos + Vector3(0, 0.5, 0), "BURNING!") 

	queue_free()

func _spawn_damage_number(pos: Vector3, value) -> void:
	var dmg = DAMAGE_NUMBER_SCENE.instantiate()
	get_tree().current_scene.add_child(dmg)
	dmg.global_position = pos
	if dmg.has_method("set_damage"):
		dmg.set_damage(value)

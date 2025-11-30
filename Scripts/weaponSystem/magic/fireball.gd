extends Node3D
class_name MagicProjectile

# Состояния жизни снаряда
enum State { FLYING, IMPACTED }

# 🛠 ИСПРАВЛЕНИЕ:
# Было: var current_state: State = State.FLYING
# Стало (просто убери двоеточие и тип):
var current_state = State.FLYING

# Данные (придут из контроллера)
var data: ProjectileData
var current_lifetime: float

const DAMAGE_NUMBER_SCENE = preload("res://Scenes/UI scenes/damage_number.tscn")

# 🛠️ ГЛАВНАЯ ФУНКЦИЯ НАСТРОЙКИ
# Вместо кучи аргументов мы принимаем один пакет данных
func setup(_data: ProjectileData) -> void:
	data = _data
	current_lifetime = data.lifetime
	
	# Применяем размер и визуал
	scale = Vector3.ONE * data.scale
	
	# Важно: если scene не задана в ресурсе, код не упадет
	if not data:
		push_error("Projectile Data is missing!")
		queue_free()

func _process(delta: float) -> void:
	if current_state != State.FLYING: return

	# Движение
	global_position -= global_transform.basis.z * data.speed * delta
	
	# Гравитация (если захочешь сделать гранату)
	if data.gravity_scale > 0:
		global_position.y -= 9.8 * data.gravity_scale * delta * delta
	
	# Таймер смерти
	current_lifetime -= delta
	if current_lifetime <= 0:
		queue_free()

# --- ОБРАБОТКА СТОЛКНОВЕНИЙ ---

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("hurtbox"):
		_handle_impact(area.get_parent(), area.global_position)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"): return # Не бьем себя
	
	if body is Enemy: # Или проверка по группе
		_handle_impact(body, global_position)
	else:
		# Попали в стену -> target = null, но взрыв нужен
		_handle_impact(null, global_position)

# --- ЛОГИКА УДАРА ---

func _handle_impact(target: Node, hit_pos: Vector3) -> void:
	# ЗАЩИТА: Если мы уже взорвались в этом кадре, не взрываемся снова
	if current_state == State.IMPACTED: return
	current_state = State.IMPACTED
	
	# 1. Спавн VFX (взрыва) из Ресурса
	if data.impact_vfx:
		var vfx = data.impact_vfx.instantiate()
		get_tree().current_scene.add_child(vfx)
		vfx.global_position = hit_pos
	
	# 2. Нанесение урона (если есть цель)
	if target:
		_apply_damage_logic(target, hit_pos)
	
	# 3. Удаление
	queue_free()

func _apply_damage_logic(target: Node, hit_pos: Vector3) -> void:
	# Урон
	var health_node = target.get_node_or_null("Health")
	if health_node:
		health_node.take_damage(data.damage)
		_spawn_damage_number(hit_pos, data.damage)
	
	# Отталкивание
	if target.has_method("apply_knockback"):
		var dir = -global_transform.basis.z.normalized()
		target.apply_knockback(dir, data.knockback)
	
	# Поджог (Данные берем из ресурса!)
	if data.burn_duration > 0 and target.has_method("apply_burn"):
		target.apply_burn(data.burn_duration, data.burn_damage)
		_spawn_damage_number(hit_pos + Vector3(0, 0.5, 0), "burn")

func _spawn_damage_number(pos: Vector3, value) -> void:
	var dmg = DAMAGE_NUMBER_SCENE.instantiate()
	get_tree().current_scene.add_child(dmg)
	dmg.global_position = pos
	if dmg.has_method("set_damage"):
		dmg.set_damage(value)

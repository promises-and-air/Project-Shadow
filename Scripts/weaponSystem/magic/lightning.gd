extends Node3D
class_name Lightning

@export var beam_mesh: MeshInstance3D # Ссылка на BoxMesh внутри сцены

const DAMAGE_NUMBER_SCENE = preload("res://Scenes/UI scenes/damage_number.tscn")

var data: ProjectileData
var max_range: float = 50.0

func setup(_data: ProjectileData) -> void:
	data = _data
	var fade_time = data.lifetime if data.lifetime > 0 else 0.3
	_cast_beam(fade_time)

func _cast_beam(fade_time: float) -> void:
	var space_state = get_world_3d().direct_space_state
	var from = global_position
	var to = global_position - global_transform.basis.z * max_range


	var shape = SphereShape3D.new()
	shape.radius = 1.0 * data.scale # Радиус зависит от scale из ресурса (например, 1.0 или 2.5)
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	
	# Настраиваем позицию и поворот "толстого луча"
	var transform = Transform3D()
	transform.origin = from

	# Давай используем motion-cast (протаскивание сферы):
	query.transform = Transform3D.IDENTITY.translated(from)
	query.motion = -global_transform.basis.z * max_range # Вектор движения
	
	query.exclude = [self, get_parent()]
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var ray_query = PhysicsRayQueryParameters3D.create(from, to)
	ray_query.exclude = [self, get_parent()]
	ray_query.collide_with_areas = true
	ray_query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(ray_query)
	var end_point = to 
	
	if result:
		end_point = result.position
		_handle_hit(result.collider, result.position, result.normal)
	
	_draw_visual_beam(from, end_point, fade_time)
	get_tree().create_timer(fade_time).timeout.connect(queue_free)

func _handle_hit(target: Node, hit_pos: Vector3, normal: Vector3) -> void:
	# VFX
	if data.impact_vfx:
		var impact = data.impact_vfx.instantiate()
		get_tree().current_scene.add_child(impact)
		impact.global_position = hit_pos
		if normal != Vector3.UP:
			impact.look_at(hit_pos + normal)
		# Масштабируем взрыв по силе выстрела
		impact.scale = Vector3.ONE * data.scale 
	
	# УРОН
	var actual_target = target
	if target.is_in_group("hurtbox"):
		actual_target = target.get_parent()
	
	var health_node = actual_target.get_node_or_null("Health")
	if health_node:
		health_node.take_damage(data.damage)
		_spawn_damage_number(hit_pos, data.damage)
		
	# Отталкивание
	if actual_target.has_method("apply_knockback"):
		var dir = -global_transform.basis.z.normalized()
		actual_target.apply_knockback(dir, data.knockback)

func _draw_visual_beam(start: Vector3, end: Vector3, duration: float) -> void:
	if not beam_mesh: return
	
	var distance = start.distance_to(end)
	beam_mesh.global_position = start
	beam_mesh.look_at(end)
	beam_mesh.position = Vector3(0, 0, -distance / 2.0)
	beam_mesh.scale.z = distance
	
	# Берем толщину из данных (1.0 для heavy, 0.2 для light)
	var thickness = data.scale 
	beam_mesh.scale.x = thickness
	beam_mesh.scale.y = thickness
	
	# Анимация сужения
	var tween = create_tween()
	tween.tween_property(beam_mesh, "scale:x", 0.0, duration).from(thickness)
	tween.parallel().tween_property(beam_mesh, "scale:y", 0.0, duration).from(thickness)

func _spawn_damage_number(pos: Vector3, value) -> void:
	var dmg = DAMAGE_NUMBER_SCENE.instantiate()
	get_tree().current_scene.add_child(dmg)
	dmg.global_position = pos
	if dmg.has_method("set_damage"):
		dmg.set_damage(value)

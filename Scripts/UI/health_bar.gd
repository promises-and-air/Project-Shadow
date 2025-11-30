extends Node3D

@export var health_node_path: NodePath
@export var bar_width: float = 1.0
@export var bar_height: float = 0.1
@export var offset_y: float = 2.0

var health: Health

var health_pivot: Node3D 
var damage_pivot: Node3D 
var bg_pivot: Node3D 

var health_mat: StandardMaterial3D
var damage_mat: StandardMaterial3D
var visibility_notifier: VisibleOnScreenNotifier3D

func _ready() -> void:
	if health_node_path:
		health = get_node(health_node_path)
	else:
		health = get_parent().get_node_or_null("Health")
	
	if not health:
		push_error("Health node not found!")
		set_process(false) # Отключаем process, если нет здоровья
		return
	
	health.health_changed.connect(_on_health_changed)
	
	_setup_visuals()
	_update_bar(true)

# 🆕 НОВАЯ ФУНКЦИЯ: Поворот всего бара к камере
func _process(_delta: float) -> void:
	var camera = get_viewport().get_camera_3d()
	if camera:
		# 1. Вариант А: Полный поворот (всегда плоско к экрану, как в UI)
		global_rotation = camera.global_rotation
		
		# 2. Вариант Б: Только по вертикальной оси (если хочешь, чтобы не наклонялось вверх-вниз)
		# rotation.y = camera.global_rotation.y

func _setup_visuals() -> void:
	# Сделаем слои еще ближе друг к другу
	bg_pivot = _create_single_bar(Color(0.107, 0.107, 0.107, 1.0), -0.002) 
	damage_pivot = _create_single_bar(Color(0.592, 0.0, 0.0, 1.0), -0.001)
	health_pivot = _create_single_bar(Color(0.0, 0.592, 0.0, 1.0), 0.0) # Сверху
	
	damage_mat = damage_pivot.get_child(0).material_override
	health_mat = health_pivot.get_child(0).material_override

func _create_single_bar(color: Color, z_offset: float) -> Node3D:
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	# Делаем толщину (Z) почти нулевой, чтобы они плотно прилегали
	box.size = Vector3(bar_width, bar_height, 0.001) 
	mesh_inst.mesh = box
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	
	# ❌ УДАЛЕНО: mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# Мы теперь вращаем весь объект в _process, поэтому тут billboard не нужен.
	
	mat.render_priority = int(z_offset * 1000) # Приоритет отрисовки все еще важен
	
	mesh_inst.material_override = mat
	
	# ПИВОТ
	var pivot_node = Node3D.new()
	add_child(pivot_node)
	pivot_node.position = Vector3(-bar_width / 2.0, offset_y, 0)
	
	pivot_node.add_child(mesh_inst)
	# Добавляем z_offset к позиции меша
	mesh_inst.position = Vector3(bar_width / 2.0, 0, z_offset)
	
	return pivot_node 

func _on_health_changed(current: float, max_value: float) -> void:
	_update_bar(false)

func _update_bar(instant: bool = false) -> void:
	if not health: return
	
	var percent = health.current_health / health.max_health
	percent = clamp(percent, 0.0, 1.0)
	
	if percent > 0.5:
		health_mat.albedo_color = Color(0.2, 0.8, 0.2)
	elif percent > 0.25:
		health_mat.albedo_color = Color(1.0, 0.6, 0.0)
	else:
		health_mat.albedo_color = Color(0.9, 0.1, 0.1)

	if instant:
		health_pivot.scale.x = percent
		damage_pivot.scale.x = percent
	else:
		var tween = create_tween()
		tween.set_parallel(true)
		
		tween.tween_property(health_pivot, "scale:x", percent, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
		tween.tween_property(damage_pivot, "scale:x", percent, 0.2).set_delay(0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

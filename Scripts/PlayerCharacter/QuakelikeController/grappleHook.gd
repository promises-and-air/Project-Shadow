extends Node
class_name GrappleHook

@onready var player: CharacterBody3D = $".."
@export var ray: RayCast3D
@export var rope: Node3D

# --- НОВОЕ: Ссылка на точку в ладони ---
@export var hook_origin: Node3D 
# ---------------------------------------

var launched: bool = false
var target: Vector3

var restLength: float = 5.0
@export var maxRestFraction: float = 0.9
@export var minRestFraction: float = 0.4
@export var stiffness: float = 4.25
@export var restLengthCurve: ProceduralCurve


func _physics_process(delta: float) -> void:
	if launched:
		handleGrapple(delta)

func _process(_delta: float) -> void:
	handleRope()

func launch() -> void:
	if ray.is_colliding():
		target = ray.get_collision_point()
		launched = true
		player.floor_snap_length = 0.0
		var dist = player.global_position.distance_to(target)
		restLength = dist * maxRestFraction
		restLengthCurve.set_targets(dist * minRestFraction, restLength)
		restLengthCurve.start()

func retract() -> void:
	launched = false
	player.floor_snap_length = 0.4

func isLaunched() -> bool:
	return launched

func handleGrapple(delta: float) -> void:
	var target_dir = player.global_position.direction_to(target)
	var target_dist = player.global_position.distance_to(target)
	
	restLength = restLengthCurve.step(delta) if restLengthCurve.is_running() else restLengthCurve.targets["min"]
	
	var displacement = target_dist - restLength
	var magnitude = 0.0
	if displacement > 0:
		magnitude = displacement * stiffness
	
	var force = target_dir * magnitude
	force = lerp(force, player.velocity, 0.1)
	player.velocity += force * delta

# --- ИСПРАВЛЕННАЯ ЛОГИКА ВИЗУАЛА ---
func handleRope() -> void:
	if not launched or not rope:
		if rope: rope.visible = false
		return
	
	rope.visible = true
	
	# 1. Начало веревки - в руке (если задан hook_origin, иначе от игрока)
	var start_pos = player.global_position
	if hook_origin:
		start_pos = hook_origin.global_position
	
	# 2. Ставим саму модель веревки в точку начала (в руку)
	rope.global_position = start_pos
	
	# 3. Поворачиваем веревку к цели
	rope.look_at(target)
	
	# 4. Растягиваем веревку (Scale Z)
	# Считаем расстояние от РУКИ до ЦЕЛИ
	var dist = start_pos.distance_to(target)
	rope.scale = Vector3(1, 1, dist) 
	# (Если твоя модель веревки лежит по Z, используй (1, 1, dist). 
	# Если она размером 1 метр в длину. Если нет, придется подбирать множитель)
func can_hook() -> bool:
	# force_raycast_update() нужен, чтобы луч обновился мгновенно,
	# даже если физический кадр еще не прошел (важно для быстрых нажатий)
	ray.force_raycast_update() 
	return ray.is_colliding()

extends Camera3D

@export var player: PlayerMovement

@export var jumpRotation: Vector3 = Vector3(-1.0, -0.5, 0.2)
@export var jumpAnimation: ProceduralCurve

@export var landPosition: Vector3 = Vector3(0, -0.15, 0)
@export var landPosAnimation: ProceduralCurve

@export var landRotation: Vector3 = Vector3(-0.5, 0, 0)
@export var landRotAnimation: ProceduralCurve

@export var hitShake: Vector3 = Vector3(0.3, 0.3, 0.1) # Базовая амплитуда тряски
@export var hitShakeAnimation: ProceduralCurve

@onready var rotationAnims = [jumpAnimation, landRotAnimation, hitShakeAnimation]
@onready var posAnims = [landPosAnimation]
@onready var tiltAnims = [slideAnimation, wallRunAnimation]


@export var slideTilt: float = -1.0
@export var slideAnimation: ProceduralCurve

@export var wallRunTilt: float = -3.0
@export var wallRunAnimation: ProceduralCurve


func _ready() -> void:
	if not is_instance_valid(player):
		push_error("PlayerMovement reference is not set in playerCamera!")
		return
	
	# Signal connections
	if player.just_jumped.connect(startJumpAnimation) != OK:
		push_warning("Failed to connect just_jumped signal")
	if player.just_landed.connect(startLandAnimation) != OK:
		push_warning("Failed to connect just_landed signal")
	if player.start_slide.connect(startSlide) != OK:
		push_warning("Failed to connect start_slide signal")
	if player.end_slide.connect(endSlide) != OK:
		push_warning("Failed to connect end_slide signal")
	if player.start_wall_run.connect(startWallRun) != OK:
		push_warning("Failed to connect start_wall_run signal")
	if player.end_wall_run.connect(endWallRun) != OK:
		push_warning("Failed to connect end_wall_run signal")
	
	# Validate curves
	assert(jumpAnimation != null, "jumpAnimation curve not assigned")
	assert(landPosAnimation != null, "landPosAnimation curve not assigned")
	assert(landRotAnimation != null, "landRotAnimation curve not assigned")
	assert(slideAnimation != null, "slideAnimation curve not assigned")
	assert(wallRunAnimation != null, "wallRunAnimation curve not assigned")
	assert(hitShakeAnimation != null, "hitShakeAnimation curve not assigned")
	
	jumpAnimation.set_targets(Vector3.ZERO, jumpRotation, Vector3.ZERO)
	landPosAnimation.set_targets(Vector3.ZERO, landPosition, Vector3.ZERO)
	landRotAnimation.set_targets(Vector3.ZERO, landRotation, Vector3.ZERO)
	slideAnimation.set_targets(0.0, slideTilt, slideTilt)
	wallRunAnimation.set_targets(0.0, wallRunTilt, wallRunTilt)
	hitShakeAnimation.set_targets(Vector3.ZERO, hitShake, Vector3.ZERO) # Базовые цели


func _process(delta: float) -> void:
	# Priority-based animation system
	var active_rotation_anim: ProceduralCurve = null
	var active_position_anim: ProceduralCurve = null
	var active_tilt_anim: ProceduralCurve = null
	
	# Find highest priority active animation
	for anim in rotationAnims:
		if anim.is_running():
			active_rotation_anim = anim
			break
	
	for anim in posAnims:
		if anim.is_running():
			active_position_anim = anim
			break
	
	for anim in tiltAnims:
		if anim.is_running():
			active_tilt_anim = anim
			break
	
	# Apply only the active animations
	var new_rotation_degrees = rotation_degrees
	
	if active_rotation_anim:
		new_rotation_degrees = active_rotation_anim.step(delta)
	
	if active_position_anim:
		position = active_position_anim.step(delta)
	
	if active_tilt_anim:
		new_rotation_degrees.z = active_tilt_anim.step(delta)

	rotation_degrees = new_rotation_degrees


# ✅ ИСПРАВЛЕНИЕ: Функция принимает аргумент 'strength'
func start_hit_shake(strength: float = 1.0) -> void:
	# 1. Останавливаем конкурирующие анимации
	landPosAnimation.force_stop()
	landRotAnimation.force_stop()
	
	# 2. Масштабируем целевую амплитуду тряски
	var scaled_hit_shake = hitShake * strength
	
	# 3. Перенастраиваем ProceduralCurve с масштабированной амплитудой
	hitShakeAnimation.set_targets(Vector3.ZERO, scaled_hit_shake, Vector3.ZERO) 
	
	# 4. Запускаем анимацию
	hitShakeAnimation.start(rotation_degrees) 
	
	print("📳 Hit shake started! Strength: ", strength)


func startJumpAnimation() -> void:
	landPosAnimation.force_stop()
	landRotAnimation.force_stop()
	# ✅ ВОССТАНОВЛЕНИЕ: Сбрасываем hitShakeAnimation к базовым целям, чтобы избежать масштабирования
	hitShakeAnimation.set_targets(Vector3.ZERO, hitShake, Vector3.ZERO) 
	jumpAnimation.start(rotation_degrees)


func startLandAnimation() -> void:
	jumpAnimation.force_stop()
	# ✅ ВОССТАНОВЛЕНИЕ: Сбрасываем hitShakeAnimation к базовым целям
	hitShakeAnimation.set_targets(Vector3.ZERO, hitShake, Vector3.ZERO) 
	landPosAnimation.start(position)
	landRotAnimation.start(rotation_degrees)


func startTilt(anim: ProceduralCurve) -> void:
	# ✅ ВОССТАНОВЛЕНИЕ: Сбрасываем hitShakeAnimation к базовым целям
	hitShakeAnimation.set_targets(Vector3.ZERO, hitShake, Vector3.ZERO) 
	for i in rotationAnims:
		i.force_stop()
	
	if anim.targets["min"] is Vector3:
		anim.start(rotation_degrees)
	else:
		anim.start(rotation_degrees.z)


func endTilt(anim: ProceduralCurve) -> void:
	if anim.targets["min"] is Vector3:
		anim.start_backwards(rotation_degrees)
	else:
		anim.start_backwards(rotation_degrees.z)


func startWallRun(left: bool) -> void:
	var target_tilt: float = abs(wallRunTilt) if not left else -abs(wallRunTilt)
	wallRunAnimation.targets["max"] = target_tilt
	wallRunAnimation.targets["snap"] = target_tilt
	startTilt(wallRunAnimation)


func endWallRun(_left: bool) -> void:
	endTilt(wallRunAnimation)


func startSlide() -> void:
	startTilt(slideAnimation)


func endSlide() -> void:
	endTilt(slideAnimation)

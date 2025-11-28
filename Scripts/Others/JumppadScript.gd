extends CSGCylinder3D
class_name Jumppad

@export_group("Jump Settings")
@export var jumpBoostValue: float = 15.0
@export var additive: bool = true
@export var horizontal_boost: float = 0.0  # Новое: boost вперед

@onready var area: Area3D = $Area3D


func _ready() -> void:
	# Проверка что Area3D существует
	if not area:
		push_error("Jumppad: Area3D child node not found!")
		return
	
	# Подключаем signal
	if area.body_entered.connect(_on_body_entered) != OK:
		push_warning("Jumppad: Failed to connect body_entered signal")
	
	area.collision_mask = 1
	area.monitoring = true


func _on_body_entered(body: Node3D) -> void:	
	if not body is PlayerMovement:
		return
	
	var player = body as PlayerMovement
	
	if additive:
		player.velocity.y = max(player.velocity.y, 0.0) + jumpBoostValue
	else:
		player.velocity.y = jumpBoostValue
	
	# ✅ НОВОЕ: Horizontal boost (опционально)
	if horizontal_boost > 0.0:
		var forward = -global_transform.basis.z
		forward.y = 0
		if forward.length() > 0:
			forward = forward.normalized()
			player.velocity.x += forward.x * horizontal_boost
			player.velocity.z += forward.z * horizontal_boost
	
	# ✅ ИСПРАВЛЕНО: Переход в AirState через State Machine
	var state_machine = player.get_node_or_null("StateMachine")
	if state_machine:
		var air_state = state_machine.states.get("airstate")
		if air_state and state_machine.current_state != air_state:
			state_machine.transition_to_state(air_state)
	
	# ✅ НОВОЕ: Emit signal для camera/viewmodel effects
	player.just_jumped.emit()
	

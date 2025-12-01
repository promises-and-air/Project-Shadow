extends CanvasLayer

@export_group("References")
@export var player_movement: CharacterBody3D # Ссылка на игрока
@export var shadow_veil_rect: ColorRect
@export var game_camera: Camera3D

@export_group("Dash VFX Settings")
@export var dash_fov_change: float = 3.0 
@export var veil_max_intensity: float = 1.2 # Можно чуть увеличить, так как теперь есть искажение
@export var attack_time: float = 0.1
@export var decay_time: float = 0.4

@export_group("Cooldown Indicator Settings")
@export var cooldown_flash_duration: float = 0.5 # Длительность "призрачного вздоха"

var _default_fov: float
var _dash_tween: Tween
var _cooldown_tween: Tween
var _was_cooldown_ready: bool = true # Флаг для отслеживания состояния

func _ready() -> void:
	await get_tree().process_frame
	if game_camera:
		_default_fov = game_camera.fov
	
	if not _validate_setup(): return

	# Подключаемся к сигналу начала рывка
	if player_movement.has_signal("start_dash"):
		player_movement.start_dash.connect(_on_dash_start)

	# Инициализируем состояние кулдауна
	if "dash_cooldown" in player_movement:
		_was_cooldown_ready = player_movement.dash_cooldown <= 0

func _process(_delta: float) -> void:
	# ПРОВЕРКА КУЛДАУНА В КАЖДОМ КАДРЕ
	if not player_movement or not "dash_cooldown" in player_movement: return
	
	var is_ready_now = player_movement.dash_cooldown <= 0.0
	
	# Если только что стал готов, а в прошлом кадре еще не был
	if is_ready_now and not _was_cooldown_ready:
		_play_cooldown_ready_flash()
	
	_was_cooldown_ready = is_ready_now

# --- ЭФФЕКТ САМОГО РЫВКА ---
func _on_dash_start() -> void:
	if _dash_tween: _dash_tween.kill()
	_dash_tween = create_tween().set_parallel(true)
	
	var mat = shadow_veil_rect.material as ShaderMaterial
	
	# 1. Шейдер (Тьма + Искажение появляются вместе)
	_dash_tween.tween_property(mat, "shader_parameter/intensity", veil_max_intensity, attack_time)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	_dash_tween.chain().tween_property(mat, "shader_parameter/intensity", 0.0, decay_time)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		
	# 2. FOV Kick
	if game_camera:
		_dash_tween.tween_property(game_camera, "fov", _default_fov + dash_fov_change, attack_time)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
		_dash_tween.chain().tween_property(game_camera, "fov", _default_fov, decay_time)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

# --- ЭФФЕКТ ГОТОВНОСТИ (НОВОЕ) ---
func _play_cooldown_ready_flash() -> void:
	if not shadow_veil_rect: return
	var mat = shadow_veil_rect.material as ShaderMaterial
	
	if _cooldown_tween: _cooldown_tween.kill()
	_cooldown_tween = create_tween()
	
	# Быстрая вспышка "призрачного" цвета и плавное затухание
	# Половина времени на появление
	_cooldown_tween.tween_property(mat, "shader_parameter/cooldown_flash_intensity", 1.0, cooldown_flash_duration * 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	
	# Вторая половина на исчезновение
	_cooldown_tween.tween_property(mat, "shader_parameter/cooldown_flash_intensity", 0.0, cooldown_flash_duration * 0.7)\
		.set_ease(Tween.EASE_IN)

func _validate_setup() -> bool:
	if not shadow_veil_rect or not shadow_veil_rect.material is ShaderMaterial:
		push_error("DarkDashVFX: Missing ColorRect or ShaderMaterial!")
		set_process(false)
		return false
	if not player_movement:
		push_error("DarkDashVFX: Player reference missing!")
		set_process(false)
		return false
	return true

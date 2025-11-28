extends TextureProgressBar

# Перетащи сюда узел WeaponManager
@export var weapon_manager: Node 

# ЦВЕТА (Настрой их в инспекторе для удобства)
@export var color_charge: Color = Color(1.0, 0.6, 0.0) # Оранжевый (Зарядка)
@export var color_cooldown: Color = Color(0.8, 0.1, 0.1) # Красный (Остывание)
@export var color_ready: Color = Color(1, 1, 1, 0) # Прозрачный (когда готов)

func _ready() -> void:
	# Настройки прогресс бара
	min_value = 0.0
	max_value = 1.0
	step = 0.01
	value = 0.0
	
	# Автопоиск (если забыл привязать)
	if not weapon_manager:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			weapon_manager = player.find_child("WeaponSlot", true, false)
	
	if weapon_manager:
		# Убедись, что сигнал в WeaponManager называется именно так
		if weapon_manager.has_signal("magic_ui_update"):
			weapon_manager.magic_ui_update.connect(_on_update_magic_ui)

func _on_update_magic_ui(charge_ratio: float, cooldown_ratio: float) -> void:
	if cooldown_ratio > 0.0:
		# --- ПЕРЕЗАРЯДКА ---
		value = cooldown_ratio
		tint_progress = color_cooldown # Красим полоску в красный
		
		# Можно сделать инверсию (чтобы круг уменьшался, а не рос)
		# fill_mode = FILL_CLOCKWISE 
		
	elif charge_ratio > 0.0:
		# --- ЗАРЯДКА ---
		value = charge_ratio
		tint_progress = color_charge # Красим в оранжевый
		
	else:
		# --- ГОТОВ ---
		value = 0.0
		tint_progress = color_ready # Прячем или делаем белым

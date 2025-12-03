extends CanvasLayer

# Используем массив, чтобы легко добавлять новые слоты
@export var icons: Array[TextureRect]

@export var active_color: Color = Color.WHITE
@export var inactive_color: Color = Color(0.3, 0.3, 0.3, 0.8)

func _ready() -> void:
	# Убедись, что назначил иконки в инспекторе в массив Icons!
	update_selection(0)

func update_selection(active_index: int):
	print("UI Switch: ", active_index)
	
	# Проходимся по ВСЕМ иконкам в цикле
	for i in range(icons.size()):
		var icon = icons[i]
		if not icon: continue
		
		var is_active = (i == active_index)
		
		# Создаем твин для каждой иконки
		var tween = create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_BACK if is_active else Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		
		# Целевые значения
		var target_scale = Vector2(1.2, 1.2) if is_active else Vector2(1.0, 1.0)
		var target_color = active_color if is_active else inactive_color
		var target_z = 1 if is_active else 0
		
		# Анимация
		tween.tween_property(icon, "scale", target_scale, 0.15)
		tween.tween_property(icon, "modulate", target_color, 0.15)
		
		# Z-index меняем мгновенно, чтобы активный сразу был сверху
		icon.z_index = target_z

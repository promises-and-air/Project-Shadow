extends Label3D

@export var float_height: float = 1.5 # Насколько высоко всплывет
@export var spread_radius: float = 1.0 # Разброс в стороны
@export var lifetime: float = 0.8 # Жизнь цифры короче, но динамичнее

func _ready() -> void:
	# Настройки Label3D для четкости (можно настроить и в Инспекторе)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED # Всегда смотреть в камеру
	no_depth_test = true # Рисовать поверх стен и врагов
	render_priority = 10 # Приоритет отрисовки
	outline_render_priority = 9
	modulate.a = 0.0 # Сначала невидимый, чтобы не мелькнул до анимации

	# Ждем кадр, чтобы точно установился текст и позиция
	await get_tree().process_frame 
	start_animation()

func start_animation() -> void:
	modulate.a = 1.0 # Делаем видимым
	
	# 1. Случайный разброс позиции (чтобы цифры не накладывались идеально друг на друга)
	var random_offset = Vector3(
		randf_range(-spread_radius, spread_radius),
		randf_range(0.0, 0.5), # Немного вариации по высоте старта
		randf_range(-spread_radius, spread_radius)
	)
	var target_pos = position + Vector3(0, float_height, 0) + (random_offset * 0.5)
	
	var tween = create_tween()
	tween.set_parallel(true)

	# 2. Движение: Быстрый вылет, потом замедление (как будто подбросили)
	tween.tween_property(self, "position", target_pos, lifetime).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)

	# 3. Скейл (Pop-up эффект): С 0 до нужного размера с отскоком (Back/Elastic)
	scale = Vector3.ZERO # Начинаем с нуля
	var final_scale = Vector3(1.0, 1.0, 1.0)
	
	# Если это Крит - делаем скейл больше
	if text.to_int() >= 60: # Используем твою логику крита
		final_scale = Vector3(2.0, 2.0, 2.0) # Крит больше
		# Эффект "удара" для крита (EASE_OUT_BACK делает "пружинку")
		tween.tween_property(self, "scale", final_scale, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		# Обычный урон - просто быстрое появление
		tween.tween_property(self, "scale", final_scale, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 4. Исчезновение (Fade out) в конце
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(lifetime - 0.3)
	
	tween.finished.connect(queue_free)

func set_damage(value) -> void:
	text = str(value)
	
	# Настройка обводки (Важно для стиля Genshin)
	outline_modulate = Color(0, 0, 0, 1) # Черная обводка
	
	# Логика цвета (твоя + доработки)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		if value >= 60:
			# Крит (обычно в Геншине шрифт жирнее, но тут меняем цвет)
			modulate = Color(1, 0.9, 0.2) # Золотисто-желтый (классический крит)
			outline_size = 32 # Жирная обводка
		elif value >= 30:
			modulate = Color(1, 0.4, 0) # Оранжевый
			outline_size = 26
		else:
			modulate = Color(1, 1, 1) # Белый (Физ урон)
			outline_size = 26
	else:
		# Текст реакции
		modulate = Color(0.9, 0.3, 0.3)
		outline_size = 32

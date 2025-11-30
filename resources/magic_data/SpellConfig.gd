extends Resource
class_name SpellConfig

@export_category("Charging")
@export var charge_time_required: float = 0.6 # Твой старый charge_threshold
@export var fov_zoom_amount: float = 15.0     # Твой старый charge_fov_amount
@export var charge_duration: float = 1.5      # Время зума

@export_category("Projectiles")
@export var light_shot: ProjectileData        # Сюда положишь файл "слабого" шара
@export var heavy_shot: ProjectileData        # Сюда положишь файл "сильного" шара

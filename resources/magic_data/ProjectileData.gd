extends Resource
class_name ProjectileData

@export_group("Visuals")
@export var projectile_scene: PackedScene # Сама сцена шара
@export var impact_vfx: PackedScene       # Эффект взрыва
@export var scale: float = 1.0

@export_group("Physics")
@export var speed: float = 25.0
@export var lifetime: float = 5.0
@export var gravity_scale: float = 0.0

@export_group("Combat")
@export var damage: int = 30
@export var knockback: float = 10.0
@export var camera_shake_name: String = "magic_light" # Имя твоей тряски

@export_group("Status Effects")
@export var burn_duration: float = 0.0    # 0 = без поджога
@export var burn_damage: int = 0

@export_group("Game Feel")
@export var recoil_amount: float = 2.0 # Градусов вверх
@export var recoil_time: float = 0.1

class_name WeaponData extends Resource

@export_group("Basic Info")
@export var weapon_name: String = "Weapon"
@export var weapon_type: String = "Sword"
@export var description: String = ""
@export var weapon_scene: PackedScene 
@export var world_model: PackedScene


@export_group("Combat Stats")
## Базовый урон, который наносит это оружие
@export var damage: int = 10

## Как далеко это оружие бьет (радиус хитбокса)
@export var attack_range: float = 1.5

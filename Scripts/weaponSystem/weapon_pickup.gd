extends Area3D
class_name WeaponPickup

@export var weapon_data: WeaponData

# 💡 Мы по-прежнему используем DisplayMesh, чтобы легко
#    контролировать ОБЩИЙ размер (твой фикс с 'scale')
@onready var display_mesh: Node3D = $DisplayMesh

func _ready() -> void:
	if not weapon_data:
		push_error("WeaponPickup не имеет WeaponData!")
		return

	# 💡 ГЛАВНОЕ ИЗМЕНЕНИЕ:
	# Мы спавним 'world_model', а не 'weapon_scene'
	if weapon_data.world_model:
		var scene = weapon_data.world_model.instantiate()
		display_mesh.add_child(scene)
	else:
		push_error("У %s не назначена 'World Model'!" % weapon_data.weapon_name)

# 💡 Функция _reset_material_properties() БОЛЬШЕ НЕ НУЖНА.
#    Можешь ее полностью удалить.

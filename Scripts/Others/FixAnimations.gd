@tool
extends Node

@export var player_node: AnimationPlayer
@export var clean_now: bool = false : set = _on_clean

func _on_clean(value):
	if value and player_node:
		clean_animations()
		clean_now = false

func clean_animations():
	var list = player_node.get_animation_list()
	print("--- НАЧИНАЮ ЧИСТКУ ---")
	
	for anim_name in list:
		var anim = player_node.get_animation(anim_name)
		var track_count = anim.get_track_count()
		
		# Идем с конца списка треков к началу
		for i in range(track_count - 1, -1, -1):
			var type = anim.track_get_type(i)
			var path = str(anim.track_get_path(i))
			
			# Оставляем только Position(1), Rotation(2), Scale(3)
			# Все остальное (например, Visible, Audio, Method Call) - удаляем, если это не методы
			if type != Animation.TYPE_POSITION_3D and type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_SCALE_3D:
				
				# Если это не вызов метода (наши launch/retract), то удаляем
				if type != Animation.TYPE_METHOD:
					print("Удален мусорный трек в [", anim_name, "]: ", path)
					anim.remove_track(i)
					
	print("--- ГОТОВО! Перезапусти сцену. ---")

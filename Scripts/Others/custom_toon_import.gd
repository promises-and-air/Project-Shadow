@tool
extends EditorScenePostImport

const TOON_SHADER_FILE = preload("res://assets/vfx shaders/toon_shader.gdshader")

func _post_import(node):
	iterate(node)
	return node

func iterate(node):
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			var source_mat = node.mesh.surface_get_material(i)
			
			# Проверяем, есть ли исходный материал
			if source_mat and source_mat is BaseMaterial3D:
				var texture = source_mat.albedo_texture
				var normal_map = source_mat.normal_texture # <--- Берем карту нормалей
				
				# Создаем новый материал
				var new_shader_mat = ShaderMaterial.new()
				new_shader_mat.shader = TOON_SHADER_FILE
				
				# Передаем ALBEDO (если есть)
				if texture:
					new_shader_mat.set_shader_parameter("albedo_texture", texture)
				
				# Передаем NORMAL MAP (если есть)
				if normal_map:
					# Включаем карту нормалей в исходнике, чтобы убедиться, что она была активна
					# (хотя для glTF это обычно true по умолчанию, если текстура есть)
					new_shader_mat.set_shader_parameter("normal_texture", normal_map)
				
				# Применяем новый материал к мешу
				node.mesh.surface_set_material(i, new_shader_mat)
	
	for child in node.get_children():
		iterate(child)

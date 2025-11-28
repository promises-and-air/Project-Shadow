extends CanvasLayer

@onready var speed_label: Label = $Control/SpeedLabel
@onready var anim_label: Label = $Control/AnimLabel

var player: CharacterBody3D = null
var state_machine = null

func _ready() -> void:
	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.size() > 0:
		player = player_nodes[0]
	else:
		push_warning("Player node not found in group 'player'")
		return
	
	# Безопасное получение state_machine из AnimationTree
	if is_instance_valid(player):
		var animation_tree_path = "Head/CameraHolder/CameraShaker/Camera/SubViewportContainer/SubViewport/viewmodel_camera/PLA/AnimationTree"
		if player.has_node(animation_tree_path):
			var animation_tree = player.get_node(animation_tree_path)
			if animation_tree:
				state_machine = animation_tree.get("parameters/playback")
		
		if not is_instance_valid(state_machine):
			push_warning("AnimationTree or state_machine not found")

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	
	update_speed()
	update_animation_label()

func update_speed() -> void:
	var horizontal_velocity := Vector3(player.velocity.x, 0, player.velocity.z)
	var vertical_velocity := player.velocity.y
	speed_label.text = "Speed: %.1f | Fall: %.1f" % [horizontal_velocity.length(), vertical_velocity]

func update_animation_label() -> void:
	if is_instance_valid(state_machine):
		var current_state = state_machine.get_current_node()
		anim_label.text = "Anim: " + str(current_state)
	else:
		anim_label.text = "Anim: N/A"

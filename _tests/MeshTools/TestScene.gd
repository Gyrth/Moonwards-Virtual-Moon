extends Spatial
var MeshTool = preload("MeshTool.gd")
export(NodePath) var test_mesh

func _ready():
	yield(get_tree(), "idle_frame")
	var mt = MeshTool.new(get_tree().current_scene, test_mesh)

	mt.get_hitbox()
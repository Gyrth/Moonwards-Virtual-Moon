extends AComponent

# Temporarily until SceneManager, scene indexing & dynamic component creation is added.
var model
var animation

func _init().("AnimationController", false):
	pass

func _ready():
	call_deferred("_initialize")

func _initialize():
	model = entity.get_component("ModelComponent")
	if model == null:
		Log.error(self, "", "Animation controller requires a model.")
		assert(false)
	animation = model.get_node("AnimationPlayer")
	pass

func _process_client(_delta):
	pass

extends MwSpatial
class_name AEntity

var components: Dictionary = {}

func _ready():
	add_to_group(Groups.ENTITIES)
	Signals.Entities.emit_signal(Signals.Entities.ENTITY_CREATED, self)

func add_component(_name: String, _comp: Node) -> void:
	# Add error checking here.
	components[_name] = _comp

func get_component(_name: String) -> Node:
	return components[_name]
extends Spatial

var player_class = preload("res://assets/Player/avatar_v2/scripts/Player.gd")

onready var label : Node = $CollisionShape/MeshInstance/Viewport/Label
onready var animaton_player : Node = $AnimationPlayer
onready var passenger_check : Node = $PassengerCheck
onready var main_body : Node = $PassengerPod/PassengerPod/StaticBody
export(NodePath) var target_location

var passengers = []
var ready_to_leave : bool = false
var timer : float = 0.0
var leave_timeout : float = 5.0
var timer_started : bool = false
onready var target_delivery_point : Vector3 = get_node(target_location).global_transform.origin

func _process(delta):
	if timer_started:
		timer += delta
		_set_text("Leaving in \n" + str(round(leave_timeout - timer)) + "\n seconds.")
		if timer >= (leave_timeout - 1.0):
			timer_started = false
			animaton_player.play("CloseDoor")
			_lock_passengers()
			_set_text("")
			yield(animaton_player, "animation_finished")
			ready_to_leave = true
			timer = 0.0

func activate() -> void:
	timer_started = true

func _set_text(text : String) -> void:
	label.text = text

func _lock_passengers():
	yield(get_tree(), "physics_frame")
	yield(get_tree(), "physics_frame")
	yield(get_tree(), "physics_frame")
	yield(get_tree(), "physics_frame")
	var bodies = passenger_check.get_overlapping_bodies()
	main_body.set_collision_layer_bit(1, false)
	
	for object in bodies:
		if object is KinematicBody:
			passengers.append({"object" : object, "parent" : object.get_parent()})
			object.get_parent().frozen = true
			var old_transform = object.global_transform
			object.get_parent().remove_child(object)
			self.add_child(object)
			object.global_transform = old_transform

func free_passengers():
	for passenger in passengers:
		var old_transform = passenger.object.global_transform
		self.remove_child(passenger.object)
		passenger.parent.add_child(passenger.object)
		passenger.object.global_transform = old_transform
		passenger.parent.frozen = false
	passengers.resize(0)

func delivered():
	main_body.set_collision_layer_bit(1, true)
	free_passengers()
	animaton_player.play("OpenDoor")

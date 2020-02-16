extends Spatial

var player_class = preload("res://assets/Player/avatar_v2/scripts/Player.gd")

onready var label : Node = $MainBody/TourPodArea/CollisionShape/MeshInstance/Viewport/Label
onready var animaton_player : Node = $MainBody/AnimationPlayer
onready var passenger_check : Node = $MainBody/PassengerCheck
onready var body : Node = $MainBody
onready var camera_control : Node = $MainBody/PlayerCamera
export(NodePath) var target_location

var passengers = []
var ready_to_leave : bool = false
var rover_present : bool = false setget set_rover_present
var timer : float = 0.0
var leave_timeout : float = 5.0
var timer_started : bool = false
onready var target_delivery_point : Vector3 = get_node(target_location).global_transform.origin

func set_rover_present(var _rover_present):
	rover_present = _rover_present
	if rover_present:
		_set_text("Press E\nto start tour.")
	else:
		_set_text("Waiting\nfor rover...")

func _process(delta):
	if timer_started:
		timer += delta
		_set_text("Leaving in \n" + str(round(leave_timeout - timer)) + "\n seconds.")
		if timer >= (leave_timeout - 1.0):
			timer_started = false
			_lock_passengers()
			animaton_player.play("CloseDoor")
			body.set_collision_layer_bit(1, false)
			camera_control.set_camera_control(true)
			_set_text("")
			yield(animaton_player, "animation_finished")
			ready_to_leave = true
			timer = 0.0

func activate() -> void:
	if rover_present:
		timer_started = true

func _set_text(text : String) -> void:
	label.text = text

func _lock_passengers():
	yield(get_tree(), "idle_frame")
	var bodies = passenger_check.get_overlapping_bodies()
	
	for object in bodies:
		if object is KinematicBody:
			passengers.append({"object" : object, "parent" : object.get_parent()})
			object.get_parent().frozen = true
			var old_transform = object.global_transform
			object.get_parent().remove_child(object)
			body.add_child(object)
			object.global_transform = old_transform

func free_passengers():
	for passenger in passengers:
		var old_transform = passenger.object.global_transform
		body.remove_child(passenger.object)
		passenger.parent.add_child(passenger.object)
		passenger.object.global_transform = old_transform
		passenger.parent.frozen = false
	passengers.resize(0)

func delivered():
	free_passengers()
	body.set_collision_layer_bit(1, true)
	animaton_player.play("OpenDoor")
	camera_control.set_camera_control(false)

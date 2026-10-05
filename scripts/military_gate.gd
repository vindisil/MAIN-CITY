extends Node3D

@export var slide_distance: float = 10.0
@export var open_time: float = 0.75

@onready var left_gate: AnimatableBody3D = get_node_or_null("FolhaEsquerda") as AnimatableBody3D
@onready var right_gate: AnimatableBody3D = get_node_or_null("FolhaDireita") as AnimatableBody3D
@onready var trigger: Area3D = get_node_or_null("Trigger") as Area3D

var left_closed: Vector3 = Vector3.ZERO
var right_closed: Vector3 = Vector3.ZERO
var occupants: int = 0

func _ready() -> void:
	if left_gate != null:
		left_closed = left_gate.position
	if right_gate != null:
		right_closed = right_gate.position
	if trigger != null:
		trigger.body_entered.connect(_on_body_entered)
		trigger.body_exited.connect(_on_body_exited)

func _valid_body(body: Node) -> bool:
	if body is CharacterBody3D:
		return true
	if body is VehicleBody3D:
		return true
	return body.is_in_group("vehicle")

func _on_body_entered(body: Node) -> void:
	if not _valid_body(body):
		return
	occupants += 1
	_set_open(true)

func _on_body_exited(body: Node) -> void:
	if not _valid_body(body):
		return
	occupants = maxi(0, occupants - 1)
	_close_after_delay()

func _close_after_delay() -> void:
	await get_tree().create_timer(1.1).timeout
	if occupants == 0:
		_set_open(false)

func _set_open(opened: bool) -> void:
	if left_gate == null or right_gate == null:
		return
	var left_target: Vector3 = left_closed
	var right_target: Vector3 = right_closed
	if opened:
		left_target += Vector3(-slide_distance, 0.0, 0.0)
		right_target += Vector3(slide_distance, 0.0, 0.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(left_gate, "position", left_target, open_time)
	tween.tween_property(right_gate, "position", right_target, open_time)

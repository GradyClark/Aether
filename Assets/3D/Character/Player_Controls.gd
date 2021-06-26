extends Node

export (NodePath) var Eyes_Node
export (NodePath) var Body_Node

#onready var shader_fix = preload("res://good to know/compile_shader_fix.tscn")
onready var simple_hud = preload("res://Assets/2D/Simple_Hud/Simple_Hud.tscn")

# How fast the player moves in meters per second.
export var speed = 14
# The downward acceleration when in the air, in meters per second squared.
export var fall_acceleration = 75

var Eyes = null
var Body = null
var Weapon:Node = null

var velocity = Vector3.ZERO

var mouse_sensitivity = 0.1

func _ready():
	# TODO: Move set_mouse_mode to code where scene is loaded, instead of character _ready
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Eyes = get_node(Eyes_Node)
	Body = get_node(Body_Node)
	Eyes.visible=true
#	Eyes.add_child(shader_fix.instance())
	var hud = simple_hud.instance()
	hud.destroyable = Body.get_node("destroyable")
	Eyes.add_child(hud)
	hud.destroyable.connect("on_death", self, "_on_death")

func _input(event):
	if Globals.is_game_paused():
		return
	if event is InputEventMouseMotion:
		Body.rotation_degrees.y -= event.relative.x * mouse_sensitivity
		Eyes.rotation_degrees.x = clamp(Eyes.rotation_degrees.x - event.relative.y * mouse_sensitivity, -90, 90)
	
#	if event is InputEventKey:
#		if Input.is_action_just_released("ui_end"):
#			get_tree().quit()
#		elif Input.is_action_just_released("ui_cancel"):
#			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
#				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
#				Globals.set_game_pause(true)
#			else:
#				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
#				Globals.set_game_pause(false)
	
	if event is InputEventMouseButton:
		if Input.is_action_just_pressed("shoot") and Weapon != null:
			Weapon.shoot()

func _physics_process(delta):
	if Globals.is_game_paused():
		return

	var direction = Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		direction.y += 1
	if Input.is_action_pressed("move_left"):
		direction.y -= 1
	if Input.is_action_pressed("move_back"):
		direction.x -= 1
	if Input.is_action_pressed("move_forward"):
		direction.x += 1

	# Turning
	direction = direction.normalized().rotated(-Body.rotation.y)
	
	velocity.x = direction.x * speed
	velocity.z = direction.y * speed
	velocity.y -= fall_acceleration * delta
	
	velocity = Body.move_and_slide(velocity, Vector3.UP)
	
func _on_death():
	Globals.set_game_pause(true)
	get_tree().change_scene("res://Scenes/main_menu/main_menu.tscn")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

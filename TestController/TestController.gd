extends KinematicBody

enum State {IDLE, RUN, JUMP, FALL, DASH}
enum Attacks {NONE, ATTACK, DEFEND, DASH}
enum Curves {LINEAR, EXPONENTIAL, INV_S}

var CURVES_RES = [
	preload("Curves/Linear.tres"),
	preload("Curves/Exponential.tres"),
	preload("Curves/Inverse_S.tres")
]

export var mouse_sens = Vector2(.1,.1) # sensitivities for each
export var gamepad_sens = Vector2(2,2) # axis + input
export var gamepad_curve = Curves.INV_S # curve analog inputs map to
export var move_speed = 3 # max move speed
export var acceleration = 0.5 # ground acceleration
export var sprint_move_speed = 6 # ground acceleration
export var friction = 1.1
export var angle_of_freedom = 80 # amount player may look up/down

# Multiplayer variables

export var id = 0
export var mouse_control = true # only works for lowest viewport (first child)

func _physics_process(delta):
	_process_input(delta)
	_process_movement(delta)

func _ready():
	if mouse_control: Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) # might need to disable for multiplayer

# Handles mouse movement
func _input(event):
	if event is InputEventMouseMotion && Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if mouse_control: # only do mouse control if enabled for this instance
			cam_rotate(Vector2(event.relative.x, event.relative.y), mouse_sens)


var input_dir = Vector3(0, 0, 0)
var isSprinting = false;
func _process_input(delta):
	# Toggle mouse capture
	if Input.is_action_just_pressed("mouse_escape") && mouse_control:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				
	isSprinting = Input.get_action_strength("sprint_%s" % id) > 0.1
	
	# WASD
	input_dir = Vector3(Input.get_action_strength("right_%s" % id) - Input.get_action_strength("left_%s" % id), 0,
			Input.get_action_strength("back_%s" % id) - Input.get_action_strength("forward_%s" % id)).normalized()
	
	# Look
	var look_vec = Vector2(
		Input.get_action_strength("look_right_%s" % id) - Input.get_action_strength("look_left_%s" % id),
		Input.get_action_strength("look_down_%s" % id) - Input.get_action_strength("look_up_%s" % id)
	)
	
	# Map gamepad look to curves
	var signs = Vector2(sign(look_vec.x),sign(look_vec.y))
	var sens_curv = CURVES_RES[gamepad_curve]
	look_vec = look_vec.abs() # Interpolate input on the curve as positives
	look_vec.x = sens_curv.interpolate_baked(look_vec.x)
	look_vec.y = sens_curv.interpolate_baked(look_vec.y)
	look_vec *= signs # Return inputs to original signs
	
	cam_rotate(look_vec, gamepad_sens)


var velocity := Vector3(0, 0, 0)
var state = State.RUN;
var collision
func _process_movement(delta):
	
	if input_dir.length() > .1:
		state = State.RUN
	else:
		state = State.IDLE
	
	if state == State.RUN:
		velocity += input_dir.rotated(Vector3(0, 1, 0), rotation.y) * acceleration
		var maxSpeed = sprint_move_speed if isSprinting else move_speed
		if velocity.length() > maxSpeed:
			velocity = velocity.normalized() * maxSpeed # clamp move speed

	# idle state
	if state == State.IDLE:
		velocity /= friction
	
	#apply
	if velocity.length() >= .1:
		collision = move_and_collide(velocity * delta)
	else:
		velocity = Vector3(0, 0, 0)

func enable_mouse():
	mouse_control = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func cam_rotate(vect, sens):
	rotate_y(deg2rad(vect.x * sens.y * -1))
	$Collider/Camera.rotate_x(deg2rad(vect.y * sens.x * -1))
	
	var camera_rot = $Collider/Camera.rotation_degrees
	camera_rot.x = clamp(camera_rot.x, 90 + angle_of_freedom * -1, 90 + angle_of_freedom)
	$Collider/Camera.rotation_degrees = camera_rot # I don't understand this function

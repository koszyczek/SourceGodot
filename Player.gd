extends CharacterBody3D
# Movement constants
const MAX_VELOCITY_AIR = 6.0
const MAX_VELOCITY_GROUND = 6.0
const MAX_ACCELERATION = 10 * MAX_VELOCITY_GROUND
const GRAVITY = 15.34
const STOP_SPEED = 0.5
const JUMP_IMPULSE = sqrt(2 * GRAVITY * 0.85)
const PLAYER_WALKING_MULTIPLIER = 0.666
const DASH_VELOCITY_MULTIPLIER = 2.0
const DASH_DURATION = 0.2
const DASH_COOLDOWN = 0.0
const MAX_DASHES = 3
const DASH_REGEN_TIME = 4.0  # Time in seconds for each dash to regenerate
var direction = Vector3()
var friction = 6
var wish_jump = false
var walking = false
var dashing = false
var dash_time = 0.0
var dash_cooldown_time = 0.0
const MAX_SPEED = 55.0

# Camera
var sensitivity = 0.05
# UI elements

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	# Mouse lock
	if Input.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif Input.is_action_pressed("mouse_left"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Camera rotation
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_handle_camera_rotation(event)
func _handle_camera_rotation(event: InputEvent):
	# Rotate the camera based on the mouse movement
	rotate_y(deg_to_rad(-event.relative.x * sensitivity))
	$Head.rotate_x(deg_to_rad(-event.relative.y * sensitivity))
	
	# Stop the head from rotating too far up or down
	$Head.rotation.x = clamp($Head.rotation.x, deg_to_rad(-60), deg_to_rad(90))
func _physics_process(delta):
	process_input(delta)
	process_movement(delta)
	
func process_input(delta):
	direction = Vector3()
	
	# Movement directions
	if Input.is_action_pressed("forward"):
		direction -= transform.basis.z
	elif Input.is_action_pressed("backward"):
		direction += transform.basis.z
	if Input.is_action_pressed("left"):
		direction -= transform.basis.x
	elif Input.is_action_pressed("right"):
		direction += transform.basis.x
		
	# Jumping
	wish_jump = Input.is_action_just_pressed("jump")
	
	# Walking
	walking = Input.is_action_pressed("walk")
	
	# Dashing
func process_movement(delta):
	# Get the normalized input direction so that we don't move faster on diagonals
	var wish_dir = direction.normalized()
	if is_on_floor():
		# Handle jumping
		if wish_jump:
			velocity.y = JUMP_IMPULSE
			velocity = update_velocity_air(wish_dir, delta)
			wish_jump = false
		else:
			if walking:
				velocity.x *= PLAYER_WALKING_MULTIPLIER
				velocity.z *= PLAYER_WALKING_MULTIPLIER
			# Apply dashing
			if dashing:
				velocity = accelerate(wish_dir, MAX_VELOCITY_GROUND * DASH_VELOCITY_MULTIPLIER, delta)
				dash_time -= delta
				if dash_time <= 0:
					dashing = false
			else:
				velocity = update_velocity_ground(wish_dir, delta)
	else:
		# Only apply gravity while in the air
		velocity.y -= GRAVITY * delta
		if dashing:
			velocity = accelerate(wish_dir, MAX_VELOCITY_AIR * DASH_VELOCITY_MULTIPLIER, delta)
		else:
			velocity = update_velocity_air(wish_dir, delta)
			
	if velocity.length() > MAX_SPEED:
		velocity = velocity.normalized() * MAX_SPEED
	
	# Move the player once velocity has been calculated
	move_and_slide()
	
	# Update dash cooldown
	if dash_cooldown_time > 0:
		dash_cooldown_time -= delta
		
func accelerate(wish_dir: Vector3, max_speed: float, delta: float) -> Vector3:
	# Get our current speed as a projection of velocity onto the wish_dir
	var current_speed = velocity.dot(wish_dir)
	# How much we accelerate is the difference between the max speed and the current speed
	# clamped to be between 0 and MAX_ACCELERATION which is intended to stop you from going too fast
	var add_speed = clamp(max_speed - current_speed, 0, MAX_ACCELERATION * delta)
	
	return velocity + add_speed * wish_dir
	
func update_velocity_ground(wish_dir: Vector3, delta: float) -> Vector3:
	# Apply friction when on the ground and then accelerate
	var speed = velocity.length()
	
	if speed != 0:
		var control = max(STOP_SPEED, speed)
		var drop = control * friction * delta
		
		# Scale the velocity based on friction
		velocity *= max(speed - drop, 0) / speed
	
	return accelerate(wish_dir, MAX_VELOCITY_GROUND, delta)
	
func update_velocity_air(wish_dir: Vector3, delta: float) -> Vector3:
	# Do not apply any friction
	return accelerate(wish_dir, MAX_VELOCITY_AIR, delta)

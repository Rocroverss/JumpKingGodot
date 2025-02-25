extends KinematicBody2D

var grounded := false
var onSlope := false
var onIce := false
var onSnow := false
var iceInertia := 0.05
var stunned := true
var noClip := false
var noCipSpeed : int = 360 * 2   # levelHeight*2

enum state { IDLE, WALKING, CHARGING, JUMPING, FALLING, SPLAT }
export var currentState = state.SPLAT

var direction : String = "right"
var velocity : Vector2
var previous_y_vel = 0
var previous_floor_normal : Vector2 = Vector2(0, -1)
var moveSpeed := 84
var moveSpeedIceMultiplier := 0.1
var moveInfo : Vector2
var gravity : float = 800
var jumpPower : float = 0
const jumpHMultiplier = 2.3
const bounceMultiplier = 0.5
const bounceSoundThreshold = 40
const levelWidth = 480
const levelHeight = 360
var currentLevelY = 1
var currentLevelX = 1
var bounceVelocityThreshold := 84 / 2  # moveSpeed / 2
const splatThreshold = 550
export var maxJump : float = 250
export var minPower : float = 0.3
var jumpPowerStep := 3.0
export var maxPower : float = 2
export var maxSpeed : float = 600
export var windVelocityMultiplier = 7
var windGroundMultiplier = 5
var jump_pressing : bool
var left_pressing : bool
var right_pressing : bool

onready var sprite = $Sprite
onready var collisionShape = $CollisionShape2D
onready var audioPlayer = $AudioStreamPlayer
onready var animationPlayer = $AnimationPlayer
onready var idleTimer = $IdleTimer
onready var splatTimer = $SplatTimer
onready var velocityLine = $Line2D
onready var mapCollisions = get_tree().get_nodes_in_group("map_collision")

onready var jumpSound = load("res://Audio/King/Land/king_jump.wav")
onready var iceJumpSound = load("res://Audio/King/Ice/king_jump.wav")
onready var snowJumpSound = load("res://Audio/King/Snow/king_jump.wav")
onready var landingSound = load("res://Audio/King/Land/king_land.wav")
onready var iceLandingSound = load("res://Audio/King/Ice/king_land.wav")
onready var snowLandingSound = load("res://Audio/King/Snow/king_land.wav")
onready var splatSound = load("res://Audio/King/Land/king_splat.wav")
onready var bumpSound = load("res://Audio/King/Land/king_bump.wav")
onready var jumpParticle = preload("res://Entities/JumpParticle.tscn")
onready var snowJumpParticle = preload("res://Entities/snowJumpParticle.tscn")

var motionPoints : PoolVector2Array

func _ready():
	motionPoints = PoolVector2Array()
	motionPoints.resize(2)
	# currentState = state.SPLAT
	# splatTimer.start()

func _physics_process(delta):
	# Wind pushes horizontally every frame
	velocity.x += WindManager.currentVelocity * windVelocityMultiplier

	check_grounded()
	if grounded and not onSlope:
		velocity.y = 0

	if not grounded:
		check_bounces()

	handle_states(delta)
	handle_animations()
	inputs(delta)
	apply_gravity(delta)
	handle_movement(delta)
	detect_slopes()

	previous_y_vel = velocity.y

	motionPoints[0] = Vector2(0, 0)
	motionPoints[1] = Vector2(WindManager.currentVelocity * windVelocityMultiplier * 4, 0)
	velocityLine.points = motionPoints
	debug_label("Wind")

# ---------------------------------------------------------------------------
# Debug / Label
# ---------------------------------------------------------------------------
func debug_label(type):
	match type:
		"Velocity":
			$Label.text = str(floor(velocity.x)) + ", " + str(floor(velocity.y))
		"Position":
			$Label.text = str(int(position.x)) + ", " + str(int(position.y))
		"State":
			$Label.text = state.keys()[currentState]
		"Slope":
			$Label.text = str(previous_floor_normal)
		"Noclip":
			$Label.text = str(noClip)
		"Level":
			var cam = get_tree().get_root().get_node("/root/World/Camera2D")
			$Label.text = "Level: " + str(cam.currentLevelY) + "y, " + str(cam.currentLevelX) + "x"
		"onIce":
			$Label.text = str(onIce)
		"Wind":
			$Label.text = str(WindManager.currentVelocity)

# ---------------------------------------------------------------------------
# Movement + Inputs
# ---------------------------------------------------------------------------
func move_right():
	if currentState != state.SPLAT:
		sprite.flip_h = false
		direction = "right"
	if not onSnow:
		currentState = state.WALKING
		if not onIce:
			velocity.x = moveSpeed
		else:
			velocity.x = lerp(velocity.x, moveSpeed + 39, moveSpeedIceMultiplier)

func move_left():
	if currentState != state.SPLAT:
		sprite.flip_h = true
		direction = "left"
	if not onSnow:
		currentState = state.WALKING
		if not onIce:
			velocity.x = -moveSpeed
		else:
			velocity.x = lerp(velocity.x, -moveSpeed - 39, moveSpeedIceMultiplier)

# Helper function to pick jump direction from input
func get_jump_direction() -> int:
	if left_pressing and not right_pressing:
		return -1
	elif right_pressing and not left_pressing:
		return 1
	else:
		return 0

func inputs(delta):
	left_pressing = Input.is_action_pressed("left")
	right_pressing = Input.is_action_pressed("right")

	# Detect fresh presses/release for jump
	var jump_just_pressed_now = Input.is_action_just_pressed("jump")
	var jump_just_released_now = Input.is_action_just_released("jump")

	noClip = Input.is_action_pressed("noclip")

	# Noclip cheats
	if noClip:
		var noclip_speed = noCipSpeed * delta
		if Input.is_action_pressed("ui_left"):
			position.x -= noclip_speed
		if Input.is_action_pressed("ui_right"):
			position.x += noclip_speed
		if Input.is_action_pressed("ui_up"):
			position.y -= noclip_speed
		if Input.is_action_pressed("ui_down"):
			position.y += noclip_speed
		return

	# -----------------------------------------------------------------------
	# Jump charging logic using fresh press
	# -----------------------------------------------------------------------
	if jump_just_pressed_now and grounded and canMove():
		currentState = state.CHARGING
		jumpPower = 0
	
	if currentState == state.CHARGING:
		jumpPower += jumpPowerStep * delta
		# If we exceed maxPower, jump automatically
		if jumpPower >= maxPower:
			jumpPower = maxPower
			jump(clamp(jumpPower, minPower, maxPower), get_jump_direction())
		# If the player releases jump before reaching max, jump with final power
		elif jump_just_released_now and grounded:
			jump(clamp(jumpPower, minPower, maxPower), get_jump_direction())

	# -----------------------------------------------------------------------
	# Normal movement input (only if IDLE or WALKING)
	# -----------------------------------------------------------------------
	if grounded and canMove():
		if currentState in [state.IDLE, state.WALKING]:
			if right_pressing and not left_pressing:
				move_right()
			elif left_pressing and not right_pressing:
				move_left()

	# -----------------------------------------------------------------------
	# Recover from FALLING or SPLAT if on ground => Pressing move or jump
	# sets you back to normal.
	# -----------------------------------------------------------------------
	if grounded:
		# Recover from FALLING
		if currentState == state.FALLING:
			# Move input
			if left_pressing:
				currentState = state.WALKING
				move_left()
			elif right_pressing:
				currentState = state.WALKING
				move_right()
			# Jump input
			elif jump_just_pressed_now and canJump():
				currentState = state.CHARGING
				jumpPower = 0  # reset so we can charge

		# Recover from SPLAT
		if currentState == state.SPLAT:
			if left_pressing or right_pressing:
				stunned = false
				currentState = state.WALKING
				if left_pressing:
					move_left()
				else:
					move_right()
			elif jump_just_pressed_now and canJump():
				stunned = false
				currentState = state.CHARGING
				jumpPower = 0  # start fresh

func apply_gravity(delta):
	if not noClip:
		velocity.y += gravity * delta
		if currentState == state.JUMPING and velocity.y > 0:
			currentState = state.FALLING
		if velocity.y > maxSpeed and not grounded:
			velocity.y = maxSpeed
	else:
		velocity = Vector2.ZERO

func handle_movement(delta):
	if noClip:
		return
	moveInfo = move_and_slide(velocity, Vector2.UP, true, 4, 0.1, true)

# ---------------------------------------------------------------------------
# State Handling
# ---------------------------------------------------------------------------
func handle_states(delta):
	if noClip:
		currentState = state.IDLE
		return

	# Clear stun if IDLE or WALKING
	if currentState in [state.IDLE, state.WALKING]:
		stunned = false
		if grounded:
			if not onIce:
				if onSnow:
					velocity.x = 0
				else:
					velocity.x = 0 + WindManager.currentVelocity * windGroundMultiplier
			else:
				if not (left_pressing or right_pressing):
					velocity.x = lerp(velocity.x, 0, iceInertia)

	# Return from SPLAT if timer ended
	if currentState == state.SPLAT and grounded:
		if splatTimer.is_stopped():
			stunned = false

	# If we are walking but not pressing any direction, go IDLE
	if currentState == state.WALKING:
		if not (left_pressing or right_pressing):
			currentState = state.IDLE

	# Walked off a ledge => FALLING
	if currentState in [state.WALKING, state.IDLE, state.CHARGING] and not grounded:
		currentState = state.FALLING

	# Landed => SPLAT or IDLE
	if currentState == state.FALLING and grounded:
		if abs(previous_y_vel) > splatThreshold:
			currentState = state.SPLAT
			audioPlayer.stream = splatSound
			audioPlayer.play()
			splatTimer.start()
			stunned = true
		else:
			currentState = state.IDLE
			stunned = false
			if onIce:
				audioPlayer.stream = iceLandingSound
			elif onSnow:
				audioPlayer.stream = snowLandingSound
			else:
				audioPlayer.stream = landingSound
			audioPlayer.play()

	# If SPLAT on ground (and not onSlope), friction
	if currentState == state.SPLAT and grounded and not onSlope:
		if not onIce:
			if onSnow:
				velocity.x = 0
			else:
				velocity.x = 0 + WindManager.currentVelocity * windGroundMultiplier
		else:
			velocity.x = lerp(velocity.x, 0, iceInertia)

func detect_slopes():
	var floor_normal = get_floor_normal()
	if floor_normal != Vector2(0, 0) and floor_normal != Vector2(0, -1):
		onSlope = true
	elif floor_normal != Vector2(0, 0):
		onSlope = false
	previous_floor_normal = floor_normal

# ---------------------------------------------------------------------------
# Jump, Grounded Check, Bounce
# ---------------------------------------------------------------------------
func jump(power: float, dir: int):
	if power < minPower:
		power = minPower

	# Play jump sound
	if onIce:
		audioPlayer.stream = iceJumpSound
	elif onSnow:
		audioPlayer.stream = snowJumpSound
	else:
		audioPlayer.stream = jumpSound
	audioPlayer.play()

	currentState = state.JUMPING
	velocity.y = 0

	var newJumpParticle
	if onSnow:
		newJumpParticle = snowJumpParticle.instance()
	else:
		newJumpParticle = jumpParticle.instance()
	newJumpParticle.position = position
	get_tree().get_root().get_node("World").add_child(newJumpParticle)

	velocity.y -= maxJump * power

	# Keep or override horizontal velocity
	if dir == 0:
		if not onIce:
			velocity.x = 0
	elif dir == -1:
		velocity.x = dir * moveSpeed * jumpHMultiplier
		sprite.flip_h = true
	else:
		velocity.x = dir * moveSpeed * jumpHMultiplier
		sprite.flip_h = false

	jumpPower = 0

func check_grounded():
	var overlappers = $GroundedArea.get_overlapping_bodies()
	grounded = false
	for body in overlappers:
		if body in mapCollisions:
			grounded = true
			break

func check_bounces():
	var overlappers = $BounceArea.get_overlapping_bodies()
	if not overlappers.empty() and not grounded:
		for body in overlappers:
			if body in mapCollisions:
				if abs(velocity.x) > bounceVelocityThreshold:
					velocity.x = velocity.bounce(velocity.normalized()).x * bounceMultiplier
				else:
					velocity.x = velocity.bounce(velocity.normalized()).x
				stunned = true
				if abs(velocity.x) > bounceSoundThreshold and not onSlope:
					audioPlayer.stream = bumpSound
					audioPlayer.play()
				break

	var head_overlappers = $HeadBounceArea.get_overlapping_bodies()
	if not head_overlappers.empty():
		for body in head_overlappers:
			if body in mapCollisions:
				velocity.y = velocity.bounce(velocity.normalized()).y * bounceMultiplier * 0.6
				if abs(velocity.x) > bounceVelocityThreshold:
					velocity.x *= bounceMultiplier
				if abs(velocity.y) > bounceSoundThreshold:
					audioPlayer.stream = bumpSound
					audioPlayer.play()
				break

# ---------------------------------------------------------------------------
# Animations, etc.
# ---------------------------------------------------------------------------
func handle_animations():
	match currentState:
		state.IDLE:
			animationPlayer.play("Idle")
		state.WALKING:
			animationPlayer.play("walk")
		state.FALLING:
			if stunned:
				animationPlayer.play("air_collide")
			else:
				animationPlayer.play("falling")
		state.CHARGING:
			animationPlayer.play("jump_start")
		state.JUMPING:
			if stunned:
				animationPlayer.play("air_collide")
			else:
				animationPlayer.play("jump_release")
		state.SPLAT:
			animationPlayer.play("splat")

func canJump():
	return grounded and not stunned

func canMove():
	return grounded and not stunned

func _on_SplatTimer_timeout():
	stunned = false

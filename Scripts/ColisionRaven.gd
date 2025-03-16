extends Area2D  # We use Area2D to detect collisions

onready var sprite = $AnimatedSprite
onready var ravenSound = load("res://Audio/raven/raven.wav")
onready var audioPlayer = $audioPlayerRaven

var timer = 0.0
var current_frame = 0
var can_detect = false     # Enabled after 0.5s so collisions don't fire too early
var borrado = false        # True once we've removed the CollisionShape2D

# We'll track flying time manually.
var flight_timer = 0.0
var flight_duration = 10.0

func _ready():
	# Force-connect the body_entered signal, just in case
	if not borrado:
		connect("body_entered", self, "_on_Area2D_body_entered")

	randomize()  # Ensure better randomness for pick_random
	# Wait 0.5 seconds, then enable collision detection
	yield(get_tree().create_timer(0.5), "timeout")
	can_detect = true
	
	# Set initial sprite frame and start processing
	sprite.frame = 0
	set_process(true)
	set_physics_process(true)

func _process(delta):
	# Handle sprite frames
	timer -= delta
	if timer <= 0:
		change_frame()

	# If we’re in the “flying” animation, move diagonally
	if can_detect and sprite.animation == "flying":
		var angle = deg2rad(-60)  # Adjust as needed
		var speed = 250
		var direction = Vector2(cos(angle), sin(angle))
		sprite.position += direction * speed * delta

		# Remove the CollisionShape2D if not already removed
		if not borrado:
			var collision_shape = $CollisionShape2D
			if collision_shape:
				collision_shape.queue_free()
				borrado = true

		# Track how long we've been flying
		flight_timer += delta
		if flight_timer >= flight_duration:
			print("Time exceeded. Destroying node.")
			queue_free()  # Safe to do now (no yield left to resume!)

func change_frame():
	if current_frame == 0:
		if randf() < 0.5:  
			timer = rand_range(1.5, 2.5)
			current_frame = 1  
		else:
			timer = rand_range(1.5, 3.0)
			current_frame = pick_random([2, 3])  
	elif current_frame == 1:
		timer = 0.05  
		current_frame = 0  
	elif current_frame == 2:
		timer = rand_range(1.5, 3.0)
		current_frame = pick_random([0, 3])  
	elif current_frame == 3:
		timer = rand_range(1.5, 3.0)
		current_frame = pick_random([0, 2])
	sprite.frame = current_frame

func pick_random(choices):
	return choices[randi() % choices.size()]

# Detect collision only with the King and trigger "flying" animation + sound
func _on_Area2D_body_entered(body):
	if not can_detect:
		return  # Ignore if collision isn't allowed yet

	if body.is_in_group("player"):
		sprite.speed_scale = 1.5
		sprite.play("flying")
		audioPlayer.stop()
		audioPlayer.stream = ravenSound
		audioPlayer.play()

# Optional: Reset animation when King exits
func _on_Area2D_body_exited(body):
	if body.is_in_group("player"):
		sprite.play("idle")  # Ensure you have an "idle" animation

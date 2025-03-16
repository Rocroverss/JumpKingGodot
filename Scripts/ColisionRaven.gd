extends Area2D  # We use Area2D to detect collisions

onready var sprite = $AnimatedSprite
onready var ravenSound = load("res://Audio/raven/raven.wav")
onready var audioPlayer = $audioPlayerRaven

var timer = 0.0
var current_frame = 0
var can_detect = false  # Start as false, enable later
var borrado = false
		
func _ready():
	#print("✅ Raven script is loaded!")  # Make sure script is running
	if not borrado:
		connect("body_entered", self, "_on_Area2D_body_entered")  # Force signal connection
	randomize()  # Ensure proper randomness
	yield(get_tree().create_timer(0.5), "timeout")  # Delay detection initially
	can_detect = true  # Enable collision detection
	#print("Raven is ready for real collisions!")

	sprite.frame = 0  # Start on frame 0
	set_process(true)
	set_physics_process(true)	

func _process(delta):
	timer -= delta  # Reduce timer
	if timer <= 0:  # When timer runs out, switch frame
		change_frame()
	# Only move the sprite if it's in the flying animation
	if can_detect and sprite.animation == "flying":
		# Define the angle and speed
		var angle = deg2rad(-60)  # Angle in degrees, for example, 45 degrees
		var speed = 250  # Speed in pixels per second
		
		# Calculate the movement direction using the angle
		var direction = Vector2(cos(angle), sin(angle))  # Direction based on angle
		
		# Move the sprite based on direction and speed, factoring in delta for smooth movement
		sprite.position += direction * speed * delta  # Move the sprite smoothly over time
		# Find and destroy the CollisionShape2D child node
		if not borrado:
			var collision_shape = $CollisionShape2D  # Access the child node by its name
			if collision_shape:
				collision_shape.queue_free()  # Destroy the CollisionShape2D node
				borrado = true
		yield(get_tree().create_timer(10), "timeout")
		print("Time exceeded. Destroying node.")
		self.queue_free()  # Destroy the current node (removes it from the scene)
		#	is_moving = false  # Stop further movement
		#is_moving = false  # Stop further movement

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


# Detect collision only with the King and trigger animation + sound
func _on_Area2D_body_entered(body):
	#print("Raven collided with:", body.name)
	#print("TriggerZone collided with:", body.name)
	if not can_detect:
		#print("Collision ignored: not ready yet!")
		return  # Prevents collision detection before it's allowed

	#print("Collision detected!")

	if body.is_in_group("player"):
		#print("King entered Raven's area!")
		sprite.speed_scale = 1.5  # Set animation speed to 1.5x
		sprite.play("flying")  # Ensure you have an animation named "flying"
		# Add movement logic here

		audioPlayer.stop()  
		audioPlayer.stream = ravenSound  
		audioPlayer.play()
	else:
		#print("Wrong group detected!")
		#print("Body entered:", body.name)  # Check which object enters
		#print("Groups:", body.get_groups())  # List all groups of the object
		pass

# Reset animation when King exits
func _on_Area2D_body_exited(body):
	if body.is_in_group("player"):
		#print("King exited Raven's area!")
		sprite.play("idle")  # Ensure an "idle" animation exists

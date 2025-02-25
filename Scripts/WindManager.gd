extends Node

var STRENGTH := 0.1    # How strong the wind can get (max +/-0.1)
var SPEED := 0.48      # How fast the wind oscillates
var currentVelocity := 0.0

onready var start_time := OS.get_ticks_msec()
var currLevel

func _ready():
	currLevel = Globals.currentLevel


func _process(delta):
	# Only apply wind in certain levels
	if Globals.currentLevel > 25 and Globals.currentLevel < 33:
		currentVelocity = getCurrentVelocity()
	else:
		currentVelocity = 0.0


func getCurrentVelocity() -> float:
	# Elapsed time in seconds
	var elapsed := float(OS.get_ticks_msec() - start_time) / 1000.0
	# Create a sine wave in [-1, +1]
	var wave_value = sin(elapsed * SPEED)
	# Scale the sine wave by STRENGTH (so final wind is in [-0.1, +0.1])
	return wave_value * STRENGTH

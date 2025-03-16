extends Node2D

var playSound := preload("res://Audio/gui_sfx/menu_confirm.wav")
var save_location = "user://save/save_state.json"
var confirm_delete = false  # Track if delete confirmation is needed
var borrando = false
# Called when the node enters the scene tree for the first time.
func _ready():
	$AnimationPlayer.play("Logo rise")
	pass # Replace with function body.

func _input(event):
	if event.is_action_pressed("jump") and not confirm_delete:
		#print("Loading on single.")
		$Label/Timer.wait_time /= 8
		$sfxplayer.stream = playSound
		$sfxplayer.play()
		$musicplayer.stop()
		yield($sfxplayer, "finished")

		get_tree().change_scene("res://Scenes/Testlevel.tscn")

	elif event.is_action_pressed("O"):
		borrando = !borrando
		if not confirm_delete:
			# Cancel deletion and restore the UI
			confirm_delete = false
			$SUREDELETE.visible = false
			$Label.visible = true
			$pressx.visible = true
			#print("Deletion canceled.")
		else:
			# Show confirmation message
			confirm_delete = true
			$SUREDELETE.visible = false
			$Label.visible = false
			$pressx.visible = false  # Hide the regular prompt
			#print("Press 'X' to confirm delete, 'O' to cancel.")
		confirm_delete = ! confirm_delete 

	elif event.is_action_pressed("jump") and confirm_delete:  # Pressing X confirms deletion
		var file = File.new()
		if file.file_exists(save_location):
			file.open(save_location, File.READ)
			file.close()
			var dir = Directory.new()
			if dir.remove(save_location) == OK:
				print("Save file deleted successfully.")
			else:
				print("Failed to delete save file.")
		else:
			print("No save file found.")
		#print("Loading on tuple.")	
		$Label/Timer.wait_time /= 8
		$sfxplayer.stream = playSound
		$sfxplayer.play()
		$musicplayer.stop()
		yield($sfxplayer, "finished")
		get_tree().change_scene("res://Scenes/Testlevel.tscn")

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_Timer_timeout():
	if not borrando:
		$Label.visible = !$Label.visible
		$pressx.visible = !$pressx.visible
		$SUREDELETE.visible = false
	else:
		$Label.visible = false
		$pressx.visible = false
		$SUREDELETE.visible = !$SUREDELETE.visible
	pass # Replace with function body.

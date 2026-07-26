class_name LoopingMusic
extends AudioStreamPlayer


func _ready() -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	if not playing:
		play()

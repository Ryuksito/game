extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var eos := EOSManager.new()
	add_child(eos)
	print("Versión del SDK de Epic cargada: ", eos.get_eos_version())


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

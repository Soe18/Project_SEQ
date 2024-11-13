extends Timer

signal reset_knockback()

func _on_timeout() -> void:
	emit_signal("reset_knockback")
	queue_free()

extends Timer

signal reset_knockback()

@warning_ignore("unused_signal")

func _on_timeout() -> void:
	emit_signal("reset_knockback")
	queue_free()

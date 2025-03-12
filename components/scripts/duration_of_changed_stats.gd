extends Timer

var stat
var amount
signal reset_stats(stat, amount, time, ally)

@warning_ignore("unused_signal")

func _on_timeout():
	emit_signal("reset_stats", stat, amount, 0, true)
	queue_free()

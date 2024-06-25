extends Timer

var stat
var amount
signal change_stats(stat, amount)

# Called when the node enters the scene tree for the first time.
func _ready():
	change_stats.connect(get_parent()._on_change_stats)

func _on_timeout():
	emit_signal("change_stats", stat, amount, 0)
	self.queue_free()

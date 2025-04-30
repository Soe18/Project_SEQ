extends Area2D

func _on_body_entered(body):
	if "is_player" in body:
		if body.is_player:
			QuestManager.quests["a_to_b"].complete_quest()

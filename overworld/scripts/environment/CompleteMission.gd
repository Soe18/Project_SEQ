extends Area2D

func _on_body_entered(body):
	if "is_player" in body:
		if body.is_player:
			QuestManager.quests[1].reach_goal_quest()
			QuestManager.quests[2].complete_quest()

extends GridContainer
@onready var id = %ID
@onready var title = %TITLE
@onready var description = %DESCRIPTION
@onready var status = %STATUS

func set_labels(id_t, title_t, description_t, status_t):
	id.text = str(id_t)
	title.text = title_t
	description.text = description_t
	status.text = str(QuestStatus.of_type.find_key(status_t))

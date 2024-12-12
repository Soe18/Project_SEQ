class_name Quest extends Resource

@export_group("Quest info")
@export var title : String = "Default title"
@export var description : String = "Default description"
var current_step : int = 0
@export var steps : int = 1

var values = null

@export var status : QuestStatus.of_type = QuestStatus.of_type.available

@export_group("Rewards")
@export var todo : String = "yey"

func display_quest():
	if self.status == QuestStatus.of_type.hidden:
		print_debug("Quest available")
		self.status = QuestStatus.of_type.available

func start_quest():
	if self.status == QuestStatus.of_type.available:
		print_debug("Quest started")
		self.status = QuestStatus.of_type.started

func inc_step():
	if self.status == QuestStatus.of_type.started:
		self.current_step += 1
		self.check_completition()

func dec_step():
	if self.status == QuestStatus.of_type.started:
		self.current_step -= 1
		self.check_completition()

func check_completition():
	if self.status == QuestStatus.of_type.started:
		# Can't get negative steps!
		if self.current_step < 0:
			print_debug("Can't get negative steps!")
			self.current_step = 0
		# Mission complete!
		if self.current_step == self.steps:
			print_debug("Quest complete!")
			self.reach_goal_quest()

# To automatically reach quest, but must be started before
func reach_goal_quest():
	if self.status == QuestStatus.of_type.started:
		print_debug("Quest completed!")
		self.status = QuestStatus.of_type.reached_goal

func complete_quest():
	if self.status == QuestStatus.of_type.reached_goal:
		print_debug("Quest done.")
		self.status = QuestStatus.of_type.done

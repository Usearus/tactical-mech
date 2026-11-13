class_name TutorialHooks
extends RefCounted

static var director: TutorialDirector


static func active() -> bool:
	return GameManager.tutorial_mission and director != null and is_instance_valid(director)


static func allows(action: String, detail: String = "") -> bool:
	if not GameManager.tutorial_mission:
		return true
	if director == null or not is_instance_valid(director):
		return true
	return director.allows(action, detail)


static func notify(event: String, detail: String = "") -> void:
	if active():
		director.notify(event, detail)


static func settled() -> void:
	if active():
		director.settled()


static func retry() -> void:
	if active():
		director.retry_fight()


static func phase() -> String:
	if not active():
		return ""
	return director.phase_name()


static func fight() -> int:
	if not active():
		return 1
	return director.fight_index()


static func detail() -> String:
	if not active():
		return ""
	return director.current_detail()


static func any_target() -> bool:
	return active() and director.any_target()

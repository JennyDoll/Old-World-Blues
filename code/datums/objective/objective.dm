var/global/list/all_objectives = list()
var/global/list/all_objectives_types = null

/hook/startup/proc/init_objectives()
	all_objectives_types = list()
	var/indent = length("[/datum/objective]/")
	for(var/path in subtypesof(/datum/objective))
		var/id = copytext("[path]", indent+1)
		all_objectives_types[id] = path
	return TRUE

/datum/objective
	var/datum/mind/owner = null		//Who owns the objective.
	var/explanation_text = "Nothing"//What that person is supposed to do.
	var/datum/mind/target = null	//If they are focused on a particular person.
	var/target_amount = 0			//If they are focused on a particular number.
									//Steal objectives have their own counter.
	var/completed = FALSE			//currently only used for custom objectives.

/datum/objective/New(var/new_owner)
	if(new_owner)
		owner = new_owner
		owner.objectives += src
	find_target()
	all_objectives.Add(src)
	..()

/datum/objective/Destroy()
	all_objectives.Remove(src)
	if(owner)
		owner.objectives.Remove(src)
	return ..()

/datum/objective/proc/check_completion()
	return completed

/datum/objective/proc/get_targets_list()
	var/list/possible_targets = list()
	for(var/datum/mind/possible_target in ticker.minds)
		if(possible_target!=owner && ishuman(possible_target.current) && (possible_target.current.stat != DEAD))
			possible_targets.Add(possible_target)

	if(owner)
		for(var/datum/objective/O in owner.objectives)
			possible_targets -= O.target

	return possible_targets


/datum/objective/proc/find_target()
	var/list/possible_targets = get_targets_list()
	if(possible_targets && possible_targets.len > 0)
		target = pick(possible_targets)
	update_explanation()

/datum/objective/proc/select_human_target(var/mob/user)
	var/list/possible_targets = get_targets_list()
	if(!possible_targets || !possible_targets.len)
		user << SPAN_WARN("Sorry! No possible targets found!")
		return
	var/datum/mind/M = input(user, "New target") as null|anything in possible_targets
	if(M)
		target = M
		update_explanation()


/datum/objective/proc/update_explanation()

/datum/objective/proc/get_panel_entry()
	return explanation_text

/datum/objective/Topic(href, href_list)
	if(!check_rights(R_DEBUG))
		return TRUE

	if(href_list["switch_target"])
		select_human_target(usr)
		owner.edit_memory()

	if(href_list["set_amount"])
		var/new_target = input("Input target number:", href_list["set_amount"], target_amount) as num|null
		if(new_target < 1)
			return
		else
			target_amount = new_target
			update_explanation()
			owner.edit_memory()
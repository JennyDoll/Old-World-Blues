/mob/living/carbon/process_resist()

	//drop && roll
	if(on_fire && !buckled)
		fire_stacks -= 1.2
		Weaken(3)
		spin(32,2)
		visible_message(
			"<span class='danger'>[src] rolls on the floor, trying to put themselves out!</span>",
			SPAN_NOTE("You stop, drop, and roll!")
			)
		sleep(30)
		if(fire_stacks <= 0)
			visible_message(
				"<span class='danger'>[src] has successfully extinguished themselves!</span>",
				SPAN_NOTE("You extinguish yourself.")
				)
			ExtinguishMob()
		return

	..()

	if(handcuffed)
		spawn() escape_handcuffs()
	else if(legcuffed)
		spawn() escape_legcuffs()

/mob/living/carbon/proc/escape_handcuffs()
	self_attack_log(src, "tries to remove handcuffs")
	//if(!(last_special <= world.time)) return

	//This line represent a significant buff to grabs...
	// We don't have to check the click cooldown because /mob/living/verb/resist() has done it for us, we can simply set the delay
	setClickCooldown(100)

	if(can_break_cuffs()) //Don't want to do a lot of logic gating here.
		break_handcuffs()
		return

	var/obj/item/weapon/handcuffs/HC = handcuffed

	//A default in case you are somehow handcuffed with something that isn't an obj/item/weapon/handcuffs type
	var/breakouttime = 1200
	var/displaytime = 2 //Minutes to display in the "this will take X minutes."
	//If you are handcuffed with actual handcuffs... Well what do I know, maybe someone will want to handcuff you with toilet paper in the future...
	if(istype(HC))
		breakouttime = HC.breakouttime
		displaytime = breakouttime / 600 //Minutes

	visible_message(
		"<span class='danger'>\The [src] attempts to remove \the [HC]!</span>",
		"<span class='warning'>You attempt to remove \the [HC]. (This will take around [displaytime] minutes and you need to stand still)</span>"
		)

	if(do_after(src, breakouttime))
		if(!handcuffed || buckled)
			return
		visible_message(
			"<span class='danger'>\The [src] manages to remove \the [handcuffed]!</span>",
			SPAN_NOTE("You successfully remove \the [handcuffed].")
			)
		self_attack_log(src, "removed handcuffs", 1)
		drop_from_inventory(handcuffed)

/mob/living/carbon/proc/escape_legcuffs()
	if(!canClick())
		return

	setClickCooldown(100)

	if(can_break_cuffs()) //Don't want to do a lot of logic gating here.
		break_legcuffs()
		return

	var/obj/item/weapon/legcuffs/HC = legcuffed

	//A default in case you are somehow legcuffed with something that isn't an obj/item/weapon/legcuffs type
	var/breakouttime = 1200
	var/displaytime = 2 //Minutes to display in the "this will take X minutes."
	//If you are legcuffed with actual legcuffs... Well what do I know, maybe someone will want to legcuff you with toilet paper in the future...
	if(istype(HC))
		breakouttime = HC.breakouttime
		displaytime = breakouttime / 600 //Minutes

	visible_message(
		"<span class='danger'>[usr] attempts to remove \the [HC]!</span>",
		"<span class='warning'>You attempt to remove \the [HC]. (This will take around [displaytime] minutes and you need to stand still)</span>"
		)

	if(do_after(src, breakouttime))
		if(!legcuffed || buckled)
			return
		visible_message(
			"<span class='danger'>[src] manages to remove \the [legcuffed]!</span>",
			SPAN_NOTE("You successfully remove \the [legcuffed].")
			)

		drop_from_inventory(legcuffed)
		legcuffed = null
		update_inv_legcuffed()

/mob/living/carbon/proc/can_break_cuffs()
	//TODO: DNA3 hulk
	/*
	if(HULK in mutations)
		return 1
	*/

/mob/living/carbon/proc/break_handcuffs()
	visible_message(
		"<span class='danger'>[src] is trying to break \the [handcuffed]!</span>",
		"<span class='warning'>You attempt to break your [handcuffed.name]. (This will take around 5 seconds and you need to stand still)</span>"
		)

	if(do_after(src, 50))
		if(!handcuffed || buckled)
			return

		self_attack_log(src, "broke their handcuffs", 1)

		visible_message(
			"<span class='danger'>[src] manages to break \the [handcuffed]!</span>",
			"<span class='warning'>You successfully break your [handcuffed.name].</span>"
			)

		say(pick(";RAAAAAAAARGH!", ";HNNNNNNNNNGGGGGGH!", ";GWAAAAAAAARRRHHH!", "NNNNNNNNGGGGGGGGHH!", ";AAAAAAARRRGH!" ))

		qdel(handcuffed)
		handcuffed = null
		if(buckled && buckled.buckle_require_restraints)
			buckled.unbuckle_mob()
		update_inv_handcuffed()

/mob/living/carbon/proc/break_legcuffs()
	src << "<span class='warning'>You attempt to break your legcuffs. (This will take around 5 seconds and you need to stand still)</span>"
	visible_message("<span class='danger'>[src] is trying to break the legcuffs!</span>")

	if(do_after(src, 50))
		if(!legcuffed || buckled)
			return

		visible_message(
			"<span class='danger'>[src] manages to break the legcuffs!</span>",
			"<span class='warning'>You successfully break your legcuffs.</span>"
			)

		say(pick(";RAAAAAAAARGH!", ";HNNNNNNNNNGGGGGGH!", ";GWAAAAAAAARRRHHH!", "NNNNNNNNGGGGGGGGHH!", ";AAAAAAARRRGH!" ))

		qdel(legcuffed)
		legcuffed = null
		update_inv_legcuffed()

/mob/living/carbon/human/can_break_cuffs()
	if(can_shred(1))
		return 1
	return ..()

/mob/living/carbon/escape_buckle()
	setClickCooldown(100)
	if(!buckled) return

	if(!restrained())
		..()
	else
		visible_message(
			"<span class='danger'>[usr] attempts to unbuckle themself!</span>",
			"<span class='warning'>You attempt to unbuckle yourself. (This will take around 2 minutes and you need to stand still)</span>"
			)

		if(do_after(usr, 1200))
			if(!buckled)
				return
			visible_message("<span class='danger'>[usr] manages to unbuckle themself!</span>",
							SPAN_NOTE("You successfully unbuckle yourself."))
			buckled.user_unbuckle_mob(src)

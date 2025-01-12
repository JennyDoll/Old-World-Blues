/obj/item/device/flashlight
	name = "flashlight"
	desc = "A hand-held emergency light."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "flashlight"
	item_state = "flashlight"
	w_class = ITEM_SIZE_SMALL
	flags = CONDUCT
	slot_flags = SLOT_BELT

	matter = list(MATERIAL_STEEL = 50,MATERIAL_GLASS = 20)

	icon_action_button = "action_flashlight"
	var/on = 0
	var/brightness_on = 4 //luminosity when on
	var/activation_sound = 'sound/items/flashlight.ogg'

/obj/item/device/flashlight/initialize()
	..()
	update_icon()

/obj/item/device/flashlight/update_icon()
	if(on)
		icon_state = "[initial(icon_state)]-on"
		set_light(brightness_on)
	else
		icon_state = "[initial(icon_state)]"
		set_light(0)

/obj/item/device/flashlight/attack_self(mob/user)
	if(!isturf(user.loc))
		user << "You cannot turn the light on while in this [user.loc]." //To prevent some lighting anomalities.
		return 0
	on = !on
	if(on && activation_sound)
		playsound(src.loc, activation_sound, 75, 1)
	update_icon()
	return 1


/obj/item/device/flashlight/attack(mob/living/M as mob, mob/living/user as mob)
	add_fingerprint(user)
	if(on && user.zone_sel.selecting == O_EYES)

		if(user.getBrainLoss() >= 60 && prob(50))	//too dumb to use flashlight properly
			return ..()	//just hit them in the head

		var/mob/living/carbon/human/H = M	//mob has protective eyewear
		if(istype(H))
			for(var/obj/item/clothing/C in list(H.head,H.wear_mask,H.glasses))
				if(istype(C) && (C.body_parts_covered & EYES))
					user << "<span class='warning'>You're going to need to remove [C.name] first.</span>"
					return

			var/obj/item/organ/vision
			if(H.species.vision_organ)
				vision = H.internal_organs_by_name[H.species.vision_organ]
			if(!vision)
				user << "<span class='warning'>You can't find any [H.species.vision_organ ? H.species.vision_organ : "eyes"] on [H]!</span>"

			user.visible_message(SPAN_NOTE("\The [user] directs [src] to [M]'s eyes."), \
							 	 SPAN_NOTE("You direct [src] to [M]'s eyes."))
			if(H != user)	//can't look into your own eyes buster
				if(H.stat == DEAD || H.blinded)	//mob is dead or fully blind
					user << "<span class='warning'>\The [H]'s pupils do not react to the light!</span>"
					return
				//TODO: DNA3 xray
				//TODO: move to organ code
				/*
				if(XRAY in H.mutations)
					user << SPAN_NOTE("\The [H] pupils give an eerie glow!")
				*/
				if(vision.is_bruised())
					user << "<span class='warning'>There's visible damage to [H]'s [vision.name]!</span>"
				else if(M.eye_blurry)
					user << SPAN_NOTE("\The [H]'s pupils react slower than normally.")
				if(H.getBrainLoss() > 15)
					user << SPAN_NOTE("There's visible lag between left and right pupils' reactions.")

				var/list/pinpoint = list("oxycodone"=1,"tramadol"=5)
				var/list/dilating = list("space_drugs"=5,"mindbreaker"=1)
				if(M.reagents.has_any_reagent(pinpoint) || H.ingested.has_any_reagent(pinpoint))
					user << SPAN_NOTE("\The [H]'s pupils are already pinpoint and cannot narrow any more.")
				else if(H.reagents.has_any_reagent(dilating) || H.ingested.has_any_reagent(dilating))
					user << SPAN_NOTE("\The [H]'s pupils narrow slightly, but are still very dilated.")
				else
					user << SPAN_NOTE("\The [H]'s pupils narrow.")

			user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN) //can be used offensively
			flick("flash", M.flash)
			//M.flash_eyes()
	else
		return ..()

/obj/item/device/flashlight/pen
	name = "penlight"
	desc = "A pen-sized light, used by medical staff."
	icon_state = "penlight"
	item_state = ""
	flags = CONDUCT
	slot_flags = SLOT_EARS
	brightness_on = 2
	w_class = ITEM_SIZE_TINY

/obj/item/device/flashlight/drone
	name = "low-power flashlight"
	desc = "A miniature lamp, that might be used by small robots."
	icon_state = "penlight"
	item_state = ""
	flags = CONDUCT
	brightness_on = 2
	w_class = ITEM_SIZE_TINY

/obj/item/device/flashlight/heavy
	name = "heavy duty flashlight"
	desc = "A hand-held heavy-duty light."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "heavyduty"
	item_state = "heavyduty"
	brightness_on = 6

/obj/item/device/flashlight/seclite
	name = "security flashlight"
	desc = "A hand-held security flashlight. Very robust."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "seclite"
	item_state = "seclite"
	brightness_on = 5
	force = 10.0
	hitsound = 'sound/weapons/genhit1.ogg'


// the desk lamps are a bit special
/obj/item/device/flashlight/lamp
	name = "desk lamp"
	desc = "A desk lamp with an adjustable mount."
	icon_state = "lamp"
	item_state = "lamp"
	brightness_on = 5
	w_class = ITEM_SIZE_LARGE
	flags = CONDUCT

	on = 1


// green-shaded desk lamp
/obj/item/device/flashlight/lamp/green
	desc = "A classic green-shaded desk lamp."
	icon_state = "lampgreen"
	item_state = "lampgreen"
	brightness_on = 5
	light_color = "#FFC58F"

/obj/item/device/flashlight/lamp/verb/toggle_light()
	set name = "Toggle light"
	set category = "Object"
	set src in oview(1)

	if(!usr.stat)
		attack_self(usr)

/obj/item/device/flashlight/lamp/AltClick(var/mob/user)
	if(in_range(src,user))
		src.toggle_light()

// FLARES

/obj/item/device/flashlight/flare
	name = "flare"
	desc = "A red Nanotrasen issued flare. There are instructions on the side, it reads 'pull cord, make light'."
	w_class = ITEM_SIZE_TINY
	brightness_on = 8 // Pretty bright.
	light_power = 3
	light_color = "#e58775"
	icon_state = "flare"
	item_state = "flare"
	icon_action_button = null	//just pull it manually, neckbeard.
	var/fuel = 0
	var/on_damage = 7
	var/produce_heat = 1500

/obj/item/device/flashlight/flare/New()
	fuel = rand(800, 1000) // Sorry for changing this so much but I keep under-estimating how long X number of ticks last in seconds.
	..()

/obj/item/device/flashlight/flare/process()
	var/turf/pos = get_turf(src)
	if(pos)
		pos.hotspot_expose(produce_heat, 5)
	fuel = max(fuel - 1, 0)
	if(!fuel || !on)
		turn_off()
		if(!fuel)
			src.icon_state = "[initial(icon_state)]-empty"
		processing_objects -= src

/obj/item/device/flashlight/flare/proc/turn_off()
	on = 0
	src.force = initial(src.force)
	src.damtype = initial(src.damtype)
	update_icon()

/obj/item/device/flashlight/flare/attack_self(mob/user)

	// Usual checks
	if(!fuel)
		user << SPAN_NOTE("It's out of fuel.")
		return
	if(on)
		return

	. = ..()
	// All good, turn it on.
	if(.)
		user.visible_message(SPAN_NOTE("[user] activates the flare."), SPAN_NOTE("You pull the cord on the flare, activating it!"))
		src.force = on_damage
		src.damtype = "fire"
		processing_objects += src

/obj/item/device/flashlight/slime
	gender = PLURAL
	name = "glowing slime extract"
	desc = "A glowing ball of what appears to be amber."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "floor1" //not a slime extract sprite but... something close enough!
	item_state = "slime"
	w_class = ITEM_SIZE_TINY
	brightness_on = 6
	on = 1 //Bio-luminesence has one setting, on.

/obj/item/device/flashlight/slime/New()
	..()
	set_light(brightness_on)

/obj/item/device/flashlight/slime/update_icon()
	return

/obj/item/device/flashlight/slime/attack_self(mob/user)
	return //Bio-luminescence does not toggle.

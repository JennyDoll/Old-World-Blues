/* SmartFridge.  Much todo
*/
/obj/machinery/smartfridge
	name = "\improper SmartFridge"
	icon = 'icons/obj/vending.dmi'
	icon_state = "smartfridge"
	layer = 2.9
	density = 1
	anchored = 1
	use_power = 1
	idle_power_usage = 5
	active_power_usage = 100
	flags = NOREACT
	var/global/max_n_of_items = 999 // Sorry but the BYOND infinite loop detector doesn't look things over 1000.
	var/icon_on = "smartfridge"
	var/icon_off = "smartfridge-off"
	var/icon_panel = "smartfridge-panel"
	var/item_quants = list()
	var/seconds_electrified = 0;
	var/shoot_inventory = 0
	var/locked = 0
	var/scan_id = 1
	var/is_secure = 0
	var/datum/wires/smartfridge/wires = null

/obj/machinery/smartfridge/secure
	is_secure = 1

/obj/machinery/smartfridge/New()
	..()
	if(is_secure)
		wires = new/datum/wires/smartfridge/secure(src)
	else
		wires = new/datum/wires/smartfridge(src)

/obj/machinery/smartfridge/Destroy()
	qdel(wires)
	..()

/obj/machinery/smartfridge/proc/accept_check(var/obj/item/O as obj)
	if(istype(O,/obj/item/weapon/reagent_containers/food/snacks/grown/) || istype(O,/obj/item/seeds/))
		return 1
	return 0

/obj/machinery/smartfridge/seeds
	name = "\improper MegaSeed Servitor"
	desc = "When you need seeds fast!"
	icon = 'icons/obj/vending.dmi'
	icon_state = "seeds"
	icon_on = "seeds"
	icon_off = "seeds-off"

/obj/machinery/smartfridge/seeds/accept_check(var/obj/item/O as obj)
	return istype(O,/obj/item/seeds/)

/obj/machinery/smartfridge/secure/extract
	name = "\improper Biological Sample Storage"
	desc = "A refrigerated storage unit for xenobiological samples."
	req_access = list(access_research)

/obj/machinery/smartfridge/secure/extract/accept_check(var/obj/item/O as obj)
	return istype(O,/obj/item/slime_extract)

/obj/machinery/smartfridge/secure/medbay
	name = "\improper Refrigerated Medicine Storage"
	desc = "A refrigerated storage unit for storing medicine and chemicals."
	icon_state = "smartfridge" //To fix the icon in the map editor.
	icon_on = "smartfridge_chem"
	req_one_access = list(access_medical,access_chemistry)

/obj/machinery/smartfridge/secure/medbay/accept_check(var/obj/item/O as obj)
	if(istype(O,/obj/item/weapon/reagent_containers/glass/))
		return 1
	if(istype(O,/obj/item/storage/pill_bottle/))
		return 1
	if(istype(O,/obj/item/weapon/reagent_containers/pill/))
		return 1
	return 0

/obj/machinery/smartfridge/secure/virology
	name = "\improper Refrigerated Virus Storage"
	desc = "A refrigerated storage unit for storing viral material."
	req_access = list(access_virology)
	icon_state = "smartfridge_virology"
	icon_on = "smartfridge_virology"
	icon_off = "smartfridge_virology-off"

/obj/machinery/smartfridge/secure/virology/accept_check(var/obj/item/O as obj)
	if(istype(O,/obj/item/weapon/reagent_containers/glass/beaker/vial/))
		return 1
	if(istype(O,/obj/item/weapon/virusdish/))
		return 1
	return 0

/obj/machinery/smartfridge/chemistry
	name = "\improper Smart Chemical Storage"
	desc = "A refrigerated storage unit for medicine and chemical storage."

/obj/machinery/smartfridge/chemistry/accept_check(var/obj/item/O as obj)
	if(istype(O,/obj/item/storage/pill_bottle) || istype(O,/obj/item/weapon/reagent_containers))
		return 1
	return 0

/obj/machinery/smartfridge/secure/blood
	name = "\improper Smart Blood Bank"
	desc = "A refrigerated storage unit for blood and spare blood packs."
	req_access = list(access_medical)
	icon_state = "smartfridge_blood"
	icon_on = "smartfridge_blood"
	icon_off = "smartfridge_blood-off"

/obj/machinery/smartfridge/secure/blood/New()
	..()
	for(var/i = 0, i<3, i++)
		add_item(new/obj/item/weapon/reagent_containers/blood/AMinus)
		add_item(new/obj/item/weapon/reagent_containers/blood/APlus)
		add_item(new/obj/item/weapon/reagent_containers/blood/BMinus)
		add_item(new/obj/item/weapon/reagent_containers/blood/BPlus)
		add_item(new/obj/item/weapon/reagent_containers/blood/OMinus)
		add_item(new/obj/item/weapon/reagent_containers/blood/OPlus)
	for(var/i = 0, i<5, i++)
		add_item(new/obj/item/weapon/reagent_containers/blood/empty)



/obj/machinery/smartfridge/secure/blood/accept_check(var/obj/item/O as obj)
	if(istype(O,/obj/item/weapon/reagent_containers/blood/))
		return 1

/obj/machinery/smartfridge/chemistry/virology
	name = "\improper Smart Virus Storage"
	desc = "A refrigerated storage unit for volatile sample storage."


/obj/machinery/smartfridge/drinks
	name = "\improper Drink Showcase"
	desc = "A refrigerated storage unit for tasty tasty alcohol."

/obj/machinery/smartfridge/drinks/accept_check(var/obj/item/O as obj)
	var/valid_types = list(
		/obj/item/weapon/reagent_containers/glass,
		/obj/item/weapon/reagent_containers/glass/drinks,
		/obj/item/weapon/reagent_containers/condiment,
	)
	return is_type_in_list(O, valid_types)

/obj/machinery/smartfridge/drying_rack
	name = "\improper Drying Rack"
	desc = "A machine for drying plants."
	icon_state = "drying_rack"
	icon_on = "drying_rack_on"
	icon_off = "drying_rack"

/obj/machinery/smartfridge/drying_rack/accept_check(var/obj/item/O as obj)
	if(istype(O, /obj/item/weapon/reagent_containers/food/snacks/))
		var/obj/item/weapon/reagent_containers/food/snacks/S = O
		if (S.dried_type)
			return 1
	return 0

/obj/machinery/smartfridge/drying_rack/process()
	..()
	if (contents.len)
		dry()

/obj/machinery/smartfridge/drying_rack/proc/dry()
	for(var/obj/item/weapon/reagent_containers/food/snacks/S in contents)
		if(S.dry) continue
		if(S.dried_type == S.type)
			S.dry = 1
			item_quants[S.name]--
			S.name = "dried [S.name]"
			S.color = "#AAAAAA"
			S.loc = loc
		else
			var/D = S.dried_type
			new D(loc)
			item_quants[S.name]--
			qdel(S)
		return
	return

/obj/machinery/smartfridge/process()
	if(stat & (BROKEN|NOPOWER))
		return
	if(src.seconds_electrified > 0)
		src.seconds_electrified--
	if(src.shoot_inventory && prob(2))
		src.throw_item()

/obj/machinery/smartfridge/update_icon()
	if(stat & (BROKEN|NOPOWER))
		icon_state = icon_off
	else
		icon_state = icon_on

/*******************
*   Item Adding
********************/

/obj/machinery/smartfridge/attackby(var/obj/item/O as obj, var/mob/user as mob)
	if(istype(O, /obj/item/weapon/screwdriver))
		panel_open = !panel_open
		user.visible_message("[user] [panel_open ? "opens" : "closes"] the maintenance panel of \the [src].", "You [panel_open ? "open" : "close"] the maintenance panel of \the [src].")
		overlays.Cut()
		if(panel_open)
			overlays += image(icon, icon_panel)
		nanomanager.update_uis(src)
		return

	if(istype(O, /obj/item/device/multitool)||istype(O, /obj/item/weapon/wirecutters))
		if(panel_open)
			attack_hand(user)
		return

	if(stat & NOPOWER)
		user << SPAN_NOTE("\The [src] is unpowered and useless.")
		return

	if(accept_check(O))
		if(contents.len >= max_n_of_items)
			user << SPAN_NOTE("\The [src] is full.")
			return 1
		else
			user.remove_from_mob(O)
			add_item(O)
			user.visible_message(SPAN_NOTE("[user] has added \the [O] to \the [src]."), SPAN_NOTE("You add \the [O] to \the [src]."))

			nanomanager.update_uis(src)

	else if(istype(O, /obj/item/storage/bag))
		var/obj/item/storage/bag/P = O
		var/plants_loaded = 0
		for(var/obj/G in P.contents)
			if(accept_check(G))
				if(contents.len >= max_n_of_items)
					user << SPAN_NOTE("\The [src] is full.")
					return 1
				else
					P.remove_from_storage(G,src)
					if(item_quants[G.name])
						item_quants[G.name]++
					else
						item_quants[G.name] = 1
					plants_loaded++
		if(plants_loaded)

			user.visible_message(SPAN_NOTE("[user] loads \the [src] with \the [P]."), SPAN_NOTE("You load \the [src] with \the [P]."))
			if(P.contents.len > 0)
				user << SPAN_NOTE("Some items are refused.")

		nanomanager.update_uis(src)

	else
		user << SPAN_NOTE("\The [src] smartly refuses [O].")
		return 1

/obj/machinery/smartfridge/secure/emag_act(var/remaining_charges, var/mob/user)
	if(!emagged)
		emagged = 1
		locked = -1
		user << "You short out the product lock on [src]."
		return 1


/obj/machinery/smartfridge/attack_ai(mob/user as mob)
	attack_hand(user)

/obj/machinery/smartfridge/attack_hand(mob/user as mob)
	if(stat & (NOPOWER|BROKEN))
		return
	wires.Interact(user)
	ui_interact(user)

/obj/machinery/smartfridge/proc/add_item(obj/item/I)
	I.loc = src
	if(item_quants[I.name])
		item_quants[I.name]++
	else
		item_quants[I.name] = 1

/*******************
*   SmartFridge Menu
********************/

/obj/machinery/smartfridge/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = 1)
	user.set_machine(src)

	var/data[0]
	data["contents"] = null
	data["electrified"] = seconds_electrified > 0
	data["shoot_inventory"] = shoot_inventory
	data["locked"] = locked
	data["secure"] = is_secure

	var/list/items[0]
	for (var/i=1 to length(item_quants))
		var/K = item_quants[i]
		var/count = item_quants[K]
		if(count > 0)
			items.Add(list(list("display_name" = html_encode(capitalize(K)), "vend" = i, "quantity" = count)))

	if(items.len > 0)
		data["contents"] = items

	ui = nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "smartfridge.tmpl", src.name, 400, 500)
		ui.set_initial_data(data)
		ui.open()

/obj/machinery/smartfridge/Topic(href, href_list)
	if(..()) return 0

	var/mob/user = usr
	var/datum/nanoui/ui = nanomanager.get_open_ui(user, src, "main")

	src.add_fingerprint(user)

	if(href_list["close"])
		user.unset_machine()
		ui.close()
		return 0

	if(href_list["vend"])
		var/index = text2num(href_list["vend"])
		var/amount = text2num(href_list["amount"])
		var/K = item_quants[index]
		var/count = item_quants[K]

		// Sanity check, there are probably ways to press the button when it shouldn't be possible.
		if(count > 0)
			item_quants[K] = max(count - amount, 0)

			var/i = amount
			for(var/obj/O in contents)
				if(O.name == K)
					O.loc = loc
					i--
					if(i <= 0)
						return 1

		return 1
	return 0

/obj/machinery/smartfridge/proc/throw_item()
	var/obj/throw_item = null
	var/mob/living/target = locate() in view(7,src)
	if(!target)
		return 0

	for (var/O in item_quants)
		if(item_quants[O] <= 0) //Try to use a record that actually has something to dump.
			continue

		item_quants[O]--
		for(var/obj/T in contents)
			if(T.name == O)
				T.loc = src.loc
				throw_item = T
				break
		break
	if(!throw_item)
		return 0
	spawn(0)
		throw_item.throw_at(target,16,3,src)
	src.visible_message("<span class='warning'>[src] launches [throw_item.name] at [target.name]!</span>")
	return 1

/************************
*   Secure SmartFridges
*************************/

/obj/machinery/smartfridge/secure/Topic(href, href_list)
	if(stat & (NOPOWER|BROKEN)) return 0
	if(usr.contents.Find(src) || (in_range(src, usr) && istype(loc, /turf)))
		if(!allowed(usr) && !emagged && locked != -1 && href_list["vend"])
			usr << "<span class='warning'>Access denied.</span>"
			return 0
	return ..()

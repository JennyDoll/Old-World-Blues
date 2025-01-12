/*	Photography!
 *	Contains:
 *		Camera
 *		Camera Film
 *		Photos
 *		Photo Albums
 */

/*******
* film *
*******/
/obj/item/device/camera_film
	name = "film cartridge"
	icon = 'icons/obj/items.dmi'
	desc = "A camera film cartridge. Insert it into a camera to reload it."
	icon_state = "film"
	item_state = "electropack"
	w_class = ITEM_SIZE_TINY


/********
* photo *
********/
var/global/photo_count = 0

/obj/item/weapon/photo
	name = "photo"
	icon = 'icons/obj/items.dmi'
	icon_state = "photo"
	item_state = "paper"
	randpixel = 10
	w_class = ITEM_SIZE_TINY
	var/id
	var/icon/img	//Big photo image
	var/scribble	//Scribble on the back.
	var/icon/tiny
	var/photo_size = 3

/obj/item/weapon/photo/New()
	id = photo_count++

/obj/item/weapon/photo/attack_self(mob/user as mob)
	user.examinate(src)

/obj/item/weapon/photo/attackby(obj/item/weapon/P as obj, mob/user as mob)
	if(istype(P, /obj/item/weapon/pen))
		var/txt = sanitize(input(user, "What would you like to write on the back?", "Photo Writing", null, "text"), 128)
		if(!user.stat && Adjacent(user))
			scribble = txt
	..()

/obj/item/weapon/photo/examine(mob/user, return_dist=1)
	.=..()
	if(.<=1)
		show(user)
	else
		user << SPAN_NOTE("It is too far away.")

/obj/item/weapon/photo/attack(mob/living/carbon/M as mob, mob/living/carbon/user as mob)
	if(user.zone_sel.selecting == O_EYES)
		user.visible_message(SPAN_NOTE(" [user] holds up a paper and shows it to [M]. "),\
			SPAN_NOTE("You show the paper to [M]. "))
		M.examinate(src)

/obj/item/weapon/photo/proc/show(mob/user as mob)
	user << browse_rsc(img, "tmp_photo_[id].png")
	user << browse("<html><head><meta charset=\"utf-8\"><title>[name]</title></head>" \
		+ "<body style='overflow:hidden;margin:0;text-align:center'>" \
		+ "<img src='tmp_photo_[id].png' width='[64*photo_size]' style='-ms-interpolation-mode:nearest-neighbor' />" \
		+ "[scribble ? "<br>Written on the back:<br><i>[scribble]</i>" : ""]"\
		+ "</body></html>", "window=book;size=[64*photo_size]x[scribble ? 400 : 64*photo_size]")
	onclose(user, "[name]")
	return

/obj/item/weapon/photo/verb/rename()
	set name = "Rename photo"
	set category = "Object"
	set src in usr

	var/n_name = sanitizeSafe(input(usr, "What would you like to label the photo?", "Photo Labelling", null)  as text, MAX_NAME_LEN)
	//loc.loc check is for making possible renaming photos in clipboards
	if(( (loc == usr || (loc.loc && loc.loc == usr)) && !usr.stat))
		name = "[(n_name ? text("[n_name]") : "photo")]"
	add_fingerprint(usr)
	return


/obj/item/weapon/photo/custom/show(mob/user)
	if(!img)
		img = input("Set image for photo") as icon
		if(!img) return
		var/icon/small_img = icon(img)
		var/icon/ic = icon('icons/obj/items.dmi',"photo")
		small_img.Scale(8, 8)
		ic.Blend(small_img,ICON_OVERLAY, 10, 13)
		icon = ic
		name = input("Set name for phote", "New name", "photo") as text
	else
		return ..()

/**************
* photo album *
**************/
/obj/item/storage/photo_album
	name = "Photo album"
	icon = 'icons/obj/items.dmi'
	icon_state = "album"
	item_state = "briefcase"
	w_class = ITEM_SIZE_NORMAL //same as book
	storage_slots = DEFAULT_BOX_STORAGE //yes, that's storage_slots. Photos are w_class 1 so this has as many slots equal to the number of photos you could put in a box
	can_hold = list(/obj/item/weapon/photo)

/obj/item/storage/photo_album/MouseDrop(obj/over_object as obj)

	if(!ishuman(usr))
		return

	var/mob/living/carbon/human/H = usr
	if(!istype(over_object, /obj/screen))
		return ..()

	playsound(loc, "rustle", 50, 1, -5)
	if(!H.restrained() && !H.stat && H.back == src)
		switch(over_object.name)
			if(BP_R_HAND)
				if(H.unEquip(src))
					H.put_in_r_hand(src)
			if(BP_L_HAND)
				if(H.unEquip(src))
					H.put_in_l_hand(src)
		add_fingerprint(usr)
		return
	if(over_object == H && in_range(src, H) || H.contents.Find(src))
		if(H.s_active)
			H.s_active.close(H)
		show_to(H)
		return
	return

/*********
* camera *
*********/
/obj/item/device/camera
	name = "camera"
	icon = 'icons/obj/items.dmi'
	desc = "A polaroid camera. 10 photos left."
	icon_state = "camera"
	item_state = "electropack"
	w_class = ITEM_SIZE_SMALL
	randpixel = 5
	flags = CONDUCT
	slot_flags = SLOT_BELT
	matter = list(MATERIAL_STEEL = 2000)
	var/pictures_max = 10
	var/pictures_left = 10
	var/on = 1
	var/icon_on = "camera"
	var/icon_off = "camera_off"
	var/size = 3


/obj/item/device/camera/verb/change_size()
	set name = "Set Photo Focus"
	set category = "Object"
	var/nsize = input("Photo Size","Pick a size of resulting photo.") as null|anything in list(1,3)
	if(nsize)
		size = nsize
		usr << SPAN_NOTE("Camera will now take [size]x[size] photos.")


/obj/item/device/camera/attack(mob/living/carbon/human/M as mob, mob/user as mob)
	return

/obj/item/device/camera/attack_self(mob/user as mob)
	on = !on
	if(on)
		src.icon_state = icon_on
	else
		src.icon_state = icon_off
	user << "You switch the camera [on ? "on" : "off"]."
	return

/obj/item/device/camera/attackby(obj/item/I as obj, mob/user as mob)
	if(istype(I, /obj/item/device/camera_film))
		if(pictures_left)
			user << SPAN_NOTE("[src] still has some film in it!")
			return
		user << SPAN_NOTE("You insert [I] into [src].")
		user.drop_from_inventory(I)
		qdel(I)
		pictures_left = pictures_max
		return
	..()


/obj/item/device/camera/proc/get_icon(list/turfs, turf/center)

	//Bigger icon base to capture those icons that were shifted to the next tile
	//i.e. pretty much all wall-mounted machinery
	var/icon/res = icon('icons/effects/96x96.dmi', "")
	res.Scale(size*32, size*32)
	// Initialize the photograph to black.
	res.Blend("#000", ICON_OVERLAY)

	var/atoms[] = list()
	for(var/turf/the_turf in turfs)
		// Add outselves to the list of stuff to draw
		atoms.Add(the_turf);
		// As well as anything that isn't invisible.
		for(var/atom/A in the_turf)
			if(A.invisibility) continue
			atoms.Add(A)

	// Sort the atoms into their layers
	var/list/sorted = sort_atoms_by_layer(atoms)
	var/center_offset = (size-1)/2 * 32 + 1
	var/i = 1
	for(var/item in sorted)
		if(!(++i % 10))
			sleep()
		var/atom/A = item
		var/icon/img = getFlatIcon(A)//build_composite_icon(A)

		// If what we got back is actually a picture, draw it.
		if(istype(img, /icon))
			// Check if we're looking at a mob that's lying down
			if(isliving(A) && A:lying)
				// If they are, apply that effect to their picture.
				img.BecomeLying()
			// Calculate where we are relative to the center of the photo
			var/xoff = (A.x - center.x) * 32 + center_offset
			var/yoff = (A.y - center.y) * 32 + center_offset
			if (istype(A,/atom/movable))
				xoff+=A:step_x
				yoff+=A:step_y
			res.Blend(img, blendMode2iconMode(A.blend_mode),  A.pixel_x + xoff, A.pixel_y + yoff)

	// Lastly, render any contained effects on top.
	for(var/turf/the_turf in turfs)
		// Calculate where we are relative to the center of the photo
		var/xoff = (the_turf.x - center.x) * 32 + center_offset
		var/yoff = (the_turf.y - center.y) * 32 + center_offset
		res.Blend(getFlatIcon(the_turf.loc), blendMode2iconMode(the_turf.blend_mode),xoff,yoff)
	return res


/obj/item/device/camera/proc/get_mobs(turf/the_turf as turf)
	var/mob_detail
	for(var/mob/living/carbon/A in the_turf)
		if(A.invisibility) continue
		var/holding = ""
		var/posenow = null
		var/datum/gender/T = gender_datums[A.get_gender()]
		if(A.r_hand)
			holding = A.r_hand.on_mob_description(A, T, slot_r_hand, "right hand")
		if(A.l_hand)
			holding += " "
			holding += A.l_hand.on_mob_description(A, T, slot_l_hand, "left hand")
		if(ishuman(A) && A.pose)
			posenow = "They're appears to [A.pose] on this photo."

		if(!mob_detail)
			mob_detail = "You can see [A] on the photo[A:health < 75 ? " - [A] looks hurt":""]. [holding][posenow] "
		else
			mob_detail += "You can also see [A] on the photo[A:health < 75 ? " - [A] looks hurt":""].[holding ? " [holding]":"."] [posenow]."
	return mob_detail

/obj/item/device/camera/afterattack(atom/target as mob|obj|turf|area, mob/user as mob, flag)
	if(!on || !pictures_left || ismob(target.loc) || !ismob(loc)) return
	captureimage(target, user, flag)

	playsound(loc, pick('sound/items/polaroid1.ogg', 'sound/items/polaroid2.ogg'), 75, 1, -3)

	pictures_left--
	desc = "A polaroid camera. It has [pictures_left] photos left."
	user << SPAN_NOTE("[pictures_left] photos left.")
	icon_state = icon_off
	on = 0
	spawn(64)
		icon_state = icon_on
		on = 1

/obj/item/device/camera/proc/can_capture_turf(turf/T, mob/user)
	var/mob/dummy = new(T)	//Go go visibility check dummy
	var/viewer = user
	if(user.client)		//To make shooting through security cameras possible
		viewer = user.client.eye
	var/can_see = (dummy in viewers(world.view, viewer))

	qdel(dummy)
	return can_see

/obj/item/device/camera/proc/captureimage(atom/target, mob/user, flag)
	var/x_c = target.x - (size-1)/2
	var/y_c = target.y + (size-1)/2
	var/z_c	= target.z
	var/list/turfs = list()
	var/mobs = ""
	for(var/i = 1; i <= size; i++)
		for(var/j = 1; j <= size; j++)
			var/turf/T = locate(x_c, y_c, z_c)
			if(can_capture_turf(T, user))
				turfs.Add(T)
				mobs += get_mobs(T)
			x_c++
		y_c--
		x_c = x_c - size

	var/obj/item/weapon/photo/p = createpicture(target, user, turfs, mobs, flag)
	printpicture(user, p)

/obj/item/device/camera/proc/createpicture(atom/target, mob/user, list/turfs, mobs, flag)
	var/icon/photoimage = get_icon(turfs, target)

	var/icon/small_img = icon(photoimage)
	var/icon/tiny_img = icon(photoimage)
	var/icon/ic = icon('icons/obj/items.dmi',"photo")
	var/icon/pc = icon('icons/obj/bureaucracy.dmi', "photo")
	small_img.Scale(8, 8)
	tiny_img.Scale(4, 4)
	ic.Blend(small_img,ICON_OVERLAY, 13, 13)
	pc.Blend(tiny_img,ICON_OVERLAY, 12, 19)

	var/obj/item/weapon/photo/p = new()
	p.name = "photo"
	p.icon = ic
	p.tiny = pc
	p.img = photoimage
	p.desc = mobs
	p.photo_size = size

	return p

/obj/item/device/camera/proc/printpicture(mob/user, obj/item/weapon/photo/p)
	user.put_in_hands(p)

/obj/item/weapon/photo/proc/copy(var/copy_id = 0)
	var/obj/item/weapon/photo/p = new/obj/item/weapon/photo()

	p.name = name
	p.icon = icon(icon, icon_state)
	p.tiny = icon(tiny)
	p.img = icon(img)
	p.desc = desc
	p.pixel_x = pixel_x
	p.pixel_y = pixel_y
	p.photo_size = photo_size
	p.scribble = scribble

	if(copy_id)
		p.id = id

	return p

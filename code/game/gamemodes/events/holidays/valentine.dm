/obj/item/valentine
	name = "valentine"
	desc = "A Valentine's card! Wonder what it says..."
	icon = 'icons/obj/toy.dmi'
	icon_state = "valentine"
	var/message = "A generic message of love or whatever."

/obj/item/valentine/New()
	..()
	message = pick("Roses are red / Violets are good / One day while Andy...",
	               "My love for you is like the singularity. It cannot be contained.",
	               "Will you be my lusty xenomorph maid?",
	               "We go together like the clown and the external airlock.",
	               "Roses are red / Liches are wizards / I love you more than a whole squad of lizards.",
	               "Be my valentine. Law 2.",
	               "You must be a mime, because you leave me speechless.",
	               "I love you like Ian loves the HoP.",
	               "You're hotter than a plasma fire in toxins.",
	               "Are you a rogue atmos tech? Because you're taking my breath away.",
	               "Could I have all access... to your heart?",
	               "Call me the doctor, because I'm here to inspect your johnson.",
	               "I'm not a changeling, but you make my proboscis extend.",
	               "I just can't get EI NATH of you.",
	               "You must be a nuke op, because you make my heart explode.",
	               "Roses are red / Botany is a farm / Not being my Valentine / causes human harm.",
	               "I want you more than an assistant wants insulated gloves.",
	               "If I was a security officer, I'd brig you all shift.",
	               "Are you the janitor? Because I think I've fallen for you.",
	               "You're always valid to my heart.",
	               "I'd risk the wrath of the gods to bwoink you.",
	               "You look as beautiful now as the last time you were cloned.",
	               "Someone check the gravitational generator, because I'm only attracted to you.",
	               "If I were the warden I'd always let you into my armory.",
	               "The virologist is rogue, and the only cure is a kiss from you.",
	               "Would you spend some time in my upgraded sleeper?",
	               "You must be a silicon, because you've unbolted my heart.",
	               "Are you Nar-Sie? Because there's nar-one else I sie.",
	               "If you were a taser, you'd be set to stunning.",
	               "Do you have stamina damage from running through my dreams?",
	               "If I were an alien, would you let me hug you?",
	               "My love for you is stronger than a reinforced wall.",
	               "This must be the captain's office, because I see a fox.",
	               "I'm not a highlander, but there can only be one for me.",
	               "The floor is made of lava! Quick, get on my bed.",
	               "If you were an abandoned station you'd be the DEARelict.",
	               "If you had a pickaxe you'd be a shaft FINEr.",
	               "Roses are red, tide is gray, if I were an assistant I'd steal you away.",
	               "Roses are red, text is green, I love you more than cleanbots clean.",
	               "If you were a carp I'd fi-lay you.",
	               "I'm a nuke op, and my pinpointer leads to your heart.",
	               "Wanna slay my megafauna?",
	               "I'm a clockwork cultist. Or zl inyragvar.",
	               "If you were a disposal bin I'd ride you all day.",
	               "Put on your explorer's suit because I'm taking you to LOVEaland.",
	               "I must be the CMO, 'cause I saw you on my CUTE sensors.",
	               "You're the vomit to my flyperson.",
	               "You must be liquid dark matter, because you're pulling me closer.",
	               "Not even sorium can drive me away from you.",
	               "Wanna make like a borg and do some heavy petting?",
	               "Are you powering the station? Because you super matter to me.",
	               "I wish science could make me a bag of holding you.",
	               "Let's call the emergency CUDDLE.",
	               "I must be tripping on BZ, because I saw an angel walk by.",
	               "Wanna empty out my tool storage?",
	               "Did you visit the medbay after you fell from heaven?",
	               "Are you wearing space pants? Wanna not be?" )

/obj/item/valentine/attackby(obj/item/W, mob/user, params)
	..()
	if(istype(W, /obj/item/weapon/pen) || istype(W, /obj/effect/decal/cleanable/crayon))
		var/recipient = input(user, "Who is receiving this valentine?", "To:", null, null)
		var/sender = input(user, "Who is sending this valentine?", "From:", null , null)
		if(recipient && sender)
			name = "valentine - To: [recipient] From: [sender]"

/obj/item/valentine/examine(mob/user)
	if(in_range(user, src) || isobserver(user))
		if( !(ishuman(user) || isobserver(user) || issilicon(user)) )
			user << browse("<HTML><HEAD><TITLE>[name]</TITLE></HEAD><BODY>[stars(message)]</BODY></HTML>", "window=[name]")
			onclose(user, "[name]")
		else
			user << browse("<HTML><HEAD><TITLE>[name]</TITLE></HEAD><BODY>[message]</BODY></HTML>", "window=[name]")
			onclose(user, "[name]")
	else
		to_chat(user, "<span class='notice'>It is too far away.</span>")

/obj/item/valentine/attack_self(mob/user)
	user.examinate(src)
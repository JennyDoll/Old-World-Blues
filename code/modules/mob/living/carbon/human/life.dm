//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:32

//NOTE: Breathing happens once per FOUR TICKS, unless the last breath fails.
// In which case it happens once per ONE TICK! So oxyloss healing is done once per 4 ticks while oxyloss damage is applied once per tick!

//Defines how much oxyloss humans can get per tick. A tile with no air at all (such as space) applies this value, otherwise it's a percentage of it.
#define HUMAN_MAX_OXYLOSS 1
//The amount of damage you'll get when in critical condition. We want this to be a 5 minute deal = 300s.
// There are 50HP to get through, so (1/6)*last_tick_duration per second. Breaths however only happen every 4 ticks. last_tick_duration = ~2.0 on average
#define HUMAN_CRIT_MAX_OXYLOSS ( 2.0 / 6)

#define HEAT_DAMAGE_LEVEL_1 2 //Amount of damage applied when your body temperature just passes the 360.15k safety point
#define HEAT_DAMAGE_LEVEL_2 4 //Amount of damage applied when your body temperature passes the 400K point
#define HEAT_DAMAGE_LEVEL_3 8 //Amount of damage applied when your body temperature passes the 1000K point

#define COLD_DAMAGE_LEVEL_1 0.5 //Amount of damage applied when your body temperature just passes the 260.15k safety point
#define COLD_DAMAGE_LEVEL_2 1.5 //Amount of damage applied when your body temperature passes the 200K point
#define COLD_DAMAGE_LEVEL_3 3 //Amount of damage applied when your body temperature passes the 120K point

//Note that gas heat damage is only applied once every FOUR ticks.
#define HEAT_GAS_DAMAGE_LEVEL_1 2 //Amount of damage applied when the current breath's temperature just passes the 360.15k safety point
#define HEAT_GAS_DAMAGE_LEVEL_2 4 //Amount of damage applied when the current breath's temperature passes the 400K point
#define HEAT_GAS_DAMAGE_LEVEL_3 8 //Amount of damage applied when the current breath's temperature passes the 1000K point

#define COLD_GAS_DAMAGE_LEVEL_1 0.5 //Amount of damage applied when the current breath's temperature just passes the 260.15k safety point
#define COLD_GAS_DAMAGE_LEVEL_2 1.5 //Amount of damage applied when the current breath's temperature passes the 200K point
#define COLD_GAS_DAMAGE_LEVEL_3 3 //Amount of damage applied when the current breath's temperature passes the 120K point

#define RADIATION_SPEED_COEFFICIENT 0.1

/mob/living/carbon/human
	var/oxygen_alert = 0
	var/phoron_alert = 0
	var/co2_alert = 0
	var/fire_alert = 0
	var/pressure_alert = 0
	var/temperature_alert = 0
	var/in_stasis = 0
	var/heartbeat = 0
	var/global/list/overlays_cache = null

/mob/living/carbon/human/Life()
	set invisibility = 0
	set background = BACKGROUND_ENABLED

	if (transforming)
		return

	//Apparently, the person who wrote this code designed it so that
	//blinded get reset each cycle and then get activated later in the
	//code. Very ugly. I dont care. Moving this stuff here so its easy
	//to find it.
	blinded = 0
	fire_alert = 0 //Reset this here, because both breathe() and handle_environment() have a chance to set it.

	//TODO: seperate this out
	// update the current life tick, can be used to e.g. only do something every 4 ticks
	life_tick++

	..()

	if(life_tick%30==15)
		hud_updateflag = 1022

	//No need to update all of these procs if the guy is dead.
	if(stat != DEAD && !in_stasis)
		//Updates the number of stored chemicals for powers
		handle_changeling()

		//Organs and blood
		handle_organs()
		stabilize_body_temperature() //Body temperature adjusts itself (self-regulation)

		handle_shock()

		handle_pain()

		handle_medical_side_effects()

		handle_heartbeat()

		if(!client)
			species.handle_npc(src)


	if(!handle_some_updates())
		return											//We go ahead and process them 5 times for HUD images and other stuff though.

	if(src.lying && src.birth)
		src.overlays += image('icons/mob/alien.dmi', loc = src, icon_state = "bursted_lie")
	else if(!src.lying && src.birth)
		src.overlays += image('icons/mob/alien.dmi', loc = src, icon_state = "bursted_stand")

	//Update our name based on whether our face is obscured/disfigured
	name = get_visible_name()

	pulse = handle_pulse()

/mob/living/carbon/human/proc/handle_some_updates()
	if(life_tick > 5 && timeofdeath && (timeofdeath < 5 || world.time - timeofdeath > 6000))	//We are long dead, or we're junk mobs spawned like the clowns on the clown shuttle
		return 0
	return 1

/mob/living/carbon/human/breathe()
	if(!should_have_organ(O_LUNGS))
		return
	if(!in_stasis)
		..()

// Calculate how vulnerable the human is to under- and overpressure.
// Returns 0 (equals 0 %) if sealed in an undamaged suit, 1 if unprotected (equals 100%).
// Suitdamage can modifiy this in 10% steps.
/mob/living/carbon/human/proc/get_pressure_weakness()

	var/pressure_adjustment_coefficient = 1 // Assume no protection at first.

	if(wear_suit && (wear_suit.item_flags & STOPPRESSUREDAMAGE) && head && (head.item_flags & STOPPRESSUREDAMAGE)) // Complete set of pressure-proof suit worn, assume fully sealed.
		pressure_adjustment_coefficient = 0

		// Handles breaches in your space suit. 10 suit damage equals a 100% loss of pressure protection.
		if(istype(wear_suit,/obj/item/clothing/suit/space))
			var/obj/item/clothing/suit/space/S = wear_suit
			if(S.can_breach && S.damage)
				pressure_adjustment_coefficient += S.damage * 0.1

	pressure_adjustment_coefficient = min(1,max(pressure_adjustment_coefficient,0)) // So it isn't less than 0 or larger than 1.

	return pressure_adjustment_coefficient

// Calculate how much of the enviroment pressure-difference affects the human.
/mob/living/carbon/human/calculate_affecting_pressure(var/pressure)
	var/pressure_difference

	// First get the absolute pressure difference.
	if(pressure < ONE_ATMOSPHERE) // We are in an underpressure.
		pressure_difference = ONE_ATMOSPHERE - pressure

	else //We are in an overpressure or standard atmosphere.
		pressure_difference = pressure - ONE_ATMOSPHERE

	if(pressure_difference < 5) // If the difference is small, don't bother calculating the fraction.
		pressure_difference = 0

	else
		// Otherwise calculate how much of that absolute pressure difference affects us, can be 0 to 1 (equals 0% to 100%).
		// This is our relative difference.
		pressure_difference *= get_pressure_weakness()

	// The difference is always positive to avoid extra calculations.
	// Apply the relative difference on a standard atmosphere to get the final result.
	// The return value will be the adjusted_pressure of the human that is the basis of pressure warnings and damage.
	if(pressure < ONE_ATMOSPHERE)
		return ONE_ATMOSPHERE - pressure_difference
	else
		return ONE_ATMOSPHERE + pressure_difference

/mob/living/carbon/human/handle_disabilities()
	..()

	if(stat != CONSCIOUS) //Let's not worry about tourettes if you're not conscious.
		return

	if (disabilities & EPILEPSY)
		if ((prob(1) && paralysis < 1))
			src << "\red You have a seizure!"
			for(var/mob/O in viewers(src, null))
				if(O == src)
					continue
				O.show_message(text("<span class='danger'>[src] starts having a seizure!</span>"), 1)
			Paralyse(10)
			make_jittery(1000)
	if (disabilities & COUGHING)
		if ((prob(5) && paralysis <= 1))
			drop_active_hand()
			drop_inactive_hand()
			spawn( 0 )
				emote("cough")
				return
	if (disabilities & TOURETTES)
		if ((prob(10) && paralysis <= 1))
			Stun(10)
			spawn( 0 )
				switch(rand(1, 3))
					if(1)
						emote("twitch")
					if(2 to 3)
						say("[prob(50) ? ";" : ""][pick("SHIT", "PISS", "FUCK", "CUNT", "COCKSUCKER", "MOTHERFUCKER", "TITS")]")
				make_jittery(100)
				return
	if (disabilities & NERVOUS)
		if (prob(10))
			stuttering = max(10, stuttering)

	var/rn = rand(0, 200)
	if(getBrainLoss() >= 5)
		if(0 <= rn && rn <= 3)
			custom_pain("Your head feels numb and painful.")
	if(getBrainLoss() >= 15)
		if(4 <= rn && rn <= 6) if(eye_blurry <= 0)
			src << "<span class='warning'>It becomes hard to see for some reason.</span>"
			eye_blurry = 10
	if(getBrainLoss() >= 35)
		if(7 <= rn && rn <= 9) if(get_active_hand())
			src << "<span class='danger'>Your hand won't respond properly, you drop what you're holding!</span>"
			drop_active_hand()
	if(getBrainLoss() >= 45)
		if(10 <= rn && rn <= 12)
			if(prob(50))
				src << "<span class='danger'>You suddenly black out!</span>"
				Paralyse(10)
			else if(!lying)
				src << "<span class='danger'>Your legs won't respond properly, you fall down!</span>"
				Weaken(10)



/mob/living/carbon/human/handle_mutations_and_radiation()
	if(in_stasis)
		return

	// Make nanoregen heal youu, -3 all damage types
	if((NANOREGEN in augmentations))
		var/healed = 0
		var/hptoreg = 0
		if(NANOREGEN in augmentations)
			hptoreg += 3
		if(stat==UNCONSCIOUS)
			if(hptoreg>=2 || prob(50)) hptoreg/=2
		if(stat==DEAD) hptoreg=0

		for(var/i=1, i<=hptoreg, i++)
			var/list/damages = new/list()
			if(getToxLoss())
				damages+="tox"
			if(getOxyLoss())
				damages+="oxy"
			if(getCloneLoss())
				damages+="clone"
			if(getBruteLoss())
				damages+="brute"
			if(getFireLoss())
				damages+="burn"
			if(halloss != 0)
				damages+="hal"

			if(damages.len)
				switch(pick(damages))
					if("tox")
						adjustToxLoss(-1)
						healed = 1
					if("oxy")
						adjustOxyLoss(-1)
						healed = 1
					if("clone")
						adjustCloneLoss(-1)
						healed = 1
					if("brute")
						heal_organ_damage(1,0)
						healed = 1
					if("burn")
						heal_organ_damage(0,1)
						healed = 1
					if("hal")
						if(halloss > 0)
							halloss -= 1
						if(halloss < 0)
							halloss = 0
						healed = 1
			else
				break

		if(healed)
			if(prob(5))
				src << "\blue You feel your wounds mending..."

	if(getFireLoss())
		if(prob(1))
			heal_organ_damage(0,1)

	//TODO: DNA3 on_mob_life()

	radiation = Clamp(radiation,0,100)

	if (radiation)
		var/obj/item/organ/internal/nutrients/rad_organ = locate() in internal_organs
		if(rad_organ && !rad_organ.is_broken())
			var/rads = radiation/25
			radiation -= rads
			nutrition += rads
			adjustBruteLoss(-(rads))
			adjustFireLoss(-(rads))
			adjustOxyLoss(-(rads))
			adjustToxLoss(-(rads))
			updatehealth()
			return

		var/damage = 0
		radiation -= 1 * RADIATION_SPEED_COEFFICIENT
		if(prob(25))
			damage = 1

		if (radiation > 50)
			damage = 1
			radiation -= 1 * RADIATION_SPEED_COEFFICIENT
			if(!isSynthetic())
				if(prob(5) && prob(100 * RADIATION_SPEED_COEFFICIENT))
					radiation -= 5 * RADIATION_SPEED_COEFFICIENT
					src << "<span class='warning'>You feel weak.</span>"
					Weaken(3)
					if(!lying)
						emote("collapse")
				if(prob(5) && prob(100 * RADIATION_SPEED_COEFFICIENT) && species.get_bodytype() == SPECIES_HUMAN) //apes go bald
					if(h_style != species.default_h_style || f_style != species.default_f_style)
						src << "<span class='warning'>Your hair falls out.</span>"
						h_style = species.default_h_style
						f_style = species.default_f_style
						update_hair()

		if (radiation > 75)
			damage = 3
			radiation -= 1 * RADIATION_SPEED_COEFFICIENT
			if(!isSynthetic())
				if(prob(5))
					take_overall_damage(0, 5 * RADIATION_SPEED_COEFFICIENT, used_weapon = "Radiation Burns")
				if(prob(1))
					src << "<span class='warning'>You feel strange!</span>"
					adjustCloneLoss(5 * RADIATION_SPEED_COEFFICIENT)
					emote("gasp")

		if(damage)
			damage *= isSynthetic() ? 0.5 : species.radiation_mod
			adjustToxLoss(damage * RADIATION_SPEED_COEFFICIENT)
			updatehealth()
			if(!isSynthetic() && organs.len)
				var/obj/item/organ/external/O = pick(organs)
				if(istype(O)) O.add_autopsy_data("Radiation Poisoning", damage)

	/** breathing **/

/mob/living/carbon/human/handle_chemical_smoke(var/datum/gas_mixture/environment)
	if(wear_mask && (wear_mask.item_flags & BLOCK_GAS_SMOKE_EFFECT))
		return
	if(glasses && (glasses.item_flags & BLOCK_GAS_SMOKE_EFFECT))
		return
	if(head && (head.item_flags & BLOCK_GAS_SMOKE_EFFECT))
		return
	..()

/mob/living/carbon/human/handle_post_breath(datum/gas_mixture/breath)
	..()
	//spread some viruses while we are at it
	if(breath && virus2.len > 0 && prob(10))
		for(var/mob/living/carbon/M in view(1,src))
			src.spread_disease_to(M)


/mob/living/carbon/human/get_breath_from_internal(volume_needed=BREATH_VOLUME)
	if(internal)

		var/obj/item/weapon/tank/rig_supply
		if(istype(back,/obj/item/weapon/rig))
			var/obj/item/weapon/rig/rig = back
			if(!rig.offline && (rig.air_supply && internal == rig.air_supply))
				rig_supply = rig.air_supply

		if (!rig_supply && (!contents.Find(internal) || !((wear_mask && (wear_mask.item_flags & AIRTIGHT)) || (head && (head.item_flags & AIRTIGHT)))))
			internal = null

		if(internal)
			return internal.remove_air_volume(volume_needed)
		else if(internals)
			internals.icon_state = "internal0"
	return null

/mob/living/carbon/human/get_breath_from_environment(var/volume_needed=BREATH_VOLUME)
	var/datum/gas_mixture/breath = ..()

	if(breath)
		//exposure to extreme pressures can rupture lungs
		var/check_pressure = breath.return_pressure()
		if(check_pressure < ONE_ATMOSPHERE / 5 || check_pressure > ONE_ATMOSPHERE * 5)
			if(!is_lung_ruptured() && prob(5))
				rupture_lung()

	return breath

/mob/living/carbon/human/handle_breath(datum/gas_mixture/breath)
	if(status_flags & GODMODE || (REBREATHER in augmentations) )
		return

	if(!breath || (breath.total_moles == 0) || suiciding)
		failed_last_breath = 1
		if(suiciding)
			adjustOxyLoss(2)//If you are suiciding, you should die a little bit faster
			oxygen_alert = max(oxygen_alert, 1)
			return 0
		if(health > config.health_threshold_crit)
			adjustOxyLoss(HUMAN_MAX_OXYLOSS)
		else
			adjustOxyLoss(HUMAN_CRIT_MAX_OXYLOSS)

		oxygen_alert = max(oxygen_alert, 1)

		return 0

	var/safe_pressure_min = species.breath_pressure // Minimum safe partial pressure of breathable gas in kPa

	// Lung damage increases the minimum safe pressure.
	if(should_have_organ(O_LUNGS))
		var/obj/item/organ/internal/lungs/L = internal_organs_by_name[O_LUNGS]
		if(isnull(L))
			safe_pressure_min = INFINITY //No lungs, how are you breathing?
		else if(L.is_broken())
			safe_pressure_min *= 1.5
		else if(L.is_bruised())
			safe_pressure_min *= 1.25

	var/safe_exhaled_max = 10
	var/safe_toxins_max = 0.2
	var/SA_para_min = 1
	var/SA_sleep_min = 5
	var/inhaled_gas_used = 0

	var/breath_pressure = (breath.total_moles*R_IDEAL_GAS_EQUATION*breath.temperature)/BREATH_VOLUME

	var/inhaling
	var/poison
	var/exhaling

	var/breath_type
	var/poison_type
	var/exhale_type

	var/failed_inhale = 0
	var/failed_exhale = 0

	if(species.breath_type)
		breath_type = species.breath_type
	else
		breath_type = "oxygen"
	inhaling = breath.gas[breath_type]

	if(species.poison_type)
		poison_type = species.poison_type
	else
		poison_type = "phoron"
	poison = breath.gas[poison_type]

	if(species.exhale_type)
		exhale_type = species.exhale_type
		exhaling = breath.gas[exhale_type]
	else
		exhaling = 0

	var/inhale_pp = (inhaling/breath.total_moles)*breath_pressure
	var/toxins_pp = (poison/breath.total_moles)*breath_pressure
	var/exhaled_pp = (exhaling/breath.total_moles)*breath_pressure

	// Not enough to breathe
	if(inhale_pp < safe_pressure_min)
		if(prob(20))
			spawn(0) emote("gasp")

		var/ratio = inhale_pp/safe_pressure_min
		// Don't fuck them up too fast (space only does HUMAN_MAX_OXYLOSS after all!)
		adjustOxyLoss(max(HUMAN_MAX_OXYLOSS*(1-ratio), 0))
		failed_inhale = 1

		oxygen_alert = max(oxygen_alert, 1)
	else
		// We're in safe limits
		oxygen_alert = 0

	inhaled_gas_used = inhaling/6

	breath.adjust_gas(breath_type, -inhaled_gas_used, update = 0) //update afterwards

	if(exhale_type)
		breath.adjust_gas_temp(exhale_type, inhaled_gas_used, bodytemperature, update = 0) //update afterwards

		// Too much exhaled gas in the air
		if(exhaled_pp > safe_exhaled_max)
			if (!co2_alert|| prob(15))
				var/word = pick("extremely dizzy","short of breath","faint","confused")
				src << "<span class='danger'>You feel [word].</span>"

			adjustOxyLoss(HUMAN_MAX_OXYLOSS)
			co2_alert = 1
			failed_exhale = 1

		else if(exhaled_pp > safe_exhaled_max * 0.7)
			if (!co2_alert || prob(1))
				var/word = pick("dizzy","short of breath","faint","momentarily confused")
				src << "<span class='warning'>You feel [word].</span>"

			//scale linearly from 0 to 1 between safe_exhaled_max and safe_exhaled_max*0.7
			var/ratio = 1.0 - (safe_exhaled_max - exhaled_pp)/(safe_exhaled_max*0.3)

			//give them some oxyloss, up to the limit - we don't want people falling unconcious due to CO2 alone until they're pretty close to safe_exhaled_max.
			if (getOxyLoss() < 50*ratio)
				adjustOxyLoss(HUMAN_MAX_OXYLOSS)
			co2_alert = 1
			failed_exhale = 1

		else if(exhaled_pp > safe_exhaled_max * 0.6)
			if (prob(0.3))
				var/word = pick("a little dizzy","short of breath")
				src << "<span class='warning'>You feel [word].</span>"

		else
			co2_alert = 0

	// Too much poison in the air.
	if(toxins_pp > safe_toxins_max)
		var/ratio = (poison/safe_toxins_max) * 10
		if(reagents)
			reagents.add_reagent("toxin", Clamp(ratio, MIN_TOXIN_DAMAGE, MAX_TOXIN_DAMAGE))
			breath.adjust_gas(poison_type, -poison/6, update = 0) //update after
		phoron_alert = max(phoron_alert, 1)
	else
		phoron_alert = 0

	// If there's some other shit in the air lets deal with it here.
	if(breath.gas["sleeping_agent"])
		var/SA_pp = (breath.gas["sleeping_agent"] / breath.total_moles) * breath_pressure

		// Enough to make us paralysed for a bit
		if(SA_pp > SA_para_min)

			// 3 gives them one second to wake up and run away a bit!
			Paralyse(3)

			// Enough to make us sleep as well
			if(SA_pp > SA_sleep_min)
				Sleeping(5)

		// There is sleeping gas in their lungs, but only a little, so give them a bit of a warning
		else if(SA_pp > 0.15)
			if(prob(20))
				spawn(0) emote(pick("giggle", "laugh"))
		breath.adjust_gas("sleeping_agent", -breath.gas["sleeping_agent"]/6, update = 0) //update after

	// Were we able to breathe?
	if (failed_inhale || failed_exhale)
		failed_last_breath = 1
	else
		failed_last_breath = 0
		adjustOxyLoss(-5)


	// Hot air hurts :(
	if(breath.temperature < species.cold_level_1 || breath.temperature > species.heat_level_1)

		if(breath.temperature <= species.cold_level_1)
			if(prob(20))
				src << "<span class='danger'>You feel your face freezing and icicles forming in your lungs!</span>"
		else if(breath.temperature >= species.heat_level_1)
			if(prob(20))
				src << "<span class='danger'>You feel your face burning and a searing heat in your lungs!</span>"

		if(breath.temperature >= species.heat_level_1)
			if(breath.temperature < species.heat_level_2)
				apply_damage(HEAT_GAS_DAMAGE_LEVEL_1, BURN, BP_HEAD, used_weapon = "Excessive Heat")
				fire_alert = max(fire_alert, 2)
			else if(breath.temperature < species.heat_level_3)
				apply_damage(HEAT_GAS_DAMAGE_LEVEL_2, BURN, BP_HEAD, used_weapon = "Excessive Heat")
				fire_alert = max(fire_alert, 2)
			else
				apply_damage(HEAT_GAS_DAMAGE_LEVEL_3, BURN, BP_HEAD, used_weapon = "Excessive Heat")
				fire_alert = max(fire_alert, 2)

		else if(breath.temperature <= species.cold_level_1)
			if(breath.temperature > species.cold_level_2)
				apply_damage(COLD_GAS_DAMAGE_LEVEL_1, BURN, BP_HEAD, used_weapon = "Excessive Cold")
				fire_alert = max(fire_alert, 1)
			else if(breath.temperature > species.cold_level_3)
				apply_damage(COLD_GAS_DAMAGE_LEVEL_2, BURN, BP_HEAD, used_weapon = "Excessive Cold")
				fire_alert = max(fire_alert, 1)
			else
				apply_damage(COLD_GAS_DAMAGE_LEVEL_3, BURN, BP_HEAD, used_weapon = "Excessive Cold")
				fire_alert = max(fire_alert, 1)


		//breathing in hot/cold air also heats/cools you a bit
		var/temp_adj = breath.temperature - bodytemperature
		if (temp_adj < 0)
			temp_adj /= (BODYTEMP_COLD_DIVISOR * 5)	//don't raise temperature as much as if we were directly exposed
		else
			temp_adj /= (BODYTEMP_HEAT_DIVISOR * 5)	//don't raise temperature as much as if we were directly exposed

		var/relative_density = breath.total_moles / (MOLES_CELLSTANDARD * BREATH_PERCENTAGE)
		temp_adj *= relative_density

		if (temp_adj > BODYTEMP_HEATING_MAX) temp_adj = BODYTEMP_HEATING_MAX
		if (temp_adj < BODYTEMP_COOLING_MAX) temp_adj = BODYTEMP_COOLING_MAX
		//world << "Breath: [breath.temperature], [src]: [bodytemperature], Adjusting: [temp_adj]"
		bodytemperature += temp_adj

	else if(breath.temperature >= species.heat_discomfort_level)
		species.get_environment_discomfort(src,"heat")
	else if(breath.temperature <= species.cold_discomfort_level)
		species.get_environment_discomfort(src,"cold")

	breath.update_values()
	return 1

/mob/living/carbon/human/proc/get_high_body_temperature_damage(var/temperature)
	if (temperature > species.heat_level_3)
		return HEAT_DAMAGE_LEVEL_3
	else if (temperature > species.heat_level_2)
		return HEAT_DAMAGE_LEVEL_2
	else if (temperature > species.heat_level_1)
		return HEAT_DAMAGE_LEVEL_1
	else
		return 0

/mob/living/carbon/human/proc/get_low_body_temperature_damage(var/temperature)
	if (temperature < species.cold_level_3)
		return COLD_DAMAGE_LEVEL_3
	else if (temperature < species.cold_level_2)
		return COLD_DAMAGE_LEVEL_2
	else if (temperature < species.cold_level_1)
		return COLD_DAMAGE_LEVEL_1
	else
		return 0

/mob/living/carbon/human/handle_environment(datum/gas_mixture/environment)
	if(!environment)
		return

	//Stuff like the xenomorph's plasma regen happens here.
	species.handle_environment_special(src)

	//Moved pressure calculations here for use in skip-processing check.
	var/pressure = environment.return_pressure()
	var/adjusted_pressure = calculate_affecting_pressure(pressure)

	//Check for contaminants before anything else because we don't want to skip it.
	for(var/g in environment.gas)
		if(gas_data.flags[g] & XGM_GAS_CONTAMINANT && environment.gas[g] > gas_data.overlay_limit[g] + 1)
			pl_effects()
			break

	if(istype(get_turf(src), /turf/space))
		//Don't bother if the temperature drop is less than 0.1 anyways. Hopefully BYOND is smart enough to turn this constant expression into a constant
		if(bodytemperature > (0.1 * HUMAN_HEAT_CAPACITY/(HUMAN_EXPOSED_SURFACE_AREA*STEFAN_BOLTZMANN_CONSTANT))**(1/4) + COSMIC_RADIATION_TEMPERATURE)
			//Thermal radiation into space
			var/heat_loss = HUMAN_EXPOSED_SURFACE_AREA * STEFAN_BOLTZMANN_CONSTANT * ((bodytemperature - COSMIC_RADIATION_TEMPERATURE)**4)
			var/temperature_loss = heat_loss/HUMAN_HEAT_CAPACITY
			bodytemperature -= temperature_loss
	else
		var/loc_temp = T0C
		if(istype(loc, /obj/mecha))
			var/obj/mecha/M = loc
			loc_temp =  M.return_temperature()
		else if(istype(loc, /obj/machinery/atmospherics/unary/cryo_cell))
			loc_temp = loc:air_contents.temperature
		else
			loc_temp = environment.temperature

		if(adjusted_pressure < species.warning_high_pressure && adjusted_pressure > species.warning_low_pressure &&\
				abs(loc_temp - bodytemperature) < 20 && bodytemperature < species.heat_level_1 && bodytemperature > species.cold_level_1)
			pressure_alert = 0
			return // Temperatures are within normal ranges, fuck all this processing. ~Ccomp

		//Body temperature adjusts depending on surrounding atmosphere based on your thermal protection (convection)
		var/temp_adj = 0
		if(loc_temp < bodytemperature)			//Place is colder than we are
			var/thermal_protection = get_cold_protection(loc_temp) //This returns a 0 - 1 value, which corresponds to the percentage of protection based on what you're wearing and what you're exposed to.
			if(thermal_protection < 1)
				temp_adj = (1-thermal_protection) * ((loc_temp - bodytemperature) / BODYTEMP_COLD_DIVISOR)	//this will be negative
		else if (loc_temp > bodytemperature)			//Place is hotter than we are
			var/thermal_protection = get_heat_protection(loc_temp) //This returns a 0 - 1 value, which corresponds to the percentage of protection based on what you're wearing and what you're exposed to.
			if(thermal_protection < 1)
				temp_adj = (1-thermal_protection) * ((loc_temp - bodytemperature) / BODYTEMP_HEAT_DIVISOR)

		//Use heat transfer as proportional to the gas density. However, we only care about the relative density vs standard 101 kPa/20 C air. Therefore we can use mole ratios
		var/relative_density = environment.total_moles / MOLES_CELLSTANDARD
		bodytemperature += between(BODYTEMP_COOLING_MAX, temp_adj*relative_density, BODYTEMP_HEATING_MAX)

	// +/- 50 degrees from 310.15K is the 'safe' zone, where no damage is dealt.
	if(bodytemperature >= species.heat_level_1)
		//Body temperature is too hot.
		fire_alert = max(fire_alert, 1)
		if(status_flags & GODMODE)	return 1	//godmode
		var/burn_dam = get_high_body_temperature_damage(bodytemperature)
		/*
		switch(bodytemperature)
			if(species.heat_level_1 to species.heat_level_2)
				burn_dam = HEAT_DAMAGE_LEVEL_1
			if(species.heat_level_2 to species.heat_level_3)
				burn_dam = HEAT_DAMAGE_LEVEL_2
			if(species.heat_level_3 to INFINITY)
				burn_dam = HEAT_DAMAGE_LEVEL_3
		*/
		take_overall_damage(burn=burn_dam, used_weapon = "High Body Temperature")
		//fire_alert = max(fire_alert, 2)

	else if(bodytemperature <= species.cold_level_1)
		fire_alert = max(fire_alert, 1)
		if(status_flags & GODMODE)	return 1	//godmode

		if(!istype(loc, /obj/machinery/atmospherics/unary/cryo_cell))
			var/burn_dam = get_low_body_temperature_damage(bodytemperature)
			/* switch(bodytemperature)
				if(species.cold_level_1 to species.cold_level_2)
					burn_dam = COLD_DAMAGE_LEVEL_1
				if(species.cold_level_2 to species.cold_level_3)
					burn_dam = COLD_DAMAGE_LEVEL_2
				if(species.cold_level_3 to -INFINITY)
					burn_dam = COLD_DAMAGE_LEVEL_3 */
			take_overall_damage(burn=burn_dam, used_weapon = "Low Body Temperature")
			//fire_alert = max(fire_alert, 1)

	// Account for massive pressure differences.  Done by Polymorph
	// Made it possible to actually have something that can protect against high pressure... Done by Errorage. Polymorph now has an axe sticking from his head for his previous hardcoded nonsense!
	if(status_flags & GODMODE)	return 1	//godmode

	if(adjusted_pressure >= species.hazard_high_pressure)
		var/pressure_damage = min( ( (adjusted_pressure / species.hazard_high_pressure) -1 )*PRESSURE_DAMAGE_COEFFICIENT , MAX_HIGH_PRESSURE_DAMAGE)
		take_overall_damage(brute=pressure_damage, used_weapon = "High Pressure")
		pressure_alert = 2
	else if(adjusted_pressure >= species.warning_high_pressure)
		pressure_alert = 1
	else if(adjusted_pressure >= species.warning_low_pressure)
		pressure_alert = 0
	else if(adjusted_pressure >= species.hazard_low_pressure)
		pressure_alert = -1
	else
		take_overall_damage(brute=LOW_PRESSURE_DAMAGE, used_weapon = "Low Pressure")
		if(getOxyLoss() < 55) // 11 OxyLoss per 4 ticks when wearing internals;    unconsciousness in 16 ticks, roughly half a minute
			adjustOxyLoss(4)  // 16 OxyLoss per 4 ticks when no internals present; unconsciousness in 13 ticks, roughly twenty seconds
		pressure_alert = -2

	return

/*
/mob/living/carbon/human/proc/adjust_body_temperature(current, loc_temp, boost)
	var/temperature = current
	var/difference = abs(current-loc_temp)	//get difference
	var/increments// = difference/10			//find how many increments apart they are
	if(difference > 50)
		increments = difference/5
	else
		increments = difference/10
	var/change = increments*boost	// Get the amount to change by (x per increment)
	var/temp_change
	if(current < loc_temp)
		temperature = min(loc_temp, temperature+change)
	else if(current > loc_temp)
		temperature = max(loc_temp, temperature-change)
	temp_change = (temperature - current)
	return temp_change
*/

/mob/living/carbon/human/proc/stabilize_body_temperature()
	// We produce heat naturally.
	if (species.passive_temp_gain)
		bodytemperature += species.passive_temp_gain
	if (species.body_temperature == null)
		return //this species doesn't have metabolic thermoregulation


	var/body_temperature_difference = species.body_temperature - bodytemperature

	if (abs(body_temperature_difference) < 0.5)
		return //fuck this precision

	if (on_fire)
		return //too busy for pesky metabolic regulation

	if(bodytemperature < species.cold_level_1) //260.15 is 310.15 - 50, the temperature where you start to feel effects.
		if(nutrition >= 2) //If we are very, very cold we'll use up quite a bit of nutriment to heat us up.
			nutrition -= 2
		var/recovery_amt = max((body_temperature_difference / BODYTEMP_AUTORECOVERY_DIVISOR), BODYTEMP_AUTORECOVERY_MINIMUM)
		//world << "Cold. Difference = [body_temperature_difference]. Recovering [recovery_amt]"
//				log_debug("Cold. Difference = [body_temperature_difference]. Recovering [recovery_amt]")
		bodytemperature += recovery_amt
	else if(species.cold_level_1 <= bodytemperature && bodytemperature <= species.heat_level_1)
		var/recovery_amt = body_temperature_difference / BODYTEMP_AUTORECOVERY_DIVISOR
		//world << "Norm. Difference = [body_temperature_difference]. Recovering [recovery_amt]"
//				log_debug("Norm. Difference = [body_temperature_difference]. Recovering [recovery_amt]")
		bodytemperature += recovery_amt
	else if(bodytemperature > species.heat_level_1) //360.15 is 310.15 + 50, the temperature where you start to feel effects.
		//We totally need a sweat system cause it totally makes sense...~
		var/recovery_amt = min((body_temperature_difference / BODYTEMP_AUTORECOVERY_DIVISOR), -BODYTEMP_AUTORECOVERY_MINIMUM)	//We're dealing with negative numbers
		//world << "Hot. Difference = [body_temperature_difference]. Recovering [recovery_amt]"
//				log_debug("Hot. Difference = [body_temperature_difference]. Recovering [recovery_amt]")
		bodytemperature += recovery_amt

//This proc returns a number made up of the flags for body parts which you are protected on. (such as HEAD, UPPER_TORSO, LOWER_TORSO, etc. See setup.dm for the full list)
/mob/living/carbon/human/proc/get_heat_protection_flags(temperature) //Temperature is the temperature you're being exposed to.
	. = 0
	//Handle normal clothing
	for(var/obj/item/clothing/C in list(head,wear_suit,w_uniform,shoes,gloves,wear_mask))
		if(C)
			if(C.max_heat_protection_temperature && C.max_heat_protection_temperature >= temperature)
				. |= C.heat_protection

//See proc/get_heat_protection_flags(temperature) for the description of this proc.
/mob/living/carbon/human/proc/get_cold_protection_flags(temperature)
	. = 0
	//Handle normal clothing
	for(var/obj/item/clothing/C in list(head,wear_suit,w_uniform,shoes,gloves,wear_mask))
		if(C)
			if(C.min_cold_protection_temperature && C.min_cold_protection_temperature <= temperature)
				. |= C.cold_protection

/mob/living/carbon/human/get_heat_protection(temperature) //Temperature is the temperature you're being exposed to.
	var/thermal_protection_flags = get_heat_protection_flags(temperature)
	return get_thermal_protection(thermal_protection_flags)

/mob/living/carbon/human/get_cold_protection(temperature)
	//There is an occasional bug where the temperature is miscalculated in ares with a small amount of gas on them,
	// so this is necessary to ensure that that bug does not affect this calculation.
	// Space's temperature is 2.7K and most suits that are intended to protect against any cold, protect down to 2.0K.
	temperature = max(temperature, 2.7)
	var/thermal_protection_flags = get_cold_protection_flags(temperature)
	return get_thermal_protection(thermal_protection_flags)

/mob/living/carbon/human/proc/get_thermal_protection(var/flags)
	.=0
	if(flags)
		if(flags & HEAD)
			. += THERMAL_PROTECTION_HEAD
		if(flags & UPPER_TORSO)
			. += THERMAL_PROTECTION_UPPER_TORSO
		if(flags & LOWER_TORSO)
			. += THERMAL_PROTECTION_LOWER_TORSO
		if(flags & LEG_LEFT)
			. += THERMAL_PROTECTION_LEG_LEFT
		if(flags & LEG_RIGHT)
			. += THERMAL_PROTECTION_LEG_RIGHT
		if(flags & FOOT_LEFT)
			. += THERMAL_PROTECTION_FOOT_LEFT
		if(flags & FOOT_RIGHT)
			. += THERMAL_PROTECTION_FOOT_RIGHT
		if(flags & ARM_LEFT)
			. += THERMAL_PROTECTION_ARM_LEFT
		if(flags & ARM_RIGHT)
			. += THERMAL_PROTECTION_ARM_RIGHT
		if(flags & HAND_LEFT)
			. += THERMAL_PROTECTION_HAND_LEFT
		if(flags & HAND_RIGHT)
			. += THERMAL_PROTECTION_HAND_RIGHT
	return min(1,.)

/mob/living/carbon/human/handle_chemicals_in_body()

	if(in_stasis)
		return

	if(reagents)
		chem_effects.Cut()
		analgesic = 0

		if(!isSynthetic())

			if(touching) touching.metabolize()
			if(ingested) ingested.metabolize()
			if(bloodstr) bloodstr.metabolize()

			if(CE_PAINKILLER in chem_effects)
				analgesic = chem_effects[CE_PAINKILLER]

			var/total_phoronloss = 0
			for(var/obj/item/I in src)
				if(I.contaminated)
					total_phoronloss += vsc.plc.CONTAMINATION_LOSS
			if(!(status_flags & GODMODE)) adjustToxLoss(total_phoronloss)

	if(status_flags & GODMODE)	return 0	//godmode

	var/obj/item/organ/internal/node/light_organ = locate() in internal_organs

	if(!isSynthetic())
		if(light_organ && !light_organ.is_broken())
			var/light_amount = 0 //how much light there is in the place, affects receiving nutrition and healing
			if(isturf(loc)) //else, there's considered to be no light
				var/turf/T = loc
				var/atom/movable/lighting_overlay/L = locate(/atom/movable/lighting_overlay) in T
				if(L)
					light_amount = min(10,L.lum_r + L.lum_g + L.lum_b) - 2 //hardcapped so it's not abused by having a ton of flashlights
				else
					light_amount =  10
			nutrition += light_amount
			traumatic_shock -= light_amount

			if(species.flags & IS_PLANT)
				if(nutrition > 450)
					nutrition = 450

				if(light_amount >= 3) //if there's enough light, heal
					adjustBruteLoss(-(round(light_amount/2)))
					adjustFireLoss(-(round(light_amount/2)))
					adjustToxLoss(-(light_amount))
					adjustOxyLoss(-(light_amount))
					//TODO: heal wounds, heal broken limbs.

	// nutrition decrease
	if (nutrition > 0 && stat != DEAD)
		nutrition = max (0, nutrition - species.hunger_factor)

	if (nutrition > 450)
		if(overeatduration < 600) //capped so people don't take forever to unfat
			overeatduration++
	else
		if(overeatduration > 1)
			overeatduration -= 2 //doubled the unfat rate

	if(!isSynthetic() && (species.flags & IS_PLANT) && (!light_organ || light_organ.is_broken()))
		if(nutrition < 200)
			take_overall_damage(2,0)

			//traumatic_shock is updated every tick, incrementing that is pointless - shock_stage is the counter.
			//Not that it matters much for diona, who have NO_PAIN.
			shock_stage++

	// TODO: stomach and bloodstream organ.
	if(!isSynthetic())
		handle_trace_chems()

	updatehealth()

	return //TODO: DEFERRED

//DO NOT CALL handle_statuses() from this proc, it's called from living/Life() as long as this returns a true value.
/mob/living/carbon/human/handle_regular_status_updates()
	if(!handle_some_updates())
		return 0

	if(status_flags & GODMODE)	return 0

	//SSD check, if a logged player is awake put them back to sleep!
	if(get_ssd() && !client && !teleop)
		Sleeping(2)
	if(stat == DEAD)	//DEAD. BROWN BREAD. SWIMMING WITH THE SPESS CARP
		blinded = 1
		silent = 0
	else				//ALIVE. LIGHTS ARE ON
		updatehealth()	//TODO

		if(health <= config.health_threshold_dead || (should_have_organ(O_BRAIN) && !has_brain()))
			death()
			blinded = 1
			silent = 0
			return 1

		//UNCONSCIOUS. NO-ONE IS HOME
		if((getOxyLoss() > (species.total_health/2)) || (health <= config.health_threshold_crit))
			Paralyse(3)

		if(hallucination)
			if(hallucination >= 20)
				if(prob(3))
					fake_attack(src)
				if(!handling_hal)
					spawn handle_hallucinations() //The not boring kind!
				if(client && prob(5))
					client.dir = pick(2,4,8)
					spawn(rand(20,50))
						client.dir = 1

			hallucination = max(0, hallucination - 2)
		else
			for(var/atom/a in hallucinations)
				qdel(a)

		if(halloss >= species.total_health)
			src << SPAN_NOTE("You're in too much pain to keep going...")
			src.visible_message("<B>[src]</B> slumps to the ground, too weak to continue fighting.")
			Paralyse(10)
			setHalLoss(species.total_health - 1)

		if(paralysis || sleeping)
			blinded = 1
			stat = UNCONSCIOUS
			animate_tail_reset()
			adjustHalLoss(-3)

			if(sleeping)
				handle_dreams()
				if (mind)
					//Are they SSD? If so we'll keep them asleep but work off some of that sleep var in case of stoxin or similar.
					if(client || sleeping > 3)
						AdjustSleeping(-1)
				if( prob(2) && health && !hal_crit )
					spawn(0)
						emote("snore")
		//CONSCIOUS
		else
			stat = CONSCIOUS

		//Periodically double-check embedded_flag
		if(embedded_flag && !(life_tick % 10))
			var/list/E
			E = get_visible_implants(0)
			if(!E.len)
				embedded_flag = 0

		//Eyes
		//Check rig first because it's two-check and other checks will override it.
		if(istype(back,/obj/item/weapon/rig))
			var/obj/item/weapon/rig/O = back
			if(O.helmet && O.helmet == head && (O.helmet.body_parts_covered & EYES))
				if((O.offline && O.offline_vision_restriction == 2) || (!O.offline && O.vision_restriction == 2))
					blinded = 1

		// Check everything else.

		//Periodically double-check embedded_flag
		if(embedded_flag && !(life_tick % 10))
			if(!embedded_needs_process())
				embedded_flag = 0
		//Vision
		var/obj/item/organ/vision
		if(species.vision_organ)
			vision = internal_organs_by_name[species.vision_organ]

		if(!species.vision_organ) // Presumably if a species has no vision organs, they see via some other means.
			eye_blind =  0
			blinded =    0
			eye_blurry = 0
		else if(!vision || vision.is_broken())   // Vision organs cut out or broken? Permablind.
			eye_blind =  1
			blinded =    1
			eye_blurry = 1
		else //You have the requisite organs
			if(sdisabilities & BLIND) 	// Disabled-blind, doesn't get better on its own
				blinded =    1
			else if(eye_blind)		  	// Blindness, heals slowly over time
				eye_blind =  max(eye_blind-1,0)
				blinded =    1
			else if(istype(glasses, /obj/item/clothing/glasses/sunglasses/blindfold))	//resting your eyes with a blindfold heals blurry eyes faster
				eye_blurry = max(eye_blurry-3, 0)
				blinded =    1

			//blurry sight
			if(vision.is_bruised())   // Vision organs impaired? Permablurry.
				eye_blurry = 1
			if(eye_blurry)	           // Blurry eyes heal slowly
				eye_blurry = max(eye_blurry-1, 0)

		//Ears
		if(sdisabilities & DEAF)	//disabled-deaf, doesn't get better on its own
			ear_deaf = max(ear_deaf, 1)
		else if(ear_deaf)			//deafness, heals slowly over time
			ear_deaf = max(ear_deaf-1, 0)
		else if(get_ear_protection() >= 2)	//resting your ears with earmuffs heals ear damage faster
			ear_damage = max(ear_damage-0.15, 0)
			ear_deaf = max(ear_deaf, 1)
		else if(ear_damage < 25)	//ear damage heals slowly under this threshold. otherwise you'll need earmuffs
			ear_damage = max(ear_damage-0.05, 0)

		//Resting
		if(resting)
			dizziness = max(0, dizziness - 15)
			jitteriness = max(0, jitteriness - 15)
			adjustHalLoss(-3)
		else
			dizziness = max(0, dizziness - 3)
			jitteriness = max(0, jitteriness - 3)
			adjustHalLoss(-1)

		if (drowsyness)
			drowsyness--
			eye_blurry = max(2, eye_blurry)
			if (prob(5))
				sleeping += 1
				Paralyse(5)

		confused = max(0, confused - 1)

		// If you're dirty, your gloves will become dirty, too.
		if(gloves && germ_level > gloves.germ_level && prob(10))
			gloves.germ_level += 1

	return 1

/mob/living/carbon/human/handle_regular_hud_updates()
	if(!overlays_cache)
		overlays_cache = list()
		overlays_cache.len = 23
		overlays_cache[1] = image('icons/mob/screen1_full.dmi', "icon_state" = "passage1")
		overlays_cache[2] = image('icons/mob/screen1_full.dmi', "icon_state" = "passage2")
		overlays_cache[3] = image('icons/mob/screen1_full.dmi', "icon_state" = "passage3")
		overlays_cache[4] = image('icons/mob/screen1_full.dmi', "icon_state" = "passage4")
		overlays_cache[5] = image('icons/mob/screen1_full.dmi', "icon_state" = "passage5")
		overlays_cache[6] = image('icons/mob/screen1_full.dmi', "icon_state" = "passage6")
		overlays_cache[7] = image('icons/mob/screen1_full.dmi', "icon_state" = "passage7")
		overlays_cache[8] = image('icons/mob/screen1_full.dmi', "icon_state" = "passage8")
		overlays_cache[9] = image('icons/mob/screen1_full.dmi', "icon_state" = "passage9")
		overlays_cache[10] = image('icons/mob/screen1_full.dmi', "icon_state" = "passage10")
		overlays_cache[11] = image('icons/mob/screen1_full.dmi', "icon_state" = "oxydamageoverlay1")
		overlays_cache[12] = image('icons/mob/screen1_full.dmi', "icon_state" = "oxydamageoverlay2")
		overlays_cache[13] = image('icons/mob/screen1_full.dmi', "icon_state" = "oxydamageoverlay3")
		overlays_cache[14] = image('icons/mob/screen1_full.dmi', "icon_state" = "oxydamageoverlay4")
		overlays_cache[15] = image('icons/mob/screen1_full.dmi', "icon_state" = "oxydamageoverlay5")
		overlays_cache[16] = image('icons/mob/screen1_full.dmi', "icon_state" = "oxydamageoverlay6")
		overlays_cache[17] = image('icons/mob/screen1_full.dmi', "icon_state" = "oxydamageoverlay7")
		overlays_cache[18] = image('icons/mob/screen1_full.dmi', "icon_state" = "brutedamageoverlay1")
		overlays_cache[19] = image('icons/mob/screen1_full.dmi', "icon_state" = "brutedamageoverlay2")
		overlays_cache[20] = image('icons/mob/screen1_full.dmi', "icon_state" = "brutedamageoverlay3")
		overlays_cache[21] = image('icons/mob/screen1_full.dmi', "icon_state" = "brutedamageoverlay4")
		overlays_cache[22] = image('icons/mob/screen1_full.dmi', "icon_state" = "brutedamageoverlay5")
		overlays_cache[23] = image('icons/mob/screen1_full.dmi', "icon_state" = "brutedamageoverlay6")

	if(hud_updateflag) // update our mob's hud overlays, AKA what others see flaoting above our head
		handle_hud_list()

	// now handle what we see on our screen

	if(!client)
		return 0

	for(var/image/hud in client.images)
		if(copytext(hud.icon_state,1,4) == "hud") //ugly, but icon comparison is worse, I believe
			client.images.Remove(hud)

	client.screen.Remove(global_hud.blurry, global_hud.druggy, global_hud.vimpaired, global_hud.darkMask, global_hud.nvg, global_hud.thermal, global_hud.meson, global_hud.science, global_hud.horny)

	update_action_buttons()

	if(damageoverlay.overlays)
		damageoverlay.overlays = list()

	if(stat == UNCONSCIOUS)
		//Critical damage passage overlay
		if(health <= 0)
			var/image/I
			switch(health)
				if(-20 to -10)
					I = overlays_cache[1]
				if(-30 to -20)
					I = overlays_cache[2]
				if(-40 to -30)
					I = overlays_cache[3]
				if(-50 to -40)
					I = overlays_cache[4]
				if(-60 to -50)
					I = overlays_cache[5]
				if(-70 to -60)
					I = overlays_cache[6]
				if(-80 to -70)
					I = overlays_cache[7]
				if(-90 to -80)
					I = overlays_cache[8]
				if(-95 to -90)
					I = overlays_cache[9]
				if(-INFINITY to -95)
					I = overlays_cache[10]
			damageoverlay.overlays += I
	else
		//Oxygen damage overlay
		if(oxyloss)
			var/image/I
			switch(oxyloss)
				if(10 to 20)
					I = overlays_cache[11]
				if(20 to 25)
					I = overlays_cache[12]
				if(25 to 30)
					I = overlays_cache[13]
				if(30 to 35)
					I = overlays_cache[14]
				if(35 to 40)
					I = overlays_cache[15]
				if(40 to 45)
					I = overlays_cache[16]
				if(45 to INFINITY)
					I = overlays_cache[17]
			damageoverlay.overlays += I

		//Fire and Brute damage overlay (BSSR)
		var/hurtdamage = src.getBruteLoss() + src.getFireLoss() + damageoverlaytemp
		damageoverlaytemp = 0 // We do this so we can detect if someone hits us or not.
		if(hurtdamage)
			var/image/I
			switch(hurtdamage)
				if(10 to 25)
					I = overlays_cache[18]
				if(25 to 40)
					I = overlays_cache[19]
				if(40 to 55)
					I = overlays_cache[20]
				if(55 to 70)
					I = overlays_cache[21]
				if(70 to 85)
					I = overlays_cache[22]
				if(85 to INFINITY)
					I = overlays_cache[23]
			damageoverlay.overlays += I

	if( stat == DEAD )
		sight |= SEE_TURFS|SEE_MOBS|SEE_OBJS|SEE_SELF
		see_in_dark = 8
		if(!druggy)		see_invisible = SEE_INVISIBLE_LEVEL_TWO
		if(healths)
			var/list/health_images = list()
			for(var/obj/item/organ/external/E in organs)
				health_images += E.get_damage_hud_image("dead")
			health_images += image('icons/mob/screen1_health.dmi',"dead")

			healths.icon_state = "blank"
			healths.overlays.Cut()
			healths.overlays += health_images

		if(client)
			if(client.view != world.view) // If mob dies while zoomed in with device, unzoom them.
				for(var/obj/item/item in contents)
					if(item.zoom)
						item.zoom()
						break

	else
		sight = species.vision_flags
		see_in_dark = species.darksight
		see_invisible = see_in_dark>2 ? SEE_INVISIBLE_LEVEL_ONE : SEE_INVISIBLE_LIVING

		if(seer)
			var/obj/effect/rune/R = locate() in loc
			if(R && R.word1 == cultwords["see"] && R.word2 == cultwords["hell"] && R.word3 == cultwords["join"])
				see_invisible = SEE_INVISIBLE_CULT
			else
				seer = 0

		if(!seer)
			see_invisible = SEE_INVISIBLE_LIVING

		var/equipped_glasses = glasses
		var/obj/item/weapon/rig/rig = back
		if(istype(rig) && rig.visor)
			if(!rig.helmet || (head && rig.helmet == head))
				if(rig.visor && rig.visor.vision && rig.visor.active && rig.visor.vision.glasses)
					equipped_glasses = rig.visor.vision.glasses
		if(equipped_glasses)
			process_glasses(equipped_glasses)

		if(healths)
			// Generate a by-limb health display.
			healths.icon_state = "blank"
			healths.overlays.Cut()

			var/list/health_images = list()
			var/forced_state = null
			if (analgesic > 100)
				for(var/obj/item/organ/external/E in organs)
					health_images += E.get_damage_hud_image("numb")
					health_images += image('icons/mob/screen1_health.dmi',"numb")
			else
				var/no_damage = 1
				var/trauma_val = 0 // Used in calculating softcrit/hardcrit indicators.
				if(!(species.flags & NO_PAIN))
					trauma_val = max(traumatic_shock,halloss)/species.total_health
				forced_state = trauma_val*0.3

				// Collect and apply the images all at once to avoid appearance churn.
				for(var/obj/item/organ/external/E in organs)
					if(no_damage && (E.brute_dam || E.burn_dam))
						no_damage = 0
					health_images += E.get_damage_hud_image(forced_state)

				// Apply a fire overlay if we're burning.
				if(on_fire)
					health_images += image('icons/mob/screen1_health.dmi',"burning")

				// Show a general pain/crit indicator if needed.
				if(trauma_val)
					if(!(species.flags & NO_PAIN))
						if(trauma_val > 0.7)
							health_images += image('icons/mob/screen1_health.dmi',"softcrit")
						if(trauma_val >= 1)
							health_images += image('icons/mob/screen1_health.dmi',"hardcrit")
				else if(no_damage)
					health_images += image('icons/mob/screen1_health.dmi',"fullhealth")

			healths.overlays += health_images

		if(nutrition_icon)
			switch(nutrition)
				if(450 to INFINITY)				nutrition_icon.icon_state = "nutrition0"
				if(350 to 450)					nutrition_icon.icon_state = "nutrition1"
				if(250 to 350)					nutrition_icon.icon_state = "nutrition2"
				if(150 to 250)					nutrition_icon.icon_state = "nutrition3"
				else							nutrition_icon.icon_state = "nutrition4"

		if(pressure)
			pressure.icon_state = "pressure[pressure_alert]"

//			if(rest)	//Not used with new UI
//				if(resting || lying || sleeping)		rest.icon_state = "rest1"
//				else									rest.icon_state = "rest0"
		if(toxin)
			if(hal_screwyhud == 4 || phoron_alert)	toxin.icon_state = "tox1"
			else									toxin.icon_state = "tox0"
		if(oxygen)
			if(hal_screwyhud == 3 || oxygen_alert)	oxygen.icon_state = "oxy1"
			else									oxygen.icon_state = "oxy0"
		if(fire)
			if(fire_alert)							fire.icon_state = "fire[fire_alert]" //fire_alert is either 0 if no alert, 1 for cold and 2 for heat.
			else									fire.icon_state = "fire0"

		if(bodytemp)
			if (!species)
				switch(bodytemperature) //310.055 optimal body temp
					if(370 to INFINITY)		bodytemp.icon_state = "temp4"
					if(350 to 370)			bodytemp.icon_state = "temp3"
					if(335 to 350)			bodytemp.icon_state = "temp2"
					if(320 to 335)			bodytemp.icon_state = "temp1"
					if(300 to 320)			bodytemp.icon_state = "temp0"
					if(295 to 300)			bodytemp.icon_state = "temp-1"
					if(280 to 295)			bodytemp.icon_state = "temp-2"
					if(260 to 280)			bodytemp.icon_state = "temp-3"
					else					bodytemp.icon_state = "temp-4"
			else
				var/temp_step
				if (bodytemperature >= species.body_temperature)
					temp_step = (species.heat_level_1 - species.body_temperature)/4

					if (bodytemperature >= species.heat_level_1)
						bodytemp.icon_state = "temp4"
					else if (bodytemperature >= species.body_temperature + temp_step*3)
						bodytemp.icon_state = "temp3"
					else if (bodytemperature >= species.body_temperature + temp_step*2)
						bodytemp.icon_state = "temp2"
					else if (bodytemperature >= species.body_temperature + temp_step*1)
						bodytemp.icon_state = "temp1"
					else
						bodytemp.icon_state = "temp0"

				else if (bodytemperature < species.body_temperature)
					temp_step = (species.body_temperature - species.cold_level_1)/4

					if (bodytemperature <= species.cold_level_1)
						bodytemp.icon_state = "temp-4"
					else if (bodytemperature <= species.body_temperature - temp_step*3)
						bodytemp.icon_state = "temp-3"
					else if (bodytemperature <= species.body_temperature - temp_step*2)
						bodytemp.icon_state = "temp-2"
					else if (bodytemperature <= species.body_temperature - temp_step*1)
						bodytemp.icon_state = "temp-1"
					else
						bodytemp.icon_state = "temp0"
		if(blind)
			if(blinded)		blind.alpha = 255
			else			blind.alpha = 0

		if(disabilities & NEARSIGHTED)	//this looks meh but saves a lot of memory by not requiring to add var/prescription
			if(glasses)					//to every /obj/item
				var/obj/item/clothing/glasses/G = glasses
				if(!G.prescription)
					client.screen += global_hud.vimpaired
			else
				client.screen += global_hud.vimpaired

		if(eye_blurry)			client.screen += global_hud.blurry
		if(druggy)				client.screen += global_hud.druggy
		if(horny)				client.screen += global_hud.horny //for aphrodisiac

		if(config.welder_vision)
			var/found_welder
			if(istype(glasses, /obj/item/clothing/glasses/welding) && !istype(glasses, /obj/item/clothing/glasses/welding/superior))
				var/obj/item/clothing/glasses/welding/O = glasses
				if(!O.up)
					found_welder = 1
			if(!found_welder && istype(head, /obj/item/clothing/head/welding))
				var/obj/item/clothing/head/welding/O = head
				if(!O.up)
					found_welder = 1
			if(!found_welder && istype(back, /obj/item/weapon/rig))
				var/obj/item/weapon/rig/O = back
				if(O.helmet && O.helmet == head && (O.helmet.body_parts_covered & EYES))
					if((O.offline && O.offline_vision_restriction == 1) || (!O.offline && O.vision_restriction == 1))
						found_welder = 1
			if(found_welder)
				client.screen |= global_hud.darkMask

		if(machine)
			var/viewflags = machine.check_eye(src)
			if(viewflags < 0)
				reset_view(null, 0)
			else if(viewflags)
				sight = viewflags //when viewing from a machine, use only the sight flags that the machine provides
		else if(eyeobj)
			if(eyeobj.owner != src)

				reset_view(null)
			else
				src.sight |= SEE_TURFS|SEE_MOBS|SEE_OBJS
		else
			var/isRemoteObserve = 0
			//TODO: DNA3 remote_view
			if(remoteview_target)
				if(remoteview_target.stat==CONSCIOUS)
					isRemoteObserve = 1
			if(!isRemoteObserve && client && !client.adminobs)
				remoteview_target = null
				reset_view(null, 0)
	return 1

/mob/living/carbon/human/proc/process_glasses(var/obj/item/clothing/glasses/G)
	if(istype(G) && G.active)
		see_in_dark += G.darkness_view
		if(G.overlay)
			client.screen |= G.overlay
		if(G.vision_flags)
			sight |= G.vision_flags
			if(!druggy && !seer)
				see_invisible = SEE_INVISIBLE_MINIMUM
		if(G.see_invisible >= 0)
			see_invisible = G.see_invisible
/* HUD shit goes here, as long as it doesn't modify sight flags */
// The purpose of this is to stop xray and w/e from preventing you from using huds -- Love, Doohl
		var/obj/item/clothing/glasses/hud/O = G
		if(istype(G, /obj/item/clothing/glasses/sunglasses/sechud))
			var/obj/item/clothing/glasses/sunglasses/sechud/S = G
			O = S.hud
		if(istype(O))
			O.process_hud(src)
			if(!druggy && !seer)	see_invisible = SEE_INVISIBLE_LIVING

/mob/living/carbon/human/handle_random_events()
	if(in_stasis)
		return

	// Puke if toxloss is too high
	if(!stat)
		if (getToxLoss() >= 45)
			spawn vomit()

	//0.1% chance of playing a scary sound to someone who's in complete darkness
	if(isturf(loc) && rand(1,1000) == 1)
		var/turf/T = loc
		var/atom/movable/lighting_overlay/L = locate(/atom/movable/lighting_overlay) in T
		if(L && L.lum_r + L.lum_g + L.lum_b == 0)
			playsound_local(src,pick(scarySounds),50, 1, -1)

/mob/living/carbon/human/handle_stomach()
	spawn(0)
		for(var/mob/living/M in stomach_contents)
			if(M.loc != src)
				stomach_contents.Remove(M)
				continue
			if(isliving(M) && stat != DEAD)
				if(M.stat == DEAD)
					M.death(1)
					stomach_contents.Remove(M)
					qdel(M)
					continue
				if(air_master.current_cycle%3==1)
					if(!(M.status_flags & GODMODE))
						M.adjustBruteLoss(5)
					nutrition += 10

/mob/living/carbon/human/proc/handle_changeling()
	if(mind && mind.changeling)
		mind.changeling.regenerate()

/mob/living/carbon/human/handle_shock()
	..()
	if(status_flags & GODMODE)	return 0	//godmode
	if(species && species.flags & NO_PAIN) return

	if(health < config.health_threshold_softcrit)// health 0 makes you immediately collapse
		shock_stage = max(shock_stage, 61)

	if(traumatic_shock >= 80)
		shock_stage += 1
	else if(health < config.health_threshold_softcrit)
		shock_stage = max(shock_stage, 61)
	else
		shock_stage = min(shock_stage, 160)
		shock_stage = max(shock_stage-1, 0)
		return

	if(shock_stage == 10)
		src << "<span class='danger'>[pick("It hurts so much", "You really need some painkillers", "Dear god, the pain")]!</span>"

	if(shock_stage >= 30)
		if(shock_stage == 30) custom_emote(1,"is having trouble keeping their eyes open.")
		eye_blurry = max(2, eye_blurry)
		stuttering = max(stuttering, 5)

	if(shock_stage == 40)
		src << "<span class='danger'>[pick("The pain is excruciating", "Please, just end the pain", "Your whole body is going numb")]!</span>"

	if (shock_stage >= 60)
		if(shock_stage == 60) custom_emote(1,"'s body becomes limp.")
		if (prob(2))
			src << "<span class='danger'>[pick("The pain is excruciating", "Please, just end the pain", "Your whole body is going numb")]!</span>"
			Weaken(20)

	if(shock_stage >= 80)
		if (prob(5))
			src << "<span class='danger'>[pick("The pain is excruciating", "Please, just end the pain", "Your whole body is going numb")]!</span>"
			Weaken(20)

	if(shock_stage >= 120)
		if (prob(2))
			src << "<span class='danger'>[pick("You black out", "You feel like you could die any moment now", "You're about to lose consciousness")]!</span>"
			Paralyse(5)

	if(shock_stage == 150)
		custom_emote(1,"can no longer stand, collapsing!")
		Weaken(20)

	if(shock_stage >= 150)
		Weaken(20)

/mob/living/carbon/human/proc/handle_pulse()
	if(life_tick % 5) return pulse	//update pulse every 5 life ticks (~1 tick/sec, depending on server load)

	if(!internal_organs_by_name[O_HEART])
		return PULSE_NONE //No blood, no pulse.

	if(stat == DEAD)
		return PULSE_NONE	//that's it, you're dead, nothing can influence your pulse

	var/temp = PULSE_NORM

	if(round(vessel.get_reagent_amount("blood")) <= BLOOD_VOLUME_BAD)	//how much blood do we have
		temp = PULSE_THREADY	//not enough :(

	if(status_flags & FAKEDEATH)
		temp = PULSE_NONE		//pretend that we're dead. unlike actual death, can be inflienced by meds

	//handles different chems' influence on pulse
	for(var/datum/reagent/R in reagents.reagent_list)
		if(R.id in bradycardics)
			if(temp <= PULSE_THREADY && temp >= PULSE_NORM)
				temp--
		if(R.id in tachycardics)
			if(temp <= PULSE_FAST && temp >= PULSE_NONE)
				temp++
		if(R.id in heartstopper) //To avoid using fakedeath
			temp = PULSE_NONE
		if(R.id in cheartstopper) //Conditional heart-stoppage
			if(R.volume >= R.overdose)
				temp = PULSE_NONE

	return temp

/mob/living/carbon/human/proc/handle_heartbeat()
	if(pulse == PULSE_NONE)
		return

	var/obj/item/organ/internal/heart/H = internal_organs_by_name[O_HEART]

	if(!H || H.robotic >=2 )
		return

	if(pulse >= PULSE_2FAST || shock_stage >= 10 || istype(get_turf(src), /turf/space))
		//PULSE_THREADY - maximum value for pulse, currently it 5.
		//High pulse value corresponds to a fast rate of heartbeat.
		//Divided by 2, otherwise it is too slow.
		var/rate = (PULSE_THREADY - pulse)/2

		if(heartbeat >= rate)
			heartbeat = 0
			src << sound('sound/effects/singlebeat.ogg',0,0,0,50)
		else
			heartbeat++

/*
	Called by life(), instead of having the individual hud items update icons each tick and check for status changes
	we only set those statuses and icons upon changes.  Then those HUD items will simply add those pre-made images.
	This proc below is only called when those HUD elements need to change as determined by the mobs hud_updateflag.
*/


/mob/living/carbon/human/proc/handle_hud_list()
	if (BITTEST(hud_updateflag, HEALTH_HUD))
		var/image/holder = hud_list[HEALTH_HUD]
		if(stat == DEAD)
			holder.icon_state = "hudhealth-100" 	// X_X
		else
			var/percentage_health = RoundHealth((health-config.health_threshold_crit)/(maxHealth-config.health_threshold_crit)*100)
			holder.icon_state = "hud[percentage_health]"
		hud_list[HEALTH_HUD] = holder

	if (BITTEST(hud_updateflag, LIFE_HUD))
		var/image/holder = hud_list[STATUS_HUD]
		if(stat == DEAD)
			holder.icon_state = "huddead"
		else
			holder.icon_state = "hudhealthy"

	if (BITTEST(hud_updateflag, STATUS_HUD))
		var/foundVirus = 0
		for (var/ID in virus2)
			if (ID in virusDB)
				foundVirus = 1
				break

		var/image/holder = hud_list[STATUS_HUD]
		var/image/holder2 = hud_list[STATUS_HUD_OOC]
		if(stat == DEAD)
			holder.icon_state = "huddead"
			holder2.icon_state = "huddead"
		else if(foundVirus)
			holder.icon_state = "hudill"
		else if(has_brain_worms())
			var/mob/living/simple_animal/borer/B = has_brain_worms()
			if(B.controlling)
				holder.icon_state = "hudbrainworm"
			else
				holder.icon_state = "hudhealthy"
			holder2.icon_state = "hudbrainworm"
		else
			holder.icon_state = "hudhealthy"
			if(virus2.len)
				holder2.icon_state = "hudill"
			else
				holder2.icon_state = "hudhealthy"

		hud_list[STATUS_HUD] = holder
		hud_list[STATUS_HUD_OOC] = holder2

	if (BITTEST(hud_updateflag, ID_HUD))
		var/image/holder = hud_list[ID_HUD]
		if(wear_id)
			var/obj/item/weapon/card/id/I = wear_id.GetID()
			if(I)
				holder.icon_state = "hud[ckey(I.GetJobName())]"
			else
				holder.icon_state = "hudunknown"
		else
			holder.icon_state = "hudunknown"


		hud_list[ID_HUD] = holder

	if (BITTEST(hud_updateflag, WANTED_HUD))
		var/image/holder = hud_list[WANTED_HUD]
		holder.icon_state = "hudblank"
		var/perpname = name
		if(wear_id)
			var/obj/item/weapon/card/id/I = wear_id.GetID()
			if(I)
				perpname = I.registered_name

		for(var/datum/data/record/E in data_core.general)
			if(E.fields["name"] == perpname)
				for (var/datum/data/record/R in data_core.security)
					if((R.fields["id"] == E.fields["id"]) && (R.fields["criminal"] == "*Arrest*"))
						holder.icon_state = "hudwanted"
						break
					else if((R.fields["id"] == E.fields["id"]) && (R.fields["criminal"] == "Incarcerated"))
						holder.icon_state = "hudprisoner"
						break
					else if((R.fields["id"] == E.fields["id"]) && (R.fields["criminal"] == "Parolled"))
						holder.icon_state = "hudparolled"
						break
					else if((R.fields["id"] == E.fields["id"]) && (R.fields["criminal"] == "Released"))
						holder.icon_state = "hudreleased"
						break
		hud_list[WANTED_HUD] = holder

	if (  BITTEST(hud_updateflag, IMPLOYAL_HUD) \
	   || BITTEST(hud_updateflag,  IMPCHEM_HUD) \
	   || BITTEST(hud_updateflag, IMPTRACK_HUD))

		var/image/holder1 = hud_list[IMPTRACK_HUD]
		var/image/holder2 = hud_list[IMPLOYAL_HUD]
		var/image/holder3 = hud_list[IMPCHEM_HUD]

		holder1.icon_state = "hudblank"
		holder2.icon_state = "hudblank"
		holder3.icon_state = "hudblank"

		for(var/obj/item/weapon/implant/I in src)
			if(I.implanted)
				if(istype(I,/obj/item/weapon/implant/tracking))
					holder1.icon_state = "hud_imp_tracking"
				if(istype(I,/obj/item/weapon/implant/loyalty))
					holder2.icon_state = "hud_imp_loyal"
				if(istype(I,/obj/item/weapon/implant/chem))
					holder3.icon_state = "hud_imp_chem"

		hud_list[IMPTRACK_HUD] = holder1
		hud_list[IMPLOYAL_HUD] = holder2
		hud_list[IMPCHEM_HUD]  = holder3

	if (BITTEST(hud_updateflag, SPECIALROLE_HUD))
		var/image/holder = hud_list[SPECIALROLE_HUD]
		holder.icon_state = "hudblank"
		if(mind && mind.special_role)
			if(hud_icon_reference[mind.special_role])
				holder.icon_state = hud_icon_reference[mind.special_role]
			else
				holder.icon_state = "hudsyndicate"
			hud_list[SPECIALROLE_HUD] = holder
	hud_updateflag = 0

/mob/living/carbon/human/handle_stunned()
	if(species.flags & NO_PAIN)
		stunned = 0
		return 0
	return ..()

/mob/living/carbon/human/handle_fire()
	if(..())
		return

	var/burn_temperature = fire_burn_temperature()
	var/thermal_protection = get_heat_protection(burn_temperature)

	if (thermal_protection < 1 && bodytemperature < burn_temperature)
		bodytemperature += round(BODYTEMP_HEATING_MAX*(1-thermal_protection), 1)

/mob/living/carbon/human/rejuvenate()
	restore_blood()
	..()

#undef HUMAN_MAX_OXYLOSS
#undef HUMAN_CRIT_MAX_OXYLOSS

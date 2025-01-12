var/global/datum/controller/gameticker/ticker
var/list/donator_icons

/datum/controller/gameticker
	var/const/restart_timeout = 600
	var/current_state = GAME_STATE_PREGAME

	var/hide_mode = 0
	var/datum/game_mode/mode = null
	var/post_game = 0
	var/event_time = null
	var/event = 0

	var/login_music			// music played in pregame lobby

	var/list/datum/mind/minds = list()//The people in the game. Used for objective tracking.

	var/Bible_icon_state	// icon_state the chaplain has chosen for his bible
	var/Bible_item_state	// item_state the chaplain has chosen for his bible
	var/Bible_name			// name of the bible
	var/Bible_deity_name

	var/random_players = 0 	// if set to nonzero, ALL players who latejoin or declare-ready join will have random appearances/genders

	var/list/syndicate_coalition = list() // list of traitor-compatible factions
	var/list/factions = list()			  // list of all factions
	var/list/availablefactions = list()	  // list of factions with openings

	var/pregame_timeleft = 0

	var/delay_end = 0	//if set to nonzero, the round will not restart on it's own

	var/triai = 0//Global holder for Triumvirate

	var/round_end_announced = 0 // Spam Prevention. Announce round end only once.

	var/queue_delay = 0
	var/list/queued_players = list()		//used for join queues when the server exceeds the hard population cap


/datum/controller/gameticker/proc/pregame()
	login_music = pick(
		/*'sound/music/halloween/skeletons.ogg',
		'sound/music/halloween/halloween.ogg',
		'sound/music/halloween/ghosts.ogg',*/
		'sound/music/space.ogg',
		'sound/music/traitor.ogg',
		'sound/music/title1.ogg',
		'sound/music/title2.ogg',
		'sound/music/clouds.s3m',
		'sound/music/david_bowie-space_oddity_original.ogg',
		'sound/music/faunts-das_malefitz.ogg',
		'sound/music/First_rendez-vous.ogg',
		'sound/music/undertale.ogg',
		'sound/music/space_oddity.ogg',
		'sound/music/Welcome_to_Lunar_Industries.ogg',
		'sound/music/Mind_Heist.ogg',
		'sound/music/CCR_-_Bad_Moon_Rising_196.ogg',
		'sound/music/Crokett_39_s_theme.ogg',
		'sound/music/music_ambient_scene6.ogg',
		'sound/music/music_battle_scene2.ogg',
		'sound/music/DARKWOOD_Main.ogg',
		'sound/music/moonbaseoddity.ogg',
		'sound/music/deus_ex_unatco.ogg',
		'sound/music/robotniks_theme.ogg')/*
		'sound/music/new_year/we_wish_you_a_merry_christmas.ogg',
		'sound/music/new_year/vypem_za_lyubov.ogg',
		'sound/music/new_year/novyy_god.ogg',
		'sound/music/new_year/let_it_snow.ogg',
		'sound/music/new_year/jingle_bells.ogg',
		'sound/music/new_year/happy_new_year.ogg',
		'sound/music/new_year/a_holly_jolly_christmas.ogg' )*/

	donator_icons = icon_states('icons/donator.dmi')

	do
		pregame_timeleft = 180
		world << "<B><FONT color='blue'>Welcome to the pre-game lobby!</FONT></B>"
		world << "Please, setup your character and select ready. Game will start in [pregame_timeleft] seconds"
		while(current_state == GAME_STATE_PREGAME)
			for(var/i=0, i<10, i++)
				sleep(1)
				vote.process()
			if(going)
				pregame_timeleft--
			if(pregame_timeleft == config.vote_autogamemode_timeleft)
				if(!vote.time_remaining)
					vote.autogamemode()	//Quit calling this over and over and over and over.
					while(vote.time_remaining)
						for(var/i=0, i<10, i++)
							sleep(1)
							vote.process()
			if(pregame_timeleft <= 0)
				current_state = GAME_STATE_SETTING_UP
	while (!setup())


/datum/controller/gameticker/proc/setup()
	//Create and announce mode
	if(master_mode=="secret")
		src.hide_mode = 1

	var/list/runnable_modes = config.get_runnable_modes()
	if((master_mode=="random") || (master_mode=="secret"))
		if(!runnable_modes.len)
			current_state = GAME_STATE_PREGAME
			world << "<B>Unable to choose playable game mode.</B> Reverting to pre-game lobby."
			return 0
		if(secret_force_mode != "secret")
			src.mode = config.pick_mode(secret_force_mode)
		if(!src.mode)
			var/list/weighted_modes = list()
			for(var/datum/game_mode/GM in runnable_modes)
				weighted_modes[GM.config_tag] = config.probabilities[GM.config_tag]
			src.mode = gamemode_cache[pickweight(weighted_modes)]
	else
		src.mode = config.pick_mode(master_mode)

	if(!src.mode)
		current_state = GAME_STATE_PREGAME
		world << "<span class='danger'>Serious error in mode setup!</span> Reverting to pre-game lobby."
		return 0

	job_master.ResetOccupations()
	src.mode.create_antagonists()
	src.mode.pre_setup()
	job_master.DivideOccupations() // Apparently important for new antagonist system to register specific job antags properly.

	if(!src.mode.can_start())
		world << "<B>Unable to start [mode.name].</B> Not enough players, [mode.required_players] players needed. Reverting to pre-game lobby."
		current_state = GAME_STATE_PREGAME
		mode.fail_setup()
		mode = null
		job_master.ResetOccupations()
		return 0

	if(hide_mode)
		world << "<B>The current game mode is - Secret!</B>"
		if(runnable_modes.len)
			var/list/tmpmodes = new
			for (var/datum/game_mode/M in runnable_modes)
				tmpmodes+=M.name
			tmpmodes = sortList(tmpmodes)
			if(tmpmodes.len)
				world << "<B>Possibilities:</B> [english_list(tmpmodes)]"
	else
		src.mode.announce()

	setup_economy()
	current_state = GAME_STATE_PLAYING
	create_characters() //Create player characters and transfer them
	collect_minds()
	equip_characters()
	data_core.manifest()

	callHook("roundstart")

	shuttle_controller.setup_shuttle_docks()

	spawn(0)//Forking here so we dont have to wait for this to finish
		mode.post_setup()
		//Cleanup some stuff
		for(var/obj/effect/landmark/start/S in landmarks_list)
			//Deleting Startpoints but we need the ai point to AI-ize people later
			if (S.name != "AI")
				qdel(S)
		world << "<FONT color='blue'><B>Enjoy the game!</B></FONT>"
		world << sound('sound/AI/welcome.ogg') // Skie
		//Holiday Round-start stuff	~Carn
		Holiday_Game_Start()

	processScheduler.start()

	for(var/obj/multiz/ladder/L in world) L.connect() //Lazy hackfix for ladders. TODO: move this to an actual controller. ~ Z

	return 1

/datum/controller/gameticker/proc/run_callback_list(list/callbacklist)
	set waitfor = FALSE

	if (!callbacklist)
		return

	for (var/thing in callbacklist)
		var/datum/callback/callback = thing
		callback.Invoke()

		//CHECK_TICK

/datum/controller/gameticker
	//station_explosion used to be a variable for every mob's hud. Which was a waste!
	//Now we have a general cinematic centrally held within the gameticker....far more efficient!
	var/obj/screen/cinematic = null

	//Plus it provides an easy way to make cinematics for other events. Just use this as a template :)
	proc/station_explosion_cinematic(var/station_missed=0, var/override = null)
		if( cinematic )	return	//already a cinematic in progress!

		//initialise our cinematic screen object
		cinematic = new(src)
		cinematic.icon = 'icons/effects/station_explosion.dmi'
		cinematic.icon_state = "station_intact"
		cinematic.layer = 20
		cinematic.mouse_opacity = 0
		cinematic.screen_loc = "1,0"

		var/obj/structure/material/bed/temp_buckle = new(src)
		//Incredibly hackish. It creates a bed within the gameticker (lol) to stop mobs running around
		if(station_missed)
			for(var/mob/living/M in living_mob_list)
				M.buckled = temp_buckle				//buckles the mob so it can't do anything
				if(M.client)
					M.client.screen += cinematic	//show every client the cinematic
		else	//nuke kills everyone on z-level 1 to prevent "hurr-durr I survived"
			for(var/mob/living/M in living_mob_list)
				M.buckled = temp_buckle
				if(M.client)
					M.client.screen += cinematic

				if(isOnStationLevel(M)) //we don't use M.death(0) because it calls a for(/mob) loop and
					M.health = 0
					M.stat = DEAD

		//Now animate the cinematic
		switch(station_missed)
			if(1)	//nuke was nearby but (mostly) missed
				if( mode && !override )
					override = mode.name
				switch( override )
					if("mercenary") //Nuke wasn't on station when it blew up
						flick("intro_nuke",cinematic)
						sleep(35)
						world << sound('sound/effects/explosionfar.ogg')
						flick("station_intact_fade_red",cinematic)
						cinematic.icon_state = "summary_nukefail"
					else
						flick("intro_nuke",cinematic)
						sleep(35)
						world << sound('sound/effects/explosionfar.ogg')
						//flick("end",cinematic)


			if(2)	//nuke was nowhere nearby	//TODO: a really distant explosion animation
				sleep(50)
				world << sound('sound/effects/explosionfar.ogg')


			else	//station was destroyed
				if( mode && !override )
					override = mode.name
				switch( override )
					if("mercenary") //Nuke Ops successfully bombed the station
						flick("intro_nuke",cinematic)
						sleep(35)
						flick("station_explode_fade_red",cinematic)
						world << sound('sound/effects/explosionfar.ogg')
						cinematic.icon_state = "summary_nukewin"
					if("AI malfunction") //Malf (screen,explosion,summary)
						flick("intro_malf",cinematic)
						sleep(76)
						flick("station_explode_fade_red",cinematic)
						world << sound('sound/effects/explosionfar.ogg')
						cinematic.icon_state = "summary_malf"
					if("blob") //Station nuked (nuke,explosion,summary)
						flick("intro_nuke",cinematic)
						sleep(35)
						flick("station_explode_fade_red",cinematic)
						world << sound('sound/effects/explosionfar.ogg')
						cinematic.icon_state = "summary_selfdes"
					else //Station nuked (nuke,explosion,summary)
						flick("intro_nuke",cinematic)
						sleep(35)
						flick("station_explode_fade_red", cinematic)
						world << sound('sound/effects/explosionfar.ogg')
						cinematic.icon_state = "summary_selfdes"
				for(var/mob/living/M in living_mob_list)
					if(isOnStationLevel(M))
						M.death()//No mercy
		//If its actually the end of the round, wait for it to end.
		//Otherwise if its a verb it will continue on afterwards.
		sleep(300)

		if(cinematic)	qdel(cinematic)		//end the cinematic
		if(temp_buckle)	qdel(temp_buckle)	//release everybody
		return


	proc/create_characters()
		for(var/mob/new_player/player in player_list)
			if(player && player.ready && player.mind && player.mind.assigned_role)
				switch(player.mind.assigned_role)
					if("AI")
						player.close_spawn_windows()
						player.AIize(1)
					if("Cyborg")
						player.create_robot_character()
						qdel(player)
					else
						player.create_character()
						qdel(player)


	proc/collect_minds()
		for(var/mob/living/player in player_list)
			if(player.mind)
				ticker.minds += player.mind


	proc/equip_characters()
		var/captainless = 1
		for(var/mob/living/player in player_list)
			if(player && player.mind && player.mind.assigned_role)
				var/rang = player.mind.assigned_role
				if(rang == "Captain")
					captainless=0
				if(!player_is_antag(player.mind, only_offstation_roles = 1))
					job_master.EquipRank(player, rang)
					equip_custom_items(player)
					job_master.MoveAtSpawnPoint(player, rang)
					if(ishuman(player))
						UpdateFactionList(player)
		if(captainless)
			for(var/mob/M in player_list)
				if(!isnewplayer(M))
					M << "Captainship not forced on anyone."

	proc/check_queue()
		if(!queued_players.len || !config.hard_popcap)
			return

		queue_delay++
		var/mob/new_player/next_in_line = queued_players[1]

		switch(queue_delay)
			if(5) //every 5 ticks check if there is a slot available
				if(living_player_count() < config.hard_popcap)
					if(next_in_line && next_in_line.client)
						next_in_line << {"
							<span class='userdanger'>A slot has opened!
							You have approximately 20 seconds to join.
							<a href='?src=\ref[next_in_line];late_join=override'>\>\>Join Game\<\<</a></span>
						"}
						next_in_line << sound('sound/misc/notice1.ogg')
						next_in_line.LateChoices()
						return
					queued_players -= next_in_line //Client disconnected, remove he
				queue_delay = 0 //No vacancy: restart timer
			if(25 to INFINITY)  //No response from the next in line when a vacancy exists, remove he
				next_in_line << "<span class='danger'>No response recieved. You have been removed from the line.</span>"
				queued_players -= next_in_line
				queue_delay = 0

	proc/process()
		if(current_state != GAME_STATE_PLAYING)
			return 0

		mode.process()
		check_queue()

//		emergency_shuttle.process() //handled in scheduler

		var/game_finished = 0
		var/mode_finished = 0
		if (config.continous_rounds)
			game_finished = (emergency_shuttle.returned() || mode.station_was_nuked)
			mode_finished = (!post_game && mode.check_finished())
		else
			game_finished = (mode.check_finished() || (emergency_shuttle.returned() && emergency_shuttle.evac == 1)) || universe_has_ended
			mode_finished = game_finished

		if(!mode.explosion_in_progress && game_finished && (mode_finished || post_game))
			current_state = GAME_STATE_FINISHED

			spawn
				declare_completion()

			spawn(50)
				callHook("roundend")

				if (mode.station_was_nuked)
					if(!delay_end)
						world << SPAN_NOTE("<B>Rebooting due to destruction of station in [restart_timeout/10] seconds</B>")
				else
					if(!delay_end)
						world << SPAN_NOTE("<B>Restarting in [restart_timeout/10] seconds</B>")

				if(!delay_end)
					sleep(restart_timeout)
					if(!delay_end)
						world.Reboot()
					else
						world << SPAN_NOTE("<B>An admin has delayed the round end</B>")
				else
					world << SPAN_NOTE("<B>An admin has delayed the round end</B>")

		else if (mode_finished)
			post_game = 1

			mode.cleanup()

			//call a transfer shuttle vote
			spawn(50)
				if(!round_end_announced) // Spam Prevention. Now it should announce only once.
					world << "\red The round has ended!"
					round_end_announced = 1
				vote.autotransfer()

		return 1

/datum/controller/gameticker/proc/declare_completion()
	world << "<br><br><br><H1>A round of [mode.name] has ended!</H1>"
	for(var/mob/Player in player_list)
		Player << sound('sound/music/space_asshole.ogg', repeat = 0, wait = 0, volume = 85, channel = 777)
		if(Player.mind && !isnewplayer(Player))
			if(Player.stat != DEAD)
				var/turf/playerTurf = get_turf(Player)
				if(emergency_shuttle.departed && emergency_shuttle.evac)
					if(isNotAdminLevel(playerTurf.z))
						Player << "<font color='blue'><b>You managed to survive, but were marooned on [station_name()] as [Player.real_name]...</b></font>"
					else
						Player << "<font color='green'><b>You managed to survive the events on [station_name()] as [Player.real_name].</b></font>"
				else if(isAdminLevel(playerTurf.z))
					Player << "<font color='green'><b>You successfully underwent crew transfer after events on [station_name()] as [Player.real_name].</b></font>"
				else if(issilicon(Player))
					Player << "<font color='green'><b>You remain operational after the events on [station_name()] as [Player.real_name].</b></font>"
				else
					Player << "<font color='blue'><b>You missed the crew transfer after the events on [station_name()] as [Player.real_name].</b></font>"
			else
				if(isobserver(Player))
					var/mob/observer/dead/O = Player
					if(!O.started_as_observer)
						Player << "<font color='red'><b>You did not survive the events on [station_name()]...</b></font>"
				else
					Player << "<font color='red'><b>You did not survive the events on [station_name()]...</b></font>"
	world << "<br>"

	for (var/mob/living/silicon/ai/aiPlayer in mob_list)
		if (aiPlayer.stat != DEAD)
			world << "<b>[aiPlayer.name] (Played by: [aiPlayer.key])'s laws at the end of the round were:</b>"
		else
			world << "<b>[aiPlayer.name] (Played by: [aiPlayer.key])'s laws when it was deactivated were:</b>"
		aiPlayer.show_laws(1)

		if (aiPlayer.connected_robots.len)
			var/robolist = "<b>The AI's loyal minions were:</b> "
			for(var/mob/living/silicon/robot/robo in aiPlayer.connected_robots)
				robolist += "[robo.name][robo.stat?" (Deactivated) (Played by: [robo.key]), ":" (Played by: [robo.key]), "]"
			world << "[robolist]"

	var/dronecount = 0

	for (var/mob/living/silicon/robot/robo in mob_list)

		if(isdrone(robo))
			dronecount++
			continue

		if (!robo.connected_ai)
			if (robo.stat != DEAD)
				world << "<b>[robo.name] (Played by: [robo.key]) survived as an AI-less borg! Its laws were:</b>"
			else
				world << "<b>[robo.name] (Played by: [robo.key]) was unable to survive the rigors of being a cyborg without an AI. Its laws were:</b>"

			if(robo) //How the hell do we lose robo between here and the world messages directly above this?
				robo.laws.show_laws(world)

	if(dronecount)
		world << "<b>There [dronecount>1 ? "were" : "was"] [dronecount] industrious maintenance [dronecount>1 ? "drones" : "drone"] at the end of this round.</b>"

	mode.declare_completion()//To declare normal completion.

	//Ask the event manager to print round end information
	event_manager.RoundEnd()

	//Print a list of antagonists to the server log
	var/list/total_antagonists = list()
	//Look into all mobs in world, dead or alive
	for(var/datum/mind/Mind in minds)
		var/temprole = Mind.special_role
		if(temprole)							//if they are an antagonist of some sort.
			if(temprole in total_antagonists)	//If the role exists already, add the name to it
				total_antagonists[temprole] += ", [Mind.name]([Mind.key])"
			else
				total_antagonists.Add(temprole) //If the role doesnt exist in the list, create it and add the mob
				total_antagonists[temprole] += ": [Mind.name]([Mind.key])"

	//Now print them all into the log!
	var/output = "Antagonists at round end were..."
	for(var/i in total_antagonists)
		output += "[i]s[total_antagonists[i]]."

	log_game(output)

	return 1

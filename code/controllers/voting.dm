var/datum/controller/vote/vote = new()

var/global/list/round_voters = list() //Keeps track of the individuals voting for a given round, for use in forcedrafting.

datum/controller/vote
	var/initiator = null
	var/started_time = null
	var/time_remaining = 0
	var/mode = null
	var/question = null
	var/list/choices = list()
	var/list/gamemode_names = list()
	var/list/voted = list()
	var/list/voting = list()
	var/list/current_votes = list()
	var/list/additional_text = list()
	var/auto_muted = 0
	var/dead_allow_forced = 0

	New()
		if(vote != src)
			if(istype(vote))
				del(vote)
			vote = src

	proc/process()	//called by master_controller
		if(mode)
			// No more change mode votes after the game has started.
			// 3 is GAME_STATE_PLAYING, but that #define is undefined for some reason
			if(mode == "gamemode" && ticker.current_state >= 2)
				world << "<b>Voting aborted due to game start.</b>"
				src.reset()
				return

			// Calculate how much time is remaining by comparing current time, to time of vote start,
			// plus vote duration
			time_remaining = round((started_time + config.vote_period - world.time)/10)

			if(time_remaining < 0)
				result()
				for(var/client/C in voting)
					if(C)
						C << browse(null,"window=vote;can_close=0")
				reset()
			else
				for(var/client/C in voting)
					if(C)
						C << browse(vote.interface(C),"window=vote;can_close=0")

				voting.Cut()

	proc/autotransfer()
		initiate_vote("crew_transfer","the server", 1)
		log_debug("The server has called a crew transfer vote")

	proc/autogamemode()
		initiate_vote("gamemode","the server", 1)
		log_debug("The server has called a gamemode vote")

	proc/reset()
		initiator = null
		time_remaining = 0
		mode = null
		question = null
		choices.Cut()
		voted.Cut()
		voting.Cut()
		current_votes.Cut()
		additional_text.Cut()
		dead_allow_forced = 0

	proc/get_result()
		//get the highest number of votes
		var/greatest_votes = 0
		var/total_votes = 0
		for(var/option in choices)
			var/votes = choices[option]
			total_votes += votes
			if(votes > greatest_votes)
				greatest_votes = votes
		//default-vote for everyone who didn't vote
		if(!config.vote_no_default && choices.len)
			var/non_voters = (clients.len - total_votes)
			if(non_voters > 0)
				if(mode == "restart")
					choices["Continue Playing"] += non_voters
					if(choices["Continue Playing"] >= greatest_votes)
						greatest_votes = choices["Continue Playing"]
				else if(mode == "gamemode")
					if(master_mode in choices)
						choices[master_mode] += non_voters
						if(choices[master_mode] >= greatest_votes)
							greatest_votes = choices[master_mode]
				else if(mode == "crew_transfer")
					greatest_votes = max(choices["Initiate Crew Transfer"], total_votes / 1.5)


		//get all options with that many votes and return them in a list
		. = list()
		if(greatest_votes)
			for(var/option in choices)
				if(choices[option] == greatest_votes)
					. += option
		return .

	proc/announce_result()
		var/list/winners = get_result()
		var/text
		if(winners.len > 0)
			if(winners.len > 1)
				if(mode != "gamemode" || ticker.hide_mode == 0) // Here we are making sure we don't announce potential game modes
					text = "<b>Vote Tied Between:</b>\n"
					for(var/option in winners)
						text += "\t[option]\n"
			. = pick(winners)

			for(var/key in current_votes)
				if(choices[current_votes[key]] == .)
					round_voters += key // Keep track of who voted for the winning round.
			if((mode == "gamemode" && . == "Extended") || ticker.hide_mode == 0) // Announce Extended gamemode, but not other gamemodes
				text += "<b>Vote Result: [.]</b>"
			else
				if(mode != "gamemode")
					text += "<b>Vote Result: [.]</b>"
				else
					text += "<b>The vote has ended.</b>" // What will be shown if it is a gamemode vote that isn't extended

		else
			if(mode == "crew_transfer")
				text += "<b>Vote Result: Continue Playing</b>"
			else
				text += "<b>Vote Result: Inconclusive - No Votes!</b>"
			if(mode == "add_antagonist")
				antag_add_failed = 1
		log_vote(text)
		world << "<font color='purple'>[text]</font>"
		return .

	proc/result()
		. = announce_result()
		var/restart = 0
		if(.)
			switch(mode)
				if("restart")
					if(. == "Restart Round")
						restart = 1
				if("gamemode")
					if(master_mode != .)
						world.save_mode(.)
						if(ticker && ticker.mode)
							restart = 1
						else
							master_mode = .
				if("crew_transfer")
					if(. == "Initiate Crew Transfer")
						init_shift_change(null, 1)
				if("add_antagonist")
					if(isnull(.) || . == "None")
						antag_add_failed = 1
					else
						additional_antag_types |= antag_names_to_ids[.]

		if(mode == "gamemode") //fire this even if the vote fails.
			if(!going)
				going = 1
				world << "<font color='red'><b>The round will start soon.</b></font>"

		if(restart)
			world << "World restarting due to vote..."
			sleep(50)
			log_game("Rebooting due to restart vote")
			world.Reboot()

		return .

	proc/submit_vote(var/ckey, var/vote)
		if(mode)
			if(!dead_allow_forced && config.vote_no_dead && !usr.client.holder)
				if(usr.stat == DEAD || usr.type == /mob/living/simple_animal/mouse || usr.type == /mob/living/silicon/robot/drone || isOnAdminLevel(usr))
					return 0
			if(vote && vote >= 1 && vote <= choices.len)
				if(current_votes[ckey])
					choices[choices[current_votes[ckey]]]--
				voted += usr.ckey
				choices[choices[vote]]++	//check this
				current_votes[ckey] = vote
				return vote
		return 0

	proc/initiate_vote(var/vote_type, var/initiator_key, var/automatic = 0)
		if(!mode)
			if(started_time != null && !(check_rights(R_ADMIN) || automatic))
				var/next_allowed_time = (started_time + config.vote_delay)
				if(next_allowed_time > world.time)
					return 0

			reset()
			dead_allow_forced = automatic && !(admins && admins.len)
			switch(vote_type)
				if("restart")
					choices.Add("Restart Round","Continue Playing")
				if("gamemode")
					if(ticker.current_state >= 2)
						return 0
					choices.Add(config.votable_modes)
					for (var/F in choices)
						var/datum/game_mode/M = gamemode_cache[F]
						if(!M)
							continue
						gamemode_names[M.config_tag] = capitalize(M.name) //It's ugly to put this here but it works
						additional_text.Add("<td align = 'center'>[M.required_players]</td>")
					gamemode_names["secret"] = "Secret"
				if("crew_transfer")
					if(check_rights(R_ADMIN|R_MOD, 0))
						question = "End the shift? Requires at least 2/3 of total votes count to succeed."
						choices.Add("Initiate Crew Transfer", "Continue The Round")
					else
						if (get_security_level() == "red" || get_security_level() == "delta")
							initiator_key << "The current alert status is too high to call for a crew transfer!"
							return 0
						if(ticker.current_state <= 2)
							return 0
							initiator_key << "The crew transfer button has been disabled!"
						question = "End the shift? Requires at least 2/3 of total votes count to succeed."
						choices.Add("Initiate Crew Transfer", "Continue The Round")
				if("add_antagonist")
					if(!config.allow_extra_antags || ticker.current_state >= 2)
						return 0
					for(var/antag_type in all_antag_types)
						var/datum/antagonist/antag = all_antag_types[antag_type]
						if(!(antag.id in additional_antag_types) && antag.is_votable())
							choices.Add(antag.role_text)
					choices.Add("None")
				if("custom")
					question = html_encode(input(usr,"What is the vote for?") as text|null)
					if(!question)	return 0
					for(var/i=1,i<=10,i++)
						var/option = capitalize(html_encode(input(usr,"Please enter an option or hit cancel to finish") as text|null))
						if(!option || mode || !usr.client)	break
						choices.Add(option)
				else
					return 0
			mode = vote_type
			initiator = initiator_key
			started_time = world.time
			var/text = "[capitalize(mode)] vote started by [initiator]."
			if(mode == "custom")
				text += "\n[question]"

			log_vote(text)
			world << "<font color='purple'><b>[text]</b>\nType <b>vote</b> or click <a href='?src=\ref[src]'>here</a> to place your votes.\nYou have [config.vote_period/10] seconds to vote.</font>"
			switch(vote_type)
				if("crew_transfer")
					world << sound('sound/ambience/alarm4.ogg', repeat = 0, wait = 0, volume = 50, channel = 3)
				if("gamemode")
					world << sound('sound/ambience/alarm4.ogg', repeat = 0, wait = 0, volume = 50, channel = 3)
				if("custom")
					world << sound('sound/ambience/alarm4.ogg', repeat = 0, wait = 0, volume = 50, channel = 3)
			if(mode == "gamemode" && going)
				going = 0
				world << "<font color='red'><b>Round start has been delayed.</b></font>"

			time_remaining = round(config.vote_period/10)
			return 1
		return 0

	proc/interface(var/client/C)
		if(!C)	return
		var/admin = 0
		var/trialmin = 0
		if(C.holder)
			if(C.holder.rights & R_ADMIN)
				admin = 1
				trialmin = 1 // don't know why we use both of these it's really weird, but I'm 2 lasy to refactor this all to use just admin.
		voting |= C

		. = "<html><head><meta charset=\"utf-8\"><title>Voting Panel</title></head><body>"
		if(mode)
			if(question)	. += "<h2>Vote: '[question]'</h2>"
			else			. += "<h2>Vote: [capitalize(mode)]</h2>"
			. += "Time Left: [time_remaining] s<hr>"
			. += "<table width = '100%'><tr><td align = 'center'><b>Choices</b></td><td align = 'center'><b>Votes</b></td>"
			if(capitalize(mode) == "Gamemode") .+= "<td align = 'center'><b>Minimum Players</b></td></b></tr>"

			for(var/i = 1, i <= choices.len, i++)
				var/votes = choices[choices[i]]
				if(!votes)	votes = 0
				. += "<tr>"
				if(mode == "gamemode")
					if(current_votes[C.ckey] == i)
						. += "<td><b><a href='?src=\ref[src];vote=[i]'>[gamemode_names[choices[i]]]</a></b></td><td align = 'center'>[votes]</td>"
					else
						. += "<td><a href='?src=\ref[src];vote=[i]'>[gamemode_names[choices[i]]]</a></b></td><td align = 'center'>[votes]</td>"
				else
					if(current_votes[C.ckey] == i)
						. += "<td><b><a href='?src=\ref[src];vote=[i]'>[choices[i]]</a></b></td><td align = 'center'>[votes]</td>"
					else
						. += "<td><a href='?src=\ref[src];vote=[i]'>[choices[i]]</a></b></td><td align = 'center'>[votes]</td>"
				if (additional_text.len >= i)
					. += additional_text[i]
				. += "</tr>"

			. += "</table><hr>"
			if(admin)
				. += "(<a href='?src=\ref[src];vote=cancel'>Cancel Vote</a>) "
		else
			. += "<h2>Start a vote:</h2><hr><ul><li>"
			//restart
			if(trialmin || config.allow_vote_restart)
				. += "<a href='?src=\ref[src];vote=restart'>Restart</a>"
			else
				. += "<font color='grey'>Restart (Disallowed)</font>"
			. += "</li><li>"
			if(trialmin || config.allow_vote_restart)
				. += "<a href='?src=\ref[src];vote=crew_transfer'>Crew Transfer</a>"
			else
				. += "<font color='grey'>Crew Transfer (Disallowed)</font>"
			if(trialmin)
				. += "\t(<a href='?src=\ref[src];vote=toggle_restart'>[config.allow_vote_restart?"Allowed":"Disallowed"]</a>)"
			. += "</li><li>"
			//gamemode
			if(trialmin || config.allow_vote_mode)
				. += "<a href='?src=\ref[src];vote=gamemode'>GameMode</a>"
			else
				. += "<font color='grey'>GameMode (Disallowed)</font>"
			if(trialmin)
				. += "\t(<a href='?src=\ref[src];vote=toggle_gamemode'>[config.allow_vote_mode?"Allowed":"Disallowed"]</a>)"
			. += "</li><li>"
			//extra antagonists
			if(!antag_add_failed && config.allow_extra_antags)
				. += "<a href='?src=\ref[src];vote=add_antagonist'>Add Antagonist Type</a>"
			else
				. += "<font color='grey'>Restart (Disallowed)</font>"
			. += "</li>"
			//custom
			if(trialmin)
				. += "<li><a href='?src=\ref[src];vote=custom'>Custom</a></li>"
			. += "</ul><hr>"
		. += "<a href='?src=\ref[src];vote=close' style='position:absolute;right:50px'>Close</a></body></html>"
		return .


	Topic(href,href_list[],hsrc)
		if(!usr || !usr.client)	return	//not necessary but meh...just in-case somebody does something stupid
		switch(href_list["vote"])
			if("close")
				voting -= usr.client
				usr << browse(null, "window=vote")
				return
			if("cancel")
				if(usr.client.holder)
					reset()
			if("toggle_restart")
				if(usr.client.holder)
					config.allow_vote_restart = !config.allow_vote_restart
			if("toggle_gamemode")
				if(usr.client.holder)
					config.allow_vote_mode = !config.allow_vote_mode
			if("restart")
				if(config.allow_vote_restart || usr.client.holder)
					initiate_vote("restart",usr.key)
			if("gamemode")
				if(config.allow_vote_mode || usr.client.holder)
					initiate_vote("gamemode",usr.key)
			if("crew_transfer")
				if(config.allow_vote_restart || usr.client.holder)
					initiate_vote("crew_transfer",usr.key)
			if("add_antagonist")
				if(config.allow_extra_antags)
					initiate_vote("add_antagonist",usr.key)
			if("custom")
				if(usr.client.holder)
					initiate_vote("custom",usr.key)
			else
				var/t = round(text2num(href_list["vote"]))
				if(t) // It starts from 1, so there's no problem
					submit_vote(usr.ckey, t)
		usr.vote()


/mob/verb/vote()
	set category = "OOC"
	set name = "Vote"

	if(vote)
		src << browse(vote.interface(client),"window=vote;can_close=0")

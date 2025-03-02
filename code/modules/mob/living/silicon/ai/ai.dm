var/list/ai_list = list()

//Not sure why this is necessary...
/proc/AutoUpdateAI(obj/subject)
	var/is_in_use = FALSE
	if(subject!=null)
		for(var/A in ai_list)
			var/mob/living/silicon/ai/M = A
			if((M.client && M.machine == subject))
				is_in_use = TRUE
				subject.attack_ai(M)
	return is_in_use


/mob/living/silicon/ai
	name = "AI"
	icon = 'icons/mob/AI.dmi'
	icon_state = "ai"
	anchored = TRUE // -- TLE
	density = TRUE
	status_flags = CANSTUN|CANPARALYSE|CANPUSH
	force_compose = TRUE
	size = SIZE_BIG

	var/list/network = list(CAMERANET_SS13)
	var/obj/machinery/camera/current = null
	var/list/connected_robots = list()
	var/aiRestorePowerRoutine = 0
	var/alarms = list("Motion"=list(), "Fire"=list(), "Atmosphere"=list(), "Power"=list(), "Camera"=list())
	var/viewalerts = FALSE
	var/lawcheck[1]
	var/ioncheck[1]
	var/icon/holo_icon//Default is assigned when AI is created.
	var/holocolor = rgb(60,180,225) //default is blue
	var/obj/item/device/pda/ai/aiPDA = null
	var/obj/item/device/multitool/aiMulti = null
	var/obj/item/device/station_map/station_holomap = null
	var/obj/item/device/camera/silicon/aicamera = null
	var/busy = FALSE //Toggle Floor Bolt busy var.
	var/chosen_core_icon_state = "ai"
	var/datum/intercom_settings/intercom_clipboard = null //Clipboard for copy/pasting intercom settings
	var/mentions_on = FALSE
	var/list/holopadoverlays = list()

	// See VOX_AVAILABLE_VOICES for available values
	var/vox_voice = "fem";
	var/vox_corrupted = FALSE
//Hud stuff

	//MALFUNCTION
	var/ai_flags = 0

	var/control_disabled = FALSE // Set to TRUE to stop AI from interacting via Click() -- TLE
	var/malfhacking = FALSE // More or less a copy of the above var, so that malf AIs can hack and still get new cyborgs -- NeoFite
	var/mob/living/silicon/ai/shuntedAI = null
	var/mob/living/silicon/ai/parent = null
	var/obj/machinery/power/apc/malfhack = null
	var/explosive = FALSE //does the AI explode when it dies?
	var/blackout_active = FALSE
	var/explosive_cyborgs = FALSE	//Will any cyborgs slaved to the AI exploe when they die?


	var/camera_light_on = FALSE
	var/list/obj/machinery/camera/lit_cameras = list()

	var/datum/trackable/track = new()

	var/last_paper_seen = null
	var/can_shunt = TRUE
	var/last_announcement = ""

	// The AI's "eye". Described on the top of the page in eye.dm

	var/mob/camera/aiEye/eyeobj
	var/sprint = 10
	var/cooldown = 0
	var/acceleration = 1

	var/static/obj/abstract/screen/nocontext/aistatic/aistatic = new()

/mob/living/silicon/ai/New(loc, var/datum/ai_laws/L, var/obj/item/device/mmi/B, var/safety = FALSE)

	var/list/possibleNames = ai_names

	var/pickedName = null
	while(!pickedName)
		pickedName = pick(ai_names)
		for (var/mob/living/silicon/ai/A in mob_list)
			if(A.real_name == pickedName && possibleNames.len > 1) //fixing the theoretically possible infinite loop
				possibleNames -= pickedName
				pickedName = null

	//AIs speak all languages that aren't restricted(XENO, CULT).
	for(var/language_name in all_languages)
		var/datum/language/lang = all_languages[language_name]
		if(!(lang.flags & RESTRICTED) && !(lang in languages))
			add_language(lang.name)

	//But gal common is restricted so let's add it manually.
	add_language(LANGUAGE_GALACTIC_COMMON)
	default_language = all_languages[LANGUAGE_GALACTIC_COMMON]
	init_language = default_language

	real_name = pickedName
	name = real_name
	anchored = TRUE
	canmove = FALSE
	setDensity(TRUE)
	loc = loc

	radio = new /obj/item/device/radio/borg/ai(src)
	radio.recalculateChannels()

	holo_icon = getHologramIcon(icon('icons/mob/AI.dmi',"holo1"))

	proc_holder_list = new()

	//Determine the AI's lawset
	if(L && istype(L,/datum/ai_laws))
		src.laws = L
	else
		src.laws = getLawset(src)

	verbs += /mob/living/silicon/ai/proc/show_laws_verb

	aiPDA = new/obj/item/device/pda/ai(src)
	aiPDA.owner = name
	aiPDA.ownjob = "AI"
	aiPDA.name = name + " (" + aiPDA.ownjob + ")"

	station_holomap = new(src)

	aiMulti = new(src)
	aicamera = new /obj/item/device/camera/silicon/ai_camera(src)
	if(istype(loc, /turf))
		verbs.Add(/mob/living/silicon/ai/proc/ai_network_change, \
		/mob/living/silicon/ai/proc/ai_statuschange, \
		/mob/living/silicon/ai/proc/ai_hologram_change)

	if(!safety)//Only used by AIize() to successfully spawn an AI.
		if(!B)//If there is no player/brain inside.
			new/obj/structure/AIcore/deactivated(loc)//New empty terminal.
			qdel(src)//Delete AI.
			return
		else
			if(B.brainmob.mind)
				B.brainmob.mind.transfer_to(src)

			to_chat(src, "<B>You are playing the station's AI. The AI cannot move, but can interact with many objects while viewing them (through cameras).</B>")
			to_chat(src, "<B>To look at other parts of the station, click on yourself to get a camera menu.</B>")
			to_chat(src, "<B>While observing through a camera, you can use most (networked) devices which you can see, such as computers, APCs, intercoms, doors, etc.</B>")
			to_chat(src, "To use something, simply click on it.")
			to_chat(src, "Use say :b to speak to your cyborgs through binary.")
			show_laws()
			if (!ismalf(src))
				to_chat(src, "<b>These laws may be changed by other players, or by you being the traitor.</b>")
			if (mind && !stored_freqs)
				to_chat(src, "The various frequencies used by the crew to communicate have been stored in your mind. Use the verb <i>Notes</i> to access them.")
				spawn(1)
					mind.store_memory("Frequencies list: <br/><b>Command:</b> [COMM_FREQ] <br/> <b>Security:</b> [SEC_FREQ] <br/> <b>Medical:</b> [MED_FREQ] <br/> <b>Science:</b> [SCI_FREQ] <br/> <b>Engineering:</b> [ENG_FREQ] <br/> <b>Service:</b> [SER_FREQ] <b>Cargo:</b> [SUP_FREQ]<br/> <b>AI private:</b> [AIPRIV_FREQ]<br/>", category=MIND_MEMORY_GENERAL, forced=TRUE)
				stored_freqs = 1

			job = "AI"
	ai_list += src
	..()
	if(!safety)
		if(prob(25))
			playsound(src, get_sfx("windows error"), 75, FALSE)
		else
			playsound(src, 'sound/machines/WXP_startup.ogg', 75, FALSE)

/mob/living/silicon/ai/verb/toggle_anchor()
	set category = "AI Commands"
	set name = "Toggle Floor Bolts"

	if(incapacitated() || aiRestorePowerRoutine || !isturf(loc) || busy)
		return
	busy = TRUE
	playsound(loc, 'sound/items/Ratchet.ogg', 50, 1)
	if(do_after(src, src, 30))
		anchored = !anchored
		to_chat(src, "You are now <b>[anchored ? "" : "un"]anchored</b>.")
	busy = FALSE

/mob/living/silicon/ai/verb/toggle_holopadoverlays()
	set category = "AI Commands"
	set name = "Toggle Holopad Overlays"

	if(incapacitated() || aiRestorePowerRoutine || !isturf(loc) || busy)
		return
	toggleholopadoverlays()
	to_chat(src, "<span class='notice' style=\"font-family:Courier\">Holopad overlays <b>[holopadoverlays.len ? "en" : "dis"]abled</b>.</span>")

/mob/living/silicon/ai/verb/radio_interact()
	set category = "AI Commands"
	set name = "Radio Configuration"
	if(stat || aiRestorePowerRoutine)
		return
	radio.attack_self(usr)

/mob/living/silicon/ai/verb/rename_photo() //This is horrible but will do for now
	set category = "AI Commands"
	set name = "Modify Photo Files"
	if(stat || aiRestorePowerRoutine)
		return

	var/list/nametemp = list()
	var/find
	var/datum/picture/selection
	if(!aicamera.aipictures.len)
		to_chat(usr, "<font color=red><B>No images saved<B></font>")
		return
	for(var/datum/picture/t in aicamera.aipictures)
		nametemp += t.fields["name"]
	find = input("Select image to delete or rename.", "Photo Modification") in nametemp
	for(var/datum/picture/q in aicamera.aipictures)
		if(q.fields["name"] == find)
			selection = q
			break

	if(!selection)
		return
	var/choice = input(usr, "Would you like to rename or delete [selection.fields["name"]]?", "Photo Modification") in list("Rename","Delete","Cancel")
	switch(choice)
		if("Cancel")
			return
		if("Delete")
			aicamera.aipictures.Remove(selection)
			qdel(selection)
		if("Rename")
			var/new_name = sanitize(input(usr, "Write a new name for [selection.fields["name"]]:","Photo Modification"))
			if(length(new_name) > 0)
				selection.fields["name"] = new_name
			else
				to_chat(usr, "You must write a name.")

var/static/list/ai_icon_states = list(
		"Alien" = "ai-alien",
		"Angel" = "ai-angel",
		"Angry" = "ai-angryface",
		"Bliss" = "ai-bliss",
		"Blue" = "ai",
		"Boy Malf" = "ai-boy-malf",
		"Boy" = "ai-boy",
		"Broken Output" = "ai-static",
		"Clown" = "ai-clown2",
		"Dancing Hotdog" = "ai-hotdog",
		"Database" = "ai-database",
		"Diagnosis" = "ai-atlantiscze",
		"Dorf" = "ai-dorf",
		"Drink It!" = "ai-silveryferret",
		"Fabulous" = "ai-fabulous",
		"Firewall" = "ai-magma",
		"Fort" = "ai-boxfort",
		"Four-Leaf" = "ai-4chan",
		"Gentoo" = "ai-gentoo",
		"Girl Malf" = "ai-girl-malf",
		"Girl" = "ai-girl",
		"Glitchman" = "ai-glitchman",
		"Gondola" = "ai-gondola",
		"Goon" = "ai-goon",
		"Green" = "ai-wierd",
		"Hades" = "ai-hades",
		"Heartline" = "ai-heartline",
		"Helios" = "ai-helios",
		"Hourglass" = "ai-hourglass",
		"Inverted" = "ai-u",
		"JaCobson" = "ai-cobson",
		"Jack Frost" = "ai-jack",
		"Matrix" = "ai-matrix",
		"Metaclub" = "ai-terminal",
		"Monochrome" = "ai-mono",
		"Mothman" = "ai-mothman",
		"Murica" = "ai-murica",
		"Nanotrasen" = "ai-nanotrasen",
		"Patriot" = "ai-patriot",
		"Pirate" = "ai-pirate",
		"President" = "ai-pres",
		"Rainbow" = "ai-clown",
		"Ravensdale" = "ai-ravensdale",
		"Red October" = "ai-soviet",
		"Red" = "ai-malf",
		"Override" = "ai-malf-shodan",
		"Robert House" = "ai-president",
		"Royal" = "ai-royal",
		"Searif" = "ai-searif",
		"Serithi" = "ai-serithi",
		"Smiley" = "ai-smiley",
		"Static" = "ai-fuzz",
		"Syndicat" = "ai-syndicatmeow",
		"Text" = "ai-text",
		"Too Deep" = "ai-toodeep",
		"Triumvirate Static" = "ai-triumvirate-malf",
		"Triumvirate" = "ai-triumvirate",
		"Wasp" = "ai-wasp",
		"Xerxes" = "ai-xerxes",
		"Yes Man" = "yes-man",
	)

/mob/living/silicon/ai/verb/pick_icon()
	set category = "AI Commands"
	set name = "Set AI Core Display"
	if(stat || aiRestorePowerRoutine)
		return
	var/selected = input("Select an icon!", "AI", null, null) as null|anything in ai_icon_states
	if(!selected)
		return
	var/chosen_state = ai_icon_states[selected]
	ASSERT(chosen_state)
	chosen_core_icon_state = chosen_state
	update_icon()

/mob/living/silicon/ai/verb/pick_hologram_color()
	set category = "AI Commands"
	set name = "Set AI hologram color"
	if(stat || aiRestorePowerRoutine)
		return
	var/chosen_holocolor = input(usr, "Please select the hologram color.", "holocolor") as color
	holocolor = chosen_holocolor

// displays the malf_ai information if the AI is the malf
/mob/living/silicon/ai/show_malf_ai()
	var/datum/role/malfAI/malf = mind.GetRole(MALF)
	var/datum/faction/malf/malffac = find_active_faction_by_member(malf)
	if(malf && malf.apcs.len >= 3)
		stat(null, "Amount of APCS hacked: [malf.apcs.len]")
		stat(null, "Time until station control secured: [max(malffac.AI_win_timeleft/(malf.apcs.len/3), 0)] seconds")

/mob/living/silicon/ai/proc/ai_alerts()


	var/dat = {"<HEAD><TITLE>Current Station Alerts</TITLE><META HTTP-EQUIV='Refresh' CONTENT='10'></HEAD><BODY>\n
<A HREF='?src=\ref[src];mach_close=aialerts'>Close</A><BR><BR>"}
	for (var/cat in alarms)
		dat += text("<B>[]</B><BR>\n", cat)
		var/list/L = alarms[cat]
		if(L.len)
			for (var/alarm in L)
				var/list/alm = L[alarm]
				var/area/A = alm[1]
				var/C = alm[2]
				var/list/sources = alm[3]
				dat += "<NOBR>"
				if(C && istype(C, /list))
					var/dat2 = ""
					for (var/obj/machinery/camera/I in C)
						dat2 += text("[]<A HREF=?src=\ref[];switchcamera=\ref[]>[]</A>", (dat2=="") ? "" : " | ", src, I, I.c_tag)
					dat += text("-- [] ([])", A.name, (dat2!="") ? dat2 : "No Camera")
				else if(C && istype(C, /obj/machinery/camera))
					var/obj/machinery/camera/Ctmp = C
					dat += text("-- [] (<A HREF=?src=\ref[];switchcamera=\ref[]>[]</A>)", A.name, src, C, Ctmp.c_tag)
				else
					dat += text("-- [] (No Camera)", A.name)
				if(sources.len > 1)
					dat += text("- [] sources", sources.len)
				dat += "</NOBR><BR>\n"
		else
			dat += "-- All Systems Nominal<BR>\n"
		dat += "<BR>\n"

	viewalerts = TRUE
	src << browse(dat, "window=aialerts&can_close=0")

// this verb lets the ai see the stations manifest
/mob/living/silicon/ai/proc/ai_roster()
	show_station_manifest()

/mob/living/silicon/ai/proc/ai_call_or_recall_shuttle()
	if(isDead())
		to_chat(src, "<span class='warning'>You can't call/recall the shuttle because you are dead!</span>")
		return
	if(istype(usr,/mob/living/silicon/ai))
		var/mob/living/silicon/ai/AI = src
		if(AI.control_disabled)
			to_chat(usr, "<span class='warning'>Wireless control is disabled!</span>")
			return
	switch(emergency_shuttle.direction)
		if(EMERGENCY_SHUTTLE_RECALLED)
			to_chat(usr, "<span class='warning'>Wait until the shuttle arrives at Centcomm and try again</span>")
		if(EMERGENCY_SHUTTLE_STANDBY)
			ai_call_shuttle()
		if(EMERGENCY_SHUTTLE_GOING_TO_STATION)
			ai_recall_shuttle()
		if(EMERGENCY_SHUTTLE_GOING_TO_CENTCOMM)
			to_chat(usr, "<span class='warning'>Too late!</span>")

/mob/living/silicon/ai/proc/ai_call_shuttle()
	var/justification = stripped_input(usr, "Please input a concise justification for the shuttle call. Note that failure to properly justify a shuttle call may lead to recall or termination.", "Nanotrasen Anti-Comdom Systems")
	if(!justification)
		return
	var/confirm = alert("Are you sure you want to call the shuttle?", "Confirm Shuttle Call", "Yes", "Cancel")
	if(confirm == "Yes")
		call_shuttle_proc(src, justification)

	// hack to display shuttle timer
	if(emergency_shuttle.online)
		var/obj/machinery/computer/communications/C = locate() in machines
		if(C)
			C.post_status("shuttle")

/mob/living/silicon/ai/proc/ai_recall_shuttle()
	if(!ismalf(src))
		to_chat(usr, "<span class='warning'>Your morality core throws an error. Recalling an emergency shuttle is a symptom of a malfunctioning artificial intelligence.</span>")
		return
	var/datum/faction/malf/M = find_active_faction_by_member(mind.GetRole(MALF))
	if(M?.stage != FACTION_ENDGAME)
		to_chat(usr, "<span class='warning'>You need to initiate the takeover first</span>")
		return
	var/confirm = alert("Are you sure you want to recall the shuttle?", "Confirm Recall Shuttle", "Yes", "Cancel")
	if(confirm == "Yes")
		recall_shuttle(src)

/mob/living/silicon/ai/check_eye(var/mob/user as mob)
	if(!current)
		return null
	user.reset_view(current)
	return TRUE

/mob/living/silicon/ai/blob_act()
	if(flags & INVULNERABLE)
		return
	if(stat != DEAD)
		..()
		playsound(loc, 'sound/effects/blobattack.ogg',50,1)
		adjustBruteLoss(60)
		updatehealth()
		return TRUE
	return FALSE

/mob/living/silicon/ai/restrained()
	if(timestopped)
		return TRUE //under effects of time magick
	return FALSE

/mob/living/silicon/ai/emp_act(severity)
	if(flags & INVULNERABLE)
		return

	if(prob(30))
		switch(pick(1,2))
			if(1)
				view_core()
			if(2)
				if(call_shuttle_proc(src))
					message_admins("[key_name_admin(src)] called the shuttle due to being hit with an EMP.'.")
	..()

/mob/living/silicon/ai/ex_act(severity, var/child=null, var/mob/whodunnit)
	if(flags & INVULNERABLE)
		return

	// if(!blinded) (this is now in flash_eyes)
	flash_eyes(visual = TRUE, affect_silicon = TRUE)

	if(!isDead())
		var/dmg_phrase = ""
		var/msg_admin = (src.key || src.ckey || (src.mind && src.mind.key)) && whodunnit
		switch(severity)
			if(1.0)
				adjustBruteLoss(100)
				adjustFireLoss(100)
				dmg_phrase = "Damage: 200"
			if(2.0)
				adjustBruteLoss(60)
				adjustFireLoss(60)
				dmg_phrase = "Damage: 120"
			if(3.0)
				adjustBruteLoss(30)
				dmg_phrase = "Damage: 30"

		add_attacklogs(src, whodunnit, "got caught in an explosive blast[whodunnit ? " from" : ""]", addition = "Severity: [severity], [dmg_phrase]", admin_warn = msg_admin)

	updatehealth()

/mob/living/silicon/ai/put_in_hands(var/obj/item/W)
	return FALSE

/mob/living/silicon/ai/Topic(href, href_list)
	if(usr != src)
		return
	. = ..()
	if(href_list["mach_close"])
		if(href_list["mach_close"] == "aialerts")
			viewalerts = FALSE
		var/t1 = text("window=[]", href_list["mach_close"])
		unset_machine()
		src << browse(null, t1)
	if(href_list["switchcamera"])
		switchCamera(locate(href_list["switchcamera"])) in cameranet.cameras
	if(href_list["showalerts"])
		ai_alerts()

	if(href_list["show_paper"])
		if(last_paper_seen)
			src << browse(last_paper_seen, "window=show_paper")
	//Carn: holopad requests
	if(href_list["jumptoholopad"])
		var/obj/machinery/hologram/holopad/H = locate(href_list["jumptoholopad"])
		if(stat == CONSCIOUS)
			if(H)
				H.attack_ai(src) //may as well recycle
			else
				to_chat(src, "<span class='notice'>Unable to locate the holopad.</span>")

	#ifndef DISABLE_VOX
	if(href_list["say_word"])
		play_vox_word(href_list["say_word"], vox_voice, null, src)
		return
	#endif

	if(href_list["track"])
		var/name_to_track = url_decode(href_list["track"])
		for(var/mob/some_mob in mob_list)
			if(some_mob.name != name_to_track)
				continue
			if(!can_track_atom(some_mob))
				continue
			ai_actual_track(some_mob)
			return
		to_chat(src, "<span class='warning'>Unable to track [name_to_track].</span>")
		return

	if(href_list["open"])
		var/mob/target = locate(href_list["open"])
		var/mob/living/silicon/ai/A = locate(href_list["open2"])
		if(A && target)
			A.open_nearest_door(target)
		return

	#ifndef DISABLE_VOX
	// set_voice=(fem|mas) - Sets VOX voicepack.
	if(href_list["set_voice"])
		// Never trust the client.
		if(!(href_list["set_voice"] in VOX_AVAILABLE_VOICES))
			to_chat(usr, "<span class='notice'>You chose a voice that is not available to AIs on this station. Command ignored.</span>")
			return

		vox_voice = href_list["set_voice"]
		to_chat(usr, "VOX voice set to [vox_voice].")
		make_announcement()
		return

	if(href_list["voice_corrupted"])
		vox_corrupted = text2num(href_list["voice_corrupted"]) // even if client hacks the value, we only care if it's true or false.
		make_announcement()

	// play_announcement=word1+word2... - Plays an announcement to the station.
	if(href_list["play_announcement"])
		//to_chat(usr, "Received play_announcement=[href_list["play_announcement"]]")
		if(announcement_checks())
			play_announcement(href_list["play_announcement"])
		return
	#endif

/mob/living/silicon/ai/bullet_act(var/obj/item/projectile/Proj)
	if((ai_flags & COREFORTIFY) && istype(Proj, /obj/item/projectile/beam))
		var/obj/item/projectile/beam/P = Proj
//		P.damage = P.damage / 2
//		P.rebound(src)
//		visible_message("<span class='danger'>\The [P] gets reflected by \the [src]'s firewall!</span>")
		visible_message("<span class='danger'>\The [P] is blocked by \the [src]'s firewall!</span>")
		anim(target = src, a_icon = 'icons/effects/64x64.dmi', flick_anim = "juggernaut_armor", lay = NARSIE_GLOW, offX = -WORLD_ICON_SIZE/2, offY = -WORLD_ICON_SIZE/2 + 4, plane = ABOVE_LIGHTING_PLANE)
		playsound(src, 'sound/items/metal_impact.ogg', 25)
//		return PROJECTILE_COLLISION_REBOUND
		return PROJECTILE_COLLISION_BLOCKED
	..(Proj)
	updatehealth()
	return PROJECTILE_COLLISION_DEFAULT

/mob/living/silicon/ai/attack_alien(mob/living/carbon/alien/humanoid/M)
	switch(M.a_intent)
		if(I_HELP)
			visible_message("<span class='notice'>[M] caresses [src]'s plating with its scythe like arm.</span>")

		else //harm
			if(M.unarmed_attack_mob(src))
				if(prob(8))
					flash_eyes(visual = TRUE, type = /obj/abstract/screen/fullscreen/flash/noise)

/mob/living/silicon/ai/attack_animal(mob/living/simple_animal/M as mob)
	M.unarmed_attack_mob(src)
	return 1

/mob/living/silicon/ai/reset_view(atom/A)
	if(camera_light_on)
		light_cameras()
	if(istype(A,/obj/machinery/camera))
		current = A
		var/obj/machinery/camera/C = A
		C.camera_twitch()
	..()


/mob/living/silicon/ai/proc/switchCamera(var/obj/machinery/camera/C)
	stop_ai_tracking()

	if(!C || isDead()) //C.can_use())
		return FALSE

	if(!src.eyeobj)
		view_core()
		return
	// ok, we're alive, camera is good and in our network...
	eyeobj.forceMove(get_turf(C))
	//machine = src

	return TRUE

/mob/living/silicon/ai/triggerAlarm(var/class, area/A, var/O, var/alarmsource)
	if(isDead())
		return TRUE
	var/list/L = alarms[class]
	for (var/I in L)
		if(I == A.name)
			var/list/alarm = L[I]
			var/list/sources = alarm[3]
			if(!(alarmsource in sources))
				sources += alarmsource
			return TRUE
	var/obj/machinery/camera/C = null
	var/list/CL = null
	if(O && istype(O, /list))
		CL = O
		if(CL.len == 1)
			C = CL[1]
	else if(O && istype(O, /obj/machinery/camera))
		C = O
	L[A.name] = list(A, (C) ? C : O, list(alarmsource))
	if(O)
		if(C && C.can_use())
			queueAlarm("--- [class] alarm detected in [A.name]! (<A HREF=?src=\ref[src];switchcamera=\ref[C]>[C.c_tag]</A>)", class)
		else if(CL && CL.len)
			var/foo = FALSE
			var/dat2 = ""
			for (var/obj/machinery/camera/I in CL)
				dat2 += text("[]<A HREF=?src=\ref[];switchcamera=\ref[]>[]</A>", (!foo) ? "" : " | ", src, I, I.c_tag)	//I'm not fixing this shit...
				foo = TRUE
			queueAlarm(text ("--- [] alarm detected in []! ([])", class, A.name, dat2), class)
		else
			queueAlarm(text("--- [] alarm detected in []! (No Camera)", class, A.name), class)
	else
		queueAlarm(text("--- [] alarm detected in []! (No Camera)", class, A.name), class)
	if(viewalerts)
		ai_alerts()
	return TRUE

/mob/living/silicon/ai/cancelAlarm(var/class, area/A as area, obj/origin)
	var/list/L = alarms[class]
	var/cleared = FALSE
	if(!A)
		return
	for (var/I in L)
		if(I == A.name)
			var/list/alarm = L[I]
			var/list/srcs  = alarm[3]
			if(origin in srcs)
				srcs -= origin
			if(!srcs.len)
				cleared = TRUE
				L -= I
	if(cleared)
		queueAlarm(text("--- [] alarm in [] has been cleared.", class, A.name), class, 0)
		if(viewalerts)
			ai_alerts()
	return !cleared

/mob/living/silicon/ai/cancel_camera()
	src.view_core()


//Replaces /mob/living/silicon/ai/verb/change_network() in ai.dm & camera.dm
//Adds in /mob/living/silicon/ai/proc/ai_network_change() instead
//Addition by Mord_Sith to define AI's network change ability
/mob/living/silicon/ai/proc/ai_network_change()
	set category = "AI Commands"
	set name = "Jump To Network"
	unset_machine()
	stop_ai_tracking()
	var/cameralist[0]

	if(usr.isDead())
		to_chat(usr, "You can't change your camera network because you are dead!")
		return

	var/mob/living/silicon/ai/U = usr

	for (var/obj/machinery/camera/C in cameranet.cameras)
		if(!C.can_use())
			continue

		var/list/tempnetwork = difflist(C.network,RESTRICTED_CAMERA_NETWORKS,1)
		if(tempnetwork.len)
			for(var/i in tempnetwork)
				cameralist[i] = i
	var/old_network = network
	network = input(U, "Which network would you like to view?") as null|anything in cameralist

	if(!U.eyeobj)
		U.view_core()
		return

	if(isnull(network))
		network = old_network // If nothing is selected
	else
		for(var/obj/machinery/camera/C in cameranet.cameras)
			if(!C.can_use())
				continue
			if(network in C.network)
				U.eyeobj.forceMove(get_turf(C))
				break
		to_chat(src, "<span class='notice'>Switched to [network] camera network.</span>")
//End of code by Mord_Sith

/mob/living/silicon/ai/proc/ai_statuschange()
	set category = "AI Commands"
	set name = "AI Status"

	if(usr.isDead())
		to_chat(usr, "You cannot change your emotional status because you are dead!")
		return

	var/emote = input("Please, select a status!", "AI Status", null, null) in ai_emotions //ai_emotions can be found in code/game/machinery/status_display.dm @ 213 (above the AI status display)

	for (var/obj/machinery/M in status_displays) //change status
		if(istype(M, /obj/machinery/ai_status_display))
			var/obj/machinery/ai_status_display/AISD = M
			AISD.emotion = emote
		//if Friend Computer, change ALL displays
		else if(istype(M, /obj/machinery/status_display))

			var/obj/machinery/status_display/SD = M
			if(emote=="Friend Computer")
				SD.friendc = TRUE
			else
				SD.friendc = FALSE
	return

//I am the icon meister. Bow fefore me.	//>fefore
/mob/living/silicon/ai/proc/ai_hologram_change()
	set name = "Change Hologram"
	set desc = "Change the default hologram available to AI to something else."
	set category = "AI Commands"

	var/input
	if(alert("Would you like to select a hologram based on a crew member or switch to unique avatar?",,"Crew Member","Unique")=="Crew Member")

		var/personnel_list[] = list()

		for(var/datum/data/record/t in data_core.locked)//Look in data core locked.
			personnel_list["[t.fields["name"]]: [t.fields["rank"]]"] = t.fields["image"]//Pull names, rank, and image.

		if(personnel_list.len)
			input = input("Select a crew member:") as null|anything in personnel_list
			var/icon/character_icon = personnel_list[input]
			if(character_icon)
				qdel(holo_icon)//Clear old icon so we're not storing it in memory.
				holo_icon = getHologramIcon(icon(character_icon))
		else
			alert("No suitable records found. Aborting.")

	else
		var/icon_list[] = list(
		"Default",
		"343",
		"Auto",
		"Boy",
		"Beach Ball",
		"Corgi",
		"Cortano",
		"Floating face",
		"Four-Leaf",
		"Girl",
		"Mothman",
		"SHODAN",
		"Spoopy",
		"Yotsuba",
		"Xenomorph",
		"Gondola",
		"Cat",
		"Hornets"
		)
		input = input("Please select a hologram:") as null|anything in icon_list
		if(input)
			QDEL_NULL(holo_icon)
			switch(input)
				if("Default")
					holo_icon = getHologramIcon(icon('icons/mob/AI.dmi',"holo1"))
				if("Floating face")
					holo_icon = getHologramIcon(icon('icons/mob/AI.dmi',"holo2"))
				if("Cortano")
					holo_icon = getHologramIcon(icon('icons/mob/AI.dmi',"holo3"))
				if("Spoopy")
					holo_icon = getHologramIcon(icon('icons/mob/AI.dmi',"holo4"))
				if("343")
					holo_icon = getHologramIcon(icon('icons/mob/AI.dmi',"holo5"))
				if("Auto")
					holo_icon = getHologramIcon(icon('icons/mob/AI.dmi',"holo6"))
				if("Four-Leaf")
					holo_icon = getHologramIcon(icon('icons/mob/AI.dmi',"holo7"))
				if("Yotsuba")
					holo_icon = getHologramIcon(icon('icons/mob/AI.dmi',"holo8"))
				if("Girl")
					holo_icon = getHologramIcon(icon('icons/mob/AI.dmi',"holo9"))
				if("Boy")
					holo_icon = getHologramIcon(icon('icons/mob/AI.dmi',"holo10"))
				if("SHODAN")
					holo_icon = getHologramIcon(icon('icons/mob/AI.dmi',"holo11"))
				if("Corgi")
					holo_icon = getHologramIcon(icon('icons/mob/AI.dmi',"holo12"))
				if("Mothman")
					holo_icon = getHologramIcon(icon('icons/mob/AI.dmi',"holo13"))
				if("Beach Ball")
					holo_icon = getHologramIcon(icon('icons/mob/AI.dmi',"beachball"))
				if("Xenomorph")
					holo_icon = getHologramIcon(icon('icons/mob/AI.dmi',"holo15"))
				if("Gondola")
					holo_icon = getHologramIcon(icon('icons/mob/AI.dmi',"holo16"))
				if("Cat")
					holo_icon = getHologramIcon(icon('icons/mob/AI.dmi',"holo17"))
				if("Hornets")
					holo_icon = getHologramIcon(icon('icons/mob/AI.dmi',"holo18"))

	return

//Toggles the luminosity and applies it by re-entereing the camera.
/mob/living/silicon/ai/verb/toggle_camera_light()
	set name = "Toggle Camera Light"
	set desc = "Toggle internal infrared camera light"
	set category = "AI Commands"
	if(stat != CONSCIOUS)
		return

	camera_light_on = !camera_light_on

	if(!camera_light_on)
		to_chat(src, "Camera lights deactivated.")

		for (var/obj/machinery/camera/C in lit_cameras)
			C.set_light(FALSE)
			lit_cameras = list()

		return

	light_cameras()

	to_chat(src, "Camera lights activated.")
	return

/mob/living/silicon/ai/verb/toggle_ai_mentions()
	set name = "Toggle AI Mentions"
	set desc = "Toggles highlighting and beeping on AI mentions"
	set category = "AI Commands"
	if(isUnconscious())
		return

	mentions_on = !mentions_on

	if(!mentions_on)
		to_chat(src, "AI mentions deactivated.")
	else
		to_chat(src, "AI mentions activated.")


/mob/living/silicon/ai/verb/toggle_station_map()
	set name = "Toggle Station Holomap"
	set desc = "Toggle station holomap on your screen"
	set category = "AI Commands"
	if(isUnconscious())
		return

	station_holomap.toggleHolomap(src,1)

//AI_CAMERA_LUMINOSITY

/mob/living/silicon/ai/proc/light_cameras()
	var/list/obj/machinery/camera/add = list()
	var/list/obj/machinery/camera/remove = list()
	var/list/obj/machinery/camera/visible = list()
	for (var/datum/camerachunk/CC in eyeobj.visibleCameraChunks)
		for (var/obj/machinery/camera/C in CC.cameras)
			if(!C.can_use() || C.light_disabled || get_dist(C, eyeobj) > 7)
				continue
			visible |= C

	add = visible - lit_cameras
	remove = lit_cameras - visible

	for (var/obj/machinery/camera/C in remove)
		C.set_light(FALSE)
		lit_cameras -= C
	for (var/obj/machinery/camera/C in add)
		C.set_light(AI_CAMERA_LUMINOSITY)
		lit_cameras |= C


/mob/living/silicon/ai/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if(W.is_wrench(user))
		if(anchored)
			user.visible_message("<span class='notice'>\The [user] starts to unbolt \the [src] from the plating...</span>")
			if(!do_after(user, src,40))
				user.visible_message("<span class='notice'>\The [user] decides not to unbolt \the [src].</span>")
				return
			user.visible_message("<span class='notice'>\The [user] finishes unfastening \the [src]!</span>")
			anchored = FALSE
			return
		else
			user.visible_message("<span class='notice'>\The [user] starts to bolt \the [src] to the plating...</span>")
			if(!do_after(user, src,40))
				user.visible_message("<span class='notice'>\The [user] decides not to bolt \the [src].</span>")
				return
			user.visible_message("<span class='notice'>\The [user] finishes fastening down \the [src]!</span>")
			anchored = TRUE
			return
	else
		return ..()

/mob/living/silicon/ai/attack_hand(mob/user)
	..()
	var/mob/living/living_user = user
	if(!istype(living_user))
		return
	if(living_user.a_intent == I_HURT)
		living_user.unarmed_attack_mob(src)
	else
		living_user.visible_message(
			"<span class='notice'>[living_user] pats [src].</span>",
			"<span class='notice'>You pat [src].</span>")


/mob/living/silicon/ai/get_multitool(var/active_only=0)
	return aiMulti

// An AI doesn't become inoperable until -100% (or whatever config.health_threshold_dead is set to)
/mob/living/silicon/ai/system_integrity()
	return (health - config.health_threshold_dead) / 2

/mob/living/silicon/ai/html_mob_check()
	return TRUE

/mob/living/silicon/ai/isTeleViewing(var/client_eye)
	return TRUE

/mob/living/silicon/ai/update_icon()
	if(stat == DEAD)
		if("[chosen_core_icon_state]-crash" in icon_states(src.icon,1))
			icon_state = "[chosen_core_icon_state]-crash"
		else
			icon_state = "ai-crash"
		return
	icon_state = chosen_core_icon_state

/mob/living/silicon/ai/update_perception()
	if(ai_flags & HIGHRESCAMS)
		client?.darkness_planemaster.alpha = 150
	else
		client?.darkness_planemaster.alpha = 255

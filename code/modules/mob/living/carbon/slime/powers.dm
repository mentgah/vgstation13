/mob/living/carbon/slime/verb/Feed()
	set category = "Slime"
	set desc = "This will let you feed on any valid creature in the surrounding area. This should also be used to halt the feeding process."
	if(Victim)
		Feedstop()
		return

	if(stat)
		to_chat(src, "<i>I must be conscious to do this...</i>")
		return

	var/list/choices = list()
	for(var/mob/living/C in view(1,src))
		if(C!=src && !istype(C,/mob/living/carbon/slime))
			choices += C
	var/mob/living/carbon/M
	if (choices.len)
		M = choices[1]
		if (choices.len > 1)
			M = input(src,"Who do you wish to feed on?") in null|choices
	if(!M)
		return
	if(M in view(1, src))

		if(!istype(src, /mob/living/carbon/brain))
			if(!istype(M, /mob/living/carbon/slime))
				if(stat != 2)
					if(health > -70)

						for(var/mob/living/carbon/slime/met in view())
							if(met.Victim == M && met != src)
								to_chat(src, "<i>The [met.name] is already feeding on this subject...</i>")
								return
						to_chat(src, "<span class='notice'><i>I have latched onto the subject and begun feeding...</i></span>")
						to_chat(M, "<span class='danger'>The [src.name] has latched onto your head!</span>")
						Feedon(M)
						add_attacklogs(src, M, "feeds on")

					else
						to_chat(src, "<i>This subject does not have a strong enough life energy...</i>")
				else
					to_chat(src, "<i>This subject does not have an edible life energy...</i>")
			else
				to_chat(src, "<i>I must not feed on my brothers...</i>")
		else
			to_chat(src, "<i>This subject does not have an edible life energy...</i>")



/mob/living/carbon/slime/proc/Feedon(var/mob/living/carbon/M)
	Victim = M
	src.forceMove(M.loc)
	canmove = 0
	anchored = 1
	var/lastnut = nutrition
//	to_chat(if(M.client) M, "<span class='warning'>You legs become paralyzed!</span>")
	icon_state = "[colour] [lifestage_name()] slime eat"
	add_logs(src, Victim, "fed on", 0)
	while(Victim && M.health > -70 && stat != 2)
		// M.canmove = 0
		canmove = 0

		if(M in view(1, src))
			loc = M.loc

			if(istype(M, /mob/living/carbon))
				var/bioprotectdivisor = istype(M.get_item_by_slot(slot_wear_suit), /obj/item/clothing/suit/bio_suit/scientist) ? 2 : 1
				if(prob(15 / bioprotectdivisor) && M.client)
					to_chat(M, "<span class='warning'>[pick("You can feel your body becoming weak!", \
					"You feel like you're about to die!", \
					"You feel every part of your body screaming in agony!", \
					"A low, rolling pain passes through your body!", \
					"Your body feels as if it's falling apart!", \
					"You feel extremely weak!", \
					"A sharp, deep pain bathes every inch of your body!")]</span>")

				Victim.adjustCloneLoss(rand(1,10/bioprotectdivisor))
				Victim.adjustToxLoss(rand(1,2/bioprotectdivisor))
				if(Victim.health <= 0)
					Victim.adjustToxLoss(rand(2/bioprotectdivisor,4/bioprotectdivisor))

				// Heal yourself
				var/healrate = 10 / bioprotectdivisor
				adjustToxLoss(-healrate)
				adjustOxyLoss(-healrate)
				adjustBruteLoss(-healrate)
				adjustFireLoss(-healrate)
				adjustCloneLoss(-healrate)

				if(Victim)
					for(var/mob/living/carbon/slime/slime in view(1,M))
						if(slime.Victim == M && slime != src)
							slime.Feedstop()

				nutrition += rand(10/bioprotectdivisor,25/bioprotectdivisor)
				if(nutrition >= lastnut + 50)
					if(prob(80))
						lastnut = nutrition
						powerlevel++
						if(powerlevel > 10)
							powerlevel = 10

				if(nutrition > 1200)
					nutrition = 1200

				Victim.updatehealth()
				updatehealth()

			else
				if(prob(25))
					to_chat(src, "<span class='warning'>[pick("I am not satisified",\
					"I can not feed from this subject","I do not feel nourished",\
					"This subject is incompatable","This subject does not have a life energy",\
					"This subject is empty","This subject is not food")]...</span>")

			sleep(rand(15,45))

		else
			break

	if(stat == 2)
		if(slime_lifestage != SLIME_ADULT)
			icon_state = "[colour] baby slime dead"

	else
		icon_state = "[colour] [lifestage_name()] slime"

	canmove = 1
	anchored = 0

	if(M)
		if(M.health <= -70)
			M.canmove = 0
			if(!client)
				if(Victim && Victim.lastassailant && !attacked)
					var/mob/assail = Victim.lastassailant.get()
					if(istype(assail) && (assail != Victim) && assail.mind)
						if(prob(50))
							if(!(assail in Friends))
								Friends.Add(assail) // no idea why i was using the |= operator

			if(M.client && istype(src, /mob/living/carbon/human))
				if(prob(85))
					rabid() // UUUNNBGHHHH GONNA EAT JUUUUUU

			if(client)
				to_chat(src, "<i>This subject does not have a strong enough life energy anymore...</i>")
		else
			M.update_canmove()

			if(client)
				to_chat(src, "<i>I have stopped feeding...</i>")
	else
		if(client)
			to_chat(src, "<i>I have stopped feeding...</i>")

	Victim = null

/mob/living/carbon/slime/proc/Feedstop()
	if(Victim)
		if(Victim.client)
			to_chat(Victim, "[src] has let go of your head!")
		Victim = null

/mob/living/carbon/slime/proc/UpdateFeed(var/mob/M)
	if(Victim)
		if(Victim == M)
			loc = M.loc // simple "attach to head" effect!


/mob/living/carbon/slime/verb/Evolve()
	set category = "Slime"
	set desc = "This will let you evolve from baby to adult slime."

	if(stat)
		to_chat(src, "<i>I must be conscious to do this...</i>")
		return
	if(slime_lifestage != SLIME_ADULT)
		if(amount_grown >= 10)
			if(istype(src, /mob/living/carbon/slime/pygmy))
				var/mob/living/carbon/human/slime/S = new (loc)
				if(mind)
					mind.transfer_to(S)
				else
					S.key = key
				transferImplantsTo(S)
				transferBorers(S)
				qdel(src)
				var/i
				while(!i)
					var/randomname = S.species.makeName()
					if(findname(randomname))
						continue
					else
						S.real_name = randomname
						i++
				return
			var/mob/living/carbon/slime/new_slime = new adulttype(loc)
			new_slime.nutrition = nutrition
			new_slime.powerlevel = max(0, powerlevel-1)
			new_slime.a_intent = I_HURT
			if(src.mind)
				src.mind.transfer_to(new_slime)
			else
				new_slime.key = src.key
			attack_log += text("\[[time_stamp()]\] <font color='black'>Evolved to an adult slime at x=[x],y=[y],z=[z]!</font>")
			new_slime.languages = languages.Copy()
			new_slime.name = src.name
			new_slime.real_name = src.real_name
			new_slime.attack_log = attack_log
			transferImplantsTo(new_slime)
			transferBorers(new_slime)

			to_chat(new_slime, "<B>You are now an adult slime.</B>")
			qdel(src)
		else
			to_chat(src, "<i>I am not ready to evolve yet...</i>")
	else
		to_chat(src, "<i>I have already evolved...</i>")

/mob/living/carbon/slime/verb/Reproduce()
	set category = "Slime"
	set desc = "This will make you split into four Slimes. NOTE: this will KILL you, but you will be transferred into one of the babies."

	if(stat)
		to_chat(src, "<i>I must be conscious to do this...</i>")
		return

	if(slime_lifestage == SLIME_ADULT)
		if(amount_grown >= 10)
			//if(input("Are you absolutely sure you want to reproduce? Your current body will cease to be, but your consciousness will be transferred into a produced slime.") in list("Yes","No")=="Yes")
			if(stat)
				to_chat(src, "<i>I must be conscious to do this...</i>")
				return

			var/list/babies = list()
			var/new_nutrition = round(nutrition * 0.9)
			var/new_powerlevel = round(powerlevel / 4)
			for(var/i = 1 to 4)
				var/newslime
				switch(i)
					if(1 to 2)
						newslime = slime_mutation[rand(1,maxcolorcount)]
					if(3)
						newslime = primarytype
					if(4)
						newslime = slime_mutation[rand(1,(maxcolorcount-1))]

				var/mob/living/carbon/slime/M = new newslime(loc)
				M.nutrition = new_nutrition
				M.powerlevel = new_powerlevel
				if(i != 1)
					step_away(M,src)
				babies += M
				feedback_add_details("slime_babies_born","slimebirth_[replacetext(M.colour," ","_")]")

			var/mob/living/carbon/slime/new_slime = pick(babies)
			new_slime.a_intent = I_HURT
			new_slime.languages = languages.Copy()
			new_slime.name = src.name
			attack_log += text("\[[time_stamp()]\] <font color='black'>Reproduced to make more slimes at x=[x],y=[y],z=[z]!</font>")
			new_slime.real_name = src.real_name
			new_slime.attack_log = attack_log
			if(src.mind)
				src.mind.transfer_to(new_slime)
			else
				new_slime.key = src.key
			transferImplantsTo(new_slime)
			transferBorers(new_slime)

			to_chat(new_slime, "<B>You are now a slime!</B>")
			qdel(src)
		else
			to_chat(src, "<i>I am not ready to reproduce yet...</i>")
	else
		to_chat(src, "<i>I am not old enough to reproduce yet...</i>")

/mob/living/carbon/slime/verb/ventcrawl()
	set name = "Crawl through Vent"
	set desc = "Enter an air vent and crawl through the pipe system."
	set category = "Object"
	if(Victim)
		return
	var/pipe = start_ventcrawl()
	if(pipe && !Victim)
		handle_ventcrawl(pipe)

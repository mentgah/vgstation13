/mob/living/carbon/human/gib(animation = FALSE, meat = TRUE)
	ASSERT(species)
	species.gib(src, animation, meat)

/* This will be called if the species datum has not overwritten /datum/species/gib() */
/mob/living/carbon/human/proc/default_gib(animation, meat)
	death(1)
	handle_body_destroyed()

	for(var/datum/organ/external/E in src.organs)
		if(istype(E, /datum/organ/external/chest) || istype(E, /datum/organ/external/groin)) //Really bad stuff happens when either get removed
			continue
		//Only make the limb drop if it's not too damaged, or if it's the head
		if(prob(100 - E.get_damage()) || istype(E, /datum/organ/external/head))
			//Override the current limb status and don't cause an explosion
			E.droplimb(1, 1)
	for(var/datum/organ/external/cosmetic_organ in cosmetic_organs)
		cosmetic_organ.droplimb(TRUE, TRUE)
	var/gib_radius = 0
	if(reagents.has_reagent(LUBE))
		gib_radius = 6 //Your insides are all lubed, so gibs travel much further

	anim(target = src, a_icon = 'icons/mob/mob.dmi', flick_anim = "gibbed-h", sleeptime = 15)
	hgibs(loc, virus2, dna, species.flesh_color, species.blood_color, gib_radius)
	spawn()
		qdel(src)

/mob/living/carbon/human/dust(var/drop_everything = FALSE)
	ASSERT(species)
	species.dust(src, drop_everything)

/* This will be called if the species datum has not overwritten /datum/species/dust() */
/mob/living/carbon/human/proc/default_dust(drop_everything)
	death(1)
	handle_body_destroyed()

	if(istype(src, /mob/living/carbon/human/manifested))
		anim(target = src, a_icon = 'icons/mob/mob.dmi', flick_anim = "dust-hm", sleeptime = 15)
	else
		anim(target = src, a_icon = 'icons/mob/mob.dmi', flick_anim = "dust-h", sleeptime = 15)

	var/datum/organ/external/head_organ = get_organ(LIMB_HEAD)
	if(head_organ.status & ORGAN_DESTROYED)
		new /obj/effect/decal/remains/human/noskull(loc)
	else
		new /obj/effect/decal/remains/human(loc)
	if(drop_everything)
		drop_all()
	spawn()
		qdel(src)

/mob/living/carbon/human/proc/handle_body_destroyed()
	monkeyizing = TRUE
	canmove = 0
	icon = null
	invisibility = 101
	dropBorers(1)

/mob/living/carbon/human/Destroy()
	infected_contact_mobs -= src
	if (pathogen)
		for (var/mob/L in science_goggles_wearers)
			if (L.client)
				L.client.images -= pathogen
		pathogen = null

	if(client && iscultist(src) && (timeofdeath == 0 || timeofdeath >= world.time - DEATH_SHADEOUT_TIMER))
		var/turf/T = get_turf(src)
		if (T)
			var/mob/living/simple_animal/shade/shade = new (T)
			playsound(T, 'sound/hallucinations/growl1.ogg', 50, 1)
			shade.name = "[real_name] the Shade"
			shade.real_name = "[real_name]"
			mind.transfer_to(shade)
			update_faction_icons()
			to_chat(shade, "<span class='sinister'>Dark energies rip your dying body appart, anchoring your soul inside the form of a Shade. You retain your memories, and devotion to the cult.</span>")

	if(species)
		QDEL_NULL(species)

	if(vessel)
		QDEL_NULL(vessel)

	my_appearance = null

	..()

/mob/living/carbon/human/death(gibbed)
	if((status_flags & BUDDHAMODE) || stat == DEAD)
		return
	if(healths)
		healths.icon_state = "health7"
	dizziness = 0
	remove_jitter()

	//If we have brain worms, dump 'em.
	var/mob/living/simple_animal/borer/B=has_brain_worms()
	if(B && B.controlling)
		to_chat(src, "<span class='danger'>Your host has died.  You reluctantly release control.</span>")
		to_chat(B.host_brain, "<span class='danger'>Just before your body passes, you feel a brief return of sensation.  You are now in control...  And dead.</span>")
		do_release_control(0)

	if(lastassailant)
		var/mob/living/carbon/human/A=lastassailant.get()
		if(istype(A))
			//Check if last assailant is a vox raider.
			//if (isvoxraider(A))
				//Not currently feasible due to terrible lastassailant tracking, and the inviolate not even being a thing anymore.
				//vox_kills++ //Bad vox. Shouldn't be killing humans.
				//to_chat(world, "Vox kills: [vox_kills]")
			if(A.mind)
				A.mind.kills += "[name] ([ckey])"

	if(!gibbed)
		update_canmove()
	stat = DEAD
	tod = worldtime2text()
	if(mind)
		mind.store_memory("Time of death: [tod]", category=MIND_MEMORY_GENERAL, forced=TRUE)
		if(!(mind && mind.suiciding)) //Cowards don't count
			score.deadcrew++
	if (dorfpod)
		dorfpod.scan_body(src)
	if(ticker && ticker.mode)
		sql_report_death(src)
	species.handle_death(src, gibbed)
	if(become_zombie)
		spawn(20 SECONDS)
			if(!gcDestroyed)
				zombify()
	return ..(gibbed)

/mob/living/carbon/human/proc/makeSkeleton()
	if(M_SKELETON in src.mutations)
		return

	if(my_appearance.f_style)
		my_appearance.f_style = "Shaved"
	if(my_appearance.h_style)
		my_appearance.h_style = "Bald"
	update_hair(0)

	mutations.Add(M_SKELETON)
	var/datum/organ/external/head/head_organ = get_organ(LIMB_HEAD)
	head_organ.disfigure("burn")
	update_body(0)
	update_mutantrace()
	return

/mob/living/carbon/human/proc/ChangeToHusk()
	if(M_HUSK in mutations)
		return
	if(my_appearance.f_style)
		my_appearance.f_style = "Shaved" //We only change the icon_state of the hair datum, so it doesn't mess up their UI/UE
	if(my_appearance.h_style)
		my_appearance.h_style = "Bald"
	update_hair(0)

	mutations.Add(M_HUSK)
	var/datum/organ/external/head/head_organ = get_organ(LIMB_HEAD)
	head_organ.disfigure("brute")
	update_body(0)
	update_mutantrace()
	vessel.remove_reagent(BLOOD,vessel.get_reagent_amount(BLOOD))
	return

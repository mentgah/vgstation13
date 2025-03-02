//trees
/obj/structure/flora
	name = "flora"
	var/icon/clicked //Because BYOND can't give us runtime icon access, this is basically just a click catcher
	var/shovelaway = FALSE
	var/pollen = null
	var/plantname = null

/obj/structure/flora/New()
	..()
	update_icon()

/obj/structure/flora/update_icon()
	clicked = new/icon(src.icon, src.icon_state, src.dir)

/obj/structure/flora/attackby(var/obj/item/I, var/mob/user, params)
	if(shovelaway && isshovel(I))
		to_chat(user,"<span class='notice'>You clear away \the [src].</span>")
		playsound(loc, 'sound/items/shovel.ogg', 50, 1)
		qdel(src)
		return 1
//	if(istype(I, /obj/item/ornament))
//		hang_ornament(I, user, params)
//		return 1
	..()

/obj/structure/flora/proc/hang_ornament(var/obj/item/I, var/mob/user, params)
	var/list/params_list = params2list(params)
	if(!istype(I, /obj/item/ornament))
		return
	if(istype(I, /obj/item/ornament/topper))
		for(var/i = 1 to contents.len)
			if(istype(contents[i], /obj/item/ornament/topper))
				to_chat(user, "Having more than one topper on a tree would look silly!")
				return
	if(user.drop_item(I, src))
		if(I.loc == src && params_list.len)
			var/image/O
			if(istype(I, /obj/item/ornament/teardrop))
				O = image('icons/obj/teardrop_ornaments.dmi', src, "[I.icon_state]_small")
			else
				O = image('icons/obj/ball_ornaments.dmi', src, "[I.icon_state]_small")

			var/clamp_x = clicked.Width() / 2
			var/clamp_y = clicked.Height() / 2
			O.pixel_x = clamp(text2num(params_list["icon-x"]) - clamp_x, -clamp_x, clamp_x)+(((((clicked.Width()/32)-1)*16)*PIXEL_MULTIPLIER))
			O.pixel_y = (clamp(text2num(params_list["icon-y"]) - clamp_y, -clamp_y, clamp_y)+((((clicked.Height()/32)-1)*16)*PIXEL_MULTIPLIER))-(5*PIXEL_MULTIPLIER)
			overlays += O
			to_chat(user, "You hang \the [I] on \the [src].")
			return 1

/obj/structure/flora/attack_hand(mob/user)
	if(contents.len)
		var/count = contents.len
		var/obj/item/I = contents[count]
		while(!istype(I, /obj/item/ornament))
			count--
			if(count < 1)
				return
			I = contents[count]
		user.visible_message("<span class='notice'>[user] plucks \the [I] off \the [src].</span>", "You take \the [I] off \the [src].")
		I.forceMove(loc)
		user.put_in_active_hand(I)
		overlays -= overlays[overlays.len]

/obj/structure/flora/wind_act(var/differential, var/list/connecting_turfs)
	if (!pollen)
		return
	var/turf/T = get_turf(src)
	var/turf/U = get_step(T,get_dir(T,pick(connecting_turfs)))
	var/log_differential = log(abs(differential) * 3)
	if (U)
		if (differential > 0)
			T.flying_pollen(U,log_differential, pollen)
		else
			T.flying_pollen(U,-log_differential, pollen)
		T.adjust_particles(PVAR_SPAWNING, 0.5, pollen)
	spawn(10)
		for (var/obj/machinery/portable_atmospherics/hydroponics/other_tray in U)//TODO: have it work on grass
			if (!other_tray.seed)
				other_tray.seed = SSplant.seeds[plantname]
				other_tray.add_planthealth(other_tray.seed.endurance)
				other_tray.lastcycle = world.time
				other_tray.weedlevel = 0
				other_tray.update_icon()

/obj/structure/flora/tree
	name = "tree"
	anchored = 1
	density = 1

	layer = FLY_LAYER
	plane = ABOVE_HUMAN_PLANE
	icon = 'icons/obj/flora/deadtrees.dmi'
	icon_state = "tree_1"

	pixel_x = -WORLD_ICON_SIZE/2

	health = 100
	maxHealth = 100

	var/height = 6 //How many logs are spawned


	var/falling_dir = 0 //Direction in which spawned logs are thrown.

	var/randomize_on_creation = 1
	var/const/log_type = /obj/item/weapon/grown/log/tree
	var/holo = FALSE
	var/image/transparent

/obj/structure/flora/tree/New()
	..()

	if(randomize_on_creation)
		health = rand(60, 200)
		maxHealth = health

		height = rand(3, 8)

		icon_state = pick(
		"tree_1",
		"tree_2",
		"tree_3",
		"tree_4",
		"tree_5",
		"tree_6",
		)


	//Trees Z-fight due to being bigger than one tile, so we need to perform serious layer fuckery to hide this obvious defect)

	var/rangevalue = 0.1 //Range over which the values spread. We don't want it to collide with "true" layer differences

	layer += rangevalue * (1 - (y + 0.5 * (x & 1)) / world.maxy)

	update_transparency()

	for(var/turf/T in circlerange(src,2))
		if(T.y > y)
			T.register_event(/event/entered, src, nameof(src::give_transparency()))
			T.register_event(/event/exited, src, nameof(src::remove_transparency()))


/obj/structure/flora/tree/Destroy()
	for(var/turf/T in circlerange(src,2))
		if(T.y > y)
			T.unregister_event(/event/entered, src, nameof(src::give_transparency()))
			T.unregister_event(/event/exited, src, nameof(src::remove_transparency()))
	..()

/obj/structure/flora/tree/proc/update_transparency()
	transparent = image(icon,src,icon_state)
	transparent.color = "[color ? color : "#FFFFFF"]"+"7F"
	transparent.override = TRUE

/obj/structure/flora/tree/proc/give_transparency(mover, location, oldloc)
	if(!ismob(mover))
		return
	var/mob/M = mover
	if(!M.client)
		return
	var/client/C = M.client
	C.images += transparent

/obj/structure/flora/tree/proc/remove_transparency(mover, location, newloc)
	if(!ismob(mover))
		return
	var/mob/M = mover
	if(!M.client)
		return
	var/client/C = M.client
	C.images -= transparent

/obj/structure/flora/tree/examine(mob/user)
	.=..()

	//Tell user about the height. Note that normally height ranges from 3 to 8 (with a 5% chance of having 6 to 15 instead)
	to_chat(user, "<span class='info'>It appears to be about [height*3] feet tall.</span>")
	switch(health / maxHealth)
		if(0.6 to 0.9)
			to_chat(user, "<span class='info'>It's been partially cut down.</span>")
		if(0.2 to 0.6)
			to_chat(user, "<span class='notice'>It's almost cut down, [falling_dir ? "and it's leaning towards the [dir2text(falling_dir)]." : "but it still stands upright."]</span>")
		if(0 to 0.2)
			to_chat(user, "<span class='danger'>It's going to fall down any minute now!</span>")

/obj/structure/flora/tree/attackby(obj/item/W, mob/living/user)
	..()

	if(istype(W, /obj/item))
		if(W.sharpness_flags & (CHOPWOOD|SERRATED_BLADE))
			health -= (user.get_strength() * W.force)
			playsound(loc, 'sound/effects/woodcuttingshort.ogg', 50, 1)
		else
			to_chat(user, "<span class='info'>\The [W] doesn't appear to be suitable to cut into \the [src]. Try something sturdier.</span>")

	update_health()

	return 1

/obj/structure/flora/tree/proc/fall_down()
	if(!falling_dir)
		falling_dir = pick(cardinal)

	var/turf/our_turf = get_turf(src) //Turf at which this tree is located
	var/turf/current_turf = get_turf(src) //Turf in which to spawn a log. Updated in the loop

	playsound(loc, 'sound/effects/woodcutting.ogg', 50, 1)

	qdel(src)

	if(!holo)
		spawn()
			while(height > 0)
				if(!current_turf)
					break //If the turf in which to spawn a log doesn't exist, stop the thing

				var/obj/item/I = new log_type(our_turf) //Spawn a log and throw it at the "current_turf"
				I.throw_at(current_turf, 10, 10)

				current_turf = get_step(current_turf, falling_dir)

				height--

				sleep(1)

/obj/structure/flora/tree/proc/update_health()
	if(health < 40 && !falling_dir)
		falling_dir = pick(cardinal)
		visible_message("<span class='danger'>\The [src] starts leaning to the [dir2text(falling_dir)]!</span>",
			drugged_message = "<span class='sinister'>\The [src] is coming to life, man.</span>")

	if(health <= 0)
		fall_down()

/obj/structure/flora/tree/ex_act(severity)
	switch(severity)
		if(1) //Epicentre
			return qdel(src)
		if(2) //Major devastation
			height -= rand(1,4) //Some logs are lost
			fall_down()
		if(3) //Minor devastation (IED)
			health -= rand(10,30)
			update_health()

/obj/structure/flora/tree/pine
	name = "pine tree"
	icon = 'icons/obj/flora/pinetrees.dmi'
	icon_state = "pine_1"

/obj/structure/flora/tree/pine/New()
	..()
	icon_state = "pine_[rand(1, 3)]"
	update_transparency()

/obj/structure/flora/tree/pine/xmas
	name = "xmas tree"
	icon = 'icons/obj/flora/pinetrees.dmi'
	icon_state = "pine_c"

/obj/structure/flora/tree/pine/xmas/holo
	holo = TRUE

/obj/structure/flora/tree/pine/xmas/New()
	..()
	icon_state = "pine_c"
	update_transparency()


/obj/structure/flora/tree/dead
	name = "dead tree"
	icon = 'icons/obj/flora/deadtrees.dmi'
	icon_state = "tree_1"

/obj/structure/flora/tree/dead/holo
	holo = TRUE

/obj/structure/flora/tree/dead/New()
	..()
	icon_state = "tree_[rand(1, 6)]"
	update_transparency()

/obj/structure/flora/tree_stump
	name = "tree stump"
	icon = 'icons/obj/flora/pinetrees.dmi'
	icon_state = "pine_stump"
	shovelaway = TRUE

//grass
/obj/structure/flora/grass
	name = "grass"
	icon = 'icons/obj/flora/snowflora.dmi'
	anchored = 1
	shovelaway = TRUE

/obj/structure/flora/grass/brown
	icon_state = "snowgrass1bb"

/obj/structure/flora/grass/brown/New()
	..()
	icon_state = "snowgrass[rand(1, 3)]bb"


/obj/structure/flora/grass/green
	icon_state = "snowgrass1gb"

/obj/structure/flora/grass/green/New()
	..()
	icon_state = "snowgrass[rand(1, 3)]gb"

/obj/structure/flora/grass/both
	icon_state = "snowgrassall1"

/obj/structure/flora/grass/both/New()
	..()
	icon_state = "snowgrassall[rand(1, 3)]"

/obj/structure/flora/grass/white
	icon_state = "snowgrass3"

/obj/structure/flora/grass/white/New()
	..()
	icon_state = "snowgrass_[rand(1, 6)]"

//bushes
/obj/structure/flora/bush
	name = "bush"
	desc = "It's amazing what can grow out here."
	icon = 'icons/obj/flora/snowflora.dmi'
	icon_state = "snowbush1"
	anchored = 1
	shovelaway = TRUE

/obj/structure/flora/bush/New()
	..()
	icon_state = "snowbush[rand(1, 6)]"

/obj/structure/flora/pottedplant
	name = "potted plant"
	desc = "Oh, no. Not again."
	icon = 'icons/obj/plants.dmi'
	icon_state = "plant-26"
	plane = ABOVE_HUMAN_PLANE
	layer = POTTED_PLANT_LAYER

/obj/structure/flora/pottedplant/Destroy()
	for(var/I in contents)
		qdel(I)

	return ..()

/obj/structure/flora/pottedplant/attackby(var/obj/item/I, var/mob/user, params)
	if(!I)
		return
	if(I.w_class > W_CLASS_SMALL)
		to_chat(user, "That item is too big.")
		return
	if(contents.len)
		var/filled = FALSE
		for(var/i = 1, i <= contents.len, i++)
			if(!istype(contents[i], /obj/item/ornament))
				filled = TRUE
		if(filled)
			to_chat(user, "There is already something in the pot.")
			playsound(loc, "sound/effects/plant_rustle.ogg", 50, 1, -1)
			return
	if(user.drop_item(I, src))
		user.visible_message("<span class='notice'>[user] stuffs something into the pot.</span>", "You stuff \the [I] into the [src].")
		playsound(loc, "sound/effects/plant_rustle.ogg", 50, 1, -1)
		if(arcanetampered)
			var/area/thearea
			var/area/prospective = pick(areas)
			while(!thearea)
				if(prospective.type != /area)
					var/turf/T = pick(get_area_turfs(prospective.type))
					if(T.z == user.z)
						thearea = prospective
						break
				prospective = pick(areas)
			var/list/L = list()
			for(var/turf/T in get_area_turfs(thearea.type))
				if(!T.density)
					var/clear = 1
					for(var/obj/O in T)
						if(O.density)
							clear = 0
							break
					if(clear)
						L+=T
			if(!L.len)
				return

			var/list/backup_L = L
			var/attempt = null
			var/success = 0
			while(L.len)
				attempt = pick(L)
				success = I.Move(attempt)
				if(!success)
					L.Remove(attempt)
				else
					break
			if(!success)
				I.forceMove(pick(backup_L))

/obj/structure/flora/pottedplant/attack_hand(mob/user)
	if(contents.len)
		var/count = 1
		var/obj/item/I = contents[count]
		while(istype(I, /obj/item/ornament))
			count++
			if(count > contents.len)	//pot is emptied of non-ornament items
				user.visible_message("<span class='notice'>[user] plucks \the [I] off \the [src].</span>", "You take \the [I] off \the [src].")
				playsound(loc, "sound/effects/plant_rustle.ogg", 50, 1, -1)
				I.forceMove(loc)
				user.put_in_active_hand(I)
				overlays -= overlays[overlays.len]
				return
			I = contents[count]
		user.visible_message("<span class='notice'>[user] retrieves something from the pot.</span>", "You retrieve \the [I] from the [src].")
		playsound(loc, "sound/effects/plant_rustle.ogg", 50, 1, -1)
		I.forceMove(loc)
		user.put_in_active_hand(I)
	else
		to_chat(user, "You root around in the roots. There isn't anything in there.")
		playsound(loc, "sound/effects/plant_rustle.ogg", 50, 1, -1)

/obj/structure/flora/pottedplant/attack_paw(mob/user)
	return attack_hand(user)

// /vg/
/obj/structure/flora/pottedplant/random/New()
	..()
	var/potted_plant_type = "[rand(1,26)]"
	icon_state = "plant-[potted_plant_type]"
	if (potted_plant_type in list("7","9","20"))
		update_moody_light_index("plant", icon, "[icon_state]-moody")

/obj/structure/flora/pottedplant/claypot
	name = "clay pot"
	desc = "Plants placed in those stop aging, but cannot be retrieved either."
	icon = 'icons/obj/hydroponics/hydro_tools.dmi'
	icon_state = "claypot"
	anchored = 0
	density = FALSE
	var/plant_name = ""
	var/image/plant_image = null
	var/list/paint_layers = list("paint-full" = null, "paint-rim" = null, "paint-stripe" = null)

/obj/structure/flora/pottedplant/claypot/examine(mob/user)
	..()
	if(plant_name)
		to_chat(user, "<span class='info'>You can see [plant_name] planted in it.</span>")

/obj/structure/flora/pottedplant/claypot/attackby(var/obj/item/O,var/mob/user)
	if(O.is_wrench(user))
		O.playtoolsound(loc, 50)
		if(do_after(user, src, 30))
			anchored = !anchored
			user.visible_message(	"<span class='notice'>[user] [anchored ? "wrench" : "unwrench"]es \the [src] [anchored ? "in place" : "from its fixture"].</span>",
									"<span class='notice'>[bicon(src)] You [anchored ? "wrench" : "unwrench"] \the [src] [anchored ? "in place" : "from its fixture"].</span>",
									"<span class='notice'>You hear a ratchet.</span>")
	else if(plant_name && isshovel(O))
		to_chat(user, "<span class='notice'>[bicon(src)] You start removing the [plant_name] from \the [src].</span>")
		if(do_after(user, src, 30))
			playsound(loc, 'sound/items/shovel.ogg', 50, 1)
			user.visible_message(	"<span class='notice'>[user] removes the [plant_name] from \the [src].</span>",
									"<span class='notice'>[bicon(src)] You remove the [plant_name] from \the [src].</span>",
									"<span class='notice'>You hear some digging.</span>")
			for(var/atom/movable/I in contents)
				I.forceMove(loc)
			var/obj/item/claypot/C = new(loc)
			transfer_fingerprints(src, C)
			C.paint_layers = paint_layers.Copy()
			C.update_icon()
			qdel(src)

	else if(istype(O,/obj/item/weapon/reagent_containers/food/snacks/grown) || istype(O,/obj/item/weapon/grown))
		to_chat(user, "<span class='warning'>There is already a plant in \the [src]</span>")

	else if(istype(O, /obj/item/painting_brush))
		var/obj/item/painting_brush/P = O
		if (P.paint_color)
			paint_act(P.paint_color,user, P.nano_paint != PAINTLIGHT_NONE)
		else
			to_chat(user, "<span class='warning'>There is no paint on \the [P].</span>")
		return 1
	else if(istype(O, /obj/item/paint_roller))
		var/obj/item/paint_roller/P = O
		if (P.paint_color)
			paint_act(P.paint_color,user, P.nano_paint != PAINTLIGHT_NONE)
		else
			to_chat(user, "<span class='warning'>There is no paint on \the [P].</span>")
		return 1

	else
		..()

/obj/structure/flora/pottedplant/claypot/proc/paint_act(var/_color, var/mob/user, var/nano_paint)
	var/list/choices = list("Full" = "paint-full", "Rim" = "paint-rim", "Stripe" = "paint-stripe")
	var/paint_target = input("Which part do you want to paint?","Clay Pot Painting",1) as null|anything in choices
	if (!paint_target)
		return
	switch(paint_target)
		if ("Full")
			to_chat(user, "<span class='notice'>You begin to cover the pot in paint.</span>")
		if ("Rim")
			to_chat(user, "<span class='notice'>You begin to paint the pot's rim.</span>")
		if ("Stripe")
			to_chat(user, "<span class='notice'>You begin to paint a stripe on the pot.</span>")
	playsound(loc, "mop", 10, 1)
	if (do_after(user, src, 20))
		if (_color == "#FFFFFF")
			_color = "#FEFEFE" //null color prevention
		if (paint_target == "Full")
			paint_layers["paint-rim"] = null
			paint_layers["paint-stripe"] = null
		paint_layers[choices[paint_target]]	= list(_color, nano_paint)
		update_icon()

/obj/structure/flora/pottedplant/claypot/update_icon()
	overlays.len = 0
	for (var/entry in paint_layers)
		if (!paint_layers[entry])
			kill_moody_light_index(entry)
		else
			var/list/paint_layer = paint_layers[entry]
			var/image/I = image(icon, src, "[icon_state]-[entry]")
			I.color = paint_layer[1]
			overlays += I
			if (paint_layer[2])
				update_moody_light_index(entry, image_override = I)
			else
				kill_moody_light_index(entry)
	overlays += plant_image
	if ("plant" in moody_lights)
		overlays += moody_lights["plant"]
	if (on_fire && fire_overlay)
		overlays += fire_overlay

//newbushes

/obj/structure/flora/ausbushes
	name = "bush"
	icon = 'icons/obj/flora/ausflora.dmi'
	icon_state = "firstbush_1"
	anchored = 1
	shovelaway = TRUE

/obj/structure/flora/ausbushes/New()
	..()
	icon_state = "firstbush_[rand(1, 4)]"

/obj/structure/flora/ausbushes/reedbush
	icon_state = "reedbush_1"

/obj/structure/flora/ausbushes/reedbush/New()
	..()
	icon_state = "reedbush_[rand(1, 4)]"

/obj/structure/flora/ausbushes/leafybush
	icon_state = "leafybush_1"

/obj/structure/flora/ausbushes/leafybush/New()
	..()
	icon_state = "leafybush_[rand(1, 3)]"

/obj/structure/flora/ausbushes/palebush
	icon_state = "palebush_1"

/obj/structure/flora/ausbushes/palebush/New()
	..()
	icon_state = "palebush_[rand(1, 4)]"

/obj/structure/flora/ausbushes/stalkybush
	icon_state = "stalkybush_1"

/obj/structure/flora/ausbushes/stalkybush/New()
	..()
	icon_state = "stalkybush_[rand(1, 3)]"

/obj/structure/flora/ausbushes/grassybush
	icon_state = "grassybush_1"

/obj/structure/flora/ausbushes/grassybush/New()
	..()
	icon_state = "grassybush_[rand(1, 4)]"

/obj/structure/flora/ausbushes/fernybush
	icon_state = "fernybush_1"

/obj/structure/flora/ausbushes/fernybush/New()
	..()
	icon_state = "fernybush_[rand(1, 3)]"

/obj/structure/flora/ausbushes/sunnybush
	icon_state = "sunnybush_1"

/obj/structure/flora/ausbushes/sunnybush/New()
	..()
	icon_state = "sunnybush_[rand(1, 3)]"

/obj/structure/flora/ausbushes/genericbush
	icon_state = "genericbush_1"

/obj/structure/flora/ausbushes/genericbush/New()
	..()
	icon_state = "genericbush_[rand(1, 4)]"

/obj/structure/flora/ausbushes/pointybush
	icon_state = "pointybush_1"

/obj/structure/flora/ausbushes/pointybush/New()
	..()
	icon_state = "pointybush_[rand(1, 4)]"

/obj/structure/flora/ausbushes/lavendergrass
	icon_state = "lavendergrass_1"

/obj/structure/flora/ausbushes/lavendergrass/New()
	..()
	icon_state = "lavendergrass_[rand(1, 4)]"

/obj/structure/flora/ausbushes/ywflowers
	icon_state = "ywflowers_1"

/obj/structure/flora/ausbushes/ywflowers/New()
	..()
	icon_state = "ywflowers_[rand(1, 3)]"

/obj/structure/flora/ausbushes/brflowers
	icon_state = "brflowers_1"

/obj/structure/flora/ausbushes/brflowers/New()
	..()
	icon_state = "brflowers_[rand(1, 3)]"

/obj/structure/flora/ausbushes/ppflowers
	icon_state = "ppflowers_1"

/obj/structure/flora/ausbushes/ppflowers/New()
	..()
	icon_state = "ppflowers_[rand(1, 4)]"

/obj/structure/flora/ausbushes/sparsegrass
	icon_state = "sparsegrass_1"

/obj/structure/flora/ausbushes/sparsegrass/New()
	..()
	icon_state = "sparsegrass_[rand(1, 3)]"

/obj/structure/flora/ausbushes/fullgrass
	icon_state = "fullgrass_1"

/obj/structure/flora/ausbushes/fullgrass/New()
	..()
	icon_state = "fullgrass_[rand(1, 3)]"

//a rock is flora according to where the icon file is
//and now these defines
/obj/structure/flora/rock
	name = "rock"
	desc = "A rock."
	icon_state = "rock1"
	icon = 'icons/obj/flora/rocks.dmi'
	anchored = 1
	shovelaway = TRUE

/obj/structure/flora/rock/New()
	..()
	icon_state = "rock[rand(1,5)]"

/obj/structure/flora/rock/pile
	name = "rocks"
	desc = "A bunch of small rocks."
	icon_state = "rockpile1"

/obj/structure/flora/rock/pile/New()
	..()
	icon_state = "rockpile[rand(1,5)]"

/obj/structure/flora/rock/pile/snow
	name = "rocks"
	desc = "A bunch of small rocks, these ones are covered in a thick frost layer."
	icon_state = "srockpile1"

/obj/structure/flora/rock/pile/snow/New()
	..()
	icon_state = "srockpile[rand(1,5)]"

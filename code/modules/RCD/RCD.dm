//Main class for the modular RCD system.
/obj/item/device/rcd
	name                = "\improper Rapid-Construction-Device (RCD)"
	desc                = "Used to rapidly construct things, or deconstruct them, for that matter."

	icon                = 'icons/obj/RCD.dmi'
	icon_state          = "rcd"

	flags               = FPRINT
	siemens_coefficient = 1
	w_class             = W_CLASS_MEDIUM
	force               = 10
	throwforce          = 10
	throw_speed         = 1
	throw_range         = 5
	starting_materials  = list(MAT_IRON = 75000, MAT_GLASS = 30000)
	w_type              = RECYK_ELECTRONIC
	melt_temperature    = MELTPOINT_STEEL // Lots of metal
	origin_tech         = Tc_ENGINEERING + "=4;" + Tc_MATERIALS + "=2"

	var/frequency = 0
	var/id = null

	//list of schematics, in definitions of RCD subtypes, no organization is needed, in New() these get organized.
	var/list/schematics = list(/datum/rcd_schematic/test)
	// Make sparks. LOTS OF SPARKS.
	var/sparky          = TRUE

	var/z_last_checked	= 0
	// A list schematics can use for storing mutual data.
	var/list/data

	var/tmp/busy        = FALSE
	var/datum/rcd_schematic/selected
	var/list/favorites  = list()
	var/tmp/next_spark  = 0

	var/datum/html_interface/rcd/interface

	var/obj/abstract/screen/close/closer
	
	
	var/list/settings //for stuff like window directions and construction options.
	var/current_menu=null //we are keeping both systems of schematics for the sake of backwards compatability
	var/list/schem_groups=null
	var/datum/rcd_grouped_schematic/selected_schem=null
	
	

/obj/item/device/rcd/New()
	. = ..()

	schem_groups=new()
	settings=new()

	//interface gets created BEFORE the schematics get created, so they can modify the HEAD content (RPD pipe colour picker).
	interface = new(src, sanitize(name))
	data      = list()
	favorites = list()

	init_schematics()
	rebuild_ui()

	var/turf/T = get_turf(src)
	if(T)
		z_last_checked = T.z

//create and organize the schematics
/obj/item/device/rcd/proc/init_schematics()
	var/list/old_schematics = schematics
	schematics = list()

	for(var/path in old_schematics)
		var/datum/rcd_schematic/C = new path(src)
		if(!schematics[C.category])
			schematics[C.category] = list()

		schematics[C.category] += C

/obj/item/device/rcd/Destroy()
	for(var/cat in schematics)
		for(var/datum/rcd_schematic/C in schematics[cat])
			qdel(C)


	qdel(interface)

	schematics   = null
	interface    = null
	data         = null

	. = ..()

/obj/item/device/rcd/dropped(var/mob/living/dropped_by)
	..()
	if(istype(dropped_by))
		dropped_by.hud_used.toggle_show_schematics_display(null,1, src)

/obj/item/device/rcd/attack_self(var/mob/user)
	//var/turf/T = get_turf(src)
	//if(T?.z != z_last_checked) i don't know why this in in here. commented out instead of removed in case it FSU
	rebuild_ui()
	interface.show(user)

/obj/item/device/rcd/proc/rebuild_ui()
	var/dat = ""

	dat += {"
		<div id="schematic_options">
		</div>
		<h2>Available schematics</h2>
		<div id='fav_list'></div>
	"}
	for(var/cat in schematics)
		dat += "<b>[cat]:</b><ul style='list-style-type:disc'>"
		var/list/L = schematics[cat]
		for(var/datum/rcd_schematic/C in L)
			var/turf/T = get_turf(src)
			if(!T || ((C.flags & RCD_Z_DOWN) && !HasBelow(T.z)) || ((C.flags & RCD_Z_UP) && !HasAbove(T.z)))
				continue
			dat += C.schematic_list_line(interface,FALSE,src.selected==C)
			for(var/client/client in interface.clients)
				C.send_list_assets(client)
		dat += "</ul>"

	interface.updateLayout(dat)

	if(selected)
		update_options_menu()
		interface.updateContent("selectedname", selected.name)

	rebuild_favs()

/obj/item/device/rcd/proc/rebuild_favs()
	var/dat = "<b>Favorites:</b> <span style='color:#fff;' title='You can cycle through these with ctrl+mousewheel outside of the UI.'>(?)</span><ul style='list-style-type:disc'>"
	for (var/datum/rcd_schematic/C in favorites)
		dat += C.schematic_list_line(interface, TRUE,src.selected==C)

	dat += "</ul>"

	interface.updateContent("fav_list", dat)

/obj/item/device/rcd/Topic(var/href, var/list/href_list)
	. = ..()
	if (. || usr.isStunned() || !(src in usr))
		return 1

	if (href_list["schematic"])
		var/datum/rcd_schematic/C = find_schematic(href_list["schematic"])

		if (!istype(C))
			return 1

		switch (href_list["act"])
			if ("select")
				try_switch(usr, C)
			if ("fav")
				favorites |= C
				rebuild_ui()

			if ("defav")
				favorites -= C
				rebuild_ui()

			if ("favorder")
				var/index = favorites.Find(C)
				if (href_list["order"] == "up")
					if (index == favorites.len)
						return 1

					favorites.Swap(index, index + 1)

				else
					if (index == 1)
						return 1

					favorites.Swap(index, index - 1)

				rebuild_favs()

		return 1

	// The href didn't get handled by us so we pass it down to the selected schematic.
	if (selected)
		return selected.Topic(href, href_list)

// Find schematic by `\ref[]`
/obj/item/device/rcd/proc/find_schematic(var/ref)
	// Hahaha my old code is shit now I gotta deal with it.
	for (var/cat in schematics)
		. = locate(ref) in schematics[cat]
		if (.)
			break

/obj/item/device/rcd/proc/try_switch(var/mob/user, var/datum/rcd_schematic/C)
	if (busy && ~C.flags & RCD_ALLOW_SWITCH)
		return 1

	if (selected && !selected.deselect(usr, C))
		return 1

	if (!C.select(usr, selected))
		return 1

	do_spark()

	selected = C
	rebuild_ui()
	update_options_menu()
	rebuild_favs()
	interface.updateContent("selectedname", selected.name)


/obj/item/device/rcd/preattack(atom/movable/A, mob/user, proximity_flag, click_parameters)
	if(A == user)
		afterattack(get_turf(user), user) 	// Skip right to afterattack()
		return TRUE

/obj/item/device/rcd/afterattack(var/atom/A, var/mob/user)
	if(!selected)
		return 1

	if(~selected.flags & (RCD_SELF_SANE | RCD_RANGE) && !(user.Adjacent(A) && A.Adjacent(user))) // If RCD_SELF_SANE and RCD_RANGE are disabled we use adjacency.
		return 1

	if(selected.flags & RCD_RANGE && ~selected.flags & RCD_SELF_SANE && get_dist(A, user) > 1) // RCD_RANGE is used AND we're NOT SELF_SANE, use range(1)
		return 1

	if(selected.flags & RCD_GET_TURF) // Get the turf because RCD_GET_TURF is on.
		A = get_turf(A)
		if (!A)
			return // Thing clicked was in nullspace, so we won't pass a null turf.

	if(~selected.flags & RCD_SELF_SANE && get_energy(user) < selected.energy_cost) // Handle energy amounts, but only if not SELF_SANE.
		return 1

	busy  = TRUE // Busy to prevent switching schematic while it's in use.
	var/t = selected.attack(A, user)
	if(!t) // No errors
		if(~selected.flags & RCD_SELF_COST) // Handle energy costs unless the schematic does it itself.
			use_energy(selected.energy_cost, user)
	else
		if(istext(t))
			to_chat(user, "<span class='warning'>\The [src]'s error light flickers: [t]</span>")
		else
			to_chat(user, "<span class='warning'>\The [src]'s error light flickers.</span>")

	busy = FALSE

	return 1

/obj/item/device/rcd/proc/do_spark()
	if (sparky && next_spark < world.time)
		spark(src, 5, FALSE)
		next_spark = world.time + 0.5 SECONDS
	else
		playsound(src, 'sound/machines/click.ogg', 20, 1)

/obj/item/device/rcd/proc/get_energy(var/mob/user)
	return INFINITY

/obj/item/device/rcd/proc/use_energy(var/amount, var/mob/user)
	return

/obj/item/device/rcd/proc/update_options_menu()
	if(selected)
		for(var/client/client in interface.clients)
			selected.send_assets(client)
		interface.updateContent("schematic_options", selected.get_HTML(args))
	else
		interface.updateContent("schematic_options", " ")

// Called by schematics to delay their actions
/obj/item/device/rcd/proc/delay(var/mob/user, var/atom/target, var/amount)
	return do_after(user, target, amount)

/obj/item/device/rcd/MouseWheeled(var/mob/user, var/delta_x, var/delta_y, var/params)
	var/modifiers = params2list(params)
	if (modifiers["ctrl"])
		if (!favorites.len)
			return

		var/index = 1

		if (selected in favorites)
			index = favorites.Find(selected)
			if (delta_y <= 0)
				index++
				if (index > favorites.len)
					index = 1
			else
				index = index - 1 || favorites.len

		var/datum/rcd_schematic/C = favorites[index]
		try_switch(user, C)

	else if (selected)
		selected.MouseWheeled(user, delta_x, delta_y, params)

/obj/item/device/rcd/borg/attack_self(var/mob/living/user)
	if(!selected || user.shown_schematics_background || !selected.show(user))
		user.hud_used.toggle_show_schematics_display(schematics["Construction"], 0, src)

/obj/item/device/rcd/borg
	var/cell_power_per_energy = 30

/obj/item/device/rcd/borg/use_energy(var/amount, var/mob/user)
	if(!isrobot(user))
		return

	var/mob/living/silicon/robot/R = user

	if(!R.cell)
		return

	R.cell.use(amount * cell_power_per_energy)

/obj/item/device/rcd/borg/get_energy(var/mob/user)
	if(!isrobot(user))
		return 0

	var/mob/living/silicon/robot/R = user

	if(!R.cell)
		return

	return R.cell.charge / cell_power_per_energy

//Matter based RCDs.
/obj/item/device/rcd/matter
	var/matter     = 0
	var/max_matter = 30

/obj/item/device/rcd/matter/attack_self(var/mob/living/user)
	if(!selected || user.shown_schematics_background || !selected.show(user))
		user.hud_used.toggle_show_schematics_display(schematics["Construction"], 0, src)

/obj/item/device/rcd/matter/examine(var/mob/user)
	..()
	to_chat(user, "It currently holds [matter]/[max_matter] matter-units.")

/obj/item/device/rcd/matter/attackby(var/obj/item/stack/S, var/mob/user)
	..()
	if(istype(S,/obj/item/stack/rcd_ammo))
		if((matter + 10) > max_matter)
			to_chat(user, "<span class='notice'>\The [src] can't hold any more matter-units.</span>")
			return 1
		matter += 10
		S.use(1)
		playsound(src, 'sound/machines/click.ogg', 20, 1)
		to_chat(user, "<span class='notice'>\The [src] now holds [matter]/[max_matter] matter-units.</span>")
		return 1

	if(S.is_screwdriver(user))
		to_chat(user, "<span class='notice'>You unscrew the access panel and release the cartridge chamber.</span>")
		while(matter >= 10)
			new /obj/item/stack/rcd_ammo(user.loc, 1)
			matter -= 10

		return 1

/obj/item/device/rcd/matter/use_energy(var/amount, var/mob/user)
	matter -= amount
	to_chat(user, "<span class='notice'>\The [src] currently holds [matter]/[max_matter] matter-units.")

/obj/item/device/rcd/matter/get_energy(var/mob/user)
	return matter

/obj/item/device/rcd/proc/show_default(var/mob/living/user)
	if(selected)
		if(selected.show(user,1))
			return
	user.hud_used.toggle_show_schematics_display(null, 1, src)

/obj/item/device/rcd/mech
	schematics = list(
	/datum/rcd_schematic/decon,
	/datum/rcd_schematic/con_floors,
	/datum/rcd_schematic/con_walls,
	/datum/rcd_schematic/con_airlock,
	/datum/rcd_schematic/con_window,
	)	
	current_menu="deconstruct"


/obj/item/device/rcd/mech/New()
	. = ..()
	rcd_list += src

	var/datum/rcd_scematic_grouping/destroy/dest_g = new(src)
	dest_g.schematics+= new /datum/rcd_grouped_schematic/destroy_all(src)
	
	schem_groups+=dest_g
	schem_groups+= new /datum/rcd_scematic_grouping/build_wall/engi_std(src)
	schem_groups+= new /datum/rcd_scematic_grouping/build_floors/engi_std(src)
	schem_groups+= new /datum/rcd_scematic_grouping/build_airlock/engi_std(src)
	schem_groups+=new /datum/rcd_scematic_grouping/build_windows/engi_std(src)
	
	current_menu=schem_groups[1].name
	schem_groups[1].switch_to()

	
/obj/item/device/rcd/mech/attack_self(var/mob/user)
	rebuild_ui()	
	interface.show(user)
	for(var/datum/rcd_scematic_grouping/schemgroup in schem_groups)
		schemgroup.send_assets(user.client)
		for(var/datum/rcd_grouped_schematic/sch)
			sch.send_assets(user.client)
	interface.hide(user) //have to do this since loading so many images takes a lot of time. and no images is better than no UI
	interface.show(user)


/obj/item/device/rcd/mech/Topic(var/href, var/list/href_list)
	//for(var/i in href_list)
	//	world.log << "[i] = [href_list[i]]"
		
	if(href_list["set_group"])
		for(var/datum/rcd_scematic_grouping/schem_group in schem_groups)
			if(schem_group.name==href_list["set_group"])
				current_menu=href_list["set_group"]
				schem_group.switch_to()
				do_spark()
				rebuild_ui()
				return
	if(href_list["set_schematic"])
		var/datum/rcd_scematic_grouping/group
		for(var/datum/rcd_scematic_grouping/schem_group in schem_groups)
			if(schem_group.name==current_menu)
				group=schem_group
				break
		if(group)
			for(var/datum/rcd_grouped_schematic/schm in group.schematics)
				if(schm.name==href_list["set_schematic"])
					selected_schem=schm
					do_spark()
					rebuild_ui()
					break
		return			
	if(href_list["set_arg"])
		if(href_list["value_togglelist"])
			var/val =  href_list["value_isnum"]=="yes" ? text2num(href_list["value"]) : href_list["value"]
			var/found=FALSE
			for(var/n in settings[href_list["set_arg"]])
				if(n==val)
					found=TRUE
					break
			if( found )
				settings[href_list["set_arg"]] -= val
			else
				settings[href_list["set_arg"]] += val
		else if(href_list["value_resetlist"])
			settings[href_list["set_arg"]]=new /list()
		else if(href_list["value_toggle"] )
			settings[href_list["set_arg"]] = ! settings[href_list["set_arg"]]
		else if (href_list["value_input"])
			var/tx=""
			for(var/datum/rcd_scematic_grouping/schem_group in schem_groups)
				if(schem_group.name==current_menu)
					tx=schem_group.selectiondialogue
					break
			settings[href_list["set_arg"]] = input(usr, tx, src, "[selected_schem?.name]")
		else
			settings[href_list["set_arg"]] = href_list["value_isnum"]=="yes" ? text2num(href_list["value"]) : href_list["value"]
		rebuild_ui()
		return
		
	return

/obj/item/device/rcd/mech/rebuild_ui()
	var/dat=""
	
	//that's right, you can embed a stylesheet in the html body, and you better believe i'm going to do this instead of setting up a whole new file for like 2 rules.
	dat+={"<style> 
	.grouplisting{
	text-align:center;
	font-size:100%;
	}
	.grouplisting img {
	width:64px;
	height:64px;
	}
	
	.grouplisting a{
	width:100%;
	height:100%;
	display:block;
	background:revert;
	}
	
	.clickabletable td{
		text-align:center;
		height:100%; /*to make it so that links inhabit the whole size of the td. kinda annoying to have to do all this.*/
	}
	
	.clickabletable a{
		width:100%;
		height:100%;
		display:block;
	}
	
	img, .clickabletable img, .grouplisting img {
		border:none;
		background:none;
		image-rendering:pixelated;
	}
	
	</style>"}
	
	dat+="<table class='grouplisting'><tr>"
	for(var/datum/rcd_scematic_grouping/schem_group in schem_groups)
		dat+="<td class='[schem_group.name==current_menu ? "schem_selected" : "schem" ]'><a href='?src=\ref[interface];set_group=[schem_group.name]'><img src='[schem_group.headerimage]'><br>[schem_group.name]</a></td>"
	dat+="</tr></table><hr>"
		
	for(var/datum/rcd_scematic_grouping/schem_group in schem_groups)
		if(schem_group.name==current_menu)
			var/t=schem_group.generate_html()
			dat+=t
			break
			
	interface.updateLayout(dat)

/obj/item/device/rcd/mech/afterattack(var/atom/A, var/mob/user)
	if(!selected_schem)
		return 1
	if( !(user.Adjacent(A) && A.Adjacent(user)) )
		return 1
	if(get_dist(A, user) > 1)
		return 1

	var/c=selected_schem.build(A,user)
	if(!c)
		to_chat(user, "<span class='warning'>\The [src]'s error light flickers.</span>")
	else
		use_energy(c, user)	
		rebuild_ui()
	return 1	
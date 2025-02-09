#define VALUE_SCANNING "Scanning"
#define VALUE_SCAN_RANGE "Scan range"
#define VALUE_REMAINING_TIME "Remaining time"
#define VALUE_DEFAULT_TIME "Default time"
#define VALUE_TIMING "Timing"
#define VALUE_PROXMODE "Mode"

#define PROXMODE_CONSTANT "Constant pulsing"
#define PROXMODE_ENTER "Pulse on entry and exit"

/var/global/list/prox_sensor_ignored_types = list \
(
	/obj/effect/beam
)

/obj/item/device/assembly/prox_sensor
	name = "proximity sensor"
	short_name = "prox sensor"

	desc = "Used for scanning and alerting when someone enters a certain proximity."
	icon_state = "prox"
	starting_materials = list(MAT_IRON = 800, MAT_GLASS = 200)
	w_type = RECYK_ELECTRONIC
	origin_tech = Tc_MAGNETS + "=1"

	wires = WIRE_PULSE | WIRE_RECEIVE

	flags = FPRINT | PROXMOVE

	secured = 0

	var/scanning = 0
	var/timing = 0
	var/time = 10

	var/default_time = 10

	var/range = 2

	var/constant_pulse = TRUE
	var/in_proximity = FALSE

	accessible_values = list(\
		VALUE_SCANNING = "scanning;"+VT_NUMBER,\
		VALUE_SCAN_RANGE = "range;"+VT_NUMBER+";1;5",\
		VALUE_REMAINING_TIME = "time;"+VT_NUMBER,\
		VALUE_DEFAULT_TIME = "default_time;"+VT_NUMBER,\
		VALUE_TIMING = "timing;"+VT_NUMBER,\
		VALUE_PROXMODE = "mode;"+VT_NUMBER)

/obj/item/device/assembly/prox_sensor/activate()
	if(!..())
		return 0//Cooldown check
	timing = !timing
	update_icon()
	countdown()
	return 0

/obj/item/device/assembly/prox_sensor/toggle_secure()
	secured = !secured
	if(secured)
		processing_objects.Add(src)
	else
		scanning = 0
		timing = 0
		processing_objects.Remove(src)
	update_icon()
	return secured

/obj/item/device/assembly/prox_sensor/HasProximity(var/atom/movable/AM)
	if(timestopped || (loc && loc.timestopped))
		return

	if(is_type_in_list(AM, global.prox_sensor_ignored_types))
		return

	if(AM.move_speed < 12)
		sense()

/obj/item/device/assembly/prox_sensor/proc/sense()
	var/turf/mainloc = get_turf(src)
//	if(scanning && cooldown <= 0)
//		mainloc.visible_message("[bicon(src)] *boop* *boop*", "*boop* *boop*")
	if((!holder && !secured)||(!scanning)||(cooldown > 0))
		return 0
	pulse(0)
	if(!holder)
		mainloc.visible_message("[bicon(src)] *beep* *beep*", "*beep* *beep*")
	cooldown = 2
	spawn(10)
		process_cooldown()
	return

/obj/item/device/assembly/prox_sensor/process()
	if(scanning)
		if(constant_pulse || !in_proximity)
			var/turf/mainloc = get_turf(src)
			for(var/mob/living/A in range(range,mainloc))
				if (A.move_speed < 12)
					in_proximity = TRUE
					sense()
		else
			var/turf/mainloc = get_turf(src)
			var/still_in_proximity = FALSE
			for(var/mob/living/A in range(range,mainloc))
				if (A.move_speed < 12)
					still_in_proximity = TRUE
					break
			if(!still_in_proximity)
				in_proximity = FALSE
				sense()

/obj/item/device/assembly/prox_sensor/proc/countdown()
	if(timing)
		if(time > 0)
			spawn(10)
				time--
				countdown()
		else
			timing = 0
			toggle_scan()
			time = default_time
		updateUsrDialog()

/obj/item/device/assembly/prox_sensor/dropped()
	spawn(0)
		sense()
		return
	return

/obj/item/device/assembly/prox_sensor/proc/toggle_scan()
	if(!secured)
		return 0
	scanning = !scanning
	update_icon()
	return

/obj/item/device/assembly/prox_sensor/update_icon()
	overlays.len = 0
	attached_overlays = list()
	if(timing)
		attached_overlays["prox_timing"] = image(icon = icon, icon_state = "prox_timing")
		overlays += attached_overlays["prox_timing"]
	if(scanning)
		attached_overlays["prox_scanning"] = image(icon = icon, icon_state = "prox_scanning")
		overlays += attached_overlays["prox_scanning"]
	if(holder)
		holder.update_icon()
	if(holder && istype(holder.loc,/obj/item/weapon/grenade/chem_grenade))
		var/obj/item/weapon/grenade/chem_grenade/grenade = holder.loc
		grenade.primed(scanning)
	return

/obj/item/device/assembly/prox_sensor/Move(NewLoc, Dir = 0, step_x = 0, step_y = 0, glide_size_override = 0)
	..()
	sense()
	return

/obj/item/device/assembly/prox_sensor/interact(mob/user as mob)//TODO: Change this to the wires thingy
	if(!secured)
		user.show_message("<span class='warning'>The [name] is unsecured!</span>")
		return 0
	var/second = time % 60
	var/minute = (time - second) / 60
	var/dat = text("<TT><B>Proximity Sensor</B>\n[] []:[]\n<A href='?src=\ref[];tp=-30'>-</A> <A href='?src=\ref[];tp=-1'>-</A> <A href='?src=\ref[];tp=1'>+</A> <A href='?src=\ref[];tp=30'>+</A>\n</TT>", (timing ? text("<A href='?src=\ref[];time=1'>Arming</A>", src) : text("<A href='?src=\ref[];time=1'>Not Arming</A>", src)), minute, second, src, src, src, src)
	dat += text("<BR>Range: <A href='?src=\ref[];range=-1'>-</A> [] <A href='?src=\ref[];range=1'>+</A>", src, range, src)

	dat += {"<BR><A href='?src=\ref[src];scanning=1'>[scanning?"Armed":"Unarmed"]</A> (Movement sensor active when armed!)
		<BR><BR><A href='?src=\ref[src];set_default_time=1'>After countdown, reset time to [(default_time - default_time%60)/60]:[(default_time % 60)]</A>
		<BR><BR><A href='?src=\ref[src];toggle_mode=1'>Mode: [constant_pulse ? PROXMODE_CONSTANT : PROXMODE_ENTER]</A>"}
	user << browse(dat, "window=prox")
	onclose(user, "prox")
	return


/obj/item/device/assembly/prox_sensor/Topic(href, href_list)
	..()
	if(usr.stat || usr.restrained() || !in_range(loc, usr) || (!usr.canmove && !usr.locked_to))
		//If the user is handcuffed or out of range, or if they're unable to move,
		//but NOT if they're unable to move as a result of being buckled into something, they're unable to use the device.
		usr << browse(null, "window=prox")
		onclose(usr, "prox")
		return

	if(href_list["scanning"])
		toggle_scan()

	if(href_list["time"])
		activate()

	if(href_list["tp"])
		var/tp = text2num(href_list["tp"])
		time += tp
		time = min(max(round(time), 0), 600)

	if(href_list["range"])
		var/r = text2num(href_list["range"])
		range += r
		range = clamp(range, 1, 5)

	if(href_list["set_default_time"])
		default_time = time
	
	if(href_list["toggle_mode"])
		constant_pulse = !constant_pulse

	updateUsrDialog()
	return

#undef VALUE_SCANNING
#undef VALUE_SCAN_RANGE
#undef VALUE_REMAINING_TIME
#undef VALUE_DEFAULT_TIME
#undef VALUE_TIMING

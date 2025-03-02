/*
~~~~~~~~~~~~~~~~~~ CREATING FLAMMABLE OBJECTS ~~~~~~~~~~~~~~~~~~
To make your /obj flammable:
- Set "flammable = TRUE".
- Ensure "w_class" and "w_type" are defined for the object or its parent.
- Note: defining "w_type" does NOT automatically make it recyclable, it just adjusts the sorting logic.

To make your /turf flammable:
- Set "flammable = TRUE"
- Assign a thermal_material as defined in the THERMAL MATERIALS section:
	ie. thermal_material = new/datum/thermal_material/wood()
- Define a thermal_mass (thermal_mass = 5 is used for wood floors)
*/

///////////////////////////////////////////////
// ZAS SETTINGS
///////////////////////////////////////////////

///Subjective exponent for the amount of heat generated by objects burning per tick.
var/ZAS_heat_multiplier = zas_settings.Get(/datum/ZAS_Setting/fire_heat_generation)
///Subjective multiplier for the amount of mass consumed by objects burning per tick.
var/ZAS_mass_consumption_multiplier = zas_settings.Get(/datum/ZAS_Setting/fire_mass_consumption)
///Subjective multiplier for the amount of oxygen consumed by objects burning per tick.
var/ZAS_oxygen_consumption_multiplier = zas_settings.Get(/datum/ZAS_Setting/fire_oxygen_consumption)
///Percent chance for fire to spread from tile to tile.
var/ZAS_fire_spread_chance = zas_settings.Get(/datum/ZAS_Setting/fire_spread_rate)
///Ratio of air removed and combusted per tick.
var/ZAS_air_consumption_rate = zas_settings.Get(/datum/ZAS_Setting/fire_consumption_rate)
///Multiplied by the equation for firelevel, affects mainly the extingiushing of fires.
var/ZAS_firelevel_multiplier = zas_settings.Get(/datum/ZAS_Setting/fire_firelevel_multiplier)
///The energy in joule released when burning one mol of a burnable substance.
var/ZAS_fuel_energy_release_rate = zas_settings.Get(/datum/ZAS_Setting/fire_fuel_energy_release)


///////////////////////////////////////////////
// THERMAL MATERIALS
///////////////////////////////////////////////
/datum/thermal_material
	var/autoignition_temperature
	var/heating_value
	var/molecular_weight
	var/fuel_ox_ratio
	var/flame_temp

/datum/thermal_material/wood
	autoignition_temperature = AUTOIGNITION_WOOD
	heating_value = HHV_WOOD
	molecular_weight = MOLECULAR_WEIGHT_WOOD
	fuel_ox_ratio = FUEL_OX_RATIO_WOOD
	flame_temp = FLAME_TEMPERATURE_WOOD
/datum/thermal_material/plastic
	autoignition_temperature = AUTOIGNITION_PLASTIC
	heating_value = HHV_PLASTIC
	molecular_weight = MOLECULAR_WEIGHT_PLASTIC
	fuel_ox_ratio = FUEL_OX_RATIO_PLASTIC
	flame_temp = FLAME_TEMPERATURE_PLASTIC
/datum/thermal_material/fabric
	autoignition_temperature = AUTOIGNITION_FABRIC
	heating_value = HHV_FABRIC
	molecular_weight = MOLECULAR_WEIGHT_FABRIC
	fuel_ox_ratio = FUEL_OX_RATIO_FABRIC
	flame_temp = FLAME_TEMPERATURE_FABRIC
/datum/thermal_material/wax
	autoignition_temperature = AUTOIGNITION_WAX
	heating_value = HHV_WAX
	molecular_weight = MOLECULAR_WEIGHT_WAX
	fuel_ox_ratio = FUEL_OX_RATIO_WAX
	flame_temp = FLAME_TEMPERATURE_WAX
/datum/thermal_material/biological
	autoignition_temperature = AUTOIGNITION_BIOLOGICAL
	heating_value = HHV_BIOLOGICAL
	molecular_weight = MOLECULAR_WEIGHT_BIOLOGICAL
	fuel_ox_ratio = FUEL_OX_RATIO_BIOLOGICAL
	flame_temp = FLAME_TEMPERATURE_BIOLOGICAL

///////////////////////////////////////////////
// COMBUSTION
///////////////////////////////////////////////
/atom
	var/on_fire = 0
	var/flammable = FALSE
	var/autoignition_temperature //inherited from thermal_material unless defined otherwise
	var/initial_thermal_mass
	var/thermal_mass = 0 //VERY loose estimate of mass in kg
	var/datum/thermal_material/thermal_material //contains the material properties of the item for burning, if applicable
	var/fire_protection //duration that something stays extinguished
	var/burntime = 0

	var/melt_temperature = 0 //unused
	var/molten = 0 //unused

	var/fire_dmi = 'icons/effects/fire.dmi'
	var/fire_sprite = "fire"
	var/fire_overlay = null

	var/mutable_appearance/charred_overlay
	var/last_char = 0

	var/atom/movable/firelightdummy/firelightdummy

/atom/movable/New()
	. = ..()
	if(flammable)
		switch(w_type)
			if(RECYK_WOOD, RECYK_CARDBOARD)
				thermal_material = new/datum/thermal_material/wood()
			if(RECYK_PLASTIC, RECYK_ELECTRONIC, RECYK_MISC, NOT_RECYCLABLE)
				thermal_material = new/datum/thermal_material/plastic()
			if(RECYK_FABRIC)
				thermal_material = new/datum/thermal_material/fabric()
			if(RECYK_WAX)
				thermal_material = new/datum/thermal_material/wax()
			if(RECYK_BIOLOGICAL)
				thermal_material = new/datum/thermal_material/biological()
		if(!thermal_material)
			flammable = FALSE
			//uncomment the following line if you want to identify any improperly-configured flammable items (may spam the logs).
			//warning("[src] was defined as flammable but was missing a 'w_type' definition; [src] marked as non-flammable for this round.")
			return
		if(!autoignition_temperature)
			autoignition_temperature = thermal_material.autoignition_temperature
		fire_protection = world.time

/atom/movable/firelightdummy
	gender = PLURAL
	name = "fire"
	mouse_opacity = 0
	vis_flags = VIS_INHERIT_ID
	light_color = LIGHT_COLOR_FIRE

/atom/movable/firelightdummy/New()
	.=..()
	set_light(2,2)

/atom/proc/melt() //unused
	return

/atom/proc/solidify() //unused
	return

/atom/proc/ashtype()
	return /obj/effect/decal/cleanable/ash

/atom/proc/useThermalMass(var/used_mass)
	thermal_mass -= used_mass

/atom/proc/genSmoke(var/oxy,var/temp,var/turf/where,var/force_smoke = FALSE)
	if(!force_smoke)
		if(prob(clamp(lerp(temp,T20C,T0C + 1000,96,100),96,100))) //4% chance of smoke at 20C, 0% at 1000C
			return FALSE
	var/smoke_density = clamp(5 * ((MINOXY2BURN/oxy) ** 2),1,5)
	var/datum/effect/system/smoke_spread/bad/smoke = new
	smoke.set_up(smoke_density,0,where)
	smoke.time_to_live = 10 SECONDS
	smoke.start()

/atom/proc/check_fire_protection()
	if(fire_protection >= world.time)
		return TRUE

/atom/proc/flammable_reagent_check()
	if(reagents?.total_volume)
		return TRUE

/atom/proc/set_charred_overlay()
	return

/atom/proc/process_charred_overlay()
	return

/obj/set_charred_overlay(char_alpha = 96)
	REMOVE_KEEP_TOGETHER(src, "ash_charred")
	cut_overlay(charred_overlay)
	var/mutable_appearance/new_charred_overlay = mutable_appearance('icons/effects/effects.dmi', "char", alpha = char_alpha, appearance_flags = RESET_COLOR|RESET_ALPHA)
	new_charred_overlay.blend_mode = BLEND_INSET_OVERLAY
	charred_overlay = new_charred_overlay
	ADD_KEEP_TOGETHER(src, "ash_charred")
	add_overlay(charred_overlay)

/obj/process_charred_overlay()
	if(thermal_mass)
		var/c_alpha = 96 + clamp((64*(1-(thermal_mass/initial_thermal_mass))),0,64)
		set_charred_overlay(c_alpha)
		last_char = world.time
	else
		if(prob(10)) //10% chance each tick of item getting charred
			set_charred_overlay()

/obj/effect/process_charred_overlay()
	return

/turf/process_charred_overlay()
	if(locate(/obj/effect/ash) in src)
		var/obj/effect/ash/A = locate(/obj/effect/ash) in src
		if(flammable)
			A.alpha = clamp((80*(1-(thermal_mass/initial_thermal_mass))),0,80) //turf's char overlays aren't as harsh as objects'
		else
			A.alpha = 40
	else
		new /obj/effect/ash(src)

/obj/effect/ash
	name = "ash"
	icon_state = "char"
	alpha = 0
	anchored = 1
	mouse_opacity = 0

/obj/effect/ash/clean_act(var/cleanliness)
	if(cleanliness >= CLEANLINESS_WATER)
		qdel(src)

/**
 * Burns solid objects and produces heat.
 *
 * Called on every obj/effect/fire/process().
 * Energy is taken from burning atoms and delivered to the obj/effect/fire at the atom's location.
 * Outputs heat produced (kJ), Oxygen consumed (mol), CO2 produced (mol), and max temperature (K) of the burning object.
 */
/atom/proc/burnSolidFuel()
	//Don't burn the container until all reagents have been depleted via burnLiquidFuel().
	if(flammable_reagent_check())
		return

	if(!flammable)
		extinguish()
		return

	//Setup
	var/turf/simulated/T = get_turf(src)
	if(!T || !istype(T))
		extinguish()
		return
	var/datum/thermal_material/material = src.thermal_material
	var/datum/gas_mixture/air = T.return_air()
	var/oxy_ratio  = air.molar_ratio(GAS_OXYGEN)
	var/temperature = air.return_temperature()
	var/delta_t
	var/heat_out = 0 //J
	var/oxy_used = 0 //mols
	var/co2_prod = 0 //mols


	//Check if a fire is present at the current location.
	var/in_fire = FALSE
	if(locate(/obj/effect/fire) in T)
		in_fire = TRUE

	burntime += 1 SECONDS

	//Rate at which energy is consumed from the burning atom and delivered to the fire.
	//Provides the "heat" and "oxygen" portions of the fire triangle.
	var/burnrate = (oxy_ratio/(MINOXY2BURN + rand(-2,2)*0.01)) * (temperature/T20C) //burnrate ~ 1 for standard air
	if(burnrate < 0.1 || (air[GAS_OXYGEN] * CELL_VOLUME < air.volume)) //evil fucking unit manipulation; extinguishes if less than 1mol O2 per tile in a zone
		extinguish()
		return

	var/delta_m = 0.20 * burnrate * ZAS_mass_consumption_multiplier
	useThermalMass(delta_m)
	genSmoke(oxy_ratio,temperature,T)

	if(world.time - last_char >= 10 SECONDS)
		process_charred_overlay()

	//Change in internal energy = energy produced by combustion (assuming perfect combustion).
	heat_out = material.heating_value * delta_m

	//Moles of Oxygen consumed and CO2 produced.
	oxy_used = (delta_m / material.molecular_weight) / material.fuel_ox_ratio
	co2_prod = oxy_used //simplification

	//Start a fire on the tile if a burning object is present without an underlying fire effect.
	if(!in_fire)
		//Change in internal energy = change in energy due to heat transfer due to isochoric reaction
		delta_t = heat_out/(delta_m * material.heating_value)
		T.hotspot_expose(temperature + delta_t, FULL_FLAME, 1)
		new /obj/effect/fire(T)

	//Ash the object if all of its mass has been consumed.
	if(thermal_mass <= 0.05)
		if(burntime < MIN_BURN_TIME) //preventing things from burning up in an instant
			thermal_mass = 0.1
		else
			thermal_mass = 0
			ashify()

	heat_out *= 1000

	return list("heat_out"=heat_out,"oxy_used"=oxy_used,"co2_prod"=co2_prod,"max_temperature"=material.flame_temp)

/**
 * Burns flammable liquid puddles or flammable liquids within containers and produces heat.
 *
 * Called on every obj/effect/fire/process().
 * Energy is taken from burning atoms and delivered to the obj/effect/fire at the atom's location.
 * Outputs heat produced (MJ), Oxygen consumed (mol), CO2 produced (mol), and max temperature (K) of the burning object.
 */
/atom/proc/burnLiquidFuel()
	if(!flammable_reagent_check())
		return

	//Setup
	var/turf/simulated/T = get_turf(src)
	if(!T || !istype(T))
		extinguish()
		return

	var/heat_out = 0 //MJ
	var/oxy_used = 0 //mols
	var/co2_prod = 0 //mols (some reagents consume co2 when they burn)
	var/max_temperature = 0 //K
	var/consumption_rate = 1.0 //units per tick
	var/has_fuel = FALSE

	//Check if a fire is present at the current location.
	var/in_fire = FALSE
	if(locate(/obj/effect/fire) in T)
		in_fire = TRUE

	for(var/possible_fuel in possible_fuels)
		if(reagents.has_reagent(possible_fuel))
			has_fuel = TRUE
			var/list/fuel_stats = possible_fuels[possible_fuel]
			max_temperature = max(max_temperature,fuel_stats["max_temperature"])
			heat_out += fuel_stats["thermal_energy_transfer"]
			consumption_rate = fuel_stats["consumption_rate"]
			oxy_used += fuel_stats["o2_cons"]
			co2_prod += -fuel_stats["co2_cons"]
			reagents.remove_reagent(possible_fuel, consumption_rate)

	if(!has_fuel)
		for(var/datum/reagent/liquid in reagents.reagent_list)
			reagents.remove_reagent(liquid.id,1) //evaporate non-flammable reagents

	//Start a fire on the tile if a burning object is present without an underlying fire effect.
	if(!in_fire)
		T.hotspot_expose(max_temperature, FULL_FLAME, 1)
		new /obj/effect/fire(T)

	return list("heat_out"=heat_out,"oxy_used"=oxy_used,"co2_prod"=co2_prod,"max_temperature"=max_temperature)

/atom/proc/has_liquid_fuel()
	if(!reagents)
		return FALSE
	for(var/possible_fuel in possible_fuels)
		if(reagents.has_reagent(possible_fuel))
			return TRUE

/atom/proc/ashify()
	if(!on_fire)
		return
	var/ashtype = ashtype()
	new ashtype(src.loc)
	visible_message("<span class='danger'>\The [src] burns into a pile of dust!</span>")
	extinguish()
	qdel(src)

/atom/proc/extinguish(var/duration = 30 SECONDS)
	if(on_fire)
		on_fire=0
	fire_protection = world.time + duration
	if(fire_overlay)
		overlays -= fire_overlay
	QDEL_NULL(firelightdummy)

/atom/proc/ignite()
	if(check_fire_protection())
		return 0

	if(!isturf(loc)) //worn or held items don't ignite (for now >:^) )
		return 0

	if(!flammable)
		if(!reagents)
			return 0
		if(!reagents.total_volume)
			return 0
		if(!has_liquid_fuel())
			return 0

	on_fire=1

	if(fire_dmi && fire_sprite && !fire_overlay)
		fire_overlay = mutable_appearance(fire_dmi,fire_sprite)
		overlays += fire_overlay

	burnSolidFuel()
	burnLiquidFuel()
	return 1

/atom/movable/ignite()
	if(..() && !firelightdummy)
		firelightdummy = new (src)

/atom/proc/fire_act(datum/gas_mixture/air, exposed_temperature, exposed_volume)
	if(flammable && !on_fire)
		ignite()
		return TRUE
	else
		process_charred_overlay()
	return FALSE

/atom/proc/checkburn()
	if(on_fire)
		return
	if(!flammable)
		CRASH("[src] tried to burn despite not being flammable!")
	//if an object is not on fire, is flammable, and is in an environment with temperature above its autoignition temp & sufficient oxygen, ignite it
	if(thermal_mass <= 0)
		ashify()
		return
	var/datum/gas_mixture/G = return_air()
	if(!G)
		return
	if(!(G.temperature >= autoignition_temperature))
		return
	if(!(G.molar_ratio(GAS_OXYGEN) >= MINOXY2BURN))
		return
	if(G[GAS_OXYGEN] * CELL_VOLUME < G.volume) //if less than 1 mol/tile, no fire
		return
	if(prob(50))
		ignite()

/area/checkburn()
	CRASH("[src] added to burnableatoms!")

/mob/checkburn()
	CRASH("[src] added to burnableatoms!")

/area/fire_act()
	return

/mob/fire_act()
	return

/**
 * Creates a hotspot on the input turf. Called by an obj to aid in logging and surface burn checking.
 *
 * Hotspots ignite any atoms (including the turf itself) on or gasses in the turf with autoignition temperatures below the input temperature.
 * Arguments:
 * * exposed_temperature - Temperature of the hotspot (Kelvin).
 * * exposed_volume - Relative volume of the turf exposed to the hotspot (Milliliter).
 * * surfaces - -1: Ignite surfaces if on the ground, 0: Only ignite gasses, 1: Always ignite surfaces.
 */
/obj/proc/try_hotspot_expose(var/exposed_temperature, var/exposed_volume = CELL_VOLUME, var/surfaces=0)
	var/turf/simulated/T = get_turf(src)
	if(!istype(T))
		return
	if(surfaces == -1)
		if(loc == T)
			surfaces = TRUE
		else
			surfaces = FALSE
	if(T.hotspot_expose(exposed_temperature,exposed_volume,surfaces))
		message_admins("\The [src] started a fire at [loc] ([x], [y], [z]): <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[x];Y=[y];Z=[z]'>JMP</a>, last touched by [fingerprintslast].")
		log_game("\The [src] started a fire at [loc]([x], [y], [z]): <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[x];Y=[y];Z=[z]'>JMP</a>, last touched by [fingerprintslast].")

///////////////////////////////////////////////
// TURF COMBUSTION
///////////////////////////////////////////////
/turf
	var/soot_type = /obj/effect/decal/cleanable/soot

/turf/New()
	..()
	if(!thermal_material)
		flammable = FALSE
		return
	if(!autoignition_temperature)
		autoignition_temperature = thermal_material.autoignition_temperature
	if(thermal_mass)
		initial_thermal_mass = thermal_mass
	fire_protection = world.time

/turf/ashify()
	if(!on_fire)
		return
	extinguish()

/**
 * Creates a hotspot on the given turf.
 *
 * Hotspots ignite any atoms (including the turf itself) on or gasses in the turf with autoignition temperatures below the input temperature.
 * Arguments:
 * * exposed_temperature - Temperature of the hotspot (Kelvin).
 * * exposed_volume - Relative volume of the turf exposed to the hotspot (Milliliter).
 * * surfaces - 0: Only ignite gasses, 1: Always ignite surfaces.
 */
/turf/proc/hotspot_expose(var/exposed_temperature, var/exposed_volume = CELL_VOLUME, var/surfaces=0)
	return 0

/turf/simulated/hotspot_expose(exposed_temperature, exposed_volume, surfaces)
	var/obj/effect/foam/fire/W = locate() in contents
	if(istype(W))
		return 0
	if(check_fire_protection())
		return 0
	if(locate(/obj/effect/fire) in src)
		return 0

	var/datum/gas_mixture/air_contents = return_air()
	if(!air_contents)
		return 0

	var/igniting = 0
	if(air_contents.check_combustability(src))
		if(air_contents.check_combustability(src) == 2)
			if(prob(exposed_volume * 100 / CELL_VOLUME))
				ignite()
				igniting = 1
		if(surfaces)
			if(flammable_reagent_check())
				ignite()
				igniting = 1
			else if(flammable && !on_fire)
				if(prob(exposed_volume * 100 / CELL_VOLUME))
					ignite()
					igniting = 1
			for(var/obj/O in contents)
				if(prob(exposed_volume * 100 / CELL_VOLUME) && istype(O) && O.flammable && !O.on_fire && exposed_temperature >= O.autoignition_temperature)
					O.ignite()
					igniting = 1
					break
		if(igniting)
			new /obj/effect/fire(src)
	return igniting

/turf/simulated/fire_act(datum/gas_mixture/air, exposed_temperature, exposed_volume)
	var/obj/effect/E = null
	if(soot_type)
		E = locate(soot_type) in src
	if(..())
		return 1
	if(on_fire)
		if(istype(E))
			qdel(E)
		return 0
	else
		if(flammable)
			ignite()
	if(!E && soot_type && prob(25))
		new soot_type(src)
	return 0

/turf/simulated/ignite()
	if(!flammable || check_fire_protection() || thermal_mass <= 0)
		return FALSE

	var/datum/gas_mixture/air_contents = return_air()
	if(air_contents[GAS_OXYGEN] < 1)
		return FALSE

	var/in_fire = FALSE
	on_fire=1

	if(locate(/obj/effect/fire) in src)
		in_fire = TRUE
	if(!in_fire)
		new /obj/effect/fire(src)
	return TRUE

/turf/simulated/flammable_reagent_check()
	if(locate(/obj/effect/decal/cleanable/liquid_fuel) in src)
		return TRUE

/turf/simulated/burnLiquidFuel()
	return

/turf/unsimulated/burnSolidFuel()
	return

/turf/unsimulated/burnLiquidFuel()
	return

///////////////////////////////////////////////
// FIRE
///////////////////////////////////////////////
/obj/effect/fire
	anchored = 1
	mouse_opacity = 0
	blend_mode = BLEND_ADD
	icon = 'icons/effects/fire.dmi'
	icon_state = "key1"
	layer = TURF_FIRE_LAYER
	plane = ABOVE_TURF_PLANE
	light_color = LIGHT_COLOR_FIRE
	var/last_vis_refresh = 0
	var/burn_duration = 0

/obj/effect/fire/New()
	. = ..()
	dir = pick(cardinal)
	var/turf/T = get_turf(loc)
	var/datum/gas_mixture/air_contents=T.return_air()
	if(air_contents)
		setfirelight(air_contents.calculate_firelevel(get_turf(src)), air_contents.temperature)
	SSair.add_hotspot(src)

/obj/effect/fire/Destroy()
	SSair.remove_hotspot(src)
	set_light(0)
	..()

/obj/effect/fire/proc/Extinguish()
	for(var/atom/A in loc)
		A.extinguish()
	qdel(src)

/obj/effect/fire/extinguish() //lol
	QDEL_NULL(firelightdummy)
	qdel(src)


/obj/effect/fire/burnSolidFuel()
	return 0

/obj/effect/fire/burnLiquidFuel()
	return 0

/obj/effect/fire/Crossed(atom/movable/AM)
	AM.ignite()
	..()

/obj/effect/fire/process()
	if(timestopped)
		return 0
	. = 1

	//Fires shouldn't spawn in areas or mobs, but it has happened...
	if(!istype(loc,/turf))
		qdel(src)

	// Get location and check if it is in a proper ZAS zone.
	var/turf/simulated/S = get_turf(loc)
	if(!istype(S) || isnull(S.zone))
		Extinguish()
		return

	//since the air is processed in fractions, we need to make sure not to have any minuscle residue or
	//the amount of moles might get to low for some functions to catch them and thus result in wonky behaviour
	var/datum/gas_mixture/air_contents = S.return_air()

	//Check if there is something to combust.
	if(!air_contents.check_recombustability(S))
		Extinguish()
	else if(air_contents.check_recombustability(S) == 1)
		if((air_contents.molar_ratio(GAS_OXYGEN)) < (MINOXY2BURN + rand(-2,2)*0.01) || (air_contents[GAS_OXYGEN] < 1)) //extinguish if the ratio of fuel:oxygen is too low or if there isn't enough oxygen present at all
			Extinguish()
			return

	if(air_contents.molar_ratio(GAS_OXYGEN) < 0.1 / CELL_VOLUME)
		air_contents[GAS_OXYGEN] = 0
	if(air_contents.molar_ratio(GAS_PLASMA) < 0.1 / CELL_VOLUME)
		air_contents[GAS_PLASMA] = 0
	if(air_contents.molar_ratio(GAS_VOLATILE) < 0.1 / CELL_VOLUME)
		air_contents[GAS_VOLATILE] = 0
	air_contents.update_values()

	//Set firelevel and fire light.
	var/firelevel = air_contents.calculate_firelevel(S)
	setfirelight(firelevel, air_contents.temperature)

	//Burn mobs.
	for(var/mob/living/carbon/human/M in S)
		if(M.mutations.Find(M_UNBURNABLE))
			continue
		M.fire_act(air_contents, FLAME_TEMPERATURE_PLASTIC, air_contents.return_volume())

	//Burn items in the turf.
	for(var/atom/A in S)
		if(A.loc == S)
			A.fire_act(air_contents, air_contents.temperature, air_contents.return_volume())

	//Burn the turf, too.
	S.fire_act(air_contents, air_contents.temperature, air_contents.return_volume())

	//Spread
	for(var/direction in cardinal)
		if(S.open_directions & direction) //Grab all valid bordering tiles
			var/turf/simulated/enemy_tile = get_step(S, direction)
			var/liquidburn = FALSE
			if(istype(enemy_tile))
				var/datum/gas_mixture/acs = enemy_tile.return_air()
				if(!acs)
					continue
				if(!acs.check_combustability(enemy_tile))
					continue
				//If extinguisher mist passed over the turf it's trying to spread to, don't spread and reduce firelevel.
				var/obj/effect/foam/fire/W = locate() in enemy_tile
				if(istype(W))
					firelevel -= 3
					continue
				if(enemy_tile.check_fire_protection())
					firelevel -= 1.5
					continue
				if(enemy_tile.flammable_reagent_check())
					liquidburn = TRUE
				//Spread the fire.
				if(!(locate(/obj/effect/fire) in enemy_tile))
					if(prob(clamp(ZAS_fire_spread_chance*round(burn_duration/5)*((acs.temperature/T20C)**0.5) + 25*firelevel + 50*liquidburn,0,100)) && S.Cross(null, enemy_tile, 0,0) && enemy_tile.Cross(null, S, 0,0))
						new/obj/effect/fire(enemy_tile)
	//seperate part of the present gas
	//this is done to prevent the fire burning all gases in a single pass
	var/datum/gas_mixture/flow = air_contents.remove_volume(ZAS_air_consumption_rate * CELL_VOLUME)
///////////////////////////////// FLOW HAS BEEN CREATED /// DONT DELETE THE FIRE UNTIL IT IS MERGED BACK OR YOU WILL DELETE AIR ///////////////////////////////////////////////
	if(flow)
		flow.zburn(S, 1)
		//merge the air back
		S.assume_air(flow)
///////////////////////////////// FLOW HAS BEEN REMERGED /// feel free to delete the fire again from here on //////////////////////////////////////////////////////////////////
	burn_duration++

/obj/effect/fire/proc/setfirelight(firelevel, firetemp)
	// Update fire color.
	if(last_vis_refresh + ((10 + rand(-2,2)) SECONDS) > world.time)
		return

	var/range
	var/power

	if(firelevel > 6)
		icon_state = "key3"
		range = 7
		power = 3
	else if(firelevel > 2.5)
		icon_state = "key2"
		range = 5
		power = 2
	else
		icon_state = "key1"
		range = 3
		power = 1

	color = heat2color(firetemp)
	set_light(range, power, color)
	last_vis_refresh = world.time

/datum/gas_mixture/proc/zburn(var/turf/T, force_burn)
	//NOTE: zburn is also called from canisters and in tanks/pipes (via react()).
	var/value = 0 //always 0 unless Plasma or Volatile Gas combusts with Oxygen.

	//Return if there's nothing left to burn.
	if(!check_recombustability(T))
		return value

	var/firelevel = 0
	var/total_fuel = 0
	var/starting_energy = temperature * heat_capacity()
	var/total_oxygen = 0
	var/used_fuel_ratio = 0
	var/total_reactants = 0
	var/used_reactants_ratio = 0
	if(temperature > PLASMA_MINIMUM_BURN_TEMPERATURE || force_burn)
		total_fuel += src[GAS_PLASMA]
		total_fuel += src[GAS_VOLATILE]
		if(total_fuel)
			//Calculate the firelevel.
			firelevel = calculate_firelevel(T)
			//determine the amount of oxygen used
			total_oxygen = min(src[GAS_OXYGEN], PLASMA_MINIMUM_OXYGEN_NEEDED * total_fuel)
			//determine the amount of fuel actually used
			used_fuel_ratio = min(src[GAS_OXYGEN] / PLASMA_MINIMUM_OXYGEN_NEEDED , total_fuel) / total_fuel
			total_fuel = total_fuel * used_fuel_ratio
			total_reactants = total_fuel + total_oxygen
			//determine the amount of reactants actually reacting
			used_reactants_ratio = clamp(firelevel / ZAS_firelevel_multiplier, clamp(0.2 / total_reactants, 0, 1), 1)

	//Combustion of solids and liquids
	var/combustion_energy = 0
	var/combustion_oxy_used = 0
	var/combustion_co2_prod = 0
	var/max_temperature = 0
	var/solid_burn_products
	var/liquid_burn_products
	if(T)
		if(T.on_fire) //burn the turf
			solid_burn_products = T.burnSolidFuel()
			if(solid_burn_products)
				combustion_energy += solid_burn_products["heat_out"]
				combustion_oxy_used += solid_burn_products["oxy_used"]
				combustion_co2_prod += solid_burn_products["co2_prod"]
				max_temperature = max(max_temperature, solid_burn_products["max_temperature"])
		for(var/atom/A in T)
			if(A.on_fire) //burn items on the turf
				solid_burn_products = A.burnSolidFuel()
				if(solid_burn_products)
					combustion_energy += solid_burn_products["heat_out"]
					combustion_oxy_used += solid_burn_products["oxy_used"]
					combustion_co2_prod += solid_burn_products["co2_prod"]
					max_temperature = max(max_temperature, solid_burn_products["max_temperature"])
			if(A.reagents || istype(A,/obj/effect/decal/cleanable/liquid_fuel)) //burn liquids in containers on the turf
				liquid_burn_products = A.burnLiquidFuel()
				if(liquid_burn_products)
					combustion_energy += liquid_burn_products["heat_out"]
					combustion_oxy_used += liquid_burn_products["oxy_used"]
					combustion_co2_prod += liquid_burn_products["co2_prod"]
					max_temperature = max(max_temperature, liquid_burn_products["max_temperature"])

	//Sanity checks.
	combustion_oxy_used = clamp(combustion_oxy_used, 0, src[GAS_OXYGEN])
	if(!max_temperature)
		max_temperature = FLAME_TEMPERATURE_PLASTIC

	//Remove and add gasses as calculated.
	adjust_multi(
		GAS_OXYGEN, -min(src[GAS_OXYGEN], total_oxygen * used_reactants_ratio + combustion_oxy_used * ZAS_oxygen_consumption_multiplier),
		GAS_PLASMA, -min(src[GAS_PLASMA], (src[GAS_PLASMA] * used_fuel_ratio * used_reactants_ratio) * 3),
		GAS_CARBON, max(2 * total_fuel * used_reactants_ratio + combustion_co2_prod * ZAS_oxygen_consumption_multiplier, 0),
		GAS_VOLATILE, -min(src[GAS_VOLATILE], (src[GAS_VOLATILE] * used_fuel_ratio * used_reactants_ratio) * 5)) //Fuel burns 5 times as quick

	//Calculate the energy produced by the reaction and then set the new temperature of the mix.
	var/combustion_efficiency = max((1 - temperature/max_temperature),0)
	temperature = (starting_energy + (combustion_energy ** ZAS_heat_multiplier) * combustion_efficiency + ZAS_fuel_energy_release_rate * total_fuel * used_reactants_ratio) / heat_capacity()
	update_values()

	value = total_reactants * used_reactants_ratio
	return value

//Checks if anything in a given turf can continue burning.
/datum/gas_mixture/proc/check_recombustability(var/turf/T)
	if(gas[GAS_OXYGEN] && (gas[GAS_PLASMA] || gas[GAS_VOLATILE]))
		if(QUANTIZE(molar_density(GAS_PLASMA) * ZAS_air_consumption_rate) >= MOLES_PLASMA_VISIBLE / CELL_VOLUME)
			return 2
		if(QUANTIZE(molar_density(GAS_VOLATILE) * ZAS_air_consumption_rate) >= BASE_ZAS_FUEL_REQ / CELL_VOLUME)
			return 2

	//Check if we're actually in a turf or not before trying to check object fires
	if(!T)
		return 0
	if(!istype(T))
		warning("check_recombustability being asked to check a [T.type] instead of /turf.")
		return 0

	if(T.flammable && !T.check_fire_protection() && T.thermal_mass > 0)
		return 1

	if(locate(/obj/effect/decal/cleanable/liquid_fuel) in T)
		return 1

	for(var/atom/A in T)
		if(!A.check_fire_protection())
			if(A.flammable && A.thermal_mass > 0)
				return 1
			if(A.reagents)
				for(var/possible_fuel in possible_fuels)
					if(A.reagents.has_reagent(possible_fuel))
						return 1

//Checks if anything in a given turf can burn.
/datum/gas_mixture/proc/check_combustability(var/turf/T)
	if(T.flammable && T.thermal_mass > 0)
		return 1

	if(locate(/obj/effect/decal/cleanable/liquid_fuel) in T)
		return 1

	if(gas[GAS_OXYGEN] && (gas[GAS_PLASMA] || gas[GAS_VOLATILE]))
		if(QUANTIZE(molar_density(GAS_PLASMA) * ZAS_air_consumption_rate) >= MOLES_PLASMA_VISIBLE / CELL_VOLUME)
			return 2 //returns 2 if we're burning plasma or volatiles
		if(QUANTIZE(molar_density(GAS_VOLATILE) * ZAS_air_consumption_rate) >= BASE_ZAS_FUEL_REQ / CELL_VOLUME)
			return 2

	for(var/atom/A in T)
		if(A.flammable && A.thermal_mass > 0)
			return 1
		if(A.reagents)
			for(var/possible_fuel in possible_fuels)
				if(A.reagents.has_reagent(possible_fuel))
					return 1

//firelevel represents the intensity of the fire according to GAS REACTANTS only. Solids and liquids burning use an internal burnrate calculation.
/datum/gas_mixture/proc/calculate_firelevel(var/turf/T)
	var/total_fuel = 0
	var/firelevel = 0

	if(check_recombustability(T))
		total_fuel += src[GAS_PLASMA]
		total_fuel += src[GAS_VOLATILE]
		var/total_combustables = (total_fuel + src[GAS_OXYGEN])

		if(total_fuel > 0 && src[GAS_OXYGEN] > 0)
			//slows down the burning when the concentration of the reactants is low
			var/dampening_multiplier = total_combustables / (total_combustables + src[GAS_NITROGEN] + src[GAS_CARBON])
			//calculates how close the mixture of the reactants is to the optimum
			var/mix_multiplier = 1 / (1 + (5 * ((src[GAS_OXYGEN] / total_combustables) ** 2))) // Thanks, Mloc
			//toss everything together
			firelevel = ZAS_firelevel_multiplier * mix_multiplier * dampening_multiplier

	return max(0, firelevel)

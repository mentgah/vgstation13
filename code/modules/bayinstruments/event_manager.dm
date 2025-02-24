/datum/musical_event
	var/sound/object
	var/mob/subject
	var/datum/sound_player/source
	var/time = 0
	var/new_volume = 100


/datum/musical_event/New(datum/sound_player/source_, mob/subject_, sound/object_, time_, volume_)
	src.source = source_
	src.subject = subject_
	src.object = object_
	src.time = time_
	src.new_volume = volume_


/datum/musical_event/proc/tick()
	if (!(istype(object) && istype(subject) && istype(source))) 
		return
	if (src.new_volume > 0) src.update_sound()
	else src.destroy_sound()


/datum/musical_event/proc/update_sound()
	src.object.volume = src.new_volume
	src.object.status |= SOUND_UPDATE
	if (src.subject)
		src.subject << src.object


/datum/musical_event/proc/destroy_sound()
	if (src.subject)
		var/sound/null_sound = sound(channel=src.object.channel, wait=0)
		if (global.musical_config.env_settings_available)
			null_sound.environment = -1
		src.subject << null_sound
	if (src.source || src.source.song)
		src.source.song.free_channel(src.object.channel)



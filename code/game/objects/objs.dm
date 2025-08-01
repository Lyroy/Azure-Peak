
/obj
	animate_movement = SLIDE_STEPS
	speech_span = SPAN_ROBOT
	var/obj_flags = CAN_BE_HIT
	/// This Var ensures the object ignores all object flags, which is extremely important for contraptions (which are supposed ot interact with all objects even if it does not produce a result)
	var/obj_flags_ignore = FALSE
	var/set_obj_flags // ONLY FOR MAPPING: Sets flags from a string list, handled in Initialize. Usage: set_obj_flags = "EMAGGED;!CAN_BE_HIT" to set EMAGGED and clear CAN_BE_HIT.

	var/damtype = BRUTE
	var/force = 0
	//a modifier to an item's damage against structures
	var/demolition_mod = 1

	var/datum/armor/armor
	var/last_peeled_limb
	var/peel_count = 0
	var/peel_threshold = 3
	var/obj_integrity	//defaults to max_integrity
	var/max_integrity = 500
	var/integrity_failure = 0 //0 if we have no special broken behavior, otherwise is a percentage of at what point the obj breaks. 0.5 being 50%
	///Damage under this value will be completely ignored
	var/damage_deflection = 0
	var/obj_broken = FALSE
	var/obj_destroyed = FALSE

	var/extinguishable = TRUE // flag for torches, lanterns, clothing, and the like.

	var/resistance_flags = NONE // INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ON_FIRE | UNACIDABLE | ACID_PROOF

	var/acid_level = 0 //how much acid is on that obj

	var/persistence_replacement //have something WAY too amazing to live to the next round? Set a new path here. Overuse of this var will make me upset.
	var/current_skin //Has the item been reskinned?
	var/list/unique_reskin //List of options to reskin.

	// Access levels, used in modules\jobs\access.dm
	var/list/req_access
	var/req_access_txt = "0"
	var/list/req_one_access
	var/req_one_access_txt = "0"

	var/renamedByPlayer = FALSE //set when a player uses a pen on a renamable object

	var/drag_slowdown // Amont of multiplicative slowdown applied if pulled. >1 makes you slower, <1 makes you faster.

	var/blade_dulling = DULLING_BASHCHOP

	var/debris = null
	var/static_debris = null
	var/break_sound = null
	var/break_message = null
	var/destroy_sound = 'sound/foley/breaksound.ogg'
	var/destroy_message = null

	var/animate_dmg = TRUE

	/// Icon to use as a 32x32 preview in crafting menus and such
	var/icon_state_preview

	vis_flags = VIS_INHERIT_PLANE

/obj/vv_edit_var(vname, vval)
	switch(vname)
		if("anchored")
			setAnchored(vval)
			return TRUE
		if("obj_flags")
			if ((obj_flags & DANGEROUS_POSSESSION) && !(vval & DANGEROUS_POSSESSION))
				return FALSE
		if("control_object")
			var/obj/O = vval
			if(istype(O) && (O.obj_flags & DANGEROUS_POSSESSION))
				return FALSE
	return ..()

/obj/Initialize()
	if (islist(armor))
		armor = getArmor(arglist(armor))
	else if (!armor)
		armor = getArmor()
	else if (!istype(armor, /datum/armor))
		stack_trace("Invalid type [armor.type] found in .armor during /obj Initialize()")
	if(obj_integrity == null)
		obj_integrity = max_integrity

	. = ..() //Do this after, else mat datums is mad.

	if (set_obj_flags)
		var/flagslist = splittext(set_obj_flags,";")
		var/list/string_to_objflag = GLOB.bitfields["obj_flags"]
		for (var/flag in flagslist)
			if (findtext(flag,"!",1,2))
				flag = copytext(flag,1-(length(flag))) // Get all but the initial !
				obj_flags &= ~string_to_objflag[flag]
			else
				obj_flags |= string_to_objflag[flag]

/obj/Destroy(force=FALSE)
	if(!ismachinery(src))
		STOP_PROCESSING(SSobj, src) // TODO: Have a processing bitflag to reduce on unnecessary loops through the processing lists
	SStgui.close_uis(src)
	. = ..()

/obj/proc/setAnchored(anchorvalue)
	SEND_SIGNAL(src, COMSIG_OBJ_SETANCHORED, anchorvalue)
	anchored = anchorvalue

/obj/throw_at(atom/target, range, speed, mob/thrower, spin=1, diagonals_first = 0, datum/callback/callback, force)
	..()
	if(obj_flags & FROZEN)
		visible_message("<span class='danger'>[src] shatters into a million pieces!</span>")
		qdel(src)

/obj/proc/updateUsrDialog()
	if((obj_flags & IN_USE) && !(obj_flags & USES_TGUI))
		var/is_in_use = FALSE
		var/list/nearby = viewers(1, src)
		for(var/mob/M in nearby)
			if ((M.client && M.machine == src))
				is_in_use = TRUE
				ui_interact(M)
		if(IsAdminGhost(usr))
			if (!(usr in nearby))
				if (usr.client && usr.machine==src) // && M.machine == src is omitted because if we triggered this by using the dialog, it doesn't matter if our machine changed in between triggering it and this - the dialog is probably still supposed to refresh.
					is_in_use = TRUE
					ui_interact(usr)

		if (is_in_use)
			obj_flags |= IN_USE
		else
			obj_flags &= ~IN_USE

/obj/proc/updateDialog(update_viewers = TRUE,update_ais = TRUE)
	// Check that people are actually using the machine. If not, don't update anymore.
	if(obj_flags & IN_USE)
		var/is_in_use = FALSE
		if(update_viewers)
			for(var/mob/M in viewers(1, src))
				if ((M.client && M.machine == src))
					is_in_use = TRUE
					src.interact(M)
		if(update_viewers) //State change is sure only if we check both
			if(!is_in_use)
				obj_flags &= ~IN_USE


/obj/attack_ghost(mob/user)
	. = ..()
	if(.)
		return
	ui_interact(user)

/obj/proc/container_resist(mob/living/user)
	return

/mob/proc/unset_machine()
	if(machine)
		machine.on_unset_machine(src)
		machine = null

//called when the user unsets the machine.
/atom/movable/proc/on_unset_machine(mob/user)
	return

/mob/proc/set_machine(obj/O)
	if(src.machine)
		unset_machine()
	src.machine = O
	if(istype(O))
		O.obj_flags |= IN_USE

/obj/item/proc/updateSelfDialog()
	var/mob/M = src.loc
	if(istype(M) && M.client && M.machine == src)
		src.attack_self(M)

/obj/proc/hide(h)
	return

/obj/get_dumping_location(datum/component/storage/source,mob/user)
	return get_turf(src)

/obj/proc/CanAStarPass(ID, to_dir, caller)
	. = !density

/obj/proc/check_uplink_validity()
	return 1

/obj/vv_get_dropdown()
	. = ..()
	VV_DROPDOWN_OPTION("", "---")
	VV_DROPDOWN_OPTION(VV_HK_MASS_DEL_TYPE, "Delete all of type")
	VV_DROPDOWN_OPTION(VV_HK_OSAY, "Object Say")

/obj/vv_do_topic(list/href_list)
	if(!(. = ..()))
		return
	if(href_list[VV_HK_OSAY])
		if(check_rights(R_FUN, FALSE))
			usr.client.object_say(src)
	if(href_list[VV_HK_MASS_DEL_TYPE])
		if(check_rights(R_DEBUG|R_SERVER))
			var/action_type = alert("Strict type ([type]) or type and all subtypes?",,"Strict type","Type and subtypes","Cancel")
			if(action_type == "Cancel" || !action_type)
				return

			if(alert("Are you really sure you want to delete all objects of type [type]?",,"Yes","No") != "Yes")
				return

			if(alert("Second confirmation required. Delete?",,"Yes","No") != "Yes")
				return

			var/O_type = type
			switch(action_type)
				if("Strict type")
					var/i = 0
					for(var/obj/Obj in world)
						if(Obj.type == O_type)
							i++
							qdel(Obj)
						CHECK_TICK
					if(!i)
						to_chat(usr, "No objects of this type exist")
						return
					log_admin("[key_name(usr)] deleted all objects of type [O_type] ([i] objects deleted) ")
					message_admins("<span class='notice'>[key_name(usr)] deleted all objects of type [O_type] ([i] objects deleted) </span>")
				if("Type and subtypes")
					var/i = 0
					for(var/obj/Obj in world)
						if(istype(Obj,O_type))
							i++
							qdel(Obj)
						CHECK_TICK
					if(!i)
						to_chat(usr, "No objects of this type exist")
						return
					log_admin("[key_name(usr)] deleted all objects of type or subtype of [O_type] ([i] objects deleted) ")
					message_admins("<span class='notice'>[key_name(usr)] deleted all objects of type or subtype of [O_type] ([i] objects deleted) </span>")

/obj/examine(mob/user)
	. = ..()
//	if(obj_flags & UNIQUE_RENAME)
//		. += "<span class='notice'>Use a pen on it to rename it or change its description.</span>"
	if(unique_reskin && !current_skin)
		. += "<span class='notice'>Alt-click it to reskin it.</span>"

/obj/AltClick(mob/user)
	. = ..()
	if(unique_reskin && !current_skin && user.canUseTopic(src, BE_CLOSE, NO_DEXTERITY))
		reskin_obj(user)

/obj/proc/reskin_obj(mob/M)
	if(!LAZYLEN(unique_reskin))
		return
	to_chat(M, "<b>Reskin options for [name]:</b>")
	for(var/V in unique_reskin)
		var/output = icon2html(src, M, unique_reskin[V])
		to_chat(M, "[V]: <span class='reallybig'>[output]</span>")

	var/choice = input(M,"Warning, you can only reskin [src] once!","Reskin Object") as null|anything in sortList(unique_reskin)
	if(!QDELETED(src) && choice && !current_skin && !M.incapacitated() && in_range(M,src))
		if(!unique_reskin[choice])
			return
		current_skin = choice
		icon_state = unique_reskin[choice]
		to_chat(M, "[src] is now skinned as '[choice].'")

// Should move all contained objects to it's location.
/obj/proc/dump_contents()
	CRASH("Unimplemented.")

/obj/merge_conflict_marker
	name = "---Merge Conflict Marker---"
	desc = "Mapping helper."
	icon = 'icons/obj/merge_conflict_marker.dmi'
	icon_state = "merge_conflict_marker"

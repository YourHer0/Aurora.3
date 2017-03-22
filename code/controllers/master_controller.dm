//simplified MC that is designed to fail when procs 'break'. When it fails it's just replaced with a new one.
//It ensures master_controller.process() is never doubled up by killing the MC (hence terminating any of its sleeping procs)
//WIP, needs lots of work still

var/global/datum/controller/game_controller/master_controller //Set in world.New()

var/global/controller_iteration = 0
var/global/last_tick_duration = 0

var/global/air_processing_killed = 0
var/global/pipe_processing_killed = 0

datum/controller/game_controller
	var/list/shuttle_list	                    // For debugging and VV

datum/controller/game_controller/New()
	//There can be only one master_controller. Out with the old and in with the new.
	if(master_controller != src)
		log_debug("Rebuilding Master Controller")
		if(istype(master_controller))
			qdel(master_controller)
		master_controller = src

	if(!job_master)
		job_master = new /datum/controller/occupations()
		job_master.SetupOccupations()
		job_master.LoadJobs("config/jobs.txt")
		admin_notice("<span class='danger'>Job setup complete</span>", R_DEBUG)

	if(!syndicate_code_phrase)		syndicate_code_phrase	= generate_code_phrase()
	if(!syndicate_code_response)	syndicate_code_response	= generate_code_phrase()

datum/controller/game_controller/proc/setup()
	world.tick_lag = config.Ticklag

	spawn(20)
		createRandomZlevel()

	setup_objects()
	setupgenetics()
	SetupXenoarch()

	transfer_controller = new


datum/controller/game_controller/proc/setup_objects()
	admin_notice("<span class='danger'>Initializing objects</span>", R_DEBUG)
	sleep(-1)
	objects_initialized = 1
	for(var/A in objects_init_list)
		var/atom/movable/object = A
		if(isnull(object.gcDestroyed))
			object.initialize()

	objects_init_list.Cut()

	admin_notice("<span class='danger'>Initializing areas</span>", R_DEBUG)
	sleep(-1)
	for(var/A in all_areas)
		var/area/area = A
		area.initialize()

	admin_notice("<span class='danger'>Initializing pipe networks</span>", R_DEBUG)
	sleep(-1)
	for(var/obj/machinery/atmospherics/machine in machines)
		machine.build_network()

	admin_notice("<span class='danger'>Initializing atmos machinery.</span>", R_DEBUG)
	sleep(-1)
	for(var/obj/machinery/atmospherics/unary/U in machines)
		if(istype(U, /obj/machinery/atmospherics/unary/vent_pump))
			var/obj/machinery/atmospherics/unary/vent_pump/T = U
			T.broadcast_status()
		else if(istype(U, /obj/machinery/atmospherics/unary/vent_scrubber))
			var/obj/machinery/atmospherics/unary/vent_scrubber/T = U
			T.broadcast_status()


	admin_notice(span("danger", "Caching space parallax."))
	create_global_parallax_icons()
	admin_notice(span("danger", "Done."))

	if(config.generate_asteroid)
		var/time = world.time
		// These values determine the specific area that the map is applied to.
		// If you do not use the official Baycode moonbase map, you will need to change them.
		// Create the chasms.
		new /datum/random_map/automata/cave_system/chasms(null,0,0,3,255,255)
		new /datum/random_map/automata/cave_system(null,0,0,3,255,255)
		new /datum/random_map/automata/cave_system/chasms(null,0,0,4,255,255)
		new /datum/random_map/automata/cave_system(null,0,0,4,255,255)
		new /datum/random_map/automata/cave_system/chasms(null,0,0,5,255,255)
		new /datum/random_map/automata/cave_system/high_yield(null,0,0,5,255,255)
		new /datum/random_map/automata/cave_system/chasms/surface(null,0,0,6,255,255)
		// Create the deep mining ore distribution map.
		new /datum/random_map/noise/ore(null, 0, 0, 5, 64, 64)
		new /datum/random_map/noise/ore(null, 0, 0, 4, 64, 64)
		new /datum/random_map/noise/ore(null, 0, 0, 3, 64, 64)
		var/counting_number
		for(var/turf/simulated/open/chasm in total_openspace)
			counting_number += 1
			chasm.update()
		var/counting_result = "Total number of chasms: [counting_number]"
		admin_notice(span("danger", counting_result))
		game_log("ASGEN", counting_result)
		var/msg = "Asteroid generation completed in [(world.time - time) / 10] seconds."
		admin_notice(span("danger", msg))
		game_log("ASGEN", msg)

	admin_notice(span("danger", "Setting up lighting."))
	initialize_lighting()
	admin_notice(span("danger", "Lighting Setup Completed."))

	//Spawn the contents of the cargo warehouse
	sleep(-1)
	spawn_cargo_stock()

	// Set up antagonists.
	populate_antag_type_list()

	//Set up spawn points.
	populate_spawn_points()

	// Setup laws.
	global.corp_regs = new

	admin_notice("<span class='danger'>Initializations complete.</span>", R_DEBUG)
	sleep(-1)

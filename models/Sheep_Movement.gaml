/**
 * Name: SheepMovements
 
 */
model SheepMovements

global {
	// space & time
	geometry shape <- rectangle(800, 600);
	float cell_size <- 4.0;
	// A 10 #h step makes the model meaningless: at walk_speed 1 m/s a sheep covers 36 km
	// in one cycle, and the FSM skips whole days between transitions. For a faster run,
	// lower nb_sheep and shorten the batch "until:" instead.
	float base_step <- 60 #s;
	float step <- base_step;
	date starting_date <- date([2026, 9, 1, 5, 0, 0]);
	float tod -> current_date.hour + current_date.minute / 60.0;
	
	float dt -> step / base_step;
	float slow_factor <- 6.0;
	int last_day <- -1;
	float last_shift <- 0.0;

	// parameters
	string layout <- "realistic" among: ["realistic", "random", "clustered", "regular", "blocks"];
	int nb_sheep <- 75;
	int nb_dogs <- 0;

	// grass & blocks scenario
	bool grass_patches <- false;
	int nb_patches_per_field <- 4;
	float patch_radius <- 25.0 #m;
	float patch_regrowth_factor <- 3.0;
	float poor_regrowth_factor <- 0.3;
	float block_min_size <- 6.0 #m;
	float block_max_size <- 20.0 #m;

	float morning_hour <- 5.0;
	float evening_hour <- 18.5;

	float walk_speed <- 1.0 #m / #s;
	float graze_speed <- 0.5 #m / #s;
	float dog_speed <- 2.0 #m / #s;
	float dog_walk_speed <- 1.0 #m / #s;

	float perception <- 40.0 #m; 
	float cohesion_distance <- 6.0 #m;
	float separation_distance <- 2.5 #m;
	float graze_search <- 20.0 #m;
	float graze_min <- 0.15;              
	float space_per_sheep <- 10.0;        
	float flock_radius <- 40.0 #m;       
	float regroup_distance <- 50.0 #m;   

	// water: the herd drinks TOGETHER, so it never splits between grass at one end of the
	// field and water at the other. A single sheep only breaks away if it gets really thirsty.
	float thirst_trigger <- 0.7;          // above this a sheep wants a drink
	float herd_water_share <- 0.35;       // once this share of the herd is thirsty, the whole herd walks to water
	float lone_thirst <- 1.6;             // a single sheep only leaves the herd for water above this

	// shepherd dog
	float herd_stray_factor <- 1.3;       // past this multiple of flock_radius a sheep counts as a stray
	float herd_push_distance <- 30.0 #m;  // a sheep this close to a herding dog turns back to the herd
	float dog_call_hour <- 5.0;
	float dog_gather_hour <- 18.5;
	point kennel <- {445, 45};
	point gate_spot <- {425, 75};
	float push_distance <- 25.0 #m;
	float follow_distance <- 10.0 #m;
	float dog_follow_distance <- 25.0 #m;
	float leave_prob <- 0.15;
	float follow_prob <- 0.3;

	// stray dog that scares the flock (Extension 3b)
	int nb_stray_dogs <- 1;
	point den <- {40, 480};                // where the stray dog rests, outside the fields
	float stray_run_speed <- 3.0 #m / #s;  // stray dog when approaching / chasing
	float stray_start_hour <- 8.0;         // stray dog only attacks between these hours
	float stray_end_hour <- 17.0;
	float chase_duration <- 10 #mn;        // how long one chase lasts
	float stray_rest <- 2 #h;              // rest between attacks
	float fear_radius <- 30.0 #m;          // sheep closer than this to a stray dog flee
	float flee_speed <- 2.5 #m / #s;
	float flee_distance <- 60.0 #m;        // how far a sheep runs before choosing a new escape point
	float scatter_angle <- 70.0;           // random deviation of the escape direction -> flock breaks apart
	float alarm_range <- 80.0 #m;          // panic can spread only when a stray dog is this close
	float alarm_distance <- 8.0 #m;        // a sheep sees a fleeing neighbour within this distance
	float alarm_prob <- 0.5;               // chance per cycle to join a fleeing neighbour
	float calm_duration <- 5 #mn;          // time without a dog nearby before regrouping
	float regroup_search <- 60.0 #m;       // how far a calm sheep looks for a group to rejoin

	// dog fight: shepherd dog defends the flock against the stray dog
	float guard_range <- 150.0 #m;         // shepherd reacts to an attacking stray dog closer than this
	float defend_speed <- 3.5 #m / #s;     // shepherd running at the intruder
	float fight_distance <- 20.0 #m;       // the two dogs start fighting when this close
	float fight_duration <- 3 #mn;         // how long a dog fight lasts
	float fight_fear_radius <- 45.0 #m;    // sheep closer than this to a fight flee
	float defend_success_prob <- 0.8;      // chance that the shepherd wins
	float chased_cooldown_factor <- 3.0;   // a beaten stray dog rests this many times longer
	float chase_off_distance <- 150.0 #m;  // shepherd stops chasing when the intruder is this far from the flock

	// ------------------------------------------------------------ csv output
	// NOTE: do not name these *_file — "csv_file" and friends are built-in GAML types.
	bool save_csv <- false;                // the batch experiments switch this on
	int save_every <- 240;                 // save a row every N cycles (240 = every 2 simulated hours)
	int next_save <- 240;                  // next cycle to save on; reset to save_every in init
	int run_id <- 0;                       // filled in init: identifies one simulation in the CSV
	string results_path <- "../results/layout_comparison.csv";

	// images (UI from Sheep_Movement.gaml)
	image_file field_img <- image_file("../images/field.jpg");
	image_file home_img <- image_file("../images/home.png");
	image_file crop_img <- image_file("../images/crop.png");
	image_file grass_img <- image_file("../images/grass.png");
	image_file shelter_img <- image_file("../images/shee_shelter.png");
	image_file river_img <- image_file("../images/river.png");
	image_file sheep_img <- image_file("../images/sheep.png");
	image_file dog_img <- image_file("../images/dog.png");           // our shepherd dog
	image_file stray_img <- image_file("../images/stray_dog.png");    // the stray dog that scares the flock
	list<point> crop_pts <- [{40, 110}, {40, 275}, {40, 430}];
	list<point> patch_centres <- [];
	list<list<cell>> patch_cells <- [];

	float w_grass <- 0.8;
	float w_cohesion <- 2.5;  
	float w_separation <- 1.2;
	float w_random <- 0.35; 
	float w_herd <- 2.0; 

	float thirst_rate <- 0.0015;
	// grazing is balanced against regrowth: with 500 sheep the flock eats 2.0 grass units per cycle
	// while the field regrows 3.4, so the pasture as a whole survives, but the patch the flock is
	// standing on is grazed down in about 3 h and needs ~14 h to recover -> the flock must keep moving.
	float eat_rate <- 0.004;         
	float grass_regrowth <- 0.006;  
	float trample_attraction <- 0.08;
	float trample_decay <- 0.998;      
	float min_cost <- 0.15;
	float track_threshold <- 5.0;

	// landscape
	geometry field1 <- rectangle({70, 70}, {330, 450});
	geometry field2 <- rectangle({470, 70}, {730, 450});
	geometry lane <- rectangle({380, 62}, {420, 515});
	geometry pen <- rectangle({370, 20}, {430, 62});
	list<point> field1_gates <- [{330, 130}, {330, 400}];
	list<point> field2_gates <- [{470, 130}, {470, 400}];
	point pen_gate <- {400, 62};

	list<point> tree_pts <- [{100, 110}, {120, 290}, {295, 105}, {285, 240}, {220, 345}, {95, 370}, {150, 210},
		{515, 125}, {560, 100}, {575, 250}, {530, 320}, {690, 330}, {610, 415}, {705, 210}, {505, 420}];
	list<point> rock_pts <- [{140, 105}, {245, 170}, {135, 330}, {700, 115}, {590, 150}, {655, 230}];
	list<point> bush_pts <- [{205, 235}, {255, 290}, {180, 300}, {300, 190}, {640, 280}, {600, 345}, {520, 220}, {700, 390}];
	list<point> log_pts <- [{160, 440}, {675, 300}];
	list<point> border_tree_pts <- [{200, 40}, {250, 35}, {300, 45}, {550, 40}, {620, 30}, {690, 45},
		{40, 200}, {40, 350}, {350, 480}, {450, 480}, {150, 490}, {600, 495}];
	list<string> kind_pool;

	//  state
	list<cell> free_cells;
	list<cell> field1_cells;
	list<cell> field2_cells;
	list<cell> pen_cells;
	map<cell, float> cell_weights;
	string daily_zone <- "field1";
	bool herd_at_water <- false;     
	point herd_water;               
	point herd_goal;                 
	float herd_speed <- 0.6 #m / #s; 
	point flock_centre;
	list<string> out_states <- ["to_pasture", "grazing", "to_grass", "to_water", "drinking", "fleeing", "regrouping"];

	// ------------------------------------------------------------ indicators
	float track_ratio <- 0.0;
	float top5_share <- 0.0;
	int flee_events <- 0;            
	int dog_fights <- 0;             
	int fights_won <- 0;             
	float mean_nn_distance <- 0.0;   

	init {
		run_id <- rnd(1, 1000000);   // drawn here, not in the declaration: one value per simulation
		next_save <- save_every;     // in case an experiment overrides save_every

		create obstacle with: [kind::"river", shape::rectangle({20, 520}, {772, 548}), color::rgb(60, 140, 220)];
//		create obstacle with: [kind::"river", shape::rectangle({745, 15}, {772, 548}), color::rgb(60, 140, 220)];
		create obstacle with: [kind::"pond", shape::(circle(16.0) at_location {175, 135}), color::rgb(60, 140, 220)];
		create obstacle with: [kind::"pond", shape::(circle(12.0) at_location {265, 395}), color::rgb(60, 140, 220)];
		create obstacle with: [kind::"pond", shape::(circle(18.0) at_location {640, 165}), color::rgb(60, 140, 220)];
//		create obstacle with: [kind::"trough", shape::(rectangle(8.0, 3.0) at_location {110, 428}), color::#blue];
//		create obstacle with: [kind::"trough", shape::(rectangle(8.0, 3.0) at_location {700, 432}), color::#blue];
		create obstacle with: [kind::"building", shape::rectangle({45, 20}, {85, 50}), color::rgb(150, 70, 50)];
		create obstacle with: [kind::"building", shape::rectangle({385, 22}, {415, 40}), color::rgb(110, 90, 70)];

		create water_point with: [location::{110, 421}, zone::"field1"];
		create water_point with: [location::{175, 153}, zone::"field1"];
		create water_point with: [location::{265, 409}, zone::"field1"];
		create water_point with: [location::{700, 425}, zone::"field2"];
		create water_point with: [location::{640, 185}, zone::"field2"];
		create water_point with: [location::{400, 512}, zone::"lane"];

		do build_fence(field1, field1_gates);
		do build_fence(field2, field2_gates);
		do build_fence(pen, [pen_gate]);
		create fence with: [shape::(rectangle({12, 12}, {788, 590})).contour];

		kind_pool <- (tree_pts collect "tree") + (rock_pts collect "rock") + (bush_pts collect "bush") + (log_pts collect "log");
		loop p over: border_tree_pts { do create_obstacle("tree", p); }
		do generate_obstacles;

		ask obstacle where each.blocking { ask cell overlapping self { blocked <- true; } }
		ask obstacle where !each.blocking { ask cell overlapping self { base_cost <- max(base_cost, myself.cost); } }
		ask fence { ask cell overlapping self { blocked <- true; } }
		ask cell overlapping lane { base_cost <- 0.6; }

		free_cells <- cell where !each.blocked;
		field1_cells <- free_cells where ((field1 - 6.0) covers each.location);
		field2_cells <- free_cells where ((field2 - 6.0) covers each.location);
		pen_cells <- free_cells where ((pen - 4.0) covers each.location);
		ask water_point { location <- (free_cells closest_to self).location; }
		kennel <- (free_cells closest_to kennel).location;
		gate_spot <- (free_cells closest_to gate_spot).location;
		cell_weights <- free_cells as_map (each::each.base_cost);

		if grass_patches { do create_grass_patches(); }

		// the flock covers an area proportional to its size (e.g. 500 sheep x 25 m² -> radius ~63 m)
		flock_radius <- sqrt(nb_sheep * space_per_sheep / #pi);
		regroup_distance <- flock_radius + 10.0;

		do choose_grazing_area();

		create sheep number: nb_sheep { location <- one_of(pen_cells).location; }
		create dog number: nb_dogs with: [location::kennel];

		den <- (free_cells closest_to den).location;
		create stray_dog number: nb_stray_dogs with: [location::den, rest_until::rnd(stray_rest)];
	}

	// ------------------------------------------------------------ construction helpers
	action build_fence(geometry zone_geom, list<point> gates) {
		geometry g <- zone_geom.contour;
		loop gp over: gates { g <- g - (circle(7.0) at_location gp); }
		create fence with: [shape::g];
	}

	action create_obstacle(string k, point p) {
		create obstacle {
			kind <- k;
			switch k {
				match "tree" { shape <- circle(rnd(2.5, 4.0)) at_location p; color <- rgb(34, 110, 40); }
				match "rock" { shape <- circle(rnd(2.0, 5.0)) at_location p; color <- #gray; }
				match "bush" { shape <- circle(rnd(3.0, 6.0)) at_location p; blocking <- false; cost <- 6.0; color <- rgb(90, 150, 60); }
				match "log" { shape <- (rectangle(12.0, 2.0) rotated_by rnd(180.0)) at_location p; color <- rgb(120, 80, 40); }
				// NEW: solid rectangular block, random size, horizontal or vertical
				match "block" {
					shape <- (rectangle(rnd(block_min_size, block_max_size), rnd(block_min_size / 2, block_max_size / 2))
						rotated_by (flip(0.5) ? 0.0 : 90.0)) at_location p;
					color <- rgb(175, 165, 145);
				}
			}
		}
	}

	bool valid_site(point p) {
		list<point> gates <- field1_gates + field2_gates;
		return (water_point none_matches (each distance_to p < 15.0))
			and (gates none_matches (each distance_to p < 15.0))
			and ((obstacle where (each.kind = "pond")) none_matches (each distance_to p < 8.0));
	}

	point sample_point(geometry f) {
		point p <- any_location_in(f - 10.0);
		loop times: 50 {
			if valid_site(p) { return p; }
			p <- any_location_in(f - 10.0);
		}
		return p;
	}

	// same number of obstacles in every layout, only the spatial distribution (or the type, for "blocks") changes
	action generate_obstacles() {
		if layout = "realistic" {
			loop p over: tree_pts { do create_obstacle("tree", p); }
			loop p over: rock_pts { do create_obstacle("rock", p); }
			loop p over: bush_pts { do create_obstacle("bush", p); }
			loop p over: log_pts { do create_obstacle("log", p); }
		} else {
			int n_per_field <- int(length(kind_pool) / 2);
			list<string> kinds <- (layout = "blocks") ? list_with(length(kind_pool), "block") : shuffle(kind_pool);
			int k_index <- 0;
			loop f over: [field1, field2] {
				list<point> pts <- [];
				switch layout {
					match_one ["random", "blocks"] {
						loop times: n_per_field { add sample_point(f) to: pts; }
					}
					match "clustered" {
						int nb_clusters <- 3;
						list<point> centres <- [];
						loop times: nb_clusters { add sample_point(f) to: centres; }
						loop i from: 0 to: n_per_field - 1 {
							point c <- centres[i mod nb_clusters];
							point p <- c + {gauss(0.0, 12.0), gauss(0.0, 12.0)};
							loop times: 20 {
								if ((f - 10.0) covers p) and valid_site(p) { break; }
								p <- c + {gauss(0.0, 12.0), gauss(0.0, 12.0)};
							}
							add p to: pts;
						}
					}
					match "regular" {
						int nx <- int(ceil(sqrt(n_per_field * f.width / f.height)));
						int ny <- int(ceil(n_per_field / nx));
						float dx <- (f.width - 20.0) / nx;
						float dy <- (f.height - 20.0) / ny;
						point origin <- {f.location.x - f.width / 2 + 10 + dx / 2, f.location.y - f.height / 2 + 10 + dy / 2};
						loop i from: 0 to: nx - 1 {
							loop j from: 0 to: ny - 1 {
								point p <- origin + {i * dx, j * dy};
								if length(pts) < n_per_field and valid_site(p) { add p to: pts; }
							}
						}
					}
				}
				loop p over: pts {
					do create_obstacle(kinds[k_index mod length(kinds)], p);
					k_index <- k_index + 1;
				}
			}
		}
	}

	// NEW: rich grass patches surrounded by poor pasture, inside each fenced field
	action create_grass_patches() {
		list<list<cell>> zones <- [field1_cells, field2_cells];
		loop zc over: zones {
			ask zc { grass <- rnd(0.2, 0.5); }
			loop times: nb_patches_per_field {
				point c <- one_of(zc).location;
				list<cell> pc <- zc where ((each.location distance_to c) < patch_radius);
				ask pc {
					rich <- true;
					grass <- 1.0;
				}
				add c to: patch_centres;
				add pc to: patch_cells;
			}
		}
	}

	// flock-level decisions
	// Pick the next grazing area: the richest grass NEAR the herd, so it drifts from one patch to
	// the next instead of jumping across the field. The rich grass patches are always candidates,
	// which is why the herd now actually walks onto them.
	action choose_grazing_area() {
		list<cell> zc <- (daily_zone = "field1") ? field1_cells : field2_cells;
		if !empty(zc) {
			geometry f <- (daily_zone = "field1") ? field1 : field2;
			list<cell> cand <- 250 among zc;                       // wide sample, not 40
			if grass_patches {
				loop c over: patch_centres {                       // always consider the rich patches
					if f covers c { add (zc closest_to c) to: cand; }
				}
			}
			point from_here <- (flock_centre = nil) ? nil : flock_centre;
			float w_dist <- (from_here = nil) ? 0.0 : 0.0015;      // 0.45 penalty across 300 m
			cell best <- cand with_max_of ((each.grass + sum(each.neighbors collect each.grass) / 8.0)
				- w_dist * ((from_here = nil) ? 0.0 : (each.location distance_to from_here)));
			if best != nil {
				herd_goal <- best.location;
				if flock_centre = nil { flock_centre <- best.location; }   // first call, at init
			}
		}
	}

	// the cells the herd is standing on
	list<cell> herd_cells -> ((daily_zone = "field1") ? field1_cells : field2_cells)
		where (flock_centre != nil and (each.location distance_to flock_centre) < flock_radius);

	// the herd WALKS to its goal: flock_centre creeps towards herd_goal instead of teleporting,
	// so the whole flock moves across the field together and leaves one clear track
	reflex herd_drift when: herd_goal != nil and flock_centre != nil {
		float d <- flock_centre distance_to herd_goal;
		if d > 0.5 {
			float move_by <- min(d, herd_speed * step);
			flock_centre <- flock_centre + (herd_goal - flock_centre) * (move_by / d);
		}
	}

	// date-based, so a changing step cannot break the daily cycle
	reflex new_day when: current_date.day != last_day {
		if cycle > 0 {
			daily_zone <- (mean(field1_cells collect each.grass) >= mean(field2_cells collect each.grass)) ? "field1" : "field2";
			do choose_grazing_area();
		}
		last_day <- current_date.day;
	}

	reflex move_grazing_area when: time - last_shift >= 90 #mn {
		last_shift <- time;
		do choose_grazing_area();
	}

	// the whole herd walks to water together and afterwards moves to a fresh patch of grass
	reflex herd_water_trip when: every(10 #cycles) {
		list<sheep> out <- sheep where (each.state in ["grazing", "to_grass", "to_water", "drinking"]);
		if !empty(out) {
			if !herd_at_water {
				if (out count (each.thirst >= thirst_trigger)) >= herd_water_share * length(out) {
					herd_water <- ((water_point where (each.zone in [daily_zone, "lane"])) closest_to flock_centre).location;
					herd_goal <- herd_water;      // the herd walks there as one, cohesion does the rest
					herd_at_water <- true;
				}
			} else if (out count (each.thirst >= thirst_trigger * 0.5)) < 0.1 * length(out) {
				herd_at_water <- false;           // everyone has drunk: back to the grass
				last_shift <- time;
				do choose_grazing_area();
			}
		}
	}

	// the herd stays together, so it has to move on as one once its own ground is grazed out
	reflex herd_needs_new_patch when: every(20 #cycles) and !herd_at_water {
		list<cell> here <- herd_cells;
		if !empty(here) and mean(here collect each.grass) < graze_min * 1.5 {
			last_shift <- time;
			do choose_grazing_area();
		}
	}

	// slow motion: while a stray dog attacks, or a fight or a stampede is on, the model
	// takes smaller time steps so the flock breaking apart is actually visible
	reflex slow_motion {
		bool action_now <- !empty(stray_dog where (each.state in ["approaching", "chasing", "fighting"]))
			or !empty(dog where (each.state in ["defending", "fighting", "chasing_off"]))
			or !empty(sheep where (each.state = "fleeing"));
		step <- action_now ? base_step / slow_factor : base_step;
	}

	// ------------------------------------------------------------ landscape dynamics
	reflex landscape_dynamics when: every(10 #cycles) {
		ask cell {
			trampling <- trampling * (trample_decay ^ dt);
			float factor <- rich ? patch_regrowth_factor : (grass_patches ? poor_regrowth_factor : 1.0);
			grass <- min(1.0, grass + grass_regrowth * factor * dt * (1.0 - min(1.0, trampling / 30.0)));
		}
	}

	reflex update_costs when: every(60 #cycles) {
		cell_weights <- free_cells as_map (each::max(min_cost, each.base_cost / (1.0 + trample_attraction * each.trampling)));
	}

	// ACTIONS, not reflexes, so the csv export can call them and save fresh numbers.
	// "do indicators;" on a reflex is not valid GAML — only an action can be called.
	action compute_indicators() {
		list<float> tr <- free_cells collect each.trampling;
		float total <- sum(tr);
		track_ratio <- (free_cells count (each.trampling > track_threshold)) / length(free_cells);
		list<float> sorted <- reverse(tr sort_by each);
		int k <- int(0.05 * length(sorted));
		top5_share <- (total > 0 and k > 0) ? sum(copy_between(sorted, 0, k)) / total : 0.0;
	}

	// flock spread: rises when a stray dog breaks the flock, falls again when sheep regroup
	action compute_spread() {
		list<sheep> out <- sheep where (each.state in out_states);
		mean_nn_distance <- (length(out) < 2) ? 0.0
			: mean(out collect (each distance_to ((out - each) closest_to each)));
	}

	reflex indicators when: every(120 #cycles) { do compute_indicators; }

	reflex flock_spread when: every(10 #cycles) { do compute_spread; }

	// ------------------------------------------------------------ csv export
	// Rows are written by the simulation itself while it runs. A reflex in the batch
	// experiment would only run once the simulations are already disposed, so nothing
	// would be saved. Saving periodically also means a run stopped early still leaves data.
	//
	// The ../results folder must exist: GAMA does not create it, and the file is APPENDED
	// to, so delete it before re-running the same experiment.
	//
	// columns: run_id, layout, grass_patches, nb_dogs, nb_stray_dogs,
	//          cycle, sim_day, sim_hour, sim_date,
	//          track_ratio, top5_share, mean_grass, flee_events, mean_nn_distance
	//
	// The schedule uses a plain counter, NOT "every(...)" and NOT "cycle mod n = 0".
	// GAML precedence can read "cycle mod save_every = 0" as "cycle mod (save_every = 0)",
	// which is never true and fails silently. "+" and ">=" cannot be misparsed.
	//
	// NOTE on time: slow_motion changes "step" while a stray dog is active, so "cycle" is
	// NOT proportional to simulated time. Plot against sim_day.
	reflex save_results when: save_csv and cycle >= next_save {
		next_save <- cycle + save_every;
		do compute_indicators;      // refresh, instead of saving a value up to 120 cycles old
		do compute_spread;
		write "saved run " + run_id + " cycle " + cycle + " day " + (time / #day);
		save [run_id, layout, grass_patches, nb_dogs, nb_stray_dogs,
			cycle, time / #day, tod, string(current_date),
			track_ratio, top5_share, mean(cell collect each.grass),
			flee_events, mean_nn_distance]
			to: results_path format: "csv" rewrite: false header: false;
	}
}

// ================================================================ grid
grid cell width: 200 height: 150 neighbors: 8 {
	bool blocked <- false;
	bool rich <- false;   // NEW: part of a rich grass patch
	float grass <- rnd(0.5, 1.0);
	float trampling <- 0.0;
	float base_cost <- 1.0;
	// the farm_view display draws the "ui" aspect below, so no per-cycle grid recolouring is needed
	rgb color -> blend(rgb(165, 125, 75), rgb(70, int(110 + 90 * grass), 50), min(1.0, trampling / 30.0));

	// UI view: transparent overlay on the field image – brown tracks, pale eaten ground
	aspect ui {
		if !blocked {
			float t <- min(1.0, trampling / 30.0);
			if t > 0.15 {
				draw shape color: rgb(140, 100, 60, int(230 * t));
			} else if grass < 0.3 {
				draw shape color: rgb(200, 180, 120, int(160 * (1.0 - grass / 0.3)));
			}
		}
	}
}

// ================================================================ static species
species obstacle {
	string kind;
	bool blocking <- true;
	float cost <- 1.0;
	rgb color <- #gray;
	aspect default { draw shape color: color border: #black; }

	image_file rock0_image_file <- image_file("../images/rock.png");

	image_file water0_image_file <- image_file("../images/water.png");
	image_file trough0_image_file <- image_file("../images/trough.png");
	aspect ui {
		switch kind {
			match_one ["river"] {
//				bool vertical <- shape.height > shape.width;
				draw river_img size: ({700#m, 320#m}) at: (420#m, 0#m);
			}
			match_one ["pond"] {
				draw water0_image_file size: (40#m, 30#m);
			}
			match "building" {
				// farmhouse on the left, sheep shelter at the pen
				draw ((location.x < 200) ? home_img : shelter_img) size: {shape.width * 1.3, shape.height * 1.6} at: location;
			}
			default { 
				draw rock0_image_file size: 20#m;
			}
		}
	}
}

species fence {
	aspect default { draw shape color: rgb(110, 70, 30); }
}

species water_point {
	string zone;
	
	image_file water0_image_file <- image_file("../images/water.png");

	aspect default { 
		draw water0_image_file size: ({40#m, 30#m});
	}
}

// sheep
species sheep skills: [moving] control: fsm {
	float thirst <- rnd(0.0, 0.4);
	float boldness <- rnd(1.0);
	point target;
	int stuck <- 0;
	geometry grazing_bounds;
	float calm_since <- 0.0;  
	float t0 <- 0.0;        
	point threat_pos;      

	//  the dog is pushing this sheep back into the herd
	bool herded -> !empty((dog at_distance herd_push_distance) where (each.state = "herding"));
	// drifted out of the herd on its own (tighter threshold when a dog is on duty)
	bool out_of_herd -> (location distance_to flock_centre)
		> (empty(dog) ? regroup_distance : flock_radius * herd_stray_factor)
		and (herd_goal = nil or (location distance_to herd_goal) > flock_radius);

	// fear: a stray dog is close, a dog fight is close, or a close neighbour is already fleeing
	bool fight_near -> (dog at_distance fight_fear_radius) one_matches (each.state = "fighting");
	bool scared -> !empty(stray_dog) and (
		!empty(stray_dog at_distance fear_radius)
		or fight_near
		or (!empty(stray_dog at_distance alarm_range) and flip(alarm_prob)
			and ((sheep at_distance alarm_distance) one_matches (each.state = "fleeing")))
	);

	bool leave_pen -> (tod >= (empty(dog) ? morning_hour : dog_call_hour) and tod < evening_hour - 1) and (
		empty(dog)
			? (boldness > 0.85 or tod >= morning_hour + 1.0
				or !empty(((sheep at_distance 15.0) - self) where (each.state = "to_pasture")))
			: (((dog one_matches (each.state = "calling_out" and (each distance_to gate_spot) < 20.0)) and flip(leave_prob))
				or tod >= dog_call_hour + 3.0)
	);

	bool go_home -> (tod >= max(evening_hour, dog_gather_hour) + 2.0 or tod < min(morning_hour, dog_call_hour))
		or (empty(dog) and tod >= evening_hour)
		or (!empty(dog) and tod >= dog_gather_hour and (
			(!empty((dog at_distance push_distance) where (each.state = "gathering"))
					or (!empty(((sheep at_distance follow_distance) - self) where (each.state = "to_house")) and flip(follow_prob)))
		));

	reflex metabolism when: state != "in_house" and state != "drinking" {
		thirst <- thirst + thirst_rate * dt;
	}

	action travel_to(point t, float spd) {
		point before <- location;
		do goto target: t on: free_cells speed: spd move_weights: cell_weights recompute_path: false;
		if (location distance_to before) < 0.01 {
			stuck <- stuck + 1;
		} else {
			stuck <- 0;
			ask cell overlapping line([before, location]) { trampling <- trampling + 1.0; }
		}
	}

	// escape point: away from the dog, with an individual random angle, kept inside the current field
	point flee_target() {
		point away <- location - threat_pos;
		float ang <- ((norm(away) > 0) ? atan2(away.y, away.x) : rnd(360.0)) + rnd(-scatter_angle, scatter_angle);
		point desired <- location + ({cos(ang), sin(ang)} * flee_distance);
		geometry field_geom <- (daily_zone = "field1") ? field1 : field2;
		bool in_field <- (field_geom - 4.0) covers location;
		cell c <- cell(desired);
		if in_field and (c = nil or c.blocked or !((field_geom - 6.0) covers desired)) {
			c <- ((daily_zone = "field1") ? field1_cells : field2_cells) closest_to desired;
		} else if c = nil or c.blocked {
			c <- free_cells closest_to desired;
		}
		return c.location;
	}

	// Extension 2 / spec section 3: look for the best grass patch within graze_search.
	// Nearer patches win over slightly richer far ones, so sheep do not cross the whole field.
	point find_grass {
		cell here <- cell(location);
		if here = nil { return grazing_spot(); }
		int radius <- max(2, int(graze_search / cell_size));
		list<cell> cand <- (here neighbors_at radius) where (!each.blocked and each.grass >= graze_min
			and (grazing_bounds != nil ? grazing_bounds covers each.location : true));
		if empty(cand) { return grazing_spot(); }   // this field is grazed out: fall back on the flock
		// stay with the herd: only look outside the flock area when the herd's own ground is bare
		list<cell> in_herd <- cand where ((each.location distance_to flock_centre) < flock_radius);
		if !empty(in_herd) { cand <- in_herd; }
		cell best <- cand with_max_of (each.grass - 0.004 * (each.location distance_to location)
			- 0.006 * (each.location distance_to flock_centre));
		return best.location;
	}

	// random spot inside the flock disc, so arriving sheep spread over the whole grazing area
	point grazing_spot() {
		list<cell> zc <- (daily_zone = "field1") ? field1_cells : field2_cells;
		float a <- rnd(360.0);
		float r <- flock_radius * rnd(1.0) * 0.8; 
		return (zc closest_to (flock_centre + {r * cos(a), r * sin(a)})).location;
	}

	action graze() {
		cell here <- cell(location);
		if here != nil {
			here.grass <- max(0.0, here.grass - eat_rate * dt);
			here.trampling <- here.trampling + 0.05 * dt;

			if flip(0.4) {
				float vx <- 0.0;
				float vy <- 0.0;

				cell best <- (here.neighbors where !each.blocked) with_max_of each.grass;
				if best != nil and best.grass > here.grass + 0.05 {
					float d <- location distance_to best.location;
					if d > 0 {
						vx <- vx + w_grass * (best.location.x - location.x) / d;
						vy <- vy + w_grass * (best.location.y - location.y) / d;
					}
				}

				// stay with the herd: anything past 70% of the flock radius is pulled back in
				float dh <- location distance_to flock_centre;
				if dh > flock_radius * 0.7 and dh > 0 {
					float pull <- w_herd * min(3.0, dh / flock_radius);
					vx <- vx + pull * (flock_centre.x - location.x) / dh;
					vy <- vy + pull * (flock_centre.y - location.y) / dh;
				}

				list<sheep> mates <- ((sheep at_distance perception) - self) where (each.state in ["grazing", "to_grass"]);
				if !empty(mates) {
					point c <- mean(mates collect each.location);
					float dc <- location distance_to c;
					if dc > cohesion_distance {
						vx <- vx + w_cohesion * (c.x - location.x) / dc;
						vy <- vy + w_cohesion * (c.y - location.y) / dc;
					}
					loop m over: mates {
						float dm <- location distance_to m.location;
						if dm < separation_distance and dm > 0 {
							vx <- vx + w_separation * (location.x - m.location.x) / dm;
							vy <- vy + w_separation * (location.y - m.location.y) / dm;
						}
					}
				} else if dh > 0 {
					// no flock mate in sight: head straight back to the herd
					vx <- vx + 3 * w_cohesion * (flock_centre.x - location.x) / dh;
					vy <- vy + 3 * w_cohesion * (flock_centre.y - location.y) / dh;
				}

				vx <- vx + rnd(-w_random, w_random);
				vy <- vy + rnd(-w_random, w_random);

				point old <- location;
				do move speed: graze_speed heading: (self towards (location + {vx, vy})) bounds: grazing_bounds;
				cell now <- cell(location);
				if now = nil or now.blocked { location <- old; }
			}
		}
	}

	state in_house initial: true {
		thirst <- max(0.0, thirst - 0.01);
		transition to: to_pasture when: leave_pen;
	}

	state to_pasture {
		enter { target <- grazing_spot(); stuck <- 0; }
		do travel_to t: target spd: walk_speed;
		if stuck > 10 { target <- grazing_spot(); stuck <- 0; }
		transition to: fleeing when: scared;
		transition to: to_house when: go_home;
		transition to: grazing when: location distance_to target < cell_size;
	}

	state grazing {
		enter { grazing_bounds <- ((daily_zone = "field1") ? field1 : field2) - 4.0; }
		do graze;
		transition to: fleeing when: scared;
		transition to: to_house when: go_home;
		transition to: to_water when: (herd_at_water and thirst >= 0.15) or thirst >= lone_thirst;
		// the dog fetches it, or it has drifted out of the herd by itself
		transition to: to_pasture when: herded or out_of_herd;
		// this patch is grazed out: go and find another one
		transition to: to_grass when: (cell(location) != nil) and (cell(location).grass < graze_min);
	}

	// walking to the grass patch this sheep chose for itself (tramples on the way,
	// so the routes between patches are what become tracks)
	state to_grass {
		enter {
			grazing_bounds <- ((daily_zone = "field1") ? field1 : field2) - 4.0;
			target <- find_grass();
			stuck <- 0;
			t0 <- time;
		}
		do travel_to t: target spd: walk_speed;
		if stuck > 8 { target <- find_grass(); stuck <- 0; }
		transition to: fleeing when: scared;
		transition to: to_house when: go_home;
		transition to: to_water when: (herd_at_water and thirst >= 0.15) or thirst >= lone_thirst;
		transition to: to_pasture when: herded or out_of_herd;
		transition to: grazing when: (location distance_to target < cell_size) or (time - t0 >= 20 #mn);
	}

	state to_water {
		enter {
			target <- (herd_at_water and herd_water != nil) ? herd_water
				: ((water_point where (each.zone in [daily_zone, "lane"])) closest_to self).location;
			stuck <- 0;
		}
		do travel_to t: target spd: walk_speed;
		transition to: fleeing when: scared;
		transition to: to_house when: go_home;
		transition to: to_pasture when: stuck > 30;
		transition to: drinking when: location distance_to target < cell_size;
	}

	state drinking {
		enter { t0 <- time; }
		thirst <- max(0.0, thirst - 0.15 * dt);
		transition to: fleeing when: scared;
		transition to: to_house when: go_home;
		transition to: to_pasture when: time - t0 >= 3 #mn;
	}

	// a stray dog is near: run away, each sheep in its own direction -> the flock breaks apart
	state fleeing {
		enter {
			flee_events <- flee_events + 1;
			calm_since <- time;
			stuck <- 0;
			threat_pos <- (stray_dog closest_to self).location;
			target <- flee_target();
		}
		list<stray_dog> threats <- stray_dog at_distance fear_radius;
		if !(empty(threats) and !fight_near) {
			calm_since <- time;
			threat_pos <- empty(threats) ? (stray_dog closest_to self).location : (threats closest_to self).location;
			if (location distance_to target) < cell_size or stuck > 3 { target <- flee_target(); stuck <- 0; }
		}
		if (location distance_to target) >= cell_size {
			do travel_to t: target spd: flee_speed;   // tramples: panic also leaves tracks
		}
		transition to: regrouping when: time - calm_since >= calm_duration;
	}

	// the dog has gone: walk back to the nearest group, then graze again
	state regrouping {
		enter { t0 <- time; stuck <- 0; }
		list<sheep> group <- ((sheep at_distance regroup_search) - self) where (each.state in ["grazing", "to_grass", "regrouping"]);
		point goal <- empty(group) ? flock_centre : mean(group collect each.location);
		cell gc <- cell(goal);
		if gc = nil or gc.blocked { goal <- (free_cells closest_to goal).location; }
		if (location distance_to goal) > cohesion_distance {
			do travel_to t: goal spd: walk_speed;
		}
		transition to: fleeing when: scared;
		transition to: to_house when: go_home;
		// if the rejoined group is far from the main flock, grazing sends it back via to_pasture
		transition to: grazing when: (location distance_to goal) <= cohesion_distance * 1.5 or time - t0 >= 30 #mn;
	}

	state to_house {
		enter { target <- one_of(pen_cells).location; stuck <- 0; }
		do travel_to t: target spd: walk_speed;
		if stuck > 10 { target <- one_of(pen_cells).location; stuck <- 0; }
		transition to: in_house when: location distance_to target < cell_size;
	}

	aspect default {
		rgb c <- #black;
		switch state {
			match "to_house" { c <- #orange; }
			match "drinking" { c <- #cyan; }
			match "to_water" { c <- rgb(0, 90, 200); }
			match "fleeing" { c <- #red; }
			match "regrouping" { c <- #yellow; }
			match "to_grass" { c <- rgb(40, 130, 40); }
		}
		draw circle(2.5) color: c border: #white;
		draw circle(1.0) at: location + {cos(heading) * 2.5, sin(heading) * 2.5} color: c border: #white;
	}

	// UI view: sheep picture, with a small coloured dot when the sheep is not simply grazing
	aspect ui {
		draw sheep_img size: 6.0;
		switch state {
			match "fleeing" { draw circle(1.3) at: location + {0, -3.5} color: #red; }
			match "regrouping" { draw circle(1.3) at: location + {0, -3.5} color: #yellow; }
			match "to_house" { draw circle(1.3) at: location + {0, -3.5} color: #orange; }
			match "to_grass" { draw circle(1.3) at: location + {0, -3.5} color: rgb(40, 130, 40); }
			match_one ["to_water", "drinking"] { draw circle(1.3) at: location + {0, -3.5} color: #deepskyblue; }
		}
	}
}

// ================================================================ shepherd dog (Extension 3)
species dog skills: [moving] control: fsm {
	point target;
	stray_dog intruder;
	bool won <- false;
	bool resolved <- false;
	float t0 <- 0.0;

	sheep far_sheep;   // the sheep that has wandered furthest out of the herd

	// the sheep furthest outside the herd, or nil when the herd is tidy
	sheep stray_sheep {
		list<sheep> out <- sheep where (each.state in ["grazing", "to_grass"]);
		if empty(out) { return nil; }
		sheep far <- out with_max_of (each distance_to flock_centre);
		return ((far distance_to flock_centre) > flock_radius * herd_stray_factor) ? far : nil;
	}

	// a stray dog is attacking close to this shepherd dog
	bool intruder_near -> (stray_dog where (each.state in ["approaching", "chasing"])) one_matches ((each distance_to self) < guard_range);

	state resting initial: true {
		if (location distance_to kennel) > cell_size {
			do goto target: kennel on: free_cells speed: dog_walk_speed;
		}
		transition to: calling_out when: tod >= dog_call_hour and tod < dog_gather_hour
			and (sheep one_matches (each.state = "in_house"));
		transition to: walking_with when: tod >= dog_call_hour and tod < dog_gather_hour
			and (sheep none_matches (each.state = "in_house"));
		transition to: gathering when: tod >= dog_gather_hour and (sheep one_matches (each.state in out_states));
	}

	state calling_out {
		if (location distance_to gate_spot) > cell_size {
			do goto target: gate_spot on: free_cells speed: dog_speed;
		}
		transition to: defending when: intruder_near;
		transition to: walking_with when: sheep none_matches (each.state = "in_house");
		transition to: gathering when: tod >= dog_gather_hour;
	}

	state walking_with {
		list<sheep> near <- sheep at_distance dog_follow_distance;
		if empty(near) {
			sheep closest <- (sheep where (each.state in out_states)) closest_to self;
			target <- (closest != nil) ? closest.location : flock_centre;
			do goto target: target on: free_cells speed: dog_walk_speed;
		} else {
			point c <- mean(near collect each.location);
			if (location distance_to c) > dog_follow_distance / 2 {
				do goto target: c on: free_cells speed: dog_walk_speed;
			}
		}
		if every(5 #cycles) { far_sheep <- stray_sheep(); }
		transition to: defending when: intruder_near;
		transition to: herding when: far_sheep != nil;
		transition to: gathering when: tod >= dog_gather_hour;
		transition to: resting when: sheep all_match (each.state = "in_house");
	}

	// day work: fetch the sheep that have wandered out of the herd and push them back in
	state herding {
		if every(5 #cycles) { far_sheep <- stray_sheep(); }
		if far_sheep != nil {
			// run to the far side of the stray, so pushing it drives it towards the herd
			point dir <- far_sheep.location - flock_centre;
			float n <- norm(dir);
			point behind <- (n > 0) ? far_sheep.location + dir * (8.0 / n) : far_sheep.location;
			cell c <- cell(behind);
			if c = nil or c.blocked { behind <- far_sheep.location; }
			do goto target: behind on: free_cells speed: dog_speed;
		}
		transition to: defending when: intruder_near;
		transition to: gathering when: tod >= dog_gather_hour;
		transition to: walking_with when: far_sheep = nil;
	}

	state gathering {
		list<sheep> out <- sheep where (each.state in out_states);
		// renamed from "last", which is a built-in GAML operator
		sheep furthest <- empty(out)
			? ((sheep where (each.state = "to_house")) with_max_of (each distance_to gate_spot))
			: (out with_max_of (each distance_to gate_spot));
		if furthest != nil {
			point dir <- furthest.location - gate_spot;
			float n <- norm(dir);
			point behind <- (n > 0) ? furthest.location + dir * (8.0 / n) : furthest.location;
			cell c <- cell(behind);
			if c = nil or c.blocked { behind <- furthest.location; }
			do goto target: behind on: free_cells speed: dog_speed;
		}
		transition to: defending when: intruder_near;
		transition to: resting when: sheep all_match (each.state = "in_house");
	}

	// run at the attacking stray dog
	state defending {
		enter { intruder <- (stray_dog where (each.state in ["approaching", "chasing"])) closest_to self; }
		if intruder != nil {
			do goto target: intruder.location on: free_cells speed: defend_speed;
		}
		transition to: fighting when: intruder != nil and (location distance_to intruder) < fight_distance;
		transition to: walking_with when: intruder = nil or !(intruder.state in ["approaching", "chasing"]);
	}

	// the two dogs fight on the spot; the noise scares nearby sheep (see sheep.fight_near)
	state fighting {
		enter {
			t0 <- time;
			resolved <- false;
			won <- flip(defend_success_prob);
			dog_fights <- dog_fights + 1;
			if won { fights_won <- fights_won + 1; }
			ask intruder { engaged <- true; }
		}
		if intruder != nil {
			location <- intruder.location;                       // the two dogs stay locked together
			if !resolved and (time - t0 >= fight_duration) {
				resolved <- true;
				ask intruder {
					if myself.won { beaten <- true; } else { resume <- true; }
				}
			}
		}
		transition to: walking_with when: intruder = nil;
		transition to: chasing_off when: resolved and won;
		transition to: recovering when: resolved and !won;
	}

	// won: chase the stray dog away from the flock
	state chasing_off {
		if intruder != nil {
			do goto target: intruder.location on: free_cells speed: defend_speed;
		}
		transition to: walking_with when: intruder = nil or intruder.state != "chased_off"
			or (intruder distance_to flock_centre) > chase_off_distance;
	}

	// lost: stay a few minutes, then go back with the flock (and defend again if needed)
	state recovering {
		enter { t0 <- time; }
		transition to: walking_with when: time - t0 >= 5 #mn;
	}

	aspect default {
		rgb c <- #gray;                                        // resting
		switch state {
			match "calling_out"  { c <- #red; }
			match "gathering"    { c <- #red; }
			match "walking_with" { c <- rgb(150, 40, 40); }
			match "herding" { c <- #blue; }
			match_one ["defending", "chasing_off"] { c <- #orangered; }
			match "fighting" { c <- #orange; }
			match "recovering" { c <- #darkgray; }
		}
		if state = "fighting" {
			draw circle(fight_fear_radius) wireframe: true color: #orange; 
			draw circle(6.0) color: rgb(255, 200, 0, 150);
		}
		draw triangle(10.0) rotate: heading + 90 color: c border: #white;
	}

	// UI view: our dog picture, with a coloured dot showing what it is doing
	aspect ui {
		if state = "fighting" {
			draw circle(fight_fear_radius) wireframe: true color: #orange;   
			draw circle(9.0) color: rgb(255, 200, 0, 120);
		}
		if state in ["defending", "chasing_off"] { draw circle(7.0) color: rgb(255, 80, 0, 90); }
		draw dog_img size: 14.0;
		rgb c <- #gray;
		switch state {
			match_one ["calling_out", "gathering"] { c <- #red; }
			match "walking_with" { c <- rgb(150, 40, 40); }
			match "herding" { c <- #blue; }
			match_one ["defending", "chasing_off"] { c <- #orangered; }
			match "fighting" { c <- #orange; }
			match "recovering" { c <- #darkgray; }
		}
		draw circle(2.0) at: location + {0, -8.5} color: c border: #white;
	}
}

// ================================================================ stray dog that scares the flock (Extension 3b)
// resting (den, cooldown) -> approaching (a grazing sheep) -> chasing (nearest sheep) -> leaving (back to den)
species stray_dog skills: [moving] control: fsm {
	point target;
	sheep prey;
	float t0 <- 0.0;
	float rest_until <- 0.0;
	bool engaged <- false;   // set by the shepherd dog when a fight starts
	bool beaten <- false;    // set by the shepherd dog when it wins
	bool resume <- false;    // set by the shepherd dog when it loses
	bool active_time -> tod >= stray_start_hour and tod < stray_end_hour;

	state resting initial: true {
		if (location distance_to den) > cell_size {
			do goto target: den on: free_cells speed: dog_walk_speed;
		}
		transition to: approaching when: active_time and time >= rest_until
			and (sheep one_matches (each.state in ["grazing", "to_grass"]));
	}

	// pick a random grazing sheep and run at it
	state approaching {
		enter { prey <- one_of(sheep where (each.state in ["grazing", "to_grass"])); }
		if prey != nil {
			do goto target: prey.location on: free_cells speed: stray_run_speed;
		}
		transition to: fighting when: engaged;
		transition to: leaving when: prey = nil or !active_time;
		transition to: chasing when: prey != nil and (location distance_to prey) < fear_radius / 2;
	}

	// run at whichever sheep is nearest, scattering the group for a while
	state chasing {
		enter { t0 <- time; }
		sheep nearest <- (sheep where (each.state in out_states)) closest_to self;
		if nearest != nil {
			do goto target: nearest.location on: free_cells speed: stray_run_speed;
		}
		transition to: fighting when: engaged;
		transition to: leaving when: (time - t0 >= chase_duration) or nearest = nil;
	}

	// fighting the shepherd dog: stays on the spot until the shepherd decides the outcome
	state fighting {
		enter { t0 <- time; }
		transition to: chased_off when: beaten;
		transition to: chasing when: resume;
		transition to: leaving when: time - t0 > fight_duration * 3;  
		exit { engaged <- false; beaten <- false; resume <- false; }
	}

	// beaten: run back to the den and stay away much longer
	state chased_off {
		exit { rest_until <- time + stray_rest * chased_cooldown_factor; }
		do goto target: den on: free_cells speed: stray_run_speed;
		transition to: resting when: (location distance_to den) < cell_size;
	}

	// walk away so the sheep can calm down and regroup
	state leaving {
		exit { rest_until <- time + stray_rest; }
		do goto target: den on: free_cells speed: dog_walk_speed;
		transition to: resting when: (location distance_to den) < cell_size;
	}

	aspect default {
		rgb c <- (state in ["approaching", "chasing"]) ? rgb(120, 0, 160) : rgb(90, 60, 110);
		if state in ["approaching", "chasing"] {
			// fear radius ring ("wireframe:" is "empty:" on older GAMA versions)
			draw circle(fear_radius) wireframe: true color: #red;
		}
		draw triangle(12.0) rotate: heading + 90 color: c border: #black;
	}

	// UI view: the stray dog picture, with its fear ring while it is attacking
	aspect ui {
		if state in ["approaching", "chasing"] {
			draw circle(fear_radius) wireframe: true color: #red;  
		}
		draw stray_img size: 15.0;
		rgb c <- (state in ["approaching", "chasing"]) ? #red : ((state = "fighting") ? #orange : rgb(90, 60, 110));
		draw circle(2.0) at: location + {0, -9.0} color: c border: #white;
	}
}

//  experiments
experiment sheep_simulation type: gui {
	parameter "Obstacle layout" var: layout category: "Landscape";
	parameter "Grass patches in fields" var: grass_patches category: "Grass & blocks";
	parameter "Patches per field" var: nb_patches_per_field min: 1 max: 10 category: "Grass & blocks";
	parameter "Patch radius (m)" var: patch_radius min: 10.0 max: 60.0 category: "Grass & blocks";
	parameter "Block min size (m)" var: block_min_size min: 4.0 max: 20.0 category: "Grass & blocks";
	parameter "Block max size (m)" var: block_max_size min: 8.0 max: 40.0 category: "Grass & blocks";
	parameter "Trampling attraction" var: trample_attraction min: 0.0 max: 0.5 category: "Landscape";
	parameter "Trampling decay (per 10 cycles)" var: trample_decay min: 0.99 max: 1.0 category: "Landscape";
	parameter "Number of sheep" var: nb_sheep min: 10 max: 1000 category: "Flock";
	parameter "Perception (m)" var: perception min: 5.0 max: 50.0 category: "Flock";
	parameter "Space per sheep (m²)" var: space_per_sheep min: 5.0 max: 100.0 category: "Flock";
	parameter "Cohesion distance (m)" var: cohesion_distance min: 2.0 max: 40.0 category: "Flock";
	parameter "Separation distance (m)" var: separation_distance min: 1.0 max: 15.0 category: "Flock";
	parameter "Cohesion strength" var: w_cohesion min: 0.0 max: 6.0 category: "Flock";
	parameter "Herd pull strength" var: w_herd min: 0.0 max: 6.0 category: "Flock";
	parameter "Random wandering" var: w_random min: 0.0 max: 2.0 category: "Flock";
	parameter "Stray threshold (x flock radius)" var: herd_stray_factor min: 1.0 max: 4.0 category: "Flock";
	parameter "Herd walking speed (m/s)" var: herd_speed min: 0.1 max: 1.0 category: "Flock";
	parameter "Thirsty above" var: thirst_trigger min: 0.1 max: 1.0 category: "Flock";
	parameter "Herd goes to water at share" var: herd_water_share min: 0.05 max: 1.0 category: "Flock";
	parameter "Grass search radius (m)" var: graze_search min: 8.0 max: 120.0 category: "Grass & blocks";
	parameter "Grazed-out threshold" var: graze_min min: 0.0 max: 0.6 category: "Grass & blocks";
	// only ONE parameter per variable: GAMA rejects a second declaration for eat_rate
	parameter "Eat rate (per 30 s)" var: eat_rate min: 0.0005 max: 0.05 category: "Grass & blocks";
	parameter "Slow-motion factor (stray dog)" var: slow_factor min: 1.0 max: 20.0 category: "Stray dog";
	parameter "Number of dogs" var: nb_dogs min: 0 max: 5 category: "Dog";
	parameter "Push distance (m)" var: push_distance min: 5.0 max: 60.0 category: "Dog";
	parameter "Follow distance (m)" var: follow_distance min: 2.0 max: 30.0 category: "Dog";
	parameter "Dog follow distance (m)" var: dog_follow_distance min: 5.0 max: 100.0 category: "Dog";
	parameter "Herding push distance (m)" var: herd_push_distance min: 5.0 max: 80.0 category: "Dog";
	parameter "Dog: call sheep out at (h)" var: dog_call_hour min: 4.0 max: 12.0 category: "Dog";
	parameter "Dog: bring sheep home at (h)" var: dog_gather_hour min: 12.0 max: 22.0 category: "Dog";
	parameter "Grass regrowth (per 10 cycles)" var: grass_regrowth min: 0.0 max: 0.02 category: "Landscape";
	parameter "Number of stray dogs" var: nb_stray_dogs min: 0 max: 5 category: "Stray dog";
	parameter "Fear radius (m)" var: fear_radius min: 5.0 max: 80.0 category: "Stray dog";
	parameter "Scatter angle (deg)" var: scatter_angle min: 0.0 max: 180.0 category: "Stray dog";
	parameter "Panic spread probability" var: alarm_prob min: 0.0 max: 1.0 category: "Stray dog";
	parameter "Calm time (s)" var: calm_duration min: 30.0 max: 1800.0 category: "Stray dog";
	parameter "Rest between attacks (s)" var: stray_rest min: 600.0 max: 28800.0 category: "Stray dog";
	parameter "Guard range (m)" var: guard_range min: 20.0 max: 400.0 category: "Dog fight";
	parameter "Fight duration (s)" var: fight_duration min: 30.0 max: 900.0 category: "Dog fight";
	parameter "Fight fear radius (m)" var: fight_fear_radius min: 5.0 max: 100.0 category: "Dog fight";
	parameter "Shepherd win probability" var: defend_success_prob min: 0.0 max: 1.0 category: "Dog fight";

	output {
		// picture view with the images from Sheep_Movement.gaml
		display farm_view type: 2d {   // use "type: java2D" on older GAMA versions
			graphics "background" {
				draw field_img size: {world.shape.width, world.shape.height} at: world.location;
				loop p over: crop_pts { draw crop_img size: 22.0 at: p; }
			}
			species cell aspect: ui;          // tracks and eaten ground on top of the field picture
			graphics "grass patches" {
				// each patch picture shrinks as it is eaten and grows back as it regrows
				if !empty(patch_centres) {
					loop i from: 0 to: length(patch_centres) - 1 {
						float g <- mean(patch_cells[i] collect each.grass);
						if g > 0.05 { draw grass_img size: 2 * patch_radius * g at: patch_centres[i]; }
					}
				}
			}
			species fence;
			graphics "gates" {
				loop gp over: field1_gates + field2_gates { draw rectangle(3.0, 14.0) at: gp color: #green border: #darkgreen; }
				draw rectangle(14.0, 3.0) at: pen_gate color: #green border: #darkgreen;
			}
			species obstacle aspect: ui;
			species water_point;
			graphics "kennel and den" {
				draw square(8.0) at: kennel color: rgb(120, 40, 20) border: #black;
				draw circle(6.0) at: den color: rgb(70, 50, 90) border: #black;
			}
			species sheep aspect: ui;
			species dog aspect: ui;
			species stray_dog aspect: ui;
		}
		display flock_disruption refresh: every(10 #cycles) {
			chart "Flock break-up and regrouping" type: series {
				data "Fleeing sheep" value: sheep count (each.state = "fleeing") color: #red;
				data "Regrouping sheep" value: sheep count (each.state = "regrouping") color: #orange;
				data "Mean nearest-neighbour distance (m)" value: mean_nn_distance color: #blue;
			}
		}
		display pathway_indicators refresh: every(120 #cycles) {
			chart "Pathway emergence" type: series {
				data "Track cells (%)" value: track_ratio * 100 color: #brown;
				data "Trampling in top 5% cells (%)" value: top5_share * 100 color: #red;
				data "Mean grass (%)" value: mean(cell collect each.grass) * 100 color: #green;
			}
		}
		display behaviour refresh: every(10 #cycles) {
			chart "Sheep states" type: pie {
				loop s over: ["in_house", "to_pasture", "grazing", "to_grass", "to_water", "drinking", "fleeing", "regrouping", "to_house"] {
					data s value: sheep count (each.state = s);
				}
			}
		}
		monitor "Date" value: current_date;
		monitor "Field today" value: daily_zone;
		monitor "Mean grass" value: mean(cell collect each.grass) with_precision 3;
		monitor "Herd" value: herd_at_water ? "at water"
			: (((herd_goal != nil and flock_centre != nil) and (flock_centre distance_to herd_goal) > 2.0)
				? "moving to new patch" : "grazing");
		monitor "Grass under the herd" value: empty(herd_cells) ? 0.0
			: (mean(herd_cells collect each.grass) with_precision 2);
		monitor "Sheep out of herd" value: sheep count ((each.state in ["grazing", "to_grass"])
			and ((each distance_to flock_centre) > flock_radius * herd_stray_factor));
		monitor "Dog state" value: empty(dog) ? "no dog" : first(dog).state;
		monitor "Sheep in pen" value: sheep count (each.state = "in_house");
		monitor "Speed" value: (step < base_step) ? "SLOW MOTION" : "normal";
		monitor "Stray dog state" value: empty(stray_dog) ? "no stray dog" : first(stray_dog).state;
		monitor "Flee events" value: flee_events;
		monitor "Dog fights (won by shepherd)" value: string(dog_fights) + " (" + string(fights_won) + ")";
	}
}

// NEW: separate simulation button – blocks + grass patches, same displays as sheep_simulation
experiment grass_and_blocks type: gui parent: sheep_simulation {
	action _init_() {
		create simulation with: [layout::"blocks", grass_patches::true];
	}
}

// ---------------------------------------------------------------- batch experiments
// Each simulation writes its own rows (see the save_results reflex in global): a reflex
// here would only run after the simulations have already been disposed.
// The ../results folder must exist beforehand — GAMA does not create it — and each file
// is APPENDED to, so delete it before re-running the same experiment.

// baseline: does obstacle distribution shape pathways?   5 x 5 = 25 runs
experiment layouts_baseline type: batch repeat: 5 keep_seed: false until: time >= 5 #day {
	parameter "Write CSV" var: save_csv among: [true];
	parameter "Results file" var: results_path among: ["../results/baseline.csv"];
	parameter "Obstacle layout" var: layout among: ["realistic", "random", "clustered", "regular", "blocks"];
	parameter "Grass patches" var: grass_patches among: [false];
	parameter "Number of dogs" var: nb_dogs among: [1];
	parameter "Number of stray dogs" var: nb_stray_dogs among: [0];
	method exploration;

	permanent {
		display batch_progress {
			chart "Pathway emergence across runs" type: series {
				data "Track cells (%)" value: (simulations mean_of each.track_ratio) * 100 color: #brown;
				data "Trampling in top 5% (%)" value: (simulations mean_of each.top5_share) * 100 color: #red;
				data "Mean grass (%)" value: (simulations mean_of mean(each.cell collect each.grass)) * 100 color: #green;
			}
		}
	}
}

// Extension 2: vegetation interacting with obstacle distribution   25 runs
experiment layouts_grass type: batch repeat: 5 keep_seed: false until: time >= 5 #day {
	parameter "Write CSV" var: save_csv among: [true];
	parameter "Results file" var: results_path among: ["../results/grass.csv"];
	parameter "Obstacle layout" var: layout among: ["realistic", "random", "clustered", "regular", "blocks"];
	parameter "Grass patches" var: grass_patches among: [true];
	parameter "Number of dogs" var: nb_dogs among: [1];
	parameter "Number of stray dogs" var: nb_stray_dogs among: [0];
	method exploration;

	permanent {
		display batch_progress {
			chart "Pathway emergence across runs" type: series {
				data "Track cells (%)" value: (simulations mean_of each.track_ratio) * 100 color: #brown;
				data "Trampling in top 5% (%)" value: (simulations mean_of each.top5_share) * 100 color: #red;
				data "Mean grass (%)" value: (simulations mean_of mean(each.cell collect each.grass)) * 100 color: #green;
			}
		}
	}
}

// Extension 3: a dog that scares the flock   25 runs
experiment layouts_straydog type: batch repeat: 5 keep_seed: false until: time >= 5 #day {
	parameter "Write CSV" var: save_csv among: [true];
	parameter "Results file" var: results_path among: ["../results/straydog.csv"];
	parameter "Obstacle layout" var: layout among: ["realistic", "random", "clustered", "regular", "blocks"];
	parameter "Grass patches" var: grass_patches among: [false];
	parameter "Number of dogs" var: nb_dogs among: [1];
	parameter "Number of stray dogs" var: nb_stray_dogs among: [1];
	parameter "Save every (cycles)" var: save_every among: [60];   // finer: disruption is a within-day spike
	method exploration;

	permanent {
		display batch_progress {
			chart "Pathway emergence across runs" type: series {
				data "Track cells (%)" value: (simulations mean_of each.track_ratio) * 100 color: #brown;
				data "Trampling in top 5% (%)" value: (simulations mean_of each.top5_share) * 100 color: #red;
			}
		}
		display flock_disruption_batch {
			chart "Flock break-up across runs" type: series {
				data "Mean nearest-neighbour distance (m)" value: simulations mean_of each.mean_nn_distance color: #blue;
				data "Flee events" value: simulations mean_of each.flee_events color: #red;
			}
		}
	}
}

// quick check that the CSV is actually written: 2 combinations, 1 repeat, 1 simulated day
experiment test_csv type: batch repeat: 1 keep_seed: false until: time >= 1 #day {
	parameter "Write CSV" var: save_csv among: [true];
	parameter "Results file" var: results_path among: ["../results/test.csv"];
	parameter "Number of sheep" var: nb_sheep among: [200];
	parameter "Obstacle layout" var: layout among: ["realistic", "clustered"];
	method exploration;

	permanent {
		display batch_progress {
			chart "Track ratio" type: series {
				data "Track cells (%)" value: (simulations mean_of each.track_ratio) * 100 color: #brown;
			}
		}
	}
}
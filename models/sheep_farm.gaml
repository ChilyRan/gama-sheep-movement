/**
 * Name: SheepFarmNinhThuan
 * USTH 2024 - Project 2: Sheep movements
 *
 * How do herd behaviour and pathway tracks emerge from individual sheep behaviours
 * on a GIS-based farm?
 *
 *   Core model   : herd leaves the pen, grazes with flocking, returns at dusk;
 *                  every cell counts trampling; worn cells become cheaper to walk on.
 *   Extension 1  : obstacle types (building, pond, shrub, cactus, rock, tree) and
 *                  obstacle layout (shapefile / random / clustered, same obstacles).
 *   Extension 2  : vegetation quality (attraction), water points (thirst),
 *                  topography from the DEM (uphill penalty), rocky ground (roughness).
 *   Extension 3  : dog (wander / herding) that scares sheep.
 *   Extension 4  : disturbance event (new shrubs appear on the busiest track)
 *                  and path adaptation (trampling decays, route costs are updated daily).
 *
 * Time: 1 cycle = 1 minute, 1440 cycles = 1 day. Simulation starts at 05:00.
 * CRS : all input layers in UTM 49N (EPSG:32649), metres.
 */
model SheepFarmNinhThuan

global {
	//==================== GIS inputs ====================
	file boundary_file   <- shape_file("../includes/field_boundary.shp");
	file pen_file        <- shape_file("../includes/pen.shp");
	file fence_file      <- shape_file("../includes/fences.shp");
	file obstacle_file   <- shape_file("../includes/obstacles.shp");
	file water_file      <- shape_file("../includes/water.shp");
	file vegetation_file <- shape_file("../includes/vegetation.shp");
	file track_file      <- shape_file("../includes/observed_tracks.shp");
	file dem_file        <- grid_file("../includes/dem.asc");

	geometry shape <- envelope(boundary_file);

	//==================== Time ====================
	float step <- 1 #mn;
	int start_hour <- 5;
	int minute_of_day -> (cycle + start_hour * 60) mod 1440;
	int current_day -> int((cycle + start_hour * 60) / 1440);
	float current_hour -> minute_of_day / 60.0;
	float leave_hour <- 6.5;
	float return_hour <- 17.0;
	string period -> (current_hour >= leave_hour and current_hour < return_hour) ? "day" : "night";

	//==================== Herd parameters ====================
	int nb_sheep <- 150;
	float sheep_travel_speed <- 0.5;    // m/s when walking to a target
	float perception_radius <- 15.0;    // m, neighbours used for cohesion
	float p_move_grazing <- 0.35;       // probability to change cell while grazing
	int max_sheep_per_cell <- 3;
	float thirst_rate <- 1.0 / 300;     // thirsty after ~5 h outside
	float eat_rate <- 0.02;

	// weights of the grazing decision
	float w_grass <- 3.0;
	float w_cohesion <- 1.0;
	float w_target <- 0.6;
	float w_path <- 1.5;
	float w_slope <- 2.0;
	float w_crowd <- 1.0;
	float w_fear <- 4.0;

	//==================== Landscape / pathway parameters ====================
	float fence_buffer <- 2.5;          // m, keeps 8-neighbour moves from crossing fences
	float path_threshold <- 50.0;       // passages for a cell to count as a path
	float path_cost_bonus <- 0.7;       // cost reduction on fully worn cells
	float trampling_decay <- 0.97;      // daily decay: unused paths fade
	float regrowth_rate <- 0.002;       // grass per minute

	//==================== Extensions ====================
	string obstacle_source <- "shapefile";  // shapefile, random, clustered   (Ext. 1)
	int nb_clusters <- 5;
	float cluster_spread <- 20.0;
	string dog_mode <- "none";              // none, wander, herding          (Ext. 3)
	float fear_radius <- 25.0;
	bool disturbance_event <- false;        //                                (Ext. 4)
	int disturbance_day <- 15;
	bool show_tracks <- true;
	bool save_daily <- true;

	//==================== Internal state ====================
	geometry field_geom;
	geometry pen_geom;
	geometry track_zone;
	point pen_gate;
	point graze_target;
	float cell_size;
	list<cell> free_cells;
	list<cell> pasture_cells;
	list<cell> pen_cells;
	map<cell, float> cell_weights;
	float total_passages <- 0.0;

	// metrics
	int nb_path_cells <- 0;
	float top5_share <- 0.0;
	float track_ratio <- 0.0;
	string results_file <- "../results/daily_metrics.csv";

	init {
		create farm_boundary from: boundary_file;
		field_geom <- union(farm_boundary collect each.shape);

		create pen from: pen_file with: [gate_x::float(read("gate_x")), gate_y::float(read("gate_y"))];
		pen_geom <- union(pen collect each.shape);
		pen_gate <- {first(pen).gate_x, first(pen).gate_y};

		create fence from: fence_file with: [has_gate::int(read("has_gate"))];
		create water_point from: water_file with: [label::string(read("name"))];
		create vegetation from: vegetation_file with: [quality::string(read("quality")), veg_type::string(read("type"))];
		create observed_track from: track_file;
		create obstacle from: obstacle_file with: [kind::string(read("type")), obs_size::float(read("size_m"))];

		if (obstacle_source != "shapefile") {
			do generate_obstacles;
		}

		cell_size <- first(cell).shape.width;
		do init_cells;
		do update_weights;
		do choose_graze_target;

		create sheep number: nb_sheep {
			current_cell <- one_of(pen_cells);
			location <- any_location_in(current_cell);
			current_cell.nb_sheep <- current_cell.nb_sheep + 1;
		}

		if (dog_mode != "none") {
			create dog {
				location <- (free_cells closest_to pen_gate).location;
			}
		}

		if (save_daily) {
			save "day,cycle,obstacle_source,dog_mode,path_cells,top5_share,track_ratio,passages"
				to: results_file format: "text" rewrite: true;
		}
	}

	//---------- Extension 1: same obstacles, different spatial distribution ----------
	action generate_obstacles {
		list<obstacle> natural <- obstacle where (each.kind in ["shrub", "cactus", "rock", "tree"]);
		list<float> radii <- natural collect sqrt(each.shape.area / #pi);
		list<string> kinds <- natural collect each.kind;
		ask natural {
			do die;
		}
		geometry allowed <- field_geom - (pen_geom + 15.0);
		ask fence {
			allowed <- allowed - (shape + 8.0);
		}
		ask obstacle {
			allowed <- allowed - (shape + 5.0);
		}
		list<point> centers <- [];
		loop i from: 1 to: nb_clusters {
			centers << any_location_in(allowed);
		}
		loop i from: 0 to: length(radii) - 1 {
			point p <- any_location_in(allowed);
			if (obstacle_source = "clustered") {
				point c <- one_of(centers);
				p <- c + {gauss(0.0, cluster_spread), gauss(0.0, cluster_spread)};
				int tries <- 0;
				loop while: !(allowed covers p) and tries < 50 {
					p <- c + {gauss(0.0, cluster_spread), gauss(0.0, cluster_spread)};
					tries <- tries + 1;
				}
				if !(allowed covers p) {
					p <- any_location_in(allowed);
				}
			}
			float r <- radii[i];
			string k <- kinds[i];
			create obstacle {
				kind <- k;
				obs_size <- 2 * r;
				shape <- circle(r) at_location p;
			}
		}
	}

	action init_cells {
		ask cell {
			in_field <- field_geom covers location;
			in_pen <- pen_geom covers location;
			is_free <- in_field;
		}
		// Extension 2: vegetation quality and rough ground
		ask vegetation {
			float q <- (quality = "high") ? 1.0 : ((quality = "medium") ? 0.6 : 0.25);
			ask cell overlapping self {
				if (myself.shape covers location) {
					grass_max <- max(grass_max, q);
					if (myself.veg_type = "rocky") {
						roughness <- 1.5;
					}
				}
			}
		}
		ask cell {
			grass <- grass_max;
			steepness <- max(list<cell>(neighbors) collect abs(each.elevation - elevation)) / cell_size;
		}
		if !empty(observed_track) {
			track_zone <- union(observed_track collect (each.shape + 8.0));
			ask cell {
				near_track <- track_zone covers location;
			}
		}
		do block_cells;
	}

	action block_cells {
		ask obstacle {
			ask cell overlapping self {
				is_free <- false;
			}
		}
		ask fence {
			geometry g <- shape + fence_buffer;
			ask cell overlapping g {
				is_free <- false;
			}
		}
		free_cells <- cell where each.is_free;
		pasture_cells <- free_cells where !each.in_pen;
		pen_cells <- free_cells where each.in_pen;
		ask cell {
			do update_color;
		}
	}

	// route costs used by goto: rough/steep ground costs more, worn paths cost less
	action update_weights {
		ask free_cells {
			float wear <- min(1.0, trampling / path_threshold);
			move_cost <- max(0.2, 1.0 + roughness + w_slope * steepness * 5.0 - path_cost_bonus * wear);
		}
		cell_weights <- free_cells as_map (each::each.move_cost);
	}

	action choose_graze_target {
		vegetation v <- one_of(vegetation where (each.quality = "high"));
		point p <- (v = nil) ? any_location_in(field_geom) : any_location_in(v.shape);
		graze_target <- (pasture_cells closest_to p).location;
	}

	action compute_metrics {
		list<float> tr <- pasture_cells collect each.trampling;
		float total <- sum(tr);
		nb_path_cells <- length(pasture_cells where (each.trampling >= path_threshold));
		if (total > 0) {
			list<float> sorted <- reverse(tr sort_by each);
			int k <- max(1, int(length(sorted) * 0.05));
			top5_share <- sum(copy_between(sorted, 0, k)) / total;
			list<cell> near <- pasture_cells where each.near_track;
			if !empty(near) {
				float share_pass <- sum(near collect each.trampling) / total;
				float share_area <- length(near) / length(pasture_cells);
				track_ratio <- share_pass / share_area;
			}
		}
	}

	//---------- Extension 4: an obstacle appears on the busiest track ----------
	action disturbance {
		cell hot <- pasture_cells with_max_of each.trampling;
		if (hot != nil) {
			loop i from: 1 to: 8 {
				point p <- hot.location + {rnd(-10.0, 10.0), rnd(-10.0, 10.0)};
				create obstacle {
					kind <- "new_shrub";
					obs_size <- 5.0;
					shape <- circle(2.5) at_location p;
				}
			}
			do block_cells;
			ask sheep where (!each.current_cell.is_free) {
				do enter(c: free_cells closest_to location);
			}
			do update_weights;
			write "Day " + current_day + ": disturbance - new shrubs placed on the busiest track at " + hot.location;
		}
	}

	action export_results {
		save (pasture_cells where (each.trampling >= path_threshold)) to: "../results/simulated_paths.shp"
			format: "shp" attributes: ["tramp"::trampling] crs: "EPSG:32649";
		write "Exported simulated paths to results/simulated_paths.shp";
	}

	reflex morning_plan when: minute_of_day = int(leave_hour * 60) - 10 {
		do choose_graze_target;
	}

	reflex new_day when: minute_of_day = 0 and cycle > 0 {
		ask cell {
			trampling <- trampling * trampling_decay;
		}
		do update_weights;
		do compute_metrics;
		if (save_daily) {
			save [current_day, cycle, obstacle_source, dog_mode, nb_path_cells, top5_share, track_ratio, total_passages]
				to: results_file format: "csv" rewrite: false header: false;
		}
		if (disturbance_event and current_day = disturbance_day) {
			do disturbance;
		}
	}
}

//======================================================================
//                              LANDSCAPE
//======================================================================
grid cell file: dem_file neighbors: 8 {
	float elevation <- grid_value;
	bool in_field <- true;
	bool in_pen <- false;
	bool is_free <- true;
	bool near_track <- false;
	float grass <- 0.0;
	float grass_max <- 0.15;     // bare sandy ground by default
	float roughness <- 0.0;
	float steepness <- 0.0;
	float trampling <- 0.0;
	float move_cost <- 1.0;
	int nb_sheep <- 0;

	reflex regrow when: is_free and every(30 #cycle) {
		float wear <- min(1.0, trampling / path_threshold);
		float cap <- grass_max * (1.0 - 0.9 * wear);   // trampled ground stays bare
		grass <- min(cap, grass + regrowth_rate * 30);
		do update_color;
	}

	action update_color {
		if (!in_field) {
			color <- rgb(40, 40, 40);
		} else {
			if (!is_free) {
				color <- rgb(125, 125, 125);
			} else {
				float wear <- min(1.0, trampling / path_threshold);
				// sand (235,220,170) -> grass (90,160,60) -> worn path (130,85,45)
				float r <- 235 - 145 * grass;
				float g <- 220 - 60 * grass;
				float b <- 170 - 110 * grass;
				color <- rgb(int(r * (1 - wear) + 130 * wear), int(g * (1 - wear) + 85 * wear), int(b * (1 - wear) + 45 * wear));
			}
		}
	}

	aspect trampling_map {
		float t <- min(1.0, ln(1 + trampling) / ln(1 + path_threshold * 4));
		draw shape color: (!is_free) ? #black : rgb(int(255 * t), int(200 * t), int(30 + 40 * t));
	}
}

species farm_boundary {
	aspect default {
		draw shape wireframe: true color: #black width: 2;
	}
}

species pen {
	float gate_x;
	float gate_y;
	aspect default {
		draw shape color: rgb(200, 165, 110, 0.35) border: #brown;
	}
}

species fence {
	int has_gate;
	aspect default {
		draw shape + 0.6 color: rgb(110, 62, 30);
	}
}

species obstacle {
	string kind;
	float obs_size;
	aspect default {
		rgb c <- #gray;
		switch kind {
			match "building" { c <- rgb(85, 85, 85); }
			match "pond" { c <- rgb(43, 108, 176); }
			match "shrub" { c <- rgb(31, 93, 31); }
			match "cactus" { c <- rgb(122, 139, 42); }
			match "rock" { c <- rgb(105, 105, 105); }
			match "tree" { c <- rgb(13, 77, 13); }
			match "new_shrub" { c <- #red; }
		}
		draw shape color: c;
	}
}

species water_point {
	string label;
	aspect default {
		draw square(5) color: #cyan border: #black;
	}
}

species vegetation {
	string quality;
	string veg_type;
}

species observed_track {
	aspect default {
		if (show_tracks) {
			draw shape color: #red width: 2;
		}
	}
}

//======================================================================
//                                SHEEP
//======================================================================
species sheep skills: [moving] {
	string activity <- "resting";   // resting, going_out, grazing, drinking, returning
	cell current_cell;
	point travel_target;
	float thirst <- rnd(0.0, 0.3);
	int leave_delay <- rnd(0, 40);   // minutes: sheep do not all leave at once

	action enter(cell c) {
		if (current_cell != nil) {
			current_cell.nb_sheep <- current_cell.nb_sheep - 1;
		}
		if (c != current_cell) {
			c.trampling <- c.trampling + 1.0;
			total_passages <- total_passages + 1;
		}
		c.nb_sheep <- c.nb_sheep + 1;
		location <- any_location_in(c);
		current_cell <- c;
	}

	action set_target(point p, float radius) {
		list<cell> options <- (cell overlapping (circle(radius) at_location p)) where each.is_free;
		travel_target <- empty(options) ? (free_cells closest_to p).location : one_of(options).location;
	}

	action go_home {
		travel_target <- one_of(pen_cells).location;
		activity <- "returning";
	}

	action go_drink {
		water_point w <- water_point closest_to self;
		do set_target(p: w.location, radius: 6.0);
		activity <- "drinking";
	}

	// walking along the cheapest route; every cell crossed gets one passage
	action travel {
		point before <- location;
		path followed <- goto(target: travel_target, on: cell_weights, speed: sheep_travel_speed, return_path: true);
		if (location != before) {
			geometry trace <- (followed != nil and followed.shape != nil) ? followed.shape : line([before, location]);
			cell previous <- current_cell;
			ask cell overlapping trace {
				if (self != previous) {
					trampling <- trampling + 1.0;
					total_passages <- total_passages + 1;
				}
			}
			cell new_cell <- cell(location);
			if (new_cell != nil and new_cell != current_cell) {
				current_cell.nb_sheep <- current_cell.nb_sheep - 1;
				new_cell.nb_sheep <- new_cell.nb_sheep + 1;
				current_cell <- new_cell;
			}
		}
	}

	reflex get_thirsty when: activity != "resting" {
		thirst <- thirst + thirst_rate;
	}

	reflex decide {
		switch activity {
			match "resting" {
				if (period = "day" and minute_of_day >= int(leave_hour * 60) + leave_delay) {
					do set_target(p: graze_target, radius: 20.0);
					activity <- "going_out";
				}
			}
			match "going_out" {
				if (period != "day") {
					do go_home;
				} else {
					if (location distance_to travel_target < 6.0) {
						activity <- "grazing";
					}
				}
			}
			match "grazing" {
				if (period != "day") {
					do go_home;
				} else {
					if (thirst >= 1.0) {
						do go_drink;
					}
				}
			}
			match "drinking" {
				if (location distance_to travel_target < 6.0) {
					thirst <- 0.0;
					if (period = "day") {
						activity <- "grazing";
					} else {
						do go_home;
					}
				}
			}
			match "returning" {
				if (location distance_to travel_target < 6.0) {
					activity <- "resting";
				}
			}
		}
	}

	reflex walk when: activity in ["going_out", "drinking", "returning"] {
		do travel;
	}

	// local decision rule: grass + flocking + herd target + existing paths - slope - crowding - fear
	reflex graze when: activity = "grazing" {
		if (current_cell.grass > 0.0) {
			current_cell.grass <- current_cell.grass - min(eat_rate, current_cell.grass);
		}
		list<dog> dogs_near <- dog at_distance fear_radius;
		bool afraid <- !empty(dogs_near);
		if (afraid or flip(p_move_grazing)) {
			list<sheep> mates <- sheep at_distance perception_radius;
			point center <- empty(mates) ? location : mean(mates collect each.location);
			point danger <- afraid ? mean(dogs_near collect each.location) : location;
			list<cell> options <- list<cell>(current_cell.neighbors) where (each.is_free and !each.in_pen);
			options << current_cell;
			cell best <- nil;
			float best_score <- -#max_float;
			loop c over: options {
				float s <- w_grass * c.grass;
				s <- s - w_cohesion * (c.location distance_to center) / perception_radius;
				s <- s - w_target * (c.location distance_to graze_target) / 100.0;
				s <- s + w_path * min(1.0, c.trampling / path_threshold);
				s <- s - w_slope * max(0.0, c.elevation - current_cell.elevation);
				s <- s - w_crowd * max(0, c.nb_sheep - max_sheep_per_cell + 1);
				s <- s - c.roughness;
				if (afraid) {
					s <- s + w_fear * ((c.location distance_to danger) - (location distance_to danger)) / cell_size;
				}
				s <- s + rnd(0.0, 0.3);
				if (s > best_score) {
					best_score <- s;
					best <- c;
				}
			}
			if (best != nil and best != current_cell) {
				do enter(c: best);
			}
		}
	}

	aspect default {
		draw circle(1.3) color: (activity = "drinking") ? #lightblue : #white border: #black;
	}
}

//======================================================================
//                         DOG (Extension 3)
//======================================================================
species dog skills: [moving] {
	point dog_target;

	reflex act {
		list<sheep> out <- sheep where (each.activity = "grazing");
		if empty(out) {
			do goto target: (free_cells closest_to pen_gate).location on: cell_weights speed: 1.0;
		} else {
			point center <- mean(out collect each.location);
			if (dog_mode = "wander") {
				if (dog_target = nil or location distance_to dog_target < 5.0) {
					dog_target <- (free_cells closest_to (center + {rnd(-60.0, 60.0), rnd(-60.0, 60.0)})).location;
				}
				do goto target: dog_target on: cell_weights speed: 1.2;
			} else {
				// herding: get behind the sheep farthest from the herd and push it back
				sheep far <- out with_max_of (each.location distance_to center);
				float d <- max(1.0, far.location distance_to center);
				point behind <- far.location + ((far.location - center) * (8.0 / d));
				do goto target: (free_cells closest_to behind).location on: cell_weights speed: 1.5;
			}
		}
	}

	aspect default {
		draw triangle(4) color: #black rotate: heading + 90;
	}
}

//======================================================================
//                             EXPERIMENTS
//======================================================================
experiment "Ninh Thuan farm" type: gui {
	parameter "Number of sheep" var: nb_sheep min: 10 max: 500 category: "Herd";
	parameter "Travel speed (m/s)" var: sheep_travel_speed min: 0.1 max: 2.0 category: "Herd";
	parameter "Perception radius (m)" var: perception_radius category: "Herd";
	parameter "Weight: grass" var: w_grass category: "Decision weights";
	parameter "Weight: cohesion" var: w_cohesion category: "Decision weights";
	parameter "Weight: herd target" var: w_target category: "Decision weights";
	parameter "Weight: existing paths" var: w_path category: "Decision weights";
	parameter "Weight: slope" var: w_slope category: "Decision weights";
	parameter "Weight: fear of dog" var: w_fear category: "Decision weights";
	parameter "Path threshold (passages)" var: path_threshold category: "Pathways";
	parameter "Daily trampling decay" var: trampling_decay min: 0.8 max: 1.0 category: "Pathways";
	parameter "Path cost bonus" var: path_cost_bonus min: 0.0 max: 0.8 category: "Pathways";
	parameter "Obstacle layout" var: obstacle_source among: ["shapefile", "random", "clustered"] category: "Extension 1";
	parameter "Number of clusters" var: nb_clusters min: 1 max: 20 category: "Extension 1";
	parameter "Dog behaviour" var: dog_mode among: ["none", "wander", "herding"] category: "Extension 3";
	parameter "Fear radius (m)" var: fear_radius category: "Extension 3";
	parameter "Disturbance event" var: disturbance_event category: "Extension 4";
	parameter "Disturbance day" var: disturbance_day min: 1 max: 100 category: "Extension 4";
	parameter "Show observed tracks" var: show_tracks category: "Display";

	user_command "Export simulated paths (shp)" {
		ask world {
			do export_results;
		}
	}

	output {
		monitor "Day" value: current_day;
		monitor "Hour" value: current_hour with_precision 2;
		monitor "Path cells" value: nb_path_cells;
		monitor "Top 5% cells share of passages" value: top5_share with_precision 3;
		monitor "Track ratio (observed tracks)" value: track_ratio with_precision 2;

		display "Farm" type: 2d {
			grid cell border: nil;
			species farm_boundary;
			species pen;
			species fence;
			species obstacle;
			species water_point;
			species observed_track;
			species sheep;
			species dog;
		}

		display "Trampling map" type: 2d refresh: every(60 #cycle) {
			species cell aspect: trampling_map;
			species fence;
			species observed_track;
		}

		display "Pathway emergence" refresh: every(1440 #cycle) {
			chart "Cells used as paths" type: series {
				data "path cells" value: nb_path_cells color: #brown marker: false;
			}
		}

		display "Concentration" refresh: every(1440 #cycle) {
			chart "Concentration of passages" type: series {
				data "top 5% share" value: top5_share color: #orange marker: false;
				data "track ratio / 10" value: track_ratio / 10 color: #red marker: false;
			}
		}
	}
}

// Extension 1: compare obstacle distributions (same obstacles, different arrangement)
experiment "Batch - obstacle distribution" type: batch repeat: 5 keep_seed: false until: current_day >= 20 {
	parameter "Obstacle layout" var: obstacle_source among: ["shapefile", "random", "clustered"];
	parameter "Save daily" var: save_daily among: [false];
	method exploration;

	reflex save_results {
		ask simulations {
			save [obstacle_source, dog_mode, nb_path_cells, top5_share, track_ratio, total_passages]
				to: "../results/batch_obstacles.csv" format: "csv" rewrite: false header: false;
		}
	}
}

// Extension 3: compare dog behaviours
experiment "Batch - dog" type: batch repeat: 5 keep_seed: false until: current_day >= 20 {
	parameter "Dog behaviour" var: dog_mode among: ["none", "wander", "herding"];
	parameter "Save daily" var: save_daily among: [false];
	method exploration;

	reflex save_results {
		ask simulations {
			save [obstacle_source, dog_mode, nb_path_cells, top5_share, track_ratio, total_passages]
				to: "../results/batch_dog.csv" format: "csv" rewrite: false header: false;
		}
	}
}

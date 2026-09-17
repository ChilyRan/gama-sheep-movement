/**
* Name: SheepMovement
* Based on the internal empty template. 
* Author: Chily RAN, Raingsey SAMOL, Seavchhing KONG, Sopheak Preab, Virakboth NAY
* Tags: Sheep modeling
*/
model FarmModel

global {
	// design layout
	int farm_width <- 4000;
	int farm_height <- 3000;
	
	int fence_width <- 900;
	int fence_height <- 2000;
	
	int home_width <- 700;
	int home_height <- 400;
	
	// Time tracking
	int current_hour <- 6;
    int current_minute <- 30;
    
	geometry shape <- rectangle(farm_width#m, farm_height#m);
	
	init {
		create farm{
			shape <- world.shape;
		}
		create fields;
		create home;
		create crop;
		create fence number: 2;
		create gate number: 2;
			
		loop f over: fence {
			int cell_size <- 50;
			int cols <- int(fence_width / cell_size) - 2;
			int rows <- int(fence_height / cell_size) - 2;
			
			loop col from: 0 to: cols - 1 {
				loop row from: 0 to: rows - 1 {
					create pasture {
						location <- {
							f.location.x - fence_width/2 + cell_size + col * cell_size,
							f.location.y - fence_height/2 + cell_size + row * cell_size
						};
						shape <- circle( 25#m);
					}
				}
			}
		}
		
		create shelter;
		create river number: 2;
		create sheep number: 50;
		create dog number: 1;
	}
	
	reflex update_time {
        current_minute <- current_minute + 1;
	
        if (current_minute = 60) {
            current_minute <- 0;
            current_hour <- current_hour + 1;
        }
	
        if (current_hour = 24) {
            current_hour <- 0;
        }
    }
    

}

species farm {
	
	aspect default {
		draw shape color: #white border: #brown;
	}
	
}

species fields{
	//import image
	image_file field0_image_file <- image_file("../images/field.jpg");
	init{
		location<- {0,0};
	}
	aspect default {
		draw field0_image_file width: farm_width#m;
	}
	
}

species home{
	geometry shape <- rectangle(home_width#m, home_height#m);
	
	init{
		location <- {500, 500};
	}
	aspect default{
		draw shape color: #red border: #brown;
	}
}

// for decoration purposes
species crop{
	geometry shape <- rectangle(500#m, 1200#m);
	init {
		location <- {500, 1700};
	}
	aspect default {
		draw shape color: #green border: #brown;
	}
}

species fence{
	geometry shape <- rectangle(fence_width#m, fence_height#m);
	
	image_file field0_image_file <- image_file("../images/field.jpg");

	init {
		if (self.index = 0) {
			location <- {1500, 1300};
			
		} else {
			location <- {3000, 1300};
		}
//		location <- {0, 0};
	}
	aspect default{
		if (self.index = 0) {
//			draw field0_image_file width: fence_width#m;
			draw shape color: #peru border: #brown;
		}else{
			draw shape color: #peru border: #brown;
		}
	}
	
}

species gate{
	bool open <- false;
	init {

        if (self.index = 0) {
            // Gate of Fence 1
            location <- {1950, 1300};
        } else {
            // Gate of Fence 2
            location <- {2550, 1300};
        }
    }
	aspect default{
		if(open){
			draw rectangle(50#m, 200#m) color: #green border: #green;
		}else{
			draw rectangle(50#m, 200#m) color: #brown border: #brown;
		}
	}
}

species pasture {

	int green_level <- 255;
	float growth_rate <- 10.0 / 1440; // 10 per day (1440 minutes)

	reflex grow {
		green_level <- min([int(green_level + growth_rate), 255]);
	}

	aspect default {
		draw shape color: rgb(0, green_level, 0);
	}
}

species shelter {

	geometry shape <- rectangle(500#m, 300#m);
	init {
		location <- {2250, 200};
	}
	aspect default {
		draw shape color: #gray border: #brown;
	}
}

// just design & layout, not have any action/reflex
species river {


	init {
		if (self.index = 0) {
			// Bottom river
			location <- {2000, 2700};
			shape <- rectangle(3500#m, 50#m);
		} else {
			// Right river
			location <- {3730, 1470};
			shape <- rectangle(50#m, 2500#m);
		}
	}

	aspect default {
		draw shape color: #blue border: #blue;
	}
}

species dog skills: [moving] {
	
	float speed <- 1.5 #m/#s;
	shelter shelter_cell;
	
	init {
		location <- {1500, 100};
	}
	
	// Guide sheep during grazing time
	reflex guide_sheep when: (current_hour > 6 and current_hour < 18) or (current_hour = 6 and current_minute >= 30) or (current_hour = 18 and current_minute < 30) {
		if (!empty(sheep)) {
			point center <- sheep mean_of each.location;
			do goto target: center speed: speed;
		}
	}
	
	// Return to shelter at night
	reflex return_to_shelter when: not ((current_hour > 6 and current_hour < 18) or (current_hour = 6 and current_minute >= 30) or (current_hour = 18 and current_minute < 30)) {
		do goto target: any_location_in(shelter_cell) speed: speed;
	}

	aspect default {
		draw circle(15#m) color: #brown;
	}
}

species sheep skills: [moving] {

	int fence_index <- 0;
	float speed <- 1.0 #m/#s;
	
	shelter shelter_cell;
	
	init {
		location <- any_location_in(shelter_cell);
	}
	
	// Grazing: eat nearby pasture
	reflex graze when: (current_hour > 6 and current_hour < 18) or (current_hour = 6 and current_minute >= 30) or (current_hour = 18 and current_minute < 30) {
		list<pasture> nearby <- pasture at_distance 30#m where (each.green_level > 0);
		if (!empty(nearby)) {
			pasture target <- nearby with_min_of (each distance_to self);
			target.green_level <- max([target.green_level - 5, 0]);
		}
	}
	
	// Move randomly while grazing
	reflex wander_when_grazing when: (current_hour > 6 and current_hour < 18) or (current_hour = 6 and current_minute >= 30) or (current_hour = 18 and current_minute < 30) {
		point new_position <- {
			fence[fence_index].location.x - fence_width/2 + rnd(fence_width),
			fence[fence_index].location.y - fence_height/2 + rnd(fence_height)
		};
		do goto target: new_position speed: speed;
	}
	
	// Sleep in shelter at night
	reflex go_to_shelter when: not ((current_hour > 6 and current_hour < 18) or (current_hour = 6 and current_minute >= 30) or (current_hour = 18 and current_minute < 30)) {
		do goto target: any_location_in(shelter_cell) speed: speed;
	}
	
	// Move to another fence when current is depleted
	reflex switch_fence when: ((current_hour > 6 and current_hour < 18) or (current_hour = 6 and current_minute >= 30) or (current_hour = 18 and current_minute < 30)) {
		int cell_size <- 50;
		int cols <- int(fence_width / cell_size) - 2;
		int rows <- int(fence_height / cell_size) - 2;
		int total_cells <- cols * rows;
		int depleted_cells <- length(pasture where (each.green_level <= 50));
		if (depleted_cells >= total_cells * 0.8) {
			int new_fence <- 1 - fence_index;
			fence_index <- new_fence;
			do goto target: fence[new_fence].location speed: speed;
		}
	}

	aspect default {
		draw triangle(20) color: #black;
	}
}


	experiment FarmSimulation {

	output {
		display map {
			species farm;
			species fields;
			species home;
			species crop;
			species fence;
			species pasture;
			species gate;
			species shelter;
			species river;
			species sheep;
			species dog;
		}
	}
}
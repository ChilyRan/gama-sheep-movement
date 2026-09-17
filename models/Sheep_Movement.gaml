/**
* Name: SheepMovement
* Based on the internal empty template. 
* Author: Chily RAN, Raingsey SAMOL, Seavchhing KONG, Sopheak Preab, Virakboth NAY
* Tags: Sheep modeling
*/
model FarmModel

global {
	int farm_width <- 4000;
	int farm_height <- 3000;
	
	int fence_width <- 900;
	int fence_height <- 2000;
	
	int home_width <- 700;
	int home_height <- 400;

	int current_hour <- 5;
    int current_minute <- 0;
    point shelter_location <- {2250, 2500};
    shelter my_shelter;
    
    
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
//			create grass number: 300 {
//				int column <- self.index mod 15;
//				int row <- int(self.index / 15);
//			
//				location <- {
//					1100 + column * 50,
//					350 + row * 100
//				};
//			}
		loop f over: fence {
			create grass number: 300 {
				location <- {
					f.location.x - fence_width / 2 + rnd(fence_width),
					f.location.y - fence_height / 2 + rnd(fence_height)
				};
			}
	}
		create shelter{
				my_shelter <- self;
			}
			
			create river number: 2;
			create sheep number: 50;
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
//		draw field0_image_file width: farm_width#m;
	}
	
}

species fields{
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

species grass {

	bool eaten <- false;

	aspect default {

		if (!eaten) {

			draw circle(10#m)
				color: #green
				border: #green;
		}
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

species sheep skills: [moving] {

	bool visible <- false;
	bool awake <- false;

	float speed <- 1.0 #m/#s;

	string state <- "sleeping";

	image_file sheep_image <- image_file("../images/sheep_3.jpeg");

	
	init{
		location<- {2000+rnd(500), 50+rnd(300)};
	}


	action wake_up() {

		visible <- true;
		awake <- true;

		state <- "going_to_gate";
	}


	// Wake at 5:00
	reflex sleep_until_5am
		when: current_hour = 5 and not awake {

		do wake_up();
	}


	// =========================
	// Go to Gate 1
	// =========================

	reflex go_to_gate
		when: state = "going_to_gate" {

		do goto
			target: gate[0]
			speed: speed;

		if (self distance_to gate[0] < 50#m) {

			gate[0].open <- true;

			state <- "entering";
		}
	}


	// =========================
	// Enter Fence 1
	// =========================

	reflex enter_fence
		when: state = "entering" {

		do goto
			target: {1500, 1300}
			speed: speed;

		if (self distance_to {1500, 1300} < 100#m) {

			state <- "grazing";
		}
	}


	// =========================
	// Walk inside Fence 1
	// =========================

	reflex walk_inside_fence
		when: state = "grazing" {

		point new_position <- {
			1100 + rnd(750),
			350 + rnd(1900)
		};

		do goto
			target: new_position
			speed: speed;
	}

	// =========================
	// Appearance
	// =========================

	aspect default {

		if (visible) {

			draw triangle(20)
				color: #black;
		}
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
			species grass;
			species gate;
			species shelter;
			species river;
			species sheep;
			
		}
	}
}
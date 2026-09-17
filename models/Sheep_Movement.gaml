/**
* Name: SheepMovement
* Based on the internal empty template. 
* Author: Chily RAN, Raingsey SAMOL, Seavchhing KONG, Sopheak Preab, Virakboth NAY
* Tags: 
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
			create crop_1;
			create crop_2;
			create crop_3;
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
			create grass number: 4000 {
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
//		create dog number: 2;
		
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
	image_file home0_image_file <- image_file("../images/home.png");

//	geometry shape <- rectangle(home_width#m, home_height#m);
	
	init{
		location <- {500, 500};
	}
	aspect default{
		draw home0_image_file size: 600#m;
//		draw shape color: #red border: #brown;
	}
}

species crop{
	
	image_file crop0_image_file <- image_file("../images/crop.png");

//	geometry shape <- rectangle(500#m, 1200#m);
	aspect default {
//		draw shape color: #green border: #brown;
		draw crop0_image_file size: 400#m;
	}
}

species crop_1 parent: crop{
	init {
		location <- {500, 1700};
	}
}
species crop_2 parent: crop{
	init {
		location <- {500, 1300};
	}
	
}
species crop_3 parent: crop{
	init {
		location <- {500, 2100};
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

	image_file grass0_image_file <- image_file("../images/grass.png");

	aspect default {

		if (!eaten) {
			draw grass0_image_file size: 50#m;
			
		}
	}
}

species shelter {

//	geometry shape <- rectangle(500#m, 300#m);

	image_file shee_shelter0_image_file <- image_file("../images/shee_shelter.png");

	init {
		location <- {2250, 300};
	}
	aspect default {
		draw shee_shelter0_image_file size: 500#m;
	}
}


species river {


	image_file river0_image_file <- image_file("../images/river.png");

	init {
		location<-{2500, 1500};
	}

	aspect default {
		draw river0_image_file size: 2500#m;
//		draw shape color: #blue border: #blue;
	}
}

species sheep skills: [moving] {

	bool visible <- false;
	bool awake <- false;

	float speed <- 1.0 #m/#s;

	string state <- "sleeping";

	image_file sheep0_image_file <- image_file("../images/sheep.png");


	
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


	// Go to Gate 1

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


	// Enter Fence 1

	reflex enter_fence
		when: state = "entering" {

		do goto
			target: {1500, 1300}
			speed: speed;

		if (self distance_to {1500, 1300} < 100#m) {

			state <- "grazing";
		}
	}


	// Walk inside Fence 1

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

	// Appearance

	aspect default {

		if (visible) {
			draw sheep0_image_file size: 40#m;
//			draw triangle(20)
//				color: #black;
		}
	}
}

species dog{
	aspect default{
		draw circle(5#m) color: #blue;
	}
}


experiment FarmSimulation {

	output {
		display map {
			species farm;
			species fields;
			species home;
			species crop_2;
			species crop_1;
			species crop_3;
			
			species fence;
			species grass;
			species gate;
			species shelter;
			species river;
			species sheep;
			species dog;
		}
	}
}
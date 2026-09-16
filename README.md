# gama-sheep-movement

## Overview

Welcome to a small digital sheep farm where paths are not painted onto the ground: they emerge one hoofstep at a time.

This project is a GIS-based agent simulation built with [GAMA Platform](https://gama-platform.org/). It explores a simple question with surprisingly complicated answers:

> How do individual sheep behaviours create herd movement patterns and visible pathways across a real landscape?

The sheep leave their pen in the morning, graze during the day, visit water when thirsty, and return home at dusk. Along the way, every passage changes the landscape. Popular routes become cheaper to travel, while unused paths slowly fade. In other words, the sheep are both the travellers and the path designers.

## What happens in the model?

Each sheep makes local decisions based on:

- grass quality and regrowth
- nearby flock members
- the shared grazing target
- existing worn paths
- slope and rocky ground
- crowding in a cell
- thirst and distance to water
- fear of a working dog

The herd is not given a route to follow. Instead, large-scale tracks emerge from many small choices. The model can also introduce a disturbance by placing new shrubs on the busiest track, forcing the herd to adapt.

## Features to explore

The main GUI experiment, **Ninh Thuan farm**, includes:

- 150 sheep by default, adjustable from 10 to 500
- a one-minute simulation step and a 24-hour day
- an 8-neighbour terrain grid generated from a DEM
- fences, a pen, water points, vegetation, obstacles, and observed tracks
- obstacle layouts from a shapefile, random placement, or clusters
- dog behaviour modes: `none`, `wander`, and `herding`
- optional disturbance events during the simulation
- live farm, trampling, pathway, and concentration displays

The model uses UTM Zone 49N coordinates, EPSG:32649, with distances in metres.

## Project layout

```text
gama-sheep-movement/
|-- models/sheep_farm.gaml       # Main GAMA model and experiments
|-- includes/                    # GIS layers and terrain data
|-- results/                     # CSV and exported simulation results
|-- tools/                       # Data-generation utilities
|-- docs/                        # Supporting documentation
`-- README.md
```

Important input layers in `includes/` include:

- `dem.asc`: digital elevation model
- `field_boundary.shp`: farm boundary
- `pen.shp`: sheep pen and gate coordinates
- `fences.shp`: fence lines
- `obstacles.shp`: buildings, ponds, shrubs, rocks, cacti, and trees
- `water.shp`: water points
- `vegetation.shp`: vegetation quality and ground type
- `observed_tracks.shp`: observed movement tracks for comparison

## Run it

1. Install the [GAMA Platform](https://gama-platform.org/).
2. Open this project as a GAMA project.
3. Open `models/sheep_farm.gaml`.
4. Run the **Ninh Thuan farm** GUI experiment.
5. Adjust the sheep, obstacle, dog, pathway, and disturbance parameters.

The model starts at 05:00. Sheep usually leave at 06:30 and return at 17:00. One simulation cycle represents one minute, so 1,440 cycles represent one day.

## What to watch

The displays tell three different stories:

- **Farm** shows the moving sheep, landscape, obstacles, water, fences, and observed tracks.
- **Trampling map** reveals where movement is concentrating.
- **Pathway emergence** and **Concentration** show whether a few tracks are becoming dominant.

At the end of each day, the model records pathway and movement metrics such as:

- number of cells that qualify as paths
- share of passages through the busiest 5% of cells
- similarity between simulated movement and observed tracks
- total passages through the landscape

These values are written to `results/daily_metrics.csv` when daily saving is enabled. Use the **Export simulated paths (shp)** command to export worn cells as `results/simulated_paths.shp`.

## Built-in experiments

- **Ninh Thuan farm**: interactive exploration with live displays.
- **Batch - obstacle distribution**: compares shapefile, random, and clustered obstacle layouts over 20 days.
- **Batch - dog**: compares no dog, wandering dog, and herding dog behaviour over 20 days.

## The big idea

No sheep is trying to build a road. No central controller tells the herd where to walk. Yet repeated local decisions leave a durable signature on the landscape. Change the terrain, the obstacles, the dog, or the sheep's priorities, and the farm writes a different map.

Have fun experimenting - and keep an eye on the paths. They remember where the herd has been.
"# gama-sheep-movement" 

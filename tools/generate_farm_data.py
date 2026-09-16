"""
Generate the GIS inputs for the Sheep Movements GAMA model.

The layout is an ILLUSTRATIVE 400 m x 400 m sheep farm, georeferenced near
Phuoc Dinh / Ninh Phuoc (Ninh Thuan area, Vietnam) in UTM zone 49N (EPSG:32649).
It is NOT digitised from real imagery: replace these layers with ones you draw
in QGIS on a satellite basemap to model a real farm (keep the same file names
and attribute names and the GAMA model works unchanged).

Outputs (in ../includes):
  field_boundary.shp  polygon
  pen.shp             polygon   gate_x, gate_y
  fences.shp          line      has_gate
  obstacles.shp       polygon   type (building|pond|shrub|cactus|rock|tree), size_m
  water.shp           point     name
  vegetation.shp      polygon   quality (high|medium|low), type (grass|rocky)
  observed_tracks.shp line      name
  dem.asc             4 m elevation grid (100 x 100), same extent as the field

Requires: pip install pyshp shapely pyproj numpy
"""
import os
import random
import numpy as np
import shapefile
from shapely.geometry import Polygon, LineString, Point, box
from shapely.affinity import scale
from shapely.geometry.polygon import orient
from pyproj import Transformer

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "includes")
os.makedirs(OUT, exist_ok=True)
random.seed(17)
np.random.seed(17)

# ---------------------------------------------------------------- georeference
LON0, LAT0 = 108.9300, 11.4700          # south-west corner (approximate)
to_utm = Transformer.from_crs("EPSG:4326", "EPSG:32649", always_xy=True)
x0, y0 = to_utm.transform(LON0, LAT0)
X0, Y0 = round(x0), round(y0)            # snap to whole metres
SIZE, CELL = 400, 4

PRJ = ('PROJCS["WGS_1984_UTM_Zone_49N",GEOGCS["GCS_WGS_1984",DATUM["D_WGS_1984",'
       'SPHEROID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],'
       'UNIT["Degree",0.0174532925199433]],PROJECTION["Transverse_Mercator"],'
       'PARAMETER["False_Easting",500000.0],PARAMETER["False_Northing",0.0],'
       'PARAMETER["Central_Meridian",111.0],PARAMETER["Scale_Factor",0.9996],'
       'PARAMETER["Latitude_Of_Origin",0.0],UNIT["Meter",1.0]]')


def g(x, y):
    """local farm coordinates (m) -> UTM"""
    return (X0 + x, Y0 + y)


def poly_utm(p):
    # shapefile convention: exterior ring clockwise
    return [g(x, y) for x, y in orient(p, sign=-1.0).exterior.coords]


def line_utm(l):
    return [g(x, y) for x, y in l.coords]


def write(name, shape_type, fields, records):
    w = shapefile.Writer(os.path.join(OUT, name), shapeType=shape_type)
    for f in fields:
        w.field(*f)
    for geom, attrs in records:
        if shape_type == shapefile.POLYGON:
            w.poly([poly_utm(geom)])
        elif shape_type == shapefile.POLYLINE:
            w.line([line_utm(geom)])
        else:
            w.point(*g(geom.x, geom.y))
        w.record(*attrs)
    w.close()
    with open(os.path.join(OUT, name + ".prj"), "w") as f:
        f.write(PRJ)


# ---------------------------------------------------------------- layout
boundary = Polygon([(0, 8), (392, 0), (400, 395), (6, 400)])

pen = box(30, 30, 90, 80)
pen_gate = (60.0, 80.0)                 # 16 m gap in the north side of the pen

fences = [
    # pen fence, gap between x=52 and x=68 on the north side
    (LineString([(30, 30), (90, 30), (90, 80), (68, 80)]), 1),
    (LineString([(52, 80), (30, 80), (30, 30)]), 1),
    # internal paddock fence (north-south) with a gate at y=140..156
    (LineString([(200, 2), (200, 140)]), 1),
    (LineString([(200, 156), (200, 270)]), 1),
    # northern fence (west-east) with a gate at x=262..278
    (LineString([(200, 300), (262, 300)]), 1),
    (LineString([(278, 300), (399, 300)]), 1),
]

tracks = [
    LineString([(60, 84), (110, 115), (160, 140), (200, 148), (260, 190), (310, 235)]),
    LineString([(60, 84), (75, 150), (95, 240), (110, 320)]),
    LineString([(310, 235), (285, 270), (270, 300), (300, 325), (330, 335)]),
]

obstacles = []
obstacles.append((box(100, 25, 125, 45), "building", 25.0))                      # farmhouse
obstacles.append((scale(Point(300, 90).buffer(1), 26, 16), "pond", 52.0))          # pond

# areas kept free so gates, pen and trough approaches stay open
keep_free = (pen.buffer(12).union(Point(*pen_gate).buffer(18))
             .union(Point(200, 148).buffer(16)).union(Point(270, 300).buffer(16))
             .union(box(95, 20, 130, 50).buffer(4)).union(Point(300, 90).buffer(34))
             .union(Point(330, 335).buffer(10)).union(Point(95, 95).buffer(8))
             .union(Point(270, 112).buffer(8)))
for f, _ in fences:
    keep_free = keep_free.union(f.buffer(6))
track_zone = LineString([(0, 0), (0, 1)]).buffer(0)
for t in tracks:
    track_zone = track_zone.union(t.buffer(7))
inner = boundary.buffer(-8)


def place(kind, n, rmin, rmax, center=None, spread=None):
    placed, tries = 0, 0
    while placed < n and tries < 5000:
        tries += 1
        if center is None:
            x, y = random.uniform(0, SIZE), random.uniform(0, SIZE)
        else:
            x, y = random.gauss(center[0], spread), random.gauss(center[1], spread)
        r = random.uniform(rmin, rmax)
        c = Point(x, y).buffer(r, 12)
        if not inner.contains(c) or c.intersects(keep_free) or c.intersects(track_zone):
            continue
        if any(c.buffer(1.5).intersects(o[0]) for o in obstacles):
            continue
        obstacles.append((c, kind, round(2 * r, 1)))
        placed += 1


place("rock", 14, 1.5, 4.0, center=(140, 250), spread=22)     # rocky outcrop
place("shrub", 22, 1.5, 3.5, center=(330, 180), spread=35)    # shrub cluster east
place("shrub", 14, 1.5, 3.0)                                  # scattered shrubs
place("cactus", 26, 0.8, 1.8)                                 # scattered cacti
place("tree", 8, 3.0, 5.0, center=(150, 60), spread=25)       # shade trees near house

water = [(Point(95, 95), "trough_pen"), (Point(330, 335), "trough_ne"), (Point(270, 112), "pond_edge")]

vegetation = [
    (box(245, 190, 385, 285), "high", "grass"),      # east pasture (behind gate)
    (Polygon([(50, 280), (170, 285), (175, 385), (45, 385)]), "high", "grass"),  # NW pasture
    (box(210, 310, 392, 392), "medium", "grass"),    # north paddock
    (box(15, 90, 195, 270), "medium", "grass"),      # central west
    (box(210, 10, 390, 180), "low", "grass"),        # dry south-east
    (Polygon([(110, 215), (175, 220), (170, 285), (105, 280)]), "low", "rocky"),
]

# ---------------------------------------------------------------- write vectors
write("field_boundary", shapefile.POLYGON, [("name", "C", 20)], [(boundary, ["farm"])])
write("pen", shapefile.POLYGON, [("name", "C", 20), ("gate_x", "N", 12, 2), ("gate_y", "N", 12, 2)],
      [(pen, ["pen", X0 + pen_gate[0], Y0 + pen_gate[1]])])
write("fences", shapefile.POLYLINE, [("has_gate", "N", 1, 0)], [(l, [h]) for l, h in fences])
write("obstacles", shapefile.POLYGON, [("type", "C", 12), ("size_m", "N", 8, 1)],
      [(geom, [k, s]) for geom, k, s in obstacles])
write("water", shapefile.POINT, [("name", "C", 20)], [(p, [n]) for p, n in water])
write("vegetation", shapefile.POLYGON, [("quality", "C", 8), ("type", "C", 8)],
      [(p, [q, t]) for p, q, t in vegetation])
write("observed_tracks", shapefile.POLYLINE, [("name", "C", 20)],
      [(t, [f"track_{i+1}"]) for i, t in enumerate(tracks)])

# ---------------------------------------------------------------- DEM (ESRI ASCII grid)
n = SIZE // CELL
dem = np.zeros((n, n))
for row in range(n):              # row 0 = north
    for col in range(n):
        x = (col + 0.5) * CELL
        y = SIZE - (row + 0.5) * CELL
        z = 18.0 + 0.012 * x + 0.004 * y                                         # gentle slope
        z += 7.0 * np.exp(-((x - 140) ** 2 + (y - 245) ** 2) / (2 * 40 ** 2))    # rocky hill
        z += 3.0 * np.exp(-((x - 330) ** 2 + (y - 60) ** 2) / (2 * 50 ** 2))     # low dune
        dem[row, col] = z
dem += np.random.normal(0, 0.05, dem.shape)
with open(os.path.join(OUT, "dem.asc"), "w") as f:
    f.write(f"ncols {n}\nnrows {n}\nxllcorner {X0}\nyllcorner {Y0}\ncellsize {CELL}\nNODATA_value -9999\n")
    for row in dem:
        f.write(" ".join(f"{v:.2f}" for v in row) + "\n")
with open(os.path.join(OUT, "dem.prj"), "w") as f:
    f.write(PRJ)

print(f"SW corner UTM 49N: {X0}, {Y0}  |  obstacles: {len(obstacles)}")
print("Files written to", os.path.abspath(OUT))

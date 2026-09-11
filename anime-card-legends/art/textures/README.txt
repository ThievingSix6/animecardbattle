SURFACE TEXTURES
================

All optional. Anything missing falls back to the flat colour that was
there before, so the city never breaks for want of a file.

  road.png       the streets and avenues
  sidewalk.png   the ground between them - the block interiors
  grass.png      the land outside the district, under the mountains
  rock.png       the mountains on the horizon

Add <name>_normal.png beside any of them and it is used as a normal
map, which is what makes wet asphalt catch the neon properly.

.png, .jpg, .jpeg and .webp all work.


THEY MUST TILE
--------------

These are repeated across the world, not stretched over it - a road
texture stretched down a 700 m street is a smear. Use a SEAMLESS
texture, or the joins will show as a grid.

One tile covers, in metres:

  road      12
  sidewalk  10
  grass     18
  rock      60

Those are in scripts/lobby3d/textures.gd if a texture wants a
different repeat. 1024x1024 is plenty; 2048 if it is the road, since
that is the one seen up close from a car.


WHERE TO GET THEM
-----------------

ambientCG.com and Poly Haven are both CC0 - free for any use,
no credit required, no licence to track. Search "asphalt", "concrete
pavement", "grass", "rock cliff". Take the 1K or 2K JPG, rename it to
the name above, drop it in.

Textures are TINTED rather than replaced: the city's palette still
reads through whatever photograph gets dropped in, so a daylight
asphalt scan still looks like it belongs in a night city.

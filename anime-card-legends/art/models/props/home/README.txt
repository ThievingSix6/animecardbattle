THE PLAYER'S HOUSE
==================

Two models:

  house.glb      the building that stands in the city
  interior.glb   the room you are put in when you walk through its door

Both are optional. Without house.glb the city uses a generic building;
without interior.glb the inside is a plain lit room. The door works
either way.

SCALE DOES NOT MATTER for either of them. Both are measured after loading
and rescaled - the house to a fixed footprint in the city, the interior
to a room about 22 m across - so models exported in centimetres, metres
or Blender units all land the right size.

THE INTERIOR NEEDS NO COLLISION. An imported .glb has none, so every mesh
inside it is given a collider built from its own triangles when the scene
loads: walls, floor, furniture, whatever is in the model. There is a
floor and four walls underneath that regardless, because a trimesh has no
thickness and a room whose floor is a single plane is a room you can fall
out of where two triangles do not quite meet.

The way back out is a lit pad near the middle of the room. Escape works
too, so nobody is ever stuck inside.

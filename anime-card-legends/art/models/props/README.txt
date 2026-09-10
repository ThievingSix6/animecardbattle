SHARED PROPS
============

Scenery reused across the whole game. Filenames are exact, lowercase.

  building.glb    every building in the city district
  portal.glb      the travel portal, in the city and in every zone
  car.glb         the drivable car parked in the plaza

One building model is enough. The city instances it about forty times
and varies each copy by height (12-34 m), rotation and sign colour, so
one export fills a skyline.

Scale and origin do not matter - each instance is measured and
rescaled. Collision is generated from the fitted bounding box, so
neither model needs collision shapes.

Without these files the city builds itself from boxes and neon, the
portal draws its own ring, and the car drives as a wedge - so
everything works before the art lands.


THE CAR
-------

car.glb is scaled uniformly to 2.7 m long, so it is never stretched,
and is assumed to face -Z (Godot's forward). If it drives backwards,
set MODEL_YAW to PI at the top of scripts/lobby3d/car_body.gd.

Only the shell is needed - no wheels-as-separate-nodes, no collision
shapes, no rig. The physics is four raycasts standing in for
suspension, and the collider is generated. An Octane-shaped single
mesh is exactly right.

Handling constants are all at the top of car_body.gd: drive force, top
speed, grip, jump impulse, flip torque, boost drain. They are grouped
by what they affect so a single number can be tuned without hunting.


EMISSIVE MAPS
=============

Exporters routinely drop the emission slot, so a model arrives with its
glow map sitting beside it as a loose file instead of inside the .glb.
Put it next to the model and it is picked up. Two layouts work:

  1. Rename it after the model:

       art/models/zones/proving.glb
       art/models/zones/proving_emissive.png

  2. Or give the model a folder of its own and keep the original name -
     useful when every exporter calls the file the same thing and
     several cannot share one folder:

       art/models/zones/proving.glb
       art/models/zones/proving/texture_emissive.png

Any file in that folder whose name contains "emissive", "emission" or
"_glow" is used. This works for zone models, props and the player.

A model that already has emission baked into its material is never
overridden - the sidecar only fills in what the export left empty.

The map TINTS the emission rather than adding to it. Godot's default
is the other way round, which makes a white emission colour over a
black mask light the entire model flat white - that is what these
models were doing before, and the maps themselves were never at fault.

To change how hard the sidecar glows, edit EMISSIVE_ENERGY at the top
of scripts/lobby3d/models.gd.

Settings > Assets lists which models loaded and which found an
emissive map, so a misnamed file is visible instead of silently
ignored.

SHARED PROPS
============

Scenery reused across the whole game. Filenames are exact, lowercase.

  building.glb    every building in the city district
  portal.glb      the travel portal, in the city and in every zone

One building model is enough. The city instances it about forty times
and varies each copy by height (12-34 m), rotation and sign colour, so
one export fills a skyline.

Scale and origin do not matter - each instance is measured and
rescaled. Collision is generated from the fitted bounding box, so
neither model needs collision shapes.

Without these files the city builds itself from boxes and neon and the
portal draws its own ring, so everything works before the art lands.


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

To change how hard the sidecar glows, edit EMISSIVE_ENERGY at the top
of scripts/lobby3d/models.gd.

Settings > Assets lists which models loaded and which found an
emissive map, so a misnamed file is visible instead of silently
ignored.

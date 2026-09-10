3D MODELS
=========

Drop files in and the game uses them. Drop nothing in and it keeps
building its own geometry as before. There is no scene to edit, no
node to wire up, and no import step beyond letting Godot import the
file when you copy it in.

WHERE THINGS GO
---------------

  art/models/player.glb            the player character
  art/models/zones/proving.glb     Ashen Proving Grounds
  art/models/zones/hollow.glb      Verdant Hollow
  art/models/zones/emberfall.glb   Emberfall Reach
  art/models/zones/duskmire.glb    Duskmire Bastion
  art/models/zones/choir.glb       Choir of Silence
  art/models/zones/heart.glb       The Tower's Heart

Those six names are the zone ids from scripts/core/campaign.gd. The
filename has to match exactly, all lowercase.

.glb is the format to prefer: one self-contained file with the
textures baked in, so nothing can go missing. .gltf, .obj, .dae,
.fbx, .blend and .tscn also work if Godot can import them.


SCALE DOES NOT MATTER
---------------------

Every model is measured after loading and rescaled to the size the
game wants, then re-seated so its lowest point sits on the ground. A
model exported in centimetres, metres or Blender units all end up
correct. You do not need to match any particular unit or origin.


ZONE MODELS
-----------

One model per zone is enough. It is reused for all seven stages of
that zone and grows as the run goes on:

  stage 1   4.5 m tall
  stage 6   9.5 m tall
  boss     16.0 m tall

Each copy is also rotated a little so seven of the same landmark do
not read as seven of the same landmark. Collision is generated from
the model's own bounding box, so the player cannot walk through it -
your model does not need collision shapes.

The stage's state (cleared / locked / boss) is shown by the light
washing over the model and by the pad it stands on, so your textures
are never recoloured.

To retune the sizes, edit MODEL_HEIGHT_FIRST / MODEL_HEIGHT_LAST /
MODEL_HEIGHT_BOSS at the top of scripts/lobby3d/zone_world.gd.


PLAYER MODEL
------------

art/models/player.glb replaces the placeholder capsule. It is scaled
to 1.9 m tall and should face -Z (Godot's forward). If it runs
backwards, set MODEL_YAW to PI at the top of
scripts/lobby3d/lobby_player.gd.

ANIMATIONS are picked up automatically from the AnimationPlayer that
comes in with the model. Clip names are matched loosely and
case-insensitively, so any of these work:

  idle    matched by a name containing idle, stand or breath
  run     matched by a name containing run, walk, jog, sprint or move
  jump    matched by a name containing jump, fall, air or leap

"Idle", "idle_loop", "Armature|Run" and "CharacterJump" all match.
Anything unmatched is simply left unused - nothing breaks.

When exporting from Blender, tick "Include > Animation" and export
the armature with its actions pushed to NLA strips (or as separate
actions), so the .glb carries the clips.


CHECKING WHAT LOADED
--------------------

Settings > Assets lists which models the game actually found, so a
misnamed file is obvious rather than silently ignored.

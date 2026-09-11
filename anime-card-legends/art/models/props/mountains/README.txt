MOUNTAIN MODELS
===============

Drop any number of .glb files in here and they replace the generated
cones on the horizon. There are no fixed names - the folder IS the
list:

  mountain_a.glb
  ridge.glb
  volcano.glb        ...whatever you call them

Every file becomes a variant, and the ~80 placements around the
district are dealt out between them round-robin, so a ridge is not one
shape repeated. One MultiMesh per variant, so five models still cost
five draw calls rather than eighty.

Scale and origin do not matter; each peak is rescaled to its place in
the ring. Heights vary from about a third to half the district's
half-width, so a model that is wide and flat and one that is tall and
thin will both work - they are stretched to the silhouette, not to
their own proportions.

With this folder empty the horizon builds low-poly cones instead, so
the district always ends in a skyline.

To retune the rings themselves, see PEAKS_NEAR / NEAR_RADIUS /
NEAR_HEIGHT at the top of scripts/lobby3d/horizon.gd.

CITY BUILDINGS
==============

Any number of .glb files, any names. Every file becomes a variant, and
the ~500 lots are dealt out between them, so the district stops being
one shape repeated four hundred times.

One MultiMesh per variant, so ten building models cost ten draw calls
for the whole skyline.

Unlike the props, buildings ARE stretched to fit their lot - a tower is
meant to be told how tall to be. Footprints run 13.5-18.7 m and heights
9-32 m, with the occasional tower to 78 m near the middle. So a model
with a roughly square footprint works best; something long and thin
will be squashed to fit.

With this folder empty the shared props/building.glb is used for
everything, and with neither the city builds from boxes.

Destination buildings are separate: those live in props/buildings/ and
are named after the shop they are.

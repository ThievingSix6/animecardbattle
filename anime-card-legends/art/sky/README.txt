SKY
===

Drop a 360 equirectangular panorama here and the city uses it:

  city.hdr     (or .exr / .png / .jpg — .hdr and .exr look best)

Any panorama in this folder is picked up even if it is named something
else, so a file downloaded from Poly Haven works as-is.

With nothing here the city generates its own night sky: deep navy
overhead, the warm haze a city throws onto its own clouds near the
horizon, and a starfield. That is the sky you are seeing if you have
not added a file.

The older location, res://art/ui/lobby_sky.png, still works.


IF THE SKY IS A FLAT COLOUR
---------------------------

That was a bug, not a missing file: Godot's fog_sky_affect defaults to
1.0, and the sky sits at infinite depth, so exponential fog resolved
to 100% out there and painted the whole sky in the fog colour -
panorama, stars and all. It is set to 0.0 in both worlds now, so fog
still works on geometry and leaves the sky alone.

ZONE TEXTURES
=============

Each campaign zone can have its own ground and stone, so Emberfall is
not the Verdant Hollow with a different light on it.

  <zone>_ground.png   the floor of the zone
  <zone>_stone.png    its pillars, arches, battlements, crystals

The zone ids are the ones from scripts/core/campaign.gd:

  proving     Ashen Proving Grounds
  hollow      Verdant Hollow
  emberfall   Emberfall Reach
  duskmire    Duskmire Bastion
  choir       Choir of Silence
  heart       The Tower's Heart

So: emberfall_ground.png, emberfall_stone.png, and so on.

Add <name>_normal.png beside either for a normal map.


PARTIAL IS FINE
---------------

Anything a zone does not supply falls back to the shared grass.png /
rock.png one folder up, and then to the zone's own palette colour. One
zone can be textured without doing all six.

Textures are TINTED by the zone's palette rather than replacing it, so
a generic rock scan still reads as ashen in the Proving Grounds and as
scorched in Emberfall.

They TILE - one ground tile covers 22 m, one stone tile 14 m - so they
must be seamless. ambientCG.com and Poly Haven are CC0.

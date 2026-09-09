CARD ARTWORK
============

Drop images here and each one becomes a card automatically. Nothing to
register, no list to maintain. Supported: .png .jpg .jpeg .webp

The filename becomes the card name, and everything else about the card
(rarity, role, element, stats, abilities) is derived deterministically
from that filename - so a given image always produces exactly the same
card on every launch and across save files.

  ashen_knight.png            "Ashen Knight", rarity rolled from the name
  ashen_knight_legendary.png  "Ashen Knight" forced to Legendary
  ashen_knight_awakened.png   "Ashen Knight" at Awakened rarity (apex tier)
  ashen_knight_shiny.png      "Ashen Knight" with the Shiny modifier

Rarity suffixes: common, uncommon, rare, epic, legendary, mythic, secret,
awakened. Modifier suffixes: awakened, shiny, golden, corrupted, divine.
Both can be combined, in any order.

To pin a specific image to an existing card, name the file after that
card: "Ashen Knight, the Unbroken" -> ashen_knight_the_unbroken.png

This folder is empty by design. With no art supplied the game still runs -
cards render their frame tinted by element, and the roster is filled by
the procedural generator (see scripts/systems/card_generator.gd).

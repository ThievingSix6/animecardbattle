CITY NPCS
=========

  diablo.glb         Diablo, Lord of Hatred — stands at the tower door
  the_boy.glb        The Boy — roams the district
  the_jokester.glb   The Jokester — turns up somewhere new each visit

Exact filenames, lowercase, underscores. Anything missing shows as a
coloured capsule that still talks, so the writing works before the art
does.

Scale and origin do not matter; each model is measured and rescaled.
Target heights are in scripts/core/npcs.gd if you want to change them.
Models should face -Z, the same as the player.


ANIMATIONS
----------

Clips are matched by keyword, case-insensitively, from whatever
AnimationPlayer comes in with the file:

  idle     idle, stand, breath, talk
  run      run, walk, jog, move
  defeat   defeat, death, die, lose, fall, kneel

"Idle", "run_loop" and "Armature|Defeat" all bind. Unmatched clips are
simply unused.

The Boy's three clips map exactly onto this: his run plays while he
wanders, his idle when you talk to him, and his defeat when you beat
him.

Settings > Assets lists which NPCs loaded and which clips bound.

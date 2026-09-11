SOUND
=====

Drop .ogg, .wav or .mp3 files in here, named exactly. Anything missing
is silence - nothing breaks for want of a sound.

UI AND CARDS
  click            buttons
  hover            mouse over a button
  coin             gold earned
  summon           a pull
  reveal_common    a card turning over, by rarity
  reveal_legendary
  reveal_secret
  levelup
  hit              a strike lands in battle
  ultimate
  victory
  defeat

MUSIC (looped, one at a time)
  music_menu       title and menus
  music_lobby      the city
  music_battle     fights and the arena

THE CAR
  engine_idle      LOOPED. Under the car whenever someone is in it.
  engine           LOOPED. Rises as the car actually moves, and its
                   pitch tracks speed, 0.7x to 2.1x. Record a steady
                   mid-range note rather than a rev - the game does the
                   revving.

  The two crossfade on how much the car is doing, so there is no click
  at the moment it starts rolling.

  boost            Fires on the press.
  boost2           Follows the instant boost ends.
  boost3           LOOPED, from there until the button comes up or the
                   tank runs dry.

  The hand-offs are timed from the files' own lengths, read at load, so
  re-cutting one of them cannot desync the chain. Any of the three
  missing is skipped rather than stalling it.

THE ARENA
  ball_hit_light   Chosen by how much the impact actually changed the
  ball_hit_medium  ball's velocity, with the volume trimmed WITHIN each
  ball_hit_hard    band - so the quietest hard hit is not as loud as
                   the hardest, and the change between bands is not
                   audible as a switch.

  soccar_crowd     LOOPED, quiet, under the whole match. Swells for a
                   few seconds on a goal, a win, a hard hit or a near
                   miss, then settles back.
  soccar_lets_go   Kickoff.
  soccar_goal      A goal.
  soccar_gasp      A shot past the goal line and outside the posts -
                   the one that was nearly something.
  soccar_game_win  Winning the match.
  30_second_warning  The clock crossing half a minute.

Looping is set in code, not in the import settings, so a plain export
works - no need to mark loop points.

.ogg is the one to prefer: it loops cleanly and stays small.


WHERE TO GET THEM
-----------------

freesound.org (check each licence) and Kenney.nl (CC0, no credit
required) both have engine loops and impacts.

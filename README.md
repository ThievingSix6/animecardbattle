# Anime Card Legends

A gacha auto-battler: summon a roster, build a five-card team, and fight it
through six zones. Combat resolves automatically — the player's decisions are
which cards to pull, merge, and field, and which passives they bring.

This repository holds two things:

| Path                  | What it is                                                        |
| --------------------- | ----------------------------------------------------------------- |
| `anime-card-legends/` | The **Godot 4.5** source project (the game proper)                 |
| `web/`                | A **standalone browser prototype** — no Godot required             |

---

## Run the browser prototype

You do **not** need Godot, and you do not need to install the game engine.
Node 18+ is the only requirement.

```bash
cd web
npm install
npm run dev
```

Then open the URL Vite prints (default <http://localhost:5173>) in Firefox or
Chrome.

### Production build

```bash
cd web
npm install
npm run build
npm run preview
```

`npm run preview` serves the built output at <http://localhost:4173>.

### No-server option

The production build is a **single self-contained HTML file** — all JavaScript
and CSS are inlined, and there are no external asset requests. After
`npm run build` you can simply double-click:

```
web/dist/index.html
```

It runs directly from `file://` with no server and no tooling.

### Headless tests

```bash
cd web
npm run simulate   # balance: win rate and pacing per zone
npm run skills     # exercises all 100 passives
```

`simulate` runs the real battle engine against the real enemy factory across a
stage and a boss from every zone, and fails on fights that stall or end in one
hit. `skills` wraps every passive so its hooks report when they run, fights it
against opponents that burn, stun and block, and fails if any hook never fires
or any skill throws — card text is generated from these mechanics, so a dead
skill is a card lying to the player.

---

## Controls

| Input               | Action                                           |
| ------------------- | ------------------------------------------------ |
| Mouse               | Click anything — nav tabs, cards, stages, buttons |
| `1` – `6`           | Jump to Lobby / Campaign / Team / Collection / Summon / Talents |
| `Enter` / `Space`   | Activate the focused card                        |
| `Esc`               | Close a dialog, or return to the Lobby           |
| `Tab`               | Move focus between cards and buttons             |

---

## What the prototype demonstrates

The full gameplay loop, not a mockup:

- **Lobby** — live stats and a summon feed that fills as cards auto-roll in
- **Summon** — single and ten-pulls against origin banners, priced in gems;
  roll packs earned from boss floors resolve millions of rolls statistically
- **Collection** — sortable grid, per-card detail with real pull odds, the
  card's passive and its family, sell, and merge-to-ascend at 100 copies
- **Team builder** — pick up to five cards; lane order decides who fights first
- **Campaign** — six zones of seven stages, each ending in a boss; clear a
  zone's boss to open the next
- **Battle** — the two active duelists centre stage with the rest of each team
  on a bench. Front cards trade blows, basic abilities fire on a cadence,
  ultimates at full energy, passives trigger, summons join the back of the
  lane, and a fallen card is replaced permanently by the next
- **Passive skills** — 100 across nine families (defense, offense, element,
  death, summon, support, control, risk, legendary). Every card carries one
- **Victory / defeat** — gem and gold rewards, roll packs on boss floors, and
  a next-stage / retry flow
- **Talents** — spend gold to speed up rolls, improve luck, and roll multiple
  cards per tick
- **Weather events** — timed global events that boost one element's pull rate

Balance is ported verbatim from the Godot project's `Config`, so the two play
the same. The starting team clears the opening stages reliably, hits a wall at
the first zone boss, and cannot progress past the second zone without summoning
and merging.

### Skills are turn-based

The skill designs are written for a real-time game — "for 4 seconds", "every 10
seconds", movement speed, knockback — but combat resolves in discrete turns.
Rather than rewrite the engine (every balance number assumes turns), each
concept is translated, and `src/game/combatant.ts` documents the mapping in one
place: two seconds is one turn, attack speed becomes ultimate charge rate,
movement speed becomes the speed stat that decides turn order. Displacement has
no turn-based analogue, so those skills grant stun resistance instead of
claiming an effect the simulation does not run.

---

## Project layout

### Godot project (`anime-card-legends/`)

```
project.godot          Godot 4.5, main scene = scenes/SaveSlots.tscn
                       autoloads: EventBus, UITheme, GameState, Audio
scenes/                12 scenes (SaveSlots, Main, Lobby, Campaign, Zone,
                       Battle, ...)
scripts/
  core/                config.gd (all tuning), campaign.gd (the six zones),
                       skills.gd (the 100 passives), event_bus, save_manager,
                       routes, mutations, audio, fmt
  models/card_data.gd  the CardData resource
  systems/             card_generator, card_library, gacha, collection,
                       progression, equipment, weather
  battle/              battle_sim (rules), combatant, skill_effects (what
                       each passive does), enemy_factory, battle_card
  screens/             one script per scene
  ui/                  design.gd (tokens), card_view, card_art, widgets, theme
  lobby3d/             3D hub world and the six campaign zone worlds
art/                   cards/ (drop-in artwork), icons/, ui/, fonts/
tools/check_gdscript.py  static checker — run before opening Godot
```

Validate the Godot source with:

```bash
cd anime-card-legends
python3 tools/check_gdscript.py
```

### Browser prototype (`web/`)

```
index.html
src/
  main.ts              app shell, router, keyboard, wallet, game loop
  game/                pure logic, no DOM — ported 1:1 from GDScript
    config.ts          <- scripts/core/config.gd
    design.ts          <- scripts/ui/design.gd
    battleSim.ts       <- scripts/battle/battle_sim.gd
    combatant.ts       <- scripts/battle/combatant.gd
    skills.ts          <- scripts/core/skills.gd + battle/skill_effects.gd
    campaign.ts        <- scripts/core/campaign.gd
    enemyFactory.ts    <- scripts/battle/enemy_factory.gd
    cardGenerator.ts   <- scripts/systems/card_generator.gd
    gacha.ts           <- scripts/systems/gacha.gd
    collection.ts      <- scripts/systems/collection.gd
    progression.ts     <- scripts/systems/progression.gd
    mutations.ts       <- scripts/core/mutations.gd
    weather.ts         <- scripts/systems/weather.gd
    gameState.ts       <- scripts/game_state.gd
  ui/                  screens, card rendering, design tokens as CSS
scripts/simulate.mjs   headless balance test
scripts/skill-check.mjs  headless skill coverage test
```

---

## Adding card artwork

Drop images into `anime-card-legends/art/cards/` and each becomes a card
automatically — the filename becomes the card name, and rarity, role, element,
stats, and abilities are derived deterministically from it, so a given image
always produces the same card. Suffixes set rarity and modifiers
(`ashen_knight_legendary.png`, `ashen_knight_shiny.png`). See the README in that
folder for the full convention.

The browser prototype ships no artwork; cards render an element-tinted frame
with role and element sigils instead.

---

## Known limitations

- **No save/load in the browser prototype.** The Godot project has a full save
  slot system (`scripts/core/save_manager.gd`); the prototype keeps everything
  in memory, so a refresh restarts the run.
- **No equipment.** `scripts/systems/equipment.gd` (crafting and stat bonuses)
  is not ported.
- **No 3D zones in the browser.** The Godot build has six walkable 3D zone
  worlds (`scripts/lobby3d/zone_world.gd`, generated from primitives with no
  imported art); the prototype uses a 2D stage select.
- **No audio.** The Godot project has an audio bus; the prototype is silent.
- **The prototype ships no card artwork,** so cards use generated frames rather
  than images.
- **The Godot project has not been run in this environment** — Godot is not
  installed here. It is validated statically with `tools/check_gdscript.py`,
  which passes, and every `res://` path resolves, but the editor has not opened
  the scenes and the 3D zones have not been walked. The skill library was
  generated from the prototype's tested copy and cross-checks identical, but no
  battle has been fought in the engine itself.

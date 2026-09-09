# Anime Card Legends

A gacha auto-battler: summon a roster, build a five-card team, and send it up a
50-floor tower. Combat resolves automatically — the player's decisions are which
cards to pull, merge, and field.

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

### Headless combat test

```bash
cd web
npm run simulate
```

Runs the real battle engine against the real enemy factory across ten tower
floors and reports win rate, round count, and average damage. Use it to catch
balance regressions without opening a browser.

---

## Controls

| Input               | Action                                           |
| ------------------- | ------------------------------------------------ |
| Mouse               | Click anything — nav tabs, cards, floors, buttons |
| `1` – `6`           | Jump to Lobby / Tower / Team / Collection / Summon / Talents |
| `Enter` / `Space`   | Activate the focused card                        |
| `Esc`               | Close a dialog, or return to the Lobby           |
| `Tab`               | Move focus between cards and buttons             |

---

## What the prototype demonstrates

The full gameplay loop, not a mockup:

- **Lobby** — live stats and a summon feed that fills as cards auto-roll in
- **Summon** — single and ten-pulls against origin banners, priced in gems;
  roll packs earned from boss floors resolve millions of rolls statistically
- **Collection** — sortable grid, per-card detail with real pull odds, sell,
  and merge-to-ascend at 100 copies
- **Team builder** — pick up to five cards; lane order decides who fights first
- **Tower** — 50 floors, every fifth a boss, floors unlock as you clear them
- **Battle** — automatic lane combat: front cards trade blows, basic abilities
  fire on a cadence, ultimates at full energy, passives (guardian intercepts,
  lifesteal, energy surge) trigger, and a fallen card is replaced by the next
- **Victory / defeat** — gem and gold rewards, roll packs on boss floors, and
  a next-floor / retry flow
- **Talents** — spend gold to speed up rolls, improve luck, and roll multiple
  cards per tick
- **Weather events** — timed global events that boost one element's pull rate

Balance is ported verbatim from the Godot project's `Config`, so the two play
the same. The starting team clears floors 1–3 reliably, fights the floor-5 boss
at roughly 80%, and cannot beat floor 10 — you have to summon and merge to
progress.

---

## Project layout

### Godot project (`anime-card-legends/`)

```
project.godot          Godot 4.5, main scene = scenes/SaveSlots.tscn
                       autoloads: EventBus, UITheme, GameState, Audio
scenes/                10 scenes (SaveSlots, Main, Lobby, Battle, Tower, ...)
scripts/
  core/                config.gd (all tuning), event_bus, save_manager,
                       routes, mutations, audio, fmt
  models/card_data.gd  the CardData resource
  systems/             card_generator, card_library, gacha, collection,
                       progression, equipment, weather
  battle/              battle_sim (rules), combatant, enemy_factory, battle_card
  screens/             one script per scene
  ui/                  design.gd (tokens), card_view, card_art, widgets, theme
  lobby3d/             3D hub world
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
    battleSim.ts       <- scripts/battle/battle_sim.gd + combatant.gd
    enemyFactory.ts    <- scripts/battle/enemy_factory.gd
    cardGenerator.ts   <- scripts/systems/card_generator.gd
    gacha.ts           <- scripts/systems/gacha.gd
    collection.ts      <- scripts/systems/collection.gd
    progression.ts     <- scripts/systems/progression.gd
    mutations.ts       <- scripts/core/mutations.gd
    weather.ts         <- scripts/systems/weather.gd
    gameState.ts       <- scripts/game_state.gd
  ui/                  screens, card rendering, design tokens as CSS
scripts/simulate.mjs   headless combat test
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
- **No 3D lobby.** The Godot hub world in `scripts/lobby3d/` is replaced by a
  2D lobby screen.
- **No audio.** The Godot project has an audio bus; the prototype is silent.
- **The prototype ships no card artwork,** so cards use generated frames rather
  than images.
- **The Godot project has not been run in this environment** — Godot is not
  installed here. It is validated statically with `tools/check_gdscript.py`,
  which passes, but the editor has not opened the scenes.

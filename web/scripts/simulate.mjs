// Headless smoke test for the combat rules.
//
//   npm run simulate
//
// Runs the real BattleSim against the real EnemyFactory across a spread of
// tower floors and reports win rate, round count, and damage spread. Catches
// balance regressions (fights that never end, or end in one hit) without
// opening a browser.

import { build } from "esbuild";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const src = resolve(here, "../src/game");

const bundle = await build({
  entryPoints: [resolve(src, "index.ts")],
  bundle: true,
  write: false,
  format: "esm",
  platform: "neutral",
  target: "es2020",
});

const code = bundle.outputFiles[0].text;
const mod = await import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}`);

const { BattleSim, buildFloor, ProgressionSystem, buildStarters } = mod;

const FLOORS = [1, 3, 5, 10, 15, 20, 25, 30, 40, 50];
const RUNS = 60;
const MAX_ROUNDS = 500;

let failures = 0;

console.log("floor  win%   avg rounds   avg dmg/hit   result");
console.log("-".repeat(58));

for (const floor of FLOORS) {
  const progression = new ProgressionSystem();
  let wins = 0;
  let totalRounds = 0;
  let totalDamage = 0;
  let totalHits = 0;
  let stalled = 0;

  for (let run = 0; run < RUNS; run++) {
    const sim = new BattleSim();
    sim.setup(buildStarters(), buildFloor(floor, progression));

    let ended = null;
    sim.on((e) => {
      if (e.type === "ended") ended = e.playerWon;
      if (e.type === "attack") { totalDamage += e.damage; totalHits++; }
      if (e.type === "ability") { totalDamage += e.damage * e.targets.length; totalHits += e.targets.length; }
    });

    let rounds = 0;
    while (sim.running && rounds < MAX_ROUNDS) {
      const order = sim.prepareRound();
      if (!sim.running || order.length === 0) break;
      for (const side of order) {
        sim.takeTurn(side);
        if (!sim.running) break;
      }
      rounds++;
    }

    if (rounds >= MAX_ROUNDS) stalled++;
    if (ended === true) wins++;
    totalRounds += rounds;
  }

  const winPct = (wins / RUNS) * 100;
  const avgRounds = totalRounds / RUNS;
  const avgDmg = totalHits > 0 ? totalDamage / totalHits : 0;

  let verdict = "ok";
  if (stalled > 0) { verdict = `STALLED ${stalled}/${RUNS}`; failures++; }
  else if (avgRounds < 2) { verdict = "TOO FAST"; failures++; }

  console.log(
    `${String(floor).padStart(5)}  ${winPct.toFixed(0).padStart(4)}%  ${avgRounds.toFixed(1).padStart(10)}  ${avgDmg.toFixed(0).padStart(12)}   ${verdict}`,
  );
}

console.log("-".repeat(58));

if (failures > 0) {
  console.error(`\n${failures} floor(s) failed the sanity check.`);
  process.exit(1);
}

// The starting team must lose eventually, or the tower has no difficulty curve.
console.log("\nStarter team stats:");
for (const c of buildStarters()) {
  console.log(`  ${c.cardName.padEnd(20)} ${c.role.padEnd(9)} atk ${String(c.attack).padStart(4)}  def ${String(c.defense).padStart(4)}  hp ${String(c.health).padStart(5)}  spd ${c.speed}`);
}
console.log("\nAll floors resolved without stalling.");

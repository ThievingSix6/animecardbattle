// Exercises every skill in the library.
//
//   npm run skills
//
// Each skill is wrapped so its hooks report when they run, then fought in
// scenarios that can actually satisfy their triggers — the enemy team is
// seeded with burn, stun and block so reactive skills have something to
// react to. A skill that throws, stalls the battle, or whose hooks never
// run at all is a bug: card text is generated from these mechanics, so a
// dead skill is a card lying to the player.

import { build } from "esbuild";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const src = resolve(here, "../src/game");

const bundle = await build({
  entryPoints: [resolve(src, "index.ts")],
  bundle: true, write: false, format: "esm", platform: "neutral", target: "es2020",
});
const mod = await import(
  `data:text/javascript;base64,${Buffer.from(bundle.outputFiles[0].text).toString("base64")}`
);

const { BattleSim, buildFloor, ProgressionSystem, buildStarters, Skills, makeCard } = mod;

const RUNS = 14;
const MAX_ROUNDS = 400;

// Enemies that can burn, stun and block, so reactive hooks get triggers.
const FOIL_SKILLS = ["cinderbrand", "crushing_blow", "ironhide", "silencer", "third_strike"];

// Instrument every hook so "did this run" is measured, not inferred.
const fired = new Map();
for (const skill of Skills.ALL_SKILLS) {
  fired.set(skill.id, new Set());
  for (const [name, fn] of Object.entries(skill.hooks)) {
    skill.hooks[name] = (ctx) => {
      fired.get(skill.id).add(name);
      return fn(ctx);
    };
  }
}

const declared = new Map(
  Skills.ALL_SKILLS.map((s) => [s.id, Object.keys(s.hooks)]),
);

function teamWith(skillId) {
  return buildStarters().map((card, i) =>
    makeCard({ ...card, cardId: `${card.cardId}_t${i}`, skillId }),
  );
}

function foilTeam(floor, progression) {
  return buildFloor(floor, progression).map((card, i) =>
    makeCard({ ...card, skillId: FOIL_SKILLS[i % FOIL_SKILLS.length] }),
  );
}

const broken = [];
const stalled = [];

for (const skill of Skills.ALL_SKILLS) {
  const progression = new ProgressionSystem();
  let error = null;
  let stall = false;

  for (let run = 0; run < RUNS && !error; run++) {
    const sim = new BattleSim();
    // Alternate floors so both easy and losing fights are covered: death
    // and ally-death hooks only run when somebody actually dies.
    const floor = run % 2 === 0 ? 6 : 14;
    sim.setup(teamWith(skill.id), foilTeam(floor, progression));

    try {
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
      if (rounds >= MAX_ROUNDS) stall = true;
    } catch (e) {
      error = e;
    }
  }

  if (error) broken.push([skill, error]);
  else if (stall) stalled.push(skill);
}

const silent = Skills.ALL_SKILLS.filter((s) => {
  const ran = fired.get(s.id);
  return declared.get(s.id).some((h) => !ran.has(h));
});

const total = Skills.ALL_SKILLS.length;
console.log(`Skill library: ${total} skills across ${Object.keys(Skills.FAMILY_LABEL).length} families\n`);
for (const family of Object.keys(Skills.FAMILY_LABEL)) {
  console.log(`  ${Skills.FAMILY_ICON[family]} ${Skills.FAMILY_LABEL[family].padEnd(10)} ${Skills.skillsInFamily(family).length}`);
}
console.log("");

if (broken.length) {
  console.log(`THREW (${broken.length}):`);
  for (const [s, e] of broken) console.log(`  ${s.id.padEnd(22)} ${e.message}`);
}
if (stalled.length) {
  console.log(`STALLED (${stalled.length}):`);
  for (const s of stalled) console.log(`  ${s.id}`);
}
if (silent.length) {
  console.log(`HOOKS NEVER RAN (${silent.length}):`);
  for (const s of silent) {
    const missing = declared.get(s.id).filter((h) => !fired.get(s.id).has(h));
    console.log(`  ${s.id.padEnd(22)} ${s.family.padEnd(10)} ${missing.join(", ")}`);
  }
}

const untexted = Skills.ALL_SKILLS.filter((s) => !s.text || s.text.length < 10);
if (untexted.length) {
  console.log(`MISSING TEXT (${untexted.length}):`);
  for (const s of untexted) console.log(`  ${s.id}`);
}

const unreachable = [];
for (const [role, families] of Object.entries(Skills.ROLE_FAMILIES)) {
  for (const f of families) {
    if (Skills.skillsInFamily(f).length === 0) unreachable.push(`${role} -> ${f}`);
  }
}
if (unreachable.length) console.log("UNREACHABLE FAMILIES:", unreachable.join(", "));

const failures = broken.length + stalled.length + silent.length + untexted.length + unreachable.length;
if (failures > 0) {
  console.error(`\n${failures} problem(s) found.`);
  process.exit(1);
}

console.log(`All ${total} skills ran every declared hook without error.`);

// Distribution sanity: what a real roster actually rolls.
const counts = {};
let withSkill = 0;
const used = new Set();
for (let i = 0; i < 600; i++) {
  const card = mod.generateOne(used);
  if (!card || !card.skillId) continue;
  withSkill++;
  const s = Skills.skillById(card.skillId);
  counts[s.family] = (counts[s.family] ?? 0) + 1;
}
console.log(`\nOf 600 generated cards, ${withSkill} rolled a passive:`);
for (const [family, n] of Object.entries(counts).sort((a, b) => b[1] - a[1])) {
  console.log(`  ${Skills.FAMILY_LABEL[family].padEnd(10)} ${n}`);
}

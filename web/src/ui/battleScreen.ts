// Battle presentation. Owns no combat rules: it listens to BattleSim and
// animates what it reports.
//
// The layout mirrors the lane-duel rules the simulation actually runs —
// two featured duelists trade blows centre stage while the rest of each
// team waits on a bench, and a fallen card is replaced by the next in line.

import * as Config from "../game/config";
import * as Design from "../game/design";
import * as AbilityText from "../game/abilityText";
import * as Mutations from "../game/mutations";
import { BattleSim, type BattleEvent, type Combatant, type Side } from "../game/battleSim";
import { buildFloor, tierFor } from "../game/enemyFactory";
import { game } from "../game/gameState";
import { button, clear, commas, compact, el } from "./dom";

const TURN_DELAY_MS = Config.ROUND_INTERVAL * 500;
const SPEEDS = [1, 1.5, 2, 4];

export interface BattleHandle {
  destroy(): void;
}

export function mountBattle(
  root: HTMLElement,
  floorNumber: number,
  onExit: (route: string) => void,
): BattleHandle {
  clear(root);

  const sim = new BattleSim();
  const benchTiles = new Map<Combatant, HTMLElement>();
  let cancelled = false;
  let speedIndex = 0;
  let turn = 0;

  // --- chrome -------------------------------------------------------

  const tier = tierFor(floorNumber);
  const isBoss = game.progression.isBossFloor(floorNumber);

  const floorChip = el("div", { class: "floor-chip" }, [
    el("b", {}, [`Floor ${floorNumber}`]),
    el("span", {}, [isBoss ? `Boss · ${tier.boss}` : `${tier.element} zone`]),
  ]);

  const turnLabel = el("div", { class: "turn-counter" }, ["Preparing…"]);

  const speedPill = button(`1x`, () => {
    speedIndex = (speedIndex + 1) % SPEEDS.length;
    speedPill.textContent = `${SPEEDS[speedIndex]}x`;
  }, "pill speed-pill");

  const forfeitBtn = button("Forfeit", () => {
    if (!sim.running) return;
    write("You forfeited the battle.", "#ef4444");
    sim.running = false;
    showResult(false);
  }, "pill forfeit-pill");

  const topBar = el("div", { class: "battle-top" }, [
    button("←", () => onExit("tower"), "pill ghost-pill"),
    floorChip,
    el("div", { class: "grow" }),
    turnLabel,
    el("div", { class: "grow" }),
    speedPill,
    forfeitBtn,
  ]);

  // --- arena --------------------------------------------------------

  const playerSlot = el("div", { class: "duel-slot" });
  const enemySlot = el("div", { class: "duel-slot" });

  const playerBar = teamBar();
  const enemyBar = teamBar();

  const playerBench = el("div", { class: "bench bench-left" });
  const enemyBench = el("div", { class: "bench bench-right" });

  const log = el("div", { class: "log", role: "log", "aria-live": "polite" });
  const challengeList = el("ul", { class: "challenge-list" });

  const challengePanel = el("aside", { class: "challenges" }, [
    el("div", { class: "challenges-head" }, ["Conditions"]),
    challengeList,
  ]);

  root.append(
    el("div", { class: "battle" }, [
      topBar,
      el("div", { class: "arena" }, [
        el("div", { class: "arena-side" }, [
          el("div", { class: "side-label side-player" }, ["Your active"]),
          playerSlot,
          playerBar.node,
        ]),
        el("div", { class: "arena-mid" }, [
          el("div", { class: "vs-mark" }, ["VS"]),
        ]),
        el("div", { class: "arena-side" }, [
          el("div", { class: "side-label side-enemy" }, ["Enemy active"]),
          enemySlot,
          enemyBar.node,
        ]),
        challengePanel,
      ]),
      el("div", { class: "benches" }, [playerBench, enemyBench]),
      el("div", { class: "section" }, ["Combat log"]),
      log,
    ]),
  );

  // --- setup --------------------------------------------------------

  sim.setup(game.getBattleTeam(), buildFloor(floorNumber, game.progression));

  for (const c of sim.players) playerBench.append(makeBenchTile(c));
  for (const c of sim.enemies) enemyBench.append(makeBenchTile(c));

  buildChallenges();
  renderActives();
  refreshTeamBars();

  sim.on(handleEvent);
  write(`Floor ${floorNumber} — begin`, Design.rarityColor("Legendary"));

  void run();

  // --- challenges ---------------------------------------------------

  // Derived from what this encounter genuinely does, so the panel can
  // never claim a rule the simulation is not running.
  function buildChallenges(): void {
    const items: string[] = [];

    const p = sim.players[0];
    const e = sim.enemies[0];
    if (p && e) {
      items.push(
        e.data.speed > p.data.speed
          ? `Opponent acts first — ${e.data.cardName} is faster (${e.data.speed} vs ${p.data.speed})`
          : `You act first — ${p.data.cardName} is at least as fast (${p.data.speed} vs ${e.data.speed})`,
      );
    }

    if (isBoss) {
      items.push(`Boss encounter — ${tier.boss} has ${Math.round((Config.BOSS_STAT_MULT - 1) * 100)}% higher stats`);
    }

    items.push(`Zone affinity: ${tier.element} — ${sim.enemies.length} enemies on this floor`);

    const scale = game.progression.statMultiplier(floorNumber);
    if (scale > 1) {
      items.push(`Floor scaling: enemy stats at ${Math.round(scale * 100)}%`);
    }

    const aoe = sim.enemies.filter((c) => c.data.ultimateTargetMode === "aoe").length;
    if (aoe > 0) items.push(`${aoe} enemy ultimate${aoe > 1 ? "s" : ""} hit your whole team`);

    if (game.weather.active) {
      items.push(`${game.weather.active.name} — ${game.weather.active.element} pulls boosted`);
    }

    for (const text of items) challengeList.append(el("li", {}, [text]));
  }

  // --- duelist cards -------------------------------------------------

  function renderActives(): void {
    const p = sim.players[sim.playerIndex];
    const e = sim.enemies[sim.enemyIndex];
    clear(playerSlot);
    clear(enemySlot);
    if (p) playerSlot.append(duelCard(p));
    if (e) enemySlot.append(duelCard(e));
  }

  function duelCard(c: Combatant): HTMLElement {
    const card = c.data;
    const rarityCol = Design.rarityColor(card.rarity);
    const mutated = Mutations.isMutated(card.modifier);
    const edge = mutated ? Mutations.color(card.modifier) : rarityCol;

    const node = el("article", {
      class: `duel-card${c.side === "enemy" ? " is-enemy" : ""}`,
      style: `--el:${Design.elementColor(card.element)};--edge:${edge}`,
      "data-cid": card.cardId,
    });

    const pips = el("div", { class: "dc-pips" });
    pips.append(pip(Design.elementIcon(card.element), Design.elementColor(card.element), card.element));
    pips.append(pip(Design.roleIcon(card.role), "#262c3d", card.role));
    if (card.passiveType === "guardian_block_heal") pips.append(pip("🛡", "#3ecf7e", "Guardian"));
    if (card.passiveType === "lifesteal") pips.append(pip("🩸", "#ef4444", "Lifesteal"));
    if (card.passiveType === "energy_surge") pips.append(pip("⚡", "#f5c518", "Energy surge"));
    if (card.ultimateTargetMode === "aoe") pips.append(pip("✳", "#a855f7", "AoE ultimate"));
    if (card.basicTargetMode === "backline") pips.append(pip("↯", "#3b82f6", "Backline basic"));

    const tags = el("div", { class: "dc-tags" });
    if (mutated) {
      tags.append(el("span", {
        class: "dc-tag",
        style: `border-color:${Mutations.color(card.modifier)};color:${Mutations.color(card.modifier)}`,
      }, [Mutations.displayName(card.modifier)]));
    }
    for (const tag of AbilityText.tags(card)) {
      tags.append(el("span", { class: "dc-tag" }, [tag]));
    }

    const passiveText = AbilityText.passive(card);

    node.append(
      el("div", { class: "dc-head" }, [
        el("span", { class: "dc-rarity", style: `color:${rarityCol};border-color:${rarityCol}` }, [card.rarity]),
        el("span", { class: "dc-dex" }, [`No.${AbilityText.dexNumber(card)}`]),
      ]),
      el("h3", { class: "dc-name" }, [card.cardName]),
      pips,
      el("div", { class: "dc-art" }, [
        el("div", { class: "dc-sigil" }, [Design.elementIcon(card.element)]),
        el("div", { class: "dc-role" }, [`${Design.roleIcon(card.role)} ${card.role}`]),
      ]),
      el("div", { class: "dc-ability" }, [
        el("b", { class: "dc-ability-name" }, [AbilityText.headlineName(card)]),
        el("p", {}, [AbilityText.headlineBody(card)]),
        ...(passiveText
          ? [el("p", { class: "dc-passive" }, [`${card.passiveAbility}: ${passiveText}`])]
          : []),
      ]),
      tags,
      el("div", { class: "dc-energy", title: "Ultimate charge" }, [
        el("i", { style: `width:${(c.energy / Config.ENERGY_MAX) * 100}%` }),
      ]),
      el("div", { class: "dc-foot" }, [
        el("span", { class: "dc-dmg" }, [`DMG ${compact(card.attack)}`]),
        el("span", { class: "dc-def" }, [`DEF ${compact(card.defense)}`]),
        el("span", { class: "dc-hp" }, [`HP ${compact(c.hp)}`]),
      ]),
    );

    return node;
  }

  function pip(glyph: string, color: string, label: string): HTMLElement {
    return el("span", { class: "pip", style: `--pip:${color}`, title: label }, [glyph]);
  }

  function slotFor(c: Combatant): HTMLElement | null {
    const slot = c.side === "player" ? playerSlot : enemySlot;
    const card = slot.querySelector<HTMLElement>(".duel-card");
    return card && card.dataset.cid === c.data.cardId ? card : null;
  }

  // --- bench ---------------------------------------------------------

  function makeBenchTile(c: Combatant): HTMLElement {
    const node = el("div", {
      class: "bench-tile",
      style: `--el:${Design.elementColor(c.data.element)};--edge:${Design.rarityColor(c.data.rarity)}`,
      title: `${c.data.cardName} — ${c.data.rarity} ${c.data.role}`,
    }, [
      el("div", { class: "bt-sigil" }, [Design.elementIcon(c.data.element)]),
      el("div", { class: "bt-bar" }, [el("i")]),
      el("div", { class: "bt-hp" }, [compact(c.hp)]),
    ]);
    benchTiles.set(c, node);
    refreshBench(c);
    return node;
  }

  function refreshBench(c: Combatant): void {
    const node = benchTiles.get(c);
    if (!node) return;
    const ratio = c.hpRatio();
    node.classList.toggle("dead", !c.alive);
    node.classList.toggle("active", c.alive && sim.activeIndex(c.side) === c.index);
    node.querySelector<HTMLElement>(".bt-bar > i")!.setAttribute("style", `width:${ratio * 100}%`);
    node.querySelector<HTMLElement>(".bt-bar")!.classList.toggle("low", ratio <= 0.3);
    node.querySelector<HTMLElement>(".bt-hp")!.textContent = c.alive ? compact(c.hp) : "Dead";
  }

  // --- team bars ------------------------------------------------------

  function teamBar() {
    const fill = el("i");
    const text = el("span", { class: "tb-text" }, ["0 / 0"]);
    const node = el("div", { class: "team-bar" }, [fill, text]);
    return { node, fill, text };
  }

  function refreshTeamBars(): void {
    apply(playerBar, sim.players);
    apply(enemyBar, sim.enemies);

    function apply(bar: ReturnType<typeof teamBar>, list: Combatant[]) {
      const hp = list.reduce((s, c) => s + c.hp, 0);
      const max = list.reduce((s, c) => s + c.maxHp, 0);
      bar.fill.setAttribute("style", `width:${max > 0 ? (hp / max) * 100 : 0}%`);
      bar.text.textContent = `${commas(hp)} / ${commas(max)}`;
      bar.node.classList.toggle("low", max > 0 && hp / max <= 0.3);
    }
  }

  // --- feedback -------------------------------------------------------

  function floatText(c: Combatant, text: string, color: string): void {
    const host = slotFor(c) ?? benchTiles.get(c);
    if (!host) return;
    const f = el("div", { class: "floater", style: `color:${color}` }, [text]);
    host.append(f);
    setTimeout(() => f.remove(), 900);
  }

  function hit(c: Combatant, damage: number): void {
    refreshBench(c);
    refreshTeamBars();

    const card = slotFor(c);
    if (card) {
      const hpNode = card.querySelector<HTMLElement>(".dc-hp");
      if (hpNode) hpNode.textContent = `HP ${compact(c.hp)}`;
      card.classList.remove("hit");
      void card.offsetWidth; // restart the shake
      card.classList.add("hit");
    }
    floatText(c, `-${compact(damage)}`, "#ef4444");
  }

  function refreshEnergy(c: Combatant): void {
    const card = slotFor(c);
    const bar = card?.querySelector<HTMLElement>(".dc-energy > i");
    if (bar) bar.setAttribute("style", `width:${(c.energy / Config.ENERGY_MAX) * 100}%`);
  }

  function write(text: string, color = "#a3aab9"): void {
    log.append(el("div", { style: `color:${color}` }, [text]));
    log.scrollTop = log.scrollHeight;
  }

  function handleEvent(event: BattleEvent): void {
    switch (event.type) {
      case "attack":
        hit(event.target, event.damage);
        refreshEnergy(event.attacker);
        write(`${event.attacker.data.cardName} strikes ${event.target.data.cardName} for ${compact(event.damage)}`, "#3b82f6");
        break;

      case "ability": {
        for (const t of event.targets) hit(t, event.damage);
        refreshEnergy(event.user);
        const ult = event.kind === "ultimate";
        const scope = event.targets.length > 1 ? ` (×${event.targets.length})` : "";
        write(
          `${event.user.data.cardName} ${ult ? "unleashes" : "uses"} ${event.ability}${scope} for ${compact(event.damage)}`,
          ult ? Design.rarityColor("Mythic") : "#f5a623",
        );
        break;
      }

      case "passive":
        refreshBench(event.source);
        refreshTeamBars();
        floatText(event.source, `+${compact(event.amount)}`, "#3ecf7e");
        write(`${event.note} (+${compact(event.amount)} HP)`, "#3ecf7e");
        break;

      case "healed":
        refreshBench(event.target);
        refreshTeamBars();
        floatText(event.target, `+${compact(event.amount)}`, "#3ecf7e");
        break;

      case "died":
        refreshBench(event.who);
        refreshTeamBars();
        write(`${event.who.data.cardName} is defeated`, "#646c7e");
        break;

      case "actives":
        renderActives();
        for (const c of [...sim.players, ...sim.enemies]) refreshBench(c);
        break;

      case "ended":
        write(event.playerWon ? "VICTORY" : "DEFEAT", event.playerWon ? "#3ecf7e" : "#ef4444");
        showResult(event.playerWon);
        break;
    }
  }

  // Hoisted: run() is kicked off above this point in the body, so a
  // `const` arrow would still be in its temporal dead zone.
  function wait(ms: number): Promise<void> {
    return new Promise<void>((resolve) => setTimeout(resolve, ms / SPEEDS[speedIndex]));
  }

  async function run(): Promise<void> {
    await wait(700);
    while (sim.running && !cancelled) {
      const order: Side[] = sim.prepareRound();
      if (!sim.running || order.length === 0) break;

      turn++;
      turnLabel.textContent = `Turn ${turn}`;

      for (const side of order) {
        sim.takeTurn(side);
        if (!sim.running || cancelled) return;
        await wait(TURN_DELAY_MS);
      }
    }
  }

  // --- result ---------------------------------------------------------

  function showResult(playerWon: boolean): void {
    const rewards = playerWon
      ? game.clearFloor(floorNumber)
      : { gems: 0, gold: 0, pack: "" };

    const accent = playerWon ? "#3ecf7e" : "#ef4444";
    const panel = el("div", { class: "result", style: `border-color:${accent}` });
    const scrim = el("div", { class: "scrim" }, [panel]);

    panel.append(
      el("h2", { style: `color:${accent}` }, [playerWon ? "VICTORY" : "DEFEAT"]),
      el("div", { class: "result-sub" }, [`Floor ${floorNumber} · ${turn} turns`]),
    );

    if (playerWon) {
      panel.append(el("div", { class: "rewards" }, [
        `+${commas(rewards.gems)} 💎    +${commas(rewards.gold)} 🪙`,
      ]));
      if (rewards.pack !== "") {
        panel.append(el("div", { style: "color:#3ecf7e;margin-bottom:16px" }, [
          `🎁 ${Config.ROLL_PACKS[rewards.pack].label} earned!`,
        ]));
      }
    } else {
      panel.append(el("div", { class: "result-sub", style: "margin-bottom:16px" }, [
        "Your team was wiped out. Summon stronger cards or rebuild your team.",
      ]));
    }

    const actions = el("div", { class: "row", style: "justify-content:center" });
    if (playerWon && floorNumber < Config.MAX_FLOOR) {
      actions.append(button("Next floor", () => {
        scrim.remove();
        onExit(`battle:${floorNumber + 1}`);
      }, "btn primary"));
    } else if (!playerWon) {
      actions.append(button("Retry", () => {
        scrim.remove();
        onExit(`battle:${floorNumber}`);
      }, "btn primary"));
    }
    actions.append(button("Tower", () => { scrim.remove(); onExit("tower"); }));
    actions.append(button("Collection", () => { scrim.remove(); onExit("collection"); }));

    panel.append(actions);
    document.body.append(scrim);
  }

  return {
    destroy() {
      cancelled = true;
      sim.running = false;
      document.querySelector(".scrim")?.remove();
    },
  };
}

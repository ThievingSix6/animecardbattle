// Ported from scripts/screens/battle_screen.gd — battle presentation.
// Owns no combat rules: it listens to BattleSim and animates what it
// reports.

import * as Config from "../game/config";
import * as Design from "../game/design";
import { BattleSim, type BattleEvent, type Combatant } from "../game/battleSim";
import { buildFloor } from "../game/enemyFactory";
import { game } from "../game/gameState";
import { button, clear, commas, compact, el } from "./dom";

const TURN_DELAY_MS = Config.ROUND_INTERVAL * 500;

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
  const views = new Map<Combatant, HTMLElement>();
  let cancelled = false;
  let speed = 1;

  const enemyRow = el("div", { class: "battle-side" });
  const playerRow = el("div", { class: "battle-side" });
  const log = el("div", { class: "log", role: "log", "aria-live": "polite" });

  const speedBtn = button(`⏩ Speed ×${speed}`, () => {
    speed = speed === 1 ? 2 : speed === 2 ? 4 : 1;
    speedBtn.textContent = `⏩ Speed ×${speed}`;
  });

  root.append(
    el("h2", { class: "screen-title" }, [`Floor ${floorNumber}`]),
    el("p", { class: "screen-sub" }, [
      game.progression.isBossFloor(floorNumber)
        ? "Boss floor — the last enemy hits far harder."
        : "Combat resolves automatically. Front card fights; when it falls the next steps up.",
    ]),
    el("div", { class: "row" }, [speedBtn, button("← Tower", () => onExit("tower"))]),
    el("div", { class: "section" }, ["Enemy"]),
    enemyRow,
    el("div", { class: "vs" }, ["⚔ VS ⚔"]),
    el("div", { class: "section" }, ["Your team"]),
    playerRow,
    el("div", { class: "section" }, ["Combat log"]),
    log,
  );

  sim.setup(game.getBattleTeam(), buildFloor(floorNumber, game.progression));

  for (const c of sim.enemies) addView(c, enemyRow);
  for (const c of sim.players) addView(c, playerRow);

  sim.on(handleEvent);
  write(`FLOOR ${floorNumber} — BEGIN`, Design.rarityColor("Legendary"));

  void run();

  function addView(c: Combatant, row: HTMLElement): void {
    const node = el("div", {
      class: "fighter",
      style: `--el:${Design.elementColor(c.data.element)}`,
    });

    const hpBar = el("i");
    const energyBar = el("i");
    const hpText = el("div", { class: "hpnum" });

    node.append(
      el("div", { class: "fname" }, [c.data.cardName]),
      el("div", { class: "frole" }, [
        `${Design.elementIcon(c.data.element)} ${c.data.role}`,
      ]),
      el("div", { class: "bar" }, [hpBar]),
      hpText,
      el("div", { class: "bar energy" }, [energyBar]),
    );

    views.set(c, node);
    row.append(node);
    refresh(c);
  }

  function refresh(c: Combatant): void {
    const node = views.get(c);
    if (!node) return;

    const ratio = c.hpRatio();
    const bar = node.querySelector<HTMLElement>(".bar:not(.energy)")!;
    bar.classList.toggle("low", ratio <= 0.3);
    bar.firstElementChild!.setAttribute("style", `width:${ratio * 100}%`);

    node.querySelector<HTMLElement>(".hpnum")!.textContent =
      `${compact(c.hp)} / ${compact(c.maxHp)}`;
    node.querySelector<HTMLElement>(".bar.energy > i")!.setAttribute(
      "style", `width:${(c.energy / Config.ENERGY_MAX) * 100}%`,
    );
    node.classList.toggle("dead", !c.alive);
  }

  function floatText(c: Combatant, text: string, color: string): void {
    const node = views.get(c);
    if (!node) return;
    const f = el("div", { class: "floater", style: `color:${color}` }, [text]);
    node.append(f);
    setTimeout(() => f.remove(), 900);
  }

  function hit(c: Combatant, damage: number): void {
    refresh(c);
    const node = views.get(c);
    if (node) {
      node.classList.remove("hit");
      void node.offsetWidth; // restart the shake animation
      node.classList.add("hit");
    }
    floatText(c, `-${compact(damage)}`, "#ef4444");
  }

  function write(text: string, color = "#a3aab9"): void {
    const line = el("div", { style: `color:${color}` }, [text]);
    log.append(line);
    log.scrollTop = log.scrollHeight;
  }

  function handleEvent(event: BattleEvent): void {
    switch (event.type) {
      case "attack":
        hit(event.target, event.damage);
        write(`${event.attacker.data.cardName} strikes ${event.target.data.cardName} for ${compact(event.damage)}`, "#3b82f6");
        break;

      case "ability": {
        for (const t of event.targets) hit(t, event.damage);
        const isUlt = event.kind === "ultimate";
        const scope = event.targets.length > 1 ? ` (×${event.targets.length})` : "";
        write(
          `${event.user.data.cardName} ${isUlt ? "unleashes" : "uses"} ${event.ability}${scope} for ${compact(event.damage)}`,
          isUlt ? Design.rarityColor("Mythic") : "#f5a623",
        );
        break;
      }

      case "passive":
        refresh(event.source);
        floatText(event.source, `+${compact(event.amount)}`, "#3ecf7e");
        write(`${event.note} (+${compact(event.amount)} HP)`, "#3ecf7e");
        break;

      case "healed":
        refresh(event.target);
        floatText(event.target, `+${compact(event.amount)}`, "#3ecf7e");
        break;

      case "died":
        refresh(event.who);
        write(`${event.who.data.cardName} is defeated`, "#646c7e");
        break;

      case "actives":
        for (const c of sim.players) views.get(c)?.classList.toggle("active", c.index === event.playerIndex && c.alive);
        for (const c of sim.enemies) views.get(c)?.classList.toggle("active", c.index === event.enemyIndex && c.alive);
        break;

      case "ended":
        write(event.playerWon ? "VICTORY" : "DEFEAT", event.playerWon ? "#3ecf7e" : "#ef4444");
        showResult(event.playerWon);
        break;
    }
  }

  // Declared as a hoisted function: run() is kicked off above, before this
  // point in the body, so a `const` arrow would be in its dead zone.
  function wait(ms: number): Promise<void> {
    return new Promise<void>((resolve) => setTimeout(resolve, ms / speed));
  }

  async function run(): Promise<void> {
    await wait(700);
    while (sim.running && !cancelled) {
      const order = sim.prepareRound();
      if (!sim.running || order.length === 0) break;

      for (const side of order) {
        sim.takeTurn(side);
        if (!sim.running || cancelled) return;
        await wait(TURN_DELAY_MS);
      }
    }
  }

  function showResult(playerWon: boolean): void {
    const rewards = playerWon
      ? game.clearFloor(floorNumber)
      : { gems: 0, gold: 0, pack: "" };

    const accent = playerWon ? "#3ecf7e" : "#ef4444";
    const panel = el("div", { class: "result", style: `border-color:${accent}` });

    panel.append(el("h2", { style: `color:${accent}` }, [playerWon ? "VICTORY" : "DEFEAT"]));

    if (playerWon) {
      panel.append(
        el("div", { class: "rewards" }, [
          `+${commas(rewards.gems)} 💎    +${commas(rewards.gold)} 🪙`,
        ]),
      );
      if (rewards.pack !== "") {
        panel.append(
          el("div", { style: "color:#3ecf7e;margin-bottom:16px" }, [
            `🎁 ${Config.ROLL_PACKS[rewards.pack].label} earned!`,
          ]),
        );
      }
    } else {
      panel.append(
        el("div", { style: "color:#a3aab9;margin-bottom:16px" }, [
          "Your team was wiped out. Summon stronger cards or rebuild your team.",
        ]),
      );
    }

    const actions = el("div", { class: "row", style: "justify-content:center" });
    const scrim = el("div", { class: "scrim" }, [panel]);

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

    actions.append(button("Tower", () => {
      scrim.remove();
      onExit("tower");
    }));
    actions.append(button("Collection", () => {
      scrim.remove();
      onExit("collection");
    }));

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

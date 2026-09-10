// The non-battle screens, mirroring scripts/screens/*.gd.

import * as Config from "../game/config";
import * as Design from "../game/design";
import * as Skills from "../game/skills";
import * as Campaign from "../game/campaign";
import type { CardData } from "../game/cardData";
import { SORTS, TEAM_SIZE } from "../game/collection";
import { ORIGIN_LABELS, ORIGINS } from "../game/cardGenerator";
import { game, type EventHandler, type EventName } from "../game/gameState";
import type { TalentId } from "../game/progression";
import { button, clear, commas, compact, el } from "./dom";
import { cardView } from "./cardView";

export type Navigate = (route: string) => void;

/**
 * Registers a game listener that the router tears down when the screen is
 * left. Screens must use this rather than game.on directly, otherwise
 * handlers pile up and keep writing into detached DOM.
 */
export type Subscribe = (event: EventName, handler: EventHandler) => void;

// ---------------- MAIN MENU / LOBBY ----------------

export function menuScreen(root: HTMLElement, nav: Navigate, sub: Subscribe): void {
  clear(root);

  const hero = el("div", { class: "hero" }, [
    el("h1", {}, ["Anime Card Legends"]),
    el("p", {}, [
      "Summon a roster, build a five-card team, and fight through six zones. " +
      "Combat resolves automatically — your decisions are which cards to pull, " +
      "merge, and field.",
    ]),
  ]);

  hero.append(
    el("div", { class: "menu-actions" }, [
      button("⚔  Campaign", () => nav("tower"), "btn primary big"),
      button("✦  Summon", () => nav("summon"), "btn big"),
      button("👥  Team", () => nav("team"), "btn big"),
    ]),
  );

  const uniqueTile = tile("0", "Unique cards");
  const poolTile = tile("0", "Cards in pool");
  const floorTile = tile("0", "Stages cleared");
  const rateTile = tile("0", "Auto-roll rate");
  const stats = el("div", { class: "stat-strip" }, [uniqueTile, poolTile, floorTile, rateTile]);

  const weather = el("div");
  const feed = el("div", { class: "feed" });

  const feedPanel = el("div", { class: "panel" }, [
    el("div", { class: "section", style: "margin-top:0" }, ["Live summon feed"]),
    feed,
    el("div", { class: "hint" }, [
      "Cards roll in automatically over time. Upgrade talents to roll faster and luckier.",
    ]),
  ]);

  root.append(hero, weather, stats, el("div", { style: "height:24px" }), feedPanel);

  // Counters update in place; re-rendering the screen would discard the feed.
  const refreshStats = () => {
    uniqueTile.querySelector("b")!.textContent = commas(game.collection.uniqueCount());
    poolTile.querySelector("b")!.textContent = commas(game.gacha.totalPoolSize());
    floorTile.querySelector("b")!.textContent = `${game.progression.highestFloor}/${Campaign.TOTAL_FLOORS}`;
    rateTile.querySelector("b")!.textContent = `${game.progression.rollInterval().toFixed(1)}s`;
  };

  const refreshWeather = () => {
    clear(weather);
    weather.append(weatherBanner());
  };

  refreshStats();
  refreshWeather();

  sub("collection", refreshStats);
  sub("weather", refreshWeather);
  sub("autoRolled", (payload) => {
    for (const card of payload as CardData[]) {
      feed.prepend(
        el("div", { style: `color:${Design.rarityColor(card.rarity)}` }, [
          `${Design.elementIcon(card.element)} ${card.cardName} — ${card.rarity}`,
        ]),
      );
    }
    while (feed.childElementCount > 40) feed.lastElementChild?.remove();
  });
}

function tile(value: string, label: string): HTMLElement {
  return el("div", { class: "stat-tile" }, [
    el("b", {}, [value]),
    el("span", {}, [label]),
  ]);
}

function weatherBanner(): HTMLElement {
  const active = game.weather.active;
  if (!active) {
    return el("div", { class: "hint", style: "text-align:center" }, [
      "No weather event active — one will roll in shortly.",
    ]);
  }
  return el("div", { class: "weather-banner" }, [
    el("b", {}, [active.name]),
    el("span", {}, [
      ` — ${active.desc} (${game.weather.secondsRemaining()}s left, luck ×${Config.EVENT_LUCK_MULT})`,
    ]),
  ]);
}

// ---------------- TOWER ----------------

export function towerScreen(root: HTMLElement, nav: Navigate): void {
  clear(root);

  const highest = game.progression.highestFloor;

  root.append(
    el("h2", { class: "screen-title" }, ["Campaign"]),
    el("p", { class: "screen-sub" }, [
      `Six zones of ${Campaign.STAGES_PER_ZONE} stages, each ending in a boss. ` +
      `Clear a zone's boss to open the next. ${highest} of ${Campaign.TOTAL_FLOORS} stages cleared.`,
    ]),
    teamStrip(nav),
  );

  for (let z = 0; z < Campaign.ZONES.length; z++) {
    root.append(zoneBlock(z, highest, nav));
  }
}

function zoneBlock(zoneIndex: number, highest: number, nav: Navigate): HTMLElement {
  const zone = Campaign.zoneAt(zoneIndex);
  const unlocked = Campaign.zoneUnlocked(zoneIndex, highest);
  const cleared = Campaign.stagesClearedIn(zoneIndex, highest);
  const complete = Campaign.zoneComplete(zoneIndex, highest);

  const head = el("div", { class: "row" }, [
    el("div", { class: "grow" }, [
      el("b", { style: `color:${unlocked ? zone.accent : "#646c7e"}` }, [
        `${Design.elementIcon(zone.element)}  ${zone.name}`,
      ]),
      el("div", { class: "hint", style: "margin-top:2px" }, [zone.subtitle]),
    ]),
    el("span", {
      class: "coin",
      style: `border-color:${complete ? "#3ecf7e" : "var(--hairline)"}`,
    }, [
      complete ? "✓ Cleared" : unlocked ? `${cleared}/${Campaign.STAGES_PER_ZONE}` : "🔒 Locked",
    ]),
  ]);

  const grid = el("div", { class: "floors" });
  for (let s = 0; s < Campaign.STAGES_PER_ZONE; s++) {
    const floorNumber = Campaign.floorFor(zoneIndex, s);
    const isBoss = Campaign.isBossStage(s);
    const isCleared = floorNumber <= highest;
    const isOpen = game.progression.isUnlocked(floorNumber);

    const b = el("button", {
      class: `floor${isCleared ? " cleared" : ""}${isBoss ? " boss" : ""}`,
      title: isBoss ? zone.boss : `Stage ${s + 1}`,
    }, [
      isBoss ? "👑" : String(s + 1),
      el("small", {}, [isCleared ? "cleared" : isBoss ? "boss" : isOpen ? "ready" : "locked"]),
    ]);

    if (!isOpen) b.disabled = true;
    else b.addEventListener("click", () => nav(`battle:${floorNumber}`));
    grid.append(b);
  }

  return el("div", { class: "panel", style: "margin-bottom:16px" }, [head, el("div", { style: "height:12px" }), grid]);
}

function teamStrip(nav: Navigate): HTMLElement {
  const team = game.getBattleTeam();
  const panel = el("div", { class: "panel" });

  panel.append(
    el("div", { class: "row" }, [
      el("div", { class: "grow" }, [
        el("b", {}, [`Your team (${team.length}/${TEAM_SIZE})`]),
      ]),
      button("Edit team", () => nav("team")),
    ]),
  );

  if (team.length === 0) {
    panel.append(el("div", { class: "empty" }, ["No cards in your team."]));
    return panel;
  }

  const row = el("div", { class: "row", style: "margin-top:12px" });
  for (const card of team) {
    row.append(
      el("div", {
        class: "coin",
        style: `border-color:${Design.rarityColor(card.rarity)}`,
      }, [
        `${Design.elementIcon(card.element)} ${card.cardName}`,
        el("span", { style: "color:#646c7e" }, [` ⚔${compact(card.attack)} ❤${compact(card.health)}`]),
      ]),
    );
  }
  panel.append(row);
  return panel;
}

// ---------------- COLLECTION ----------------

let sortKey = "rarity";

export function collectionScreen(root: HTMLElement, nav: Navigate): void {
  clear(root);

  const grid = el("div", { class: "card-grid" });
  const sortRow = el("div", { class: "row" });

  for (const sort of SORTS) {
    const b = button(sort.label, () => {
      sortKey = sort.key;
      collectionScreen(root, nav);
    }, `btn${sortKey === sort.key ? " primary" : ""}`);
    sortRow.append(b);
  }

  const cards = game.collection.sorted(sortKey);

  root.append(
    el("h2", { class: "screen-title" }, ["Collection"]),
    el("p", { class: "screen-sub" }, [
      `${commas(cards.length)} unique of ${commas(game.gacha.totalPoolSize())} in the pool. ` +
      `Click a card to sell a copy, or merge ${Config.MERGE_REQUIREMENT} copies to ascend it.`,
    ]),
    sortRow,
    el("div", { style: "height:16px" }),
    grid,
  );

  if (cards.length === 0) {
    grid.append(el("div", { class: "empty" }, ["No cards yet — wait for an auto-roll or summon."]));
    return;
  }

  for (const card of cards) {
    grid.append(
      cardView(card, {
        copies: game.collection.copiesOf(card.cardId),
        inTeam: game.collection.inTeam(card.cardId),
        onClick: (c) => openCardDetail(c, () => collectionScreen(root, nav)),
      }),
    );
  }
}

function openCardDetail(card: CardData, refresh: () => void): void {
  const panel = el("div", { class: "result", style: "text-align:left;min-width:420px" });
  const scrim = el("div", { class: "scrim" }, [panel]);
  const close = () => scrim.remove();

  const copies = game.collection.copiesOf(card.cardId);
  const canMerge = game.collection.canMerge(card.cardId);

  panel.append(
    el("h2", { style: `color:${Design.rarityColor(card.rarity)};font-size:24px;text-align:center` }, [
      card.cardName,
    ]),
    el("p", { style: "color:#a3aab9;text-align:center;margin-top:0" }, [
      `${card.rarity} · ${card.element} ${card.role} · ${card.faction}`,
    ]),
    el("p", { style: "color:#a3aab9;font-style:italic" }, [card.description]),
    statLine("Attack", compact(card.attack)),
    statLine("Defense", compact(card.defense)),
    statLine("Health", compact(card.health)),
    statLine("Speed", compact(card.speed)),
    statLine("Basic", `${card.basicAbility} (${card.basicTargetMode})`),
    statLine("Ultimate", `${card.ultimateAbility} (${card.ultimateTargetMode})`),
    statLine("Copies", commas(copies)),
    statLine("Sell value", `${commas(card.sellValue)} gold`),
    statLine("Pull odds", formatOdds(game.gacha.cardOdds(card))),
  );

  const skill = Skills.skillById(card.skillId);
  if (skill) {
    const color = Skills.FAMILY_COLOR[skill.family];
    panel.append(
      el("div", { class: "skill-block", style: `border-color:${color}` }, [
        el("div", { class: "skill-head" }, [
          el("span", { class: "skill-icon", style: `color:${color}` }, [Skills.FAMILY_ICON[skill.family]]),
          el("b", { style: `color:${color}` }, [skill.name]),
          el("span", { class: "skill-family" }, [Skills.FAMILY_LABEL[skill.family]]),
        ]),
        el("p", {}, [skill.text]),
      ]),
    );
  }

  const actions = el("div", { class: "row", style: "justify-content:center;margin-top:16px" });

  actions.append(button(game.collection.inTeam(card.cardId) ? "Remove from team" : "Add to team", () => {
    game.toggleTeam(card.cardId);
    close();
    refresh();
  }, "btn primary"));

  const mergeBtn = button(`Merge ×${Config.MERGE_REQUIREMENT}`, () => {
    game.mergeCard(card.cardId);
    close();
    refresh();
  });
  mergeBtn.disabled = !canMerge;
  mergeBtn.title = canMerge ? "" : `Needs ${Config.MERGE_REQUIREMENT} copies`;
  actions.append(mergeBtn);

  actions.append(button("Sell one", () => {
    game.sellCard(card.cardId);
    close();
    refresh();
  }, "btn danger"));

  actions.append(button("Close", close));
  panel.append(actions);

  scrim.addEventListener("click", (e) => {
    if (e.target === scrim) close();
  });
  document.body.append(scrim);
}

function statLine(label: string, value: string): HTMLElement {
  return el("div", { class: "row", style: "justify-content:space-between;border-bottom:1px solid #2d3446;padding:6px 0" }, [
    el("span", { style: "color:#646c7e" }, [label]),
    el("b", {}, [value]),
  ]);
}

function formatOdds(odds: number): string {
  if (odds <= 0) return "—";
  return `1 in ${commas(Math.round(1 / odds))}`;
}

// ---------------- TEAM BUILDER ----------------

export function teamScreen(root: HTMLElement, nav: Navigate): void {
  clear(root);

  const team = game.getBattleTeam();
  const grid = el("div", { class: "card-grid" });

  root.append(
    el("h2", { class: "screen-title" }, ["Team Builder"]),
    el("p", { class: "screen-sub" }, [
      `Pick up to ${TEAM_SIZE} cards. Order matters: the first card fights, ` +
      "and when it falls the next steps up. Click any card to toggle it.",
    ]),
    el("div", { class: "panel" }, [
      el("b", {}, [`Selected: ${team.length}/${TEAM_SIZE}`]),
      el("div", { class: "hint" }, [
        team.length === 0
          ? "Nothing selected — battle would fall back to your first owned cards."
          : team.map((c) => c.cardName).join("  →  "),
      ]),
    ]),
    el("div", { class: "row", style: "margin-top:16px" }, [
      button("⚔ To the Tower", () => nav("tower"), "btn primary"),
      button("View collection", () => nav("collection")),
    ]),
    el("div", { class: "section" }, ["Owned cards"]),
    grid,
  );

  const cards = game.collection.sorted("rarity");
  if (cards.length === 0) {
    grid.append(el("div", { class: "empty" }, ["No cards owned yet."]));
    return;
  }

  for (const card of cards) {
    grid.append(
      cardView(card, {
        copies: game.collection.copiesOf(card.cardId),
        inTeam: game.collection.inTeam(card.cardId),
        selected: game.collection.inTeam(card.cardId),
        onClick: (c) => {
          game.toggleTeam(c.cardId);
          teamScreen(root, nav);
        },
      }),
    );
  }
}

// ---------------- SUMMON / PACKS ----------------

let banner = "";

export function summonScreen(root: HTMLElement, nav: Navigate): void {
  clear(root);

  const results = el("div", { class: "card-grid" });
  const bannerRow = el("div", { class: "row" });

  for (const origin of ["", ...ORIGINS]) {
    bannerRow.append(
      button(ORIGIN_LABELS[origin], () => {
        banner = origin;
        summonScreen(root, nav);
      }, `btn${banner === origin ? " primary" : ""}`),
    );
  }

  const doSummon = (count: number) => {
    const pulled = game.summon(count, banner);
    if (pulled.length === 0) return;
    clear(results);
    for (const card of pulled) {
      results.append(cardView(card, { copies: game.collection.copiesOf(card.cardId) }));
    }
  };

  const packRow = el("div", { class: "row" });
  for (const [id, pack] of Object.entries(Config.ROLL_PACKS)) {
    const count = game.progression.packCount(id);
    const b = button(`${pack.label} (${count})`, () => {
      const summary = game.useRollPack(id);
      if (!summary) return;
      game.toast(`${pack.label} opened — ${commas(pack.rolls)} rolls resolved.`, "success");
      summonScreen(root, nav);
    });
    b.disabled = count <= 0;
    packRow.append(b);
  }

  root.append(
    el("h2", { class: "screen-title" }, ["Summon"]),
    el("p", { class: "screen-sub" }, [
      `Single pull ${commas(Config.SUMMON_COST_X1)} 💎 · Ten pull ${commas(Config.SUMMON_COST_X10)} 💎`,
    ]),
    weatherBanner(),
    el("div", { class: "section" }, ["Banner"]),
    bannerRow,
    el("div", { class: "row", style: "margin-top:16px" }, [
      button(`Summon ×1  (${commas(Config.SUMMON_COST_X1)} 💎)`, () => doSummon(1), "btn primary big"),
      button(`Summon ×10  (${commas(Config.SUMMON_COST_X10)} 💎)`, () => doSummon(10), "btn big"),
    ]),
    el("div", { class: "section" }, ["Roll packs (earned from boss floors)"]),
    packRow,
    el("div", { class: "section" }, ["Last summon"]),
    results,
  );
}

// ---------------- TALENTS ----------------

export function talentsScreen(root: HTMLElement, nav: Navigate): void {
  clear(root);

  const panel = el("div", { class: "panel", style: "padding:0" });
  const talents: Array<{ id: TalentId; name: string; blurb: string }> = [
    { id: "speed", name: "Roll Speed", blurb: "Auto-rolls arrive faster." },
    { id: "luck", name: "Luck", blurb: "Shifts pulls toward rarer tiers." },
    { id: "multi", name: "Multi-roll", blurb: "More cards per auto-roll." },
  ];

  for (const talent of talents) {
    const level = game.progression.talents[talent.id];
    const maxed = game.progression.isMaxed(talent.id);
    const cost = game.progression.cost(talent.id);

    const b = button(maxed ? "MAX" : `Upgrade — ${commas(cost)} 🪙`, () => {
      if (game.upgradeTalent(talent.id)) {
        game.toast(`${talent.name} upgraded.`, "success");
        talentsScreen(root, nav);
      }
    }, "btn primary");
    b.disabled = maxed || game.gold < cost;

    panel.append(
      el("div", { class: "talent" }, [
        el("div", { class: "grow" }, [
          el("b", {}, [talent.name]),
          el("div", { class: "eff" }, [talent.blurb]),
          el("div", { class: "eff" }, [game.progression.talentEffectText(talent.id)]),
        ]),
        el("div", { class: "lvl" }, [`Lv ${level}/${Config.TALENT_MAX[talent.id]}`]),
        b,
      ]),
    );
  }

  root.append(
    el("h2", { class: "screen-title" }, ["Talents"]),
    el("p", { class: "screen-sub" }, ["Spend gold to improve the background roll engine."]),
    panel,
  );
}

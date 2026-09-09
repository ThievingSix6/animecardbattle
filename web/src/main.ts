import "./ui/styles.css";

import { game, type EventHandler, type EventName, type Toast } from "./game/gameState";
import { button, clear, commas, el } from "./ui/dom";
import { mountBattle, type BattleHandle } from "./ui/battleScreen";
import {
  collectionScreen, menuScreen, summonScreen,
  talentsScreen, teamScreen, towerScreen,
} from "./ui/screens";

const NAV = [
  { route: "menu", label: "Lobby", key: "1" },
  { route: "tower", label: "Tower", key: "2" },
  { route: "team", label: "Team", key: "3" },
  { route: "collection", label: "Collection", key: "4" },
  { route: "summon", label: "Summon", key: "5" },
  { route: "talents", label: "Talents", key: "6" },
];

const app = document.getElementById("app")!;

const gemCoin = el("span", { class: "coin" }, ["💎 ", el("b", {}, ["0"])]);
const goldCoin = el("span", { class: "coin" }, ["🪙 ", el("b", {}, ["0"])]);

const navBar = el("nav", { class: "nav" });
const main = el("main");
const toasts = el("div", { class: "toasts" });

app.append(
  el("header", { class: "topbar" }, [
    el("div", { class: "brand" }, ["Anime Card Legends"]),
    el("span", { style: "color:#646c7e;font-size:12px" }, ["browser prototype"]),
    el("div", { class: "wallet" }, [gemCoin, goldCoin]),
  ]),
  navBar,
  main,
);
document.body.append(toasts);

let battle: BattleHandle | null = null;

// Listeners a screen registers live only as long as that screen is shown.
let screenSubs: Array<[EventName, EventHandler]> = [];

function sub(event: EventName, handler: EventHandler): void {
  game.on(event, handler);
  screenSubs.push([event, handler]);
}

for (const item of NAV) {
  const b = button(item.label, () => navigate(item.route), "");
  b.append(el("span", { class: "key" }, [item.key]));
  b.dataset.route = item.route;
  navBar.append(b);
}

function navigate(route: string): void {
  if (battle) {
    battle.destroy();
    battle = null;
  }

  for (const [event, handler] of screenSubs) game.off(event, handler);
  screenSubs = [];

  clear(main);
  main.scrollTop = 0;

  for (const b of navBar.querySelectorAll<HTMLButtonElement>("button")) {
    const active = b.dataset.route === route || (route.startsWith("battle") && b.dataset.route === "tower");
    b.setAttribute("aria-current", String(active));
  }

  if (route.startsWith("battle:")) {
    const floor = Number(route.split(":")[1]) || 1;
    game.progression.pendingFloor = floor;
    battle = mountBattle(main, floor, navigate);
    return;
  }

  switch (route) {
    case "tower": towerScreen(main, navigate); break;
    case "team": teamScreen(main, navigate); break;
    case "collection": collectionScreen(main, navigate); break;
    case "summon": summonScreen(main, navigate); break;
    case "talents": talentsScreen(main, navigate); break;
    default: menuScreen(main, navigate, sub); break;
  }
}

// ---------------- WALLET / TOASTS ----------------

function refreshWallet(): void {
  const gems = gemCoin.querySelector("b")!;
  const gold = goldCoin.querySelector("b")!;
  const gemsChanged = gems.textContent !== commas(game.gems);
  const goldChanged = gold.textContent !== commas(game.gold);

  gems.textContent = commas(game.gems);
  gold.textContent = commas(game.gold);

  if (gemsChanged) flash(gemCoin);
  if (goldChanged) flash(goldCoin);
}

function flash(node: HTMLElement): void {
  node.classList.remove("flash");
  void node.offsetWidth;
  node.classList.add("flash");
}

game.on("currency", refreshWallet);

game.on("toast", (payload) => {
  const { text, kind } = payload as Toast;
  const node = el("div", { class: `toast ${kind}` }, [text]);
  toasts.append(node);
  setTimeout(() => node.remove(), 3200);
});

// ---------------- KEYBOARD ----------------

document.addEventListener("keydown", (e) => {
  if (e.target instanceof HTMLInputElement) return;

  const item = NAV.find((n) => n.key === e.key);
  if (item) {
    navigate(item.route);
    return;
  }

  if (e.key === "Escape") {
    const scrim = document.querySelector(".scrim");
    if (scrim) scrim.remove();
    else navigate("menu");
  }
});

// ---------------- BOOT ----------------

game.start();
refreshWallet();
navigate("menu");

let last = performance.now();
function frame(now: number): void {
  const delta = Math.min(0.25, (now - last) / 1000);
  last = now;
  game.tick(delta);
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

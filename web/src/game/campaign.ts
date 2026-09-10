// Mirrors scripts/core/campaign.gd — six zones, each with six encounters
// and a boss.
//
// Zones are a structured view over the linear floor system rather than a
// parallel progression: stage S of zone Z is floor (Z * STAGES_PER_ZONE +
// S + 1). One source of truth for difficulty scaling, unlocks and rewards,
// so a zone cannot drift out of sync with the floor it plays.
//
// The architecture fields drive the 3D zone worlds in the Godot build. The
// browser prototype uses the palette for theming and ignores the rest.

import type { Element, Role } from "./config";

export const STAGES_PER_ZONE = 7;
export const ENCOUNTERS_PER_ZONE = 6;

export interface Zone {
  id: string;
  name: string;
  subtitle: string;
  element: Element;
  boss: string;
  names: string[];
  roles: Role[];
  accent: string;
  ground: string;
}

export const ZONES: Zone[] = [
  {
    id: "proving", name: "Ashen Proving Grounds",
    subtitle: "Where every climber is measured.",
    element: "Earth", boss: "Golem Warlord",
    names: ["Training Golem", "Rusted Automaton", "Stone Sentinel"],
    roles: ["Tank", "DPS"],
    accent: "#c08a4a", ground: "#2b2620",
  },
  {
    id: "hollow", name: "Verdant Hollow",
    subtitle: "The forest closed over this road a long time ago.",
    element: "Wind", boss: "Alpha Direwolf",
    names: ["Feral Wolf", "Bandit Scout", "Marsh Lurker"],
    roles: ["DPS", "Assassin", "Support"],
    accent: "#3ac9a6", ground: "#1b2b24",
  },
  {
    id: "emberfall", name: "Emberfall Reach",
    subtitle: "The mountain has been burning for an age.",
    element: "Fire", boss: "Cinder Tyrant",
    names: ["Ash Revenant", "Molten Husk", "Cinder Stalker"],
    roles: ["DPS", "Tank", "Assassin"],
    accent: "#e0532c", ground: "#2c1712",
  },
  {
    id: "duskmire", name: "Duskmire Bastion",
    subtitle: "A fortress built by people with nothing left to lose.",
    element: "Dark", boss: "The Bandit Kingpin",
    names: ["Bandit Raider", "Rogue Mercenary", "Cutthroat"],
    roles: ["DPS", "Assassin", "Tank"],
    accent: "#7a4ae0", ground: "#1e1a2c",
  },
  {
    id: "choir", name: "Choir of Silence",
    subtitle: "The hymn never stopped. Nobody is left to sing it.",
    element: "Light", boss: "High Cultist Mordrai",
    names: ["Dark Cultist", "Shadow Acolyte", "Void Priest"],
    roles: ["DPS", "Healer", "Support"],
    accent: "#e0c840", ground: "#2a2820",
  },
  {
    id: "heart", name: "The Tower's Heart",
    subtitle: "Everything above was only the approach.",
    element: "Dark", boss: "The Tower's Heart",
    names: ["Tower Wraith", "Voidbound Horror", "Nameless Sentinel"],
    roles: ["Tank", "DPS", "Assassin"],
    accent: "#ff2d95", ground: "#16121f",
  },
];

export const TOTAL_FLOORS = ZONES.length * STAGES_PER_ZONE;

export function zoneAt(index: number): Zone {
  return ZONES[Math.min(Math.max(index, 0), ZONES.length - 1)];
}

export function floorFor(zoneIndex: number, stageIndex: number): number {
  return zoneIndex * STAGES_PER_ZONE + stageIndex + 1;
}

export function zoneIndexForFloor(floorNumber: number): number {
  const i = Math.floor((floorNumber - 1) / STAGES_PER_ZONE);
  return Math.min(Math.max(i, 0), ZONES.length - 1);
}

export function stageIndexForFloor(floorNumber: number): number {
  return (floorNumber - 1) % STAGES_PER_ZONE;
}

export function zoneForFloor(floorNumber: number): Zone {
  return zoneAt(zoneIndexForFloor(floorNumber));
}

export function isBossStage(stageIndex: number): boolean {
  return stageIndex === STAGES_PER_ZONE - 1;
}

export function stageLabel(floorNumber: number): string {
  const stage = stageIndexForFloor(floorNumber);
  return isBossStage(stage) ? "Boss" : `Stage ${stage + 1}`;
}

/** A zone opens once the previous zone's boss has fallen. */
export function zoneUnlocked(zoneIndex: number, highestFloor: number): boolean {
  return zoneIndex <= 0 || highestFloor >= zoneIndex * STAGES_PER_ZONE;
}

export function stagesClearedIn(zoneIndex: number, highestFloor: number): number {
  const cleared = highestFloor - zoneIndex * STAGES_PER_ZONE;
  return Math.min(Math.max(cleared, 0), STAGES_PER_ZONE);
}

export function zoneComplete(zoneIndex: number, highestFloor: number): boolean {
  return stagesClearedIn(zoneIndex, highestFloor) >= STAGES_PER_ZONE;
}

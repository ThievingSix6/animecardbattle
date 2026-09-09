// Seeded RNG. The Godot project seeds a RandomNumberGenerator with
// hash(name) so a given card rolls identical stats on every launch; this
// reproduces that property in the browser.

export function hashString(text: string): number {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 16777619) >>> 0;
  }
  return h >>> 0;
}

export class Rng {
  private state: number;

  constructor(seed: number | string) {
    const n = typeof seed === "string" ? hashString(seed) : seed >>> 0;
    // A zero state would lock mulberry32 into a fixed point.
    this.state = n === 0 ? 0x9e3779b9 : n;
  }

  /** Uniform float in [0, 1). */
  randf(): number {
    this.state = (this.state + 0x6d2b79f5) >>> 0;
    let t = this.state;
    t = Math.imul(t ^ (t >>> 15), 1 | t);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }

  randfRange(from: number, to: number): number {
    return from + this.randf() * (to - from);
  }

  /** Integer in [0, max). */
  randi(max: number): number {
    return Math.floor(this.randf() * max) % Math.max(1, max);
  }

  pick<T>(list: readonly T[]): T {
    return list[this.randi(list.length)];
  }
}

/** Shared unseeded stream for live gameplay rolls. */
export const rng = new Rng(Date.now() >>> 0);

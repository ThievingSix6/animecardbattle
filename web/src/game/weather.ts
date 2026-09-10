// Ported from scripts/systems/weather.gd — timed global events that boost
// one element's pull rate and the player's luck while active.

import * as Config from "./config";
import type { WeatherEvent } from "./config";
import { rng } from "./rng";

// The Godot build checks every 5-15 minutes; the prototype runs a much
// tighter cycle so a player sees the system work within a short session.
const EVENT_DURATION = 45.0;
const EVENT_CHECK_MIN = 25.0;
const EVENT_CHECK_MAX = 50.0;
const EVENT_CHANCE = 0.6;

export class WeatherSystem {
  active: WeatherEvent | null = null;
  private remaining = 0;
  private nextCheck = 12.0;

  /** Advances the clock by `delta` seconds. Returns true if state changed. */
  update(delta: number): boolean {
    if (this.active) {
      this.remaining -= delta;
      if (this.remaining <= 0) {
        this.active = null;
        this.nextCheck = rng.randfRange(EVENT_CHECK_MIN, EVENT_CHECK_MAX);
        return true;
      }
      return false;
    }

    this.nextCheck -= delta;
    if (this.nextCheck > 0) return false;

    this.nextCheck = rng.randfRange(EVENT_CHECK_MIN, EVENT_CHECK_MAX);
    if (rng.randf() > EVENT_CHANCE) return false;

    this.active = rng.pick(Config.WEATHER_EVENTS);
    this.remaining = EVENT_DURATION;
    return true;
  }

  secondsRemaining(): number {
    return Math.max(0, Math.ceil(this.remaining));
  }

  boostedElement(): string {
    return this.active?.element ?? "";
  }

  luckMultiplier(): number {
    return this.active ? Config.EVENT_LUCK_MULT : 1.0;
  }
}

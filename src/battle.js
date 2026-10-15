// Auto-battle simulation. Pure logic with no DOM access, so it can run headless
// (see tools/sim-check.mjs) or be driven frame-by-frame by the battle view.
import { TROOPS, ENEMIES, LEVELS, REACH_UNIT, elementMultiplier } from './data.js';

export const FIELD = { w: 900, h: 420 };
const ROW_X = { front: 320, middle: 230, back: 140 };
export const ROWS = ['front', 'middle', 'back'];
const LANE_Y = [110, 215, 320];
const WAVE_PAUSE = 1.5;
const WAVE_HEAL = 0.25;
const TIME_LIMIT = 240;
const PROJECTILE_SPEED = 380;
const BODY = 22;

let nextId = 1;

function makeUnit(side, def, x, y, extra = {}) {
  return {
    id: nextId++, side, def, x, y, homeX: x, homeY: y,
    hp: def.hp, maxHp: def.hp, cd: Math.random() * 0.4, target: null,
    size: def.large ? 84 : 52, flash: 0, ...extra,
  };
}

// formation: [{ troop: {id, type}, row: 'front'|'middle'|'back', lane: 0..2 }]
export function createBattle(levelId, formation) {
  const level = LEVELS[levelId];
  const allies = formation.map(({ troop, row, lane }) =>
    makeUnit('ally', TROOPS[troop.type], ROW_X[row], LANE_Y[lane], { troopId: troop.id }));
  const battle = {
    levelId, level, allies, enemies: [], projectiles: [], popups: [],
    wave: 0, wavesCleared: 0, phase: 'fighting', pauseTimer: 0, time: 0,
    fallen: [],
  };
  spawnWave(battle, 0);
  return battle;
}

function spawnWave(battle, index) {
  const list = battle.level.waves[index];
  battle.wave = index;
  battle.enemies = list.map((key, i) => {
    const def = ENEMIES[key];
    const lane = i % 3;
    const depth = Math.floor(i / 3);
    const x = def.boss ? 700 : 640 + depth * 90 + (lane === 1 ? 0 : 25);
    const y = def.boss ? LANE_Y[1] : LANE_Y[lane];
    return makeUnit('enemy', def, x, y);
  });
}

const alive = (u) => u.hp > 0;
const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);

function pickTarget(unit, foes) {
  const living = foes.filter(alive);
  if (!living.length) return null;
  if (unit.def.targetLowestHp) {
    const inRange = living.filter((f) => dist(unit, f) <= unit.def.reach * REACH_UNIT + BODY);
    if (inRange.length) return inRange.reduce((a, b) => (b.hp < a.hp ? b : a));
  }
  return living.reduce((a, b) => (dist(unit, b) < dist(unit, a) ? b : a));
}

function damageFor(attacker, target) {
  let dmg = attacker.def.dmg * elementMultiplier(attacker.def.element, target.def.element);
  if (target.def.large && attacker.def.vsLarge) dmg *= attacker.def.vsLarge;
  // Kept fractional so stats scale cleanly; popups show the rounded value.
  return dmg * (0.9 + Math.random() * 0.2);
}

function applyDamage(battle, target, dmg) {
  if (!alive(target)) return;
  target.hp = Math.max(0, target.hp - dmg);
  target.flash = 0.15;
  battle.popups.push({ x: target.x, y: target.y - target.size / 2, text: `-${Math.max(1, Math.round(dmg))}`, t: 0, side: target.side });
  if (!alive(target) && target.side === 'ally') battle.fallen.push(target.troopId);
}

function stepUnit(battle, unit, friends, foes, dt) {
  unit.cd -= dt;
  unit.flash = Math.max(0, unit.flash - dt);
  if (!unit.target || !alive(unit.target) || unit.def.targetLowestHp) unit.target = pickTarget(unit, foes);
  const t = unit.target;
  if (!t) return;
  const reach = unit.def.reach * REACH_UNIT + (t.def.large ? BODY * 1.6 : BODY);
  const d = dist(unit, t);
  // The 1px slack stops units from stalling a hair outside reach due to float error.
  if (d > reach + 1) {
    const step = Math.min(unit.def.speed * dt, d - reach);
    unit.x += ((t.x - unit.x) / d) * step;
    unit.y += ((t.y - unit.y) / d) * step;
  } else if (unit.cd <= 0) {
    unit.cd = unit.def.cooldown;
    const dmg = damageFor(unit, t);
    if (unit.def.projectile) {
      battle.projectiles.push({ x: unit.x, y: unit.y - 6, target: t, dmg, color: unit.def.projectile });
    } else {
      applyDamage(battle, t, dmg);
    }
  }
  // Keep units from stacking on top of each other.
  for (const f of friends) {
    if (f === unit || !alive(f)) continue;
    const fd = dist(unit, f);
    const min = (unit.size + f.size) * 0.38;
    if (fd > 0 && fd < min) {
      const push = ((min - fd) / fd) * 0.5;
      unit.x += (unit.x - f.x) * push;
      unit.y += (unit.y - f.y) * push;
    }
  }
  unit.x = Math.max(30, Math.min(FIELD.w - 30, unit.x));
  unit.y = Math.max(50, Math.min(FIELD.h - 30, unit.y));
}

export function stepBattle(battle, dt) {
  if (battle.phase === 'won' || battle.phase === 'lost') return battle;
  battle.time += dt;
  for (const p of battle.popups) p.t += dt;
  battle.popups = battle.popups.filter((p) => p.t < 0.8);

  if (battle.phase === 'intermission') {
    battle.pauseTimer -= dt;
    if (battle.pauseTimer <= 0) {
      // Survivors regroup and recover a quarter of their health between waves.
      for (const a of battle.allies.filter(alive)) {
        a.x = a.homeX; a.y = a.homeY; a.target = null;
        a.hp = Math.min(a.maxHp, a.hp + Math.round(a.maxHp * WAVE_HEAL));
      }
      spawnWave(battle, battle.wave + 1);
      battle.phase = 'fighting';
    }
    return battle;
  }

  for (const u of battle.allies) if (alive(u)) stepUnit(battle, u, battle.allies, battle.enemies, dt);
  for (const u of battle.enemies) if (alive(u)) stepUnit(battle, u, battle.enemies, battle.allies, dt);

  for (const p of battle.projectiles) {
    const d = dist(p, p.target);
    const step = PROJECTILE_SPEED * dt;
    if (d <= step || !alive(p.target)) {
      applyDamage(battle, p.target, p.dmg);
      p.done = true;
    } else {
      p.x += ((p.target.x - p.x) / d) * step;
      p.y += ((p.target.y - p.y) / d) * step;
    }
  }
  battle.projectiles = battle.projectiles.filter((p) => !p.done);

  if (!battle.allies.some(alive) || battle.time > TIME_LIMIT) {
    battle.phase = 'lost';
  } else if (!battle.enemies.some(alive)) {
    battle.wavesCleared = battle.wave + 1;
    if (battle.wave + 1 >= battle.level.waves.length) {
      battle.phase = 'won';
    } else {
      battle.phase = 'intermission';
      battle.pauseTimer = WAVE_PAUSE;
      battle.projectiles = [];
    }
  }
  return battle;
}

// Runs the rest of a battle instantly (used by Skip and the balance check).
export function resolveBattle(battle) {
  while (battle.phase !== 'won' && battle.phase !== 'lost') stepBattle(battle, 1 / 30);
  return battle;
}

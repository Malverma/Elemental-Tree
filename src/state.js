// Game state, save/load, real-time production and player actions.
import { ECONOMY, PARTS, TROOPS, LEVELS, ELEMENTS, STORAGE_CAP_MINUTES } from './data.js';
import { ROWS } from './battle.js';

const SAVE_KEY = 'elemental-tree-save-v1';

export function newGame(now = Date.now()) {
  return {
    version: 1,
    lastTick: now,
    resources: { sunlight: 0, sap: 0, power: Object.fromEntries(ELEMENTS.map((e) => [e, 0])) },
    pending: { sunlight: 0, sap: 0 },
    tree: { level: 1, xp: 0, roots: PARTS.roots.startLevel, trunk: PARTS.trunk.startLevel, branches: PARTS.branches.startLevel },
    troops: [],
    nextTroopId: 1,
    formation: [], // [{ troopId, row, lane }]
    levels: {}, // levelId -> { conquered, stored, clears }
    log: [],
  };
}

export function load() {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    if (raw) {
      const data = JSON.parse(raw);
      if (data.version === 1) return data;
    }
  } catch { /* fall through to a new game */ }
  return newGame();
}

export function save(state) {
  try { localStorage.setItem(SAVE_KEY, JSON.stringify(state)); } catch { /* storage unavailable */ }
}

export function resetSave() {
  try { localStorage.removeItem(SAVE_KEY); } catch { /* ignore */ }
}

// --- Derived values ---------------------------------------------------------

export const rates = (s) => ({
  sunlight: ECONOMY.sunlightPerMin(s.tree.branches),
  sap: ECONOMY.sapPerMin(s.tree.trunk),
});
export const caps = (s) => {
  const r = rates(s);
  return { sunlight: r.sunlight * STORAGE_CAP_MINUTES, sap: r.sap * STORAGE_CAP_MINUTES };
};
export const reach = (s) => ECONOMY.rootReach(s.tree.roots);
export const formationSlots = (s) => ECONOMY.formationSlots(s.tree.trunk);
export const rosterCap = (s) => ECONOMY.rosterCap(s.tree.level);
export const levelState = (s, id) => s.levels[id] ?? { conquered: false, stored: 0, clears: 0 };
export const canReach = (s, id) => LEVELS[id].distance <= reach(s);

// --- Time -------------------------------------------------------------------

export function tick(state, now = Date.now()) {
  const minutes = Math.max(0, (now - state.lastTick) / 60000);
  state.lastTick = now;
  advance(state, minutes);
}

// Adds `minutes` of production. Also used by the dev time-warp button.
export function advance(state, minutes) {
  const r = rates(state);
  const c = caps(state);
  state.pending.sunlight = Math.min(c.sunlight, state.pending.sunlight + r.sunlight * minutes);
  state.pending.sap = Math.min(c.sap, state.pending.sap + r.sap * minutes);
  for (const [id, ls] of Object.entries(state.levels)) {
    if (!ls.conquered) continue;
    const daily = LEVELS[id].dailyYield;
    ls.stored = Math.min(daily, ls.stored + (daily / STORAGE_CAP_MINUTES) * minutes);
  }
}

// --- Actions (each returns { ok, msg }) ---------------------------------------

const ok = (msg) => ({ ok: true, msg });
const fail = (msg) => ({ ok: false, msg });

export function collect(state) {
  const sun = Math.floor(state.pending.sunlight);
  const sap = Math.floor(state.pending.sap);
  if (sun + sap === 0) return fail('Nothing to collect yet.');
  state.resources.sunlight += sun;
  state.resources.sap += sap;
  state.pending.sunlight -= sun;
  state.pending.sap -= sap;
  return ok(`Collected ${sun} sunlight and ${sap} sap.`);
}

// Tapping the branches gathers sunlight straight into the player's stock.
export function tapBranches(state) {
  state.resources.sunlight += ECONOMY.tapSunlight;
  return ok();
}

export function collectLevel(state, id) {
  const ls = levelState(state, id);
  const amount = Math.floor(ls.stored);
  if (!ls.conquered || amount === 0) return fail('No power stored yet.');
  ls.stored -= amount;
  const el = LEVELS[id].element;
  state.resources.power[el] += amount;
  return ok(`Collected ${amount} ${el} power.`);
}

function addXp(state, amount) {
  const t = state.tree;
  t.xp += amount;
  let ups = 0;
  while (t.xp >= ECONOMY.xpToNext(t.level)) {
    t.xp -= ECONOMY.xpToNext(t.level);
    t.level += 1;
    ups += 1;
  }
  return ups;
}

// Feed sunlight into the tree's growth (1 sunlight = 1 XP).
export function channel(state, amount) {
  const needed = ECONOMY.xpToNext(state.tree.level) - state.tree.xp;
  const spend = Math.min(amount ?? needed, state.resources.sunlight);
  if (spend <= 0) return fail('Not enough sunlight.');
  state.resources.sunlight -= spend;
  const ups = addXp(state, spend);
  return ok(ups ? `The tree grew to level ${state.tree.level}!` : `Channeled ${spend} sunlight.`);
}

export function partCost(state, part) {
  return PARTS[part].cost(state.tree[part]);
}

export function canUpgrade(state, part) {
  if (state.tree[part] >= state.tree.level) return fail(`Grow the tree to level ${state.tree[part] + 1} first.`);
  const cost = partCost(state, part);
  for (const [res, amt] of Object.entries(cost)) {
    if (state.resources[res] < amt) return fail(`Need ${amt} ${res}.`);
  }
  return ok('');
}

export function upgradePart(state, part) {
  const check = canUpgrade(state, part);
  if (!check.ok) return check;
  for (const [res, amt] of Object.entries(partCost(state, part))) state.resources[res] -= amt;
  state.tree[part] += 1;
  return ok(`${PARTS[part].name} upgraded to level ${state.tree[part]}.`);
}

export function canSummon(state, type) {
  const def = TROOPS[type];
  if (state.tree.level < def.unlockLevel) return fail(`Unlocks at tree level ${def.unlockLevel}.`);
  if (state.troops.length >= rosterCap(state)) return fail('Roster is full.');
  if (state.resources.sap < def.sapCost) return fail(`Need ${def.sapCost} sap.`);
  return ok('');
}

export function summon(state, type) {
  const check = canSummon(state, type);
  if (!check.ok) return check;
  const def = TROOPS[type];
  state.resources.sap -= def.sapCost;
  const troop = { id: state.nextTroopId++, type };
  state.troops.push(troop);
  autoPlace(state, troop);
  return ok(`A ${def.name} sprouts from the trunk.`);
}

const cellTaken = (state, row, lane) => state.formation.some((f) => f.row === row && f.lane === lane);

// Puts a new troop in its preferred row if a formation slot is free.
function autoPlace(state, troop) {
  if (state.formation.length >= formationSlots(state)) return;
  const pref = TROOPS[troop.type].preferredRow;
  const order = [pref, ...ROWS.filter((r) => r !== pref)];
  for (const row of order) {
    for (const lane of [1, 0, 2]) {
      if (!cellTaken(state, row, lane)) {
        state.formation.push({ troopId: troop.id, row, lane });
        return;
      }
    }
  }
}

// Places a troop at a cell (or removes it when troopId is null).
export function placeTroop(state, troopId, row, lane) {
  state.formation = state.formation.filter((f) => !(f.row === row && f.lane === lane));
  if (troopId == null) return ok('');
  const existing = state.formation.findIndex((f) => f.troopId === troopId);
  if (existing >= 0) state.formation.splice(existing, 1);
  else if (state.formation.length >= formationSlots(state)) return fail('All formation slots are used. Upgrade the trunk for more.');
  state.formation.push({ troopId, row, lane });
  return ok('');
}

// Moves the troop in one cell to another, swapping if the target cell is occupied.
export function moveTroop(state, fromRow, fromLane, toRow, toLane) {
  const from = state.formation.find((f) => f.row === fromRow && f.lane === fromLane);
  if (!from) return fail('');
  const to = state.formation.find((f) => f.row === toRow && f.lane === toLane);
  if (to) {
    to.row = fromRow;
    to.lane = fromLane;
  }
  from.row = toRow;
  from.lane = toLane;
  return ok('');
}

export function formationTroops(state) {
  return state.formation
    .map((f) => ({ ...f, troop: state.troops.find((t) => t.id === f.troopId) }))
    .filter((f) => f.troop);
}

export function canEnter(state, id) {
  const lvl = LEVELS[id];
  if (!lvl.playable) return fail('Coming soon.');
  if (!canReach(state, id)) return fail(`Roots must reach distance ${lvl.distance}.`);
  if (!formationTroops(state).length) return fail('Place troops in your formation first.');
  return ok('');
}

// Applies a finished battle. Fallen troops are lost for good.
export function applyBattleResult(state, battle) {
  const fallen = new Set(battle.fallen);
  state.troops = state.troops.filter((t) => !fallen.has(t.id));
  state.formation = state.formation.filter((f) => !fallen.has(f.troopId));

  const lvl = LEVELS[battle.levelId];
  const ls = (state.levels[battle.levelId] ??= { conquered: false, stored: 0, clears: 0 });
  const won = battle.phase === 'won';
  const firstClear = won && !ls.conquered;
  let xp = 10 * battle.wavesCleared;
  let sap = 0;
  if (won) {
    xp = firstClear ? lvl.rewards.firstXp : lvl.rewards.xp;
    sap = lvl.rewards.sap;
    ls.clears += 1;
    ls.conquered = true;
  }
  state.resources.sap += sap;
  const levelUps = addXp(state, xp);
  return { won, firstClear, xp, sap, lost: fallen.size, levelUps, newLevel: state.tree.level };
}

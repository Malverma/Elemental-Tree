// Headless balance check: runs each level many times with sample squads.
// Run: node tools/sim-check.mjs
import { createBattle, resolveBattle } from '../src/battle.js';

const squad = (...types) => {
  const rowOf = { soldier: 'front', spearman: 'middle', archer: 'back' };
  const used = {};
  return types.map((type, i) => {
    const row = rowOf[type];
    const lane = [1, 0, 2][(used[row] = (used[row] ?? -1) + 1)];
    return { troop: { id: i + 1, type }, row, lane };
  });
};

const scenarios = [
  ['sunny_meadow', squad('soldier', 'soldier')],
  ['sunny_meadow', squad('soldier', 'soldier', 'soldier')],
  ['sunny_meadow', squad('soldier', 'soldier', 'spearman')],
  ['sunny_meadow', squad('soldier', 'soldier', 'spearman', 'archer')],
  ['whispering_spring', squad('soldier', 'soldier', 'spearman', 'archer')],
  ['whispering_spring', squad('soldier', 'soldier', 'spearman', 'archer', 'archer')],
  ['whispering_spring', squad('soldier', 'soldier', 'soldier', 'spearman', 'spearman', 'archer')],
];

const RUNS = 200;
for (const [level, formation] of scenarios) {
  let wins = 0, lost = 0, waves = 0, time = 0;
  for (let i = 0; i < RUNS; i++) {
    const b = resolveBattle(createBattle(level, formation));
    if (b.phase === 'won') wins++;
    lost += b.fallen.length;
    waves += b.wavesCleared;
    time += b.time;
  }
  const names = formation.map((f) => f.troop.type).join(', ');
  console.log(
    `${level.padEnd(18)} [${names}]`.padEnd(80),
    `win ${(100 * wins / RUNS).toFixed(0).padStart(3)}%`,
    `avg waves ${(waves / RUNS).toFixed(1)}`,
    `avg lost ${(lost / RUNS).toFixed(1)}`,
    `avg ${(time / RUNS).toFixed(0)}s`,
  );
}

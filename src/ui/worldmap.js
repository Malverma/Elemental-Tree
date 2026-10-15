import * as S from '../state.js';
import { LEVELS, WAYPOINTS, GROVE, ENEMIES, BIOME_COLORS } from '../data.js';
import { icon, elementIcon } from './common.js';

const nodePos = (id) => (id === 'grove' ? GROVE : LEVELS[id] ?? WAYPOINTS[id]);

function rootPath(from, to) {
  const a = nodePos(from), b = nodePos(to);
  const mx = (a.x + b.x) / 2 + (b.y - a.y) * 0.15;
  const my = (a.y + b.y) / 2 - (b.x - a.x) * 0.15;
  return `M${a.x} ${a.y} Q${mx} ${my} ${b.x} ${b.y}`;
}

export function renderMap(el, app) {
  const s = app.state;
  const reach = S.reach(s);
  const sel = app.ui.selectedLevel;
  const nodes = { ...WAYPOINTS, ...LEVELS };

  const biomes = Object.values(LEVELS).map((l) =>
    `<ellipse cx="${l.x}" cy="${l.y}" rx="130" ry="95" fill="${BIOME_COLORS[l.element]}" opacity="0.18"/>`).join('');

  const paths = Object.entries(nodes).map(([id, n]) => {
    const d = rootPath(n.from, id);
    const rooted = n.distance <= reach;
    return rooted
      ? `<path d="${d}" class="root rooted"/><path d="${d}" class="root-core"/>`
      : `<path d="${d}" class="root unrooted"/>`;
  }).join('');

  const levelNodes = Object.entries(LEVELS).map(([id, l]) => {
    const ls = S.levelState(s, id);
    const rooted = S.canReach(s, id);
    const cls = ['node', rooted ? 'rooted' : 'far', l.playable ? '' : 'soon', ls.conquered ? 'conquered' : '', sel === id ? 'selected' : ''].join(' ');
    return `
    <g class="${cls}" data-level="${id}" tabindex="0" role="button" aria-label="${l.name}">
      <circle cx="${l.x}" cy="${l.y}" r="34" fill="${BIOME_COLORS[l.element]}"/>
      <image href="assets/${elementIcon(l.element)}.svg" x="${l.x - 18}" y="${l.y - 18}" width="36" height="36"/>
      ${ls.conquered ? `<circle cx="${l.x + 26}" cy="${l.y - 26}" r="9" class="flag"/>` : ''}
      <text x="${l.x}" y="${l.y + 54}" class="label">${l.name}</text>
      <text x="${l.x}" y="${l.y + 70}" class="sublabel">${l.playable ? `Reach ${l.distance}` : 'Coming soon'}</text>
    </g>`;
  }).join('');

  el.innerHTML = `
  <section class="worldmap">
    <div class="panel map-panel">
      <svg viewBox="0 0 1000 620" class="map">
        <rect width="1000" height="620" fill="var(--map-bg)"/>
        ${biomes}
        ${paths}
        <g class="grove-node">
          <circle cx="${GROVE.x}" cy="${GROVE.y}" r="40" fill="var(--leaf)" stroke="var(--leaf-dark)" stroke-width="3"/>
          <rect x="${GROVE.x - 5}" y="${GROVE.y}" width="10" height="26" fill="var(--bark)"/>
          <text x="${GROVE.x}" y="${GROVE.y + 62}" class="label">Home Grove</text>
        </g>
        ${levelNodes}
      </svg>
      <p class="muted small">Roots reach distance <b>${reach}</b>. Upgrade the roots in the Grove to reach farther lands.</p>
    </div>
    <div class="panel level-info">${levelInfo(s, sel)}</div>
  </section>`;

  el.querySelectorAll('[data-level]').forEach((g) => {
    const pick = () => { app.ui.selectedLevel = g.dataset.level; app.render(); };
    g.addEventListener('click', pick);
    g.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') pick(); });
  });
  el.querySelector('[data-enter]')?.addEventListener('click', () => app.startBattle(sel));
  el.querySelector('[data-collect-level]')?.addEventListener('click', () => app.act(S.collectLevel, sel));
  liveMap(el, app);
}

function levelInfo(s, id) {
  const l = LEVELS[id];
  const ls = S.levelState(s, id);
  const head = `
    <h2>${icon(elementIcon(l.element), 22)} ${l.name}</h2>
    <p class="muted">${l.biome} · ${l.element[0].toUpperCase() + l.element.slice(1)} · Root distance ${l.distance}</p>`;
  if (!l.playable) return `${head}<p>This land is still being prepared. Coming in a future build.</p>`;

  const enemies = [...new Set(l.waves.flat())];
  const enter = S.canEnter(s, id);
  return `${head}
    <p><b>Status:</b> ${ls.conquered ? `Conquered (${ls.clears} clear${ls.clears === 1 ? '' : 's'})` : S.canReach(s, id) ? 'Rooted, ready to attack' : 'Out of reach'}</p>
    <h3>Enemies</h3>
    <div class="enemy-list">
      ${enemies.map((k) => `<span class="enemy"><img src="assets/${ENEMIES[k].img}.svg" alt="">${ENEMIES[k].name}${ENEMIES[k].boss ? ' <b>(boss)</b>' : ''}</span>`).join('')}
    </div>
    <p class="muted small">${l.waves.length - 1} waves + boss wave. Survivors recover 25% HP between waves.</p>
    <h3>Rewards</h3>
    <ul class="rates">
      <li>First clear: ${l.rewards.firstXp} growth, ${icon('icon_sap')} ${l.rewards.sap}</li>
      <li>Replays: ${l.rewards.xp} growth, ${icon('icon_sap')} ${l.rewards.sap}</li>
      <li>Once conquered: ${icon(elementIcon(l.element))} ${l.dailyYield} ${l.element} power per day</li>
    </ul>
    ${ls.conquered ? `
      <div class="row">
        <span>${icon(elementIcon(l.element))} Stored: <b data-live="stored"></b> / ${l.dailyYield}</span>
        <button data-collect-level>Collect</button>
      </div>` : ''}
    <button class="primary wide" data-enter ${enter.ok ? '' : 'disabled'}>${ls.conquered ? 'Battle again' : 'Attack'}</button>
    ${enter.ok ? '' : `<p class="hint">${enter.msg}</p>`}`;
}

export function liveMap(el, app) {
  const n = el.querySelector('[data-live="stored"]');
  if (n) n.textContent = Math.floor(S.levelState(app.state, app.ui.selectedLevel).stored);
}

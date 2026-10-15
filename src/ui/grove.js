import * as S from '../state.js';
import { ECONOMY, PARTS } from '../data.js';
import { icon, fmt, costHtml } from './common.js';
import { treeSvg } from './treeArt.js';

const STAGES = [[35, 'World Tree'], [20, 'Elder Tree'], [10, 'Grown Tree'], [5, 'Young Tree'], [1, 'Sapling']];
const stageName = (lvl) => STAGES.find(([min]) => lvl >= min)[1];

export function renderGrove(el, app) {
  const s = app.state;
  const { tree } = s;
  const need = ECONOMY.xpToNext(tree.level);
  const r = S.rates(s);

  el.innerHTML = `
  <section class="grove">
    <div class="panel tree-panel">
      ${treeSvg(tree)}
      <p class="tap-hint">Tap the branches to gather ${icon('icon_sunlight', 16)} ${ECONOMY.tapSunlight} sunlight</p>
      <div class="collect">
        <div class="pending">
          <span>${icon('icon_sunlight')}<b data-live="pending-sun"></b></span>
          <span>${icon('icon_sap')}<b data-live="pending-sap"></b></span>
        </div>
        <button class="primary" data-collect>Collect</button>
        <p class="muted small">Stores up to 24 hours of production.</p>
      </div>
    </div>

    <div class="side">
      <div class="panel">
        <h2>${stageName(tree.level)} <span class="muted">· Level ${tree.level}</span></h2>
        <div class="bar"><div style="width:${(100 * tree.xp) / need}%"></div></div>
        <p class="muted small">${fmt(tree.xp)} / ${fmt(need)} growth. Channel sunlight or win battles to grow.
          Each tree part can be upgraded up to the tree's level.</p>
        <div class="row">
          <button data-channel="10">Channel 10 ${icon('icon_sunlight', 16)}</button>
          <button data-channel="max">Channel to next level</button>
        </div>
        <ul class="rates">
          <li>${icon('icon_sunlight')} ${r.sunlight} sunlight / min</li>
          <li>${icon('icon_sap')} ${r.sap} sap / min</li>
        </ul>
      </div>

      ${Object.entries(PARTS).map(([key, part]) => partCard(s, key, part)).join('')}
    </div>
  </section>`;

  const crown = el.querySelector('[data-tap]');
  crown.addEventListener('pointerdown', (e) => tap(el, app, e.clientX, e.clientY));
  crown.addEventListener('keydown', (e) => {
    if (e.key !== 'Enter' && e.key !== ' ') return;
    e.preventDefault();
    const box = crown.getBoundingClientRect();
    tap(el, app, box.x + box.width / 2, box.y + box.height / 2, true);
  });
  el.querySelector('[data-collect]').onclick = () => app.act(S.collect);
  el.querySelectorAll('[data-channel]').forEach((b) => {
    b.onclick = () => app.act(S.channel, b.dataset.channel === 'max' ? undefined : 10);
  });
  el.querySelectorAll('[data-upgrade]').forEach((b) => {
    b.onclick = () => app.act(S.upgradePart, b.dataset.upgrade);
  });
  liveGrove(el, app);
}

// Gathers sunlight from a tap and floats a "+1" where the player tapped.
function tap(el, app, x, y, refocus = false) {
  app.act(S.tapBranches);
  const panel = el.querySelector('.tree-panel');
  const box = panel.getBoundingClientRect();
  const pop = document.createElement('span');
  pop.className = 'tap-pop';
  pop.textContent = `+${ECONOMY.tapSunlight}`;
  pop.style.left = `${x - box.x}px`;
  pop.style.top = `${y - box.y}px`;
  panel.append(pop);
  setTimeout(() => pop.remove(), 700);
  if (refocus) el.querySelector('[data-tap]').focus();
}

function partCard(s, key, part) {
  const lvl = s.tree[key];
  const check = S.canUpgrade(s, key);
  return `
  <div class="panel part">
    <div class="part-head">
      <h3>${part.name} <span class="muted">Lv ${lvl}</span></h3>
      <span class="effect">${part.effect(lvl)} → <b>${part.effect(lvl + 1)}</b></span>
    </div>
    <p class="muted small">${part.blurb}</p>
    <div class="row">
      <span class="costs">${costHtml(S.partCost(s, key), s)}</span>
      <button data-upgrade="${key}" ${check.ok ? '' : 'disabled'} title="${check.msg}">Upgrade</button>
    </div>
    ${lvl >= s.tree.level ? `<p class="hint">Needs tree level ${lvl + 1}.</p>` : ''}
  </div>`;
}

export function liveGrove(el, app) {
  const p = app.state.pending;
  const set = (k, v) => { const n = el.querySelector(`[data-live="${k}"]`); if (n) n.textContent = v; };
  set('pending-sun', fmt(p.sunlight));
  set('pending-sap', fmt(p.sap));
}

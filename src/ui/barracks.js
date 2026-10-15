import * as S from '../state.js';
import { TROOPS } from '../data.js';
import { ROWS } from '../battle.js';
import { icon } from './common.js';

const ROW_LABEL = { back: 'Back', middle: 'Middle', front: 'Front' };

export function renderBarracks(el, app) {
  const s = app.state;
  const sel = app.ui.selectedTroop;
  const placed = new Map(s.formation.map((f) => [`${f.row}:${f.lane}`, f.troopId]));
  const inFormation = new Set(s.formation.map((f) => f.troopId));
  const troopById = new Map(s.troops.map((t) => [t.id, t]));

  el.innerHTML = `
  <section class="barracks">
    <div class="panel">
      <h2>Grow troops</h2>
      <p class="muted small">Troops sprout from the trunk and cost sap. <b>Fallen troops are lost for good.</b></p>
      <div class="summon-grid">
        ${Object.entries(TROOPS).map(([type, d]) => summonCard(s, type, d)).join('')}
      </div>
    </div>

    <div class="panel">
      <div class="part-head">
        <h2>Formation</h2>
        <span class="muted">${s.formation.length} / ${S.formationSlots(s)} slots · upgrade the trunk for more</span>
      </div>
      <p class="muted small">Pick a troop from the roster, then a cell. Drag a placed troop to move it (dropping on another troop swaps them). Click a placed troop to remove it.</p>
      <div class="enemy-ahead">↑ Enemies ahead ↑</div>
      <div class="formation">
        <div></div>${[0, 1, 2].map((lane) => `<div class="col-label">Lane ${lane + 1}</div>`).join('')}
        ${ROWS.map((row) => `
          <div class="row-label ${row}">${ROW_LABEL[row]}</div>
          ${[0, 1, 2].map((lane) => {
            const t = troopById.get(placed.get(`${row}:${lane}`));
            return `<button class="cell ${t ? 'filled' : ''}" data-row="${row}" data-lane="${lane}">
              ${t ? `<img src="assets/${TROOPS[t.type].img}.svg" alt="${TROOPS[t.type].name}" draggable="false">` : '+'}
            </button>`;
          }).join('')}`).join('')}
      </div>
    </div>

    <div class="panel">
      <div class="part-head">
        <h2>Roster</h2>
        <span class="muted">${s.troops.length} / ${S.rosterCap(s)}</span>
      </div>
      ${s.troops.length ? '' : '<p class="muted">No troops yet. Grow some above.</p>'}
      <div class="roster">
        ${s.troops.map((t) => `
          <button class="troop ${sel === t.id ? 'selected' : ''}" data-troop="${t.id}">
            <img src="assets/${TROOPS[t.type].img}.svg" alt="">
            <span>${TROOPS[t.type].name} <span class="muted">#${t.id}</span></span>
            ${inFormation.has(t.id) ? '<span class="badge">placed</span>' : ''}
          </button>`).join('')}
      </div>
    </div>
  </section>`;

  el.querySelectorAll('[data-summon]').forEach((b) => {
    b.onclick = () => app.act(S.summon, b.dataset.summon);
  });
  el.querySelectorAll('[data-troop]').forEach((b) => {
    b.onclick = () => {
      const id = Number(b.dataset.troop);
      app.ui.selectedTroop = sel === id ? null : id;
      app.render();
    };
  });
  let dragged = false;
  el.querySelectorAll('.cell').forEach((c) => {
    c.onclick = () => {
      if (dragged) return;
      const { row } = c.dataset;
      const lane = Number(c.dataset.lane);
      if (sel != null) {
        app.ui.selectedTroop = null;
        app.act(S.placeTroop, sel, row, lane);
      } else if (c.classList.contains('filled')) {
        app.act(S.placeTroop, null, row, lane);
      }
    };
    if (c.classList.contains('filled')) {
      c.addEventListener('pointerdown', (e) => startDrag(e, c, app, (v) => { dragged = v; }));
    }
  });
}

// Drags a placed troop with the pointer (mouse or touch). Dropping it on another
// cell moves it there, swapping with any troop already in that cell.
function startDrag(e, cell, app, setDragged) {
  if (e.button !== 0) return;
  const startX = e.clientX, startY = e.clientY;
  let ghost = null;
  let over = null;

  const cellAt = (x, y) => document.elementFromPoint(x, y)?.closest('.formation .cell');
  const move = (ev) => {
    if (!ghost) {
      if (Math.hypot(ev.clientX - startX, ev.clientY - startY) < 6) return;
      setDragged(true);
      ghost = cell.querySelector('img').cloneNode();
      ghost.className = 'drag-ghost';
      document.body.append(ghost);
      cell.classList.add('dragging');
    }
    ghost.style.left = `${ev.clientX}px`;
    ghost.style.top = `${ev.clientY}px`;
    const target = cellAt(ev.clientX, ev.clientY);
    if (target !== over) {
      over?.classList.remove('drop-target');
      over = target && target !== cell ? target : null;
      over?.classList.add('drop-target');
    }
  };
  const end = (ev) => {
    removeEventListener('pointermove', move);
    removeEventListener('pointerup', end);
    removeEventListener('pointercancel', end);
    if (!ghost) return;
    ghost.remove();
    cell.classList.remove('dragging');
    over?.classList.remove('drop-target');
    const target = ev.type === 'pointerup' ? cellAt(ev.clientX, ev.clientY) : null;
    if (target && target !== cell) {
      app.act(S.moveTroop, cell.dataset.row, Number(cell.dataset.lane), target.dataset.row, Number(target.dataset.lane));
    }
    // The click that follows a drag must not count as "remove troop".
    setTimeout(() => setDragged(false));
  };
  addEventListener('pointermove', move);
  addEventListener('pointerup', end);
  addEventListener('pointercancel', end);
}

function summonCard(s, type, d) {
  const check = S.canSummon(s, type);
  const locked = s.tree.level < d.unlockLevel;
  return `
  <div class="summon ${locked ? 'locked' : ''}">
    <img src="assets/${d.img}.svg" alt="" width="64" height="64">
    <h3>${d.name}</h3>
    <p class="muted small">${d.role}</p>
    <dl class="stats">
      <dt>HP</dt><dd>${d.hp}</dd><dt>DMG</dt><dd>${d.dmg}</dd><dt>Reach</dt><dd>${d.reach}${d.reach === 1 ? ' (melee)' : ''}</dd>
    </dl>
    ${locked
      ? `<p class="hint">Unlocks at tree level ${d.unlockLevel}</p>`
      : `<button data-summon="${type}" ${check.ok ? '' : 'disabled'} title="${check.msg}">Grow ${icon('icon_sap', 16)}${d.sapCost}</button>`}
  </div>`;
}

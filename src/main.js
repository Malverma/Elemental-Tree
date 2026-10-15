import * as S from './state.js';
import { icon, fmt } from './ui/common.js';
import { renderGrove, liveGrove } from './ui/grove.js';
import { renderBarracks } from './ui/barracks.js';
import { renderMap, liveMap } from './ui/worldmap.js';
import { openBattle } from './ui/battleView.js';

const views = {
  grove: { render: renderGrove, live: liveGrove },
  barracks: { render: renderBarracks },
  map: { render: renderMap, live: liveMap },
};

const app = {
  state: S.load(),
  tab: views[location.hash.slice(1)] ? location.hash.slice(1) : 'grove',
  ui: { selectedTroop: null, selectedLevel: 'sunny_meadow' },

  // Runs a state action, shows its message, saves and re-renders.
  act(action, ...args) {
    const res = action(app.state, ...args);
    if (res?.msg) toast(res.msg, res.ok ? 'good' : 'bad');
    app.save();
    app.render();
    return res;
  },
  save() { S.save(app.state); },
  render() {
    renderResources();
    const el = document.getElementById('view');
    el.innerHTML = '';
    views[app.tab].render(el, app);
  },
  switchTab(tab) {
    app.tab = tab;
    history.replaceState(null, '', `#${tab}`);
    for (const b of document.querySelectorAll('#tabs button')) b.classList.toggle('active', b.dataset.tab === tab);
    app.render();
  },
  startBattle(levelId) {
    const check = S.canEnter(app.state, levelId);
    if (!check.ok) return toast(check.msg, 'bad');
    openBattle(app, levelId);
  },
  toast,
};

function renderResources() {
  const { resources: r, tree } = app.state;
  const chips = [
    ['icon_sunlight', 'Sunlight', r.sunlight],
    ['icon_sap', 'Sap', r.sap],
    ['icon_nature', 'Nature power', r.power.nature],
    ['icon_water', 'Water power', r.power.water],
  ];
  document.getElementById('resources').innerHTML =
    `<span class="chip level" title="Tree level">Lv ${tree.level}</span>` +
    chips.map(([img, label, v]) => `<span class="chip" title="${label}">${icon(img, 20)}${fmt(v)}</span>`).join('');
}

function toast(msg, kind = 'good') {
  const box = document.getElementById('toasts');
  const t = document.createElement('div');
  t.className = `toast ${kind}`;
  t.textContent = msg;
  box.append(t);
  setTimeout(() => t.classList.add('out'), 2600);
  setTimeout(() => t.remove(), 3100);
}

document.getElementById('tabs').addEventListener('click', (e) => {
  const tab = e.target.closest('button')?.dataset.tab;
  if (tab) app.switchTab(tab);
});

// Dev helpers: open with ?dev=1 for a time-warp and reset button.
if (new URLSearchParams(location.search).has('dev')) {
  const dev = document.getElementById('dev');
  dev.innerHTML = '<button data-warp>+1 hour</button><button data-reset>Reset</button>';
  dev.addEventListener('click', (e) => {
    if (e.target.matches('[data-warp]')) { S.advance(app.state, 60); app.save(); app.render(); }
    if (e.target.matches('[data-reset]') && confirm('Delete your save and start over?')) {
      S.resetSave();
      app.state = S.newGame();
      app.render();
    }
  });
}

S.tick(app.state);
app.switchTab(app.tab);

setInterval(() => {
  S.tick(app.state);
  views[app.tab].live?.(document.getElementById('view'), app);
}, 1000);
setInterval(() => app.save(), 5000);
window.elementalTree = app;
addEventListener('beforeunload', () => app.save());

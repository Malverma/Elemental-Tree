import * as S from '../state.js';
import { LEVELS, ENEMIES, BIOME_COLORS } from '../data.js';
import { createBattle, stepBattle, resolveBattle, FIELD } from '../battle.js';
import { icon } from './common.js';

const images = {};
function img(name) {
  if (!images[name]) {
    images[name] = new Image();
    images[name].src = `assets/${name}.svg`;
  }
  return images[name];
}

export function openBattle(app, levelId) {
  const s = app.state;
  const level = LEVELS[levelId];
  const canSkip = S.levelState(s, levelId).conquered;
  const battle = createBattle(levelId, S.formationTroops(s));
  for (const u of battle.allies) img(u.def.img);
  for (const key of level.waves.flat()) img(ENEMIES[key].img);

  const root = document.getElementById('battle');
  root.hidden = false;
  root.innerHTML = `
  <div class="battle-box">
    <div class="battle-bar">
      <h2>${icon(`icon_${level.element}`, 22)} ${level.name}</h2>
      <span class="wave" data-wave></span>
      <div class="row">
        <button data-pause>Pause</button>
        <button data-speed>Speed 1×</button>
        ${canSkip ? '<button data-skip>Skip</button>' : ''}
        <button data-retreat class="danger">Retreat</button>
      </div>
    </div>
    <canvas width="${FIELD.w}" height="${FIELD.h}"></canvas>
    <div class="battle-result" hidden></div>
  </div>`;

  const canvas = root.querySelector('canvas');
  const ctx = canvas.getContext('2d');
  let speed = 1, paused = false, finished = false, last = performance.now();

  root.querySelector('[data-pause]').onclick = (e) => {
    paused = !paused;
    e.target.textContent = paused ? 'Resume' : 'Pause';
  };
  root.querySelector('[data-speed]').onclick = (e) => {
    speed = speed === 1 ? 2 : 1;
    e.target.textContent = `Speed ${speed}×`;
  };
  root.querySelector('[data-skip]')?.addEventListener('click', () => resolveBattle(battle));
  root.querySelector('[data-retreat]').onclick = () => {
    if (confirm('Retreat? Troops that already fell stay lost, and you earn no victory rewards.')) {
      battle.phase = 'lost';
      battle.retreated = true;
    }
  };

  function frame(now) {
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    if (!paused) {
      let remaining = dt * speed;
      while (remaining > 0 && battle.phase !== 'won' && battle.phase !== 'lost') {
        const step = Math.min(1 / 60, remaining);
        stepBattle(battle, step);
        remaining -= step;
      }
    }
    draw(ctx, battle);
    root.querySelector('[data-wave]').textContent =
      battle.phase === 'intermission' ? 'Next wave…'
        : `Wave ${battle.wave + 1} / ${battle.level.waves.length}${battle.wave === battle.level.waves.length - 1 ? ' · Boss' : ''}`;
    if ((battle.phase === 'won' || battle.phase === 'lost') && !finished) {
      finished = true;
      showResult(app, root, battle);
      return;
    }
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}

function showResult(app, root, battle) {
  const res = S.applyBattleResult(app.state, battle);
  app.save();
  root.querySelector('.battle-bar .row').hidden = true;
  const box = root.querySelector('.battle-result');
  box.hidden = false;
  box.innerHTML = `
    <h2>${res.won ? 'Victory!' : battle.retreated ? 'Retreated' : 'Defeat'}</h2>
    ${res.firstClear ? `<p class="conquer">${battle.level.name} is conquered! It now yields ${battle.level.dailyYield} ${battle.level.element} power per day.</p>` : ''}
    <ul class="rates">
      <li>+${res.xp} growth${res.levelUps ? ` · <b>Tree reached level ${res.newLevel}!</b>` : ''}</li>
      ${res.sap ? `<li>${icon('icon_sap')} +${res.sap} sap</li>` : ''}
      <li>Waves cleared: ${battle.wavesCleared} / ${battle.level.waves.length}</li>
      <li>${res.lost ? `<b>${res.lost} troop${res.lost === 1 ? '' : 's'} fell and ${res.lost === 1 ? 'is' : 'are'} lost for good.</b>` : 'No troops lost.'}</li>
    </ul>
    <button class="primary" data-close>Return to map</button>`;
  box.querySelector('[data-close]').onclick = () => {
    root.hidden = true;
    root.innerHTML = '';
    app.render();
  };
}

function draw(ctx, b) {
  const { w, h } = FIELD;
  const tint = BIOME_COLORS[b.level.element];
  const sky = ctx.createLinearGradient(0, 0, 0, h);
  sky.addColorStop(0, '#DCEFD8');
  sky.addColorStop(1, '#BFD9A8');
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, w, h);
  ctx.globalAlpha = 0.25;
  ctx.fillStyle = tint;
  ctx.fillRect(w / 2, 0, w / 2, h);
  ctx.globalAlpha = 1;
  ctx.fillStyle = 'rgba(80,60,30,0.12)';
  for (const y of [110, 215, 320]) ctx.fillRect(0, y + 22, w, 6);

  const units = [...b.allies, ...b.enemies].filter((u) => u.hp > 0).sort((a, c) => a.y - c.y);
  for (const u of units) {
    const im = img(u.def.img);
    const sz = u.size * 1.25; // drawn a bit larger than the collision size
    ctx.save();
    if (u.flash > 0) ctx.filter = 'brightness(1.8)';
    if (im.complete && im.naturalWidth) ctx.drawImage(im, u.x - sz / 2, u.y - sz / 2, sz, sz);
    ctx.restore();
    const bw = sz * 0.7;
    ctx.fillStyle = 'rgba(0,0,0,0.35)';
    ctx.fillRect(u.x - bw / 2, u.y - sz / 2 - 8, bw, 5);
    ctx.fillStyle = u.side === 'ally' ? '#5DBB4C' : '#D9534F';
    ctx.fillRect(u.x - bw / 2, u.y - sz / 2 - 8, (bw * u.hp) / u.maxHp, 5);
  }

  for (const p of b.projectiles) {
    ctx.fillStyle = p.color;
    ctx.strokeStyle = '#2B1D12';
    ctx.beginPath();
    ctx.arc(p.x, p.y, 4, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
  }

  ctx.font = 'bold 14px system-ui, sans-serif';
  ctx.textAlign = 'center';
  for (const p of b.popups) {
    ctx.globalAlpha = 1 - p.t / 0.8;
    ctx.fillStyle = p.side === 'ally' ? '#B83A2E' : '#FFF6D8';
    ctx.strokeStyle = 'rgba(0,0,0,0.6)';
    ctx.lineWidth = 3;
    ctx.strokeText(p.text, p.x, p.y - p.t * 30);
    ctx.fillText(p.text, p.x, p.y - p.t * 30);
  }
  ctx.globalAlpha = 1;

  if (b.phase === 'intermission') {
    ctx.fillStyle = 'rgba(0,0,0,0.35)';
    ctx.fillRect(0, h / 2 - 30, w, 60);
    ctx.fillStyle = '#FFF6D8';
    ctx.font = 'bold 26px system-ui, sans-serif';
    ctx.fillText(`Wave ${b.wave + 1} cleared!`, w / 2, h / 2 + 9);
  }
}

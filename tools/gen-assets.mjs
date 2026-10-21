// Generates the temp placeholder SVG assets in /assets.
// The same art lives in Penpot on the "Elemental Tree – Temp Assets" page.
// Run: node tools/gen-assets.mjs
import { writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Written to both the web prototype and the Godot project.
const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const outDirs = [join(root, 'assets')];  // the web prototype; the Godot game uses pixel art
for (const dir of outDirs) mkdirSync(dir, { recursive: true });

const INK = '#2B1D12';
const o = (w = 2) => `stroke="${INK}" stroke-width="${w}" stroke-linejoin="round" stroke-linecap="round"`;
const svg = (w, h, body) =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>\n`;

const twigBody = (x = 32) => `
<path d="M${x - 6} 58 L${x - 2} 42 M${x + 6} 58 L${x + 2} 42" stroke="${INK}" stroke-width="5" stroke-linecap="round"/>
<path d="M${x - 6} 58 L${x - 2} 42 M${x + 6} 58 L${x + 2} 42" stroke="#8B5A2B" stroke-width="3" stroke-linecap="round"/>
<rect x="${x - 6}" y="26" width="12" height="18" rx="5" fill="#9C6B3C" ${o()}/>
<path d="M${x - 3} 30 L${x - 1} 38 M${x + 3} 31 L${x + 2} 36" stroke="#6E4724" stroke-width="1.5"/>
<circle cx="${x}" cy="18" r="8" fill="#B07D48" ${o()}/>
<circle cx="${x - 3}" cy="18" r="1.6" fill="${INK}"/><circle cx="${x + 3}" cy="18" r="1.6" fill="${INK}"/>`;

const leaf = (x, y, rot = 0, c = '#5DBB4C') =>
  `<path transform="rotate(${rot} ${x} ${y})" d="M${x} ${y} C${x + 3} ${y - 7} ${x + 10} ${y - 8} ${x + 12} ${y - 10} C${x + 11} ${y - 3} ${x + 7} ${y + 2} ${x} ${y} Z" fill="${c}" ${o()}/>`;

const drop = (fill, line, shine) => `
<path d="M16 3 C21 11 25 16 25 21 C25 26 21 29 16 29 C11 29 7 26 7 21 C7 16 11 11 16 3 Z" fill="${fill}" stroke="${line}" stroke-width="2"/>
<path d="M12 21 C12 18 13 16 15 13" fill="none" stroke="${shine}" stroke-width="2" stroke-linecap="round"/>`;

// Highlight on a potion's glass.
const shine = `<path d="M9.5 23 C9.5 21.5 10.3 20.6 11.3 20.4" fill="none" stroke="#FFFFFF" stroke-width="1.5" stroke-linecap="round" opacity="0.8"/>`;

// Garden: a two-tone stem, a ring of petals and a pointed star.
const stem = (d, c = '#3E8E3A') =>
  `<path d="${d}" fill="none" stroke="${INK}" stroke-width="4.5" stroke-linecap="round"/>
<path d="${d}" fill="none" stroke="${c}" stroke-width="2.5" stroke-linecap="round"/>`;
const petals = (cx, cy, n, len, w, fill, rot0 = 0) =>
  Array.from({ length: n }, (_, i) =>
    `<ellipse cx="${cx}" cy="${cy - len / 2 - 2}" rx="${w}" ry="${len / 2}" transform="rotate(${rot0 + (360 / n) * i} ${cx} ${cy})" fill="${fill}" ${o(1.5)}/>`).join('');
const star = (cx, cy, outer, inner, n = 5) =>
  Array.from({ length: n * 2 }, (_, i) => {
    const r = i % 2 ? inner : outer;
    const a = (Math.PI / n) * i - Math.PI / 2;
    return `${i ? 'L' : 'M'}${(cx + r * Math.cos(a)).toFixed(1)} ${(cy + r * Math.sin(a)).toFixed(1)}`;
  }).join(' ') + ' Z';
const sparkle = (x, y, r, c) =>
  `<path d="M${x} ${y - r} L${x + r * 0.3} ${y - r * 0.3} L${x + r} ${y} L${x + r * 0.3} ${y + r * 0.3} L${x} ${y + r} L${x - r * 0.3} ${y + r * 0.3} L${x - r} ${y} L${x - r * 0.3} ${y - r * 0.3} Z" fill="${c}"/>`;
// Every seed shares one kernel shape, in its element's colours.
const seed = (fill, line, extra = '') => svg(32, 32, `
  <path d="M16 6 C22 10 25 16 24.5 21 C24 26 20.5 29 16 29 C11.5 29 8 26 7.5 21 C7 16 10 10 16 6 Z" fill="${fill}" stroke="${line}" stroke-width="2" stroke-linejoin="round"/>
  <path d="M16 9 C14 14 13.5 21 15 27" fill="none" stroke="${line}" stroke-width="1.2" stroke-linecap="round" opacity="0.6"/>
  <path d="M11 20 C11 16.5 12 14 13.5 12" fill="none" stroke="#FFFFFF" stroke-width="1.6" stroke-linecap="round" opacity="0.7"/>
  ${extra}`);

const assets = {
  troop_soldier: svg(64, 64, `
  ${twigBody(30)}
  ${leaf(30, 10, -20)}
  <path d="M40 40 L54 20" stroke="${INK}" stroke-width="5" stroke-linecap="round"/>
  <path d="M40 40 L54 20" stroke="#D9D2C0" stroke-width="3" stroke-linecap="round"/>
  <path d="M38 36 L45 41" stroke="#5A3A1E" stroke-width="3" stroke-linecap="round"/>
  <ellipse cx="20" cy="38" rx="8" ry="10" fill="#7A4E26" ${o()}/>
  <circle cx="20" cy="38" r="3" fill="#C49A5A" ${o()}/>`),

  troop_spearman: svg(64, 64, `
  <path d="M50 60 L50 6" stroke="${INK}" stroke-width="4" stroke-linecap="round"/>
  <path d="M50 60 L50 8" stroke="#8B5A2B" stroke-width="2" stroke-linecap="round"/>
  <path d="M50 2 L55 12 L50 16 L45 12 Z" fill="#9AA3A8" ${o()}/>
  ${twigBody(30)}
  ${leaf(28, 10, -40)}${leaf(32, 10, 10)}
  <path d="M36 34 L50 30" stroke="${INK}" stroke-width="3" stroke-linecap="round"/>`),

  troop_archer: svg(64, 64, `
  ${twigBody(28)}
  <path d="M19 16 C20 6 36 6 37 16 L35 13 C30 8 26 8 21 13 Z" fill="#3E8E3A" ${o()}/>
  <path d="M44 14 C56 24 56 44 44 54" fill="none" stroke="${INK}" stroke-width="4" stroke-linecap="round"/>
  <path d="M44 14 C56 24 56 44 44 54" fill="none" stroke="#A8743E" stroke-width="2" stroke-linecap="round"/>
  <path d="M44 14 L44 54" stroke="#E8E2D0" stroke-width="1"/>
  <path d="M34 34 L58 34" stroke="${INK}" stroke-width="2"/>
  <path d="M58 34 L54 31 L54 37 Z" fill="#9AA3A8" ${o()}/>`),

  enemy_thorn_beetle: svg(64, 64, `
  <path d="M16 50 L10 56 M24 52 L22 60 M40 52 L42 60 M48 50 L54 56" ${o(3)}/>
  <ellipse cx="32" cy="38" rx="20" ry="15" fill="#2F5D3A" ${o()}/>
  <path d="M32 24 L32 52" stroke="${INK}" stroke-width="2"/>
  <path d="M18 30 L12 24 L20 28 M26 26 L24 18 L29 25 M38 26 L40 18 L35 25 M46 30 L52 24 L44 28" fill="#7FBF5A" ${o()}/>
  <ellipse cx="32" cy="22" rx="9" ry="6" fill="#1E3B26" ${o()}/>
  <circle cx="28" cy="21" r="1.8" fill="#FFD84A"/><circle cx="36" cy="21" r="1.8" fill="#FFD84A"/>`),

  enemy_burrow_rabbit: svg(64, 64, `
  <ellipse cx="22" cy="10" rx="4" ry="11" transform="rotate(-12 22 18)" fill="#A7825E" ${o()}/>
  <ellipse cx="34" cy="10" rx="4" ry="11" transform="rotate(12 34 18)" fill="#A7825E" ${o()}/>
  <ellipse cx="34" cy="44" rx="18" ry="14" fill="#A7825E" ${o()}/>
  <circle cx="51" cy="44" r="5" fill="#EFE6DA" ${o()}/>
  <circle cx="26" cy="28" r="11" fill="#B8936D" ${o()}/>
  <circle cx="22" cy="26" r="2" fill="${INK}"/>
  <circle cx="16" cy="30" r="2" fill="#E07A7A"/>
  <path d="M24 56 L20 58 M40 57 L44 59" ${o(3)}/>`),

  enemy_bramble_hare: svg(96, 96, `
  <ellipse cx="32" cy="16" rx="6" ry="17" transform="rotate(-14 32 28)" fill="#6E4A3A" ${o()}/>
  <ellipse cx="50" cy="16" rx="6" ry="17" transform="rotate(14 50 28)" fill="#6E4A3A" ${o()}/>
  <ellipse cx="52" cy="64" rx="28" ry="22" fill="#6E4A3A" ${o()}/>
  <path d="M30 52 C40 44 60 46 74 54 M34 72 C46 66 62 68 78 74" fill="none" stroke="#3F7A2E" stroke-width="4"/>
  <path d="M38 48 L36 42 M52 46 L52 39 M66 50 L69 44 M44 68 L42 62 M60 68 L61 61 M74 72 L78 67" stroke="#C94A3A" stroke-width="3" stroke-linecap="round"/>
  <circle cx="38" cy="42" r="16" fill="#7D5644" ${o()}/>
  <circle cx="32" cy="38" r="3" fill="#E0322B"/>
  <path d="M26 33 L36 35" stroke="${INK}" stroke-width="2.5"/>
  <path d="M22 46 L28 46" stroke="${INK}" stroke-width="2"/>
  <path d="M36 84 L30 88 M64 85 L70 88" ${o(4)}/>
  <path d="M26 22 L56 22 L50 12 L44 20 L41 10 L37 20 L32 12 Z" fill="#3F7A2E" ${o()}/>`),

  enemy_spring_frog: svg(64, 64, `
  <ellipse cx="32" cy="42" rx="20" ry="14" fill="#4FAF8C" ${o()}/>
  <ellipse cx="32" cy="46" rx="12" ry="8" fill="#C8E8C0"/>
  <circle cx="22" cy="26" r="7" fill="#4FAF8C" ${o()}/><circle cx="42" cy="26" r="7" fill="#4FAF8C" ${o()}/>
  <circle cx="22" cy="26" r="3" fill="${INK}"/><circle cx="42" cy="26" r="3" fill="${INK}"/>
  <path d="M24 40 C29 44 35 44 40 40" fill="none" stroke="${INK}" stroke-width="2"/>
  <path d="M12 52 L6 58 L16 58 Z M52 52 L58 58 L48 58 Z" fill="#3E8F72" ${o()}/>`),

  enemy_ripple_sprite: svg(64, 64, `
  <ellipse cx="32" cy="58" rx="16" ry="3" fill="none" stroke="#7FC8F0" stroke-width="2"/>
  <path d="M32 6 C40 20 50 30 50 40 C50 50 42 56 32 56 C22 56 14 50 14 40 C14 30 24 20 32 6 Z" fill="#5BB4E8" fill-opacity="0.9" ${o()}/>
  <path d="M24 36 C24 30 27 26 30 22" fill="none" stroke="#D8F1FF" stroke-width="3" stroke-linecap="round"/>
  <circle cx="27" cy="40" r="2.5" fill="#123A5A"/><circle cx="37" cy="40" r="2.5" fill="#123A5A"/>
  <path d="M28 47 C31 49 33 49 36 47" fill="none" stroke="#123A5A" stroke-width="2"/>`),

  enemy_mossback_turtle: svg(96, 96, `
  <ellipse cx="18" cy="60" rx="10" ry="8" fill="#7D9A5A" ${o()}/>
  <circle cx="14" cy="58" r="2" fill="${INK}"/>
  <path d="M28 76 L24 86 L34 86 M66 76 L70 86 L60 86" fill="#7D9A5A" ${o()}/>
  <path d="M22 70 C22 40 40 26 52 26 C68 26 82 40 82 70 Z" fill="#5C6B3A" ${o()}/>
  <path d="M36 70 L40 50 L52 42 L64 50 L68 70 M40 50 L28 56 M64 50 L76 56 M52 42 L52 30" fill="none" stroke="#3B4524" stroke-width="2"/>
  <path d="M30 34 C36 22 50 18 60 22 C70 24 78 32 80 42 C72 36 64 38 58 32 C50 36 40 30 30 34 Z" fill="#6FBF4A" ${o()}/>
  <circle cx="44" cy="26" r="3" fill="#F2E36B"/><circle cx="64" cy="28" r="2.5" fill="#F2E36B"/>
  <rect x="18" y="68" width="68" height="6" rx="3" fill="#C2B27A" ${o()}/>`),

  icon_sunlight: svg(32, 32, `
  <g stroke="#E8A317" stroke-width="2.5" stroke-linecap="round">
   <path d="M16 2 V6 M16 26 V30 M2 16 H6 M26 16 H30 M6 6 L9 9 M23 23 L26 26 M26 6 L23 9 M9 23 L6 26"/></g>
  <circle cx="16" cy="16" r="7" fill="#FFD447" stroke="#E8A317" stroke-width="2"/>`),

  icon_sap: svg(32, 32, drop('#E09A2D', '#8A5410', '#FFE1A3')),

  icon_nature: svg(32, 32, `
  <path d="M6 26 C6 12 14 5 27 5 C27 18 20 26 6 26 Z" fill="#5DBB4C" stroke="#2C6B24" stroke-width="2" stroke-linejoin="round"/>
  <path d="M6 26 L20 12" stroke="#2C6B24" stroke-width="2" stroke-linecap="round"/>`),

  icon_water: svg(32, 32, drop('#4AA8E8', '#1D5E8C', '#D8F1FF')),

  icon_fire: svg(32, 32, `
  <path d="M16 3 C18 9 24 12 24 20 C24 25 20 29 16 29 C12 29 8 25 8 20 C8 15 11 13 12 9 C14 12 14 14 15 15 C16 11 15 7 16 3 Z" fill="#F0642D" stroke="#8C2A0E" stroke-width="2" stroke-linejoin="round"/>
  <path d="M16 18 C18 21 20 22 20 25 C20 27 18 28 16 28 C14 28 12 27 12 25 C12 22 15 21 16 18 Z" fill="#FFC53D"/>`),

  icon_ice: svg(32, 32, `
  <g stroke="#3A8FB8" stroke-width="2.5" stroke-linecap="round">
   <path d="M16 3 V29 M5 9.5 L27 22.5 M27 9.5 L5 22.5"/>
   <path d="M12 5 L16 8 L20 5 M12 27 L16 24 L20 27"/></g>
  <circle cx="16" cy="16" r="3" fill="#BDEBFF" stroke="#3A8FB8" stroke-width="2"/>`),

  icon_dark: svg(32, 32, `
  <path d="M20 4 C12 5 6 11 6 18 C6 25 12 29 18 29 C24 29 28 26 29 21 C26 23 22 24 19 22 C14 19 13 11 20 4 Z" fill="#6A3FA0" stroke="#2E1450" stroke-width="2" stroke-linejoin="round"/>
  <circle cx="22" cy="12" r="1.5" fill="#D9C2FF"/><circle cx="25" cy="17" r="1" fill="#D9C2FF"/>`),

  // --- Expedition loot ----------------------------------------------------
  // Each potion has its own flask shape so they read apart at a glance.
  // Thorn Draught (+DMG): red, a cone flask with a thorn.
  item_thorn_draught: svg(32, 32, `
  <rect x="13" y="2" width="6" height="5" rx="1" fill="#A8743E" ${o(1.5)}/>
  <path d="M13 7 H19 V12 L26 25 C27 27 26 29 24 29 H8 C6 29 5 27 6 25 L13 12 Z" fill="#F4F1E6" ${o()}/>
  <path d="M9.6 18.5 H22.4 L25 24.6 C25.6 26.2 25 27.5 23.5 27.5 H8.5 C7 27.5 6.4 26.2 7 24.6 Z" fill="#D9534F" stroke="#7A1F1A" stroke-width="1.5" stroke-linejoin="round"/>
  <path d="M12.2 26 C14.6 25 16.4 23 17.6 19.2 C17.9 22.4 18.8 24.6 20.2 26 Z" fill="#FFE3E0" stroke="#7A1F1A" stroke-width="1.2" stroke-linejoin="round"/>
  <path d="M21.5 5.5 L23.5 2.5 M23 8.5 L26.5 7 M23.5 11.5 L27 11.5" stroke="#D9534F" stroke-width="1.6" stroke-linecap="round"/>`),

  // Bark Brew (+HP): bark-brown, a round flask with a heart.
  item_bark_brew: svg(32, 32, `
  <rect x="13" y="3" width="6" height="5" rx="1" fill="#A8743E" ${o(1.5)}/>
  <path d="M13 8 H19 V12 C24 13.5 27 17 27 21 C27 26 22 29 16 29 C10 29 5 26 5 21 C5 17 8 13.5 13 12 Z" fill="#F4F1E6" ${o()}/>
  <path d="M6.5 18 H25.5 C26.3 24 22 27.5 16 27.5 C10 27.5 5.7 24 6.5 18 Z" fill="#B07D48" stroke="#5A3A1E" stroke-width="1.5"/>
  <path d="M12.5 12.6 H19.5" stroke="#8B5A2B" stroke-width="2.5" stroke-linecap="round"/>
  <path d="M16 26 C12.3 23.6 11.7 21.7 12.6 20.4 C13.6 19.1 15.3 19.3 16 20.7 C16.7 19.3 18.4 19.1 19.4 20.4 C20.3 21.7 19.7 23.6 16 26 Z" fill="#E8556D" stroke="#7A1F1A" stroke-width="1.2" stroke-linejoin="round"/>
  ${shine}`),

  // Growth Tonic (+growth): green, a tall vial with an up arrow and a sprout.
  item_growth_tonic: svg(32, 32, `
  <rect x="12.5" y="2" width="7" height="5" rx="1" fill="#A8743E" ${o(1.5)}/>
  <path d="M11.5 7 H20.5 V24 C20.5 27 18.5 29 16 29 C13.5 29 11.5 27 11.5 24 Z" fill="#F4F1E6" ${o()}/>
  <path d="M12.8 13 H19.2 V24 C19.2 26.2 17.8 27.6 16 27.6 C14.2 27.6 12.8 26.2 12.8 24 Z" fill="#7CC46A" stroke="#2C6B24" stroke-width="1.5" stroke-linejoin="round"/>
  <path d="M16 25 V17.5 M13.6 20 L16 17.5 L18.4 20" fill="none" stroke="#FFFFFF" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M19.5 4 C21 1.5 24.5 1 26 2 C25.5 4.5 22.5 6 19.5 4 Z" fill="#5DBB4C" stroke="#2C6B24" stroke-width="1.2" stroke-linejoin="round"/>
  <path d="M25.5 10 L26.3 12.2 L28.5 13 L26.3 13.8 L25.5 16 L24.7 13.8 L22.5 13 L24.7 12.2 Z" fill="#FFD447" stroke="#B07A12" stroke-width="0.8" stroke-linejoin="round"/>`),

  // Inventory button: a leather satchel.
  icon_inventory: svg(32, 32, `
  <path d="M10.5 11 C10.5 3.5 21.5 3.5 21.5 11" fill="none" stroke="${INK}" stroke-width="3.5" stroke-linecap="round"/>
  <path d="M10.5 11 C10.5 3.5 21.5 3.5 21.5 11" fill="none" stroke="#7A4E26" stroke-width="1.6" stroke-linecap="round"/>
  <path d="M5 13 C5 11 6 10 8 10 H24 C26 10 27 11 27 13 V25 C27 27.5 25.5 29 23 29 H9 C6.5 29 5 27.5 5 25 Z" fill="#9C6B3C" ${o()}/>
  <path d="M5 13 C5 11 6 10 8 10 H24 C26 10 27 11 27 13 V17 C21.5 20.5 10.5 20.5 5 17 Z" fill="#7A4E26" ${o()}/>
  <rect x="13.5" y="16.5" width="5" height="5" rx="1" fill="#FFD447" ${o(1.5)}/>
  <path d="M8 25 C8 23 9 22 10.5 21.5" fill="none" stroke="#C49A5A" stroke-width="1.5" stroke-linecap="round"/>`),

  // --- Garden: seeds (found on expeditions) ---------------------------------
  // Sapling seed: an acorn.
  seed_sapling: svg(32, 32, `
  <path d="M16 9 C16 6 17 4 19.5 3" fill="none" stroke="${INK}" stroke-width="2.5" stroke-linecap="round"/>
  <path d="M20 4 C21.5 1.8 25 1.4 26.5 2.4 C26 5 23 6.3 20 4 Z" fill="#5DBB4C" stroke="#2C6B24" stroke-width="1.2" stroke-linejoin="round"/>
  <path d="M8.5 15 C8.5 25 11.5 29.5 16 29.5 C20.5 29.5 23.5 25 23.5 15 Z" fill="#C48A4A" ${o()}/>
  <path d="M12 19 C12 22.5 13 25 14.5 26.5" fill="none" stroke="#F0D2A8" stroke-width="1.6" stroke-linecap="round"/>
  <path d="M5.5 15 C5.5 9.5 10 8 16 8 C22 8 26.5 9.5 26.5 15 C26.5 16.5 5.5 16.5 5.5 15 Z" fill="#7A4E26" ${o()}/>
  <path d="M10 11.5 L12 13.5 M15 10.5 L17 12.5 M20 11 L22 13" stroke="#5A3A1E" stroke-width="1.2" stroke-linecap="round"/>`),

  seed_nature: seed('#7CC46A', '#2C6B24', `
  <path d="M16 7 C15 4 16.5 1.8 20 1.2 C20 4.5 18.5 6.6 16 7 Z M16 7 C14 4.8 11.5 4.3 9.5 5.3 C11.2 7.6 13.8 8 16 7 Z" fill="#A6E08E" stroke="#2C6B24" stroke-width="1.2" stroke-linejoin="round"/>`),

  seed_water: seed('#5BB4E8', '#1F5F8B', `
  <path d="M10 23 C12 21.5 14 21.5 16 23 C18 24.5 20 24.5 22 23" fill="none" stroke="#D8F1FF" stroke-width="1.6" stroke-linecap="round"/>
  <path d="M25 3 C27 6 28 7.5 28 9 C28 10.6 26.7 11.5 25 11.5 C23.3 11.5 22 10.6 22 9 C22 7.5 23 6 25 3 Z" fill="#7FC8F0" stroke="#1F5F8B" stroke-width="1.2" stroke-linejoin="round"/>`),

  seed_fire: seed('#F0642D', '#7A1F1A', `
  <path d="M16 7 C13 4 14.5 1.5 16.5 0.8 C16.4 2.6 18.3 3.2 18.8 1.6 C20.4 3.4 19.5 6 16 7 Z" fill="#FFC53D" stroke="#7A1F1A" stroke-width="1" stroke-linejoin="round"/>
  <circle cx="19" cy="20" r="1.3" fill="#FFC53D"/><circle cx="14" cy="24" r="1" fill="#FFC53D"/>`),

  seed_ice: seed('#BDEBFF', '#3A8FB8', `
  <path d="M16 16 V24 M12.5 18 L19.5 22 M19.5 18 L12.5 22" stroke="#3A8FB8" stroke-width="1.4" stroke-linecap="round"/>
  ${sparkle(26, 6, 3.5, '#9FDDF5')}`),

  seed_dark: seed('#7B54B5', '#2E1450', `
  <path d="M19 15 C16.5 15.5 15 17.5 15 20 C15 22.5 17 24.5 19.5 24.5 C18 23.5 17.2 22 17.2 20 C17.2 18 18 16.3 19 15 Z" fill="#D9C2FF"/>
  ${sparkle(26, 6, 3.5, '#D9C2FF')}`),

  // --- Garden: plot, sprout and grown plants ------------------------------
  // Plants stand at x 32 with their base at y 50, inside the plot's hole.
  garden_plot: svg(64, 64, `
  <path d="M5 51 L6 45 L8.5 50.5 M57 50 L58.5 44.5 L60 50" fill="none" stroke="#3E8E3A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <ellipse cx="32" cy="52" rx="28" ry="9" fill="#A87C55" ${o()}/>
  <ellipse cx="32" cy="50.5" rx="19" ry="5" fill="#6E4724" stroke="#5A3A1E" stroke-width="1.5"/>
  <circle cx="11" cy="55" r="1.6" fill="#D9C8A8"/><circle cx="52" cy="56" r="1.3" fill="#D9C8A8"/><circle cx="45" cy="58" r="1" fill="#D9C8A8"/>`),

  plant_sprout: svg(64, 64, `
  ${stem('M32 51 C32 46 31.5 42 32 37')}
  ${leaf(32, 39, -85, '#A6E08E')}${leaf(32, 39, 5, '#7CC46A')}`),

  // Garden sapling: a little tree that gathers sunlight and sap.
  plant_sapling: svg(64, 64, `
  <g stroke="#E8A317" stroke-width="2" stroke-linecap="round"><path d="M54 4 V7 M54 17 V20 M46 12 H49 M59 12 H62 M48.5 6.5 L50.5 8.5 M57.5 15.5 L59.5 17.5"/></g>
  <circle cx="54" cy="12" r="3.5" fill="#FFD447" stroke="#B07A12" stroke-width="1.2"/>
  <path d="M28.5 51 C30 43 30 35 30.5 26 L33.5 26 C34 35 34 43 35.5 51 Z" fill="#8B5A2B" ${o()}/>
  <path d="M32 48 C31.5 41 31.8 34 32 28" fill="none" stroke="#E09A2D" stroke-width="1.3" opacity="0.9"/>
  <path d="M31.5 36 C27 34 24 31 22 28" fill="none" stroke="#5A3A1E" stroke-width="3" stroke-linecap="round"/>
  <circle cx="22" cy="26" r="8" fill="#5DBB4C" stroke="#2C6B24" stroke-width="2"/>
  <circle cx="42" cy="25" r="8.5" fill="#5DBB4C" stroke="#2C6B24" stroke-width="2"/>
  <circle cx="32" cy="17" r="11" fill="#5DBB4C" stroke="#2C6B24" stroke-width="2"/>
  <circle cx="28" cy="13" r="4" fill="#A6E08E" opacity="0.8"/><circle cx="19.5" cy="23.5" r="2.5" fill="#A6E08E" opacity="0.8"/>
  <path d="M38.5 39 C40 41.2 40.8 42.5 40.8 43.6 C40.8 44.9 39.8 45.7 38.5 45.7 C37.2 45.7 36.2 44.9 36.2 43.6 C36.2 42.5 37 41.2 38.5 39 Z" fill="#F2B544" stroke="#9A5B12" stroke-width="1.2"/>`),

  // Verdant Daisy (nature): leafy green petals around a sunny heart.
  flower_nature: svg(64, 64, `
  ${stem('M32 51 C31 43 33 34 32 26')}
  ${leaf(32, 44, -95, '#5DBB4C')}${leaf(32, 38, 0, '#5DBB4C')}
  ${petals(32, 20, 8, 12, 3.6, '#A6E08E', 22.5)}
  <circle cx="32" cy="20" r="5.5" fill="#FFD447" ${o(1.5)}/>
  <circle cx="30.5" cy="18.5" r="1.6" fill="#FFF3B8"/>`),

  // Dewdrop Lily (water): a blue cup bloom with a dewdrop on its leaf.
  flower_water: svg(64, 64, `
  ${stem('M32 51 C33 44 31 37 32 30')}
  ${leaf(32, 45, -95, '#4FAF8C')}${leaf(32, 41, -5, '#4FAF8C')}
  <path d="M46 31 C48 34 49 35.6 49 37 C49 38.7 47.6 39.7 46 39.7 C44.4 39.7 43 38.7 43 37 C43 35.6 44 34 46 31 Z" fill="#D8F1FF" stroke="#3A8FB8" stroke-width="1.4"/>
  <path d="M21 16 C20 26 25 32 32 32 C39 32 44 26 43 16 C40 19 37 21 35 24 L32 11 L29 24 C27 21 24 19 21 16 Z" fill="#5BB4E8" ${o()}/>
  <path d="M29 24 L32 11 L35 24 C34 28 30 28 29 24 Z" fill="#7FC8F0" ${o(1.5)}/>
  <path d="M24.5 21 C25 25 26.5 27.5 28.5 29" fill="none" stroke="#D8F1FF" stroke-width="1.6" stroke-linecap="round"/>`),

  // Ember Poppy (fire): flame-red petals with a smouldering heart.
  flower_fire: svg(64, 64, `
  ${stem('M32 51 C30 44 33 35 32 28', '#4F7A2A')}
  ${leaf(32, 46, -95, '#6E9A3A')}${leaf(32, 40, 0, '#6E9A3A')}
  ${petals(32, 21, 5, 11, 6.5, '#F0642D')}
  ${petals(32, 21, 5, 7, 3.5, '#FFC53D', 36)}
  <circle cx="32" cy="21" r="4" fill="${INK}"/>
  <circle cx="31" cy="20" r="1" fill="#FFC53D"/><circle cx="33.5" cy="22" r="0.8" fill="#FFC53D"/>
  <path d="M48 8 L49.2 10.5 L48 13 L46.8 10.5 Z M14 10 L15 12 L14 14 L13 12 Z" fill="#FF8A3D"/>`),

  // Frost Bell (ice): icy bells hanging from an arching stem.
  flower_ice: svg(64, 64, `
  ${stem('M30 51 C28 38 33 22 46 17', '#5E9C8C')}
  ${stem('M30.5 31 C27 30.5 24.5 32 24 35', '#5E9C8C')}
  ${leaf(29.5, 45, -95, '#8FC9B8')}${leaf(29.5, 41, 0, '#8FC9B8')}
  <path d="M40 30 C40 23 42 19 46 19 C50 19 52 23 52 30 L54 33 C50 35.5 42 35.5 38 33 Z" fill="#BDEBFF" ${o()}/>
  <path d="M42.5 31 C42.5 26 43.5 23 45 21.5" fill="none" stroke="#FFFFFF" stroke-width="1.6" stroke-linecap="round"/>
  <circle cx="46" cy="36" r="2" fill="#9FDDF5" ${o(1.2)}/>
  <path d="M19 42 C19 37.5 21 35 24 35 C27 35 29 37.5 29 42 L31 44.5 C28 46.5 20 46.5 17 44.5 Z" fill="#BDEBFF" ${o()}/>
  <path d="M40 34 L41 38 L42 34.5 M50 34.5 L51 38.5 L52 34" fill="#E8F8FF" stroke="#3A8FB8" stroke-width="1" stroke-linejoin="round"/>
  ${sparkle(12, 18, 3.5, '#9FDDF5')}${sparkle(56, 46, 2.5, '#9FDDF5')}`),

  // Nightshade (dark): a violet star bloom glowing at its heart.
  flower_dark: svg(64, 64, `
  ${stem('M32 51 C33 43 31 35 32 29', '#3E6B3A')}
  ${leaf(32, 45, -95, '#4E7A44')}${leaf(32, 40, 0, '#4E7A44')}
  <path d="${star(32, 21, 15, 6)}" fill="#7B54B5" ${o()}/>
  <path d="${star(32, 21, 8, 3.5)}" fill="#B58BE0" stroke="#2E1450" stroke-width="1" stroke-linejoin="round"/>
  <circle cx="32" cy="21" r="2.6" fill="#FFD447" stroke="#B07A12" stroke-width="1"/>
  <path d="M54 4 C50.5 4.5 49 7.5 49.5 10.5 C50 13 52.5 14.5 55 14 C53 13 52 11 52 9 C52 7 53 5 54 4 Z" fill="#D9C2FF"/>
  ${sparkle(11, 12, 3, '#D9C2FF')}${sparkle(48, 34, 2.2, '#D9C2FF')}`),

  // --- Elemental troops ---------------------------------------------------
  troop_vine_lasher: svg(64, 64, `
  ${twigBody(28)}
  ${leaf(26, 10, -60)}${leaf(28, 10, -10)}${leaf(30, 12, 30, '#3E8E3A')}
  <path d="M22 30 L34 40" stroke="#5DBB4C" stroke-width="3"/>
  <path d="M36 34 C46 30 54 22 52 14 C50 8 43 9 45 16" fill="none" stroke="${INK}" stroke-width="5" stroke-linecap="round"/>
  <path d="M36 34 C46 30 54 22 52 14 C50 8 43 9 45 16" fill="none" stroke="#3E8E3A" stroke-width="3" stroke-linecap="round"/>
  ${leaf(52, 22, 40, '#7FBF5A')}`),

  troop_tide_caller: svg(64, 64, `
  <path d="M46 60 L46 18" stroke="${INK}" stroke-width="4" stroke-linecap="round"/>
  <path d="M46 60 L46 19" stroke="#8B5A2B" stroke-width="2" stroke-linecap="round"/>
  ${twigBody(28)}
  <path d="M19 17 C20 6 36 6 37 17 L34 13 C30 9 26 9 22 13 Z" fill="#2F7FBF" ${o()}/>
  <path d="M34 34 L46 30" stroke="${INK}" stroke-width="3" stroke-linecap="round"/>
  <circle cx="46" cy="13" r="7" fill="#5BB4E8" ${o()}/>
  <path d="M43 12 C43 10 44 9 46 8" fill="none" stroke="#D8F1FF" stroke-width="2" stroke-linecap="round"/>
  <path d="M38 4 C42 1 50 1 54 4" fill="none" stroke="#7FC8F0" stroke-width="2" stroke-linecap="round"/>`),

  troop_ember_sprout: svg(64, 64, `
  ${twigBody(28)}
  <path d="M23 12 C20 6 24 2 27 1 C27 4 30 5 31 2 C34 4 36 7 33 12 Z" fill="#F0642D" ${o()}/>
  <path d="M26 11 C25 8 27 6 28 5 C29 7 31 8 30 11 Z" fill="#FFC53D"/>
  <path d="M38 42 L52 24" stroke="${INK}" stroke-width="6" stroke-linecap="round"/>
  <path d="M38 42 L52 24" stroke="#5A3A1E" stroke-width="4" stroke-linecap="round"/>
  <path d="M49 24 C46 18 50 13 53 12 C53 15 56 16 57 14 C60 17 59 22 56 25 Z" fill="#F0642D" ${o()}/>
  <path d="M52 23 C51 20 53 18 54 17 C55 19 57 20 55 23 Z" fill="#FFC53D"/>`),

  troop_frost_warden: svg(64, 64, `
  ${twigBody(32)}
  <path d="M23 16 C24 7 40 7 41 16 Z" fill="#BDEBFF" ${o()}/>
  <path d="M32 7 L32 3" stroke="#3A8FB8" stroke-width="2" stroke-linecap="round"/>
  <path d="M42 42 L56 20" stroke="${INK}" stroke-width="5" stroke-linecap="round"/>
  <path d="M42 42 L56 20" stroke="#E8F7FF" stroke-width="3" stroke-linecap="round"/>
  <path d="M6 26 L22 22 L25 44 L15 56 L5 44 Z" fill="#9FDDF5" ${o()}/>
  <path d="M15 28 L15 48 M9 36 L21 36" stroke="#3A8FB8" stroke-width="2" stroke-linecap="round"/>`),

  troop_shade_twig: svg(64, 64, `
  ${twigBody(30)}
  <path d="M23 26 C19 38 19 48 21 54 L39 54 C41 48 41 38 37 26 Z" fill="#4B3466" ${o()}/>
  <path d="M20 20 C20 5 40 5 40 20 L37 16 C34 10 26 10 23 16 Z" fill="#3D2560" ${o()}/>
  <circle cx="27" cy="18" r="1.8" fill="#C9A6FF"/><circle cx="33" cy="18" r="1.8" fill="#C9A6FF"/>
  <path d="M40 42 L52 30" stroke="${INK}" stroke-width="4" stroke-linecap="round"/>
  <path d="M40 42 L52 30" stroke="#B58BE0" stroke-width="2" stroke-linecap="round"/>
  <path d="M38 40 L43 45" stroke="${INK}" stroke-width="3" stroke-linecap="round"/>`),

  // --- Ember Vent (fire) ----------------------------------------------------
  enemy_cinder_lizard: svg(64, 64, `
  <path d="M42 44 C52 44 60 38 61 29" fill="none" stroke="${INK}" stroke-width="7" stroke-linecap="round"/>
  <path d="M42 44 C52 44 60 38 61 29" fill="none" stroke="#C8471E" stroke-width="4" stroke-linecap="round"/>
  <path d="M24 51 L20 58 M42 51 L46 58" ${o(3)}/>
  <ellipse cx="34" cy="44" rx="16" ry="9" fill="#D9531E" ${o()}/>
  <circle cx="30" cy="41" r="2" fill="#FFC53D"/><circle cx="38" cy="45" r="2" fill="#FFC53D"/><circle cx="44" cy="40" r="1.6" fill="#FFC53D"/>
  <circle cx="16" cy="38" r="9" fill="#E8692E" ${o()}/>
  <circle cx="13" cy="36" r="2" fill="#FFD84A"/>
  <path d="M8 41 C11 43 14 43 17 42" fill="none" stroke="${INK}" stroke-width="1.5"/>`),

  enemy_ash_moth: svg(64, 64, `
  <path d="M32 30 C18 12 6 16 8 28 C10 38 22 38 32 34 Z" fill="#8C8580" ${o()}/>
  <path d="M32 30 C46 12 58 16 56 28 C54 38 42 38 32 34 Z" fill="#8C8580" ${o()}/>
  <path d="M32 36 C22 40 16 50 22 54 C28 56 32 46 32 40 Z" fill="#A69E97" ${o()}/>
  <path d="M32 36 C42 40 48 50 42 54 C36 56 32 46 32 40 Z" fill="#A69E97" ${o()}/>
  <circle cx="18" cy="26" r="3.5" fill="#FF8A3D"/><circle cx="46" cy="26" r="3.5" fill="#FF8A3D"/>
  <ellipse cx="32" cy="38" rx="5" ry="12" fill="#5A4A40" ${o()}/>
  <path d="M30 27 C27 20 24 18 21 18 M34 27 C37 20 40 18 43 18" fill="none" stroke="${INK}" stroke-width="2" stroke-linecap="round"/>
  <circle cx="30" cy="30" r="1.4" fill="#FFC53D"/><circle cx="34" cy="30" r="1.4" fill="#FFC53D"/>`),

  enemy_magma_salamander: svg(96, 96, `
  <path d="M62 66 C78 66 90 56 92 42" fill="none" stroke="${INK}" stroke-width="11" stroke-linecap="round"/>
  <path d="M62 66 C78 66 90 56 92 42" fill="none" stroke="#7A2414" stroke-width="8" stroke-linecap="round"/>
  <path d="M34 78 L28 88 M64 78 L70 88" ${o(5)}/>
  <ellipse cx="50" cy="64" rx="28" ry="16" fill="#8E2A17" ${o()}/>
  <path d="M30 44 L36 32 L42 46 L50 34 L56 50 L64 38 L68 54" fill="#F0642D" ${o()}/>
  <path d="M32 62 L40 68 L48 60 L56 70 L66 62" fill="none" stroke="#FFB02E" stroke-width="3" stroke-linejoin="round"/>
  <ellipse cx="22" cy="56" rx="16" ry="12" fill="#A3321B" ${o()}/>
  <circle cx="16" cy="52" r="3.5" fill="#FFD84A"/><circle cx="16" cy="52" r="1.5" fill="${INK}"/>
  <path d="M8 60 C14 64 20 64 26 62" fill="none" stroke="${INK}" stroke-width="2"/>
  <circle cx="9" cy="67" r="3" fill="#FFB02E"/>`),

  // --- Frostbite Hollow (ice) -----------------------------------------------
  enemy_frost_wolf: svg(64, 64, `
  <path d="M50 38 C60 32 62 22 58 18" fill="none" stroke="${INK}" stroke-width="7" stroke-linecap="round"/>
  <path d="M50 38 C60 32 62 22 58 18" fill="none" stroke="#DDEFF7" stroke-width="4" stroke-linecap="round"/>
  <path d="M28 48 L26 58 M36 49 L36 58 M46 48 L48 58" ${o(4)}/>
  <ellipse cx="38" cy="40" rx="16" ry="10" fill="#DDEFF7" ${o()}/>
  <path d="M30 34 L34 30 L36 35 L40 31 L42 36" fill="none" stroke="#7FC8F0" stroke-width="2" stroke-linejoin="round"/>
  <path d="M8 34 L22 24 L26 15 L30 26 L32 40 L18 42 Z" fill="#C5E3F2" ${o()}/>
  <circle cx="22" cy="31" r="2" fill="#2A6FA0"/>
  <circle cx="9" cy="34" r="2.2" fill="${INK}"/>`),

  enemy_icicle_bat: svg(64, 64, `
  <path d="M32 30 C22 18 8 18 4 28 C10 28 12 34 16 36 C18 32 24 32 26 36 Z" fill="#9FD3EC" ${o()}/>
  <path d="M32 30 C42 18 56 18 60 28 C54 28 52 34 48 36 C46 32 40 32 38 36 Z" fill="#9FD3EC" ${o()}/>
  <path d="M26 46 L29 57 L32 46 Z M33 46 L36 59 L39 46 Z" fill="#E8F7FF" stroke="#3A8FB8" stroke-width="1.5" stroke-linejoin="round"/>
  <path d="M26 27 L25 19 L30 25 M38 27 L39 19 L34 25" fill="#BFE6F7" ${o()}/>
  <circle cx="32" cy="36" r="10" fill="#BFE6F7" ${o()}/>
  <circle cx="29" cy="35" r="1.8" fill="#123A5A"/><circle cx="35" cy="35" r="1.8" fill="#123A5A"/>`),

  enemy_rime_elk: svg(96, 96, `
  <path d="M38 70 L36 90 M48 72 L48 90 M66 72 L66 90 M76 70 L78 90" ${o(6)}/>
  <path d="M38 70 L36 89 M48 72 L48 89 M66 72 L66 89 M76 70 L78 89" stroke="#8C9BA8" stroke-width="3" stroke-linecap="round"/>
  <ellipse cx="58" cy="58" rx="28" ry="16" fill="#8C9BA8" ${o()}/>
  <path d="M36 50 C48 40 68 40 84 50 C70 47 50 47 36 54 Z" fill="#E8F7FF" ${o()}/>
  <path d="M40 56 L26 40 L14 42 L9 50 L22 54 L32 66 Z" fill="#A4B3BF" ${o()}/>
  <path d="M24 38 L20 22 L12 16 M20 22 L26 11 M28 38 L34 22 L44 16 M34 22 L32 9" fill="none" stroke="#2A6FA0" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M24 38 L20 22 L12 16 M20 22 L26 11 M28 38 L34 22 L44 16 M34 22 L32 9" fill="none" stroke="#BDEBFF" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="20" cy="45" r="2.2" fill="#2A6FA0"/>
  <circle cx="11" cy="50" r="2.5" fill="${INK}"/>`),

  // --- Gloomroot Cavern (dark) ----------------------------------------------
  enemy_cave_bat: svg(64, 64, `
  <path d="M32 30 C22 18 8 18 4 28 C10 28 12 34 16 36 C18 32 24 32 26 36 Z" fill="#4B3466" ${o()}/>
  <path d="M32 30 C42 18 56 18 60 28 C54 28 52 34 48 36 C46 32 40 32 38 36 Z" fill="#4B3466" ${o()}/>
  <path d="M26 27 L25 19 L30 25 M38 27 L39 19 L34 25" fill="#5E4280" ${o()}/>
  <circle cx="32" cy="36" r="10" fill="#5E4280" ${o()}/>
  <circle cx="29" cy="34" r="2" fill="#E0322B"/><circle cx="35" cy="34" r="2" fill="#E0322B"/>
  <path d="M29 41 L30 44 L31 41 M33 41 L34 44 L35 41" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="1"/>`),

  enemy_shadow_slime: svg(64, 64, `
  <ellipse cx="32" cy="58" rx="20" ry="3" fill="#2E1450" opacity="0.4"/>
  <path d="M12 56 C10 40 18 22 32 22 C46 22 54 40 52 56 C46 58 42 54 38 57 C34 60 30 56 26 58 C20 60 16 56 12 56 Z" fill="#3D2560" ${o()}/>
  <path d="M20 42 C21 34 25 29 30 27" fill="none" stroke="#8A6BC0" stroke-width="3" stroke-linecap="round"/>
  <ellipse cx="26" cy="40" rx="3.5" ry="4.5" fill="#D9C2FF"/><ellipse cx="38" cy="40" rx="3.5" ry="4.5" fill="#D9C2FF"/>
  <circle cx="25" cy="41" r="1.6" fill="${INK}"/><circle cx="37" cy="41" r="1.6" fill="${INK}"/>`),

  enemy_hollow_mole_king: svg(96, 96, `
  <path d="M62 84 L60 91 M74 82 L76 91" ${o(5)}/>
  <ellipse cx="52" cy="62" rx="32" ry="24" fill="#4A3A4F" ${o()}/>
  <ellipse cx="46" cy="68" rx="16" ry="12" fill="#6B5870"/>
  <path d="M22 76 L16 85 M26 78 L23 88 M30 78 L30 88" stroke="${INK}" stroke-width="4" stroke-linecap="round"/>
  <path d="M22 76 L16 85 M26 78 L23 88 M30 78 L30 88" stroke="#E8E2D0" stroke-width="2" stroke-linecap="round"/>
  <ellipse cx="30" cy="50" rx="18" ry="15" fill="#574760" ${o()}/>
  <ellipse cx="13" cy="55" rx="7" ry="5" fill="#E89AB0" ${o()}/>
  <path d="M22 45 L29 47" stroke="#C9A6FF" stroke-width="3" stroke-linecap="round"/>
  <path d="M20 37 L22 24 L28 32 L32 20 L36 32 L42 24 L42 38 Z" fill="#B58BE0" ${o()}/>
  <circle cx="32" cy="30" r="2.2" fill="#FFD447"/>`),

  // --- Brambleheart Thicket (nature) ----------------------------------------
  enemy_thornback_boar: svg(64, 64, `
  <path d="M22 50 L20 59 M30 51 L30 59 M42 51 L42 59 M50 49 L52 58" ${o(4)}/>
  <ellipse cx="38" cy="40" rx="20" ry="13" fill="#7A5236" ${o()}/>
  <path d="M24 30 L26 22 L30 29 L34 20 L37 28 L42 19 L44 28 L50 22 L50 31" fill="#3F7A2E" ${o()}/>
  <path d="M30 26 L29 22 M42 24 L42 19" stroke="#C94A3A" stroke-width="2.5" stroke-linecap="round"/>
  <path d="M58 36 C62 34 63 30 61 28" fill="none" stroke="${INK}" stroke-width="2" stroke-linecap="round"/>
  <path d="M6 42 C6 32 12 28 22 30 L26 46 C18 50 8 50 6 42 Z" fill="#8A6044" ${o()}/>
  <ellipse cx="8" cy="43" rx="4" ry="5" fill="#C98B74" ${o()}/>
  <circle cx="7" cy="42" r="1" fill="${INK}"/><circle cx="9.5" cy="44" r="1" fill="${INK}"/>
  <path d="M12 48 C10 52 12 54 15 53" fill="#F2E8D2" ${o(1.5)}/>
  <circle cx="17" cy="36" r="2" fill="#E0322B"/>
  <path d="M14 32 L20 34" stroke="${INK}" stroke-width="2" stroke-linecap="round"/>`),

  enemy_pollen_wisp: svg(64, 64, `
  ${sparkle(10, 14, 3, '#FFE27A')}${sparkle(54, 46, 2.5, '#FFE27A')}${sparkle(52, 12, 2, '#C8E86B')}
  ${petals(32, 32, 6, 14, 5, '#C8E86B', 30)}
  <circle cx="32" cy="32" r="12" fill="#FFD447" ${o()}/>
  <path d="M25 30 C25 26 27 24 30 23" fill="none" stroke="#FFF4C2" stroke-width="2.5" stroke-linecap="round"/>
  <circle cx="28" cy="33" r="2" fill="${INK}"/><circle cx="36" cy="33" r="2" fill="${INK}"/>
  <path d="M29 38 C31 40 33 40 35 38" fill="none" stroke="${INK}" stroke-width="1.5" stroke-linecap="round"/>
  <circle cx="20" cy="56" r="2" fill="#FFE27A"/><circle cx="27" cy="60" r="1.4" fill="#FFE27A"/>`),

  enemy_blight_treant: svg(96, 96, `
  <path d="M30 88 C34 80 36 76 38 70 M66 88 C62 80 60 76 58 70 M20 90 L38 86 M58 86 L78 90" fill="none" stroke="${INK}" stroke-width="7" stroke-linecap="round"/>
  <path d="M30 88 C34 80 36 76 38 70 M66 88 C62 80 60 76 58 70 M20 90 L38 86 M58 86 L78 90" fill="none" stroke="#5A4232" stroke-width="4" stroke-linecap="round"/>
  <path d="M34 74 C30 60 30 44 36 34 L60 34 C66 44 66 60 62 74 Z" fill="#6B4E3A" ${o()}/>
  <path d="M40 44 L42 66 M54 40 L52 60 M47 62 L48 72" stroke="#4A3526" stroke-width="2" stroke-linecap="round"/>
  <path d="M36 50 C26 46 18 38 12 26 M12 26 L6 22 M12 26 L10 18 M60 48 C70 44 78 36 84 24 M84 24 L90 20 M84 24 L86 16" fill="none" stroke="${INK}" stroke-width="6" stroke-linecap="round"/>
  <path d="M36 50 C26 46 18 38 12 26 M12 26 L6 22 M12 26 L10 18 M60 48 C70 44 78 36 84 24 M84 24 L90 20 M84 24 L86 16" fill="none" stroke="#6B4E3A" stroke-width="3.5" stroke-linecap="round"/>
  <path d="M22 30 C16 16 30 4 48 6 C66 4 80 16 74 30 C66 36 58 32 48 34 C38 32 30 36 22 30 Z" fill="#5E6B2E" ${o()}/>
  <path d="M30 22 C34 16 40 14 46 14" fill="none" stroke="#8C9A48" stroke-width="3" stroke-linecap="round"/>
  <circle cx="34" cy="26" r="3" fill="#9B5FC0"/><circle cx="60" cy="20" r="2.5" fill="#9B5FC0"/><circle cx="66" cy="28" r="2" fill="#9B5FC0"/>
  <path d="M38 44 L44 46 M58 44 L52 46" stroke="${INK}" stroke-width="2.5" stroke-linecap="round"/>
  <circle cx="42" cy="49" r="2.8" fill="#C8E86B"/><circle cx="54" cy="49" r="2.8" fill="#C8E86B"/>
  <path d="M42 58 L45 56 L48 59 L51 56 L54 58" fill="none" stroke="${INK}" stroke-width="2" stroke-linejoin="round"/>`),

  // --- Sunken Lagoon (water) ------------------------------------------------
  enemy_snapjaw_crab: svg(64, 64, `
  <path d="M18 44 L8 52 M20 48 L12 58 M46 44 L56 52 M44 48 L52 58" ${o(3)}/>
  <path d="M18 34 L12 24 M46 34 L52 24" ${o(4)}/>
  <path d="M4 18 C4 10 12 8 16 12 L12 18 L18 18 C18 24 8 26 4 18 Z" fill="#E0573A" ${o()}/>
  <path d="M60 18 C60 10 52 8 48 12 L52 18 L46 18 C46 24 56 26 60 18 Z" fill="#E0573A" ${o()}/>
  <ellipse cx="32" cy="40" rx="18" ry="12" fill="#C8432A" ${o()}/>
  <path d="M20 38 C24 32 40 32 44 38" fill="none" stroke="#F08A62" stroke-width="2.5" stroke-linecap="round"/>
  <path d="M27 30 L26 24 M37 30 L38 24" stroke="${INK}" stroke-width="2"/>
  <circle cx="26" cy="23" r="3" fill="#FFFFFF" ${o(1.5)}/><circle cx="38" cy="23" r="3" fill="#FFFFFF" ${o(1.5)}/>
  <circle cx="26" cy="23" r="1.3" fill="${INK}"/><circle cx="38" cy="23" r="1.3" fill="${INK}"/>
  <path d="M28 45 L30 43 L32 45 L34 43 L36 45" fill="none" stroke="${INK}" stroke-width="1.5" stroke-linejoin="round"/>`),

  enemy_bubble_eel: svg(64, 64, `
  <path d="M14 56 C4 48 10 36 22 38 C34 40 40 30 34 22" fill="none" stroke="${INK}" stroke-width="13" stroke-linecap="round"/>
  <path d="M14 56 C4 48 10 36 22 38 C34 40 40 30 34 22" fill="none" stroke="#3A8C9E" stroke-width="9" stroke-linecap="round"/>
  <path d="M12 50 C9 46 12 42 18 42" fill="none" stroke="#9FE0E8" stroke-width="2" stroke-linecap="round"/>
  <path d="M10 40 L4 36 L8 44 Z" fill="#2E6F7E" ${o(1.5)}/>
  <ellipse cx="38" cy="18" rx="10" ry="8" fill="#3A8C9E" ${o()}/>
  <path d="M30 10 L34 4 L38 10 L42 5 L44 12" fill="#2E6F7E" ${o(1.5)}/>
  <circle cx="40" cy="16" r="2.4" fill="#FFD84A"/><circle cx="40" cy="16" r="1" fill="${INK}"/>
  <path d="M44 22 C46 23 47 22 47 20" fill="none" stroke="${INK}" stroke-width="1.5" stroke-linecap="round"/>
  <circle cx="52" cy="14" r="4" fill="#D8F1FF" fill-opacity="0.8" stroke="#5BB4E8" stroke-width="1.5"/>
  <circle cx="57" cy="5" r="2.5" fill="#D8F1FF" fill-opacity="0.8" stroke="#5BB4E8" stroke-width="1.5"/>`),

  enemy_lagoon_kraken: svg(96, 96, `
  <path d="M26 64 C14 70 10 82 18 88 M38 70 C32 80 34 88 40 90 M58 70 C64 80 62 88 56 90 M70 64 C82 70 86 82 78 88" fill="none" stroke="${INK}" stroke-width="10" stroke-linecap="round"/>
  <path d="M26 64 C14 70 10 82 18 88 M38 70 C32 80 34 88 40 90 M58 70 C64 80 62 88 56 90 M70 64 C82 70 86 82 78 88" fill="none" stroke="#2F6FA8" stroke-width="7" stroke-linecap="round"/>
  <circle cx="16" cy="78" r="1.6" fill="#BDE3FA"/><circle cx="35" cy="82" r="1.6" fill="#BDE3FA"/><circle cx="61" cy="82" r="1.6" fill="#BDE3FA"/><circle cx="80" cy="78" r="1.6" fill="#BDE3FA"/>
  <path d="M18 60 C14 30 30 8 48 8 C66 8 82 30 78 60 C70 70 26 70 18 60 Z" fill="#3A7FC0" ${o()}/>
  <path d="M28 40 C28 26 36 18 46 16" fill="none" stroke="#9FD3F5" stroke-width="4" stroke-linecap="round"/>
  <circle cx="60" cy="24" r="4" fill="#5BB4E8"/><circle cx="68" cy="36" r="3" fill="#5BB4E8"/><circle cx="34" cy="20" r="2.5" fill="#5BB4E8"/>
  <path d="M30 42 L42 46 M66 42 L54 46" stroke="${INK}" stroke-width="3" stroke-linecap="round"/>
  <ellipse cx="38" cy="51" rx="5" ry="6" fill="#FFD84A" ${o(1.5)}/><ellipse cx="58" cy="51" rx="5" ry="6" fill="#FFD84A" ${o(1.5)}/>
  <rect x="37" y="48" width="2" height="7" rx="1" fill="${INK}"/><rect x="57" y="48" width="2" height="7" rx="1" fill="${INK}"/>
  <path d="M44 62 C46 60 50 60 52 62" fill="none" stroke="${INK}" stroke-width="2" stroke-linecap="round"/>`),

  // --- Dungeons -------------------------------------------------------------
  // A mossy stone arch over a dark cave mouth, with eyes peering out.
  dungeon: svg(64, 64, `
  <path d="M4 58 C4 30 16 10 32 10 C48 10 60 30 60 58 Z" fill="#8A8478" ${o()}/>
  <path d="M10 26 L18 28 M8 40 L16 40 M48 28 L55 25 M48 40 L56 41 M24 14 L26 20 M40 14 L38 20" stroke="${INK}" stroke-width="1.6" stroke-linecap="round"/>
  <path d="M14 58 C14 38 22 24 32 24 C42 24 50 38 50 58 Z" fill="#1E1630" ${o()}/>
  <path d="M18 58 C18 42 24 30 32 30 C40 30 46 42 46 58 Z" fill="#120C1E"/>
  <ellipse cx="27" cy="44" rx="2.6" ry="2" fill="#FFD447"/><ellipse cx="37" cy="44" rx="2.6" ry="2" fill="#FFD447"/>
  <circle cx="27" cy="44" r="0.9" fill="${INK}"/><circle cx="37" cy="44" r="0.9" fill="${INK}"/>
  <path d="M8 22 C12 14 18 12 22 14 C18 16 14 20 12 26 Z" fill="#5DBB4C" ${o(1.5)}/>
  <path d="M44 13 C50 13 55 18 56 24 C52 21 48 19 44 19 Z" fill="#5DBB4C" ${o(1.5)}/>
  <rect x="2" y="56" width="60" height="5" rx="2.5" fill="#6E6A60" ${o()}/>
  <circle cx="12" cy="56" r="4" fill="#A39C8E" ${o(1.5)}/><circle cx="53" cy="55" r="3" fill="#A39C8E" ${o(1.5)}/>`),
};

// --- Wild twigs -------------------------------------------------------------
// Rival twig troops that guard the two-element lands: the player's elemental
// troops in weathered grey bark, with red eyes and a scowl.
const WILD_BARK = { '#9C6B3C': '#6B5A4C', '#B07D48': '#857060', '#8B5A2B': '#5C4A3C', '#6E4724': '#463830' };
const wild = (troop, x) => {
  let s = assets[troop];
  for (const [from, to] of Object.entries(WILD_BARK)) s = s.replaceAll(from, to);
  s = s.replaceAll(`cy="18" r="1.6" fill="${INK}"`, `cy="18.5" r="1.8" fill="#E0322B"`);
  const brow = `<path d="M${x - 6} 14 L${x - 1.5} 16 M${x + 6} 14 L${x + 1.5} 16" stroke="${INK}" stroke-width="2" stroke-linecap="round"/>`;
  return s.replace('</svg>', `${brow}</svg>`);
};
for (const [troop, x] of [['vine_lasher', 28], ['tide_caller', 28], ['ember_sprout', 28], ['frost_warden', 32], ['shade_twig', 30]]) {
  assets[`enemy_wild_${troop}`] = wild(`troop_${troop}`, x);
}

for (const [name, content] of Object.entries(assets)) {
  for (const dir of outDirs) writeFileSync(join(dir, `${name}.svg`), content);
}
console.log(`Wrote ${Object.keys(assets).length} assets to ${outDirs.join(' and ')}`);

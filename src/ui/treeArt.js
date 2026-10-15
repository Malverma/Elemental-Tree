// Draws the Elemental Tree as SVG. Roots, trunk and branches each grow with their level.

const GROUND = 220;
const CX = 160;

function seeded(seed) {
  let s = seed;
  return () => ((s = (s * 9301 + 49297) % 233280) / 233280);
}

function leafPath(x, y, len, angle) {
  const r = (angle * Math.PI) / 180;
  const tx = x + Math.cos(r) * len, ty = y + Math.sin(r) * len;
  const nx = -Math.sin(r) * len * 0.35, ny = Math.cos(r) * len * 0.35;
  const mx = (x + tx) / 2, my = (y + ty) / 2;
  return `<path d="M${x} ${y} Q${mx + nx} ${my + ny} ${tx} ${ty} Q${mx - nx} ${my - ny} ${x} ${y} Z" fill="#5DBB4C" stroke="#2C6B24" stroke-width="1.5"/>`;
}

export function treeSvg(tree) {
  const { level, roots, trunk, branches } = tree;
  const rand = seeded(7);
  const height = Math.min(175, 40 + 16 * level);
  const baseW = 5 + 3.5 * trunk;
  const topW = Math.max(2, baseW * 0.35);
  const top = GROUND - height;
  const parts = [];

  // Soil cutaway and grass line.
  parts.push(`<rect x="0" y="${GROUND}" width="320" height="120" fill="var(--soil)"/>`);
  parts.push(`<path d="M0 ${GROUND} Q80 ${GROUND - 6} 160 ${GROUND} T320 ${GROUND} V${GROUND + 6} H0 Z" fill="var(--grass)"/>`);

  // Roots: more and longer with each level; the tips glow where they reach new land.
  const rootCount = 2 + 2 * roots;
  for (let i = 0; i < rootCount; i++) {
    const side = i % 2 ? 1 : -1;
    const spread = (Math.floor(i / 2) + 1) / (rootCount / 2 + 1);
    const len = 30 + 16 * roots * (0.6 + rand() * 0.4);
    const ex = CX + side * spread * Math.min(150, len * 1.6);
    const ey = GROUND + 18 + (1 - spread) * Math.min(90, len);
    const w = Math.max(1.5, baseW * 0.5 * (1 - spread * 0.6));
    parts.push(`<path d="M${CX + side * baseW * 0.3} ${GROUND + 2} Q${CX + side * spread * 30} ${ey - 8} ${ex} ${ey}" fill="none" stroke="var(--bark-dark)" stroke-width="${w}" stroke-linecap="round"/>`);
    if (roots > 0) parts.push(`<circle cx="${ex}" cy="${ey}" r="2.5" fill="var(--root-glow)"/>`);
  }

  // Branches: one more pair per level, each with a leaf cluster.
  const branchCount = branches * 2;
  const clusters = [];
  for (let i = 0; i < branchCount; i++) {
    const side = i % 2 ? 1 : -1;
    const t = 0.35 + 0.55 * ((Math.floor(i / 2) + 0.5) / Math.max(1, branches));
    const by = GROUND - height * t;
    const len = 18 + height * 0.28 * (1.1 - t * 0.5);
    const ex = CX + side * len, ey = by - len * 0.55;
    parts.push(`<path d="M${CX} ${by} Q${CX + side * len * 0.5} ${by - 2} ${ex} ${ey}" fill="none" stroke="var(--bark)" stroke-width="${Math.max(2, topW)}" stroke-linecap="round"/>`);
    clusters.push([ex, ey, 10 + len * 0.35]);
  }

  // Trunk with sap veins (one per trunk level).
  parts.push(`<path d="M${CX - baseW} ${GROUND + 2} C${CX - baseW * 0.7} ${GROUND - height * 0.4} ${CX - topW} ${top + 20} ${CX - topW} ${top} L${CX + topW} ${top} C${CX + topW} ${top + 20} ${CX + baseW * 0.7} ${GROUND - height * 0.4} ${CX + baseW} ${GROUND + 2} Z" fill="var(--bark)" stroke="var(--bark-dark)" stroke-width="2"/>`);
  for (let i = 0; i < trunk; i++) {
    const off = ((i + 1) / (trunk + 1) - 0.5) * baseW * 1.1;
    parts.push(`<path d="M${CX + off} ${GROUND - 4} Q${CX + off * 0.6} ${GROUND - height * 0.5} ${CX + off * 0.3} ${top + 12}" fill="none" stroke="var(--sap)" stroke-width="1.6" stroke-linecap="round" opacity="0.85"/>`);
  }

  // Crown: a sapling has two leaves; a grown tree has a canopy. Tapping it gathers sunlight,
  // so it gets an invisible hit area at least as big as a fingertip.
  const crown = [];
  let hitR = 44;
  if (level < 3 && branches === 0) {
    crown.push(leafPath(CX, top + 2, 22, -150), leafPath(CX, top + 2, 22, -30), leafPath(CX, top, 16, -90));
  } else {
    const r = 18 + level * 4;
    hitR = Math.max(hitR, r * 1.4);
    clusters.push([CX, top, r], [CX - r * 0.6, top + r * 0.3, r * 0.7], [CX + r * 0.6, top + r * 0.3, r * 0.7]);
  }
  for (const [x, y, r] of clusters) {
    crown.push(`<circle cx="${x}" cy="${y}" r="${r}" fill="var(--leaf)" stroke="var(--leaf-dark)" stroke-width="2"/>`);
    crown.push(`<circle cx="${x - r * 0.3}" cy="${y - r * 0.3}" r="${r * 0.35}" fill="var(--leaf-light)" opacity="0.7"/>`);
  }
  parts.push(`<g class="crown" data-tap role="button" tabindex="0" aria-label="Tap the branches to gather 1 sunlight">
    <circle cx="${CX}" cy="${top}" r="${hitR}" fill="transparent"/>${crown.join('')}</g>`);

  return `<svg class="tree-art" viewBox="0 20 320 300" role="img" aria-label="Your Elemental Tree">${parts.join('')}</svg>`;
}

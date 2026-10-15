export const icon = (name, size = 18) =>
  `<img class="icon" src="assets/${name}.svg" alt="" width="${size}" height="${size}">`;

export const fmt = (n) => {
  n = Math.floor(n);
  if (n >= 1e6) return `${(n / 1e6).toFixed(1)}M`;
  if (n >= 1e4) return `${(n / 1e3).toFixed(1)}k`;
  return String(n);
};

const RES_ICON = { sunlight: 'icon_sunlight', sap: 'icon_sap' };

// Renders a cost like "50 ☀ 30 sap", marking the parts the player can't afford.
export const costHtml = (cost, state) =>
  Object.entries(cost)
    .map(([res, amt]) => {
      const short = state.resources[res] < amt ? ' short' : '';
      return `<span class="cost${short}">${icon(RES_ICON[res], 16)}${fmt(amt)}</span>`;
    })
    .join('');

export const elementIcon = (el) => `icon_${el}`;

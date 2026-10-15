// Static game data and economy formulas. All tuning lives here.

export const ELEMENTS = ['nature', 'water', 'fire', 'ice', 'dark'];

// Each element is strong against the next one in this cycle (spec §6.4).
const STRONG_AGAINST = { water: 'fire', fire: 'ice', ice: 'nature', nature: 'dark', dark: 'water' };

export function elementMultiplier(attacker, defender) {
  if (!attacker || !defender) return 1;
  if (STRONG_AGAINST[attacker] === defender) return 1.5;
  if (STRONG_AGAINST[defender] === attacker) return 0.75;
  return 1;
}

export const STORAGE_CAP_MINUTES = 24 * 60;

export const ECONOMY = {
  // Tree level: XP needed to go from `level` to `level + 1`.
  xpToNext: (level) => Math.round(50 * level ** 1.5),
  // Branches raise sunlight per minute. The sapling starts at 10/min.
  sunlightPerMin: (branches) => 10 + 5 * branches,
  // Sunlight gained per tap on the branches.
  tapSunlight: 1,
  // Trunk raises sap per minute and formation slots.
  sapPerMin: (trunk) => 4 * trunk,
  formationSlots: (trunk) => Math.min(9, 2 + trunk),
  // Roots level is how far (in root distance) the tree can reach on the map.
  rootReach: (roots) => roots,
  rosterCap: (treeLevel) => 3 + 2 * treeLevel,
};

// Upgrade cost for a tree part when going from `level` to `level + 1`.
export const PARTS = {
  roots: {
    name: 'Roots',
    blurb: 'Spread across the world map. Each level reaches one step farther.',
    startLevel: 0,
    cost: (lvl) => ({ sunlight: Math.round(50 * 1.8 ** lvl), sap: Math.round(30 * 1.8 ** lvl) }),
    effect: (lvl) => `Reach ${ECONOMY.rootReach(lvl)}`,
  },
  trunk: {
    name: 'Trunk',
    blurb: 'Produces sap for growing troops. Also widens the battle formation.',
    startLevel: 1,
    cost: (lvl) => ({ sunlight: Math.round(30 * 1.6 ** (lvl - 1)), sap: Math.round(20 * 1.6 ** (lvl - 1)) }),
    effect: (lvl) => `${ECONOMY.sapPerMin(lvl)} sap/min · ${ECONOMY.formationSlots(lvl)} slots`,
  },
  branches: {
    name: 'Branches',
    blurb: 'Catch more of the sun. Raises sunlight gathered per minute.',
    startLevel: 0,
    cost: (lvl) => ({ sunlight: Math.round(40 * 1.5 ** lvl) }),
    effect: (lvl) => `${ECONOMY.sunlightPerMin(lvl)} sunlight/min`,
  },
};

// Stats: hp, dmg (damage per hit), reach (1 = melee; each point is REACH_UNIT px
// on the battlefield), cooldown (seconds between hits), speed (px per second).
export const REACH_UNIT = 30;

export const TROOPS = {
  soldier: {
    name: 'Twig Soldier', img: 'troop_soldier', unlockLevel: 1, sapCost: 10,
    role: 'Melee frontline', preferredRow: 'front',
    hp: 45, dmg: 5, reach: 1, cooldown: 1.0, speed: 40,
  },
  spearman: {
    name: 'Twig Spearman', img: 'troop_spearman', unlockLevel: 2, sapCost: 15,
    role: 'Melee with reach, bonus vs. large foes', preferredRow: 'middle',
    hp: 42, dmg: 6, reach: 2, cooldown: 1.2, speed: 38, vsLarge: 1.5,
  },
  archer: {
    name: 'Twig Archer', img: 'troop_archer', unlockLevel: 3, sapCost: 20,
    role: 'Ranged, fragile', preferredRow: 'back',
    hp: 20, dmg: 6, reach: 8, cooldown: 1.4, speed: 34, projectile: '#E8E2D0', targetLowestHp: true,
  },
};

export const ENEMIES = {
  thorn_beetle: { name: 'Thorn Beetle', img: 'enemy_thorn_beetle', element: 'nature', hp: 20, dmg: 3, reach: 1, cooldown: 1.2, speed: 30 },
  burrow_rabbit: { name: 'Burrow Rabbit', img: 'enemy_burrow_rabbit', element: 'nature', hp: 11, dmg: 3, reach: 1, cooldown: 1.1, speed: 60 },
  bramble_hare: { name: 'Bramble Hare', img: 'enemy_bramble_hare', element: 'nature', hp: 110, dmg: 6, reach: 1, cooldown: 1.4, speed: 34, large: true, boss: true },
  spring_frog: { name: 'Spring Frog', img: 'enemy_spring_frog', element: 'water', hp: 22, dmg: 4, reach: 1, cooldown: 1.25, speed: 45 },
  ripple_sprite: { name: 'Ripple Sprite', img: 'enemy_ripple_sprite', element: 'water', hp: 13, dmg: 3, reach: 5, cooldown: 1.6, speed: 32, projectile: '#7FC8F0' },
  mossback_turtle: { name: 'Old Mossback Turtle', img: 'enemy_mossback_turtle', element: 'water', hp: 150, dmg: 7, reach: 1, cooldown: 1.95, speed: 22, large: true, boss: true },
};

// World map. Coordinates are in the 1000x620 map viewBox; the grove sits at the center.
export const GROVE = { x: 500, y: 330 };

export const LEVELS = {
  sunny_meadow: {
    name: 'Sunny Meadow', biome: 'Meadows', element: 'nature', distance: 1, from: 'grove',
    x: 330, y: 250, playable: true, dailyYield: 20,
    rewards: { firstXp: 60, xp: 20, sap: 15 },
    waves: [
      ['burrow_rabbit', 'burrow_rabbit', 'burrow_rabbit'],
      ['thorn_beetle', 'burrow_rabbit', 'thorn_beetle', 'burrow_rabbit'],
      ['thorn_beetle', 'thorn_beetle', 'burrow_rabbit', 'thorn_beetle', 'burrow_rabbit'],
      ['bramble_hare', 'burrow_rabbit', 'burrow_rabbit'],
    ],
  },
  whispering_spring: {
    name: 'Whispering Spring', biome: 'Springs', element: 'water', distance: 2, from: 'sunny_meadow',
    x: 170, y: 130, playable: true, dailyYield: 25,
    rewards: { firstXp: 120, xp: 35, sap: 25 },
    waves: [
      ['spring_frog', 'spring_frog', 'spring_frog'],
      ['spring_frog', 'ripple_sprite', 'spring_frog', 'ripple_sprite'],
      ['spring_frog', 'spring_frog', 'spring_frog', 'ripple_sprite', 'ripple_sprite', 'ripple_sprite'],
      ['mossback_turtle', 'ripple_sprite', 'ripple_sprite'],
    ],
  },
  ember_vent: {
    name: 'Ember Vent', biome: 'Volcanic Ridge', element: 'fire', distance: 3, from: 'frostfork',
    x: 840, y: 110, playable: false,
  },
  frostbite_hollow: {
    name: 'Frostbite Hollow', biome: 'Frozen Tundra', element: 'ice', distance: 3, from: 'frostfork',
    x: 860, y: 470, playable: false,
  },
  gloomroot_cavern: {
    name: 'Gloomroot Cavern', biome: 'Underground Caves', element: 'dark', distance: 4, from: 'grove',
    x: 470, y: 515, playable: false,
  },
};

// Path-only waypoints (not levels) that root paths travel through.
export const WAYPOINTS = {
  frostfork: { name: 'Root Fork', distance: 2, from: 'grove', x: 690, y: 300 },
};

export const BIOME_COLORS = {
  nature: '#7CC46A',
  water: '#5BB4E8',
  fire: '#F0642D',
  ice: '#9FDDF5',
  dark: '#7B54B5',
};

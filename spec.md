# Elemental Tree — Game Spec

> Working title: **Elemental Tree – Spread Your Roots**
> Status: Draft v0.3 (2026-10-14) — first playable build in progress (see §12)

## 1. Overview

The player tends a living **Elemental Tree** that begins as a small sapling. The tree grows by gathering energy: at first only a daily ration of **sunlight**, later also **XP** from battles and **elemental power** from conquered lands. The tree is made of three parts — **Roots**, **Trunk** and **Branches** — each with its own job. The roots spread across the world map to reach new levels, the trunk produces **sap** used to summon twig troops, and the branches hold elemental power that unlocks elemental troops. Battles are **auto-battles**: the player builds and positions a squad, then watches it fight.

### Design pillars
- **Nurture over time** – a daily rhythm of returning to collect energy and watch the tree grow.
- **Spread your roots** – the world map visibly becomes the tree's territory as roots reach and conquer levels.
- **Elemental identity** – which lands you conquer shapes what kind of tree (and army) you build.

## 2. Core Loop

```
 Collect sunlight ──► Tree levels up ──► Higher caps for Roots / Trunk / Branches
                                                  │
        ┌─────────────────────────────────────────┘
        ▼
 Trunk produces Sap ──► Summon troops ──► Auto-battle a level ──► Conquer it
        ▲                                                            │
        │                                                            ▼
 Extend Roots to new levels ◄── Infuse Branches ◄── Collect daily elemental power
```

1. Collect daily sunlight, sap, and elemental power from conquered levels.
2. Level up the tree, then upgrade its Roots, Trunk and Branches.
3. Summon troops with sap and arrange them in a formation.
4. Enter a level the roots have reached; the battle plays out automatically.
5. Win to earn XP; on first clear, the level is **conquered** and starts producing daily elemental power.

## 3. The Elemental Tree

### 3.1 Tree level & growth stages
The tree has an overall **Tree Level**, raised by filling the **Growth** bar. Tree Level sets the stage, unlocks features, and **caps the level of each tree part** (no part can exceed the Tree Level).

| Stage | Tree Level | Unlocks |
|---|---|---|
| Sapling | 1–4 | Sunlight collection, Trunk (sap), Twig Soldier |
| Young Tree | 5–9 | Roots & world map, Meadow level, combat XP, Twig Spearman |
| Grown Tree | 10–19 | Branches & elemental infusion, Twig Archer |
| Elder Tree | 20–34 | Larger formations, advanced troops, distant biomes |
| World Tree | 35+ | Endgame levels, multi-element troops |

Growth comes from:
- **Sunlight** (from the start)
- **Combat XP** (from Young Tree)

Exact thresholds are tuning values (see §10).

### 3.2 Tree parts

| Part | Role | Upgraded with | Upgrade effect |
|---|---|---|---|
| **Roots** | Spread across the world map to reach levels | Sap | More reach (longer root paths), faster spread |
| **Trunk** | Produces Sap | Sap + Sunlight | More sap per day, larger sap storage, larger formation size |
| **Branches** | Catch sunlight; later also hold elemental power (one branch per element) | Sunlight (later: that element's power) | More sunlight per minute; later elemental troop unlocks, stat bonuses, passives |

#### Roots
- The roots start at the home grove in the center of the world map.
- Each map node is connected by **root paths**. To enter a level, the roots must reach it.
- **Extending** a root along a path to an adjacent node costs Sap and takes real time to grow (e.g. 1–8 hours, longer for farther nodes).
- **Root Level** sets the maximum root distance from the grove, so better (farther) levels require upgraded roots.
- Elemental power from conquered levels travels back to the tree through the roots — visually, roots glow with the element they carry.

#### Trunk
- Produces **Sap** continuously, stored up to a cap (see §4.1).
- Trunk Level increases sap production rate, sap storage cap, and the number of formation slots in battle.
- The trunk is the first part available — even the sapling produces a little sap.

#### Branches
- Five branches, one per element: **Water, Fire, Nature, Ice, Dark**. A branch is dormant until the first power of its element is collected.
- Raising a branch's level:
  - Unlocks elemental variants of troops (e.g. Water Branch 1 → Water Twig Soldier, Water Branch 3 → Water Twig Spearman).
  - Increases the stats of that element's troops.
  - Adds passive bonuses (e.g. Nature: troops regenerate slowly).
  - Changes the tree's look (leaves, blossoms, glow) so the build is visible.

## 4. Energy & Resources

| Resource | Source | Used for |
|---|---|---|
| **Sunlight** | Gathered continuously (10/min for the level 1 sapling, raised by Branches); collected at the tree | Growth (Tree Level), part upgrades |
| **XP** | Battles | Growth (Tree Level) |
| **Sap** | Produced by the Trunk; small battle rewards | Summoning troops, extending/upgrading Roots, Trunk upgrades |
| **Water power** | Conquered Water levels | Water branch |
| **Nature power** | Conquered Nature levels | Nature branch |
| **Fire power** | Conquered Fire levels | Fire branch |
| **Ice power** | Conquered Ice levels | Ice branch |
| **Dark power** | Conquered Dark levels | Dark branch |

### 4.1 Daily collection
- Sunlight, sap, and elemental power accumulate in real time and are **collected** by the player (tap the tree for sunlight/sap, tap conquered levels for elemental power — or "collect all" once unlocked).
- Each source has a **storage cap** (default: 24h of production). Production pauses when full, encouraging daily check-ins without harshly punishing a missed day.
- Production is continuous; daily quests/bonuses reset at local midnight.

## 5. World Map

- A node-based map centered on the tree's home grove. Nodes are **levels**; edges are **root paths**.
- Node states: **Hidden → Visible → Rooted (enterable) → Conquered**.
  - *Visible:* within sight of the roots but not yet reached.
  - *Rooted:* roots have grown to the node; the level can be played.
  - *Conquered:* cleared; produces daily elemental power.
- Farther nodes are harder and yield more power, so root reach is the main gate on progression.

### 5.1 Biomes

| Biome | Element | Notes |
|---|---|---|
| Meadows | Nature | Starting biome, open terrain |
| Forests | Nature | Cover and ambushes *(post-launch content)* |
| Springs | Water | Small, healing pools |
| Lakes | Water | Water hazards, larger maps *(post-launch content)* |
| Underground Caves | Dark | Low visibility, tunnels |
| Volcanic Ridge | Fire | Lava hazards |
| Frozen Tundra | Ice | Slippery ground, slows units |

### 5.2 Starting levels (one per element)

The first content set is five levels, one per element, arranged at increasing root distance from the grove.

| # | Level | Biome | Element | Root distance | Tree Level req. | Enemies | Daily yield |
|---|---|---|---|---|---|---|---|
| 1 | **Sunny Meadow** | Meadows | Nature | 1 | 5 | Thorn Beetles, Burrow Rabbits; boss: Bramble Hare | 20 Nature |
| 2 | **Whispering Spring** | Springs | Water | 2 | 8 | Spring Frogs, Ripple Sprites; boss: Old Mossback Turtle | 25 Water |
| 3 | **Ember Vent** | Volcanic Ridge | Fire | 3 | 12 | Cinder Lizards, Ash Moths; boss: Magma Salamander | 30 Fire |
| 4 | **Frostbite Hollow** | Frozen Tundra | Ice | 3 | 14 | Frost Wolves, Icicle Bats; boss: Rime Elk | 30 Ice |
| 5 | **Gloomroot Cavern** | Underground Caves | Dark | 4 | 17 | Cave Bats, Shadow Slimes; boss: Hollow Mole King | 35 Dark |

- Each level has **3 waves** plus a boss wave; the boss guards the biome's **corrupted heart**.
- Clearing the boss conquers the level. Replays grant XP and a little sap, but no extra conquest reward.
- Map layout: Meadow is adjacent to the grove; Spring branches from Meadow; Ember Vent and Frostbite Hollow sit on opposite paths at distance 3, so the player chooses which to root toward first; Gloomroot Cavern is deepest — roots literally grow *down* into it.

### 5.3 Level yield
Yield scales with level distance/difficulty. Future option: enemies can **reclaim** levels, requiring defense (see §11).

## 6. Combat (Auto-Battler)

### 6.1 Battle flow
1. **Scout:** before battle, the player sees the level's waves, enemy types and elements.
2. **Formation:** the player places troops on a formation grid — **3 rows (Front / Middle / Back) × N columns**. Formation slots are set by Trunk Level (start: 3 slots, max: 15).
3. **Battle:** troops and enemies fight automatically. Units target by simple rules (melee → nearest enemy in front; spearmen reach 2 tiles; archers → lowest-HP or highest-threat target in range).
4. **Between waves:** surviving troops carry their HP forward; the player cannot change the formation mid-level (proposed — may allow a short regroup between waves).
5. **Result:** win or lose; rewards granted.

- **Win:** defeat all waves including the boss.
- **Lose:** all troops defeated. Partial XP is awarded for waves cleared.
- **Controls during battle:** 1×/2× speed, pause, and skip (skip unlocks after the level has been cleared once).

### 6.2 Base troops

| Troop | Role | Preferred row | Unlock | Notes |
|---|---|---|---|---|
| Twig Soldier | Melee frontline | Front | Sapling | Cheap, balanced |
| Twig Spearman | Melee, reach | Front / Middle | Young Tree | Hits 2 tiles deep; bonus vs. large enemies |
| Twig Archer | Ranged | Back | Grown Tree | Fragile, high damage |

Future base troops: Bark Shieldbearer, Seed Slinger, Root Guardian.

### 6.3 Elemental troops
Any base troop can be summoned with an element once the matching branch unlocks it. The element adds stats, an automatic ability, and the elemental matchup.

| Element | Ability flavor |
|---|---|
| Water | Hits slow enemies; archers fire splashing water bolts |
| Fire | Burn damage over time; higher attack, lower HP |
| Nature | Self-heal over time; chance to root enemies in place |
| Ice | Chance to freeze on hit; tougher armor |
| Dark | Lifesteal; reduces enemy damage |

### 6.4 Elemental matchups
Each element is strong against one element and weak against another (5-cycle):

```
Water → Fire → Ice → Nature → Dark → Water
(arrow = "is strong against")
```

- Water douses Fire · Fire melts Ice · Ice freezes Nature · Nature's light dispels Dark · Dark corrupts Water
- Strong: +50% damage dealt. Weak: −25% damage dealt. (Tuning values.)

Because every starting level is a different element, the player needs a spread of branches to counter each one.

### 6.5 Summoning
- Troops are grown from the trunk for a **Sap** cost; elemental troops cost extra sap plus a small amount of their element's power.
- Summoned troops go to a **roster**; the player picks from the roster when setting a formation.
- Roster size is capped by Tree Level.
- **Fallen troops are lost permanently.** Survivors return to the roster and recover fully after battle.

## 7. Progression Summary

| Phase | Player experience |
|---|---|
| Early (Sapling) | Collect sunlight and sap, level the tree, summon first Twig Soldiers |
| Mid (Young/Grown) | Roots unlock; root to Sunny Meadow and Whispering Spring; first Nature & Water branches |
| Late (Elder) | Choose Ember Vent or Frostbite Hollow first, then reach Gloomroot Cavern; mixed-element formations |
| Endgame (World Tree) | Forests, Lakes and harder tiers of each biome, multi-element troops, territory defense |

## 8. UI Screens

- **Grove (home):** the tree with its three parts, collect buttons, growth bar.
- **Tree Upgrades:** tabs for Roots, Trunk and the five Branches, with levels, costs and unlocks.
- **Barracks:** summon troops with sap, choose element, view roster.
- **Garden:** seed plots, growth timers, tap plants to collect, seed pouch.
- **World Map:** nodes, root paths, root growth timers, conquest status, collect elemental power.
- **Formation:** scout info + placement grid.
- **Battle:** auto-battle view with speed/pause/skip.
- **Results:** XP, sap, conquest notice.

## 9. Data Model (sketch)

```
Tree        { level, growth,
              roots:    { level },
              trunk:    { level, storedSap, lastCollectedAt },
              branches: { water, fire, nature, ice, dark: level } }
Resources   { sunlight, xp, sap, power: {water, fire, nature, ice, dark} }
MapNode     { id, levelId | null, neighbors[], rootDistance }
RootPath    { from, to, state: none|growing|grown, growStartedAt, growDuration }
Level       { id, biome, element, waves[], boss, state, dailyYield, storedPower, lastCollectedAt }
TroopType   { id, baseStats, preferredRow, unlockTreeLevel, sapCost }
Troop       { id, typeId, element | null, level, hp }
Formation   { slots: [{ row, col, troopId }] }
Enemy       { id, biome, element, stats, abilities }
```

Production and root growth are calculated from timestamps on load (no background process needed), clamped to storage caps.

## 10. Tuning Values (initial placeholders)

| Value | Placeholder |
|---|---|
| Daily sunlight | 100 Growth/day at Sapling, scaling with Tree Level |
| Daily sap | 50 × Trunk Level |
| Storage caps | 24h of production |
| Growth to next level | 100 × level^1.5 |
| Root extension cost | 40 × distance² Sap |
| Root grow time | 1h × distance² |
| Branch upgrade cost | 50 × branch level^1.4 of that element |
| Twig Soldier / Spearman / Archer | 10 / 15 / 20 Sap |
| Elemental troop surcharge | +50% Sap + 5 element power |
| Formation slots | 3 + Trunk Level (max 15) |
| Matchup bonus / penalty | +50% / −25% |

## 11. Open Questions

1. **Regroup between waves:** allow formation changes between waves or keep it locked for the whole level?
2. **Territory defense:** can enemies reclaim conquered levels?
3. **Platform & engine:** stay on web, or move to mobile/PC? Online accounts or local saves only?
4. **Monetization** (if any): must not undercut the daily-growth rhythm.
5. **Art direction:** pixel art vs. hand-drawn; side view vs. top-down for battles.

## 12. First Build (v0.1) Scope

**Engine: Godot 4.7** (`godot/`), portrait 720×1280, Compatibility renderer, Android package `com.elementaltree.game` (arm64). Build the test APK with
`godot --headless --path godot --export-debug "Android" build/ElementalTree-0.1.0-debug.apk`. Debug builds show +1h and Reset buttons. Balance check: `godot --headless --path godot --script res://tools/sim_check.gd`; UI smoke test: `.../tools/smoke_test.gd`.

The original HTML/JS prototype (repo root, `npm start`) is kept as a reference but is frozen at the first build: elements, the three new lands and troop upgrades exist only in the Godot build. Battles in the Godot build run bottom-to-top (enemies attack from the top) to match the front-facing formation.

**Included**
- Sapling at Tree Level 1 gathering **10 sunlight/min**; the trunk makes **4 sap/min** per trunk level. Production builds up at the tree (24h cap) and is collected by hand.
- **Tap the branches** for +1 sunlight per tap, to speed up the slow start.
- Growth: channel sunlight into the tree (1 sunlight = 1 growth) or win battles. Growth needed = 50 × level^1.5.
- Upgrades (each part capped at Tree Level):
  - **Roots** (sunlight + sap): +1 map reach per level. Starts at 0.
  - **Trunk** (sunlight + sap): +4 sap/min and +1 formation slot per level (3 slots at level 1, max 9).
  - **Branches** (sunlight): +5 sunlight/min per level.
- Unit stats are HP, DMG and Reach (1 = melee; each point is 30 px on the battlefield).
- Base troops: Twig Soldier (tree level 1), Twig Spearman (level 2), Twig Archer (level 3), grown with sap. Roster cap = 3 + 2 × Tree Level. Fallen troops are lost for good.
- Formation: 3 × 3 grid, front-facing (Front row on top, then Middle, then Back; columns are lanes). Drag a placed troop to move it; dropping on another troop swaps them.
- Auto-battler: 3 waves + a boss wave, survivors keep their damage between waves (no healing; expeditions still heal 25%), 1×/2× speed, pause, retreat, and skip once a level is conquered.
- World map with all five levels playable: Sunny Meadow (reach 1), Whispering Spring (2), Ember Vent and Frostbite Hollow (3), Gloomroot Cavern (4). Each has 3 waves + a boss; the three newer bosses have abilities (Magma Salamander burns, Rime Elk freezes, Hollow Mole King lifesteals).
- **Element rewards:** first clear of a level grants a full day of its element (its daily yield); every repeat win grants 3 hours' worth.
- **Elemental troops** (hidden in the Barracks until the roots reach a land of that element, unlocked by conquering it; cost 20 sap + 6 of the element): Vine Lasher (nature, reach 2, regenerates), Tide Caller (water, ranged, slows), Ember Sprout (fire, high damage, burns), Frost Warden (ice, armored tank, can freeze), Shade Twig (dark, fast, lifesteal).
- **Troop upgrades (infusion):** in the Barracks, select a base troop and spend 5 of an element to give it that element permanently: its matchups, an ability and stat changes (nature +15% HP/+10% DMG & regen; water +10% HP/DMG & slow; fire +30% DMG/−10% HP & burn; ice +25% HP, 10% armor & freeze chance; dark +10% HP/DMG & 30% lifesteal).
- Element matchups are live for troops and enemies (Water → Fire → Ice → Nature → Dark → Water; ×1.5 strong, ×0.75 weak). Levels show a tip naming their counter element.
- Conquered levels store their element's power (up to one day's yield), collected from the map.
- **Expeditions:** every rooted land has a "Start expedition" button. It sends the formation into endless waves of that land's foes, which get 5% stronger (HP and DMG) and slowly more numerous each wave; every 5th wave is a boss wave and a **checkpoint**. Pressing on from a checkpoint rests the squad (+50% HP on top of the usual 25% wave heal). Each cleared wave adds growth (XP) to the expedition's loot (boss waves double), and has a 20% chance to drop a potion and a 30% chance to drop a seed (boss waves always drop one of each). At a checkpoint the player can **return with the loot** or **press on** to the next one. If the squad falls, runs out of time (90 s per wave) or retreats, all the expedition's loot is lost. Fallen troops are lost for good either way. Expeditions never conquer a land or count as clears.
- **Garden (tab):** 12 plots for seeds found on expeditions. Each cleared expedition wave has a 30% chance to drop a seed (boss checkpoints always drop one): 60% a seed of the land's element, otherwise an Acorn. Seeds are kept only if the squad returns, like the rest of the loot. A planted seed grows for **5 minutes**, then its plant gathers resources (stored up to 4 hours' worth) that are collected by **tapping the plant**. Acorn → Garden Sapling (2 sunlight + 1 sap per min); Daisy/Lily/Poppy/Bell/Nightshade Seed → Verdant Daisy (nature), Dewdrop Lily (water), Ember Poppy (fire), Frost Bell (ice), Nightshade (dark), each making 1 of its element per 20 min. Plants stay until uprooted (which loses anything uncollected). The seed pouch lists only seeds the player has (or says it is empty).
- **Inventory & potions:** the Grove has an **Inventory** button listing the potions found on expeditions; a **Potions** button opens it in battle and at expedition checkpoints (the battle pauses while it is open). **Thorn Draught** gives troops +15% damage, **Bark Brew** +20% max HP, and **Growth Tonic** +50% growth from battles. Each lasts 5 waves (a whole level, or about one expedition checkpoint stretch) and the same potion can't stack. Drunk in the Grove, a potion is readied for the next battle or expedition (and can be put back until then); drunk in battle it works at once. Tuned so one potion tips a close fight but both combat potions together are worth about one extra troop, and an expedition turns up fewer potions than it takes to keep a buff running (see `sim_check.gd`).

**Simplified for now**
- Roots grow instantly on upgrade: no per-path sap cost or grow timers yet.
- Elemental branches (spending power on the tree itself) aren't in yet; power is spent on troops.
- Tree stages beyond Sapling/Young Tree are cosmetic names only.

**Temp art** is in Penpot on the "Elemental Tree – Temp Assets" page; `tools/gen-assets.mjs` regenerates the matching SVGs in `assets/`.

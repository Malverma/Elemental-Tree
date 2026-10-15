class_name GameData
## Static game data and economy formulas. All tuning lives here.

const ELEMENTS := ["nature", "water", "fire", "ice", "dark"]

# Each element is strong against the next one in this cycle (spec §6.4).
const STRONG_AGAINST := {"water": "fire", "fire": "ice", "ice": "nature", "nature": "dark", "dark": "water"}

const STORAGE_CAP_MINUTES := 24.0 * 60.0
const TAP_SUNLIGHT := 1
const TAP_SAP := 1
# Reach 1 = melee. Each point of reach is this many pixels on the battlefield.
const REACH_UNIT := 30.0

const BIOME_COLORS := {
	"nature": Color("#7CC46A"),
	"water": Color("#5BB4E8"),
	"fire": Color("#F0642D"),
	"ice": Color("#9FDDF5"),
	"dark": Color("#7B54B5"),
}


static func element_multiplier(attacker: String, defender: String) -> float:
	if attacker == "" or defender == "":
		return 1.0
	if STRONG_AGAINST.get(attacker, "") == defender:
		return 1.5
	if STRONG_AGAINST.get(defender, "") == attacker:
		return 0.75
	return 1.0


# --- Combat budget -----------------------------------------------------------
# Auto-battles are a time-to-kill race, not an RPG roll. Author units and waves
# against these paper numbers, then confirm with tools/sim_check.gd.
#   DPS  = dmg / cooldown  (+ burn × dmg while the DoT stays refreshed)
#   EHP  = hp / (1 − armor)
#   P    = sqrt(DPS × EHP)          combat power
#   leftover after a wave ≈ squad_EHP − pack_DPS × (pack_HP / squad_DPS)
# Live fights are harsher: enemies currently pile onto the nearest body.
# Level leftover targets (fraction of starting squad EHP): 0.75, 0.45, 0.20, photo-finish.

static func hit_dps(def: Dictionary) -> float:
	var dps := float(def["dmg"]) / float(def["cooldown"])
	if def.has("burn"):
		dps += float(def["dmg"]) * float(def["burn"])
	return dps


static func ehp(def: Dictionary) -> float:
	return float(def["hp"]) / (1.0 - float(def.get("armor", 0.0)))


static func combat_power(def: Dictionary) -> float:
	return sqrt(hit_dps(def) * ehp(def))


## Squad EHP left after one wave if damage is spread evenly. Negative = wipe.
static func leftover_ehp(squad_ehp: float, squad_dps: float, pack_hp: float, pack_dps: float) -> float:
	if squad_dps <= 0.0:
		return -pack_hp
	return squad_ehp - pack_dps * (pack_hp / squad_dps)


# --- Economy -----------------------------------------------------------------

static func xp_to_next(level: int) -> int:
	return roundi(50.0 * pow(level, 1.5))

static func sunlight_per_min(branches: int) -> float:
	return 10.0 + 5.0 * branches

static func sap_per_min(trunk: int) -> float:
	return 4.0 * trunk

static func formation_slots(trunk: int) -> int:
	return mini(9, 2 + trunk)

static func root_reach(roots: int) -> int:
	return roots

static func roster_cap(tree_level: int) -> int:
	return 3 + 2 * tree_level


# --- Tree parts --------------------------------------------------------------

const PARTS := {
	"roots": {
		"name": "Roots", "start": 0,
		"blurb": "Spread across the world map. Each level reaches one step farther.",
	},
	"trunk": {
		"name": "Trunk", "start": 1,
		"blurb": "Produces sap for growing troops. Also widens the battle formation.",
	},
	"branches": {
		"name": "Branches", "start": 0,
		"blurb": "Catch more of the sun. Raises sunlight gathered per minute.",
	},
}
const PART_ORDER := ["roots", "trunk", "branches"]


# Cost to raise `part` from `lvl` to `lvl + 1`.
static func part_cost(part: String, lvl: int) -> Dictionary:
	match part:
		"roots":
			return {"sunlight": roundi(50 * pow(1.8, lvl)), "sap": roundi(30 * pow(1.8, lvl))}
		"trunk":
			return {"sunlight": roundi(30 * pow(1.6, lvl - 1)), "sap": roundi(20 * pow(1.6, lvl - 1))}
		_:
			return {"sunlight": roundi(40 * pow(1.5, lvl))}


static func part_effect(part: String, lvl: int) -> String:
	match part:
		"roots":
			return "Reach %d" % root_reach(lvl)
		"trunk":
			return "%d sap/min · %d slots" % [sap_per_min(lvl), formation_slots(lvl)]
		_:
			return "%d sunlight/min" % sunlight_per_min(lvl)


# --- Units -------------------------------------------------------------------
# hp, dmg (damage per hit), reach (1 = melee), cooldown (seconds between hits),
# speed (pixels per second). Optional abilities:
#   regen     heals this fraction of max HP per second
#   slow      hits slow the target (moves 40% slower, attacks 30% slower) for SLOW_TIME
#   burn      hits set the target burning for this fraction of the hit per second, for BURN_TIME
#   freeze    chance per hit to freeze the target (no moving or attacking) for FREEZE_TIME
#   armor     takes this fraction less damage
#   lifesteal heals this fraction of the damage it deals

const SLOW_TIME := 2.0
const BURN_TIME := 3.0
const FREEZE_TIME := 1.0

const BASE_TROOPS := ["soldier", "spearman", "archer"]
const TROOP_ORDER := ["soldier", "spearman", "archer", "vine_lasher", "tide_caller", "ember_sprout", "frost_warden", "shade_twig"]
const TROOPS := {
	"soldier": {
		"name": "Twig Soldier", "img": "troop_soldier", "element": "", "unlock_level": 1, "sap_cost": 10,
		"role": "Melee frontline", "preferred_row": "front",
		"hp": 40, "dmg": 5, "reach": 1, "cooldown": 1.0, "speed": 40,
	},
	"spearman": {
		"name": "Twig Spearman", "img": "troop_spearman", "element": "", "unlock_level": 2, "sap_cost": 15,
		"role": "Bonus vs. large foes", "preferred_row": "middle",
		"hp": 38, "dmg": 6, "reach": 2, "cooldown": 1.2, "speed": 38, "vs_large": 1.5,
	},
	"archer": {
		"name": "Twig Archer", "img": "troop_archer", "element": "", "unlock_level": 3, "sap_cost": 20,
		"role": "Ranged, fragile", "preferred_row": "back",
		"hp": 18, "dmg": 6, "reach": 8, "cooldown": 1.4, "speed": 34,
		"projectile": Color("#E8E2D0"), "target_lowest_hp": true,
	},
	# Elemental troops unlock once a land of their element is conquered,
	# and cost some of that element's power to grow.
	"vine_lasher": {
		"name": "Vine Lasher", "img": "troop_vine_lasher", "element": "nature", "unlock_level": 1,
		"sap_cost": 20, "power_cost": 6, "role": "Whips from reach 2, heals over time", "preferred_row": "middle",
		"hp": 42, "dmg": 5, "reach": 2, "cooldown": 1.1, "speed": 38, "regen": 0.025,
	},
	"tide_caller": {
		"name": "Tide Caller", "img": "troop_tide_caller", "element": "water", "unlock_level": 1,
		"sap_cost": 20, "power_cost": 6, "role": "Ranged, hits slow enemies", "preferred_row": "back",
		"hp": 20, "dmg": 4, "reach": 6, "cooldown": 1.3, "speed": 34, "projectile": Color("#5BB4E8"), "slow": true,
	},
	"ember_sprout": {
		"name": "Ember Sprout", "img": "troop_ember_sprout", "element": "fire", "unlock_level": 1,
		"sap_cost": 20, "power_cost": 6, "role": "Hard hitter, sets foes burning", "preferred_row": "front",
		"hp": 28, "dmg": 8, "reach": 1, "cooldown": 1.0, "speed": 45, "burn": 0.3,
	},
	"frost_warden": {
		"name": "Frost Warden", "img": "troop_frost_warden", "element": "ice", "unlock_level": 1,
		"sap_cost": 20, "power_cost": 6, "role": "Armored tank, hits can freeze", "preferred_row": "front",
		"hp": 64, "dmg": 4, "reach": 1, "cooldown": 1.3, "speed": 32, "armor": 0.15, "freeze": 0.12,
	},
	"shade_twig": {
		"name": "Shade Twig", "img": "troop_shade_twig", "element": "dark", "unlock_level": 1,
		"sap_cost": 20, "power_cost": 6, "role": "Fast, heals from damage dealt", "preferred_row": "front",
		"hp": 34, "dmg": 6, "reach": 1, "cooldown": 1.0, "speed": 50, "lifesteal": 0.35,
	},
}

# Upgrading a base troop with elemental power ("infusing") gives it that element:
# its matchups, an ability and some stat changes.
const INFUSE_COST := 5
const INFUSION := {
	"nature": {"hp_mult": 1.15, "dmg_mult": 1.1, "regen": 0.02, "desc": "+15% HP, +10% DMG, heals 2% HP per second"},
	"water": {"hp_mult": 1.1, "dmg_mult": 1.1, "slow": true, "desc": "+10% HP and DMG, hits slow enemies"},
	"fire": {"hp_mult": 0.9, "dmg_mult": 1.3, "burn": 0.3, "desc": "+30% DMG, -10% HP, hits set enemies burning"},
	"ice": {"hp_mult": 1.25, "dmg_mult": 1.0, "armor": 0.1, "freeze": 0.12, "desc": "+25% HP, takes 10% less damage, hits can freeze"},
	"dark": {"hp_mult": 1.1, "dmg_mult": 1.1, "lifesteal": 0.3, "desc": "+10% HP and DMG, heals 30% of damage dealt"},
}
const ABILITY_KEYS := ["regen", "slow", "burn", "freeze", "armor", "lifesteal"]


## Effective battle stats for a troop instance ({ id, type, element }).
static func troop_def(troop: Dictionary) -> Dictionary:
	var def: Dictionary = TROOPS[troop["type"]].duplicate()
	var el: String = troop.get("element", "")
	if el != "" and def["element"] == "":
		var inf: Dictionary = INFUSION[el]
		def["element"] = el
		def["name"] = "%s %s" % [el.capitalize(), def["name"]]
		def["hp"] = roundi(def["hp"] * inf["hp_mult"])
		def["dmg"] = snappedf(def["dmg"] * inf["dmg_mult"], 0.1)
		for k in ABILITY_KEYS:
			if inf.has(k):
				def[k] = inf[k]
	return def


static func strong_against(element: String) -> String:
	return STRONG_AGAINST.get(element, "")


static func weak_against(element: String) -> String:
	for k in STRONG_AGAINST:
		if STRONG_AGAINST[k] == element:
			return k
	return ""


const ENEMIES := {
	"thorn_beetle": {"name": "Thorn Beetle", "img": "enemy_thorn_beetle", "element": "nature",
		"hp": 20, "dmg": 3, "reach": 1, "cooldown": 1.2, "speed": 30},
	"burrow_rabbit": {"name": "Burrow Rabbit", "img": "enemy_burrow_rabbit", "element": "nature",
		"hp": 11, "dmg": 3, "reach": 1, "cooldown": 1.1, "speed": 60},
	"bramble_hare": {"name": "Bramble Hare", "img": "enemy_bramble_hare", "element": "nature",
		"hp": 110, "dmg": 6, "reach": 1, "cooldown": 1.4, "speed": 34, "large": true, "boss": true},
	"spring_frog": {"name": "Spring Frog", "img": "enemy_spring_frog", "element": "water",
		"hp": 22, "dmg": 4, "reach": 1, "cooldown": 1.25, "speed": 45},
	"ripple_sprite": {"name": "Ripple Sprite", "img": "enemy_ripple_sprite", "element": "water",
		"hp": 13, "dmg": 3, "reach": 5, "cooldown": 1.6, "speed": 32, "projectile": Color("#7FC8F0")},
	"mossback_turtle": {"name": "Old Mossback Turtle", "img": "enemy_mossback_turtle", "element": "water",
		"hp": 150, "dmg": 7, "reach": 1, "cooldown": 1.95, "speed": 22, "large": true, "boss": true},
	"cinder_lizard": {"name": "Cinder Lizard", "img": "enemy_cinder_lizard", "element": "fire",
		"hp": 26, "dmg": 4, "reach": 1, "cooldown": 1.2, "speed": 40},
	"ash_moth": {"name": "Ash Moth", "img": "enemy_ash_moth", "element": "fire",
		"hp": 13, "dmg": 3, "reach": 4, "cooldown": 1.4, "speed": 48, "projectile": Color("#FF8A3D")},
	"magma_salamander": {"name": "Magma Salamander", "img": "enemy_magma_salamander", "element": "fire",
		"hp": 200, "dmg": 8, "reach": 1, "cooldown": 1.7, "speed": 26, "large": true, "boss": true, "burn": 0.3},
	"frost_wolf": {"name": "Frost Wolf", "img": "enemy_frost_wolf", "element": "ice",
		"hp": 26, "dmg": 4, "reach": 1, "cooldown": 1.0, "speed": 58},
	"icicle_bat": {"name": "Icicle Bat", "img": "enemy_icicle_bat", "element": "ice",
		"hp": 16, "dmg": 3, "reach": 4, "cooldown": 1.5, "speed": 50, "projectile": Color("#BDEBFF")},
	"rime_elk": {"name": "Rime Elk", "img": "enemy_rime_elk", "element": "ice",
		"hp": 230, "dmg": 9, "reach": 1, "cooldown": 1.8, "speed": 28, "large": true, "boss": true, "freeze": 0.12},
	"cave_bat": {"name": "Cave Bat", "img": "enemy_cave_bat", "element": "dark",
		"hp": 17, "dmg": 4, "reach": 1, "cooldown": 0.9, "speed": 66},
	"shadow_slime": {"name": "Shadow Slime", "img": "enemy_shadow_slime", "element": "dark",
		"hp": 48, "dmg": 5, "reach": 1, "cooldown": 1.4, "speed": 24},
	"hollow_mole_king": {"name": "Hollow Mole King", "img": "enemy_hollow_mole_king", "element": "dark",
		"hp": 290, "dmg": 10, "reach": 1, "cooldown": 1.7, "speed": 24, "large": true, "boss": true, "lifesteal": 0.3},
}


# --- World map ---------------------------------------------------------------
# Coordinates are in a 680x640 map space; the home grove sits in the middle.

const GROVE := Vector2(340, 330)
const LEVEL_ORDER := ["sunny_meadow", "whispering_spring", "ember_vent", "frostbite_hollow", "gloomroot_cavern"]
const LEVELS := {
	"sunny_meadow": {
		"name": "Sunny Meadow", "biome": "Meadows", "element": "nature", "distance": 1, "from": "grove",
		"pos": Vector2(165, 255), "playable": true, "daily_yield": 20,
		"rewards": {"first_xp": 60, "xp": 20, "sap": 15},
		"waves": [
			["burrow_rabbit", "burrow_rabbit", "burrow_rabbit"],
			["thorn_beetle", "burrow_rabbit", "thorn_beetle", "burrow_rabbit"],
			["thorn_beetle", "thorn_beetle", "burrow_rabbit", "thorn_beetle", "burrow_rabbit"],
			["bramble_hare", "burrow_rabbit", "burrow_rabbit"],
		],
	},
	"whispering_spring": {
		"name": "Whispering Spring", "biome": "Springs", "element": "water", "distance": 2, "from": "sunny_meadow",
		"pos": Vector2(120, 95), "playable": true, "daily_yield": 25,
		"rewards": {"first_xp": 120, "xp": 35, "sap": 25},
		"waves": [
			["spring_frog", "spring_frog", "spring_frog"],
			["spring_frog", "ripple_sprite", "spring_frog", "ripple_sprite"],
			["spring_frog", "spring_frog", "spring_frog", "ripple_sprite", "ripple_sprite", "ripple_sprite"],
			["mossback_turtle", "ripple_sprite", "ripple_sprite"],
		],
	},
	"ember_vent": {
		"name": "Ember Vent", "biome": "Volcanic Ridge", "element": "fire", "distance": 3, "from": "root_fork",
		"pos": Vector2(570, 95), "playable": true, "daily_yield": 30,
		"rewards": {"first_xp": 180, "xp": 50, "sap": 35},
		"waves": [
			["cinder_lizard", "cinder_lizard", "cinder_lizard"],
			["cinder_lizard", "ash_moth", "cinder_lizard", "ash_moth"],
			["cinder_lizard", "cinder_lizard", "cinder_lizard", "ash_moth", "ash_moth", "ash_moth"],
			["magma_salamander", "ash_moth", "ash_moth"],
		],
	},
	"frostbite_hollow": {
		"name": "Frostbite Hollow", "biome": "Frozen Tundra", "element": "ice", "distance": 3, "from": "root_fork",
		"pos": Vector2(575, 455), "playable": true, "daily_yield": 30,
		"rewards": {"first_xp": 180, "xp": 50, "sap": 35},
		"waves": [
			["frost_wolf", "frost_wolf", "frost_wolf"],
			["frost_wolf", "icicle_bat", "frost_wolf", "icicle_bat"],
			["frost_wolf", "frost_wolf", "frost_wolf", "icicle_bat", "icicle_bat", "icicle_bat"],
			["rime_elk", "frost_wolf", "frost_wolf"],
		],
	},
	"gloomroot_cavern": {
		"name": "Gloomroot Cavern", "biome": "Underground Caves", "element": "dark", "distance": 4, "from": "grove",
		"pos": Vector2(250, 530), "playable": true, "daily_yield": 35,
		"rewards": {"first_xp": 260, "xp": 70, "sap": 45},
		"waves": [
			["cave_bat", "cave_bat", "cave_bat"],
			["shadow_slime", "cave_bat", "shadow_slime", "cave_bat"],
			["shadow_slime", "shadow_slime", "shadow_slime", "cave_bat", "cave_bat", "cave_bat"],
			["hollow_mole_king", "shadow_slime", "cave_bat", "cave_bat"],
		],
	},
}

# Path-only waypoints (not levels) that root paths travel through.
const WAYPOINTS := {
	"root_fork": {"name": "Root Fork", "distance": 2, "from": "grove", "pos": Vector2(480, 270)},
}


# Battle rewards of elemental power: a full day's yield on first clear, 3 hours' worth on replays.
const FIRST_CLEAR_POWER_HOURS := 24.0
const REPLAY_POWER_HOURS := 3.0

static func power_reward(level_id: String, first_clear: bool) -> int:
	var hours := FIRST_CLEAR_POWER_HOURS if first_clear else REPLAY_POWER_HOURS
	return roundi(LEVELS[level_id]["daily_yield"] * hours / 24.0)


# --- Expeditions ----------------------------------------------------------------
# Endless waves of a land's foes, fought for growth and loot rather than conquest.
# Every 5th wave is a boss wave and a checkpoint where the squad may head home
# with its loot. If the squad falls (or retreats) the loot is lost.

const EXPEDITION_CHECKPOINT := 5
const EXPEDITION_SCALE := 0.05  # enemy HP and damage grow by this fraction per wave
const EXPEDITION_CAMP_HEAL := 0.5  # pressing on from a checkpoint heals survivors this much (on top of the wave heal)
const EXPEDITION_WAVE_TIME := 90.0  # seconds per wave before the squad gives up
const EXPEDITION_ITEM_CHANCE := 0.2  # per normal wave; boss waves always drop an item

# Potions found on expeditions. Each one boosts the squad for POTION_WAVES waves:
# drunk in the Grove it is ready for the start of the next battle, drunk in battle
# it starts at once. A normal level is 4 waves, so one potion covers a whole level;
# on an expedition it lasts until about the next checkpoint. The same potion
# can't be stacked: drink it again once it has worn off.
#   effect  "dmg": troops deal `amount` more damage
#           "hp":  troops have `amount` more max HP (current HP scales with it)
#           "xp":  growth earned while it is active is raised by `amount`
const POTION_WAVES := 5
const ITEM_ORDER := ["thorn_draught", "bark_brew", "growth_tonic"]
const ITEMS := {
	"thorn_draught": {"name": "Thorn Draught", "img": "item_thorn_draught", "effect": "dmg", "amount": 0.15,
		"desc": "Troops deal +15% damage for 5 waves."},
	"bark_brew": {"name": "Bark Brew", "img": "item_bark_brew", "effect": "hp", "amount": 0.2,
		"desc": "Troops get +20% max HP for 5 waves."},
	"growth_tonic": {"name": "Growth Tonic", "img": "item_growth_tonic", "effect": "xp", "amount": 0.5,
		"desc": "+50% growth from battles for 5 waves."},
}


static func is_expedition_checkpoint(index: int) -> bool:
	return (index + 1) % EXPEDITION_CHECKPOINT == 0


static func expedition_scale(index: int) -> float:
	return 1.0 + EXPEDITION_SCALE * index


## Enemy keys for expedition wave `index` (0-based), drawn from the land's foes.
static func expedition_wave(level_id: String, index: int) -> Array:
	var foes := []
	var boss := ""
	for w in LEVELS[level_id]["waves"]:
		for key in w:
			if ENEMIES[key].get("boss", false):
				boss = key
			elif key not in foes:
				foes.append(key)
	var out := []
	if is_expedition_checkpoint(index):
		out.append(boss)
		for i in mini(4, (index + 1) / EXPEDITION_CHECKPOINT):
			out.append(foes.pick_random())
	else:
		for i in mini(9, 3 + index / 4):
			out.append(foes.pick_random())
	return out


## Growth earned for clearing expedition wave `index`; boss waves give double.
static func expedition_wave_xp(level_id: String, index: int) -> int:
	var xp: float = LEVELS[level_id]["rewards"]["xp"] / 4.0 * (1.0 + 0.1 * index)
	return roundi(xp * (2.0 if is_expedition_checkpoint(index) else 1.0))


static func node_pos(id: String) -> Vector2:
	if id == "grove":
		return GROVE
	if LEVELS.has(id):
		return LEVELS[id]["pos"]
	return WAYPOINTS[id]["pos"]


# --- Garden -----------------------------------------------------------------------
# Seeds found on expeditions are planted in garden plots. After GROW_MINUTES a
# seed is grown and its plant slowly makes resources, stored in the plant (up to
# GARDEN_CAP_MINUTES of production) until the player taps it to collect.

const GARDEN_PLOTS := 12
const GROW_MINUTES := 5.0
const GARDEN_CAP_MINUTES := 4.0 * 60.0
const EXPEDITION_SEED_CHANCE := 0.3  # per normal wave; boss waves always drop a seed
const SEED_LAND_CHANCE := 0.6  # a dropped seed is the land's element, otherwise a sapling seed

const SEED_ORDER := ["sapling", "nature", "water", "fire", "ice", "dark"]
# `makes` is resource -> amount per minute once grown. Resources are "sunlight",
# "sap" or an element's power.
const SEEDS := {
	"sapling": {"name": "Acorn", "img": "seed_sapling", "plant": "Garden Sapling", "plant_img": "plant_sapling",
		"makes": {"sunlight": 2.0, "sap": 1.0}},
	"nature": {"name": "Daisy Seed", "img": "seed_nature", "plant": "Verdant Daisy", "plant_img": "flower_nature",
		"makes": {"nature": 0.05}},
	"water": {"name": "Lily Seed", "img": "seed_water", "plant": "Dewdrop Lily", "plant_img": "flower_water",
		"makes": {"water": 0.05}},
	"fire": {"name": "Poppy Seed", "img": "seed_fire", "plant": "Ember Poppy", "plant_img": "flower_fire",
		"makes": {"fire": 0.05}},
	"ice": {"name": "Bell Seed", "img": "seed_ice", "plant": "Frost Bell", "plant_img": "flower_ice",
		"makes": {"ice": 0.05}},
	"dark": {"name": "Nightshade Seed", "img": "seed_dark", "plant": "Nightshade", "plant_img": "flower_dark",
		"makes": {"dark": 0.05}},
}


## A short "2 sunlight + 1 sap / min" style summary of what a plant makes.
static func seed_yield_text(seed_id: String) -> String:
	var parts := []
	for res in SEEDS[seed_id]["makes"]:
		var per_min: float = SEEDS[seed_id]["makes"][res]
		parts.append("%d %s / min" % [per_min, res] if per_min >= 1.0 else "1 %s / %d min" % [res, roundi(1.0 / per_min)])
	return ", ".join(parts)


## Which seed an expedition in `level_id` drops.
static func roll_seed(level_id: String) -> String:
	return LEVELS[level_id]["element"] if randf() < SEED_LAND_CHANCE else "sapling"

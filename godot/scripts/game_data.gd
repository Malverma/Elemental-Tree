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

# Sunlight (growth) to reach the next tree level, sized in minutes of collecting:
# 15 min for 1 → 2, rising ×1.77 a level to 24 h for 9 → 10, then 24 h a level.
# Timed at the sunlight rate with branches one level behind the tree.
const GROWTH_FIRST_MINUTES := 15.0
const GROWTH_DAY_LEVEL := 9

static func growth_minutes(level: int) -> float:
	var ratio := pow(STORAGE_CAP_MINUTES / GROWTH_FIRST_MINUTES, 1.0 / (GROWTH_DAY_LEVEL - 1))
	return GROWTH_FIRST_MINUTES * pow(ratio, mini(level, GROWTH_DAY_LEVEL) - 1)

static func xp_to_next(level: int) -> int:
	return roundi(growth_minutes(level) * sunlight_per_min(level - 1) / 10.0) * 10

# The tree stops at MAX_LEVEL. Prestiging there costs double the last level's
# growth, drops the tree back to level 0 and adds PRESTIGE_BONUS to growth,
# sunlight and sap production and troop HP and damage, per prestige.
const MAX_LEVEL := 10
const PRESTIGE_BONUS := 0.1

static func prestige_cost() -> int:
	return 2 * xp_to_next(MAX_LEVEL - 1)

static func prestige_mult(prestiges: int) -> float:
	return 1.0 + PRESTIGE_BONUS * prestiges

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
		"name": "Roots", "start": 0, "sunlight_share": 0.3,
		"blurb": "Spread across the world map. Each level reaches one step farther.",
	},
	"trunk": {
		"name": "Trunk", "start": 1, "sunlight_share": 0.2,
		"blurb": "Produces sap for growing troops. Also widens the battle formation.",
	},
	"branches": {
		"name": "Branches", "start": 0, "sunlight_share": 0.2,
		"blurb": "Catch more of the sun. Raises sunlight gathered per minute.",
	},
}
const PART_ORDER := ["roots", "trunk", "branches"]


# Part upgrades up to this level cost sunlight only, so early sap goes to troops.
const SAP_FREE_PART_LEVELS := 3

# Cost to raise `part` from `lvl` to `lvl + 1`. Sunlight follows the tree's
# growth curve: a share (`sunlight_share`) of what the tree needed to reach the
# level that unlocks this upgrade, rounded to 5.
static func part_cost(part: String, lvl: int) -> Dictionary:
	var sun: float = PARTS[part]["sunlight_share"] * xp_to_next(maxi(lvl, 1))
	var cost := {"sunlight": roundi(sun / 5.0) * 5}
	match part:
		"roots":
			cost["sap"] = roundi(30 * pow(1.8, lvl))
		"trunk":
			cost["sap"] = roundi(20 * pow(1.6, lvl - 1))
	if lvl + 1 <= SAP_FREE_PART_LEVELS:
		cost.erase("sap")
	return cost


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
#   dive      (foes) rushes the farthest-back row instead of the nearest troop
#   cleave    (foes) each hit also deals this fraction to troops within CLEAVE_RADIUS of the target
# Formation rules: troops hold their spot, chasing foes at most HOLD_RADIUS away
# from it, so rows and lanes matter. Melee troops (reach 1–2) taunt: a non-boss
# foe they hit turns on them for TAUNT_TIME, so a front line screens the rows behind.

const HOLD_RADIUS := 140.0
const TAUNT_TIME := 2.5
const CLEAVE_RADIUS := 70.0
const SLOW_TIME := 2.0
const BURN_TIME := 3.0
const FREEZE_TIME := 1.0

const BASE_TROOPS := ["soldier", "spearman", "archer"]
const TROOP_ORDER := ["soldier", "spearman", "archer", "vine_lasher", "tide_caller", "ember_sprout", "frost_warden", "shade_twig"]
const TROOPS := {
	"soldier": {
		"name": "Twig Soldier", "img": "troop_soldier", "element": "", "unlock_level": 1, "sap_cost": 30,
		"role": "Melee frontline", "preferred_row": "front",
		"hp": 40, "dmg": 5, "reach": 1, "cooldown": 1.0, "speed": 40,
	},
	"spearman": {
		"name": "Twig Spearman", "img": "troop_spearman", "element": "", "unlock_level": 2, "sap_cost": 45,
		"role": "Bonus vs. large foes", "preferred_row": "middle",
		"hp": 38, "dmg": 6, "reach": 2, "cooldown": 1.2, "speed": 38, "vs_large": 1.5,
	},
	"archer": {
		"name": "Twig Archer", "img": "troop_archer", "element": "", "unlock_level": 3, "sap_cost": 60,
		"role": "Ranged, fragile", "preferred_row": "back",
		"hp": 18, "dmg": 6, "reach": 8, "cooldown": 1.4, "speed": 34,
		"projectile": Color("#E8E2D0"), "target_lowest_hp": true,
	},
	# Elemental troops unlock once a land of their element is conquered,
	# and cost some of that element's power to grow.
	"vine_lasher": {
		"name": "Vine Lasher", "img": "troop_vine_lasher", "element": "nature", "unlock_level": 1,
		"sap_cost": 60, "power_cost": 6, "role": "Whips from reach 2, heals over time", "preferred_row": "middle",
		"hp": 42, "dmg": 5, "reach": 2, "cooldown": 1.1, "speed": 38, "regen": 0.025,
	},
	"tide_caller": {
		"name": "Tide Caller", "img": "troop_tide_caller", "element": "water", "unlock_level": 1,
		"sap_cost": 60, "power_cost": 6, "role": "Ranged, hits slow enemies", "preferred_row": "back",
		"hp": 20, "dmg": 4, "reach": 6, "cooldown": 1.3, "speed": 34, "projectile": Color("#5BB4E8"), "slow": true,
	},
	"ember_sprout": {
		"name": "Ember Sprout", "img": "troop_ember_sprout", "element": "fire", "unlock_level": 1,
		"sap_cost": 60, "power_cost": 6, "role": "Hard hitter, sets foes burning", "preferred_row": "front",
		"hp": 28, "dmg": 8, "reach": 1, "cooldown": 1.0, "speed": 45, "burn": 0.3,
	},
	"frost_warden": {
		"name": "Frost Warden", "img": "troop_frost_warden", "element": "ice", "unlock_level": 1,
		"sap_cost": 60, "power_cost": 6, "role": "Armored tank, hits can freeze", "preferred_row": "front",
		"hp": 64, "dmg": 4, "reach": 1, "cooldown": 1.3, "speed": 32, "armor": 0.15, "freeze": 0.12,
	},
	"shade_twig": {
		"name": "Shade Twig", "img": "troop_shade_twig", "element": "dark", "unlock_level": 1,
		"sap_cost": 60, "power_cost": 6, "role": "Fast, heals from damage dealt", "preferred_row": "front",
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
		"hp": 11, "dmg": 3, "reach": 1, "cooldown": 1.1, "speed": 60, "dive": true},
	"bramble_hare": {"name": "Bramble Hare", "img": "enemy_bramble_hare", "element": "nature",
		"hp": 110, "dmg": 6, "reach": 1, "cooldown": 1.4, "speed": 34, "large": true, "boss": true, "cleave": 0.4},
	"spring_frog": {"name": "Spring Frog", "img": "enemy_spring_frog", "element": "water",
		"hp": 22, "dmg": 4, "reach": 1, "cooldown": 1.25, "speed": 45},
	"ripple_sprite": {"name": "Ripple Sprite", "img": "enemy_ripple_sprite", "element": "water",
		"hp": 13, "dmg": 3, "reach": 5, "cooldown": 1.6, "speed": 32, "projectile": Color("#7FC8F0")},
	"mossback_turtle": {"name": "Old Mossback Turtle", "img": "enemy_mossback_turtle", "element": "water",
		"hp": 150, "dmg": 7, "reach": 1, "cooldown": 1.95, "speed": 22, "large": true, "boss": true, "cleave": 0.5},
	"cinder_lizard": {"name": "Cinder Lizard", "img": "enemy_cinder_lizard", "element": "fire",
		"hp": 26, "dmg": 4, "reach": 1, "cooldown": 1.2, "speed": 40},
	"ash_moth": {"name": "Ash Moth", "img": "enemy_ash_moth", "element": "fire",
		"hp": 13, "dmg": 3, "reach": 4, "cooldown": 1.4, "speed": 48, "projectile": Color("#FF8A3D")},
	"magma_salamander": {"name": "Magma Salamander", "img": "enemy_magma_salamander", "element": "fire",
		"hp": 200, "dmg": 8, "reach": 1, "cooldown": 1.7, "speed": 26, "large": true, "boss": true, "burn": 0.3, "cleave": 0.5},
	"frost_wolf": {"name": "Frost Wolf", "img": "enemy_frost_wolf", "element": "ice",
		"hp": 26, "dmg": 4, "reach": 1, "cooldown": 1.0, "speed": 58, "dive": true},
	"icicle_bat": {"name": "Icicle Bat", "img": "enemy_icicle_bat", "element": "ice",
		"hp": 16, "dmg": 3, "reach": 4, "cooldown": 1.5, "speed": 50, "projectile": Color("#BDEBFF")},
	"rime_elk": {"name": "Rime Elk", "img": "enemy_rime_elk", "element": "ice",
		"hp": 230, "dmg": 9, "reach": 1, "cooldown": 1.8, "speed": 28, "large": true, "boss": true, "freeze": 0.12, "cleave": 0.5},
	"cave_bat": {"name": "Cave Bat", "img": "enemy_cave_bat", "element": "dark",
		"hp": 17, "dmg": 4, "reach": 1, "cooldown": 0.9, "speed": 66, "dive": true},
	"shadow_slime": {"name": "Shadow Slime", "img": "enemy_shadow_slime", "element": "dark",
		"hp": 48, "dmg": 5, "reach": 1, "cooldown": 1.4, "speed": 24},
	"hollow_mole_king": {"name": "Hollow Mole King", "img": "enemy_hollow_mole_king", "element": "dark",
		"hp": 290, "dmg": 10, "reach": 1, "cooldown": 1.7, "speed": 24, "large": true, "boss": true, "lifesteal": 0.3, "cleave": 0.5},
	# Brambleheart Thicket
	"thornback_boar": {"name": "Thornback Boar", "img": "enemy_thornback_boar", "element": "nature",
		"hp": 42, "dmg": 3.6, "reach": 1, "cooldown": 1.2, "speed": 42, "armor": 0.1},
	"pollen_wisp": {"name": "Pollen Wisp", "img": "enemy_pollen_wisp", "element": "nature",
		"hp": 14, "dmg": 3, "reach": 4, "cooldown": 1.4, "speed": 40, "projectile": Color("#FFD447"), "regen": 0.02},
	"blight_treant": {"name": "Blight Treant", "img": "enemy_blight_treant", "element": "nature",
		"hp": 250, "dmg": 7.2, "reach": 1, "cooldown": 1.8, "speed": 20, "large": true, "boss": true, "regen": 0.01, "cleave": 0.5},
	# Sunken Lagoon
	"snapjaw_crab": {"name": "Snapjaw Crab", "img": "enemy_snapjaw_crab", "element": "water",
		"hp": 38, "dmg": 4.2, "reach": 1, "cooldown": 1.3, "speed": 34, "armor": 0.25},
	"bubble_eel": {"name": "Bubble Eel", "img": "enemy_bubble_eel", "element": "water",
		"hp": 16, "dmg": 3, "reach": 4, "cooldown": 1.4, "speed": 38, "projectile": Color("#D8F1FF"), "slow": true},
	"lagoon_kraken": {"name": "Lagoon Kraken", "img": "enemy_lagoon_kraken", "element": "water",
		"hp": 310, "dmg": 7.8, "reach": 2, "cooldown": 1.8, "speed": 20, "large": true, "boss": true, "slow": true, "cleave": 0.5},
	# Wild twigs: rival elemental troops guarding the two-element lands, with the same stats as yours.
	"wild_vine_lasher": {"name": "Wild Vine Lasher", "img": "enemy_wild_vine_lasher", "element": "nature",
		"hp": 42, "dmg": 5, "reach": 2, "cooldown": 1.1, "speed": 38, "regen": 0.025},
	"wild_tide_caller": {"name": "Wild Tide Caller", "img": "enemy_wild_tide_caller", "element": "water",
		"hp": 20, "dmg": 4, "reach": 4, "cooldown": 1.3, "speed": 34, "projectile": Color("#5BB4E8"), "slow": true},
	"wild_ember_sprout": {"name": "Wild Ember Sprout", "img": "enemy_wild_ember_sprout", "element": "fire",
		"hp": 28, "dmg": 8, "reach": 1, "cooldown": 1.0, "speed": 45, "burn": 0.3},
	"wild_frost_warden": {"name": "Wild Frost Warden", "img": "enemy_wild_frost_warden", "element": "ice",
		"hp": 64, "dmg": 4, "reach": 1, "cooldown": 1.3, "speed": 32, "armor": 0.15, "freeze": 0.12},
	"wild_shade_twig": {"name": "Wild Shade Twig", "img": "enemy_wild_shade_twig", "element": "dark",
		"hp": 34, "dmg": 6, "reach": 1, "cooldown": 1.0, "speed": 50, "lifesteal": 0.35, "dive": true},
}


# --- World map ---------------------------------------------------------------
# Coordinates are in a 680x1000 map space. Three roots grow out of the home
# grove (west, north and south-east) and fork as they go; each land names the
# land (or the grove) its root branches from, and `distance` is the reach the
# roots need to get there. The last three lands belong to two elements and are
# guarded by wild twigs.
# `scale` multiplies every foe's HP and damage in that land.

const MAP_SIZE := Vector2(680, 1000)
const GROVE := Vector2(340, 450)
const LEVEL_ORDER := ["sunny_meadow", "whispering_spring", "ember_vent", "frostbite_hollow", "gloomroot_cavern",
	"brambleheart_thicket", "sunken_lagoon", "steamvent_marsh", "frostshade_barrows", "blighted_heartwood"]
const LEVELS := {
	"sunny_meadow": {
		"name": "Sunny Meadow", "biome": "Meadows", "elements": ["nature"], "distance": 1, "from": "grove",
		"pos": Vector2(175, 420), "playable": true, "daily_yield": 20,
		"rewards": {"first_xp": 60, "xp": 20, "sap": 15},
		"waves": [
			["burrow_rabbit", "burrow_rabbit", "burrow_rabbit"],
			["thorn_beetle", "burrow_rabbit", "thorn_beetle", "burrow_rabbit"],
			["thorn_beetle", "thorn_beetle", "burrow_rabbit", "thorn_beetle", "burrow_rabbit"],
			["bramble_hare", "burrow_rabbit", "burrow_rabbit"],
		],
	},
	"whispering_spring": {
		"name": "Whispering Spring", "biome": "Springs", "elements": ["water"], "distance": 2, "from": "sunny_meadow",
		"pos": Vector2(115, 250), "playable": true, "daily_yield": 25,
		"rewards": {"first_xp": 120, "xp": 35, "sap": 25},
		"waves": [
			["spring_frog", "spring_frog", "spring_frog"],
			["spring_frog", "ripple_sprite", "spring_frog", "ripple_sprite"],
			["spring_frog", "spring_frog", "spring_frog", "ripple_sprite", "ripple_sprite", "ripple_sprite"],
			["mossback_turtle", "ripple_sprite", "ripple_sprite"],
		],
	},
	"ember_vent": {
		"name": "Ember Vent", "biome": "Volcanic Ridge", "elements": ["fire"], "distance": 3, "from": "grove",
		"pos": Vector2(340, 200), "playable": true, "label_above": true, "daily_yield": 30,
		"rewards": {"first_xp": 180, "xp": 50, "sap": 35},
		"waves": [
			["cinder_lizard", "cinder_lizard", "cinder_lizard"],
			["cinder_lizard", "ash_moth", "cinder_lizard", "ash_moth"],
			["cinder_lizard", "cinder_lizard", "cinder_lizard", "ash_moth", "ash_moth", "ash_moth"],
			["magma_salamander", "ash_moth", "ash_moth"],
		],
	},
	"frostbite_hollow": {
		"name": "Frostbite Hollow", "biome": "Frozen Tundra", "elements": ["ice"], "distance": 4, "from": "ember_vent",
		"pos": Vector2(565, 170), "playable": true, "daily_yield": 30,
		"rewards": {"first_xp": 220, "xp": 60, "sap": 40},
		"waves": [
			["frost_wolf", "frost_wolf", "frost_wolf"],
			["frost_wolf", "icicle_bat", "frost_wolf", "icicle_bat"],
			["frost_wolf", "frost_wolf", "frost_wolf", "icicle_bat", "icicle_bat", "icicle_bat"],
			["rime_elk", "frost_wolf", "frost_wolf"],
		],
	},
	"gloomroot_cavern": {
		"name": "Gloomroot Cavern", "biome": "Underground Caves", "elements": ["dark"], "distance": 5, "from": "grove",
		"pos": Vector2(555, 620), "playable": true, "daily_yield": 35,
		"rewards": {"first_xp": 260, "xp": 70, "sap": 45},
		"waves": [
			["cave_bat", "cave_bat", "cave_bat"],
			["shadow_slime", "cave_bat", "shadow_slime", "cave_bat"],
			["shadow_slime", "shadow_slime", "shadow_slime", "cave_bat", "cave_bat", "cave_bat"],
			["hollow_mole_king", "shadow_slime", "cave_bat", "cave_bat"],
		],
	},
	"brambleheart_thicket": {
		"name": "Brambleheart Thicket", "biome": "Old Thicket", "elements": ["nature"], "distance": 6, "from": "sunny_meadow",
		"pos": Vector2(140, 660), "playable": true, "daily_yield": 40,
		"rewards": {"first_xp": 450, "xp": 120, "sap": 60},
		"waves": [
			["thornback_boar", "thornback_boar", "pollen_wisp", "pollen_wisp"],
			["thornback_boar", "thornback_boar", "thornback_boar", "pollen_wisp", "pollen_wisp"],
			["thornback_boar", "thornback_boar", "thornback_boar", "pollen_wisp", "pollen_wisp", "pollen_wisp"],
			["blight_treant", "thornback_boar", "pollen_wisp", "pollen_wisp"],
		],
	},
	"sunken_lagoon": {
		"name": "Sunken Lagoon", "biome": "Drowned Ruins", "elements": ["water"], "distance": 7, "from": "gloomroot_cavern",
		"pos": Vector2(420, 830), "playable": true, "daily_yield": 45,
		"rewards": {"first_xp": 650, "xp": 170, "sap": 75},
		"waves": [
			["snapjaw_crab", "snapjaw_crab", "bubble_eel", "bubble_eel"],
			["snapjaw_crab", "snapjaw_crab", "snapjaw_crab", "bubble_eel", "bubble_eel"],
			["snapjaw_crab", "snapjaw_crab", "snapjaw_crab", "bubble_eel", "bubble_eel", "bubble_eel"],
			["lagoon_kraken", "snapjaw_crab", "bubble_eel", "bubble_eel"],
		],
	},
	"steamvent_marsh": {
		"name": "Steamvent Marsh", "biome": "Boiling Marsh", "elements": ["water", "fire"], "distance": 8, "from": "ember_vent",
		"pos": Vector2(130, 110), "playable": true, "label_above": true, "daily_yield": 30, "scale": 0.7,
		"rewards": {"first_xp": 950, "xp": 250, "sap": 95},
		"waves": [
			["wild_ember_sprout", "wild_ember_sprout", "wild_tide_caller", "wild_tide_caller"],
			["snapjaw_crab", "cinder_lizard", "snapjaw_crab", "bubble_eel", "ash_moth", "wild_tide_caller"],
			["wild_ember_sprout", "wild_ember_sprout", "wild_ember_sprout", "wild_tide_caller", "wild_tide_caller", "ash_moth"],
			["snapjaw_crab", "wild_ember_sprout", "snapjaw_crab", "bubble_eel", "wild_tide_caller", "bubble_eel", "ash_moth"],
			["lagoon_kraken", "magma_salamander", "wild_ember_sprout", "wild_tide_caller", "wild_tide_caller"],
		],
	},
	"frostshade_barrows": {
		"name": "Frostshade Barrows", "biome": "Frozen Barrows", "elements": ["ice", "dark"], "distance": 9, "from": "frostbite_hollow",
		"pos": Vector2(575, 410), "playable": true, "daily_yield": 30, "scale": 0.95,
		"rewards": {"first_xp": 1350, "xp": 350, "sap": 115},
		"waves": [
			["wild_frost_warden", "wild_shade_twig", "wild_frost_warden", "wild_shade_twig"],
			["frost_wolf", "shadow_slime", "frost_wolf", "icicle_bat", "cave_bat", "wild_shade_twig"],
			["wild_frost_warden", "wild_frost_warden", "wild_frost_warden", "wild_shade_twig", "wild_shade_twig", "icicle_bat"],
			["shadow_slime", "wild_frost_warden", "shadow_slime", "icicle_bat", "wild_shade_twig", "icicle_bat", "cave_bat"],
			["rime_elk", "hollow_mole_king", "wild_frost_warden", "wild_shade_twig", "wild_shade_twig"],
		],
	},
	"blighted_heartwood": {
		"name": "Blighted Heartwood", "biome": "Rotten Heartwood", "elements": ["nature", "dark"], "distance": 10, "from": "brambleheart_thicket",
		"pos": Vector2(190, 880), "playable": true, "daily_yield": 35,
		"rewards": {"first_xp": 1900, "xp": 480, "sap": 140},
		"waves": [
			["wild_vine_lasher", "wild_shade_twig", "wild_vine_lasher", "wild_shade_twig"],
			["thornback_boar", "shadow_slime", "thornback_boar", "pollen_wisp", "cave_bat", "wild_vine_lasher"],
			["wild_vine_lasher", "wild_vine_lasher", "wild_vine_lasher", "wild_shade_twig", "wild_shade_twig", "pollen_wisp"],
			["thornback_boar", "wild_shade_twig", "shadow_slime", "pollen_wisp", "wild_vine_lasher", "pollen_wisp", "cave_bat"],
			["blight_treant", "hollow_mole_king", "wild_vine_lasher", "wild_shade_twig", "wild_shade_twig"],
		],
	},
}

# Path-only waypoints (not levels) that root paths could travel through.
const WAYPOINTS := {}


# Battle rewards of elemental power: a full day's yield on first clear, 3 hours' worth on replays.
# A two-element land yields its `daily_yield` of each of its elements.
const FIRST_CLEAR_POWER_HOURS := 24.0
const REPLAY_POWER_HOURS := 3.0

static func power_reward(level_id: String, first_clear: bool) -> int:
	var hours := FIRST_CLEAR_POWER_HOURS if first_clear else REPLAY_POWER_HOURS
	return roundi(LEVELS[level_id]["daily_yield"] * hours / 24.0)


# --- Expeditions ----------------------------------------------------------------
# Started from the Home Grove: endless waves fought for growth and loot rather
# than conquest. Waves come in stretches of 5 that share one element, cycling
# nature → water → fire → ice → dark → nature… Each stretch ends with that
# element's boss and a checkpoint where the squad may head home with its loot.
# If the squad falls (or retreats) the loot is lost.

const EXPEDITION_CHECKPOINT := 5
const EXPEDITION_SCALE := 0.05  # enemy HP and damage grow by this fraction per wave
const EXPEDITION_CAMP_HEAL := 0.5  # pressing on from a checkpoint heals survivors this much (on top of the wave heal)
const EXPEDITION_WAVE_TIME := 90.0  # seconds per wave before the squad gives up
const EXPEDITION_ITEM_CHANCE := 0.2  # per normal wave; boss waves always drop an item
const EXPEDITION_KILL_POWER := 1  # elemental power looted per enemy defeated, of that enemy's element

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


## The element shared by expedition wave `index` (0-based) and the rest of its stretch.
static func expedition_element(index: int) -> String:
	return ELEMENTS[(index / EXPEDITION_CHECKPOINT) % ELEMENTS.size()]


## The first single-element land of `element`: expedition foes and rewards follow it.
static func land_of(element: String) -> String:
	for id in LEVEL_ORDER:
		if LEVELS[id]["elements"] == [element]:
			return id
	return ""


## "water", or "water and fire" for a two-element land.
static func elements_text(id: String) -> String:
	return " and ".join(LEVELS[id]["elements"])


## Enemy keys for expedition wave `index` (0-based), drawn from its element's foes.
static func expedition_wave(index: int) -> Array:
	var foes := []
	var boss := ""
	for w in LEVELS[land_of(expedition_element(index))]["waves"]:
		for key in w:
			if ENEMIES[key].get("boss", false):
				boss = key
			elif not key in foes:
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


## Growth earned for clearing expedition wave `index`, based on the replay
## growth of its element's land; boss waves give double.
static func expedition_wave_xp(index: int) -> int:
	var land := land_of(expedition_element(index))
	var xp: float = LEVELS[land]["rewards"]["xp"] / 4.0 * (1.0 + 0.1 * index)
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
const SEED_ELEMENT_CHANCE := 0.6  # a dropped seed is the wave's element, otherwise a sapling seed

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


## Which seed an expedition wave of `element` drops.
static func roll_seed(element: String) -> String:
	return element if randf() < SEED_ELEMENT_CHANCE else "sapling"


# --- Dungeons ---------------------------------------------------------------------
# DUNGEON_COUNT dungeons sit at random spots on the world map, each full of foes
# of one random element. A cleared dungeon crumbles and a new one appears
# DUNGEON_RESPAWN_MINUTES later, 1 or 2 reach farther out than the one it
# replaces (the first ones are rolled between reach 1 and DUNGEON_START_MAX);
# a lost battle leaves it standing. A dungeon is about as tough as the land at
# its root distance. Clearing one gives potions, plus garden seeds
# once the tree has prestiged.

const DUNGEON_COUNT := 3
const DUNGEON_RESPAWN_MINUTES := 30.0
const DUNGEON_WAVES := 4  # the last one is a boss wave
const DUNGEON_START_MAX := 5
const DUNGEON_MAX_DISTANCE := 10
const DUNGEON_SCALE_PER_REACH := 0.12  # foe strength per step of reach past (or short of) their home land
const DUNGEON_GAP := 80.0  # map distance kept from lands, the grove, other dungeons and the edge
const DUNGEON_NAMES := {
	"nature": "Overgrown Burrow", "water": "Flooded Grotto", "fire": "Smoldering Pit",
	"ice": "Rime Crypt", "dark": "Shadow Den",
}


## Root distance of the dungeon that replaces a cleared one at `cleared`.
static func next_dungeon_distance(cleared: int) -> int:
	return mini(DUNGEON_MAX_DISTANCE, cleared + randi_range(1, 2))


## Potions for clearing a dungeon at root distance `distance`. Seeds use the same count once the garden is open.
static func dungeon_reward_count(distance: int) -> int:
	return 1 + distance / 3


## The nearest land whose waves include enemy `key`, or "" if no land has it.
static func enemy_home(key: String) -> String:
	var best := ""
	for id in LEVELS:
		for w in LEVELS[id]["waves"]:
			if key in w and (best == "" or LEVELS[id]["distance"] < LEVELS[best]["distance"]):
				best = id
	return best


## A new dungeon of `element` at root distance `distance`: { element, distance, scale, waves }.
## The boss is the element's toughest one from a land within the distance (or the
## nearest one past it), its foes come from lands no farther than the boss's, and
## all of them are scaled up or down to the distance.
static func roll_dungeon(element: String, distance: int) -> Dictionary:
	var boss := ""
	var boss_dist := 0
	for key in ENEMIES:
		var home := enemy_home(key)
		if ENEMIES[key]["element"] != element or home == "" or not ENEMIES[key].get("boss", false):
			continue
		var d: int = LEVELS[home]["distance"]
		var fits := d <= distance
		var best_fits := boss_dist <= distance
		if boss == "" or (fits and (not best_fits or d > boss_dist)) or (not fits and not best_fits and d < boss_dist):
			boss = key
			boss_dist = d
	var boss_home := enemy_home(boss)
	var foes := []
	for key in ENEMIES:
		var home := enemy_home(key)
		if ENEMIES[key]["element"] == element and home != "" and not ENEMIES[key].get("boss", false) \
				and LEVELS[home]["distance"] <= maxi(distance, boss_dist):
			foes.append(key)
	if foes.is_empty():
		foes.append(boss)
	var waves := []
	for i in DUNGEON_WAVES - 1:
		var w := []
		for j in mini(9, 3 + i + distance / 3):
			w.append(foes.pick_random())
		waves.append(w)
	var last := [boss]
	for j in mini(4, 1 + distance / 3):
		last.append(foes.pick_random())
	waves.append(last)
	var scale: float = LEVELS[boss_home].get("scale", 1.0) * clampf(1.0 + DUNGEON_SCALE_PER_REACH * (distance - boss_dist), 0.6, 2.0)
	return {"element": element, "distance": distance, "scale": snappedf(scale, 0.01), "waves": waves}


## A random map spot for a new dungeon, clear of the lands and their names, the
## grove, the root paths and the `taken` dungeon spots. If the map is too crowded
## for a fully clear spot, the roomiest one tried.
static func roll_dungeon_pos(taken: Array) -> Vector2:
	var avoid := _dungeon_avoid(taken)
	var best := Vector2.ZERO
	var best_gap := -1.0
	for i in 300:
		var p := Vector2(randf_range(DUNGEON_GAP, MAP_SIZE.x - DUNGEON_GAP), randf_range(DUNGEON_GAP, MAP_SIZE.y - DUNGEON_GAP))
		var gap := _dungeon_gap(p, avoid)
		if gap >= DUNGEON_GAP:
			return p
		if gap > best_gap:
			best = p
			best_gap = gap
	return best


## Whether a dungeon at `p` is still clear of the lands, the grove, the root
## paths and the `taken` spots (say, after the map layout changed).
static func dungeon_spot_clear(p: Vector2, taken: Array) -> bool:
	return _dungeon_gap(p, _dungeon_avoid(taken)) >= DUNGEON_GAP


# A node and the ends and middle of the name drawn under it.
const _NAME_MARKS := [Vector2.ZERO, Vector2(-55, 48), Vector2(0, 48), Vector2(55, 48)]

# Points a dungeon (and its name) must keep DUNGEON_GAP away from.
static func _dungeon_avoid(taken: Array) -> Array:
	var avoid := []
	for at in [GROVE] + taken:
		for m in _NAME_MARKS:
			avoid.append(at + m)
	for id in LEVELS:
		for m in _NAME_MARKS:
			avoid.append(LEVELS[id]["pos"] + (Vector2(m.x, -m.y) if label_above(id) else m))
		avoid.append_array(root_path_points(LEVELS[id]["from"], id))
	return avoid


static func _dungeon_gap(p: Vector2, avoid: Array) -> float:
	var gap := INF
	for a in avoid:
		for m in _NAME_MARKS:
			gap = minf(gap, (p + m).distance_to(a))
	return gap


## Whether a land's name goes above its node (set where a root comes up from
## right below and would otherwise run through the name).
static func label_above(id: String) -> bool:
	return LEVELS[id].get("label_above", false)


## Points along the curved root path from node `from` to node `to`.
static func root_path_points(from: String, to: String, steps := 24) -> PackedVector2Array:
	var a := node_pos(from)
	var b := node_pos(to)
	var mid := (a + b) / 2.0 + Vector2(b.y - a.y, -(b.x - a.x)) * 0.15
	var pts := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	return pts

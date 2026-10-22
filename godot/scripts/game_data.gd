class_name GameData
## Static game data and economy formulas. All tuning lives here.

const ELEMENTS := ["nature", "water", "fire", "ice", "dark"]

# Each element is strong against the next one in this cycle (spec §6.4).
const STRONG_AGAINST := {"nature": "water", "water": "fire", "fire": "ice", "ice": "dark", "dark": "nature"}

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
# 30 min (300) for 1 → 2, about 67 min (1000) for 2 → 3, then rising ×1.55 a
# level to 24 h for 9 → 10, then 24 h a level.
# Timed at the sunlight rate with branches one level behind the tree.
const GROWTH_FIRST_MINUTES := 30.0
const GROWTH_SECOND_MINUTES := 1000.0 / 15.0
const GROWTH_DAY_LEVEL := 9

static func growth_minutes(level: int) -> float:
	if level <= 1:
		return GROWTH_FIRST_MINUTES
	var ratio := pow(STORAGE_CAP_MINUTES / GROWTH_SECOND_MINUTES, 1.0 / (GROWTH_DAY_LEVEL - 2))
	return GROWTH_SECOND_MINUTES * pow(ratio, mini(level, GROWTH_DAY_LEVEL) - 2)

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

# Sap only grows troops (and the later Roots and Trunk upgrades), so it climbs
# gently: a new Trunk level adds 1 sap/min. With a full level of production a
# tree can afford its part upgrades plus a few troops of the newest kind; taps,
# battle rewards and birds cover the rest.
static func sap_per_min(trunk: int) -> float:
	return 3.0 + trunk

static func formation_slots(trunk: int) -> int:
	return mini(9, 2 + trunk)

static func root_reach(roots: int) -> int:
	return roots

static func roster_cap(tree_level: int) -> int:
	return 3 + 2 * tree_level

# Taps grow with the Tapping part and keep pace with the growth curve: at
# tapping level L a leaf tap gives 1 / TAPS_PER_GROWTH of the growth needed for
# level L + 1, so a tree with matching tapping always needs about the same
# number of taps per level. (Level 1 needs 150, so untrained taps give 1.)
const TAPS_PER_GROWTH := 150

static func tap_sunlight(tap: int) -> int:
	return maxi(TAP_SUNLIGHT, roundi(float(xp_to_next(tap + 1)) / TAPS_PER_GROWTH))

# Trunk taps follow sap production rather than the growth curve: a tap gives
# about a quarter-minute of the sap a trunk matching the tapping level makes.
const TAPS_PER_SAP_MINUTE := 4

static func tap_sap(tap: int) -> int:
	return maxi(TAP_SAP, roundi(sap_per_min(tap + 1) / TAPS_PER_SAP_MINUTE))


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
		"perks": [
			{"id": "bird_targeting", "level": 7, "kind": "Minor perk", "name": "Bird Targeting",
				"desc": "A branch snaps out of the leaves to pop a bird once a minute while you're in the Grove, and collects what it drops."},
		],
	},
	"tap": {
		"name": "Tapping", "start": 0, "sunlight_share": 0.2,
		"blurb": "Each tap on the leaves or trunk gathers more, keeping pace with the tree's growth.",
	},
}
const PART_ORDER := ["roots", "trunk", "branches", "tap"]


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
		"tap":
			return "%d sun · %d sap a tap" % [tap_sunlight(lvl), tap_sap(lvl)]
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
#   cleave    each hit also deals this fraction to foes within CLEAVE_RADIUS of the target
#   thorns    a melee attacker that hits it takes this fraction of the hit back
#   heal      (troops) instead of attacking, mends the most hurt troop in reach by
#             this fraction of its max HP (it only attacks when no one is hurt)
#   vs_large  damage multiplier against large foes (bosses)
#   projectile  ranged: hits travel as a shot of this colour; `shot` names its
#             look and flight in the battle view (see BattleCanvas.SHOTS)
#   hunt_ranged (troops) goes for foes that shoot from range first
#   dive      (foes) rushes the farthest-back row instead of the nearest troop
# Auras help the troops on the stumps right beside it (same row or lane, one
# step away), however strong those troops are, so they stay useful as the
# squad grows; the same aura from two troops adds up:
#   rally     neighbours deal this fraction more damage
#   ward      neighbours take this fraction less damage
#   haste     neighbours attack this fraction faster
# Formation rules: troops hold their spot, chasing foes at most HOLD_RADIUS away
# from it, so rows and lanes matter. Melee troops (reach 1–2) taunt: a non-boss
# foe they hit turns on them for TAUNT_TIME, so a front line screens the rows behind.

const HOLD_RADIUS := 140.0
const TAUNT_TIME := 2.5
const CLEAVE_RADIUS := 70.0
const SLOW_TIME := 2.0
const BURN_TIME := 3.0
const FREEZE_TIME := 1.0
## Stumps closer than this are neighbours for auras (lanes are 105 px apart, rows 90).
const AURA_RADIUS := 110.0
const AURA_KEYS := ["rally", "ward", "haste"]
# Any hit, by troop or foe, has CRIT_CHANCE to be a critical hit for CRIT_MULT damage.
const CRIT_CHANCE := 0.08
const CRIT_MULT := 1.75
# Knockback pushes are this much weaker on large foes and bosses.
const KNOCKBACK_HEAVY := 0.4

## Troops with no element of their own, which can be infused with one.
const BASE_TROOPS := ["soldier", "guard", "scout", "spearman", "archer", "acorn_slinger", "drummer", "sap_mender", "bramble_knight", "elder_oak"]
const TROOP_ORDER := ["soldier", "guard", "scout", "archer", "spearman", "acorn_slinger", "drummer",
	"vine_lasher", "tide_caller", "ember_sprout", "sap_mender", "bramble_knight", "frost_warden", "shade_twig", "elder_oak"]
# Troops come out of the Barracks' root box. `sap_cost` is what a troop is
# worth in sap, for balancing (see tools/sim_check.gd). Each rarity is a clear
# step up in raw power (P = sqrt(DPS × EHP), about 14 / 17 / 22 / 30), while the
# commons carry auras that grow with the squad around them.
const TROOPS := {
	"soldier": {
		"rarity": "common", "name": "Twig Soldier", "img": "troop_soldier", "element": "", "unlock_level": 1, "sap_cost": 30,
		"role": "Frontline. Neighbours deal 10% more damage", "preferred_row": "front",
		"hp": 44, "dmg": 5, "reach": 1, "cooldown": 1.0, "speed": 40, "rally": 0.1,
	},
	"guard": {
		"rarity": "common", "name": "Twig Guard", "img": "troop_guard", "element": "", "unlock_level": 1, "sap_cost": 35,
		"role": "Shield wall: takes 30% less damage, neighbours 10% less", "preferred_row": "front",
		"hp": 50, "dmg": 3, "reach": 1, "cooldown": 1.3, "speed": 32, "armor": 0.3, "ward": 0.1,
	},
	"scout": {
		"rarity": "common", "name": "Thistle Scout", "img": "troop_scout", "element": "", "unlock_level": 2, "sap_cost": 30,
		"role": "Fast, hunts down foes that shoot from range", "preferred_row": "front",
		"hp": 30, "dmg": 4, "reach": 1, "cooldown": 0.75, "speed": 64, "hunt_ranged": true,
	},
	"spearman": {
		"rarity": "uncommon", "name": "Twig Spearman", "img": "troop_spearman", "element": "", "unlock_level": 1, "sap_cost": 45,
		"role": "Reach 2, +75% damage to bosses and large foes", "preferred_row": "middle",
		"hp": 42, "dmg": 6, "reach": 2, "cooldown": 1.2, "speed": 38, "vs_large": 1.75,
	},
	"archer": {
		"rarity": "uncommon", "name": "Twig Archer", "img": "troop_archer", "element": "", "unlock_level": 1, "sap_cost": 50,
		"role": "Long range, picks off the weakest foe", "preferred_row": "back",
		"hp": 22, "dmg": 6.5, "reach": 8, "cooldown": 1.4, "speed": 34,
		"projectile": Color("#E8E2D0"), "shot": "arrow", "target_lowest_hp": true,
	},
	"acorn_slinger": {
		"rarity": "uncommon", "name": "Acorn Slinger", "img": "troop_acorn_slinger", "element": "", "unlock_level": 2, "sap_cost": 55,
		"role": "Lobs acorns that burst on nearby foes", "preferred_row": "back",
		"hp": 26, "dmg": 5, "reach": 6, "cooldown": 1.7, "speed": 34, "cleave": 0.6, "projectile": Color("#A87444"), "shot": "acorn",
	},
	"drummer": {
		"rarity": "uncommon", "name": "Twig Drummer", "img": "troop_drummer", "element": "", "unlock_level": 2, "sap_cost": 50,
		"role": "Neighbours attack 15% faster", "preferred_row": "middle",
		"hp": 40, "dmg": 3, "reach": 2, "cooldown": 1.3, "speed": 36, "haste": 0.15,
	},
	# Elemental troops join the root box once a land of their element is
	# conquered. The farther their land, the later they arrive and the rarer they are.
	"vine_lasher": {
		"rarity": "rare", "name": "Vine Lasher", "img": "troop_vine_lasher", "element": "nature", "unlock_level": 1,
		"sap_cost": 75, "role": "Whips from reach 2, heals over time", "preferred_row": "middle",
		"hp": 56, "dmg": 6.5, "reach": 2, "cooldown": 1.1, "speed": 38, "regen": 0.015,
	},
	"tide_caller": {
		"rarity": "rare", "name": "Tide Caller", "img": "troop_tide_caller", "element": "water", "unlock_level": 1,
		"sap_cost": 90, "role": "Ranged, hits splash and slow enemies", "preferred_row": "back",
		"hp": 30, "dmg": 6, "reach": 6, "cooldown": 1.3, "speed": 34, "projectile": Color("#5BB4E8"), "shot": "tide", "slow": true, "cleave": 0.35,
	},
	"ember_sprout": {
		"rarity": "rare", "name": "Ember Sprout", "img": "troop_ember_sprout", "element": "fire", "unlock_level": 1,
		"sap_cost": 115, "role": "Hard hitter, sets foes burning", "preferred_row": "front",
		"hp": 38, "dmg": 9.5, "reach": 1, "cooldown": 1.0, "speed": 45, "burn": 0.3,
	},
	"sap_mender": {
		"rarity": "rare", "name": "Sap Mender", "img": "troop_sap_mender", "element": "", "unlock_level": 2, "sap_cost": 90,
		"role": "Heals the most hurt troop in reach", "preferred_row": "back",
		"hp": 34, "dmg": 3, "reach": 6, "cooldown": 1.9, "speed": 34, "heal": 0.07, "projectile": Color("#FFD447"), "shot": "sap",
	},
	"bramble_knight": {
		"rarity": "rare", "name": "Bramble Knight", "img": "troop_bramble_knight", "element": "", "unlock_level": 3, "sap_cost": 100,
		"role": "Armored, thorns hurt foes that strike it", "preferred_row": "front",
		"hp": 64, "dmg": 5.5, "reach": 1, "cooldown": 1.2, "speed": 32, "armor": 0.2, "thorns": 0.3,
	},
	"frost_warden": {
		"rarity": "epic", "name": "Frost Warden", "img": "troop_frost_warden", "element": "ice", "unlock_level": 1,
		"sap_cost": 145, "role": "Armored tank, hits can freeze, shields neighbours", "preferred_row": "front",
		"hp": 92, "dmg": 6, "reach": 1, "cooldown": 1.3, "speed": 32, "armor": 0.2, "freeze": 0.15, "ward": 0.1,
	},
	"shade_twig": {
		"rarity": "epic", "name": "Shade Twig", "img": "troop_shade_twig", "element": "dark", "unlock_level": 1,
		"sap_cost": 180, "role": "Fast, heals from damage dealt", "preferred_row": "front",
		"hp": 52, "dmg": 9, "reach": 1, "cooldown": 0.9, "speed": 52, "lifesteal": 0.4,
	},
	"elder_oak": {
		"rarity": "epic", "name": "Elder Oak", "img": "troop_elder_oak", "element": "", "unlock_level": 4, "sap_cost": 170,
		"role": "Huge and slow, sweeping blows hit every foe nearby", "preferred_row": "front",
		"hp": 110, "dmg": 9, "reach": 2, "cooldown": 1.7, "speed": 26, "armor": 0.1, "cleave": 0.4,
	},
}

# Upgrading a base troop with elemental power ("infusing") gives it that element:
# its matchups, an ability and some stat changes.
const INFUSE_COST := 5
const INFUSION := {
	"nature": {"hp_mult": 1.15, "dmg_mult": 1.1, "regen": 0.01, "desc": "+15% HP, +10% DMG, heals 1% HP per second"},
	"water": {"hp_mult": 1.1, "dmg_mult": 1.1, "slow": true, "desc": "+10% HP and DMG, hits slow enemies"},
	"fire": {"hp_mult": 0.9, "dmg_mult": 1.3, "burn": 0.3, "desc": "+30% DMG, -10% HP, hits set enemies burning"},
	"ice": {"hp_mult": 1.25, "dmg_mult": 1.0, "armor": 0.1, "freeze": 0.12, "desc": "+25% HP, takes 10% less damage, hits can freeze"},
	"dark": {"hp_mult": 1.1, "dmg_mult": 1.1, "lifesteal": 0.3, "desc": "+10% HP and DMG, heals 30% of damage dealt"},
}
const ABILITY_KEYS := ["regen", "slow", "burn", "freeze", "armor", "lifesteal"]


# --- Root box ---------------------------------------------------------------

# Troops are summoned from the root box in the Barracks. Sap injected into the
# box (from `min_sap`, needed to open it, up to `max_sap`) moves its odds along
# the tier's `curve`: points of [sap, weights], straight lines between them.
# A weight is keyed by a troop type, or by a rarity to share evenly among that
# rarity's troops not named on their own. Elemental power injected (up to
# BOX_MAX_POWER of one element) raises the chance of that element's troop in a
# straight line from its usual odds up to BOX_FOCUS_MAX (95% at a full 10, in
# every tier), shrinking the other troops' odds to make room.
# Only unlocked troops can come out: a named troop that is still locked passes
# its weight to the rest of its rarity, and a rarity with nothing unlocked
# passes its weight down to the next rarity that has something.
# Each prestige raises the weight of the better rarities a little (see
# BOX_PRESTIGE_BONUS): at prestige 10, Rare troops weigh twice as much.
# The box favours troops the roster is short of: each one of a type already
# in the roster scales that type's weight by BOX_REPEAT (down to BOX_REPEAT_MIN),
# so a box rarely hands out the same troop again and again.
# The box upgrades Root → Bark → Heartwood, and keeps its tier through prestige.
#
# Odds by rarity (common / uncommon / rare / epic):
#   Root       30: 50 / 38 / 11 /  1  →  75: 30 / 45 / 21 /  4  →  150: 12 / 38 / 38 / 12
#   Bark       60: 30 / 45 / 21 /  4  →  300:  5 / 35 / 42 / 18
#   Heartwood 120:  8 / 37 / 38 / 17  →  600:  0 / 15 / 50 / 35
# Each tier doubles the sap range and pays off once elemental lands are conquered.
const RARITY_ORDER := ["common", "uncommon", "rare", "epic"]
const RARITY := {
	"common": {"name": "Common", "color": Color("#D8CFB8")},
	"uncommon": {"name": "Uncommon", "color": Color("#8FD16A")},
	"rare": {"name": "Rare", "color": Color("#5BB4E8")},
	"epic": {"name": "Epic", "color": Color("#C98AF2")},
}
const BOX_MAX_POWER := 10
const BOX_FOCUS_MAX := 0.95
## Added to each rarity's weight per prestige, as a fraction of it.
const BOX_PRESTIGE_BONUS := {"common": 0.0, "uncommon": 0.04, "rare": 0.1, "epic": 0.15}
const BOX_REPEAT := 0.8
const BOX_REPEAT_MIN := 0.35
const TWIG_BOXES := [
	{"name": "Root Box", "img": "twig_box_1", "unlock_level": 1, "cost": {},
		"min_sap": 30, "max_sap": 150, "sap_step": 15, "curve": [
			[30, {"common": 50, "uncommon": 38, "rare": 11, "epic": 1}],
			[75, {"common": 30, "uncommon": 45, "rare": 21, "epic": 4}],
			[150, {"common": 12, "uncommon": 38, "rare": 38, "epic": 12}]]},
	{"name": "Bark Box", "img": "twig_box_2", "unlock_level": 3, "cost": {"sunlight": 300, "sap": 250},
		"min_sap": 60, "max_sap": 300, "sap_step": 30, "curve": [
			[60, {"common": 30, "uncommon": 45, "rare": 21, "epic": 4}],
			[300, {"common": 5, "uncommon": 35, "rare": 42, "epic": 18}]]},
	{"name": "Heartwood Box", "img": "twig_box_3", "unlock_level": 6, "cost": {"sunlight": 2500, "sap": 1200},
		"min_sap": 120, "max_sap": 600, "sap_step": 60, "curve": [
			[120, {"common": 8, "uncommon": 37, "rare": 38, "epic": 17}],
			[600, {"common": 0, "uncommon": 15, "rare": 50, "epic": 35}]]},
]

static func twig_box(tier: int) -> Dictionary:
	return TWIG_BOXES[clampi(tier, 1, TWIG_BOXES.size()) - 1]

# The tier's curve weights at `sap` (below the first point counts as the first).
static func _box_weights(tier: int, sap: float) -> Dictionary:
	var curve: Array = twig_box(tier)["curve"]
	var a: Array = curve[0]
	var b: Array = curve[0]
	for pt in curve:
		b = pt
		if pt[0] >= sap:
			break
		a = pt
	var t := 0.0 if b[0] == a[0] else clampf((sap - a[0]) / float(b[0] - a[0]), 0.0, 1.0)
	var w := {}
	for k in a[1].keys() + b[1].keys():
		w[k] = lerpf(a[1].get(k, 0.0), b[1].get(k, 0.0), t)
	return w

## The odds of each troop type coming out of a box. `pool` lists the unlocked
## types; `focus_type` (or "") is the troop the injected element favours.
## `prestige` tilts the odds toward the better rarities; `owned` (type -> how
## many the roster has) turns them away from troops already there.
## Returns { types: { type: p }, rarity: { rarity: p }, focus: p }, where
## `focus` is how far the injected energy has pulled the odds, 0..1.
static func box_odds(tier: int, sap: float, focus_type: String, power: float, pool: Array, prestige := 0, owned := {}) -> Dictionary:
	var w := _box_weights(tier, sap)
	# Each rarity's total weight, and how it splits among its unlocked troops.
	var split := {}  # rarity -> { type: weight }
	var total_r := {}
	for r in RARITY_ORDER:
		var unlocked: Array = pool.filter(func(t): return TROOPS[t]["rarity"] == r)
		var shared: float = w.get(r, 0.0)
		var named := {}
		var total: float = shared
		for t in TROOP_ORDER:
			if TROOPS[t]["rarity"] == r and w.has(t):
				total += w[t]
				if t in unlocked:
					named[t] = w[t]
				else:
					shared += w[t]  # still locked: the rest of its rarity takes its weight
		var rest: Array = unlocked.filter(func(t): return not named.has(t))
		if rest.is_empty():
			rest = named.keys()
		var parts := named.duplicate()
		var rest_w := 0.0
		for t in rest:
			rest_w += named.get(t, 0.0)
		for t in rest:
			# Shared weight goes evenly to unnamed troops, or in proportion when all are named.
			parts[t] = parts.get(t, 0.0) + (shared * named[t] / rest_w if named.has(t) and rest_w > 0.0 else shared / rest.size())
		split[r] = parts
		total_r[r] = total
	# A rarity with nothing unlocked passes its weight to the next one down (or up).
	for i in range(RARITY_ORDER.size() - 1, -1, -1):
		var r: String = RARITY_ORDER[i]
		if split[r].is_empty() and total_r[r] > 0.0:
			var to := ""
			for j in range(i - 1, -1, -1):
				if not split[RARITY_ORDER[j]].is_empty():
					to = RARITY_ORDER[j]
					break
			if to == "":
				for j in range(i + 1, RARITY_ORDER.size()):
					if not split[RARITY_ORDER[j]].is_empty():
						to = RARITY_ORDER[j]
						break
			if to != "":
				var into: Dictionary = split[to]
				var into_w := 0.0
				for t in into:
					into_w += into[t]
				for t in into:
					into[t] += total_r[r] * (into[t] / into_w if into_w > 0.0 else 1.0 / into.size())
			total_r[r] = 0.0
	var types := {}
	var sum := 0.0
	for r in RARITY_ORDER:
		for t in split[r]:
			types[t] = split[r][t] * (1.0 + BOX_PRESTIGE_BONUS[r] * prestige) \
				* maxf(BOX_REPEAT_MIN, pow(BOX_REPEAT, owned.get(t, 0)))
			sum += types[t]
	for t in types:
		types[t] /= sum
	var focus := clampf(power / BOX_MAX_POWER, 0.0, 1.0) if focus_type in pool else 0.0
	if focus > 0.0 and types.get(focus_type, 0.0) < 1.0:
		var base: float = types.get(focus_type, 0.0)
		var want := maxf(base, lerpf(base, BOX_FOCUS_MAX, focus))
		for t in types:
			types[t] = want if t == focus_type else types[t] * (1.0 - want) / (1.0 - base)
		types[focus_type] = want
	var rarity := {}
	for r in RARITY_ORDER:
		rarity[r] = 0.0
	for t in types:
		rarity[TROOPS[t]["rarity"]] += types[t]
	return {"types": types, "rarity": rarity, "focus": focus}

## The troop of an element, or "" if there is none.
static func element_troop(element: String) -> String:
	for t in TROOP_ORDER:
		if TROOPS[t]["element"] == element:
			return t
	return ""


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


## One line of plain text for each ability a unit's `def` carries (see the
## ability list under Units), for its details card.
static func troop_traits(def: Dictionary) -> Array:
	var out := []
	var pct := func(x: float) -> String: return "%s%%" % str(snappedf(x * 100.0, 0.1)).trim_suffix(".0")
	if def.has("rally"):
		out.append("Neighbours deal %s more damage" % pct.call(def["rally"]))
	if def.has("ward"):
		out.append("Neighbours take %s less damage" % pct.call(def["ward"]))
	if def.has("haste"):
		out.append("Neighbours attack %s faster" % pct.call(def["haste"]))
	if def.has("armor"):
		out.append("Takes %s less damage" % pct.call(def["armor"]))
	if def.has("heal"):
		out.append("Mends the most hurt troop in reach for %s of its HP, and only attacks when no one is hurt" % pct.call(def["heal"]))
	if def.has("regen"):
		out.append("Heals %s of its HP each second" % pct.call(def["regen"]))
	if def.has("lifesteal"):
		out.append("Heals %s of the damage it deals" % pct.call(def["lifesteal"]))
	if def.has("thorns"):
		out.append("Foes striking it up close take %s of their hit back" % pct.call(def["thorns"]))
	if def.has("cleave"):
		out.append("Each hit also deals %s to foes near the target" % pct.call(def["cleave"]))
	if def.has("burn"):
		out.append("Hits set foes burning for %s of the hit each second, for %d s" % [pct.call(def["burn"]), BURN_TIME])
	if def.get("slow", false):
		out.append("Hits slow foes for %d s" % SLOW_TIME)
	if def.has("freeze"):
		out.append("%s chance a hit freezes the foe for %d s" % [pct.call(def["freeze"]), FREEZE_TIME])
	if def.has("vs_large"):
		out.append("%s more damage to bosses and large foes" % pct.call(def["vs_large"] - 1.0))
	if def.get("hunt_ranged", false):
		out.append("Goes after foes that shoot from range first")
	if def.get("target_lowest_hp", false):
		out.append("Picks off the weakest foe in reach")
	if def["reach"] <= 2:
		out.append("Foes it hits turn to fight it, screening the rows behind")
	return out


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
	"bramble_hare": {"name": "Thornmaw", "img": "enemy_bramble_hare", "element": "nature",
		"hp": 90, "dmg": 5, "reach": 1, "cooldown": 1.4, "speed": 34, "large": true, "boss": true, "cleave": 0.4},
	"spring_frog": {"name": "Spring Frog", "img": "enemy_spring_frog", "element": "water",
		"hp": 18, "dmg": 3, "reach": 1, "cooldown": 1.25, "speed": 45, "dive": true},
	"ripple_sprite": {"name": "Ripple Sprite", "img": "enemy_ripple_sprite", "element": "water",
		"hp": 12, "dmg": 3, "reach": 5, "cooldown": 1.8, "speed": 32, "projectile": Color("#7FC8F0"), "shot": "droplet"},
	"mossback_turtle": {"name": "Old Mossback Turtle", "img": "enemy_mossback_turtle", "element": "water",
		"hp": 120, "dmg": 6, "reach": 1, "cooldown": 1.95, "speed": 22, "large": true, "boss": true, "cleave": 0.5},
	"cinder_lizard": {"name": "Cinder Lizard", "img": "enemy_cinder_lizard", "element": "fire",
		"hp": 26, "dmg": 4, "reach": 1, "cooldown": 1.2, "speed": 40},
	"ash_moth": {"name": "Ash Moth", "img": "enemy_ash_moth", "element": "fire",
		"hp": 13, "dmg": 3, "reach": 4, "cooldown": 1.4, "speed": 48, "projectile": Color("#FF8A3D"), "shot": "ember"},
	"magma_salamander": {"name": "Magma Salamander", "img": "enemy_magma_salamander", "element": "fire",
		"hp": 200, "dmg": 8, "reach": 1, "cooldown": 1.7, "speed": 26, "large": true, "boss": true, "burn": 0.3, "cleave": 0.5},
	"frost_wolf": {"name": "Frost Wolf", "img": "enemy_frost_wolf", "element": "ice",
		"hp": 26, "dmg": 4, "reach": 1, "cooldown": 1.0, "speed": 58, "dive": true},
	"icicle_bat": {"name": "Icicle Bat", "img": "enemy_icicle_bat", "element": "ice",
		"hp": 16, "dmg": 3, "reach": 4, "cooldown": 1.5, "speed": 50, "projectile": Color("#BDEBFF"), "shot": "icicle"},
	"rime_elk": {"name": "Rime Elk", "img": "enemy_rime_elk", "element": "ice",
		"hp": 230, "dmg": 9, "reach": 1, "cooldown": 1.8, "speed": 28, "large": true, "boss": true, "freeze": 0.12, "cleave": 0.5},
	"cave_bat": {"name": "Cave Bat", "img": "enemy_cave_bat", "element": "dark",
		"hp": 17, "dmg": 4, "reach": 1, "cooldown": 0.9, "speed": 66, "dive": true},
	"shadow_slime": {"name": "Shadow Slime", "img": "enemy_shadow_slime", "element": "dark",
		"hp": 48, "dmg": 5, "reach": 1, "cooldown": 1.4, "speed": 24},
	"hollow_mole_king": {"name": "Hollow King", "img": "enemy_hollow_mole_king", "element": "dark",
		"hp": 290, "dmg": 10, "reach": 1, "cooldown": 1.7, "speed": 24, "large": true, "boss": true, "lifesteal": 0.3, "cleave": 0.5},
	# Brambleheart Thicket
	"thornback_boar": {"name": "Thornback Boar", "img": "enemy_thornback_boar", "element": "nature",
		"hp": 42, "dmg": 3.6, "reach": 1, "cooldown": 1.2, "speed": 42, "armor": 0.1},
	"pollen_wisp": {"name": "Pollen Wisp", "img": "enemy_pollen_wisp", "element": "nature",
		"hp": 14, "dmg": 3, "reach": 4, "cooldown": 1.4, "speed": 40, "projectile": Color("#FFD447"), "shot": "pollen", "regen": 0.02},
	"blight_treant": {"name": "Blight Treant", "img": "enemy_blight_treant", "element": "nature",
		"hp": 250, "dmg": 7.2, "reach": 1, "cooldown": 1.8, "speed": 20, "large": true, "boss": true, "regen": 0.01, "cleave": 0.5},
	# Sunken Lagoon
	"snapjaw_crab": {"name": "Snapjaw Crab", "img": "enemy_snapjaw_crab", "element": "water",
		"hp": 38, "dmg": 4.2, "reach": 1, "cooldown": 1.3, "speed": 34, "armor": 0.25},
	"bubble_eel": {"name": "Bubble Eel", "img": "enemy_bubble_eel", "element": "water",
		"hp": 16, "dmg": 3, "reach": 4, "cooldown": 1.4, "speed": 38, "projectile": Color("#D8F1FF"), "shot": "bubble", "slow": true},
	"lagoon_kraken": {"name": "Lagoon Kraken", "img": "enemy_lagoon_kraken", "element": "water",
		"hp": 310, "dmg": 7.8, "reach": 2, "cooldown": 1.8, "speed": 20, "large": true, "boss": true, "slow": true, "cleave": 0.5},
	# Fused bosses of the two-element lands: a little less HP than the two bosses
	# they replace put together. `fused` keeps them out of single-element dungeons.
	"scaldmaw_hydra": {"name": "Scaldmaw Hydra", "img": "enemy_scaldmaw_hydra", "element": "water", "fused": true,
		"hp": 470, "dmg": 11, "reach": 2, "cooldown": 1.7, "speed": 22, "large": true, "boss": true, "burn": 0.3, "slow": true, "cleave": 0.5},
	"rimeshade_wight": {"name": "Rimeshade Wight", "img": "enemy_rimeshade_wight", "element": "ice", "fused": true,
		"hp": 480, "dmg": 12, "reach": 1, "cooldown": 1.7, "speed": 26, "large": true, "boss": true, "freeze": 0.12, "lifesteal": 0.2, "cleave": 0.5},
	# Wild twigs: rival elemental troops guarding the two-element lands, a little weaker than yours.
	"wild_vine_lasher": {"name": "Wild Vine Lasher", "img": "enemy_wild_vine_lasher", "element": "nature",
		"hp": 42, "dmg": 5, "reach": 2, "cooldown": 1.1, "speed": 38, "regen": 0.012},
	"wild_tide_caller": {"name": "Wild Tide Caller", "img": "enemy_wild_tide_caller", "element": "water",
		"hp": 20, "dmg": 4, "reach": 4, "cooldown": 1.3, "speed": 34, "projectile": Color("#5BB4E8"), "shot": "foam", "slow": true},
	"wild_ember_sprout": {"name": "Wild Ember Sprout", "img": "enemy_wild_ember_sprout", "element": "fire",
		"hp": 28, "dmg": 8, "reach": 1, "cooldown": 1.0, "speed": 45, "burn": 0.3},
	"wild_frost_warden": {"name": "Wild Frost Warden", "img": "enemy_wild_frost_warden", "element": "ice",
		"hp": 64, "dmg": 4, "reach": 1, "cooldown": 1.3, "speed": 32, "armor": 0.15, "freeze": 0.12},
	"wild_shade_twig": {"name": "Wild Shade Twig", "img": "enemy_wild_shade_twig", "element": "dark",
		"hp": 34, "dmg": 6, "reach": 1, "cooldown": 1.0, "speed": 50, "lifesteal": 0.35, "dive": true},
}


# --- World map ---------------------------------------------------------------
# Coordinates are in a 680x1520 map space. Three roots grow out of the home
# grove (west, north and south-east) and fork as they go; each land names the
# land (or the grove) its root branches from, and `distance` is the reach the
# roots need to get there. The last three lands belong to two elements and are
# guarded by wild twigs.
# `scale` multiplies every foe's HP and damage in that land.

## Tall to match a phone screen: the map fills it top to bottom, under both
## bars (its last rows sit under the page bar, below the lands).
const MAP_SIZE := Vector2(680, 1520)
## Map rows the top bar and the bottom card cover; dungeons don't spawn there.
const MAP_SAFE_TOP := 190.0
const MAP_SAFE_BOTTOM := 1280.0
const GROVE := Vector2(340, 682)
const LEVEL_ORDER := ["sunny_meadow", "whispering_spring", "ember_vent", "frostbite_hollow", "gloomroot_cavern",
	"brambleheart_thicket", "sunken_lagoon", "steamvent_marsh", "frostshade_barrows", "blighted_heartwood"]
## Two-element lands that only grow on the world maps after a prestige. They're
## side lands: they never gate the tree's growth, and their foes all come from
## the lands above (they're never an enemy's home, see enemy_home).
const PRESTIGE_LEVEL_ORDER := ["mossmire_fen", "cinderfrost_peak", "cindergloom_wastes"]
const LEVELS := {
	"sunny_meadow": {
		"name": "Sunny Meadow", "biome": "Meadows", "elements": ["nature"], "distance": 1, "from": "grove",
		"pos": Vector2(175, 643), "playable": true, "daily_yield": 25,
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
		"pos": Vector2(115, 422), "playable": true, "daily_yield": 30,
		"rewards": {"first_xp": 120, "xp": 35, "sap": 25},
		"waves": [
			["spring_frog", "spring_frog", "spring_frog"],
			["spring_frog", "ripple_sprite", "spring_frog", "ripple_sprite"],
			["spring_frog", "spring_frog", "spring_frog", "ripple_sprite", "ripple_sprite"],
			["mossback_turtle", "ripple_sprite", "ripple_sprite"],
		],
	},
	"ember_vent": {
		"name": "Ember Vent", "biome": "Volcanic Ridge", "elements": ["fire"], "distance": 3, "from": "grove",
		"pos": Vector2(340, 357), "playable": true, "label_above": true, "daily_yield": 40,
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
		"pos": Vector2(565, 318), "playable": true, "daily_yield": 40,
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
		"pos": Vector2(555, 903), "playable": true, "daily_yield": 45,
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
		"pos": Vector2(140, 955), "playable": true, "daily_yield": 50,
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
		"pos": Vector2(420, 1176), "playable": true, "daily_yield": 55, "scale": 1.15,
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
		"pos": Vector2(130, 240), "playable": true, "label_above": true, "daily_yield": 40, "scale": 0.82,
		"rewards": {"first_xp": 950, "xp": 250, "sap": 95},
		"waves": [
			["wild_ember_sprout", "wild_ember_sprout", "wild_tide_caller", "wild_tide_caller"],
			["snapjaw_crab", "cinder_lizard", "snapjaw_crab", "bubble_eel", "ash_moth", "wild_tide_caller"],
			["wild_ember_sprout", "wild_ember_sprout", "wild_ember_sprout", "wild_tide_caller", "wild_tide_caller", "ash_moth"],
			["snapjaw_crab", "wild_ember_sprout", "snapjaw_crab", "bubble_eel", "wild_tide_caller", "bubble_eel", "ash_moth"],
			["scaldmaw_hydra", "wild_ember_sprout", "wild_tide_caller", "wild_tide_caller"],
		],
	},
	"frostshade_barrows": {
		"name": "Frostshade Barrows", "biome": "Frozen Barrows", "elements": ["ice", "dark"], "distance": 9, "from": "frostbite_hollow",
		"pos": Vector2(575, 630), "playable": true, "daily_yield": 40, "scale": 1.1,
		"rewards": {"first_xp": 1350, "xp": 350, "sap": 115},
		"waves": [
			["wild_frost_warden", "wild_shade_twig", "wild_frost_warden", "wild_shade_twig"],
			["frost_wolf", "shadow_slime", "frost_wolf", "icicle_bat", "cave_bat", "wild_shade_twig"],
			["wild_frost_warden", "wild_frost_warden", "wild_frost_warden", "wild_shade_twig", "wild_shade_twig", "icicle_bat"],
			["shadow_slime", "wild_frost_warden", "shadow_slime", "icicle_bat", "wild_shade_twig", "icicle_bat", "cave_bat"],
			["rimeshade_wight", "wild_frost_warden", "wild_shade_twig", "wild_shade_twig"],
		],
	},
	"blighted_heartwood": {
		"name": "Blighted Heartwood", "biome": "Rotten Heartwood", "elements": ["nature", "dark"], "distance": 10, "from": "brambleheart_thicket",
		"pos": Vector2(190, 1241), "playable": true, "daily_yield": 45, "scale": 1.15,
		"rewards": {"first_xp": 1900, "xp": 480, "sap": 140},
		"waves": [
			["wild_vine_lasher", "wild_shade_twig", "wild_vine_lasher", "wild_shade_twig"],
			["thornback_boar", "shadow_slime", "thornback_boar", "pollen_wisp", "cave_bat", "wild_vine_lasher"],
			["wild_vine_lasher", "wild_vine_lasher", "wild_vine_lasher", "wild_shade_twig", "wild_shade_twig", "pollen_wisp"],
			["thornback_boar", "wild_shade_twig", "shadow_slime", "pollen_wisp", "wild_vine_lasher", "pollen_wisp", "cave_bat"],
			["blight_treant", "hollow_mole_king", "wild_vine_lasher", "wild_shade_twig", "wild_shade_twig"],
		],
	},
	# After a prestige only (PRESTIGE_LEVEL_ORDER); their spots come from the map layout.
	"mossmire_fen": {
		"name": "Mossmire Fen", "biome": "Sunken Fen", "elements": ["nature", "water"], "distance": 6, "from": "sunny_meadow",
		"pos": Vector2(140, 955), "playable": true, "daily_yield": 35, "scale": 0.85,
		"rewards": {"first_xp": 520, "xp": 140, "sap": 65},
		"waves": [
			["wild_vine_lasher", "wild_vine_lasher", "wild_tide_caller", "wild_tide_caller"],
			["thornback_boar", "spring_frog", "thornback_boar", "pollen_wisp", "ripple_sprite", "wild_tide_caller"],
			["wild_vine_lasher", "wild_vine_lasher", "wild_vine_lasher", "wild_tide_caller", "wild_tide_caller", "pollen_wisp"],
			["thornback_boar", "spring_frog", "pollen_wisp", "ripple_sprite", "wild_vine_lasher", "wild_tide_caller", "spring_frog"],
			["blight_treant", "mossback_turtle", "wild_vine_lasher", "wild_tide_caller", "wild_tide_caller"],
		],
	},
	"cinderfrost_peak": {
		"name": "Cinderfrost Peak", "biome": "Fire-and-Ice Peak", "elements": ["fire", "ice"], "distance": 8, "from": "frostbite_hollow",
		"pos": Vector2(565, 318), "playable": true, "daily_yield": 40, "scale": 0.9,
		"rewards": {"first_xp": 1000, "xp": 260, "sap": 100},
		"waves": [
			["wild_ember_sprout", "wild_ember_sprout", "wild_frost_warden", "wild_frost_warden"],
			["cinder_lizard", "frost_wolf", "cinder_lizard", "ash_moth", "icicle_bat", "wild_frost_warden"],
			["wild_ember_sprout", "wild_ember_sprout", "wild_ember_sprout", "wild_frost_warden", "wild_frost_warden", "icicle_bat"],
			["frost_wolf", "wild_ember_sprout", "cinder_lizard", "ash_moth", "wild_frost_warden", "icicle_bat", "ash_moth"],
			["magma_salamander", "rime_elk", "wild_ember_sprout", "wild_frost_warden", "wild_frost_warden"],
		],
	},
	"cindergloom_wastes": {
		"name": "Cindergloom Wastes", "biome": "Ashen Wastes", "elements": ["fire", "dark"], "distance": 10, "from": "gloomroot_cavern",
		"pos": Vector2(555, 903), "playable": true, "daily_yield": 45, "scale": 1.15,
		"rewards": {"first_xp": 1900, "xp": 480, "sap": 140},
		"waves": [
			["wild_ember_sprout", "wild_shade_twig", "wild_ember_sprout", "wild_shade_twig"],
			["cinder_lizard", "shadow_slime", "cinder_lizard", "ash_moth", "cave_bat", "wild_shade_twig"],
			["wild_ember_sprout", "wild_ember_sprout", "wild_ember_sprout", "wild_shade_twig", "wild_shade_twig", "ash_moth"],
			["shadow_slime", "wild_ember_sprout", "cinder_lizard", "ash_moth", "wild_shade_twig", "cave_bat", "ash_moth"],
			["magma_salamander", "hollow_mole_king", "wild_ember_sprout", "wild_shade_twig", "wild_shade_twig"],
		],
	},
}


## The lands on the current world map: the after-prestige lands join the rest
## once the map has a layout (the first map has none).
static func map_lands() -> Array:
	return LEVEL_ORDER + PRESTIGE_LEVEL_ORDER if not layout.is_empty() else LEVEL_ORDER

## Each land's names, taken in turn with the tree's prestige, so a redrawn map
## has new names too. The first is the land's `name`.
const LAND_NAMES := {
	"sunny_meadow": ["Sunny Meadow", "Buttercup Fields", "Golden Glade"],
	"whispering_spring": ["Whispering Spring", "Mistfall Pool", "Silverbrook Font"],
	"ember_vent": ["Ember Vent", "Cinder Crag", "Ashfire Ridge"],
	"frostbite_hollow": ["Frostbite Hollow", "Icicle Dell", "Snowdrift Vale"],
	"gloomroot_cavern": ["Gloomroot Cavern", "Duskhollow Deep", "Shadowmaw Caves"],
	"brambleheart_thicket": ["Brambleheart Thicket", "Thornweald", "Briarwood Tangle"],
	"sunken_lagoon": ["Sunken Lagoon", "Drowned Atoll", "Coral Hollows"],
	"steamvent_marsh": ["Steamvent Marsh", "Scalding Fen", "Boilmire Bog"],
	"frostshade_barrows": ["Frostshade Barrows", "Rimegrave Tombs", "Wraithfrost Crypts"],
	"blighted_heartwood": ["Blighted Heartwood", "Rotroot Wilds", "Witherbark Hollow"],
	"mossmire_fen": ["Mossmire Fen", "Lilyrot Bog", "Reedwater Mire"],
	"cinderfrost_peak": ["Cinderfrost Peak", "Steamrime Summit", "Emberglace Spire"],
	"cindergloom_wastes": ["Cindergloom Wastes", "Ashshadow Barrens", "Smokeveil Badlands"],
}

## Which of the LAND_NAMES and DUNGEON_NAMES are in use: the tree's prestige count, set by Game.
static var name_set := 0

static func land_name(id: String) -> String:
	var names: Array = LAND_NAMES.get(id, [LEVELS[id]["name"]])
	return names[name_set % names.size()]

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
#           "reach": troops strike from `amount` reach farther
#           "crit": troops have `amount` more chance to land a critical hit
#           "knockback": troops' hits push foes `amount` pixels away
const POTION_WAVES := 5
# A world-map battle (a land or a dungeon) has SHROOM_CHANCE of starting with one
# mushroom in a random potion's colours growing at the edge of the field.
# Tapping it picks it, for one of that potion.
const SHROOM_CHANCE := 0.5
const ITEM_ORDER := ["thorn_draught", "bark_brew", "reach_tonic", "keen_elixir", "gale_brew"]
const ITEMS := {
	"thorn_draught": {"name": "Thorn Draught", "img": "item_thorn_draught", "shroom": "shroom_thorn_draught", "effect": "dmg", "amount": 0.15,
		"desc": "Troops deal +15% damage for 5 waves."},
	"bark_brew": {"name": "Bark Brew", "img": "item_bark_brew", "shroom": "shroom_bark_brew", "effect": "hp", "amount": 0.2,
		"desc": "Troops get +20% max HP for 5 waves."},
	"reach_tonic": {"name": "Longreach Tonic", "img": "item_reach_tonic", "shroom": "shroom_reach_tonic", "effect": "reach", "amount": 1,
		"desc": "Troops strike from +1 reach for 5 waves."},
	"keen_elixir": {"name": "Keen Elixir", "img": "item_keen_elixir", "shroom": "shroom_keen_elixir", "effect": "crit", "amount": 0.15,
		"desc": "Troops get +15% critical hit chance for 5 waves."},
	"gale_brew": {"name": "Gale Brew", "img": "item_gale_brew", "shroom": "shroom_gale_brew", "effect": "knockback", "amount": 40.0,
		"desc": "Troops' hits knock foes back for 5 waves."},
}

# Birds that visit the Grove can be tapped. A tapped bird bursts into feathers
# and leaves sap or sunlight (half the time each) worth BIRD_MINUTES of what a
# tree of its level makes, or BIRD_POWER of a random element whose land has been
# conquered (BIRD_POWER_CHANCE), or rarely a random potion (BIRD_POTION_CHANCE).
const BIRD_MINUTES := 5.0
## Bird Targeting (a Branches perk) pops a bird this often while the Grove is open.
const BIRD_TARGET_SECONDS := 60.0
const BIRD_POWER := 1
const BIRD_POWER_CHANCE := 0.35
const BIRD_POTION_CHANCE := 0.04


## Sap a tapped bird leaves at tree `level`: BIRD_MINUTES of a trunk at that level.
static func bird_sap(level: int) -> int:
	return roundi(BIRD_MINUTES * sap_per_min(maxi(level, 1)))


## Sunlight a tapped bird leaves at tree `level`: BIRD_MINUTES of branches one
## level behind the tree, as the growth curve is timed.
static func bird_sunlight(level: int) -> int:
	return roundi(BIRD_MINUTES * sunlight_per_min(maxi(level - 1, 0)))


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
	if layout.has(id):
		return layout[id]["pos"]
	if LEVELS.has(id):
		return LEVELS[id]["pos"]
	return WAYPOINTS[id]["pos"]


## The node a land's root grows from: the grove or another land.
static func node_from(id: String) -> String:
	if layout.has(id):
		return layout[id]["from"]
	return LEVELS[id]["from"] if LEVELS.has(id) else WAYPOINTS[id]["from"]


## The world map after a prestige: land id -> { pos, from, label_above }, plus
## "dungeon_spots". Set from the save's map seed (see MapLayout); empty for the
## first map, which uses the positions in LEVELS.
static var layout := {}


# --- Garden -----------------------------------------------------------------------
# Seeds found on expeditions are planted in garden plots. After GROW_MINUTES a
# seed is grown and its plant slowly makes resources, stored in the plant (up to
# GARDEN_CAP_MINUTES of production) until the player taps it to collect.

const GARDEN_PLOTS := 12  # the most plots the garden can hold
const GARDEN_START_PLOTS := 1
const PLOT_BASE_COST := 300  # sunlight for the second plot
const PLOT_COST_GROWTH := 1.6  # each plot after costs this much more

## Sunlight to buy the next plot when the garden has `owned` of them.
static func plot_cost(owned: int) -> int:
	return roundi(PLOT_BASE_COST * pow(PLOT_COST_GROWTH, owned - GARDEN_START_PLOTS) / 10.0) * 10
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
# DUNGEON_COUNT dungeons sit on DUNGEON_SPOTS around the world map, each full of foes
# of one random element. A cleared dungeon crumbles and a new one appears
# DUNGEON_RESPAWN_MINUTES later; a lost battle leaves it standing. Each new
# dungeon's level is rolled within 1 of the tree's level when it appears, and
# it is about as tough as the land at that root distance (the land that gates
# that tree level). Clearing one gives potions, plus garden seeds once the tree
# has prestiged.

const DUNGEON_COUNT := 3
const DUNGEON_EARLY_SEED_CHANCE := 0.15  # before the first prestige, a cleared dungeon may drop one seed
const DUNGEON_RESPAWN_MINUTES := 30.0
const DUNGEON_WAVES := 4  # the last one is a boss wave
const DUNGEON_LEVEL_SPREAD := 1  # a new dungeon is up to this many levels above or below the tree
const DUNGEON_SCALE_PER_REACH := 0.18  # foe strength per step of reach past (or short of) their home land
const DUNGEON_GAP := 80.0  # map distance DUNGEON_SPOTS keep from the lands and the grove
## Each element's dungeon names, taken in turn with the tree's prestige (see name_set).
const DUNGEON_NAMES := {
	"nature": ["Overgrown Burrow", "Mossy Warren", "Thornroot Den"],
	"water": ["Flooded Grotto", "Tidepool Cave", "Sunken Cellar"],
	"fire": ["Smoldering Pit", "Cinder Forge", "Magma Hollow"],
	"ice": ["Rime Crypt", "Frozen Vault", "Glacier Cave"],
	"dark": ["Shadow Den", "Gloom Pit", "Nightshade Lair"],
}

static func dungeon_name(element: String) -> String:
	return DUNGEON_NAMES[element][name_set % DUNGEON_NAMES[element].size()]


## The level of a dungeon appearing while the tree is at `tree_level`.
static func roll_dungeon_level(tree_level: int) -> int:
	return clampi(tree_level + randi_range(-DUNGEON_LEVEL_SPREAD, DUNGEON_LEVEL_SPREAD), 1, MAX_LEVEL)


## Potions for clearing a dungeon of level `level`. Seeds use the same count once the garden is open.
static func dungeon_reward_count(level: int) -> int:
	return 1 + level / 3


## The nearest land whose waves include enemy `key`, or "" if no land has it.
## After-prestige lands only borrow foes, so they're never a home.
static func enemy_home(key: String) -> String:
	var best := ""
	for id in LEVEL_ORDER:
		for w in LEVELS[id]["waves"]:
			if key in w and (best == "" or LEVELS[id]["distance"] < LEVELS[best]["distance"]):
				best = id
	return best


## A new dungeon of `element` at level `level`: { element, level, scale, waves }.
## Its foes match the land at root distance `level`: the boss is the element's
## toughest one from a land within that distance (or the nearest one past it),
## its foes come from lands no farther than the boss's, and all of them are
## scaled up or down to the distance.
static func roll_dungeon(element: String, level: int) -> Dictionary:
	var distance := level
	var boss := ""
	var boss_dist := 0
	for key in ENEMIES:
		var home := enemy_home(key)
		if ENEMIES[key]["element"] != element or home == "" or not ENEMIES[key].get("boss", false) \
				or ENEMIES[key].get("fused", false):
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
	# Each level past 1 adds a foe, going to the regular waves in turn from the last.
	var regular := DUNGEON_WAVES - 1
	var waves := []
	for i in regular:
		var extra := (distance - 1 + i) / regular
		var w := []
		for j in mini(9, 3 + i + extra):
			w.append(foes.pick_random())
		waves.append(w)
	var last := [boss]
	for j in mini(4, 1 + distance / 3):
		last.append(foes.pick_random())
	waves.append(last)
	var scale: float = LEVELS[boss_home].get("scale", 1.0) * clampf(1.0 + DUNGEON_SCALE_PER_REACH * (distance - boss_dist), 0.6, 2.0)
	return {"element": element, "level": level, "scale": snappedf(scale, 0.01), "waves": waves}


## Where dungeons can stand: open ground clear of the lands and their names,
## the grove and the root paths. Only DUNGEON_COUNT are out at once, so a new
## dungeon always has a free spot to choose from.
const DUNGEON_SPOTS := [Vector2(346, 856), Vector2(324, 1041), Vector2(585, 1129), Vector2(450, 470), Vector2(95, 790)]

static func dungeon_spots() -> Array:
	return layout.get("dungeon_spots", DUNGEON_SPOTS)


## A free dungeon spot (not in `taken`), avoiding `last`, the spot the dungeon
## it replaces stood on, so a respawn turns up somewhere new.
static func roll_dungeon_pos(taken: Array, last := Vector2.INF) -> Vector2:
	var free := dungeon_spots().filter(func(p): return not taken.any(func(t): return t.distance_to(p) < 1.0))
	var fresh := free.filter(func(p): return last == Vector2.INF or last.distance_to(p) >= 1.0)
	if not fresh.is_empty():
		return fresh.pick_random()
	return free.pick_random() if not free.is_empty() else dungeon_spots().pick_random()


## Whether `p` is a dungeon spot that none of the `taken` ones already uses
## (a save from before the spots were fixed may have one elsewhere).
static func dungeon_spot_clear(p: Vector2, taken: Array) -> bool:
	return dungeon_spots().any(func(q): return q.distance_to(p) < 1.0) and not taken.any(func(t): return t.distance_to(p) < 1.0)


## Whether a land's name goes above its node (set where a root comes up from
## right below and would otherwise run through the name).
static func label_above(id: String) -> bool:
	if layout.has(id):
		return layout[id]["label_above"]
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

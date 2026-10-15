class_name BattleSim
extends RefCounted
## Auto-battle simulation. Pure logic with no nodes, so it can run headless
## (tools/sim_check.gd) or be stepped frame-by-frame by the battle view.
## Portrait field: the player's troops stand at the bottom and enemies attack from the top.

const W := 720.0
const H := 900.0
const ROWS := ["front", "middle", "back"]
const ROW_Y := {"front": 580.0, "middle": 670.0, "back": 760.0}
const LANE_X := [255.0, 360.0, 465.0]
const WAVE_PAUSE := 1.5
const WAVE_HEAL := 0.25  # expeditions only; level battles carry damage from wave to wave
const TIME_LIMIT := 240.0
const PROJECTILE_SPEED := 380.0
const BODY := 22.0
# Units fight within this band around the three lanes.
const MIN_X := 195.0
const MAX_X := 535.0


class Unit:
	var side: String
	var def: Dictionary
	var pos: Vector2
	var home: Vector2
	var hp: float
	var max_hp: float
	var cd: float
	var target: Unit
	var size: float
	var flash := 0.0
	var troop_id := -1
	# Status effects (seconds remaining).
	var slow_t := 0.0
	var frozen_t := 0.0
	var burn_t := 0.0
	var burn_dps := 0.0
	var burn_shown := 0.0  # burn damage not yet shown as a popup

	func _init(p_side: String, p_def: Dictionary, p_pos: Vector2) -> void:
		side = p_side
		def = p_def
		pos = p_pos
		home = p_pos
		hp = p_def["hp"]
		max_hp = hp
		cd = randf() * 0.4
		size = 84.0 if p_def.get("large", false) else 52.0

	func alive() -> bool:
		return hp > 0.0


class Projectile:
	var pos: Vector2
	var attacker: Unit
	var target: Unit
	var dmg: float
	var color: Color
	var done := false


class DamagePopup:
	var pos: Vector2
	var text: String
	var t := 0.0
	var side: String
	var burn := false


var level_id: String
var level: Dictionary
var allies: Array[Unit] = []
var enemies: Array[Unit] = []
var projectiles: Array[Projectile] = []
var popups: Array[DamagePopup] = []
var wave := 0
var waves_cleared := 0
var phase := "fighting"  # fighting | intermission | checkpoint | won | lost
var pause_timer := 0.0
var time := 0.0
var wave_time := 0.0
var fallen: Array[int] = []
var retreated := false
var seen := {}  # enemy keys that have appeared in this battle
# Expeditions run endless scaling waves and stop at each checkpoint so the
# player can head home ("won") or press on. Loot is only kept on a return.
var expedition := false
var loot_xp := 0
var loot_items := {}  # item_id -> count
var loot_seeds := {}  # seed_id -> count
# Potions drunk this battle: item_id -> index of the last wave they last through.
var potions := {}


# formation: [{ "troop": {id, type, element}, "row": "front"|"middle"|"back", "lane": 0..2 }]
# potions: item ids drunk before the battle, active from the first wave.
func _init(p_level_id: String, formation: Array, p_expedition := false, p_potions := []) -> void:
	level_id = p_level_id
	level = GameData.LEVELS[level_id]
	expedition = p_expedition
	for f in formation:
		var u := Unit.new("ally", GameData.troop_def(f["troop"]), Vector2(LANE_X[f["lane"]], ROW_Y[f["row"]]))
		u.troop_id = f["troop"]["id"]
		allies.append(u)
	_spawn_wave(0)
	for id in p_potions:
		drink(id)


func is_over() -> bool:
	return phase == "won" or phase == "lost"


## Number of waves in the level, or 0 for an endless expedition.
func wave_count() -> int:
	return 0 if expedition else level["waves"].size()


func is_boss_wave() -> bool:
	return GameData.is_expedition_checkpoint(wave) if expedition else wave == wave_count() - 1


## Expedition: head home with the loot from the current checkpoint.
func return_home() -> void:
	if phase == "checkpoint":
		phase = "won"


## Expedition: rest at the checkpoint, then fight on toward the next one.
func press_on() -> void:
	if phase == "checkpoint":
		for a in allies:
			if a.alive():
				a.hp = minf(a.max_hp, a.hp + roundf(a.max_hp * GameData.EXPEDITION_CAMP_HEAL))
		phase = "intermission"
		pause_timer = WAVE_PAUSE


func potion_active(id: String) -> bool:
	return potions.has(id)


## Waves left on an active potion, counting the current (or next) wave.
func potion_waves_left(id: String) -> int:
	return potions[id] - _potion_start() + 1 if potions.has(id) else 0


## Total boost from active potions with this effect ("dmg", "hp" or "xp").
func boost(effect: String) -> float:
	var total := 0.0
	for id in potions:
		if GameData.ITEMS[id]["effect"] == effect:
			total += GameData.ITEMS[id]["amount"]
	return total


# Between waves a potion starts with the coming wave rather than the cleared one.
func _potion_start() -> int:
	return wave + 1 if phase == "intermission" or phase == "checkpoint" else wave


func can_drink(id: String) -> bool:
	return not is_over() and not potions.has(id)


## Starts a potion's effect. Returns false if it's already active or the battle is over.
func drink(id: String) -> bool:
	if not can_drink(id):
		return false
	potions[id] = _potion_start() + GameData.POTION_WAVES - 1
	if GameData.ITEMS[id]["effect"] == "hp":
		_scale_ally_hp(1.0 + GameData.ITEMS[id]["amount"])
	return true


# Ends potions that don't last into wave `next_wave`.
func _expire_potions(next_wave: int) -> void:
	for id in potions.keys():
		if potions[id] < next_wave:
			potions.erase(id)
			if GameData.ITEMS[id]["effect"] == "hp":
				_scale_ally_hp(1.0 / (1.0 + GameData.ITEMS[id]["amount"]))


# Raises or lowers max HP; current HP keeps the same fraction of it.
func _scale_ally_hp(factor: float) -> void:
	for a in allies:
		a.max_hp *= factor
		if a.alive():
			a.hp *= factor


func _spawn_wave(index: int) -> void:
	wave = index
	wave_time = 0.0
	enemies.clear()
	var list: Array = GameData.expedition_wave(level_id, index) if expedition else level["waves"][index]
	var scale := GameData.expedition_scale(index) if expedition else 1.0
	for i in list.size():
		seen[list[i]] = true
		var def: Dictionary = GameData.ENEMIES[list[i]]
		if scale != 1.0:
			def = def.duplicate()
			def["hp"] = roundi(def["hp"] * scale)
			def["dmg"] = def["dmg"] * scale
		var lane := i % 3
		var depth := i / 3
		var p: Vector2
		if def.get("boss", false):
			p = Vector2(LANE_X[1], 200)
		else:
			p = Vector2(LANE_X[lane], 260 - depth * 90 - (0 if lane == 1 else 25))
		enemies.append(Unit.new("enemy", def, p))


func _pick_target(unit: Unit, foes: Array[Unit]) -> Unit:
	var best: Unit = null
	if unit.def.get("target_lowest_hp", false):
		var range_px: float = unit.def["reach"] * GameData.REACH_UNIT + BODY
		for f in foes:
			if f.alive() and unit.pos.distance_to(f.pos) <= range_px and (best == null or f.hp < best.hp):
				best = f
		if best:
			return best
	for f in foes:
		if f.alive() and (best == null or unit.pos.distance_to(f.pos) < unit.pos.distance_to(best.pos)):
			best = f
	return best


func _damage_for(attacker: Unit, target: Unit) -> float:
	var dmg: float = attacker.def["dmg"] * GameData.element_multiplier(attacker.def.get("element", ""), target.def.get("element", ""))
	if attacker.side == "ally":
		dmg *= 1.0 + boost("dmg")
	if target.def.get("large", false) and attacker.def.has("vs_large"):
		dmg *= attacker.def["vs_large"]
	# Kept fractional so stats scale cleanly; popups show the rounded value.
	return dmg * (0.9 + randf() * 0.2)


func _popup(target: Unit, amount: float, burn := false) -> void:
	var p := DamagePopup.new()
	p.pos = target.pos - Vector2(0, target.size / 2)
	p.text = "-%d" % maxi(1, roundi(amount))
	p.side = target.side
	p.burn = burn
	popups.append(p)


func _apply_damage(target: Unit, dmg: float, show := true) -> void:
	if not target.alive():
		return
	target.hp = maxf(0.0, target.hp - dmg)
	if show:
		target.flash = 0.15
		_popup(target, dmg)
	if not target.alive() and target.side == "ally":
		fallen.append(target.troop_id)


# A landed hit: armor, damage, then the attacker's elemental on-hit abilities.
func _hit(attacker: Unit, target: Unit, dmg: float) -> void:
	if not target.alive():
		return
	dmg *= 1.0 - target.def.get("armor", 0.0)
	var dealt := minf(dmg, target.hp)
	_apply_damage(target, dmg)
	var a := attacker.def
	if a.has("lifesteal") and attacker.alive():
		attacker.hp = minf(attacker.max_hp, attacker.hp + dealt * a["lifesteal"])
	if not target.alive():
		return
	if a.has("burn"):
		target.burn_dps = maxf(target.burn_dps if target.burn_t > 0.0 else 0.0, dmg * a["burn"])
		target.burn_t = GameData.BURN_TIME
	if a.get("slow", false):
		target.slow_t = GameData.SLOW_TIME
	if a.has("freeze") and randf() < a["freeze"]:
		target.frozen_t = GameData.FREEZE_TIME


# Burning, regeneration and timers. Returns false if the unit can't act this step.
func _tick_status(unit: Unit, dt: float) -> bool:
	if unit.burn_t > 0.0:
		unit.burn_t -= dt
		var b := unit.burn_dps * dt
		unit.burn_shown += b
		_apply_damage(unit, b, false)
		if unit.burn_shown >= 2.0 or (unit.burn_t <= 0.0 and unit.burn_shown >= 0.5):
			_popup(unit, unit.burn_shown, true)
			unit.burn_shown = 0.0
		if not unit.alive():
			return false
	if unit.def.has("regen"):
		unit.hp = minf(unit.max_hp, unit.hp + unit.max_hp * unit.def["regen"] * dt)
	unit.slow_t = maxf(0.0, unit.slow_t - dt)
	if unit.frozen_t > 0.0:
		unit.frozen_t -= dt
		return false
	return true


func _step_unit(unit: Unit, friends: Array[Unit], foes: Array[Unit], dt: float) -> void:
	unit.flash = maxf(0.0, unit.flash - dt)
	if not _tick_status(unit, dt):
		return
	unit.cd -= dt
	var slowed := unit.slow_t > 0.0
	if unit.target == null or not unit.target.alive() or unit.def.get("target_lowest_hp", false):
		unit.target = _pick_target(unit, foes)
	var t := unit.target
	if t == null:
		return
	var reach: float = unit.def["reach"] * GameData.REACH_UNIT + (BODY * 1.6 if t.def.get("large", false) else BODY)
	var d := unit.pos.distance_to(t.pos)
	# The 1px slack stops units from stalling a hair outside reach due to float error.
	if d > reach + 1.0:
		var step := minf(unit.def["speed"] * (0.6 if slowed else 1.0) * dt, d - reach)
		unit.pos += (t.pos - unit.pos) / d * step
	elif unit.cd <= 0.0:
		unit.cd = unit.def["cooldown"] * (1.3 if slowed else 1.0)
		var dmg := _damage_for(unit, t)
		if unit.def.has("projectile"):
			var p := Projectile.new()
			p.pos = unit.pos - Vector2(0, 6)
			p.attacker = unit
			p.target = t
			p.dmg = dmg
			p.color = unit.def["projectile"]
			projectiles.append(p)
		else:
			_hit(unit, t, dmg)
	# Keep units from stacking on top of each other.
	for f in friends:
		if f == unit or not f.alive():
			continue
		var fd := unit.pos.distance_to(f.pos)
		var min_d := (unit.size + f.size) * 0.38
		if fd > 0.0 and fd < min_d:
			unit.pos += (unit.pos - f.pos) * ((min_d - fd) / fd) * 0.5
	unit.pos.x = clampf(unit.pos.x, MIN_X, MAX_X)
	unit.pos.y = clampf(unit.pos.y, 30.0, H - 30.0)


func step(dt: float) -> void:
	if is_over() or phase == "checkpoint":
		return
	time += dt
	wave_time += dt
	for p in popups:
		p.t += dt
	popups.assign(popups.filter(func(p: DamagePopup) -> bool: return p.t < 0.8))

	if phase == "intermission":
		pause_timer -= dt
		if pause_timer <= 0.0:
			# Survivors regroup between waves. In a level they keep their wounds;
			# on an expedition they recover a quarter of their health.
			for a in allies:
				if a.alive():
					a.pos = a.home
					a.target = null
					if expedition:
						a.hp = minf(a.max_hp, a.hp + roundf(a.max_hp * WAVE_HEAL))
					a.slow_t = 0.0
					a.frozen_t = 0.0
					a.burn_t = 0.0
			_spawn_wave(wave + 1)
			phase = "fighting"
		return

	for u in allies:
		if u.alive():
			_step_unit(u, allies, enemies, dt)
	for u in enemies:
		if u.alive():
			_step_unit(u, enemies, allies, dt)

	for p in projectiles:
		var d := p.pos.distance_to(p.target.pos)
		var s := PROJECTILE_SPEED * dt
		if d <= s or not p.target.alive():
			_hit(p.attacker, p.target, p.dmg)
			p.done = true
		else:
			p.pos += (p.target.pos - p.pos) / d * s
	projectiles.assign(projectiles.filter(func(p: Projectile) -> bool: return not p.done))

	var out_of_time := wave_time > GameData.EXPEDITION_WAVE_TIME if expedition else time > TIME_LIMIT
	if not allies.any(func(u: Unit) -> bool: return u.alive()) or out_of_time:
		phase = "lost"
	elif not enemies.any(func(u: Unit) -> bool: return u.alive()):
		waves_cleared = wave + 1
		projectiles.clear()
		if expedition:
			_collect_wave_loot()
			if GameData.is_expedition_checkpoint(wave):
				_expire_potions(wave + 1)
				phase = "checkpoint"
				return
		if not expedition and wave + 1 >= wave_count():
			phase = "won"
		else:
			_expire_potions(wave + 1)
			phase = "intermission"
			pause_timer = WAVE_PAUSE


func _collect_wave_loot() -> void:
	loot_xp += roundi(GameData.expedition_wave_xp(level_id, wave) * (1.0 + boost("xp")))
	if GameData.is_expedition_checkpoint(wave) or randf() < GameData.EXPEDITION_ITEM_CHANCE:
		var item: String = GameData.ITEM_ORDER.pick_random()
		loot_items[item] = loot_items.get(item, 0) + 1
	if GameData.is_expedition_checkpoint(wave) or randf() < GameData.EXPEDITION_SEED_CHANCE:
		var seed_id := GameData.roll_seed(level_id)
		loot_seeds[seed_id] = loot_seeds.get(seed_id, 0) + 1


# Runs the rest of a battle instantly (used by Skip and the balance check).
# Expeditions stop at the next checkpoint.
func resolve() -> void:
	while not is_over() and phase != "checkpoint":
		step(1.0 / 30.0)


# Units point at each other through `target`, which forms reference cycles.
# Call this when done with a battle so its units can be freed.
func dispose() -> void:
	for u in allies + enemies:
		u.target = null
	projectiles.clear()

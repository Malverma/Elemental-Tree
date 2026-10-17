extends SceneTree
## Headless balance check: runs each level many times with sample squads.
## Run: godot --headless --path godot --script res://tools/sim_check.gd

const RUNS := 200


# Each entry is "type" or "type:element" (an infused base troop).
func _squad(types: Array) -> Array:
	var used := {}
	var out := []
	for i in types.size():
		var parts: PackedStringArray = types[i].split(":")
		var troop := {"id": i + 1, "type": parts[0], "element": parts[1] if parts.size() > 1 else ""}
		var row: String = GameData.TROOPS[troop["type"]]["preferred_row"]
		var r := row
		used[r] = used.get(r, -1) + 1
		if used[r] > 2:  # row full, spill into the next one
			for alt in ["middle", "back", "front"]:
				if used.get(alt, -1) < 2:
					r = alt
					used[r] = used.get(r, -1) + 1
					break
		out.append({"troop": troop, "row": r, "lane": [1, 0, 2][used[r]]})
	return out


func _paper_squad(types: Array) -> Dictionary:
	var e := 0.0
	var d := 0.0
	for t in types:
		var parts: PackedStringArray = t.split(":")
		var def := GameData.troop_def({"type": parts[0], "element": parts[1] if parts.size() > 1 else ""})
		e += GameData.ehp(def)
		d += GameData.hit_dps(def)
	return {"ehp": e, "dps": d, "p": sqrt(e * d)}


func _init() -> void:
	print("Paper combat power (P = sqrt(DPS × EHP))")
	for id in GameData.TROOP_ORDER:
		var def: Dictionary = GameData.TROOPS[id]
		print("  %-14s DPS %5.2f  EHP %5.1f  P %5.1f  P/sap %4.2f" % [
			id, GameData.hit_dps(def), GameData.ehp(def), GameData.combat_power(def),
			GameData.combat_power(def) / def["sap_cost"]])

	print("\nPaper leftover EHP on Sunny Meadow (even damage)")
	for types in [["soldier", "soldier"], ["soldier", "soldier", "soldier"], ["soldier", "soldier", "spearman", "archer"]]:
		var s := _paper_squad(types)
		var e: float = s["ehp"]
		var line := "%-48s start %5.0f" % [str(types), e]
		for w in GameData.LEVELS["sunny_meadow"]["waves"]:
			var php := 0.0
			var pdps := 0.0
			for key in w:
				php += GameData.ENEMIES[key]["hp"]
				pdps += GameData.hit_dps(GameData.ENEMIES[key])
			e = GameData.leftover_ehp(e, s["dps"], php, pdps)
			line += "  → %5.0f" % e
		print(line)

	var scenarios := [
		["sunny_meadow", ["soldier", "soldier"]],
		["sunny_meadow", ["soldier", "soldier", "soldier"]],
		["sunny_meadow", ["soldier", "soldier", "spearman"]],
		["sunny_meadow", ["soldier", "soldier", "spearman", "archer"]],
		["whispering_spring", ["soldier", "soldier", "spearman", "archer", "archer"]],
		["whispering_spring", ["soldier", "soldier", "soldier", "spearman", "spearman", "archer"]],
		["whispering_spring", ["soldier:dark", "soldier", "spearman", "archer", "archer"]],
		["ember_vent", ["soldier", "soldier", "soldier", "spearman", "archer", "archer"]],
		["ember_vent", ["soldier:water", "soldier:water", "soldier", "spearman", "archer", "tide_caller"]],
		["frostbite_hollow", ["soldier", "soldier", "soldier", "spearman", "archer", "archer"]],
		["frostbite_hollow", ["ember_sprout", "ember_sprout", "soldier", "spearman", "archer:fire", "archer"]],
		["gloomroot_cavern", ["soldier", "soldier", "soldier", "spearman", "spearman", "archer", "archer"]],
		["gloomroot_cavern", ["vine_lasher", "soldier:nature", "soldier:nature", "spearman", "archer", "archer", "archer:nature"]],
		["gloomroot_cavern", ["frost_warden", "frost_warden", "shade_twig", "spearman", "tide_caller", "archer", "archer"]],
	]
	for sc in scenarios:
		var wins := 0
		var lost := 0
		var waves := 0
		var time := 0.0
		for i in RUNS:
			var b := BattleSim.new(sc[0], _squad(sc[1]))
			b.resolve()
			b.dispose()
			if b.phase == "won":
				wins += 1
			lost += b.fallen.size()
			waves += b.waves_cleared
			time += b.time
		print("%-17s %-88s win %3d%%  avg waves %.1f  avg lost %.1f  avg %ds" % [
			sc[0], str(sc[1]), 100 * wins / RUNS, float(waves) / RUNS, float(lost) / RUNS, roundi(time / RUNS)])

	# Expeditions: always press on, to see how deep each squad gets.
	print("\nExpeditions (always pressing on)")
	# The first entry is a label only: every expedition sets out from the Home Grove.
	var expeditions := [
		["3 troops", ["soldier", "soldier", "soldier"]],
		["4 troops", ["soldier", "soldier", "spearman", "archer"]],
		["6 troops", ["soldier", "soldier", "soldier", "spearman", "spearman", "archer"]],
		["6 mixed", ["soldier:water", "soldier:water", "soldier", "spearman", "archer", "tide_caller"]],
		["7 mixed", ["vine_lasher", "soldier:nature", "soldier:nature", "spearman", "archer", "archer", "archer:nature"]],
	]
	for sc in expeditions:
		var waves := 0
		var cp1 := 0
		var cp2 := 0
		var cp3 := 0
		var power := 0
		for i in RUNS:
			var b := BattleSim.new_expedition(_squad(sc[1]))
			while true:
				b.resolve()
				if b.phase != "checkpoint" or b.waves_cleared >= 50:
					break
				b.press_on()
			b.dispose()
			waves += b.waves_cleared
			cp1 += 1 if b.waves_cleared >= 5 else 0
			cp2 += 1 if b.waves_cleared >= 10 else 0
			cp3 += 1 if b.waves_cleared >= 15 else 0
			power += b.loot_power.values().reduce(func(x, y): return x + y, 0)
		print("%-17s %-88s avg waves %.1f  reach 5: %3d%%  reach 10: %3d%%  reach 15: %3d%%  avg power %.1f" % [
			sc[0], str(sc[1]), float(waves) / RUNS, 100 * cp1 / RUNS, 100 * cp2 / RUNS, 100 * cp3 / RUNS, float(power) / RUNS])

	# Potions: the same squads with no potion, each combat potion, and both.
	# A potion should help a close fight noticeably without making a hard one free.
	print("\nPotions (win % with none / Thorn Draught / Bark Brew / both)")
	var potion_sets := [[], ["thorn_draught"], ["bark_brew"], ["thorn_draught", "bark_brew"]]
	var potion_scenarios := [
		["sunny_meadow", ["soldier", "soldier"]],
		["whispering_spring", ["soldier", "soldier", "soldier", "spearman"]],
		["whispering_spring", ["soldier", "soldier", "spearman", "archer", "archer"]],
		["ember_vent", ["soldier", "soldier", "spearman", "archer", "archer"]],
		["frostbite_hollow", ["soldier", "soldier", "spearman", "archer", "archer"]],
		["gloomroot_cavern", ["soldier", "soldier", "soldier", "spearman", "archer", "archer"]],
	]
	for sc in potion_scenarios:
		var line := "%-17s %-72s" % [sc[0], str(sc[1])]
		for ps in potion_sets:
			var wins := 0
			for i in RUNS / 2:
				var b := BattleSim.new(sc[0], _squad(sc[1]), false, ps)
				b.resolve()
				b.dispose()
				wins += 1 if b.phase == "won" else 0
			line += "  %3d%%" % (200 * wins / RUNS)
		print(line)

	# Expeditions drinking a fresh potion at every checkpoint: average depth, and
	# potions found vs. drunk (a squad shouldn't be able to keep every buff up for free).
	print("\nExpeditions with potions (avg waves / found per run / drunk per run)")
	for sc in [expeditions[1], expeditions[2], expeditions[4]]:
		var line := "%-17s %-72s" % [sc[0], str(sc[1])]
		for ps in potion_sets:
			var waves := 0
			var found := 0
			var drunk := 0
			var runs := RUNS / 4  # expeditions are long; fewer runs keeps the check quick
			for i in runs:
				var b := BattleSim.new_expedition(_squad(sc[1]), ps)
				drunk += ps.size()
				while true:
					b.resolve()
					if b.phase != "checkpoint" or b.waves_cleared >= 50:
						break
					b.press_on()
					for id in ps:
						if b.drink(id):
							drunk += 1
				b.dispose()
				waves += b.waves_cleared
				for id in b.loot_items:
					found += b.loot_items[id]
			line += "  %4.1f/%.1f/%.1f" % [float(waves) / runs, float(found) / runs, float(drunk) / runs]
		print(line)
	quit()

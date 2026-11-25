extends Node

## Verification: for each level, the catches as Player rolls them (rarity by reach and dark water,
## a rare one now and then the rarest), the species from FishData.pick_species as in play - how
## often one is the branch's own, and about how many catches its quota takes.
const N := 20000

func _ready() -> void:
	_go.call_deferred()

func _go() -> void:
	var lines := ["id\tname\tfish\tepic\tdark\tquota\tp_own\tcatch50\tcatch80\tquota_catches\tper_fish"]
	for l in Campaign.LEVELS:
		var r: Dictionary = Campaign.rules_for(l.id)
		var theme := str(r.theme) if str(r.theme) != "" else MapGenerator.THEME
		var waters := FishData.waters_for_theme(theme)
		FishData.branch_fish = r.get("fish", []).duplicate()
		FishData.branch_epic = r.get("fish_epic", []).duplicate()
		var own: Array = FishData.branch_fish + FishData.branch_epic
		var dark := int(r.ponds[1]) > 0
		var hits := 0
		var each := {}
		var value := 0.0
		for _i in N:
			var tier: String = ["near", "mid", "far"][randi() % 3]
			var zone := "rare" if dark and randf() < 0.3 else "common"
			var rare_chance := Player.FAR_RARE_CHANCE if tier == "far" else Player.NORMAL_RARE_CHANCE
			if zone == "rare":
				rare_chance += Player.RARE_ZONE_RARE_CHANCE_BONUS
			var rare := randf() < rare_chance
			var epic := rare and randf() < Player.EPIC_CHANCE_OF_RARE
			var rarity := "epic" if epic else ("rare" if rare else "common")
			var sp := FishData.pick_species(tier, zone, rarity, "", waters)
			value += float(FishData.TIERS[tier].value) * float(sp.value_mult)
			if sp.id in own:
				hits += 1
				each[sp.id] = int(each.get(sp.id, 0)) + 1
		var p := float(hits) / N
		var c50 := INF if p <= 0.0 else log(0.5) / log(1.0 - p)
		var c80 := INF if p <= 0.0 else log(0.2) / log(1.0 - p)
		var avg := value / N
		lines.append("%s\t%s\t%s\t%s\t%s\t%.0f\t%.4f\t%.1f\t%.1f\t%.1f\t%s" % [l.id, l.name, ",".join(FishData.branch_fish), ",".join(FishData.branch_epic),
			"y" if dark else "n", float(r.quota), p, c50, c80, float(r.quota) / avg, JSON.stringify(each)])
	FishData.branch_fish = []
	FishData.branch_epic = []
	var f := FileAccess.open(OS.get_environment("OUT") + "/catch_sim.tsv", FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("\n".join(lines))
	get_tree().quit()

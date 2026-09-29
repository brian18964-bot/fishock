class_name DerivedArt

## User request: a detailed snowfield and a detailed autumn wood. Their
## trees, rocks and bushes are the detailed sprites made over for the
## season by tools/derive_variants.py - same size and camera, only the
## albedo differs (<name>_<season>_55deg_albedo.png beside the original).
## Each variant table (tree.gd, obstacle.gd, bush.gd) takes these copies
## on: the albedo swapped, the family "<family>_<season>" (pine_snow,
## oak_autumn, rock_snow, bush_autumn...), everything else the source's.
const SEASONS := ["snow", "autumn"]


## Copies of `entries` for every season a sprite was made in. Entries
## without a family count as `default_family`.
static func derive(entries: Array, default_family: String) -> Array:
	var out := []
	for e in entries:
		for season in SEASONS:
			var path: String = e.albedo.replace("_55deg_albedo.png", "_%s_55deg_albedo.png" % season)
			if not ResourceLoader.exists(path):
				continue
			var d: Dictionary = e.duplicate()
			d.albedo = path
			d.family = "%s_%s" % [e.get("family", default_family), season]
			out.append(d)
	return out

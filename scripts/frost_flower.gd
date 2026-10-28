class_name FrostFlower
extends Node2D

## User request: the frost flower (the user's clematis, its bud turned up) - it
## grows only by the stones on the map, its roots spreading over the ground
## round it in a cold patch (RunView3D draws the flower, the frost and the cold
## mist). The soil of that patch is dug up, with the shovel, as 冷凍土
## (Profile.USABLES "frozen_soil": Player.dig).

## How far from the flower the cold ground reaches (px) - the patch to dig.
const DIG_RADIUS := 32.0
## How many digs the patch gives before it's dug out.
const DIGS := 3
## How many to a map (the campaign's smaller ones fewer), and how far off a
## stone's edge one grows (px).
const PER_MAP := Vector2i(2, 3)
const FROM_ROCK := Vector2(14.0, 22.0)

## Digs left.
var digs := DIGS


func _ready() -> void:
	add_to_group("frost_flowers")


## The patch as it is now (1 full .. 0 dug out): the frost thins as it's dug.
func frost() -> float:
	return float(digs) / float(DIGS)


## Whether `at` (2D) is on the cold ground, near enough to dig.
func reaches(at: Vector2) -> bool:
	return digs > 0 and global_position.distance_to(at) <= DIG_RADIUS


## One dig taken.
func dug() -> void:
	digs = maxi(digs - 1, 0)

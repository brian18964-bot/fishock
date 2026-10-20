extends SceneTree
## Each character's own body, measured off its model standing in Idle
## (user request: the characters' sizes differ - the long arms, the big
## hands, the round bellies - and one way of moving for all of them left
## them reaching into the lamp, the lamp into their bellies). Written to
## assets/sprites/player/<id>/fit.json (CharacterArt.fit()), in the
## character's frame (+z ahead, +x its left, m):
##   grip         where the curled left fingers leave room for the lamp's
##                bail - the middle of the hole the fist makes, in the
##                hand_l bone's frame; grip_axis the hole's way through
##                (index to pinky), grip_room its radius
##   hand_l/r     how far the hand reaches past the wrist; forearm, how thick
##                the forearm is (round it), elbow, round the elbow
##   thigh, calf  how thick the leg is round them
##   shoulder, pelvis, arm, leg   heights and lengths (hips_z: the hips'
##                joint ahead of its feet)
##   front, back, side, side_r   the body's (not the arms') furthest
##                forward, back, out to its left and to its right, per BIN m
##                of height from the ground - standing and walking
##   walk, run    the ground speed the Walk and Run clips' feet keep (m/s)
##
##   godot --headless --path . -s "$PWD/tools/measure_bodies.gd" [-- id ...]
## (the measuring's in measure_bodies_work.gd, loaded once the game's
## autoloads are up)


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	root.add_child(load("res://tools/measure_bodies_work.gd").new())

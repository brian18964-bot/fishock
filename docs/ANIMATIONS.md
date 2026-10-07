# Character animation sources

What the game's characters move with, where it came from and under what
licence, and which clips are kept ready for later.

## In use

| Source | Licence | Where | Used for |
|---|---|---|---|
| KayKit Character Animations 1.1 (Kay Lousberg, kaylousberg.com) | CC0 | `art_src/kaykit/` (Rig_Medium .glb) | the player's sheet: the short (one-handed) cast, waiting, reeling, the fight, the bite, the strike, landing the fish (`tools/render_player.py` via `tools/kaykit.py`) |
| Universal Animation Library 1 & 2, Standard (Quaternius) | CC0 | `art_src/player/ual1_standard.glb` (UAL2 kept out) | the player's skeleton; the camp character's clips (`tools/build_menu_character.py`); the struggle in the big ghost's grip (`tools/render_player_struggle.py`); the big ghost and the water ghost |
| Quaternius animal packs | CC0 | `art_src/critter/`, `art_src/animal/` | the animals and critters |
| Mixamo (Adobe) - Y Bot's Idle, Standard Run, Fishing Cast | Mixamo's terms: free in games, raw files not to be passed on | not in the repo (`MIXAMO_DIR`) | user request: the idle, the run and the long two-handed cast kept as they were (short casts are KayKit's one-handed one) |

The Mixamo clips came from github.com/Kevin-Kwan/Unity3D-FishingRodMotion,
not from mixamo.com; to be clean for a commercial release, download the
same three (Y Bot: Idle, Standard Run, Fishing Cast; FBX, With Skin, 60
fps) with your own Adobe account and keep that record - the sheets render
from them unchanged. Everything else is CC0, and the skeleton the sheets
pose is UAL's. (The water ghost is the user's own zombie model, which came
rigged to Mixamo's skeleton; its motion is UAL2's.)

ActionForge (actionforge.app) serves the same Quaternius UAL1 + UAL2 clips
(84, CC0) with in-browser tools to blend, pose, mirror and export them -
useful for adjusting a UAL clip before it's brought in. Its own site code is
not part of what's downloaded.

## How KayKit's clips reach the characters

`tools/kaykit.py` carries a KayKit clip onto UAL's skeleton with the
character bound: the trunk turned as KayKit's turns, the limbs pointed the
way KayKit's point, mirrored (KayKit casts right-handed; the game's angler
holds the rod in the left hand, cranking with the right), the legs brought
part of the way to straight (KayKit's mannequin is short-legged and deep in
the knees) with the feet kept on the ground. The sheet tools then put the
hands on the rod and the reel (`tools/rod_grip.py`, `tools/reel.py`).

## Kept ready (not in the game yet)

KayKit, Rig_Medium (`art_src/kaykit/`), by file:

| File | Clips worth having | Possible use |
|---|---|---|
| Tools | Chop / Chopping, Dig / Digging, Pickaxe, Saw, Hammer, Lockpick, Work_A-C, Holding_A-C | chopping trees (now a still), carrying the oil drum (Holding), camp chores |
| General | Throw, PickUp, Use_Item, Interact, Hit_A/B, Death_A/B, Spawn_Ground | the 誘惑 fish throw, turning a rock, drinking a potion or using an eye, a beast's pounce, being caught |
| MovementBasic | Walking_A-C, Running_B, Jump_* | walking pace, variety |
| MovementAdvanced | Sneaking, Crouching, Crawling, Dodge_*, Walking_Backwards | sneaking past the big ghost, dodging |
| Simulation | Sit_Floor_*, Sit_Chair_*, Lie_Down / Lie_Idle / Lie_StandUp, Cheering, Waving | the camp (resting by the fire), a legendary catch (Cheering) |
| CombatMelee | Melee_1H_Attack_*, Melee_Block* | the knife and machete parrying a pounce |
| CombatRanged | Ranged_1H_Shoot / Reload / Aiming | the pistol |

UAL1 / UAL2 Standard (also on ActionForge): Swim_Idle_Loop / Swim_Fwd_Loop,
Crouch_Fwd_Loop, Farm_Harvest / PlantSeed / Watering, TreeChopping_Loop,
Walk_Carry_Loop, OverhandThrow, Idle_Lantern_Loop, Idle_TalkingPhone_Loop,
Pistol_*, Sword_*, Roll, Sprint_Loop, Push_Loop, Hit_Knockback, Death01.

## Not usable

- Bandai Namco Research motion data: CC BY-NC-ND (no commercial use).
- SFU motion capture database: research only.
- Mixamo raw files may not be redistributed; downloaded with one's own Adobe
  account they may be used in a game. Not needed now.

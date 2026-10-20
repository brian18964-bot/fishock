"""The Meshy animal people (user request: the user's own models, made in
the dragon's and the new cat's style - tools/build_meshy_character.py
rigs them). Each one's measurements, in Meshy's frame (the model as
exported: its feet toward -z, facing -y, its left +x, about 1.9 tall),
read off its mesh - the trunk on the middle line (y, z), the limbs on its
left side (x, y, z; the right mirrored):

  height      the game's size of it (m, top to toe): its old namesake's
  joints      the skeleton's joints, standing in its A pose
  ears        [[point, ...]]: each ear (horn tuft...) from its root out,
              one bone between each two points - EarTailSway moves them
  tail        its root and what of the mesh is tail (behind y, below z,
              reached from the root over the mesh), how many bones, the
              way it's laid at rest (each bone's angle down from straight
              back, deg; None leaves it as made), how far its skin reaches
  remove      [(centre, radius)]: bits of the generation to take off - a
              loose piece of the mesh lying wholly within `radius` of
              `centre`, pale (the croc's stray white ball on its back)

The sources (the user's ASSET1 release) stay out of the repo.
"""

CHARACTERS = {
    "bear2": dict(
        name="棕熊", meshy="Cozy_Bear_in_Shorts", height=1.60,
        joints=dict(
            pelvis=(0.10, -0.17), spine_01=(0.12, -0.02), spine_02=(0.13, 0.15), spine_03=(0.13, 0.30),
            neck_01=(0.10, 0.48), Head=(0.05, 0.60), head_end=(0.0, 0.85),
            clavicle=(0.04, 0.08, 0.40), upperarm=(0.28, 0.05, 0.40), lowerarm=(0.46, 0.04, 0.19),
            hand=(0.645, 0.02, -0.01), hand_end=(0.80, 0.0, -0.24),
            thigh=(0.14, 0.06, -0.22), calf=(0.23, 0.04, -0.52), foot=(0.27, 0.07, -0.83),
            ball=(0.27, -0.17, -0.93), toe=(0.27, -0.27, -0.945)),
        ears=[[(0.15, 0.03, 0.86), (0.18, 0.03, 0.90), (0.20, 0.03, 0.935)]],
        tail=dict(root=(0.0, 0.26, -0.19), behind=0.27, below=-0.12, bones=2, angles=None, reach=0.05),
    ),
    "dog2": dict(
        name="柴犬", meshy="Cozy_Canine_Gentleman", height=1.69,
        joints=dict(
            pelvis=(-0.05, -0.02), spine_01=(-0.05, 0.12), spine_02=(-0.06, 0.27), spine_03=(-0.07, 0.40),
            neck_01=(-0.06, 0.56), Head=(-0.02, 0.66), head_end=(-0.04, 0.90),
            clavicle=(0.03, -0.04, 0.48), upperarm=(0.20, -0.02, 0.47), lowerarm=(0.37, 0.0, 0.27),
            hand=(0.54, 0.02, 0.06), hand_end=(0.62, 0.0, -0.15),
            thigh=(0.10, 0.0, -0.03), calf=(0.17, -0.07, -0.43), foot=(0.24, 0.02, -0.83),
            ball=(0.25, -0.18, -0.93), toe=(0.26, -0.29, -0.945)),
        ears=[[(0.09, 0.0, 0.92), (0.12, -0.08, 0.905), (0.16, -0.15, 0.88)]],
        tail=dict(root=(0.02, 0.05, 0.14), behind=0.08, below=0.2, bones=6, angles=(40, 25, 10, -5, -20, -30),
                  reach=0.09),
    ),
    "dog3": dict(
        name="牧羊犬", meshy="Sweater_Pup", height=1.69,
        joints=dict(
            pelvis=(-0.04, -0.02), spine_01=(-0.04, 0.12), spine_02=(-0.05, 0.27), spine_03=(-0.06, 0.40),
            neck_01=(-0.05, 0.55), Head=(-0.01, 0.63), head_end=(-0.02, 0.90),
            clavicle=(0.03, -0.05, 0.46), upperarm=(0.19, -0.05, 0.45), lowerarm=(0.34, -0.05, 0.27),
            hand=(0.48, -0.05, 0.06), hand_end=(0.62, -0.08, -0.13),
            thigh=(0.10, -0.04, -0.02), calf=(0.15, -0.08, -0.44), foot=(0.21, 0.0, -0.83),
            ball=(0.22, -0.18, -0.93), toe=(0.22, -0.29, -0.945)),
        ears=[[(0.08, -0.02, 0.93), (0.12, -0.07, 0.91), (0.16, -0.12, 0.88)]],
        tail=dict(root=(0.05, 0.07, 0.12), behind=0.09, below=0.2, bones=6, angles=(40, 25, 10, -5, -20, -30),
                  reach=0.10),
    ),
    "deer2": dict(
        name="紅鹿", meshy="Cozy_Woodland_Gentlem", height=1.97,
        joints=dict(
            pelvis=(0.07, -0.12), spine_01=(0.07, 0.0), spine_02=(0.07, 0.13), spine_03=(0.07, 0.27),
            neck_01=(0.07, 0.42), Head=(0.05, 0.58), head_end=(0.0, 0.80),
            clavicle=(0.03, 0.06, 0.33), upperarm=(0.17, 0.06, 0.32), lowerarm=(0.31, 0.06, 0.14),
            hand=(0.46, 0.05, -0.05), hand_end=(0.57, 0.03, -0.25),
            thigh=(0.09, 0.07, -0.15), calf=(0.14, -0.02, -0.50), foot=(0.19, 0.08, -0.84),
            ball=(0.20, -0.08, -0.93), toe=(0.20, -0.16, -0.945)),
        ears=[[(0.07, 0.02, 0.73), (0.15, 0.02, 0.745), (0.22, 0.01, 0.755)]],
        tail=None,
    ),
    "owl2": dict(
        name="角鴞", meshy="Professor_Hootsworth", height=1.62,
        joints=dict(
            pelvis=(-0.05, -0.08), spine_01=(-0.05, 0.05), spine_02=(-0.06, 0.20), spine_03=(-0.06, 0.35),
            neck_01=(-0.05, 0.52), Head=(-0.04, 0.62), head_end=(-0.04, 0.86),
            clavicle=(0.03, -0.05, 0.46), upperarm=(0.20, -0.05, 0.45), lowerarm=(0.38, -0.05, 0.25),
            hand=(0.565, -0.06, 0.05), hand_end=(0.78, -0.08, -0.17),
            thigh=(0.12, -0.05, -0.12), calf=(0.15, -0.03, -0.50), foot=(0.20, 0.0, -0.84),
            ball=(0.20, -0.20, -0.92), toe=(0.20, -0.38, -0.94)),
        ears=[[(0.09, -0.02, 0.84), (0.14, -0.05, 0.89), (0.18, -0.08, 0.945)]],
        tail=dict(root=(0.0, 0.06, 0.08), behind=0.07, below=0.12, bones=3, angles=None, reach=0.06),
    ),
    "sheep2": dict(
        name="綿羊", meshy="Woolly_Wayfarer", height=1.62,
        joints=dict(
            pelvis=(0.06, -0.12), spine_01=(0.06, 0.0), spine_02=(0.06, 0.14), spine_03=(0.06, 0.29),
            neck_01=(0.05, 0.51), Head=(0.02, 0.66), head_end=(-0.02, 0.92),
            clavicle=(0.03, 0.06, 0.47), upperarm=(0.17, 0.06, 0.47), lowerarm=(0.33, 0.07, 0.26),
            hand=(0.50, 0.03, 0.02), hand_end=(0.60, 0.0, -0.17),
            thigh=(0.10, 0.06, -0.15), calf=(0.14, 0.02, -0.50), foot=(0.20, 0.08, -0.84),
            ball=(0.21, -0.08, -0.93), toe=(0.21, -0.16, -0.945)),
        ears=[[(0.10, 0.05, 0.78), (0.18, 0.05, 0.755), (0.27, 0.05, 0.72)]],
        tail=dict(root=(0.0, 0.19, 0.11), behind=0.21, below=0.2, bones=1, angles=None, reach=0.05),
    ),
    "croc": dict(
        name="鱷魚", meshy="Cozy_Croc_Guy", height=1.65,
        joints=dict(
            pelvis=(-0.37, -0.10), spine_01=(-0.37, 0.05), spine_02=(-0.37, 0.20), spine_03=(-0.38, 0.35),
            neck_01=(-0.36, 0.54), Head=(-0.36, 0.64), head_end=(-0.40, 0.88),
            clavicle=(0.03, -0.40, 0.48), upperarm=(0.19, -0.42, 0.47), lowerarm=(0.36, -0.46, 0.30),
            hand=(0.54, -0.52, 0.10), hand_end=(0.68, -0.60, -0.13),
            thigh=(0.10, -0.42, -0.18), calf=(0.14, -0.45, -0.51), foot=(0.17, -0.38, -0.84),
            ball=(0.17, -0.50, -0.93), toe=(0.17, -0.62, -0.945)),
        ears=[],
        tail=dict(root=(0.0, -0.26, 0.0), behind=-0.22, below=0.06, bones=8,
                  angles=(20, 6, 0, -4, -7, -10, -13, -16), reach=0.10),
        remove=[((-0.012, -0.227, 0.08), 0.09)],
    ),
}

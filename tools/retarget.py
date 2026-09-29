"""Carries a clip from Quaternius' Universal Animation Library 2 (CC0 -
kept out of the repo, like the other source models) over to another
skeleton, for the ghosts' sprite renders.

Each mapped bone gets the source bone's rotation *relative to its parent*,
measured against a reference pose and expressed in world axes:

    D_b(f) = W_p(ref) W_p(f)^-1 W_b(f) W_b(ref)^-1

(W = a bone's world orientation), and the target is posed down its
hierarchy as

    T_b(f) = T_p(f) T_p(rest)^-1 D_b(f)^k T_b(rest)

so the target moves the way the source moves, from its own rest pose. With
ref = the source's rest pose and a target that is T-posed like it (the
Mixamo zombie), that is ordinary retargeting. With ref = the clip's average
pose and a target modelled in some other pose (the big ghost, sculpted
holding its lantern out), it lays the clip's motion - the sway, the lolling
head, the arm swing - over the target's own pose instead. `k` scales the
motion (0 = none, 1 = as is). Bones only rotate; the target keeps its
proportions.

    import retarget
    src = retarget.load_library(path)          # the UAL2 armature
    clip = retarget.Clip(src, "Zombie_Walk_Fwd_Loop", bones, ref="rest")
    retarget.apply(target_arm, clip.delta(t), mapping, strength)
"""
import bpy
from mathutils import Matrix, Quaternion, Vector


def load_library(path):
    """Imports the UAL2 .glb; returns its armature (its mannequin mesh is
    hidden from renders)."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = set(bpy.data.objects) - before
    for o in new:
        if o.type != 'ARMATURE':
            o.hide_render = True
            o.hide_viewport = True
    return next(o for o in new if o.type == 'ARMATURE')


def find(name):
    # The glTF importer names them "<clip>_<armature>".
    for a in bpy.data.actions:
        if a.name.split("|")[-1] in (name, name + "_Armature"):
            return a
    raise SystemExit(f"no action {name!r}")


def _world_rot(arm, pb):
    return (arm.matrix_world @ pb.matrix).to_quaternion()


def _rest_rot(arm, bone):
    return (arm.matrix_world @ bone.matrix_local).to_quaternion()


def _average(qs):
    ref = qs[0]
    acc = Quaternion((0.0, 0.0, 0.0, 0.0))
    for q in qs:
        if q.dot(ref) < 0.0:
            q = -q
        acc = Quaternion([a + b for a, b in zip(acc, q)])
    return acc.normalized()


class Clip:
    """A source clip sampled once: per bone, world orientations over
    `samples` evenly spaced frames of the loop (a one-shot clip is sampled
    start to end inclusive). ref: "rest", "mean" or a frame index."""

    def __init__(self, src_arm, action_name, bones, samples, loop=True, ref="mean"):
        self.action = find(action_name)
        ad = src_arm.animation_data or src_arm.animation_data_create()
        for t in ad.nla_tracks:
            t.mute = True
        ad.action = self.action
        start, end = self.action.frame_range
        n = samples
        self.times = [start + (end - start) * i / (n if loop else max(n - 1, 1)) for i in range(n)]
        self.parent = {}
        for b in bones:
            p = src_arm.data.bones[b].parent
            while p is not None and p.name not in bones:
                p = p.parent
            self.parent[b] = p.name if p is not None else None
        self.rots = []
        self.heads = []
        root = bones[0]
        for t in self.times:
            whole = int(t)
            # Stepping off the frame first: a freshly assigned action isn't
            # evaluated by a frame_set to where the scene already stands.
            bpy.context.scene.frame_set(whole + 1)
            bpy.context.scene.frame_set(whole, subframe=t - whole)
            bpy.context.view_layer.update()
            self.rots.append({b: _world_rot(src_arm, src_arm.pose.bones[b]) for b in bones})
            self.heads.append(src_arm.matrix_world @ src_arm.pose.bones[root].head)
        self.rest_head = src_arm.matrix_world @ src_arm.data.bones[root].head_local
        if ref == "rest":
            self.ref = {b: _rest_rot(src_arm, src_arm.data.bones[b]) for b in bones}
        elif ref == "mean":
            self.ref = {b: _average([r[b] for r in self.rots]) for b in bones}
        else:
            self.ref = dict(self.rots[ref])

    def offset(self, i):
        """How far the first bone (the hips) has moved from its rest place
        at sample i - the bob and sway of a walk (the clips have no root
        motion)."""
        return self.heads[i] - self.rest_head

    def dirs(self, i):
        """{bone: world direction it points} at sample i."""
        return {b: q @ Vector((0.0, 1.0, 0.0)) for b, q in self.rots[i].items()}

    def delta(self, i):
        """{bone: D_b} for sample i."""
        out = {}
        rot = self.rots[i]
        for b, p in self.parent.items():
            d = rot[b] @ self.ref[b].inverted()
            if p is not None:
                d = self.ref[p] @ rot[p].inverted() @ d
            out[b] = d
        return out


def apply(arm, deltas, mapping, strength=1.0, extra=None, aim=None, offset=None):
    """Poses target armature `arm`: mapping is {source bone: target bone};
    `strength` a number or {source bone: number}; `extra` optional
    {target bone: world-axis Quaternion} added on top (a lean).

    aim: {source bone: world direction} - those bones are simply pointed
    the way the source's point (twist left as it comes), for limbs whose
    rest pose differs between the two skeletons (arms down vs a T-pose).
    offset: a world-space shift for the root bone (Clip.offset, scaled)."""
    to_arm = arm.matrix_world.to_quaternion().inverted()
    from_arm = arm.matrix_world.to_quaternion()
    targets = {t: s for s, t in mapping.items()}
    pose = {}      # target bone -> armature-space pose matrix
    rest = {}
    for bone in arm.data.bones:  # parents come before children
        pb = arm.pose.bones[bone.name]
        rest[bone.name] = bone.matrix_local
        parent = bone.parent
        if parent is not None:
            # The parent's motion carries this bone along.
            carry = pose[parent.name] @ rest[parent.name].inverted()
        else:
            carry = Matrix.Identity(4)
        spin = Quaternion()
        s = targets.get(bone.name)
        carried = carry.to_3x3() @ bone.matrix_local.to_3x3()
        if aim and s in aim:
            now = (carried @ Vector((0.0, 1.0, 0.0))).normalized()
            want = (to_arm @ aim[s]).normalized()
            m3 = now.rotation_difference(want).to_matrix() @ carried
        else:
            if s is not None and s in deltas:
                k = strength.get(s, 0.0) if isinstance(strength, dict) else strength
                d = Quaternion().slerp(deltas[s], k)
                spin = to_arm @ d @ from_arm
            if extra and bone.name in extra:
                spin = (to_arm @ extra[bone.name] @ from_arm) @ spin
            # T_b(f) = C D T_b(rest), turning about the bone's (carried) head.
            m3 = carry.to_3x3() @ spin.to_matrix() @ bone.matrix_local.to_3x3()
        r = m3.to_4x4()
        r.translation = (carry @ bone.matrix_local).translation
        if parent is None and offset is not None:
            r.translation += arm.matrix_world.inverted().to_3x3() @ offset
        pose[bone.name] = r
        # matrix_basis from the pose matrix: local rest offset vs parent.
        if parent is not None:
            local_rest = rest[parent.name].inverted() @ bone.matrix_local
            pb.matrix_basis = local_rest.inverted() @ pose[parent.name].inverted() @ r
        else:
            pb.matrix_basis = bone.matrix_local.inverted() @ r
    bpy.context.view_layer.update()

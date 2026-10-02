"""The finch character with a real bird's head (user request: the finch's
plush felt head swapped for a realistic one - the user's owl model, its
head cut off at the shoulders and set on the finch's neck).

  blender -b --python tools/build_finch_bird_head.py -- FINCH.blend BIRD.blend OUT.blend [PREVIEW_PREFIX]

FINCH.blend: the finch in its beginner's clothes (build_finch_beginner.py).
BIRD.blend: the owl (cgtrader Owl.blend: one mesh, sm_1_0_0, facing -y
like the finch, its head at the -y end, top up). Its head is kept - the
part forward of HEAD_Y and above HEAD_Z - the felt head and its eyes are
taken off, the owl's head sized to about the felt one's width, its
shoulders sunk into the jumper's neckline, and given to the head bone
(DEF_head, weight 1) so it turns with it. PREVIEW_PREFIX: front, 3/4 and
face renders (<prefix>_front.png, ...).
"""
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
SRC, BIRD, OUT = args[:3]
PREVIEW = args[3] if len(args) > 3 else ""

# The owl's head in its own file.
HEAD_Y = -0.24
HEAD_Z = 0.24
HEAD_X = 0.16
# On the finch: as wide as this, its lowest point this high (the jumper's
# neckline is at ~0.91), centred over the head bone, a touch forward.
WIDTH = 0.25
BOTTOM = 0.85
FORWARD = -0.035
OFF = ["finch_head", "finch_eye"]


def cut_head(src):
    with bpy.data.libraries.load(src) as (data_from, data_to):
        data_to.objects = ["sm_1_0_0"]
    owl = data_to.objects[0]
    bpy.context.scene.collection.objects.link(owl)
    owl.name = "bird_head"
    owl.modifiers.clear()
    owl.parent = None
    bm = bmesh.new()
    bm.from_mesh(owl.data)
    gone = [v for v in bm.verts if not (v.co.y < HEAD_Y and v.co.z > HEAD_Z and abs(v.co.x) < HEAD_X)]
    bmesh.ops.delete(bm, geom=gone, context="VERTS")
    bm.to_mesh(owl.data)
    bm.free()
    return owl


def place(owl, arm):
    pts = [Vector(v.co) for v in owl.data.vertices]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    k = WIDTH / (hi.x - lo.x)
    bone = arm.data.bones["DEF_head"]
    at = arm.matrix_world @ bone.head_local
    centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for v in owl.data.vertices:
        v.co = (Vector(v.co) - centre) * k + Vector((at.x, at.y + FORWARD, BOTTOM))
    owl.matrix_world = Matrix.Identity(4)
    owl.data.update()


def rig(owl, arm):
    group = owl.vertex_groups.new(name="DEF_head")
    group.add([v.index for v in owl.data.vertices], 1.0, "REPLACE")
    md = owl.modifiers.new("Armature", "ARMATURE")
    md.object = arm
    owl.data.shade_smooth()


def main():
    bpy.ops.wm.open_mainfile(filepath=SRC)
    for name in OFF:
        if name in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    owl = cut_head(BIRD)
    place(owl, arm)
    rig(owl, arm)
    bpy.ops.wm.save_as_mainfile(filepath=OUT, copy=True)
    if PREVIEW:
        sc = bpy.context.scene
        for o in sc.objects:
            for md in o.modifiers:
                if md.type == "PARTICLE_SYSTEM":
                    md.show_render = False
        sc.render.engine = "CYCLES"
        sc.cycles.samples = 32
        # The source's compositor writes renders to its author's own folders.
        sc.use_nodes = False
        for cam, name, res in (("Camera_80mm_body_front", "front", (540, 720)),
                               ("Camera_80mm_body_3/4", "three", (540, 720)),
                               ("Camera_135mm_face_front", "face", (600, 600)),
                               ("Camera_135mm_face_side", "side", (600, 600))):
            sc.camera = bpy.data.objects[cam]
            sc.render.resolution_x, sc.render.resolution_y = res
            sc.render.filepath = "%s_%s.png" % (PREVIEW, name)
            bpy.ops.render.render(write_still=True)


main()

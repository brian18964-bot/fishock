"""Procedural fishing float (bobber), rendered through the same 55deg
albedo + normal pipeline as every other sprite (tools/render_sprite.py).

The asset packs have no float, so it's built here: a ball, red on top and
white underneath, sitting on the water line (z=0), with a thin stick and a
yellow tip. Drawn a little larger than life so it reads on a phone.

  SPRITE_DENSITY=2 python tools/render_bobber.py OUT_DIR
    (SPRITE_DENSITY=2: twice the pixels, same printed cell and offset - the
    committed sheets are rendered this way, see scripts/art.gd)

writes OUT_DIR/bobber_55deg_{albedo,normal}.png and prints its cell size and
sprite offset ((center_x, -center_y) * 27.108).
"""
import json
import os
import sys

import bpy
import bmesh  # noqa: E402  (bpy must load first)

sys.path.insert(0, os.path.dirname(__file__))
import render_splash as splash  # noqa: E402

RED = (0.85, 0.08, 0.06, 1.0)
WHITE = (0.93, 0.93, 0.9, 1.0)
TIP = (0.98, 0.82, 0.15, 1.0)
RADIUS = 0.36
STRETCH = 1.45  # taller than wide, so the 55deg view shows both colours
FLOAT_Z = 0.2  # ball center above the water line
SPLIT = 0.08  # red above this height (relative to the center), white below


def make_bobber():
    red = splash.material("float_red", RED)
    white = splash.material("float_white", WHITE)
    tip = splash.material("float_tip", TIP)

    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=RADIUS, location=(0, 0, FLOAT_Z))
    ball = bpy.context.active_object
    ball.scale.z = STRETCH
    bpy.ops.object.transform_apply(scale=True)
    ball.data.materials.append(red)
    ball.data.materials.append(white)
    bm = bmesh.new()
    bm.from_mesh(ball.data)
    for face in bm.faces:
        face.material_index = 0 if face.calc_center_median().z > FLOAT_Z + SPLIT else 1
    bm.to_mesh(ball.data)
    bm.free()
    bpy.ops.object.shade_smooth()

    top = FLOAT_Z + RADIUS * STRETCH
    stick_len = 0.75
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.055, depth=stick_len,
                                        location=(0, 0, top + stick_len / 2 - 0.05))
    bpy.context.active_object.data.materials.append(white)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=0.1,
                                         location=(0, 0, top + stick_len - 0.05))
    bpy.context.active_object.data.materials.append(tip)
    bpy.ops.object.shade_smooth()
    return 1, lambda i: None


def main():
    out_dir = sys.argv[-1]
    os.makedirs(out_dir, exist_ok=True)
    meta = splash.build("bobber", make_bobber, out_dir)
    print(json.dumps(meta))


if __name__ == "__main__":
    main()

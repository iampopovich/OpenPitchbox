# Blender (headless): per-frame motion stats of CMU clips, to find the useful segments.
# blender -b --python tools/blender/analyze_cmu.py -- <dir> <out.json>
import bpy, sys, json, os

args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], args[1]
BONES = ["root", "pelvis", "foot_l", "foot_r", "ball_l", "ball_r", "hand_l", "hand_r", "Head"]
result = {}
for f in sorted(os.listdir(src)):
    if not f.endswith(".glb"):
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src, f))
    arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    act = arm.animation_data.action
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    sc = bpy.context.scene
    frames = []
    step = 2
    for fr in range(f0, f1 + 1, step):
        sc.frame_set(fr)
        row = {}
        for b in BONES:
            pb = arm.pose.bones.get(b)
            if pb:
                p = arm.matrix_world @ pb.head
                row[b] = [round(p.x, 3), round(p.y, 3), round(p.z, 3)]
        frames.append(row)
    result[f[:-4]] = {"fps": sc.render.fps, "start": f0, "end": f1, "step": step, "frames": frames}
    print("analyzed", f, f0, f1)
json.dump(result, open(out, "w"))

# Blender (headless): merges the armature animations of several CMU glTF clips into one
# small GLB (armature + actions, no meshes or textures).
# blender -b --python tools/blender/merge_cmu.py -- <src_dir> <out.glb> <id> [<id> ...]
import bpy, sys, os

args = sys.argv[sys.argv.index("--") + 1:]
src, out, ids = args[0], args[1], args[2:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
keep = None
for cid in ids:
    path = next(os.path.join(src, f) for f in os.listdir(src) if f.startswith(cid + "-") and f.endswith(".glb"))
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in new if o.type == "ARMATURE")
    act = arm.animation_data.action
    act.name = "cmu_" + cid
    act.use_fake_user = True
    if keep is None:
        keep = arm
        keep.name = "Armature"
        for o in new:
            if o is not arm:
                bpy.data.objects.remove(o, do_unlink=True)
    else:
        for o in new:
            bpy.data.objects.remove(o, do_unlink=True)
    print("merged", cid, act.frame_range[:])
# every action becomes its own track so the exporter writes all of them
keep.animation_data.action = None
for act in bpy.data.actions:
    tr = keep.animation_data.nla_tracks.new()
    tr.name = act.name
    tr.strips.new(act.name, int(act.frame_range[0]), act)
    tr.mute = True
for m in list(bpy.data.meshes):
    bpy.data.meshes.remove(m)
for img in list(bpy.data.images):
    bpy.data.images.remove(img)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animation_mode="NLA_TRACKS",
                          export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=True)
print("written", out, os.path.getsize(out))

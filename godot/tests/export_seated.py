import bpy
from pathlib import Path
r = bpy.data.objects['Armature']
s = bpy.context.scene
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
for o in bpy.context.selected_objects:
    o.select_set(False)
r.select_set(True)
bpy.data.objects['char1'].select_set(True)
bpy.context.view_layer.objects.active = r
r.animation_data.action = None
for t in list(r.animation_data.nla_tracks):
    r.animation_data.nla_tracks.remove(t)
for name in ['Nael_Sit_Down', 'Nael_Seated_Pose', 'Nael_Seated_Idle_Loop', 'Nael_Stand_Up']:
    t = r.animation_data.nla_tracks.new()
    t.name = name
    t.strips.new(name, 1, bpy.data.actions[name])
r.scale = (.1, .1, .1)
s.frame_start = 1
s.frame_end = 181
bpy.ops.export_scene.gltf(filepath=str(Path(__file__).resolve().parents[1] / 'assets/characters/nael_seated.glb'), export_format='GLB', use_selection=True, export_animation_mode='NLA_TRACKS', export_animations=True, export_cameras=False, export_lights=False, export_force_sampling=True)

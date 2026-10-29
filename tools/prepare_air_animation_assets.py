"""Blender batch derivation. Originals are never saved over.

Select complete loose blade islands, retaining UVs, normals and materials from
the supplied Blender sources. Source files are never saved or overwritten.
"""
import bpy, bmesh, json, math
from mathutils import Vector
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
report = {}
def gl(v): return Vector((v.x, v.z, -v.y))
def bl(v): return Vector((v[0], -v[2], v[1]))
def islands(obj):
    adjacent = [[] for _ in obj.data.vertices]
    for e in obj.data.edges:
        a,b=e.vertices; adjacent[a].append(b); adjacent[b].append(a)
    seen=set(); result=[]
    for i in range(len(adjacent)):
        if i in seen: continue
        stack=[i]; seen.add(i); ids=[]
        while stack:
            j=stack.pop(); ids.append(j)
            for k in adjacent[j]:
                if k not in seen: seen.add(k); stack.append(k)
        ps=[gl(obj.matrix_world @ obj.data.vertices[j].co) for j in ids]
        lo=Vector([min(p[k] for p in ps) for k in range(3)])
        hi=Vector([max(p[k] for p in ps) for k in range(3)])
        result.append((ids,lo,hi))
    return result
def extract(obj, ids, name, pivot):
    part=obj.copy(); part.data=obj.data.copy(); bpy.context.collection.objects.link(part)
    part.name=name
    def keep(o, retain):
        bm=bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if (v.index in ids) != retain], context='VERTS')
        bm.to_mesh(o.data); bm.free(); o.data.update()
    keep(part,True); keep(obj,False)
    # Center in world space without changing the visible rest position.
    world_pivot=bl(pivot); local=part.matrix_world.inverted() @ world_pivot
    for v in part.data.vertices: v.co -= local
    part.matrix_world.translation=world_pivot
    return part

for folder,file in [('viperhawk_gunship','viperhawk_gunship'),('ironclad_skyrunner','ironclad_skyrunner'),('ironclad_skycarrier','ironclad_skycarrier')]:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/f'assets/Enemy/air/{folder}/{file}.blend'))
    body=next(o for o in bpy.data.objects if o.type=='MESH')
    parts=[]
    # Recompute indices after each extraction because deletion compacts vertices.
    for side,label in [(-1,'L'),(1,'R')]:
        selected=set()
        for ids,lo,hi in islands(body):
            center=(lo+hi)*.5
            if folder=='viperhawk_gunship':
                match=(len(ids)<=30 and side*center.x>.24 and lo.y>.018 and lo.z>-.125 and hi.z<.08)
                pivot=(side*.3475,.035,-.024)
            elif folder=='ironclad_skyrunner':
                match=(len(ids)<=80 and side*center.x>.20 and side*center.x<.30 and lo.z>-.196 and hi.z<-.16)
                pivot=(side*.249,-.03247,-.179)
            else:
                # This export has intake grilles, no distinct propeller blade islands.
                # Do not cut nacelles or invent spinning body geometry.
                match=False
                pivot=(side*.2175,-.053,-.29)
            if match: selected.update(ids)
        if selected:
            part=extract(body,selected,'Fan_'+label if folder=='viperhawk_gunship' else 'Propeller_'+label,pivot)
            parts.append({'name':part.name,'vertices':len(selected),'pivot':pivot})
    if parts:
        target=ROOT/f'assets/Enemy/air/{folder}/{file}_animated.glb'
        bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',export_animations=False,export_yup=True)
    elif folder=='ironclad_skycarrier':
        # The supplied intake is fused to each nacelle. Author a small four-blade
        # rotor within its opening instead of cutting/rotating the nacelle.
        material=bpy.data.materials.new('AuthoredPropellerSteel')
        material.diffuse_color=(.065,.078,.09,1)
        material.use_nodes=True
        bsdf=material.node_tree.nodes.get('Principled BSDF')
        bsdf.inputs['Base Color'].default_value=(.065,.078,.09,1)
        bsdf.inputs['Roughness'].default_value=.82
        for side,label in [(-1,'L'),(1,'R')]:
            pivot=(side*.2175,-.053,-.294)
            verts=[]; faces=[]
            for i in range(4):
                angle=i*math.pi/2
                for radius,width,depth in [(.007,-.003,0),(.035,-.004,-.001),(.033,.006,.001),(.008,.003,.001)]:
                    x=radius*math.cos(angle)-width*math.sin(angle)
                    y=radius*math.sin(angle)+width*math.cos(angle)
                    verts.append(tuple(bl((x,y,depth))))
                faces.append(tuple(range(i*4,i*4+4)))
                faces.append(tuple(reversed(range(i*4,i*4+4))))
            mesh=bpy.data.meshes.new('PropellerBlades_'+label); mesh.from_pydata(verts,[],faces)
            obj=bpy.data.objects.new('Propeller_'+label,mesh); bpy.context.collection.objects.link(obj)
            obj.location=bl(pivot); mesh.materials.append(material)
            parts.append({'name':obj.name,'authored':True,'pivot':pivot})
        bpy.ops.export_scene.gltf(filepath=str(ROOT/f'assets/Enemy/air/{folder}/{file}_animated.glb'),export_format='GLB',export_animations=False,export_yup=True)
    report[folder]=parts

for folder,stem in [('iron_viper_gunship','iron_viper'),('crimson_desert_gunship','crimson_desert'),('desert_rotorblade_miniature','desert_rotorblade')]:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/f'assets/Enemy/air/{folder}/{folder}.blend'))
    fixed=[]
    for obj in list(bpy.data.objects):
        if obj.type!='MESH' or obj.name=='Fuselage': continue
        selected=set()
        for ids,lo,hi in islands(obj):
            size=hi-lo
            if 'Tail' in obj.name:
                match=(folder=='crimson_desert_gunship' and len(ids)==38) or (folder=='iron_viper_gunship' and len(ids)==56)
            else:
                match=size.x<.065 and size.z<.065 and size.y>.025
                if folder=='crimson_desert_gunship': match=len(ids)==153
            if match: selected.update(ids)
        if selected:
            part=extract(obj,selected,'Fixed_'+obj.name,(0,0,0))
            part.parent=None
            fixed.append({'name':part.name,'vertices':len(selected)})
        if folder=='crimson_desert_gunship' and obj.name=='Main_Rotor':
            # Hub bounds identify the actual shaft; preserve all world-space
            # vertices while correcting the old bounding-box-centered pivot.
            old=obj.matrix_world.copy()
            new_pivot=bl((-.01416,.1074585,.1066895))
            delta=old.inverted() @ new_pivot
            for v in obj.data.vertices: v.co -= delta
            obj.matrix_world.translation=new_pivot
    bpy.ops.export_scene.gltf(filepath=str(ROOT/f'assets/Enemy/air/{folder}/{stem}_flight.glb'),export_format='GLB',export_animations=False,export_yup=True)
    report[folder]=fixed
(ROOT/'artifacts/air-model-review/derived-parts.json').write_text(json.dumps(report,indent=2))
print('AIR_DERIVED_PARTS',json.dumps(report))

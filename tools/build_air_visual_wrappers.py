"""Author production wrappers with source-space sockets and explicit animation."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DEFS=[
('iron_viper','iron_viper_gunship/iron_viper_flight',10.5,1,[('Cannon',(0,-.104,-.307))],True),
('crimson_desert','crimson_desert_gunship/crimson_desert_flight',9.5,1,
 [(f'Rocket_{side}{i}',(x,y,.067)) for i,(dx,y) in enumerate([(0,-.048),(.026,-.048),(0,-.074),(.026,-.074)]) for side,x in [('L',-.232+dx),('R',.166+dx)]],True),
('desert_rotorblade_boss','desert_rotorblade_miniature/desert_rotorblade_flight',12.5,1.6,
 [('Barrage_L',(-.167,-.092,-.148)),('Barrage_R',(.166,-.092,-.149))],True),
('crimson_skyblade','crimson_skyblade/crimson_skyblade',6.2,.8,
 [('Cannon_L',(-.074,-.068,-.201)),('Cannon_R',(.075,-.068,-.201)),('Exhaust_L',(-.05,-.055,.462)),('Exhaust_R',(.05,-.055,.462))],False),
('astra_viper','astra_viper/astra_viper',6.8,1,
 [('Cannon_L',(-.074,-.068,-.18)),('Cannon_R',(.074,-.068,-.18)),('Exhaust',(0,-.052,.471))],False),
('ironclad_skyrunner','ironclad_skyrunner/ironclad_skyrunner_animated',6.2,.8,
 [('Cannon_L',(-.053,-.092,-.303)),('Cannon_R',(.053,-.092,-.303))],True),
('ironclad_skycarrier','ironclad_skycarrier/ironclad_skycarrier_animated',8.5,1.2,[('BombDrop',(0,-.145,-.06))],True),
('viperhawk_gunship','viperhawk_gunship/viperhawk_gunship_animated',7,1,
 [('Pod_L',(-.163,-.051,-.294)),('Pod_R',(.163,-.051,-.294)),('MineDrop',(0,-.132,.04))],True),
]
def vec(p):return 'Vector3('+', '.join(str(x) for x in p)+')'
for name,model,s,y,sockets,rotors in DEFS:
    weapons=[n for n,p in sockets if not n.startswith('Exhaust') and n!='MineDrop']
    text='[gd_scene format=3]\n\n'
    text+=f'[ext_resource type="PackedScene" path="res://assets/Enemy/air/{model}.glb" id="1"]\n'
    text+='[ext_resource type="Script" path="res://src/enemies/air/air_visual_rig.gd" id="2"]\n'
    if rotors:text+='[ext_resource type="Script" path="res://src/enemies/air/helicopter_rotor_controller.gd" id="3"]\n'
    text+='\n[sub_resource type="StandardMaterial3D" id="CueMaterial"]\nshading_mode = 0\nalbedo_color = Color(1, 0.4, 0.08, 1)\nemission_enabled = true\nemission = Color(1, 0.25, 0.04, 1)\n'
    text+='\n[sub_resource type="SphereMesh" id="CueMesh"]\nmaterial = SubResource("CueMaterial")\nradius = 0.10\nheight = 0.20\nradial_segments = 8\nrings = 4\n'
    if name=='viperhawk_gunship':
        text+='\n[sub_resource type="StandardMaterial3D" id="MissileMaterial"]\nalbedo_color = Color(0.15, 0.8, 0.95, 1)\nroughness = 0.8\n\n[sub_resource type="BoxMesh" id="MissileCueMesh"]\nmaterial = SubResource("MissileMaterial")\nsize = Vector3(0.4, 0.08, 0.7)\n'
    if any(n.startswith('Exhaust') for n,p in sockets):
        text+='\n[sub_resource type="StandardMaterial3D" id="ExhaustMaterial"]\nshading_mode = 0\nalbedo_color = Color(0.3, 0.65, 1, 1)\nemission_enabled = true\nemission = Color(0.2, 0.5, 1, 1)\n\n[sub_resource type="SphereMesh" id="ExhaustMesh"]\nmaterial = SubResource("ExhaustMaterial")\nradius = 0.012\nheight = 0.024\nradial_segments = 8\nrings = 4\n'
    text+='\n[node name="Visuals" type="Node3D"]\nscript = ExtResource("2")\n'
    text+='weapon_sockets = Array[NodePath](['+', '.join('NodePath("CosmeticOffset/Sockets/'+n+'")' for n in weapons)+'])\n'
    text+='\n[node name="CosmeticOffset" type="Node3D" parent="."]\n'
    text+=f'\n[node name="Model" parent="CosmeticOffset" instance=ExtResource("1")]\nposition = Vector3(0, {y}, 0)\nscale = Vector3({s}, {s}, {s})\n'
    text+=f'\n[node name="Sockets" type="Node3D" parent="CosmeticOffset"]\nposition = Vector3(0, {y}, 0)\nscale = Vector3({s}, {s}, {s})\n'
    for n,p in sockets:
        text+=f'\n[node name="{n}" type="Marker3D" parent="CosmeticOffset/Sockets"]\nposition = {vec(p)}\n'
        if n.startswith('Exhaust'):
            text+=f'\n[node name="Glow" type="MeshInstance3D" parent="CosmeticOffset/Sockets/{n}"]\nposition = Vector3(0, 0, 0.008)\nscale = Vector3(1, 1, 2.2)\nmesh = SubResource("ExhaustMesh")\ncast_shadow = 0\n'
    text+=f'\n[node name="StateCue" type="MeshInstance3D" parent="CosmeticOffset"]\nposition = Vector3(0, {y+.4}, -0.8)\nmesh = SubResource("CueMesh")\ncast_shadow = 0\nvisible = false\n'
    if name=='viperhawk_gunship':
        text+='\n[node name="MineCue" type="MeshInstance3D" parent="CosmeticOffset"]\nposition = Vector3(0, 0.15, 0.28)\nmesh = SubResource("CueMesh")\ncast_shadow = 0\n\n[node name="MissileCue" type="Node3D" parent="CosmeticOffset"]\n'
        for side in [-1,1]:text+=f'\n[node name="PodStripe{side}" type="MeshInstance3D" parent="CosmeticOffset/MissileCue"]\nposition = Vector3({side*1.14}, 0.66, -1)\nmesh = SubResource("MissileCueMesh")\n'
    if rotors:
        text+='\n[node name="RotorController" type="Node" parent="."]\nscript = ExtResource("3")\n'
        if name in ['viperhawk_gunship','ironclad_skyrunner','ironclad_skycarrier']:
            part='Fan' if name=='viperhawk_gunship' else 'Propeller'
            text+='extra_rotor_paths = Array[NodePath](['+', '.join(f'NodePath("CosmeticOffset/Model/{part}_{side}")' for side in ['L','R'])+'])\n'
            text+='extra_rotor_axis = '+vec((0,1,0) if part=='Fan' else (0,0,1))+'\n'
    (ROOT/f'scenes/enemies/air/{name}_visuals.tscn').write_text(text,encoding='utf-8')
print('Authored eight production wrappers')

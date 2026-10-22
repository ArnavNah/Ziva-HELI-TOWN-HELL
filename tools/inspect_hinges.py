import bpy
import bmesh
from mathutils import Vector

def inspect_hinges():
    # Raptor
    bpy.ops.wm.open_mainfile(filepath=r"assets/Enemy/new ground/Raptor_Raider/Raptor_Raider_Separated.blend")
    turret = bpy.data.objects.get("Gun_Turret")
    # In Raptor, what parts are the fixed pedestal vs the rotating turret vs the gun?
    # Let's inspect the islands around Z=0.06 to 0.12
    bm = bmesh.new()
    bm.from_mesh(turret.data)
    # Print distinct parts
    print("=== RAPTOR GUN TURRET COMPONENT BREAKDOWN ===")
    # Island 6: base ring (Z from 0 to 0.0688)
    # What are the other islands?
    # Let's group islands into:
    # 1. Base pedestal (Z <= 0.07)
    # 2. Turret body (cab/housing that rotates on pedestal)
    # 3. Elevating gun / barrels
    
inspect_hinges()

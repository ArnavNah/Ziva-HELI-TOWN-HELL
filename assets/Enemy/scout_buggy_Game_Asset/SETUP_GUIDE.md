# Desert Recon Buggy - Game Integration Guide

## Folder Location
Copy the **`Buggy_Game_Asset`** folder directly into your game project (e.g. `res://assets/buggy/` in Godot).

---

## Contents
* **`Desert_Recon_Buggy_Body.glb`**: Main vehicle body with front windshield & side door black tactical glass.
* **`Desert_Recon_Buggy_Wheel.glb`**: Wheel model with pivot centered at `(0, 0, 0)`.
* **`Desert_Recon_Buggy_Turret.glb`**: Heavy machine gun turret with pivot centered at `(0, 0, 0)` at the traverse base ring.
* **`Desert_Recon_Buggy_Glass.glb`**: Standalone glass mesh (for destructible windows or custom shaders).
* **`textures/`**: Backup 2048x2048 PBR maps (`polished_albedo.png`, `polished_orm.png`, `polished_normal.png`). *(Note: all textures are already embedded directly inside each .glb file).*

---

## Godot 4 Vehicle Setup

```text
VehicleBody3D (or CharacterBody3D)
├── BodyMesh (Instance of Desert_Recon_Buggy_Body.glb)
│
├── TurretMount (Node3D)  [Position: (0.0396, 0.1433, 0.1492)]
│   └── TurretMesh (Instance of Desert_Recon_Buggy_Turret.glb)
│       # Rotate TurretMount.rotation.y to traverse / aim 360°
│
├── Wheel_FrontLeft (VehicleWheel3D)   [Position: (-0.224, -0.170,  0.334)]
│   └── WheelMesh (Instance of Desert_Recon_Buggy_Wheel.glb)
│
├── Wheel_FrontRight (VehicleWheel3D)  [Position: ( 0.224, -0.170,  0.334)]
│   └── WheelMesh (Instance of Desert_Recon_Buggy_Wheel.glb)
│
├── Wheel_RearLeft (VehicleWheel3D)    [Position: (-0.224, -0.170, -0.219)]
│   └── WheelMesh (Instance of Desert_Recon_Buggy_Wheel.glb)
│
└── Wheel_RearRight (VehicleWheel3D)   [Position: ( 0.224, -0.170, -0.219)]
    └── WheelMesh (Instance of Desert_Recon_Buggy_Wheel.glb)
```

*(If you scale the vehicle by e.g. 4.0 to make it full human-sized 3.8m, simply multiply the wheel and turret positions by 4.0).*

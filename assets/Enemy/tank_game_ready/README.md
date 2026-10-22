# Tank Game Asset (Game Ready)

This folder contains the complete, cleaned game assets for the armored vehicle.
All wheels have been completely removed, AI gloss/shine has been eliminated with delighted matte PBR textures, and the turret is split with a centered pivot for in-game animation.

---

## Files Included

### 3D Models
- **`tank_hull.glb` / `tank_hull.fbx` / `tank_hull.blend`**:
  - The tank body without wheels or turret.
  - Contains a socket/empty named **`TurretMount`** located at `(-0.009, 0.0007, 0.1179)`.
- **`tank_turret.glb` / `tank_turret.fbx` / `tank_turret.blend`**:
  - The turret assembly (body, cannon, mantlet, hatch, optics).
  - **Local Origin `(0, 0, 0)`** is positioned at the base ring's yaw rotation axis.
- **`tank_assembled.glb` / `tank_assembled.fbx` / `tank_assembled.blend`**:
  - Pre-assembled version with `Tank_Turret` parented to `TurretMount`.

### Textures (`textures/`)
- `tank_base_color.png` – 2048x2048 diffuse/albedo (delighted matte camouflage).
- `tank_metallic_roughness.png` – 2048x2048 ORM map (Red = AO, Green = Roughness 0.95, Blue = Metallic 0.0).
- `tank_normal.png` – 2048x2048 normal map (smoothed panel lines, zero AI surface lumpiness).

---

## Game Engine Setup Guide

### Godot Engine (4.x)
1. Drag the entire `tank_game_ready` folder into your Godot project `res://` directory.
2. In your scene:
   - Add `tank_hull.glb` (or create a Node3D with the hull).
   - Find the `TurretMount` node under `Tank_Hull`.
   - Add `tank_turret.glb` as a child of `TurretMount`, and set its `transform.origin = Vector3.ZERO`.
3. To rotate/aim the turret in GDScript:
   ```gdscript
   @onready var turret = $Tank_Hull/TurretMount/Tank_Turret
   
   func _process(delta):
       # Yaw rotation (aiming left/right)
       turret.rotate_y(deg_to_rad(30.0) * delta)
   ```

### Unity
1. Drag the `tank_game_ready` folder into your `Assets/` directory.
2. Place `tank_hull` into your scene hierarchy.
3. Drag `tank_turret` onto `TurretMount` as a child and reset its Local Position to `(0, 0, 0)`.
4. In your C# script:
   ```csharp
   public Transform turretTransform;
   
   void Update() {
       // Aim turret around vertical axis
       turretTransform.Rotate(Vector3.up, 30.0f * Time.deltaTime);
   }
   ```

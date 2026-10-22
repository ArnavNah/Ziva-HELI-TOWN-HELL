# Integrate the modular Scout Buggy model into ZIVA

Work in the existing Godot project:
`C:/Users/Prime 3/Documents/ziva-heli-town-helll`

Replace only the `scout_buggy` enemy's procedural visual model with the user's supplied vehicle body, separate wheel mesh, and separate machine-gun turret. Animate the wheels and turret in Godot. This is a visual integration task that preserves the working enemy gameplay.

## 1. Identify the model and inspect the actual files

The reference images show a short military off-road buggy with a roll cage, olive/sand camouflage, red enemy markings, a separate tire, and a separate pedestal machine gun. Use this for **Scout Buggy**, not Rocket Buggy or Raider Technical. A technical is a longer pickup with a rear gun bed; this reference fits the lighter Scout Buggy role better.

The user now wants animated wheels on this wheeled buggy. The earlier request for enclosed, non-animated tank running gear applies to the tanks only.

Read project instructions and recheck the current source before editing. Other tasks may be editing this project. Preserve unrelated changes. Relevant current files:

- `src/enemies/enemy_data.gd`: Scout Buggy specifications and wave scaling.
- `src/enemies/enemy_spawner.gd`: creates `ProceduralRaider`, collider and DamageReceiver; routes Scout Buggy visuals through `RaiderVisuals.build()`.
- `src/enemies/raider_visuals.gd`: existing `scout_buggy` chassis, four procedural wheels, and direct enemy child named `Turret`.
- `src/enemies/procedural_raider.gd`: ground movement, predictive aiming, warnings, projectile creation and weapon selection.
- `src/enemies/base_enemy.gd`: movement/avoidance, turret tracking, modifiers, death, attack permissions and wave stat application.
- `autoload/shader_manager.gd`: selective outlines.

The user has now supplied the actual files in `res://assets/Enemy/scout_buggy_Game_Asset/`:

- `Desert_Recon_Buggy_Body.glb`
- `Desert_Recon_Buggy_Tire.glb`
- `Desert_Recon_Buggy_Turret.glb`
- `textures/` and `SETUP_GUIDE.md`

All new user-supplied enemy models belong under `assets/Enemy/`; preserve the capital E. The setup guide uses the old name `Desert_Recon_Buggy_Wheel.glb`, but the actual file is `Desert_Recon_Buggy_Tire.glb`. Glass is already a second mesh inside Body.glb; no separate Glass.glb is present. Treat the guide's mounting positions as unverified starting references, not final coordinates after scaling and orientation corrections.

Initial GLB metadata inspection found: body 6,948 triangles across two meshes/two materials; tire 10,340 triangles in one mesh; turret 1,036 triangles in one mesh. Four unmodified tires plus body and turret total approximately 49,344 triangles per vehicle before outlines. The tire needs particular attention for this low-poly game: evaluate a reduced derived mesh, roughly 500–1,000 triangles per tire as a starting target, preserving its silhouette and UVs. Report measured results rather than claiming the source is already optimized.

Source bounds also reveal inconsistent part scale: body length is about 0.953 source units, while the unmounted tire diameter is about 0.955 units. They cannot simply be instanced at equal scale. The tire's thin dimension is local Z, so inspect and correct its axle orientation before binding local-X spin pivots. The turret is a single mesh with its lowest Y at zero; this does not prove the pivot is centered horizontally or that the barrel has a separate elevation joint. None of the three GLBs contains animation clips. Textures are embedded in the GLBs, with additional PNGs supplied alongside them.

These are file-metadata findings, not a completed in-editor rig or pivot/UV quality approval. Recheck the current Godot AI editor connection, import the real assets, inspect them visually, and validate the assembly.

Inspect and record each supplied part's mesh names, transforms, bounds, triangle count, materials, textures, orientation and origin. Check for duplicate geometry, baked-in wheels or gun, holes left by separation, hidden leftovers, floating fragments and reversed normals. Screenshots alone cannot verify these. Fix small verified defects without changing the design; preserve original source files.

## 2. Assemble the vehicle at the existing gameplay scale

Keep the CharacterBody3D as the enemy physics root. Use a reusable visual scene or visual component. Retain supplied source assets in `assets/Enemy/scout_buggy_Game_Asset/`; do not relocate them into a differently capitalized enemy folder. Keep original imports separate from the assembled `.tscn` and animation controller.

Use Godot's existing vehicle convention: +Y up, -Z forward, +X right. Correct each imported part's orientation with an intermediate transform node if necessary. First normalize the demonstrably inconsistent tire export scale to fit the actual wheel wells, recording the correction and measured radius. Then apply a consistent assembled-vehicle scale. Do not apply one blanket scale to these mismatched raw exports or use undocumented arbitrary scales to hide bad pivot placement.

The current Scout Buggy gameplay collider is approximately 2.5 m wide × 2.0 m high × 3.5 m long, with its bottom at the enemy root's ground plane. Its current procedural visual chassis is about 4 m long and wheel radius is about 0.6 m. These are baseline references, not measurements of the new asset. Match the existing camera/road scale; inspect complete assembled bounds and adjust visual scale, pivot offsets and wheel radius together. Avoid silently expanding the enemy's collision footprint. Report any necessary collider adjustment and why it is needed.

Use four instances of the wheel mesh, sharing mesh/material resources where possible. Place them at the real axle centers and fit the existing fenders. Left/right names are from the driver's viewpoint. Do not use a negative scale to mirror a wheel; orient its mesh with a proper rotation and verify the outer hub faces outward. Recessed wheel wells and suspension parts should remain stationary on the body.

Ground contact should occur at the tire bottoms. Preserve useful collider shape simplicity; do not add wheel rigid bodies, VehicleBody3D physics, four extra collision bodies or detailed mesh collision for cosmetic animation.

Recommended assembly, adapted to the actual file structure:

```text
ScoutBuggy (existing CharacterBody3D / ProceduralRaider)
├── CollisionShape3D
├── DamageReceiver
├── Visuals
│   ├── BodyModel
│   └── Wheels
│       ├── FrontLeftSteer
│       │   └── FrontLeftSpin
│       │       └── WheelModel
│       ├── FrontRightSteer
│       │   └── FrontRightSpin
│       │       └── WheelModel
│       ├── RearLeftSpin
│       │   └── WheelModel
│       └── RearRightSpin
│           └── WheelModel
└── Turret (direct child; vertical yaw pivot at the mount center)
    ├── MountModel (stationary in elevation, if separable)
    └── GunPitch (horizontal elevation pivot at the gun trunnion)
        └── Recoil (optional, gun only)
            ├── GunModel
            └── Muzzle (Marker3D at the barrel tip)
```

This is a proposed hierarchy, not a statement that these nodes already exist. Ensure a visual component can bind to this tree without becoming a second physics or weapon controller.

## Shared-wheel preference — updated 20 October 2026

The user wants one universal wheel mesh/material shared across wheeled enemy models. Use the supplied `assets/Enemy/tank_game_ready/Tank_Tire_Reduced.glb` as the initial candidate, behind a reusable shared-wheel scene/resource wrapper. Fit it to the Scout Buggy using per-instance mount, orientation and radius/width configuration; keep the original Scout Buggy tire as a reference/source asset rather than generating another unique runtime wheel mesh for this vehicle. Existing inspection of the original tire's scale and triangle count above remains historical context, not an instruction to prefer it over the shared wheel.

Each of the four wheel positions still needs a separate animated transform, but all should reference the same Mesh, textures and Material resources. Avoid making those resources unique or duplicating their geometry per vehicle. Keep original user files. Reuse saves resource memory; it does not eliminate per-wheel drawing, triangles or animation costs. See `docs/IMPLEMENT_ASSAULT_APC_MODEL_PROMPT.md` for the shared-wheel assembly requirements.

## 3. Animate wheels from actual movement

Use cosmetic transform animation; no skeleton is required for separate rigid meshes.

- Wheel spin pivots must pass through the center of each wheel axle. Put any mesh-origin correction below the spin pivot so the wheel rotates in place rather than orbiting around the car.
- Normalize each spin pivot so its local X axis is the axle, and verify the correct spin sign visually after wheel mesh orientation corrections.
- Drive rotation from signed actual planar displacement projected onto the vehicle's forward direction: `angle_delta = signed_distance / wheel_radius`. Use the measured radius in game units, not a guessed source-unit value.
- Reverse movement reverses spin. A stationary or wall-blocked vehicle must not keep spinning because it is commanded to move. Ignore vertical motion, respawns and teleport-sized displacements. Reset previous-position samples after spawning or teleporting.
- Smoothly steer the two front pivots around local Y using actual movement direction/turning. Clamp to a reasonable cosmetic angle, for example 20–30 degrees; these are visual steering limits, not new movement constraints. Keep the rear wheels unsteered and return front steering toward center when appropriate.
- Update after the enemy's movement for that physics tick, or explicitly coordinate the visual update order so samples are consistent. Respect pause, death and scene removal. Do not add whole-chassis spinning, independent suspension physics or constant-speed idle wheel animation.

## 4. Aim the turret without rotating the buggy body

The current `BaseEnemy.track_turret()` rotates the whole supplied node in 3D using `global_rotate()`. It does not already provide separate yaw and pitch pivots. Simply adding GunPitch below a yawing Turret will not make it work automatically.

For the imported Scout Buggy, implement yaw at the vertical mount center and pitch at the gun elevation hinge. Convert aim direction into the appropriate parent/local space, so the gun still tracks correctly while the chassis is turning. Use smooth bounded turns, preserve the existing predictive target calculation, and keep firing dependent on alignment and line of sight. Retain the current warning timing and aim commitment behavior.

Inspect the supplied turret mesh before promising independent elevation: the image appears to include the pedestal/base, receiver, barrel and ammunition box in one assembly. Separating the whole turret from the vehicle enables independent aiming but does not prove its internal gun elevation joint is separated.

If mesh data permits, separate the rotating mount from the elevating gun in a derived source/export, preserving UVs and materials. Keep the mount upright while the receiver/barrel and appropriate attached parts pitch around their real hinge. Do not duplicate the full turret at both pivots, tilt the entire pedestal as a gun barrel, or claim articulation that the mesh cannot support. If source geometry cannot be safely separated with the available tools, document that limitation and deliver a clearly identified yaw-only fallback rather than silently faking a working elevation joint. Preserve gameplay permissions and report any visual aiming mismatch in that fallback.

The proposed current firing elevation range is about -15 to +75 degrees, but the existing helper's comments are stricter than its implementation. Add explicit limits for the imported rig and verify them; do not assume existing comments enforce the limits. Do not alter other enemy rigs unnecessarily. A narrow Scout Buggy visual-aiming hook is preferable to changing every enemy's shared turret behavior.

Check turret clearance against the roof, roll cage, ammo box and rear cargo. Mount it on the actual mounting surface, not at the source gun object's arbitrary origin. Do not allow the barrel to aim through the cabin. Choose realistic traverse limits if the supplied geometry cannot safely rotate through 360 degrees, and make the enemy reposition when needed rather than firing through its own vehicle.

Optional recoil should move only the appropriate gun parts slightly along the barrel axis, then return to their bind position. Do not recoil the whole car or pedestal.

## 5. Fire from the visible barrel tip

Currently `ProceduralRaider` uses `turret.global_position` as its muzzle origin for targeting, warnings, LOS and projectile spawn. That is the mount pivot, not the imported barrel's tip.

Add a shared muzzle-origin resolver for this visual rig and use it consistently for predictive aiming, warning-line placement, line-of-sight tests, muzzle flash and projectile spawn. Keep the old origin fallback for variants without a named muzzle. Resolve from the actual runtime rig; do not scatter hard-coded offsets through the weapon logic.

Place `Muzzle` at the real tip with local -Z pointing out of the barrel. Preserve the weapon's predicted/committed aim direction, projectile speed, damage, spread, burst count, cooldown and collision masks. In particular, replacing visuals must not turn the Scout Buggy's machine gun into the Raider Technical's weapon. Confirm projectiles leave the gun cleanly and do not originate inside the cabin, roof or mount.

## 6. Connect it to the existing spawner and modifiers

Replace procedural visuals for `scout_buggy` only. Do not leave the old wheels, chassis or gun underneath the imported model. Avoid adding two nodes called Turret or two DamageReceivers. Preserve a safe procedural fallback if the visual scene is unavailable and report fallback use clearly.

Keep the direct-child `Turret` interface or update all relevant access points together. Instantiate the rig before BaseEnemy ready-time visual/modifier binding. Check node ownership and initialization order for spawned and standalone preview instances.

Preserve Scout Buggy's existing wave gate, per-type cap, hull, speed, rewards, machine-gun behavior, wave scaling, pursuit, road navigation, obstacle avoidance, spawn clearance, attack permissions and death handling. The current baseline data is wave 1, cap 5, 38 hull, speed 18, score 90 and XP 3; re-read the data in case it has changed.

Check the ELITE modifier carefully: BaseEnemy currently scales Visuals by 1.2 and separately scales/repositions the direct-child Turret. Ensure the body, four wheels, muzzle and turret stay aligned, scale exactly once and match the collider. Avoid moving the new turret beneath Visuals without adapting that behavior.

Reuse supplied UVs/textures. Preserve the olive/sand/red design, dark rubber and readable weapon silhouette. Inspect texture filtering, roughness, normal maps and transparency in the actual GL Compatibility renderer. Avoid noisy over-shiny materials or changing the world color grade to compensate for this asset. Keep shared materials where practical and preserve enemy outlines/culling without baking the turret or wheels into an unarticulated combined mesh.

## 7. Verify and show the result

Use the real Scout Buggy spawn path and the production flight camera, not only a static asset preview. Exercise normal and ELITE variants.

Verify: four correctly mounted tires; wheels rotate around their axles; forward/reverse signs are correct; stopping and pushing against a wall stop wheel spin; front wheels steer without rotating the hubs around the body; turret aims independently while driving/turning; pedestal stays upright; gun elevates only if the mesh supports it; shots and warning lines start at the barrel tip; no roof/roll-cage intersection; no duplicate procedural meshes; no purple/missing textures; pause/death/teleport cleanup; unchanged combat and spawn behavior.

Run appropriate existing enemy checks, especially `tests/verify_enemy_pursuit.gd` and `tests/test_enemy_combat_intelligence.gd`, after reading their current assumptions. Add focused coverage for the new rig only where it catches real animation, integration or muzzle-origin regressions. Verify the assembled model with a rendered drive/aim/fire demonstration; headless checks alone cannot approve visual alignment.

Deliver the saved reusable rig, its controller/configuration, the narrow spawner/aim/muzzle integration, original asset backups, screenshots or a short demonstration of driving and firing, and a concise report of file changes, scale/pivot decisions, actual mesh/material counts and any remaining asset defects. Clearly distinguish inspection, implementation and verified results. Do not mark missing-model or yaw-only work as a fully articulated completed import.

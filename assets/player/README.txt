PLAYER - optimized Apache helicopter

QUICK IMPORT
Import player.glb into your game project. It contains the assembled helicopter with embedded textures and these separate nodes:
  Player
    Helicopter_Body
    Main_Rotor
    Tail_Rotor

The model has 67,820 triangles in total:
  Body: 54,476
  Main rotor: 9,060
  Tail rotor: 4,284

ROTOR ANIMATION
For player.glb, rotate Main_Rotor around its local Y axis and Tail_Rotor around its local Z axis. Their origins are centered on the spin axes, and their mounting positions are already set. The helicopter faces -X; rotate the Player parent to match your game's forward direction if needed.

BLENDER SOURCE FILES
apache_game_lowpoly.blend contains the body.
apache_rotors_lowpoly.blend contains both rotors.
To assemble these in Blender, open the body file, then append Collection > Apache_Rotors_LowPoly from the rotor file. Keep the saved object transforms. In the Blender source files, the main rotor spins around local Z and the tail rotor around local Y.

TEXTURES
The GLB embeds its textures, and both Blender files contain packed textures.
Separate 4096 x 4096 PNGs are also included in textures_lowpoly:
  apache_basecolor.png - sRGB base color
  apache_orm.png - Non-Color; R = AO, G = roughness, B = metallic
  apache_normal.png - Non-Color tangent-space normal

The wheels, under-nose gun, wing weapons and protruding tail-side housing have been removed. The wings and side engines are retained.

This folder contains copies of the optimized assets. The original detailed and optimized source files in the parent folder are unchanged.

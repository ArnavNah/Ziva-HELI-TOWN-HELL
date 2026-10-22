extends SceneTree

func _init() -> void:
	call_deferred("_build")

func _build() -> void:
	print("--- BUILDING INTERCEPTOR 3D MODEL ---")
	
	# Root node for the visual rig
	var root_node = Node3D.new()
	root_node.name = "InterceptorRig"
	
	# Visuals node
	var visuals = Node3D.new()
	visuals.name = "Visuals"
	root_node.add_child(visuals)
	visuals.owner = root_node
	
	# Materials definition
	var mat_steel_blue = StandardMaterial3D.new()
	mat_steel_blue.resource_name = "mat_steel_blue"
	mat_steel_blue.albedo_color = Color(0.28, 0.38, 0.48, 1.0) # #47617a
	mat_steel_blue.roughness = 0.90
	
	var mat_charcoal = StandardMaterial3D.new()
	mat_charcoal.resource_name = "mat_charcoal"
	mat_charcoal.albedo_color = Color(0.16, 0.18, 0.21, 1.0) # #292e35
	mat_charcoal.roughness = 0.88
	
	var mat_brick_red = StandardMaterial3D.new()
	mat_brick_red.resource_name = "mat_brick_red"
	mat_brick_red.albedo_color = Color(0.72, 0.22, 0.18, 1.0) # #b8382e
	mat_brick_red.roughness = 0.88
	
	var mat_ivory = StandardMaterial3D.new()
	mat_ivory.resource_name = "mat_ivory"
	mat_ivory.albedo_color = Color(0.92, 0.89, 0.80, 1.0) # #eae3cc
	mat_ivory.roughness = 0.90
	
	var mat_canopy = StandardMaterial3D.new()
	mat_canopy.resource_name = "mat_canopy"
	mat_canopy.albedo_color = Color(0.08, 0.10, 0.13, 1.0)
	mat_canopy.roughness = 0.32
	mat_canopy.metallic = 0.20
	
	var mat_muzzle = StandardMaterial3D.new()
	mat_muzzle.resource_name = "mat_muzzle"
	mat_muzzle.albedo_color = Color(0.04, 0.05, 0.06, 1.0)
	mat_muzzle.roughness = 0.95

	# Airframe container
	var airframe = Node3D.new()
	airframe.name = "Airframe"
	visuals.add_child(airframe)
	airframe.owner = root_node
	
	# -------------------------------------------------------------
	# 1. SPEAR NOSE (Long, aggressive, faceted arrowhead forward cone)
	# -------------------------------------------------------------
	var spear_cone = MeshInstance3D.new()
	spear_cone.name = "SpearNoseCone"
	var spear_mesh = CylinderMesh.new()
	spear_mesh.top_radius = 0.02
	spear_mesh.bottom_radius = 0.54
	spear_mesh.height = 3.2
	spear_mesh.radial_segments = 8
	spear_mesh.rings = 1
	spear_mesh.material = mat_steel_blue
	spear_cone.mesh = spear_mesh
	spear_cone.position = Vector3(0, 0.02, -3.2)
	spear_cone.rotation_degrees = Vector3(-90, 22.5, 0)
	airframe.add_child(spear_cone)
	spear_cone.owner = root_node
	
	# Pitot needle
	var pitot = MeshInstance3D.new()
	pitot.name = "PitotNeedle"
	var pitot_mesh = CylinderMesh.new()
	pitot_mesh.top_radius = 0.015
	pitot_mesh.bottom_radius = 0.025
	pitot_mesh.height = 0.75
	pitot_mesh.radial_segments = 6
	pitot_mesh.rings = 1
	pitot_mesh.material = mat_charcoal
	pitot.mesh = pitot_mesh
	pitot.position = Vector3(0, 0.02, -5.15)
	pitot.rotation_degrees = Vector3(-90, 0, 0)
	airframe.add_child(pitot)
	pitot.owner = root_node

	# -------------------------------------------------------------
	# 2. CENTRAL FUSELAGE
	# -------------------------------------------------------------
	# Forward fuselage deck (connecting spear cone to cockpit)
	var fwd_deck = MeshInstance3D.new()
	fwd_deck.name = "FwdDeck"
	var fd_mesh = BoxMesh.new()
	fd_mesh.size = Vector3(1.10, 0.68, 1.8)
	fd_mesh.material = mat_steel_blue
	fwd_deck.mesh = fd_mesh
	fwd_deck.position = Vector3(0, 0.06, -0.9)
	airframe.add_child(fwd_deck)
	fwd_deck.owner = root_node
	
	# Mid fuselage body
	var mid_body = MeshInstance3D.new()
	mid_body.name = "MidFuselage"
	var mb_mesh = BoxMesh.new()
	mb_mesh.size = Vector3(1.18, 0.78, 2.6)
	mb_mesh.material = mat_steel_blue
	mid_body.mesh = mb_mesh
	mid_body.position = Vector3(0, 0.10, 1.1)
	airframe.add_child(mid_body)
	mid_body.owner = root_node
	
	# Aft fuselage body
	var aft_body = MeshInstance3D.new()
	aft_body.name = "AftFuselage"
	var ab_mesh = BoxMesh.new()
	ab_mesh.size = Vector3(1.12, 0.72, 1.4)
	ab_mesh.material = mat_steel_blue
	aft_body.mesh = ab_mesh
	aft_body.position = Vector3(0, 0.12, 2.7)
	airframe.add_child(aft_body)
	aft_body.owner = root_node

	# Fuselage belly / underside plate
	var belly = MeshInstance3D.new()
	belly.name = "FuselageUnderside"
	var belly_mesh = BoxMesh.new()
	belly_mesh.size = Vector3(1.05, 0.15, 5.2)
	belly_mesh.material = mat_charcoal
	belly.mesh = belly_mesh
	belly.position = Vector3(0, -0.32, 0.8)
	airframe.add_child(belly)
	belly.owner = root_node

	# -------------------------------------------------------------
	# 3. CANOPY (Dark opaque faceted canopy set behind long nose)
	# -------------------------------------------------------------
	var canopy = MeshInstance3D.new()
	canopy.name = "CockpitCanopy"
	var c_mesh = BoxMesh.new()
	c_mesh.size = Vector3(0.64, 0.36, 1.35)
	c_mesh.material = mat_canopy
	canopy.mesh = c_mesh
	canopy.position = Vector3(0, 0.44, -1.0)
	canopy.rotation_degrees = Vector3(-12.0, 0, 0)
	airframe.add_child(canopy)
	canopy.owner = root_node

	# Canopy windshield forward slope
	var windshield = MeshInstance3D.new()
	windshield.name = "WindshieldSlope"
	var ws_mesh = BoxMesh.new()
	ws_mesh.size = Vector3(0.60, 0.28, 0.80)
	ws_mesh.material = mat_canopy
	windshield.mesh = ws_mesh
	windshield.position = Vector3(0, 0.36, -1.75)
	windshield.rotation_degrees = Vector3(-24.0, 0, 0)
	airframe.add_child(windshield)
	windshield.owner = root_node

	# -------------------------------------------------------------
	# 4. BRICK-RED DORSAL STRIPE
	# -------------------------------------------------------------
	var dorsal_stripe = MeshInstance3D.new()
	dorsal_stripe.name = "DorsalStripe"
	var ds_mesh = BoxMesh.new()
	ds_mesh.size = Vector3(0.42, 0.10, 2.8)
	ds_mesh.material = mat_brick_red
	dorsal_stripe.mesh = ds_mesh
	dorsal_stripe.position = Vector3(0, 0.52, 0.9)
	airframe.add_child(dorsal_stripe)
	dorsal_stripe.owner = root_node
	
	var dorsal_slope = MeshInstance3D.new()
	dorsal_slope.name = "DorsalStripeFwdSlope"
	var dsf_mesh = BoxMesh.new()
	dsf_mesh.size = Vector3(0.42, 0.10, 0.65)
	dsf_mesh.material = mat_brick_red
	dorsal_slope.mesh = dsf_mesh
	dorsal_slope.position = Vector3(0, 0.46, -0.45)
	dorsal_slope.rotation_degrees = Vector3(-16.0, 0, 0)
	airframe.add_child(dorsal_slope)
	dorsal_slope.owner = root_node

	# -------------------------------------------------------------
	# 5. WING-ROOT INTAKES & RECOGNITION PLATES
	# -------------------------------------------------------------
	for side in [-1.0, 1.0]:
		var side_name = "Left" if side < 0 else "Right"
		var intake = MeshInstance3D.new()
		intake.name = "IntakeBody_" + side_name
		var in_mesh = BoxMesh.new()
		in_mesh.size = Vector3(0.36, 0.52, 1.4)
		in_mesh.material = mat_steel_blue
		intake.mesh = in_mesh
		intake.position = Vector3(side * 0.72, 0.05, -0.4)
		airframe.add_child(intake)
		intake.owner = root_node
		
		var intake_lip = MeshInstance3D.new()
		intake_lip.name = "IntakeLip_" + side_name
		var lip_mesh = BoxMesh.new()
		lip_mesh.size = Vector3(0.38, 0.54, 0.10)
		lip_mesh.material = mat_ivory
		intake_lip.mesh = lip_mesh
		intake_lip.position = Vector3(side * 0.72, 0.05, -1.11)
		airframe.add_child(intake_lip)
		intake_lip.owner = root_node
		
		var intake_recess = MeshInstance3D.new()
		intake_recess.name = "IntakeRecess_" + side_name
		var rec_mesh = BoxMesh.new()
		rec_mesh.size = Vector3(0.32, 0.46, 0.08)
		rec_mesh.material = mat_charcoal
		intake_recess.mesh = rec_mesh
		intake_recess.position = Vector3(side * 0.72, 0.05, -1.12)
		airframe.add_child(intake_recess)
		intake_recess.owner = root_node
		
		# Ivory side marker plate
		var side_panel = MeshInstance3D.new()
		side_panel.name = "FuselagePanelIvory_" + side_name
		var sp_mesh = BoxMesh.new()
		sp_mesh.size = Vector3(0.04, 0.14, 0.55)
		sp_mesh.material = mat_ivory
		side_panel.mesh = sp_mesh
		side_panel.position = Vector3(side * 0.60, 0.22, 0.4)
		airframe.add_child(side_panel)
		side_panel.owner = root_node

	# -------------------------------------------------------------
	# 6. FORWARD GUN OPENINGS (Two short reinforced forward muzzles)
	# -------------------------------------------------------------
	for side in [-1.0, 1.0]:
		var side_name = "Left" if side < 0 else "Right"
		var gun_mount = Node3D.new()
		gun_mount.name = "GunSocket_" + side_name
		gun_mount.position = Vector3(side * 0.95, -0.02, -1.05)
		airframe.add_child(gun_mount)
		gun_mount.owner = root_node
		
		var fairing = MeshInstance3D.new()
		fairing.name = "Fairing"
		var f_mesh = BoxMesh.new()
		f_mesh.size = Vector3(0.28, 0.26, 0.65)
		f_mesh.material = mat_ivory
		fairing.mesh = f_mesh
		fairing.position = Vector3.ZERO
		gun_mount.add_child(fairing)
		fairing.owner = root_node
		
		var barrel = MeshInstance3D.new()
		barrel.name = "Barrel"
		var b_mesh = CylinderMesh.new()
		b_mesh.top_radius = 0.07
		b_mesh.bottom_radius = 0.07
		b_mesh.height = 0.75
		b_mesh.radial_segments = 8
		b_mesh.rings = 1
		b_mesh.material = mat_charcoal
		barrel.mesh = b_mesh
		barrel.position = Vector3(0, 0, -0.45)
		barrel.rotation_degrees = Vector3(-90, 0, 0)
		gun_mount.add_child(barrel)
		barrel.owner = root_node
		
		var muzzle = MeshInstance3D.new()
		muzzle.name = "MuzzleOpening"
		var muz_mesh = CylinderMesh.new()
		muz_mesh.top_radius = 0.05
		muz_mesh.bottom_radius = 0.05
		muz_mesh.height = 0.06
		muz_mesh.radial_segments = 8
		muz_mesh.rings = 1
		muz_mesh.material = mat_muzzle
		muzzle.mesh = muz_mesh
		muzzle.position = Vector3(0, 0, -0.83)
		muzzle.rotation_degrees = Vector3(-90, 0, 0)
		gun_mount.add_child(muzzle)
		muzzle.owner = root_node

	# -------------------------------------------------------------
	# 7. TRIANGULAR DELTA WINGS (Thick faceted arrowhead wings)
	# -------------------------------------------------------------
	# Generate procedural triangular delta wing meshes with visible thickness
	for side in [-1.0, 1.0]:
		var side_name = "Left" if side < 0 else "Right"
		
		# Wing Mesh Instance
		var wing_inst = MeshInstance3D.new()
		wing_inst.name = "DeltaWing_" + side_name
		
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		
		# Vertices definition (in local wing space or fuselage space)
		# Root leading: (side * 0.9, 0.08, -0.9)
		# Root trailing: (side * 0.9, 0.08, 2.7)
		# Tip trailing: (side * 3.1, 0.08, 2.5)
		var s = side
		var y_top = 0.08
		var y_bot = -0.08
		
		var p_root_lead_top = Vector3(s * 0.9, y_top, -0.9)
		var p_root_trail_top = Vector3(s * 0.9, y_top, 2.7)
		var p_tip_trail_top = Vector3(s * 3.1, y_top, 2.5)
		
		var p_root_lead_bot = Vector3(s * 0.9, y_bot, -0.9)
		var p_root_trail_bot = Vector3(s * 0.9, y_bot, 2.7)
		var p_tip_trail_bot = Vector3(s * 3.1, y_bot, 2.5)
		
		# Top triangle
		if s > 0:
			st.add_vertex(p_root_lead_top)
			st.add_vertex(p_tip_trail_top)
			st.add_vertex(p_root_trail_top)
		else:
			st.add_vertex(p_root_lead_top)
			st.add_vertex(p_root_trail_top)
			st.add_vertex(p_tip_trail_top)
			
		st.generate_normals()
		st.set_material(mat_steel_blue)
		var wing_mesh = st.commit()
		
		# Bottom surface (charcoal)
		var st_bot = SurfaceTool.new()
		st_bot.begin(Mesh.PRIMITIVE_TRIANGLES)
		if s > 0:
			st_bot.add_vertex(p_root_lead_bot)
			st_bot.add_vertex(p_root_trail_bot)
			st_bot.add_vertex(p_tip_trail_bot)
		else:
			st_bot.add_vertex(p_root_lead_bot)
			st_bot.add_vertex(p_tip_trail_bot)
			st_bot.add_vertex(p_root_trail_bot)
		st_bot.generate_normals()
		st_bot.set_material(mat_charcoal)
		wing_mesh = st_bot.commit(wing_mesh)
		
		# Leading edge side face (charcoal bevel)
		var st_lead = SurfaceTool.new()
		st_lead.begin(Mesh.PRIMITIVE_TRIANGLES)
		if s > 0:
			st_lead.add_vertex(p_root_lead_top)
			st_lead.add_vertex(p_root_lead_bot)
			st_lead.add_vertex(p_tip_trail_bot)
			
			st_lead.add_vertex(p_root_lead_top)
			st_lead.add_vertex(p_tip_trail_bot)
			st_lead.add_vertex(p_tip_trail_top)
		else:
			st_lead.add_vertex(p_root_lead_top)
			st_lead.add_vertex(p_tip_trail_bot)
			st_lead.add_vertex(p_root_lead_bot)
			
			st_lead.add_vertex(p_root_lead_top)
			st_lead.add_vertex(p_tip_trail_top)
			st_lead.add_vertex(p_tip_trail_bot)
		st_lead.generate_normals()
		st_lead.set_material(mat_charcoal)
		wing_mesh = st_lead.commit(wing_mesh)
		
		# Trailing edge face
		var st_trail = SurfaceTool.new()
		st_trail.begin(Mesh.PRIMITIVE_TRIANGLES)
		if s > 0:
			st_trail.add_vertex(p_tip_trail_top)
			st_trail.add_vertex(p_tip_trail_bot)
			st_trail.add_vertex(p_root_trail_bot)
			
			st_trail.add_vertex(p_tip_trail_top)
			st_trail.add_vertex(p_root_trail_bot)
			st_trail.add_vertex(p_root_trail_top)
		else:
			st_trail.add_vertex(p_tip_trail_top)
			st_trail.add_vertex(p_root_trail_bot)
			st_trail.add_vertex(p_tip_trail_bot)
			
			st_trail.add_vertex(p_tip_trail_top)
			st_trail.add_vertex(p_root_trail_top)
			st_trail.add_vertex(p_root_trail_bot)
		st_trail.generate_normals()
		st_trail.set_material(mat_charcoal)
		wing_mesh = st_trail.commit(wing_mesh)
		
		wing_inst.mesh = wing_mesh
		airframe.add_child(wing_inst)
		wing_inst.owner = root_node
		
		# Warm ivory wingtip accent panel
		var wingtip_ivory = MeshInstance3D.new()
		wingtip_ivory.name = "WingtipPanelIvory_" + side_name
		var wti_mesh = BoxMesh.new()
		wti_mesh.size = Vector3(0.55, 0.17, 0.70)
		wti_mesh.material = mat_ivory
		wingtip_ivory.mesh = wti_mesh
		wingtip_ivory.position = Vector3(side * 2.75, 0.0, 2.15)
		wingtip_ivory.rotation_degrees = Vector3(0, side * -12.0, 0)
		airframe.add_child(wingtip_ivory)
		wingtip_ivory.owner = root_node

		# Mid-wing ivory accent stripe
		var wing_inner_ivory = MeshInstance3D.new()
		wing_inner_ivory.name = "WingInnerPanelIvory_" + side_name
		var wii_mesh = BoxMesh.new()
		wii_mesh.size = Vector3(0.45, 0.17, 0.40)
		wii_mesh.material = mat_ivory
		wing_inner_ivory.mesh = wii_mesh
		wing_inner_ivory.position = Vector3(side * 1.85, 0.0, 2.50)
		airframe.add_child(wing_inner_ivory)
		wing_inner_ivory.owner = root_node

	# -------------------------------------------------------------
	# 8. VERTICAL TAIL FIN (Single tall swept stabilizer)
	# -------------------------------------------------------------
	var tail_fin = MeshInstance3D.new()
	tail_fin.name = "VerticalTailFin"
	var fin_st = SurfaceTool.new()
	fin_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var fin_thick = 0.08
	# Base root: z = 0.9 to z = 3.2, y = 0.55
	# Fin tip: z = 2.4 to z = 3.1, y = 2.35
	var p_fwd_root_r = Vector3(fin_thick, 0.55, 0.9)
	var p_fwd_root_l = Vector3(-fin_thick, 0.55, 0.9)
	var p_aft_root_r = Vector3(fin_thick, 0.55, 3.2)
	var p_aft_root_l = Vector3(-fin_thick, 0.55, 3.2)
	
	var p_fwd_tip_r = Vector3(fin_thick * 0.7, 2.35, 2.4)
	var p_fwd_tip_l = Vector3(-fin_thick * 0.7, 2.35, 2.4)
	var p_aft_tip_r = Vector3(fin_thick * 0.7, 2.35, 3.1)
	var p_aft_tip_l = Vector3(-fin_thick * 0.7, 2.35, 3.1)
	
	# Right side of fin
	fin_st.add_vertex(p_fwd_root_r)
	fin_st.add_vertex(p_fwd_tip_r)
	fin_st.add_vertex(p_aft_root_r)
	
	fin_st.add_vertex(p_fwd_tip_r)
	fin_st.add_vertex(p_aft_tip_r)
	fin_st.add_vertex(p_aft_root_r)
	
	# Left side of fin
	fin_st.add_vertex(p_fwd_root_l)
	fin_st.add_vertex(p_aft_root_l)
	fin_st.add_vertex(p_fwd_tip_l)
	
	fin_st.add_vertex(p_fwd_tip_l)
	fin_st.add_vertex(p_aft_root_l)
	fin_st.add_vertex(p_aft_tip_l)
	
	# Leading edge
	fin_st.add_vertex(p_fwd_root_r)
	fin_st.add_vertex(p_fwd_root_l)
	fin_st.add_vertex(p_fwd_tip_r)
	
	fin_st.add_vertex(p_fwd_root_l)
	fin_st.add_vertex(p_fwd_tip_l)
	fin_st.add_vertex(p_fwd_tip_r)
	
	# Trailing edge
	fin_st.add_vertex(p_aft_root_r)
	fin_st.add_vertex(p_aft_tip_r)
	fin_st.add_vertex(p_aft_root_l)
	
	fin_st.add_vertex(p_aft_root_l)
	fin_st.add_vertex(p_aft_tip_r)
	fin_st.add_vertex(p_aft_tip_l)
	
	# Top edge
	fin_st.add_vertex(p_fwd_tip_r)
	fin_st.add_vertex(p_fwd_tip_l)
	fin_st.add_vertex(p_aft_tip_r)
	
	fin_st.add_vertex(p_fwd_tip_l)
	fin_st.add_vertex(p_aft_tip_l)
	fin_st.add_vertex(p_aft_tip_r)
	
	fin_st.generate_normals()
	fin_st.set_material(mat_steel_blue)
	tail_fin.mesh = fin_st.commit()
	airframe.add_child(tail_fin)
	tail_fin.owner = root_node
	
	# Tail fin ivory rudder panel
	var fin_ivory = MeshInstance3D.new()
	fin_ivory.name = "TailFinRudderIvory"
	var fi_mesh = BoxMesh.new()
	fi_mesh.size = Vector3(0.18, 0.95, 0.35)
	fi_mesh.material = mat_ivory
	fin_ivory.mesh = fi_mesh
	fin_ivory.position = Vector3(0, 1.85, 2.85)
	airframe.add_child(fin_ivory)
	fin_ivory.owner = root_node

	# -------------------------------------------------------------
	# 9. OVERSIZED REAR JET EXHAUST
	# -------------------------------------------------------------
	var exhaust_nozzle = MeshInstance3D.new()
	exhaust_nozzle.name = "OversizedJetExhaust"
	var noz_mesh = CylinderMesh.new()
	noz_mesh.top_radius = 0.44
	noz_mesh.bottom_radius = 0.54
	noz_mesh.height = 0.95
	noz_mesh.radial_segments = 10
	noz_mesh.rings = 1
	noz_mesh.material = mat_charcoal
	exhaust_nozzle.mesh = noz_mesh
	exhaust_nozzle.position = Vector3(0, 0.12, 3.7)
	exhaust_nozzle.rotation_degrees = Vector3(90, 0, 0)
	airframe.add_child(exhaust_nozzle)
	exhaust_nozzle.owner = root_node
	
	var exhaust_interior = MeshInstance3D.new()
	exhaust_interior.name = "ExhaustInterior"
	var int_mesh = CylinderMesh.new()
	int_mesh.top_radius = 0.38
	int_mesh.bottom_radius = 0.38
	int_mesh.height = 0.15
	int_mesh.radial_segments = 10
	int_mesh.rings = 1
	int_mesh.material = mat_muzzle
	exhaust_interior.mesh = int_mesh
	exhaust_interior.position = Vector3(0, 0.12, 4.18)
	exhaust_interior.rotation_degrees = Vector3(90, 0, 0)
	airframe.add_child(exhaust_interior)
	exhaust_interior.owner = root_node

	# Pack and save scene
	var packed_scene = PackedScene.new()
	var pack_result = packed_scene.pack(root_node)
	if pack_result != OK:
		printerr("Failed to pack Interceptor scene! Code: ", pack_result)
		quit(1)
		return
		
	var scene_path = "res://scenes/enemies/interceptor_visuals.tscn"
	var save_err = ResourceSaver.save(packed_scene, scene_path)
	if save_err != OK:
		printerr("Failed to save scene to ", scene_path, ", err: ", save_err)
		quit(1)
		return
		
	print("SUCCESSFULLY saved Interceptor scene to: ", scene_path)
	quit(0)

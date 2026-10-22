@tool
extends SceneTree

func _init() -> void:
	print("--- ASSEMBLING LOW-POLY INTERCEPTOR JET VISUALS SCENE ---")
	var root_node = Node3D.new()
	root_node.name = "InterceptorVisuals"

	# Authentic Megabonk Palette Materials
	var mat_steel_blue = StandardMaterial3D.new()
	mat_steel_blue.resource_name = "mat_steel_blue"
	mat_steel_blue.albedo_color = Color(0.35, 0.46, 0.58)
	mat_steel_blue.roughness = 0.92

	var mat_charcoal = StandardMaterial3D.new()
	mat_charcoal.resource_name = "mat_charcoal"
	mat_charcoal.albedo_color = Color(0.18, 0.20, 0.23)
	mat_charcoal.metallic = 0.10
	mat_charcoal.roughness = 0.88

	var mat_brick_red = StandardMaterial3D.new()
	mat_brick_red.resource_name = "mat_brick_red"
	mat_brick_red.albedo_color = Color(0.72, 0.24, 0.20)
	mat_brick_red.roughness = 0.90

	var mat_warm_ivory = StandardMaterial3D.new()
	mat_warm_ivory.resource_name = "mat_warm_ivory"
	mat_warm_ivory.albedo_color = Color(0.92, 0.88, 0.78)
	mat_warm_ivory.roughness = 0.90

	var mat_canopy_dark = StandardMaterial3D.new()
	mat_canopy_dark.resource_name = "mat_canopy_dark"
	mat_canopy_dark.albedo_color = Color(0.11, 0.13, 0.17)
	mat_canopy_dark.roughness = 0.35
	mat_canopy_dark.metallic = 0.25

	var airframe = Node3D.new()
	airframe.name = "Airframe"
	root_node.add_child(airframe)
	airframe.owner = root_node

	# -------------------------------------------------------------
	# 1. Long Faceted Spear Nose (Watertight Hexagonal Cone)
	# -------------------------------------------------------------
	var st_nose = SurfaceTool.new()
	st_nose.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_nose.set_material(mat_steel_blue)

	var nose_tip = Vector3(0.0, 0.36, -4.20)

	# Mid-station at Z = -2.70
	var n_mid_top = Vector3(0.0, 0.58, -2.70)
	var n_mid_tr  = Vector3(0.24, 0.48, -2.70)
	var n_mid_br  = Vector3(0.24, 0.22, -2.70)
	var n_mid_bot = Vector3(0.0, 0.16, -2.70)
	var n_mid_bl  = Vector3(-0.24, 0.22, -2.70)
	var n_mid_tl  = Vector3(-0.24, 0.48, -2.70)

	# Forward pyramid: tip to mid-station (CCW facing out)
	_add_tri(st_nose, nose_tip, n_mid_top, n_mid_tr)
	_add_tri(st_nose, nose_tip, n_mid_tr, n_mid_br)
	_add_tri(st_nose, nose_tip, n_mid_br, n_mid_bot)
	_add_tri(st_nose, nose_tip, n_mid_bot, n_mid_bl)
	_add_tri(st_nose, nose_tip, n_mid_bl, n_mid_tl)
	_add_tri(st_nose, nose_tip, n_mid_tl, n_mid_top)

	# Base station at Z = -1.40 (matches fuselage Station 0)
	var n_base_top = Vector3(0.0, 0.80, -1.40)
	var n_base_tr  = Vector3(0.42, 0.65, -1.40)
	var n_base_br  = Vector3(0.42, 0.20, -1.40)
	var n_base_bot = Vector3(0.0, 0.14, -1.40)
	var n_base_bl  = Vector3(-0.42, 0.20, -1.40)
	var n_base_tl  = Vector3(-0.42, 0.65, -1.40)

	# Connect mid-station to base-station
	_add_quad(st_nose, n_mid_top, n_base_top, n_base_tr, n_mid_tr)
	_add_quad(st_nose, n_mid_tr, n_base_tr, n_base_br, n_mid_br)
	_add_quad(st_nose, n_mid_br, n_base_br, n_base_bot, n_mid_bot)
	_add_quad(st_nose, n_mid_bot, n_base_bot, n_base_bl, n_mid_bl)
	_add_quad(st_nose, n_mid_bl, n_base_bl, n_base_tl, n_mid_tl)
	_add_quad(st_nose, n_mid_tl, n_base_tl, n_base_top, n_mid_top)

	st_nose.generate_normals()

	var nose_inst = MeshInstance3D.new()
	nose_inst.name = "SpearNose"
	nose_inst.mesh = st_nose.commit()
	airframe.add_child(nose_inst)
	nose_inst.owner = root_node

	# -------------------------------------------------------------
	# 2. Complete Watertight Fuselage Hull (Steel Blue)
	# -------------------------------------------------------------
	var st_fuse = SurfaceTool.new()
	st_fuse.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_fuse.set_material(mat_steel_blue)

	# Station 0 at Z = -1.40
	var s0_tc = n_base_top
	var s0_tr = n_base_tr
	var s0_br = n_base_br
	var s0_bc = n_base_bot
	var s0_bl = n_base_bl
	var s0_tl = n_base_tl

	# Station 1 at Z = -0.15 (Behind canopy / wing root leading edge)
	var s1_tc = Vector3(0.0, 0.88, -0.15)
	var s1_tr = Vector3(0.55, 0.76, -0.15)
	var s1_br = Vector3(0.55, 0.22, -0.15)
	var s1_bc = Vector3(0.0, 0.16, -0.15)
	var s1_bl = Vector3(-0.55, 0.22, -0.15)
	var s1_tl = Vector3(-0.55, 0.76, -0.15)

	# Connect Station 0 to Station 1 (Solid hull under canopy & intakes)
	_add_quad(st_fuse, s0_tc, s1_tc, s1_tr, s0_tr)
	_add_quad(st_fuse, s0_tl, s0_tc, s1_tc, s1_tl)
	_add_quad(st_fuse, s0_tr, s1_tr, s1_br, s0_br)
	_add_quad(st_fuse, s0_bl, s1_bl, s1_tl, s0_tl)
	_add_quad(st_fuse, s0_br, s1_br, s1_bc, s0_bc)
	_add_quad(st_fuse, s0_bc, s1_bc, s1_bl, s0_bl)

	# Station 2 at Z = 1.65 (Aft wing root / vertical fin base)
	var s2_tc = Vector3(0.0, 0.86, 1.65)
	var s2_tr = Vector3(0.54, 0.74, 1.65)
	var s2_br = Vector3(0.54, 0.22, 1.65)
	var s2_bc = Vector3(0.0, 0.16, 1.65)
	var s2_bl = Vector3(-0.54, 0.22, 1.65)
	var s2_tl = Vector3(-0.54, 0.74, 1.65)

	# Connect Station 1 to Station 2
	_add_quad(st_fuse, s1_tc, s2_tc, s2_tr, s1_tr)
	_add_quad(st_fuse, s1_tl, s1_tc, s2_tc, s2_tl)
	_add_quad(st_fuse, s1_tr, s2_tr, s2_br, s1_br)
	_add_quad(st_fuse, s1_bl, s2_bl, s2_tl, s1_tl)
	_add_quad(st_fuse, s1_br, s2_br, s2_bc, s1_bc)
	_add_quad(st_fuse, s1_bc, s2_bc, s2_bl, s1_bl)

	# Station 3 at Z = 2.15 (Rear exhaust bulkhead)
	var s3_tc = Vector3(0.0, 0.80, 2.15)
	var s3_tr = Vector3(0.44, 0.70, 2.15)
	var s3_br = Vector3(0.44, 0.26, 2.15)
	var s3_bc = Vector3(0.0, 0.20, 2.15)
	var s3_bl = Vector3(-0.44, 0.26, 2.15)
	var s3_tl = Vector3(-0.44, 0.70, 2.15)

	# Connect Station 2 to Station 3
	_add_quad(st_fuse, s2_tc, s3_tc, s3_tr, s2_tr)
	_add_quad(st_fuse, s2_tl, s2_tc, s3_tc, s3_tl)
	_add_quad(st_fuse, s2_tr, s3_tr, s3_br, s2_br)
	_add_quad(st_fuse, s2_bl, s3_bl, s3_tl, s2_tl)
	_add_quad(st_fuse, s2_br, s3_br, s3_bc, s2_bc)
	_add_quad(st_fuse, s2_bc, s3_bc, s3_bl, s2_bl)

	# Rear endcap (Facing +Z)
	_add_tri(st_fuse, s3_tc, s3_tr, s3_br)
	_add_tri(st_fuse, s3_tc, s3_br, s3_bc)
	_add_tri(st_fuse, s3_tc, s3_bc, s3_bl)
	_add_tri(st_fuse, s3_tc, s3_bl, s3_tl)

	st_fuse.generate_normals()

	var fuse_inst = MeshInstance3D.new()
	fuse_inst.name = "CentralFuselage"
	fuse_inst.mesh = st_fuse.commit()
	airframe.add_child(fuse_inst)
	fuse_inst.owner = root_node

	# -------------------------------------------------------------
	# 3. Cockpit Canopy (Faceted Dark Opaque Glass Canopy)
	# -------------------------------------------------------------
	var st_canopy = SurfaceTool.new()
	st_canopy.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_canopy.set_material(mat_canopy_dark)

	var c_nose_pt = Vector3(0.0, 0.81, -1.35)
	var c_cr_f    = Vector3(0.0, 1.20, -0.88)
	var c_cr_b    = Vector3(0.0, 1.18, -0.36)
	var c_tail    = Vector3(0.0, 0.90, -0.15)

	var c_rf_r    = Vector3(0.32, 0.74, -0.88)
	var c_rf_l    = Vector3(-0.32, 0.74, -0.88)
	var c_rb_r    = Vector3(0.34, 0.78, -0.36)
	var c_rb_l    = Vector3(-0.34, 0.78, -0.36)

	# Windshield facets (CCW facing out)
	_add_tri(st_canopy, c_nose_pt, c_cr_f, c_rf_r)
	_add_tri(st_canopy, c_nose_pt, c_rf_l, c_cr_f)

	# Roof facets
	_add_quad(st_canopy, c_cr_f, c_cr_b, c_rb_r, c_rf_r)
	_add_quad(st_canopy, c_cr_f, c_rf_l, c_rb_l, c_cr_b)

	# Side window facets
	_add_tri(st_canopy, c_nose_pt, c_rf_r, Vector3(0.38, 0.68, -1.20))
	_add_tri(st_canopy, c_nose_pt, Vector3(-0.38, 0.68, -1.20), c_rf_l)
	_add_quad(st_canopy, c_rf_r, c_rb_r, Vector3(0.40, 0.74, -0.36), Vector3(0.38, 0.70, -0.88))
	_add_quad(st_canopy, c_rf_l, Vector3(-0.38, 0.70, -0.88), Vector3(-0.40, 0.74, -0.36), c_rb_l)

	# Rear slope facets
	_add_tri(st_canopy, c_cr_b, c_tail, c_rb_r)
	_add_tri(st_canopy, c_cr_b, c_rb_l, c_tail)

	st_canopy.generate_normals()

	var canopy_inst = MeshInstance3D.new()
	canopy_inst.name = "CockpitCanopy"
	canopy_inst.mesh = st_canopy.commit()
	airframe.add_child(canopy_inst)
	canopy_inst.owner = root_node

	# -------------------------------------------------------------
	# 4. Brick-Red Dorsal Spine & Stripe
	# -------------------------------------------------------------
	var st_spine = SurfaceTool.new()
	st_spine.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_spine.set_material(mat_brick_red)

	var sp_f_c = Vector3(0.0, 0.94, -0.15)
	var sp_f_r = Vector3(0.18, 0.88, -0.15)
	var sp_f_l = Vector3(-0.18, 0.88, -0.15)

	var sp_m_c = Vector3(0.0, 0.96, 0.85)
	var sp_m_r = Vector3(0.18, 0.89, 0.85)
	var sp_m_l = Vector3(-0.18, 0.89, 0.85)

	var sp_b_c = Vector3(0.0, 0.90, 1.85)
	var sp_b_r = Vector3(0.16, 0.85, 1.85)
	var sp_b_l = Vector3(-0.16, 0.85, 1.85)

	_add_quad(st_spine, sp_f_c, sp_m_c, sp_m_r, sp_f_r)
	_add_quad(st_spine, sp_f_l, sp_m_l, sp_m_c, sp_f_c)
	_add_quad(st_spine, sp_m_c, sp_b_c, sp_b_r, sp_m_r)
	_add_quad(st_spine, sp_m_l, sp_b_l, sp_b_c, sp_m_c)

	st_spine.generate_normals()

	var spine_inst = MeshInstance3D.new()
	spine_inst.name = "DorsalStripe"
	spine_inst.mesh = st_spine.commit()
	airframe.add_child(spine_inst)
	spine_inst.owner = root_node

	# -------------------------------------------------------------
	# 5. Wing-Root Air Intakes (Left and Right)
	# -------------------------------------------------------------
	var intakes_node = Node3D.new()
	intakes_node.name = "AirIntakes"
	airframe.add_child(intakes_node)
	intakes_node.owner = root_node

	for side in [-1.0, 1.0]:
		# Outer intake body (Steel Blue)
		var st_in = SurfaceTool.new()
		st_in.begin(Mesh.PRIMITIVE_TRIANGLES)
		st_in.set_material(mat_steel_blue)

		var i_top_f = Vector3(side * 0.50, 0.68, -1.35)
		var i_top_o = Vector3(side * 0.88, 0.68, -1.35)
		var i_bot_f = Vector3(side * 0.50, 0.22, -1.35)
		var i_bot_o = Vector3(side * 0.88, 0.22, -1.35)

		var i_top_f_b = Vector3(side * 0.58, 0.72, -0.20)
		var i_top_o_b = Vector3(side * 0.95, 0.72, -0.20)
		var i_bot_f_b = Vector3(side * 0.58, 0.22, -0.20)
		var i_bot_o_b = Vector3(side * 0.95, 0.22, -0.20)

		if side > 0:
			# Top face
			_add_quad(st_in, i_top_f, i_top_f_b, i_top_o_b, i_top_o)
			# Outer side face
			_add_quad(st_in, i_top_o, i_top_o_b, i_bot_o_b, i_bot_o)
			# Bottom face
			_add_quad(st_in, i_bot_o, i_bot_o_b, i_bot_f_b, i_bot_f)
		else:
			# Top face
			_add_quad(st_in, i_top_f, i_top_o, i_top_o_b, i_top_f_b)
			# Outer side face
			_add_quad(st_in, i_top_o, i_bot_o, i_bot_o_b, i_top_o_b)
			# Bottom face
			_add_quad(st_in, i_bot_o, i_bot_f, i_bot_f_b, i_bot_o_b)

		st_in.generate_normals()

		var in_inst = MeshInstance3D.new()
		in_inst.name = "IntakeBody_%s" % ("L" if side < 0 else "R")
		in_inst.mesh = st_in.commit()
		intakes_node.add_child(in_inst)
		in_inst.owner = root_node

		# Warm Ivory Beveled Intake Lip Rim
		var lip_box = BoxMesh.new()
		lip_box.size = Vector3(0.38, 0.48, 0.12)
		lip_box.material = mat_warm_ivory

		var lip = MeshInstance3D.new()
		lip.name = "IntakeLip_%s" % ("L" if side < 0 else "R")
		lip.mesh = lip_box
		lip.position = Vector3(side * 0.70, 0.45, -1.36)
		intakes_node.add_child(lip)
		lip.owner = root_node

		# Dark Charcoal Recessed Duct Opening
		var duct_box = BoxMesh.new()
		duct_box.size = Vector3(0.26, 0.36, 0.04)
		duct_box.material = mat_charcoal

		var duct = MeshInstance3D.new()
		duct.name = "Duct_%s" % ("L" if side < 0 else "R")
		duct.mesh = duct_box
		duct.position = Vector3(side * 0.70, 0.45, -1.43)
		intakes_node.add_child(duct)
		duct.owner = root_node

		# Warm Ivory Upper Flank Recognition Panel
		var panel_box = BoxMesh.new()
		panel_box.size = Vector3(0.06, 0.22, 0.50)
		panel_box.material = mat_warm_ivory

		var panel = MeshInstance3D.new()
		panel.name = "AccentPanel_%s" % ("L" if side < 0 else "R")
		panel.mesh = panel_box
		panel.position = Vector3(side * 0.66, 0.76, 0.55)
		airframe.add_child(panel)
		panel.owner = root_node

	# -------------------------------------------------------------
	# 6. Swept Clipped Delta Wings (Chunky, Visible Thickness)
	# -------------------------------------------------------------
	var wings_node = Node3D.new()
	wings_node.name = "DeltaWings"
	airframe.add_child(wings_node)
	wings_node.owner = root_node

	for side in [-1.0, 1.0]:
		var st_wing = SurfaceTool.new()
		st_wing.begin(Mesh.PRIMITIVE_TRIANGLES)
		st_wing.set_material(mat_steel_blue)

		var y_top = 0.56
		var y_bot = 0.42

		# Delta wing root at fuselage shoulder
		var w_root_f_t = Vector3(side * 0.60, y_top, -0.25)
		var w_root_f_b = Vector3(side * 0.60, y_bot, -0.25)
		var w_root_r_t = Vector3(side * 0.60, y_top, 1.82)
		var w_root_r_b = Vector3(side * 0.60, y_bot, 1.82)

		# Swept wingtip outer front corner
		var w_tip_f_t  = Vector3(side * 2.80, y_top, 1.38)
		var w_tip_f_b  = Vector3(side * 2.80, y_bot, 1.38)

		# Clipped wingtip outer rear corner
		var w_tip_r_t  = Vector3(side * 2.65, y_top, 1.76)
		var w_tip_r_b  = Vector3(side * 2.65, y_bot, 1.76)

		if side > 0:
			# Top surface (CCW facing +Y)
			_add_tri(st_wing, w_root_f_t, w_tip_f_t, w_root_r_t)
			_add_tri(st_wing, w_tip_f_t, w_tip_r_t, w_root_r_t)
			# Leading edge face
			_add_quad(st_wing, w_root_f_t, w_root_f_b, w_tip_f_b, w_tip_f_t)
			# Wingtip edge face
			_add_quad(st_wing, w_tip_f_t, w_tip_f_b, w_tip_r_b, w_tip_r_t)
			# Trailing edge face
			_add_quad(st_wing, w_tip_r_t, w_tip_r_b, w_root_r_b, w_root_r_t)
		else:
			# Top surface (CCW facing +Y)
			_add_tri(st_wing, w_root_f_t, w_root_r_t, w_tip_f_t)
			_add_tri(st_wing, w_tip_f_t, w_root_r_t, w_tip_r_t)
			# Leading edge face
			_add_quad(st_wing, w_root_f_b, w_root_f_t, w_tip_f_t, w_tip_f_b)
			# Wingtip edge face
			_add_quad(st_wing, w_tip_f_b, w_tip_f_t, w_tip_r_t, w_tip_r_b)
			# Trailing edge face
			_add_quad(st_wing, w_tip_r_b, w_tip_r_t, w_root_r_t, w_root_r_b)

		st_wing.generate_normals()

		var wing_inst = MeshInstance3D.new()
		wing_inst.name = "Wing_%s" % ("L" if side < 0 else "R")
		wing_inst.mesh = st_wing.commit()
		wings_node.add_child(wing_inst)
		wing_inst.owner = root_node

		# Charcoal Wing Underside Surface
		var st_under = SurfaceTool.new()
		st_under.begin(Mesh.PRIMITIVE_TRIANGLES)
		st_under.set_material(mat_charcoal)
		if side > 0:
			_add_tri(st_under, w_root_f_b, w_root_r_b, w_tip_f_b)
			_add_tri(st_under, w_tip_f_b, w_root_r_b, w_tip_r_b)
		else:
			_add_tri(st_under, w_root_f_b, w_tip_f_b, w_root_r_b)
			_add_tri(st_under, w_tip_f_b, w_tip_r_b, w_root_r_b)
		st_under.generate_normals()

		var under_inst = MeshInstance3D.new()
		under_inst.name = "Underside_%s" % ("L" if side < 0 else "R")
		under_inst.mesh = st_under.commit()
		wings_node.add_child(under_inst)
		under_inst.owner = root_node

		# Charcoal Inboard Root Trim (Authentic detail matching concept art)
		var st_trim = SurfaceTool.new()
		st_trim.begin(Mesh.PRIMITIVE_TRIANGLES)
		st_trim.set_material(mat_charcoal)
		var w_trim_mid_t = Vector3(side * 1.50, y_top + 0.005, 0.42)
		if side > 0:
			_add_tri(st_trim, w_root_f_t + Vector3(0, 0.005, 0), w_trim_mid_t, w_root_r_t + Vector3(0, 0.005, 0))
		else:
			_add_tri(st_trim, w_root_f_t + Vector3(0, 0.005, 0), w_root_r_t + Vector3(0, 0.005, 0), w_trim_mid_t)
		st_trim.generate_normals()

		var trim_inst = MeshInstance3D.new()
		trim_inst.name = "RootTrim_%s" % ("L" if side < 0 else "R")
		trim_inst.mesh = st_trim.commit()
		wings_node.add_child(trim_inst)
		trim_inst.owner = root_node

	# -------------------------------------------------------------
	# 7. Swept Vertical Stabilizer Tail Fin
	# -------------------------------------------------------------
	var st_tail = SurfaceTool.new()
	st_tail.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_tail.set_material(mat_steel_blue)

	var t_root_f = Vector3(0.0, 0.90, 0.65)
	var t_root_b = Vector3(0.0, 0.88, 2.05)
	var t_tip_f  = Vector3(0.0, 2.45, 1.58)
	var t_tip_b  = Vector3(0.0, 2.38, 2.08)

	var t_w = 0.065 # Half thickness

	# Right side face
	_add_tri(st_tail, t_root_f + Vector3(t_w, 0, 0), t_tip_f + Vector3(t_w, 0, 0), t_root_b + Vector3(t_w, 0, 0))
	_add_tri(st_tail, t_tip_f + Vector3(t_w, 0, 0), t_tip_b + Vector3(t_w, 0, 0), t_root_b + Vector3(t_w, 0, 0))
	# Left side face
	_add_tri(st_tail, t_root_f + Vector3(-t_w, 0, 0), t_root_b + Vector3(-t_w, 0, 0), t_tip_f + Vector3(-t_w, 0, 0))
	_add_tri(st_tail, t_tip_f + Vector3(-t_w, 0, 0), t_root_b + Vector3(-t_w, 0, 0), t_tip_b + Vector3(-t_w, 0, 0))
	# Trailing edge face
	_add_quad(st_tail, t_tip_b + Vector3(t_w, 0, 0), t_tip_b + Vector3(-t_w, 0, 0), t_root_b + Vector3(-t_w, 0, 0), t_root_b + Vector3(t_w, 0, 0))
	# Top tip edge face
	_add_quad(st_tail, t_tip_f + Vector3(t_w, 0, 0), t_tip_f + Vector3(-t_w, 0, 0), t_tip_b + Vector3(-t_w, 0, 0), t_tip_b + Vector3(t_w, 0, 0))
	st_tail.generate_normals()

	var tail_inst = MeshInstance3D.new()
	tail_inst.name = "VerticalTailFin"
	tail_inst.mesh = st_tail.commit()
	airframe.add_child(tail_inst)
	tail_inst.owner = root_node

	# Brick-Red Leading Edge Spine on Tail Fin
	var st_tail_strip = SurfaceTool.new()
	st_tail_strip.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_tail_strip.set_material(mat_brick_red)
	_add_quad(st_tail_strip, t_root_f + Vector3(t_w, 0, 0), t_tip_f + Vector3(t_w, 0, 0), t_tip_f + Vector3(-t_w, 0, 0), t_root_f + Vector3(-t_w, 0, 0))
	st_tail_strip.generate_normals()

	var tail_strip_inst = MeshInstance3D.new()
	tail_strip_inst.name = "TailFinLeadingEdge"
	tail_strip_inst.mesh = st_tail_strip.commit()
	airframe.add_child(tail_strip_inst)
	tail_strip_inst.owner = root_node

	# -------------------------------------------------------------
	# 8. Oversized Rear Jet Exhaust Nozzle & Flame Core
	# -------------------------------------------------------------
	var exhaust_mesh = CylinderMesh.new()
	exhaust_mesh.top_radius = 0.44
	exhaust_mesh.bottom_radius = 0.50
	exhaust_mesh.height = 0.65
	exhaust_mesh.radial_segments = 8
	exhaust_mesh.material = mat_charcoal

	var exhaust = MeshInstance3D.new()
	exhaust.name = "RearJetExhaust"
	exhaust.mesh = exhaust_mesh
	exhaust.position = Vector3(0, 0.50, 2.28)
	exhaust.rotation_degrees = Vector3(90, 0, 0)
	airframe.add_child(exhaust)
	exhaust.owner = root_node

	# Glowing Orange Afterburner Flame Core
	var core_mesh = CylinderMesh.new()
	core_mesh.top_radius = 0.36
	core_mesh.bottom_radius = 0.36
	core_mesh.height = 0.08
	core_mesh.radial_segments = 8
	var mat_flame_core = StandardMaterial3D.new()
	mat_flame_core.albedo_color = Color(0.98, 0.45, 0.12)
	mat_flame_core.emission_enabled = true
	mat_flame_core.emission = Color(0.98, 0.45, 0.12)
	mat_flame_core.emission_energy_multiplier = 1.60
	core_mesh.material = mat_flame_core

	var core = MeshInstance3D.new()
	core.name = "ExhaustFlameCore"
	core.mesh = core_mesh
	core.position = Vector3(0, 0.50, 2.58)
	core.rotation_degrees = Vector3(90, 0, 0)
	airframe.add_child(core)
	core.owner = root_node

	# -------------------------------------------------------------
	# 9. Two Short Reinforced Forward Guns (Wing Roots Flanking Nose)
	# -------------------------------------------------------------
	var weapons_node = Node3D.new()
	weapons_node.name = "Weapons"
	airframe.add_child(weapons_node)
	weapons_node.owner = root_node

	for side in [-1.0, 1.0]:
		# Reinforced gun pod housing on intake flank
		var pod_box = BoxMesh.new()
		pod_box.size = Vector3(0.18, 0.18, 0.85)
		pod_box.material = mat_steel_blue

		var pod = MeshInstance3D.new()
		pod.name = "GunPod_%s" % ("L" if side < 0 else "R")
		pod.mesh = pod_box
		pod.position = Vector3(side * 0.98, 0.46, -0.92)
		weapons_node.add_child(pod)
		pod.owner = root_node

		# Gun barrel (Faceted 6-sided charcoal cylinder)
		var barrel_cyl = CylinderMesh.new()
		barrel_cyl.top_radius = 0.05
		barrel_cyl.bottom_radius = 0.06
		barrel_cyl.height = 0.70
		barrel_cyl.radial_segments = 6
		barrel_cyl.material = mat_charcoal

		var barrel = MeshInstance3D.new()
		barrel.name = "Barrel_%s" % ("L" if side < 0 else "R")
		barrel.mesh = barrel_cyl
		barrel.position = Vector3(side * 0.98, 0.46, -1.65)
		barrel.rotation_degrees = Vector3(-90, 0, 0)
		weapons_node.add_child(barrel)
		barrel.owner = root_node

		# Muzzle Marker Socket for projectile & flash spawning
		var muzzle = Marker3D.new()
		muzzle.name = "Muzzle_%s" % ("L" if side < 0 else "R")
		muzzle.position = Vector3(side * 0.98, 0.46, -2.02)
		weapons_node.add_child(muzzle)
		muzzle.owner = root_node

	# Pack and save the scene
	var packed_scene = PackedScene.new()
	var pack_result = packed_scene.pack(root_node)
	if pack_result != OK:
		printerr("Failed to pack InterceptorVisuals scene! Error: ", pack_result)
		root_node.queue_free()
		quit(1)
		return

	var save_path = "res://scenes/enemies/interceptor_visuals.tscn"
	var save_result = ResourceSaver.save(packed_scene, save_path)
	if save_result != OK:
		printerr("Failed to save InterceptorVisuals scene! Error: ", save_result)
		root_node.queue_free()
		quit(1)
		return

	print("Successfully generated and saved Interceptor visual asset to: ", save_path)
	root_node.queue_free()
	quit(0)

func _add_tri(st: SurfaceTool, v1: Vector3, v2: Vector3, v3: Vector3) -> void:
	st.add_vertex(v1)
	st.add_vertex(v2)
	st.add_vertex(v3)

func _add_quad(st: SurfaceTool, v1: Vector3, v2: Vector3, v3: Vector3, v4: Vector3) -> void:
	st.add_vertex(v1)
	st.add_vertex(v2)
	st.add_vertex(v3)
	st.add_vertex(v1)
	st.add_vertex(v3)
	st.add_vertex(v4)

class_name HangarMenu
extends Control

## HangarMenu — Comprehensive Airbase Hangar, Armory Facility & Pilot Dossier (Page 19, 20 & 26).
## Features categorized tabs: Aircraft Systems (8), Pilot Perks (8), Armory Weapon Mods (4), and Career Dossier.
## Displays before/after stat previews, interactive mod switching, and real-time wallet tracking.

enum TabIndex {
	SYSTEMS = 0,
	PERKS = 1,
	MODS = 2,
	DOSSIER = 3
}

signal hangar_closed(return_target: String)

var current_tab: TabIndex = TabIndex.SYSTEMS
var caller_origin: String = "main_menu"
var _focus_restore_key: String = ""

var wallet_label: Label
var scroll_container: ScrollContainer
var content_container: VBoxContainer
var back_button: Button
var tab_buttons: Array[Button] = []

# --- METADATA DICTIONARIES ---

const SYSTEM_METADATA: Dictionary = {
	"engine": {
		"name": "TURBOSHAFT ENGINE",
		"desc": "Overhauls cyclic thrust acceleration and maximum cruising airspeed.",
		"stat_unit": "% Thrust & Speed",
		"stat_step": 8.0,
		"base_val": 0.0
	},
	"rotor": {
		"name": "MAIN ROTOR ASSEMBLY",
		"desc": "Improves collective lift responsiveness and rudder yaw turn rate.",
		"stat_unit": "% Yaw Rate",
		"stat_step": 10.0,
		"base_val": 0.0
	},
	"armor": {
		"name": "COMPOSITE HULL ARMOR",
		"desc": "Reinforces ballistic survivability against flak, rockets, and collisions.",
		"stat_unit": " Bonus Hull HP",
		"stat_step": 15.0,
		"base_val": 0.0
	},
	"airframe": {
		"name": "TITANIUM AIRFRAME",
		"desc": "Enhances passive kinetic impact mitigation and structural rigidity.",
		"stat_unit": "% Armor Mitigation",
		"stat_step": 4.0,
		"base_val": 0.0
	},
	"fuel": {
		"name": "EXPANDED FUEL BLADDER",
		"desc": "Increases maximum fuel capacity to prolong tactical mission flight time.",
		"stat_unit": " Bonus Fuel (L)",
		"stat_step": 15.0,
		"base_val": 0.0
	},
	"targeting": {
		"name": "FIRE CONTROL RADAR",
		"desc": "Accelerates chin turret auto-assist tracking speed and lock acquisition.",
		"stat_unit": "% Lock & Tracking Speed",
		"stat_step": 15.0,
		"base_val": 0.0
	},
	"weapon_system": {
		"name": "ORDNANCE MUNITIONS",
		"desc": "Boosts muzzle energy and payload explosive yield across all weapons.",
		"stat_unit": "% Weapon Damage",
		"stat_step": 6.0,
		"base_val": 0.0
	},
	"countermeasures": {
		"name": "FLARE DISPENSER RIG",
		"desc": "Reduces countermeasure reload cooldown and expands decoy capacity.",
		"stat_unit": " Flares / -0.5s CD",
		"stat_step": 1.0,
		"base_val": 3.0
	}
}

const PERK_METADATA: Dictionary = {
	"magnet_radius": {
		"name": "SCAVENGER MAGNET",
		"desc": "Widens electromagnetic recovery envelope for floating salvage and XP gems.",
		"stat_unit": "% Pickup Radius",
		"stat_step": 25.0
	},
	"vector_thrusters": {
		"name": "VECTOR THRUSTERS",
		"desc": "Overclocks evasive dash impulse distance and shortens surge cooldown.",
		"stat_unit": "% Dash Speed / -0.4s CD",
		"stat_step": 20.0
	},
	"scavenger_rig": {
		"name": "SALVAGE DRILL RIG",
		"desc": "Harvests bonus salvage caches and credit bounties from enemy wreckage.",
		"stat_unit": "% Extra Credits & Salvage",
		"stat_step": 15.0
	},
	"rotor_armor": {
		"name": "REINFORCED ROTOR BLADES",
		"desc": "Prevents structural rotor damage when clipping building facades.",
		"stat_unit": "% Collision Resistance",
		"stat_step": 20.0
	},
	"combat_computer": {
		"name": "TARGETING COMPUTER",
		"desc": "Expands painted salvo missile lock-on range and seeker speed.",
		"stat_unit": "% Salvo Lock Range",
		"stat_step": 10.0
	},
	"lean_burn": {
		"name": "LEAN BURN MIXTURE",
		"desc": "Calibrates fuel injection to minimize consumption rate during flight.",
		"stat_unit": "% Fuel Efficiency",
		"stat_step": 12.0
	},
	"devastator_core": {
		"name": "DEVASTATOR CORE",
		"desc": "Charges the tactical Devastation Super meter faster on hostile kills.",
		"stat_unit": "% Super Charge Rate",
		"stat_step": 20.0
	},
	"emp_rounds": {
		"name": "ELECTROMAGNETIC ROUNDS",
		"desc": "Adds an EMP disruption proc chance to machine gun and cannon rounds.",
		"stat_unit": "% EMP Proc Chance",
		"stat_step": 12.0
	}
}

const WEAPON_MOD_METADATA: Array[Dictionary] = [
	{
		"weapon_type": GameConstants.WeaponType.MACHINE_GUN,
		"weapon_name": "M197 20MM TWIN MACHINE GUN",
		"mods": [
			{
				"id": GameConstants.WeaponMod.NONE,
				"name": "STANDARD MUNITIONS",
				"desc": "Factory high-velocity dual 20mm automatic cannon (430 m/s velocity)."
			},
			{
				"id": GameConstants.WeaponMod.MG_INCENDIARY,
				"name": "MOD A: INCENDIARY TRACERS",
				"desc": "18% chance to ignite targets on hit, dealing 14 burn DPS over 3.0s."
			},
			{
				"id": GameConstants.WeaponMod.MG_PIERCING,
				"name": "MOD B: ARMOR PIERCING SABOT",
				"desc": "+35% kinetic damage against armored vehicles, tanks, and boss hulls."
			}
		]
	},
	{
		"weapon_type": GameConstants.WeaponType.MISSILE,
		"weapon_name": "AGM-114 HELLFIRE HOMING MISSILE",
		"mods": [
			{
				"id": GameConstants.WeaponMod.NONE,
				"name": "STANDARD GUIDANCE",
				"desc": "Semi-active radar-guided homing missile (55 dmg, high maneuverability)."
			},
			{
				"id": GameConstants.WeaponMod.MISSILE_EMP,
				"name": "MOD A: EMP DISRUPTION WARHEAD",
				"desc": "Disables target movement, flak turrets, and radar tracking for 2.0s."
			},
			{
				"id": GameConstants.WeaponMod.MISSILE_CLUSTER,
				"name": "MOD B: CLUSTER SUB-MUNITIONS",
				"desc": "Detonates into 3 secondary explosive bomblets for concentrated area denial."
			}
		]
	},
	{
		"weapon_type": GameConstants.WeaponType.ROCKET,
		"weapon_name": "HYDRA 70MM BALLISTIC ROCKET POD",
		"mods": [
			{
				"id": GameConstants.WeaponMod.NONE,
				"name": "STANDARD HIGH EXPLOSIVE",
				"desc": "Ballistic unguided rocket volley (80 dmg, 28m explosive blast radius)."
			},
			{
				"id": GameConstants.WeaponMod.ROCKET_NAPALM,
				"name": "MOD A: NAPALM THERMOBARIC",
				"desc": "+30% blast radius with lingering thermite firefield scorching ground targets."
			},
			{
				"id": GameConstants.WeaponMod.ROCKET_SHAPED,
				"name": "MOD B: SHAPED CHARGE PENETRATOR",
				"desc": "+45% direct kinetic damage against fortified installations and elite armor."
			}
		]
	},
	{
		"weapon_type": GameConstants.WeaponType.SHOTGUN,
		"weapon_name": "TACTICAL FLAK COMBAT SHOTGUN",
		"mods": [
			{
				"id": GameConstants.WeaponMod.NONE,
				"name": "STANDARD FLAK SPREAD",
				"desc": "6-pellet close-quarters wide spread pattern (60 aggregate damage per blast)."
			},
			{
				"id": GameConstants.WeaponMod.SHOTGUN_SHOCK,
				"name": "MOD A: SHOCKWAVE DISRUPTOR",
				"desc": "25% chance to concuss and slow enemy advance speed by 45% for 2.5s."
			},
			{
				"id": GameConstants.WeaponMod.SHOTGUN_SLUG,
				"name": "MOD B: HEAVY SABOT SLUG",
				"desc": "+30% focused kinetic damage with -45% spread cone for mid-range punch."
			}
		]
	}
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui_layout()
	refresh_ui()
	get_node("/root/ProfileManager").save_failed.connect(func(message): wallet_label.text = message)

func _build_ui_layout() -> void:
	for child in get_children():
		child.queue_free()

	tab_buttons.clear()

	# Dark tactical backdrop
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.09, 0.96)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(PRESET_FULL_RECT)
	main_vbox.offset_left = 36.0
	main_vbox.offset_top = 20.0
	main_vbox.offset_right = -36.0
	main_vbox.offset_bottom = -20.0
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)

	# 1. TOP HEADER BAR
	var top_bar = HBoxContainer.new()
	main_vbox.add_child(top_bar)

	var title = Label.new()
	title.text = "AIRBASE HANGAR & ARMORY FACILITY"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title)

	wallet_label = Label.new()
	wallet_label.add_theme_font_size_override("font_size", 16)
	wallet_label.add_theme_color_override("font_color", Color(0.25, 0.95, 0.45, 1.0))
	top_bar.add_child(wallet_label)

	# 2. CATEGORY TAB SELECTOR BAR
	var tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 10)
	main_vbox.add_child(tab_bar)

	var tab_titles = [
		"AIRCRAFT SYSTEMS (8)",
		"PILOT PERKS (8)",
		"ARMORY WEAPON MODS (4)",
		"PILOT DOSSIER & RECORDS"
	]

	for i in tab_titles.size():
		var btn = Button.new()
		btn.text = tab_titles[i]
		btn.custom_minimum_size = Vector2(180, 36)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func(): _switch_tab(i as TabIndex))
		tab_bar.add_child(btn)
		tab_buttons.append(btn)

	# 3. SCROLLABLE CONTENT VIEW
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll_container)

	content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("separation", 12)
	scroll_container.add_child(content_container)

	# 4. BOTTOM ACTION BAR
	var bottom_bar = HBoxContainer.new()
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(bottom_bar)

	back_button = Button.new()
	back_button.text = "RETURN TO OPERATIONS CENTER [ESC]"
	back_button.custom_minimum_size = Vector2(320, 42)
	back_button.pressed.connect(_on_back_pressed)
	bottom_bar.add_child(back_button)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

func _switch_tab(new_tab: TabIndex) -> void:
	current_tab = new_tab
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("ui_click")
	refresh_ui()

func refresh_ui() -> void:
	if not has_node("/root/ProfileManager"):
		return
	var pm = get_node("/root/ProfileManager")
	var focused_control := get_viewport().gui_get_focus_owner()
	if focused_control and content_container.is_ancestor_of(focused_control):
		_focus_restore_key = str(focused_control.get_meta("purchase_key", ""))
	var old_scroll: int = scroll_container.scroll_vertical
	call_deferred("_restore_scroll", old_scroll)

	if wallet_label:
		wallet_label.text = "CREDITS: %d CR | SALVAGE: %d" % [pm.banked_credits, pm.salvage]

	# Update tab button highlights
	for i in tab_buttons.size():
		var is_active = (i == int(current_tab))
		tab_buttons[i].modulate = Color(1.2, 1.2, 1.0) if is_active else Color(0.7, 0.7, 0.7)

	# Clear previous content
	for child in content_container.get_children():
		content_container.remove_child(child)
		child.queue_free()

	match current_tab:
		TabIndex.SYSTEMS:
			_render_systems_tab(pm)
		TabIndex.PERKS:
			_render_perks_tab(pm)
		TabIndex.MODS:
			_render_weapon_mods_tab(pm)
		TabIndex.DOSSIER:
			_render_dossier_tab(pm)

# --- 1. SYSTEMS TAB ---
func _render_systems_tab(pm: Node) -> void:
	var desc_label = Label.new()
	desc_label.text = "Permanent airframe enhancements installed on all deployed aircraft. Ranks 1 to 5."
	desc_label.add_theme_color_override("font_color", Color(0.65, 0.85, 0.95))
	content_container.add_child(desc_label)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	content_container.add_child(grid)

	for sys_key in pm.HANGAR_PRICES.keys():
		var curr_rank: int = pm.hangar_ranks.get(sys_key, 0)
		var prices: Array = pm.HANGAR_PRICES[sys_key]
		var meta: Dictionary = SYSTEM_METADATA.get(sys_key, {"name": sys_key.to_upper(), "desc": "", "stat_unit": "", "stat_step": 1.0, "base_val": 0.0})

		var panel = _create_card_container()
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 6)
		panel.add_child(vbox)

		# Title & Rank row
		var h_title = HBoxContainer.new()
		vbox.add_child(h_title)

		var title_lbl = Label.new()
		title_lbl.text = meta["name"]
		title_lbl.add_theme_font_size_override("font_size", 14)
		title_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_title.add_child(title_lbl)

		var rank_lbl = Label.new()
		rank_lbl.text = _format_stars(curr_rank)
		rank_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		h_title.add_child(rank_lbl)

		# Description
		var desc_lbl = Label.new()
		desc_lbl.text = meta["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_lbl)

		# Stat preview row
		var curr_stat = meta["base_val"] + (curr_rank * meta["stat_step"])
		var next_stat = meta["base_val"] + ((curr_rank + 1) * meta["stat_step"])
		var preview_lbl = Label.new()
		if curr_rank >= 5:
			preview_lbl.text = "Performance: +%.0f%s [MAX OPERATIONAL SPEC]" % [curr_stat, meta["stat_unit"]]
			preview_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
		else:
			preview_lbl.text = "Current: +%.0f%s  ->  Next: +%.0f%s" % [curr_stat, meta["stat_unit"], next_stat, meta["stat_unit"]]
			preview_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		preview_lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(preview_lbl)

		# Upgrade Button
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 34)
		if curr_rank >= 5:
			btn.text = "SYSTEM AT MAXIMUM RANK"
			btn.disabled = true
		else:
			var cost: int = prices[curr_rank]
			btn.set_meta("purchase_key", "system:" + sys_key)
			btn.text = "UPGRADE TO RANK %d — %d CR" % [curr_rank + 1, cost]
			btn.disabled = not pm.can_afford(cost)
			btn.tooltip_text = "Earn more credits to purchase this upgrade." if btn.disabled else "Apply upgrade"
			btn.mouse_entered.connect(func():
				if has_node("/root/AudioManager"):
					get_node("/root/AudioManager").play_sfx("ui_hover")
			)
			btn.focus_entered.connect(func():
				if has_node("/root/AudioManager"):
					get_node("/root/AudioManager").play_sfx("ui_hover")
			)
			btn.pressed.connect(func():
				if pm.can_afford(cost):
					if pm.buy_hangar_upgrade(sys_key):
						if has_node("/root/AudioManager"):
							get_node("/root/AudioManager").play_sfx("ui_buy")
						refresh_ui()
				else:
					if has_node("/root/AudioManager"):
						get_node("/root/AudioManager").play_sfx("ui_denied")
					_flash_insufficient_funds(btn, cost)
			)
		vbox.add_child(btn)

		grid.add_child(panel)

# --- 2. PERKS TAB ---
func _render_perks_tab(pm: Node) -> void:
	var desc_label = Label.new()
	desc_label.text = "Tactical pilot doctrine specializations. Enhance scavenging, dash maneuvers, and combat telemetry."
	desc_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	content_container.add_child(desc_label)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	content_container.add_child(grid)

	for perk_key in pm.PERK_PRICES.keys():
		var curr_rank: int = pm.perk_ranks.get(perk_key, 0)
		var prices: Array = pm.PERK_PRICES[perk_key]
		var meta: Dictionary = PERK_METADATA.get(perk_key, {"name": perk_key.to_upper(), "desc": "", "stat_unit": "", "stat_step": 1.0})

		var panel = _create_card_container()
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 6)
		panel.add_child(vbox)

		# Title & Stars row
		var h_title = HBoxContainer.new()
		vbox.add_child(h_title)

		var title_lbl = Label.new()
		title_lbl.text = meta["name"]
		title_lbl.add_theme_font_size_override("font_size", 14)
		title_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_title.add_child(title_lbl)

		var rank_lbl = Label.new()
		rank_lbl.text = _format_stars(curr_rank)
		rank_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		h_title.add_child(rank_lbl)

		# Description
		var desc_lbl = Label.new()
		desc_lbl.text = meta["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_lbl)

		# Stat preview
		var curr_bonus = curr_rank * meta["stat_step"]
		var next_bonus = (curr_rank + 1) * meta["stat_step"]
		var preview_lbl = Label.new()
		if curr_rank >= 5:
			preview_lbl.text = "Bonus: +%.0f%s [SPECIALIZATION COMPLETE]" % [curr_bonus, meta["stat_unit"]]
			preview_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
		else:
			preview_lbl.text = "Current: +%.0f%s  ->  Next: +%.0f%s" % [curr_bonus, meta["stat_unit"], next_bonus, meta["stat_unit"]]
			preview_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		preview_lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(preview_lbl)

		# Upgrade Button
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 34)
		if curr_rank >= 5:
			btn.text = "DOCTRINE MASTERED (5/5)"
			btn.disabled = true
		else:
			var cost: int = prices[curr_rank]
			btn.set_meta("purchase_key", "perk:" + perk_key)
			btn.text = "TRAIN RANK %d — %d CR" % [curr_rank + 1, cost]
			btn.mouse_entered.connect(func():
				if has_node("/root/AudioManager"):
					get_node("/root/AudioManager").play_sfx("ui_hover")
			)
			btn.focus_entered.connect(func():
				if has_node("/root/AudioManager"):
					get_node("/root/AudioManager").play_sfx("ui_hover")
			)
			btn.pressed.connect(func():
				if pm.can_afford(cost):
					if pm.buy_perk(perk_key):
						if has_node("/root/AudioManager"):
							get_node("/root/AudioManager").play_sfx("ui_buy")
						refresh_ui()
				else:
					if has_node("/root/AudioManager"):
						get_node("/root/AudioManager").play_sfx("ui_denied")
					_flash_insufficient_funds(btn, cost)
			)
		vbox.add_child(btn)

		grid.add_child(panel)

# --- 3. ARMORY WEAPON MODS TAB ---
func _render_weapon_mods_tab(pm: Node) -> void:
	var desc_label = Label.new()
	desc_label.text = "Equip tactical ordnance variants per weapon. Select one active configuration per slot."
	desc_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	content_container.add_child(desc_label)

	for weapon_entry in WEAPON_MOD_METADATA:
		var w_type: int = weapon_entry["weapon_type"]
		var active_mod: int = pm.get_equipped_mod(w_type)

		var card = _create_card_container()
		var card_vbox = VBoxContainer.new()
		card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_vbox.add_theme_constant_override("separation", 10)
		card.add_child(card_vbox)

		# Weapon Name Header
		var w_lbl = Label.new()
		w_lbl.text = weapon_entry["weapon_name"]
		w_lbl.add_theme_font_size_override("font_size", 15)
		w_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		card_vbox.add_child(w_lbl)

		# Mod Options Row
		var mods_hbox = HBoxContainer.new()
		mods_hbox.add_theme_constant_override("separation", 14)
		card_vbox.add_child(mods_hbox)

		for mod in weapon_entry["mods"]:
			var mod_id: int = mod["id"]
			var is_equipped: bool = (mod_id == active_mod)

			var mod_box = VBoxContainer.new()
			mod_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mod_box.add_theme_constant_override("separation", 6)

			var m_title = Label.new()
			m_title.text = mod["name"]
			m_title.add_theme_font_size_override("font_size", 12)
			m_title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6) if is_equipped else Color(0.85, 0.88, 0.9))
			mod_box.add_child(m_title)

			var m_desc = Label.new()
			m_desc.text = mod["desc"]
			m_desc.add_theme_font_size_override("font_size", 10)
			m_desc.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
			m_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			m_desc.custom_minimum_size.y = 38
			mod_box.add_child(m_desc)

			var equip_btn = Button.new()
			equip_btn.custom_minimum_size = Vector2(0, 32)
			if is_equipped:
				equip_btn.text = "✓ EQUIPPED"
				equip_btn.disabled = true
			else:
				equip_btn.set_meta("purchase_key", "mod:" + str(w_type) + ":" + str(mod_id))
				equip_btn.text = "EQUIP MOD"
				equip_btn.mouse_entered.connect(func():
					if has_node("/root/AudioManager"):
						get_node("/root/AudioManager").play_sfx("ui_hover")
				)
				equip_btn.focus_entered.connect(func():
					if has_node("/root/AudioManager"):
						get_node("/root/AudioManager").play_sfx("ui_hover")
				)
				equip_btn.pressed.connect(func():
					pm.equip_mod(w_type, mod_id)
					if has_node("/root/AudioManager"):
						get_node("/root/AudioManager").play_sfx("ui_click")
					refresh_ui()
				)
			mod_box.add_child(equip_btn)

			mods_hbox.add_child(mod_box)

		content_container.add_child(card)

# --- 4. PILOT DOSSIER & RECORDS TAB ---
func _render_dossier_tab(pm: Node) -> void:
	var dossier_panel = _create_card_container()
	var d_vbox = VBoxContainer.new()
	d_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_vbox.add_theme_constant_override("separation", 10)
	dossier_panel.add_child(d_vbox)

	var d_title = Label.new()
	d_title.text = "PILOT CAREER DOSSIER & SORTIE ARCHIVE"
	d_title.add_theme_font_size_override("font_size", 16)
	d_title.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	d_vbox.add_child(d_title)

	var score_lbl = Label.new()
	score_lbl.text = "CAREER HIGH SCORE: %d PTS\nBANKED ACCUMULATED CREDITS: %d CR\nTACTICAL SALVAGE RESERVES: %d UNITS" % [
		pm.high_score, pm.banked_credits, pm.salvage
	]
	score_lbl.add_theme_font_size_override("font_size", 13)
	score_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	d_vbox.add_child(score_lbl)

	# Top High Scores Hall of Fame
	if pm.high_scores.size() > 0:
		var fame_header = Label.new()
		fame_header.text = "\n--- TOP SORTIE HIGH SCORES (HALL OF FAME) ---"
		fame_header.add_theme_font_size_override("font_size", 13)
		fame_header.add_theme_color_override("font_color", Color("ffd700"))
		d_vbox.add_child(fame_header)
		for entry in pm.get_top_high_scores(5):
			var h_lbl = Label.new()
			h_lbl.text = " #%d. %d PTS  |  %s  |  Wave %d  |  %d Kills  |  %s" % [
				entry.get("rank", 1), entry.get("score", 0), entry.get("aircraft", "APACHE"),
				entry.get("wave", 1), entry.get("kills", 0), entry.get("outcome", "KIA")
			]
			h_lbl.add_theme_font_size_override("font_size", 11)
			h_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 0.95))
			d_vbox.add_child(h_lbl)

	# Achievement Service Medals
	var ach_header = Label.new()
	ach_header.text = "\n--- AUTHORIZED DECORATIONS & CITATIONS ---"
	ach_header.add_theme_font_size_override("font_size", 13)
	ach_header.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	d_vbox.add_child(ach_header)

	var all_achievements = [
		{"id": "first_flight", "title": "AIR CADET", "desc": "Completed first operational deployment sortie."},
		{"id": "tank_buster", "title": "ARMOR DESTROYER", "desc": "Neutralized enemy flak tank or siege armor in combat."},
		{"id": "sam_suppression", "title": "RADAR WILDCAT", "desc": "Demolished hostile SAM site or radar installation."},
		{"id": "wave_5_survivor", "title": "SECTOR DEFENDER", "desc": "Successfully held tactical airspace through Wave 5."},
		{"id": "gunship_slayer", "title": "DREADNOUGHT SLAYER", "desc": "Downed the Wave 10 Heavy Gunship Boss."}
	]

	for ach in all_achievements:
		var is_unlocked = pm.unlocked_achievements.has(ach["id"])
		var a_lbl = Label.new()
		var prefix = "★ [AWARDED] " if is_unlocked else "☆ [LOCKED]   "
		a_lbl.text = "%s%s — %s" % [prefix, ach["title"], ach["desc"]]
		a_lbl.add_theme_font_size_override("font_size", 11)
		a_lbl.add_theme_color_override("font_color", Color(0.2, 0.95, 0.5) if is_unlocked else Color(0.5, 0.55, 0.6))
		d_vbox.add_child(a_lbl)

	content_container.add_child(dossier_panel)

# --- HELPER FUNCTIONS ---
func _create_card_container() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.14, 0.92)
	style.border_color = Color(0.22, 0.32, 0.40, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _format_stars(rank: int) -> String:
	var s = ""
	for i in 5:
		s += "★ " if i < rank else "☆ "
	return s.strip_edges() + (" (%d/5)" % [rank])

func _on_back_pressed() -> void:
	visible = false
	var origin := caller_origin
	caller_origin = "main_menu"
	var parent_menu = get_parent()
	if parent_menu and parent_menu.has_method("_update_wallet_display"):
		parent_menu._update_wallet_display()
	if origin == "vehicle_select" and parent_menu.has_node("VehicleSelectionMenu"):
		var selection = parent_menu.get_node("VehicleSelectionMenu")
		selection.visible = true
		selection.select_aircraft(selection.current_aircraft_idx)
		selection.armory_btn.grab_focus()
	elif parent_menu and parent_menu.has_node("VBoxContainer/StartBtn"):
		parent_menu.get_node("VBoxContainer/HangarBtn").grab_focus()
	hangar_closed.emit(origin)

func _flash_insufficient_funds(_button: Button = null, cost: int = 0) -> void:
	if wallet_label:
		if cost > 0:
			wallet_label.text = "INSUFFICIENT FUNDS! REQUIRED: %d CR" % cost
		else:
			wallet_label.text = "NOT ENOUGH CREDITS FOR THIS UPGRADE."
		wallet_label.add_theme_color_override("font_color", Color(1.0, 0.28, 0.25))
		var tween = create_tween()
		tween.tween_interval(1.6)
		tween.tween_callback(func():
			if is_instance_valid(wallet_label):
				wallet_label.remove_theme_color_override("font_color")
				var pm = get_node_or_null("/root/ProfileManager")
				if pm:
					wallet_label.text = "CURRENT AIRBASE CREDITS: %d CR" % pm.banked_credits
		)

func _restore_scroll(value: int) -> void:
	if visible:
		for button in content_container.find_children("*", "BaseButton", true, false):
			if not button.disabled and str(button.get_meta("purchase_key", "")) == _focus_restore_key and not _focus_restore_key.is_empty():
				button.grab_focus()
				break
		var focus := get_viewport().gui_get_focus_owner()
		if not focus or not focus.is_visible_in_tree() or focus.is_queued_for_deletion():
			tab_buttons[int(current_tab)].grab_focus()
	scroll_container.scroll_vertical = value

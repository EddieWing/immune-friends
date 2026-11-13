extends RefCounted
const FIELDS=["shop_rules","selected_rewards","max_funds","tuning","training_mode","experimental","pending_cells","battle_income","catalog","base_catalog","rules","cells","blood","blood_links","blood_velocity","blood_drag","blood_target","viruses","particles","effects","blasts","links","offers","rewards","reward_choices","events","event_sequence","presentation_revision","round_losses","round_no","target_rounds","money","tier","xp","frozen","phase","gym_mode","next_id","elapsed","source_emitters","spawn_timer","spawn_queue","infection_sources","source_center","wave","last_message","seed_value","web_core_normals"]
const PHYSICS=["rigid_membership","states","contacts","drives","settings","material_cache","material_settings","material_tuning","web_templates","web_template_dt","web_materials","web_material_ids","web_materials_dirty","contact_axes","cache_axes","stepping","settled_input","settled_hits"]
const BONDS=["groups","membership","prepared_links","prepared"]
const ELECTRICITY=["currents","step"]
static func deep_copy(v):
	if v is Dictionary or v is Array:return v.duplicate(true)
	if v is PackedFloat32Array or v is PackedFloat64Array or v is PackedInt32Array or v is PackedInt64Array or v is PackedVector2Array or v is PackedByteArray:return v.duplicate()
	return v
static func snapshot(s):
	var r={"fields":{},"physics":{},"bonds":{},"electricity":{},"rng_state":s.rng.state}
	for k in FIELDS:r.fields[k]=deep_copy(s.get(k))
	for k in PHYSICS:r.physics[k]=deep_copy(s.physics.get(k))
	for k in BONDS:r.bonds[k]=deep_copy(s.bonds.get(k))
	for k in ELECTRICITY:r.electricity[k]=deep_copy(s.electricity.get(k))
	return r
static func restore(s,r):
	for k in FIELDS:s.set(k,deep_copy(r.fields[k]))
	for k in PHYSICS:s.physics.set(k,deep_copy(r.physics[k]))
	for k in BONDS:s.bonds.set(k,deep_copy(r.bonds[k]))
	for k in ELECTRICITY:s.electricity.set(k,deep_copy(r.electricity[k]))
	s.rng.state=r.rng_state

class_name ZzMedievalSound
extends RefCounted

## Which dot-audio stock weapon sound a [signal ZzWeaponAnim.cue] name plays ([DotWeaponSound]).
## Null when the cue is silent by design or dot-audio is not linked; a game that wants its own
## audio connects the cue itself and sets [member ZzMedievalHeld.play_builtin_sounds] false.

const CUES := {
	&"swing_light": &"swing", &"swing_heavy": &"swing_heavy", &"bash": &"bash",
	&"hit_steel": &"melee_metal", &"hit_iron": &"melee_metal", &"hit_wood": &"impact_wood",
	&"hit_flesh": &"melee_flesh", &"draw": &"draw_blade", &"draw_full": &"bow_draw",
	&"bow_loose": &"bow_fire", &"bolt_fire": &"crossbow_fire",
	&"reload_start": &"crossbow_load", &"reload_done": &"crossbow_load",
}


static func stream_for(cue: StringName, weapon_id: StringName = &"") -> AudioStream:
	var sound: StringName = CUES.get(cue, &"")
	if sound == &"" and String(cue).begins_with("hit_"):
		sound = &"impact"
	# A bow or crossbow "draw" is the string, not a blade leaving a sheath.
	if cue == &"draw" and weapon_id in [&"bow", &"crossbow"]:
		sound = &"bow_draw" if weapon_id == &"bow" else &"crossbow_load"
	return DotWeaponSound.pick(sound, randi()) if sound != &"" else null

class_name EnemyTraits
extends RefCounted
## What makes one enemy different from the next. Every trait runs 0 to 1 and each
## enemy gets its own mix: an archetype sets the leanings (a rusher presses
## forward and leaves cover quickly, a marksman waits and aims, a cautious one
## lives behind cover, a hunter never loses you) and every enemy then varies
## around it.

enum Archetype { AUTO, GRUNT, RUSHER, SUPPRESSOR, CAUTIOUS, MARKSMAN, FLANKER, HUNTER }

## Per archetype: skill lean, aggression, caution, composure, cunning, patience, discipline.
const BASE := {
	Archetype.GRUNT: [0.4, 0.5, 0.45, 0.4, 0.3, 0.4, 0.4],
	Archetype.RUSHER: [0.45, 0.9, 0.15, 0.6, 0.3, 0.2, 0.3],
	Archetype.SUPPRESSOR: [0.45, 0.4, 0.5, 0.5, 0.2, 0.5, 0.2],
	Archetype.CAUTIOUS: [0.6, 0.25, 0.9, 0.5, 0.35, 0.7, 0.6],
	Archetype.MARKSMAN: [0.85, 0.2, 0.65, 0.7, 0.35, 0.9, 0.85],
	Archetype.FLANKER: [0.6, 0.6, 0.4, 0.55, 0.9, 0.45, 0.5],
	Archetype.HUNTER: [0.55, 0.8, 0.2, 0.7, 0.6, 0.5, 0.5],
}

var archetype := Archetype.GRUNT
## Aim quality, reaction speed.
var skill := 0.5
## Presses forward, fights closer, leaves cover sooner.
var aggression := 0.5
## Looks for cover, stays in it longer, backs off when hurt.
var caution := 0.5
## Keeps its head under fire: less flinch and pain.
var composure := 0.5
## Goes around instead of through.
var cunning := 0.5
## Waits: longer between peeks, longer in cover.
var patience := 0.5
## Tight, even bursts instead of sprays.
var discipline := 0.5
## Scales the range it likes to fight at.
var range_scale := 1.0
## How fast it walks, as a share of full speed.
var pace := 1.0
## Which way it likes to shuffle (-1 .. 1).
var strafe_bias := 0.0
## Charges the target instead of waiting for it: sprints in from afar and keeps
## closing. Only the aggressive ones do.
var rush := 0.0
## Where in its fighting range it likes to stand (0 = the near end, 1 = the far
## end), so a group spreads out over the range instead of piling up at one spot.
var lane := 0.5
## How far (metres) it always knows where you are, wherever you hide, climb or
## jump, and comes for you; 0 = only what it can see and hear. A hunter's is long.
var tracking := 0.0


static func roll(rng: RandomNumberGenerator, requested: Archetype, stats: WeaponStats, skill_range: Vector2) -> EnemyTraits:
	var traits := EnemyTraits.new()
	traits.archetype = requested if requested != Archetype.AUTO else _pick(rng, stats)

	var base: Array = BASE[traits.archetype]
	traits.skill = lerpf(skill_range.x, skill_range.y, _vary(rng, base[0]))
	traits.aggression = _vary(rng, base[1])
	traits.caution = _vary(rng, base[2])
	traits.composure = _vary(rng, base[3])
	traits.cunning = _vary(rng, base[4])
	traits.patience = _vary(rng, base[5])
	traits.discipline = _vary(rng, base[6])

	traits.range_scale = lerpf(1.2, 0.8, traits.aggression) * rng.randf_range(0.92, 1.08)
	traits.pace = rng.randf_range(0.8, 1.0)
	traits.strafe_bias = rng.randf_range(-1.0, 1.0)
	traits.rush = clampf((traits.aggression - 0.55) / 0.35, 0.0, 1.0)
	traits.lane = rng.randf() * lerpf(1.0, 0.5, traits.aggression)
	traits.tracking = 35.0 if traits.archetype == Archetype.HUNTER else 0.0
	return traits


static func _vary(rng: RandomNumberGenerator, centre: float) -> float:
	return clampf(centre + rng.randfn(0.0, 0.12), 0.0, 1.0)


## Which archetypes suit the gun, weighted.
static func _pick(rng: RandomNumberGenerator, stats: WeaponStats) -> Archetype:
	var weights: Dictionary
	if stats.pellets > 1:
		weights = { Archetype.RUSHER: 0.45, Archetype.FLANKER: 0.2, Archetype.GRUNT: 0.2, Archetype.CAUTIOUS: 0.15 }
	elif stats.manual_cycle:
		weights = { Archetype.MARKSMAN: 0.6, Archetype.CAUTIOUS: 0.3, Archetype.GRUNT: 0.1 }
	elif stats.automatic:
		weights = {
			Archetype.SUPPRESSOR: 0.2,
			Archetype.RUSHER: 0.2,
			Archetype.GRUNT: 0.2,
			Archetype.CAUTIOUS: 0.15,
			Archetype.FLANKER: 0.15,
			Archetype.HUNTER: 0.1,
		}
	else:
		weights = {
			Archetype.GRUNT: 0.3,
			Archetype.CAUTIOUS: 0.25,
			Archetype.RUSHER: 0.2,
			Archetype.FLANKER: 0.15,
			Archetype.MARKSMAN: 0.1,
		}

	var roll := rng.randf()
	for key: Archetype in weights:
		roll -= weights[key]
		if roll <= 0.0:
			return key

	return Archetype.GRUNT

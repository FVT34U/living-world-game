class_name AttributeConsequenceSystem
extends System

## The game-domain rules addons/attributes deliberately doesn't know about,
## applied uniformly to every settler and animal that carries an
## AttributeSet - the same code path regardless of which kind of character
## it is, matching the addon's "player or NPC, it doesn't care" design:
##
## - attrs.tick(delta) applies every attribute's own passive drift
##   (Satiety fading, Energy idly recovering, Age always climbing).
## - Starving (Satiety at 0), exhausted (Energy at 0), or old (Age past
##   OLD_AGE_THRESHOLD) all drain Health - none of those three conditions is
##   fatal by itself, but sustained neglect eventually is.
## - Happiness drifts toward how well Satiety/Energy/Health are currently
##   doing, rather than being driven by any single event.
## - Health reaching 0 is fatal - Game.despawn_entity() handles a settler
##   and an animal identically.

const STARVING_HEALTH_DRAIN := 2.0
const EXHAUSTED_HEALTH_DRAIN := 2.0
const OLD_AGE_HEALTH_DRAIN := 0.5
const OLD_AGE_THRESHOLD := 900.0  # ~15 minutes - a real mechanic, not a near-term inevitability
const HAPPINESS_LERP_SPEED := 0.05

var _buf: Array[int] = []

func _init() -> void:
	super._init(-5, System.Phase.PROCESS)

func update(world: ECSWorld, delta: float) -> void:
	world.query_into([Game.ATTRIBUTES_TYPE], _buf)
	for e in _buf:
		var attrs: AttributeSet = world.get_component(e, Game.ATTRIBUTES_TYPE)
		attrs.tick(delta)

		if attrs.get_value(Game.SATIETY_ATTR) <= 0.0:
			attrs.add_value(Game.HEALTH_ATTR, -STARVING_HEALTH_DRAIN * delta)
		if attrs.get_value(Game.ENERGY_ATTR) <= 0.0:
			attrs.add_value(Game.HEALTH_ATTR, -EXHAUSTED_HEALTH_DRAIN * delta)
		if attrs.get_value(Game.AGE_ATTR) >= OLD_AGE_THRESHOLD:
			attrs.add_value(Game.HEALTH_ATTR, -OLD_AGE_HEALTH_DRAIN * delta)

		var wellbeing := (
			attrs.get_ratio(Game.SATIETY_ATTR) + attrs.get_ratio(Game.ENERGY_ATTR) + attrs.get_ratio(Game.HEALTH_ATTR)
		) / 3.0
		var current_happiness := attrs.get_value(Game.HAPPINESS_ATTR)
		attrs.set_value(Game.HAPPINESS_ATTR, lerpf(current_happiness, wellbeing * 100.0, HAPPINESS_LERP_SPEED))

		if attrs.get_value(Game.HEALTH_ATTR) <= 0.0:
			Game.despawn_entity(world, e)

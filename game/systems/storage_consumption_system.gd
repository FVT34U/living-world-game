class_name StorageConsumptionSystem
extends System

## Slowly drains every StorageComponent so stockpiles don't just grow forever
## - a stand-in for "the settlement eats/burns what's gathered" without
## modeling individual settlers' meals, except for the meat half: whenever
## meat is actually available to consume, every settler's own Satiety
## attribute (addons/attributes) gets refilled a bit, so a settlement that
## runs out of meat visibly leaves its settlers hungrier rather than the
## consumption staying purely abstract. Wood has no such hook - it isn't food.
##
## The drain rate scales with the settler population (gently - one settler
## eats a quarter of a unit per tick, rounded up, not a whole unit each) so
## a bigger settlement visibly consumes faster without outpacing what a
## handful of woodcutters/hunters can actually gather.

const CONSUME_INTERVAL := 6.0  # seconds between consumption ticks
const SETTLERS_PER_UNIT := 4
const SETTLER_FEED_AMOUNT := 20.0

var _timer: float = 0.0
var _settler_buf: Array[int] = []
var _storage_buf: Array[int] = []

func _init() -> void:
	super._init(12, System.Phase.PROCESS)

func update(world: ECSWorld, delta: float) -> void:
	_timer += delta
	if _timer < CONSUME_INTERVAL:
		return
	_timer = 0.0

	world.query_into([Game.SETTLER_ROLE_TYPE], _settler_buf)
	var amount := maxi(1, ceili(float(_settler_buf.size()) / SETTLERS_PER_UNIT))

	world.query_into([Game.STORAGE_TYPE], _storage_buf)
	var meat_consumed := 0
	for e in _storage_buf:
		var s: StorageComponent = world.get_component(e, Game.STORAGE_TYPE)
		s.consume(Game.WOOD_RESOURCE.id, amount)
		meat_consumed += s.consume(Game.MEAT_RESOURCE.id, amount)

	if meat_consumed <= 0:
		return
	for e in _settler_buf:
		if world.has_component(e, Game.ATTRIBUTES_TYPE):
			(world.get_component(e, Game.ATTRIBUTES_TYPE) as AttributeSet).add_value(Game.SATIETY_ATTR, SETTLER_FEED_AMOUNT)

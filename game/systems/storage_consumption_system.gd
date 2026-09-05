class_name StorageConsumptionSystem
extends System

## Slowly drains every StorageComponent so stockpiles don't just grow forever
## - a stand-in for "the settlement eats/burns what's gathered" without
## modeling individual settlers' meals. The drain rate scales with the
## settler population (gently - one settler eats a quarter of a unit per
## tick, rounded up, not a whole unit each) so a bigger settlement visibly
## consumes faster without outpacing what a handful of woodcutters/hunters
## can actually gather.

const CONSUME_INTERVAL := 6.0  # seconds between consumption ticks
const SETTLERS_PER_UNIT := 4

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
	for e in _storage_buf:
		var s: StorageComponent = world.get_component(e, Game.STORAGE_TYPE)
		s.consume(Game.WOOD_RESOURCE.id, amount)
		s.consume(Game.MEAT_RESOURCE.id, amount)

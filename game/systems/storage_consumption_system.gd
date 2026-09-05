class_name StorageConsumptionSystem
extends System

## Slowly drains every StorageComponent so stockpiles don't just grow forever
## - a stand-in for "the settlement eats/burns what's gathered" without
## modeling individual settlers' meals. The drain rate scales with the
## settler population so a bigger settlement visibly consumes faster.

const CONSUME_INTERVAL := 4.0  # seconds between consumption ticks
const AMOUNT_PER_SETTLER := 1

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
	var settlers := maxi(_settler_buf.size(), 1)

	world.query_into([Game.STORAGE_TYPE], _storage_buf)
	for e in _storage_buf:
		var s: StorageComponent = world.get_component(e, Game.STORAGE_TYPE)
		s.consume(Game.WOOD_RESOURCE.id, settlers * AMOUNT_PER_SETTLER)
		s.consume(Game.MEAT_RESOURCE.id, settlers * AMOUNT_PER_SETTLER)

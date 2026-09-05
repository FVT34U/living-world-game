class_name StorageLabelSystem
extends System

## Keeps a storage building's label showing its live wood/meat stock against
## capacity, so deposits (GoapPlanningSystem/DepositResourceAction) and
## gradual consumption (StorageConsumptionSystem) are both visible at a
## glance.

var _buf: Array[int] = []

func _init() -> void:
	super._init(22, System.Phase.PROCESS)

func update(world: ECSWorld, _delta: float) -> void:
	world.query_into([Game.STORAGE_TYPE, Game.NODE_REF_TYPE], _buf)
	for e in _buf:
		var node_ref: NodeRefComponent = world.get_component(e, Game.NODE_REF_TYPE)
		if node_ref.label == null:
			continue
		var s: StorageComponent = world.get_component(e, Game.STORAGE_TYPE)
		node_ref.label.text = "Wood %d/%d\nMeat %d/%d" % [
			s.get_amount(Game.WOOD_RESOURCE.id), s.capacity,
			s.get_amount(Game.MEAT_RESOURCE.id), s.capacity,
		]

class_name PlantRegrowSystem
extends System

## Counts down each eaten plant's regrow_timer and brings it back once it
## reaches zero - the other half of EatPlantAction's consume step.

var _buf: Array[int] = []

func _init() -> void:
	super._init(11, System.Phase.PROCESS)

func update(world: ECSWorld, delta: float) -> void:
	world.query_into([Game.PLANT_TYPE], _buf)
	for e in _buf:
		var p: PlantComponent = world.get_component(e, Game.PLANT_TYPE)
		if p.alive:
			continue
		p.regrow_timer -= delta
		if p.regrow_timer > 0.0:
			continue
		p.alive = true
		if world.has_component(e, Game.NODE_REF_TYPE):
			var node_ref: NodeRefComponent = world.get_component(e, Game.NODE_REF_TYPE)
			if is_instance_valid(node_ref.node):
				node_ref.node.visible = true

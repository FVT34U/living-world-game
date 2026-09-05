class_name StatusLabelSystem
extends System

## Copies each GOAP agent's currently-running action name (or "idle" between
## plans) onto its NodeRefComponent.label, so the demo visibly shows which
## action - and by extension which of the three addons' work - is driving
## each settler/animal at any moment.

var _buf: Array[int] = []

func _init() -> void:
	super._init(21, System.Phase.PROCESS)

func update(world: ECSWorld, _delta: float) -> void:
	world.query_into([Game.GOAP_AGENT_TYPE, Game.NODE_REF_TYPE], _buf)
	for e in _buf:
		var node_ref: NodeRefComponent = world.get_component(e, Game.NODE_REF_TYPE)
		if node_ref.label == null:
			continue
		var agent: GoapAgent = (world.get_component(e, Game.GOAP_AGENT_TYPE) as GoapAgentComponent).agent
		var text := "idle"
		if agent.current_action_index >= 0 and agent.current_action_index < agent.current_plan.size():
			text = agent.current_plan[agent.current_action_index].action_name
		node_ref.label.text = text

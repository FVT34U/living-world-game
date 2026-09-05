class_name SettlerRoleComponent
extends RefCounted

## Cosmetic/bookkeeping tag (&"woodcutter" / &"hunter") used by the dev panel
## and StorageConsumptionSystem's population count. The actual behavior comes
## entirely from which goals/actions EntityFactory.spawn_settler() assigns
## the entity's GoapAgent - this component doesn't drive planning itself.

var role: StringName = &""

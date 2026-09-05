class_name PlantComponent
extends RefCounted

## A foraging spot an animal can eat from. Unlike an animal, an eaten plant
## isn't destroyed - it goes inert (alive=false, hidden) and regrows after
## regrow_timer counts down to zero (see PlantRegrowSystem), so the same
## plant entity can be eaten repeatedly over a long play session.

var alive: bool = true
var regrow_timer: float = 0.0

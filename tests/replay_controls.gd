extends "res://src/controls.gd"
## Injects post-deadzone action strengths; production response/command path is retained.
var injected: Dictionary = {}
func strength(action: String) -> float:
 return float(injected.get(action, 0.0))

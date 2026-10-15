class_name InteractionProvider
extends RefCounted
## Capability instance; the controller validates physical access before begin/complete.
var definition: InteractionDefinition
var stock := 0
var active := true
var _users: Dictionary = {}
func _init(config: InteractionDefinition = null) -> void:
	definition = config
	if config != null: stock = config.initial_stock
func available() -> bool:
	return active and stock != 0 and _users.size() < definition.capacity and (stock < 0 or _users.size() < stock)
func begin(actor: int) -> bool:
	if actor <= 0: return false
	if _users.has(actor): return true
	if not available(): return false
	_users[actor] = true
	return true
func has_user(actor: int) -> bool:
	return _users.has(actor)
func cancel_all() -> void:
	_users.clear()
func cancel(actor: int) -> void:
	_users.erase(actor)
func complete(actor: int) -> Dictionary:
	if not active or not _users.has(actor) or stock == 0: return {}
	_users.erase(actor)
	if stock > 0: stock -= 1
	return definition.effects()
func invalidate() -> void:
	active = false
	_users.clear()
func observation() -> Dictionary:
	return {"interaction": definition.interaction_id, "duration": definition.duration,
		"effects": definition.effects(), "available": available()}

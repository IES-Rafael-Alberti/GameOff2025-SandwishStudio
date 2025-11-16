extends Resource
class_name PassiveData

enum PassiveType {
	HEALTH_INCREASE,
	CRITICAL_DAMAGE_INCREASE,
	CRITICAL_CHANCE_INCREASE,
	ATTACK_SPEED_INCREASE,
	BASE_DAMAGE_INCREASE
}

@export var type: PassiveType
@export var value: float
@export var name_passive: String
@export_multiline var description: String
@export var icon: Texture2D
@export var price: int

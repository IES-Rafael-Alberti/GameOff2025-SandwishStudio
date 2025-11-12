extends Resource

class_name PieceRes

enum Race { NORDICA, JAPONESA, EUROPEA }
enum Tier { COMUN, RARO, EPICO, LEGENDARIO }

@export var id: String = ""
@export var display_name: String = ""
@export var Race: Race 
@export var Tier: Tier

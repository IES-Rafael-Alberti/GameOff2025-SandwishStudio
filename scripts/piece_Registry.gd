extends Node
class_name PieceRegistry

var _map := {
	"europea.satiro": "res://resources/Europea/satiro.tres",
	"europea.duende": "res://resources/Europea/Duende.tres",
	"europea.banshie": "res://resources/Europea/banshie.tres",
	"europea.dragon": "res://resources/Europea/dragon.tres",
	"nordica.draugr": "res://resources/Nordica/Draugr.tres",
	"nordica.valkirias": "res://resources/Nordica/valkirias.tres",
	"nordica.nornas": "res://resources/Nordica/Nornas.tres",
	"nordica.jotun": "res://resources/Nordica/Jotun.tres",
	"japonesa.kappa": "res://resources/Japonesa/Kappa.tres",
	"japonesa.hitotsume_kozo": "res://resources/Japonesa/Hitotsume_kozo.tres",
	"japonesa.tengu": "res://resources/Japonesa/tengu.tres",
	"japonesa.oni": "res://resources/Japonesa/oni.tres",
}

func get_piece(id: String) -> PieceRes:
	var p := _map.get(id, "") as String
	return load(p) if p != "" else null

# Funcion temporal para hacer pruebas
func get_random_piece() -> PieceRes:
	var ids: Array = _map.keys()
	if ids.is_empty():
		return null

	var index: int = randi() % ids.size()
	var id: String = String(ids[index])

	return get_piece(id)

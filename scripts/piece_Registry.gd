extends Node
class_name PieceRegistry

var _map := {
	"european.satiro": "res://resources/Europea/atiro.tres",
	"european.duende": "res://resources/Europea/Duende.tres",
	"european.banshie": "res://resources/Europea/banshie.tres",
	"european.dragon": "res://resources/Europea/dragon.tres",
	"nordic.draugr": "res://resources/Nordica/Draugr.tres",
	"nordic.valkirias": "res://resources/Nordica/valkirias.tres",
	"nordic.nornas": "res://resources/Nordica/Nornas.tres",
	"nordic.jotun": "res://resources/Nordica/Jotun.tres",
	"japanese.kappa": "res://resources/Japonesa/Kappa.tres",
	"japanese.hitotsume_kozo": "res://resources/Japonesa/Hitotsume_kozo.tres",
	"japanese.tengu": "res://resources/Japonesa/tengu.tres",
	"japanese.oni": "res://resources/Japonesa/oni.tres",
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

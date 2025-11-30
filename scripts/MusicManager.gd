extends Node

# --- CONFIGURACIÓN DE PISTAS (RUTAS) ---
const TRACK_MENU = "res://assets/audios/Music/MusicMainMenu.wav"
const TRACK_GAMEPLAY = "res://assets/audios/Music/MainMusicGameplay.wav"
const TRACK_DAY_FINISHED = "res://assets/audios/Music/GoodEndingMusic.wav"
const TRACK_WIN = "res://assets/audios/Music/GoodEndingMusic.wav"
const TRACK_LOSE = "res://assets/audios/Music/BadEnding-Short.wav"

# --- CONFIGURACIÓN DE VOLÚMENES ---
const VOL_MENU = -15.0
const VOL_GAMEPLAY = -25.0
const VOL_DAY_FINISHED = -3.0
const VOL_WIN = 0.0
const VOL_LOSE = 0.0

# Duración del fundido (mezcla) en segundos
const CROSSFADE_DURATION: float = 2.0

# --- VARIABLES INTERNAS ---
var _player_1: AudioStreamPlayer
var _player_2: AudioStreamPlayer
var _active_player_idx: int = 1
var _current_tween: Tween
var _streams: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_streams()
	_player_1 = _create_player("MusicPlayer1")
	_player_2 = _create_player("MusicPlayer2")

func _load_streams() -> void:
	# Carga estándar
	_streams["menu"] = load(TRACK_MENU) if ResourceLoader.exists(TRACK_MENU) else null
	_streams["gameplay"] = load(TRACK_GAMEPLAY) if ResourceLoader.exists(TRACK_GAMEPLAY) else null
	_streams["day_finished"] = load(TRACK_DAY_FINISHED) if ResourceLoader.exists(TRACK_DAY_FINISHED) else null
	_streams["win"] = load(TRACK_WIN) if ResourceLoader.exists(TRACK_WIN) else null
	_streams["lose"] = load(TRACK_LOSE) if ResourceLoader.exists(TRACK_LOSE) else null
	
	# --- NUEVO: FORZAR LOOP EN TODAS LAS PISTAS CARGADAS ---
	for key in _streams:
		if _streams[key] != null:
			_force_loop(_streams[key])
func _create_player(p_name: String) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	p.name = p_name
	p.bus = "Music"
	add_child(p)
	return p

# --- FUNCIONES PÚBLICAS DE CONTROL ---

func play_menu() -> void:
	_crossfade_to(_streams["menu"], VOL_MENU)

func play_gameplay() -> void:
	_crossfade_to(_streams["gameplay"], VOL_GAMEPLAY)

func play_day_finished() -> void:
	_crossfade_to(_streams["day_finished"], VOL_DAY_FINISHED)

func play_win() -> void:
	_crossfade_to(_streams["win"], VOL_WIN)

func play_lose() -> void:
	_crossfade_to(_streams["lose"], VOL_LOSE)

func stop_music() -> void:
	_crossfade_to(null, -80.0)

# --- SISTEMA DE MEZCLA (CROSSFADE) ---

func _crossfade_to(new_stream: AudioStream, target_db: float = 0.0) -> void:
	var outgoing_player = _player_1 if _active_player_idx == 1 else _player_2
	var incoming_player = _player_2 if _active_player_idx == 1 else _player_1
	
	if outgoing_player.playing and outgoing_player.stream == new_stream:
		return
	
	if _current_tween:
		_current_tween.kill()
	_current_tween = create_tween().set_parallel(true)
	
	# Fade Out
	if outgoing_player.playing:
		_current_tween.tween_property(outgoing_player, "volume_db", -80.0, CROSSFADE_DURATION).set_ease(Tween.EASE_IN)
	
	# Fade In
	if new_stream:
		incoming_player.stream = new_stream
		incoming_player.volume_db = -80.0 
		incoming_player.play()
		_current_tween.tween_property(incoming_player, "volume_db", target_db, CROSSFADE_DURATION).set_ease(Tween.EASE_OUT)
		_active_player_idx = 2 if _active_player_idx == 1 else 1
	
	_current_tween.chain().tween_callback(func():
		outgoing_player.stop()
	)
func _force_loop(stream: AudioStream) -> void:
	# --- CORRECCIÓN PARA ARCHIVOS .WAV ---
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		
		# Si el punto final del loop es 0, calculamos la longitud real del audio
		if stream.loop_end == 0:
			var bytes_per_sample = 1 # Por defecto 8 bits
			
			# Ajustamos si es 16 bits (lo estándar en música)
			if stream.format == AudioStreamWAV.FORMAT_16_BITS:
				bytes_per_sample = 2
			
			# Ajustamos según si es Mono (1) o Estéreo (2)
			var channels = 2 if stream.stereo else 1
			
			# Calculamos: Tamaño total / (Bytes por muestra * Canales)
			# Esto nos da el número exacto de samples donde termina la canción
			stream.loop_end = stream.data.size() / (bytes_per_sample * channels)

	# --- PARA ARCHIVOS .OGG (Más sencillo) ---
	elif stream is AudioStreamOggVorbis:
		stream.loop = true

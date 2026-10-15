extends Node2D

# --- NODOS DE SCREEN MENU ---
@onready var screen_menu: VBoxContainer = $UI/ScreenMenu
@onready var input_nombre: LineEdit = $UI/ScreenMenu/InputName
@onready var btn_create: Button = $UI/ScreenMenu/BtnCreateLobby
@onready var input_codigo: LineEdit = $UI/ScreenMenu/JoinRow/CodeInput
@onready var btn_join: Button = $UI/ScreenMenu/JoinRow/BtnJoinLobby

# --- NODOS DE SCREEN LOBBY ---
@onready var screen_lobby: VBoxContainer = $UI/ScreenLobby
@onready var label_lobby_info: Label = $UI/ScreenLobby/CodeRow/LabelLobbyInfo
@onready var btn_copiar_codigo: Button = $UI/ScreenLobby/CodeRow/BtnCopyCode
@onready var lista_players: ItemList = $UI/ScreenLobby/PlayersList

var eos: EOSManager
var peer: EOSMultiplayerPeer
var current_lobby_id: String = ""
var codigo_sala_actual: String = ""

# Diccionario sincronizado entre todos: { peer_id : {"nombre": String, "puid": String} }
var players_conectados: Dictionary = {}

const SOCKET_NAME := "GameSocket"

func _ready() -> void:
	randomize()
	input_nombre.text = "Player_" + str(randi() % 900 + 100)
	
	screen_menu.visible = true
	screen_lobby.visible = false
	btn_create.disabled = true
	btn_join.disabled = true
	
	# 1. Instanciar EOSManager
	eos = EOSManager.new()
	add_child(eos)
	
	# 2. Conectar señales de EOS
	eos.login_completed.connect(_on_login_completed)
	eos.lobby_created.connect(_on_lobby_created)
	eos.lobbies_found.connect(_on_lobbies_found)
	eos.lobby_joined.connect(_on_lobby_joined)
	eos.lobby_member_status_changed.connect(_on_lobby_member_status_changed)
	
	# 3. Conectar señales de red de Godot
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	# 4. Conectar botones de la UI
	btn_create.pressed.connect(_on_create_pressed)
	btn_join.pressed.connect(_on_join_pressed)
	btn_copiar_codigo.pressed.connect(_on_copiar_codigo_pressed)
	
	# 5. Inicializar EOS leyendo res://.env
	var config := EOSEnvLoader.load_env("res://.env")
	if eos.initialize_eos(config):
		eos.login_anonymous(input_nombre.text)
	else:
		print("ERROR: No se pudo inicializar EOS. Verifica res://.env")

# --- LOGIN INICIAL ---
func _on_login_completed(success: bool, puid: String, error_msg: String) -> void:
	if success:
		print("Login exitoso! Mi PUID: ", puid)
		btn_create.disabled = false
		btn_join.disabled = false
	else:
		print("Error en Login: ", error_msg)

# --- CREAR LOBBY (GENERA UN CÓDIGO DE 6 CARACTERES) ---
func _generar_codigo_corto() -> String:
	const CARACTERES := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var codigo := ""
	for i in range(6):
		codigo += CARACTERES[randi() % CARACTERES.length()]
	return codigo

func _on_create_pressed() -> void:
	btn_create.disabled = true
	btn_join.disabled = true
	
	codigo_sala_actual = _generar_codigo_corto()
	print("Creando lobby con código: ", codigo_sala_actual)
	# Usamos codigo_sala_actual como el bucket_id en Epic (Max 5 jugadores)
	eos.create_lobby(5, codigo_sala_actual, true)

func _on_lobby_created(success: bool, lobby_id: String, error_msg: String) -> void:
	if success:
		current_lobby_id = lobby_id
		peer = EOSMultiplayerPeer.new()
		peer.create_host(SOCKET_NAME)
		multiplayer.multiplayer_peer = peer
		
		_registrar_jugador_local()
		_mostrar_screen_lobby("CÓDIGO DE SALA: " + codigo_sala_actual + " (Eres el Host)")
	else:
		print("Error al crear lobby: ", error_msg)
		btn_create.disabled = false
		btn_join.disabled = false

# --- UNIRSE A LOBBY CON EL CÓDIGO ---
func _on_join_pressed() -> void:
	var codigo_ingresado := input_codigo.text.strip_edges().to_upper()
	if codigo_ingresado.is_empty():
		print("Escribe un código de lobby primero.")
		return
	
	codigo_sala_actual = codigo_ingresado
	btn_create.disabled = true
	btn_join.disabled = true
	print("Buscando lobby con código: ", codigo_sala_actual)
	eos.search_lobbies(codigo_sala_actual)

func _on_lobbies_found(lobbies: Array) -> void:
	if lobbies.is_empty():
		print("No existe ningún lobby con el código: ", codigo_sala_actual)
		btn_create.disabled = false
		btn_join.disabled = false
		return
	
	# Como filtramos por el código único, tomamos el lobby encontrado y entramos directo
	var lobby_destino: Dictionary = lobbies[0]
	eos.join_lobby(lobby_destino["lobby_id"])

func _on_lobby_joined(success: bool, lobby_id: String, owner_puid: String, error_msg: String) -> void:
	if success:
		current_lobby_id = lobby_id
		peer = EOSMultiplayerPeer.new()
		peer.create_client(owner_puid, SOCKET_NAME)
		multiplayer.multiplayer_peer = peer
		
		_registrar_jugador_local()
		_mostrar_screen_lobby("CÓDIGO DE SALA: " + codigo_sala_actual + " (Conectado)")
	else:
		print("Error al unirse al lobby: ", error_msg)
		btn_create.disabled = false
		btn_join.disabled = false

# --- PANTALLA DEL LOBBY, COPIAR CÓDIGO Y LISTA DE JUGADORES ---
func _mostrar_screen_lobby(titulo: String) -> void:
	screen_menu.visible = false
	screen_lobby.visible = true
	label_lobby_info.text = titulo
	_refrescar_ui_lista()

func _on_copiar_codigo_pressed() -> void:
	DisplayServer.clipboard_set(codigo_sala_actual)
	btn_copiar_codigo.text = "¡Copiado!"
	await get_tree().create_timer(1.5).timeout
	btn_copiar_codigo.text = "Copiar Código"

func _registrar_jugador_local() -> void:
	var nombre_elegido := input_nombre.text.strip_edges()
	if nombre_elegido.is_empty():
		nombre_elegido = "SinNombre"
	players_conectados[multiplayer.get_unique_id()] = {
		"nombre": nombre_elegido,
		"puid": eos.get_local_product_user_id()
	}

func _on_peer_connected(nuevo_peer_id: int) -> void:
	# En cuanto el túnel P2P conecta con un amigo, le enviamos nuestro nombre y PUID
	var mi_info: Dictionary = players_conectados[multiplayer.get_unique_id()]
	rpc_id(nuevo_peer_id, "recibir_datos_jugador", mi_info["nombre"], mi_info["puid"])

func _on_peer_disconnected(peer_id_saliente: int) -> void:
	players_conectados.erase(peer_id_saliente)
	_refrescar_ui_lista()

func _on_lobby_member_status_changed(_lobby_id: String, _member_puid: String, _status: int) -> void:
	_refrescar_ui_lista()

@rpc("any_peer", "reliable")
func recibir_datos_jugador(nombre: String, puid: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	players_conectados[sender_id] = {
		"nombre": nombre,
		"puid": puid
	}
	_refrescar_ui_lista()

func _refrescar_ui_lista() -> void:
	lista_players.clear()
	for peer_id in players_conectados.keys():
		var info: Dictionary = players_conectados[peer_id]
		var rol := " [HOST]" if peer_id == 1 else ""
		var yo := " (TÚ)" if peer_id == multiplayer.get_unique_id() else ""
		var fila := "%s%s%s  —  PeerID: %d | PUID: %s..." % [
			info["nombre"], rol, yo, peer_id, str(info["puid"]).substr(0, 8)
		]
		lista_players.add_item(fila)

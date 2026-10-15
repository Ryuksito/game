# Referencia de API y Guía de Uso: `eos-godot`

Addon nativo en C++ para Godot 4.7 basado en **GDExtension** y el **SDK oficial de Epic Online Services (EOS) v1.19.2.1**.

Provee autenticación anónima por Device ID, administración de lobbies para 1 a 5 jugadores y transporte de red P2P totalmente integrado con el sistema de multijugador (`@rpc`) de Godot.

---

## 1. Clase `EOSManager` (Hereda de `Node`)

Gestiona el ciclo de vida de la plataforma EOS, la autenticación y las operaciones de lobbies.

### Métodos
| Método | Retorno | Descripción |
| :--- | :--- | :--- |
| `get_eos_version()` | `String` | Retorna la versión del SDK de Epic enlazado (ej. `1.19.2.1-58105819`). |
| `initialize_eos(config: Dictionary)` | `bool` | Inicializa el SDK y la plataforma de EOS usando las credenciales dinámicas provistas en el diccionario. Configura Relay automático para CGNAT. |
| `shutdown_eos()` | `void` | Libera la plataforma, búsquedas activas, lobbies en caché y apaga el SDK de EOS de forma segura e idempotente. |
| `login_anonymous(display_name: String)` | `void` | Inicia el flujo de autenticación anónima mediante `Device ID`. Si el usuario no existe en EOS Connect, se crea automáticamente. |
| `get_local_product_user_id()` | `String` | Retorna el `ProductUserId` (PUID) local en formato texto hexadecimal, o cadena vacía si no está autenticado. |
| `create_lobby(max_players: int, bucket_id: String, is_public: bool)` | `void` | Crea un lobby en EOS limitando los cupos entre 1 y 5 jugadores (`std::clamp`). Publica automáticamente el atributo público `"BUCKET"` para indexación en búsquedas. |
| `search_lobbies(bucket_id: String)` | `void` | Busca hasta 25 lobbies públicos activos que coincidan exactamente con el `bucket_id` (o si se pasa un ID de lobby de 32 caracteres, filtra directamente por Lobby ID). Cachea los `EOS_HLobbyDetails` para permitir unirse de inmediato. |
| `join_lobby(lobby_id: String)` | `void` | Se une al lobby indicado consumiendo el detalle previamente cacheado por `search_lobbies`. Si no se encuentra en caché local, realiza automáticamente un fallback a `join_lobby_by_id`. |
| `join_lobby_by_id(lobby_id: String)` | `void` | Se une directamente a un lobby usando su `lobby_id` único sin requerir búsqueda previa en caché (soporta `bEnableJoinById = EOS_TRUE`). |
| `leave_lobby(lobby_id: String)` | `void` | Abandona el lobby activo y limpia la referencia interna. |
| `get_lobby_members(lobby_id: String)` | `Array[String]` | Retorna un arreglo con los `ProductUserId` en texto de todos los miembros actualmente conectados al lobby. |
| `get_lobby_owner_puid(lobby_id: String)` | `String` | Retorna el `ProductUserId` del anfitrión (host / owner) del lobby. |
| `get_current_lobby_id()` | `String` | Retorna el identificador del lobby en el que se encuentra el jugador actualmente. |

### Señales
| Señal | Parámetros | Descripción |
| :--- | :--- | :--- |
| `login_completed` | `success: bool, product_user_id: String, error_message: String` | Se emite cuando el login con Device ID finaliza con éxito o error. |
| `lobby_created` | `success: bool, lobby_id: String, error_message: String` | Se emite al completar la creación y publicación del atributo `"BUCKET"` del lobby. |
| `lobbies_found` | `lobbies: Array[Dictionary]` | Retorna los lobbies encontrados. Cada elemento contiene: `lobby_id`, `owner_puid`, `available_slots`, `max_members`. |
| `lobby_joined` | `success: bool, lobby_id: String, owner_puid: String, error_message: String` | Se emite al ingresar a un lobby existente, entregando el PUID del host. |
| `lobby_left` | `success: bool, lobby_id: String` | Se emite al salir del lobby. |
| `lobby_member_status_changed` | `lobby_id: String, member_puid: String, status: int` | Se emite cuando un miembro entra, sale o se desconecta (`EOS_ELobbyMemberStatus`). |

---

## 2. Clase `EOSMultiplayerPeer` (Hereda de `MultiplayerPeerExtension`)

Implementación nativa de red P2P que se conecta directamente a la arquitectura multijugador de alto nivel de Godot (`multiplayer.multiplayer_peer`).

### Métodos
| Método | Retorno | Descripción |
| :--- | :--- | :--- |
| `create_host(socket_name: String = "GameSocket")` | `Error` | Configura el peer como Host (`unique_id = 1`), registra listeners P2P y abre el socket de escucha. Retorna `OK` (`0`) en éxito. |
| `create_client(host_puid_str: String, socket_name: String = "GameSocket")` | `Error` | Configura el peer como Cliente, genera un ID determinista (`unique_id >= 2`), registra al host como peer 1, envía un paquete de apertura de túnel (handshake) por el canal 255 y emite `peer_connected(1)`. |
| `get_peer_id_from_puid(puid_str: String)` | `int` | Retorna el `peer_id` (int32) numérico de Godot asociado al `ProductUserId` de EOS indicado. |
| `get_puid_from_peer_id(peer_id: int)` | `String` | Retorna el `ProductUserId` en texto correspondiente al `peer_id` numérico de Godot. |

### Señales Heredadas de `MultiplayerPeer`
- `peer_connected(id: int)`: Se dispara cuando un nuevo jugador se conecta al socket P2P.
- `peer_disconnected(id: int)`: Se dispara cuando un jugador se desconecta o cierra la sesión P2P.

---

## 3. Clase Utilitaria `EOSEnvLoader` (GDScript)

Script independiente (`res://addons/eos-godot/eos_env_loader.gd`) para leer y parsear variables de entorno desde un archivo `.env`.

### Método Estático
```gdscript
static func load_env(file_path: String = "res://.env") -> Dictionary
```
Parsea claves ignorando comentarios (`#`), espacios en blanco y comillas, entregando el diccionario requerido por `EOSManager.initialize_eos(config)`:
- `product_name`
- `product_version`
- `product_id`
- `sandbox_id`
- `deployment_id`
- `client_id`
- `client_secret`

---

## 4. Ejemplo Completo en GDScript

A continuación se muestra un script de ejemplo que demuestra el flujo completo: inicialización, login anónimo, creación o búsqueda de lobby, asignación a `multiplayer.multiplayer_peer` y envío de una llamada `@rpc`.

```gdscript
extends Node

var eos_manager: EOSManager
var peer: EOSMultiplayerPeer

const BUCKET_NAME: String = "ArenaDeathmatch"
const SOCKET_NAME: String = "GameSocket"

func _ready() -> void:
	# 1. Instanciar el nodo EOSManager y añadirlo al árbol de la escena
	eos_manager = EOSManager.new()
	add_child(eos_manager)

	# 2. Conectar las señales de ciclo de vida y lobbies
	eos_manager.login_completed.connect(_on_login_completed)
	eos_manager.lobby_created.connect(_on_lobby_created)
	eos_manager.lobbies_found.connect(_on_lobbies_found)
	eos_manager.lobby_joined.connect(_on_lobby_joined)

	# 3. Conectar señales del árbol de multijugador de Godot
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# 4. Cargar configuración desde .env e inicializar EOS
	var config: Dictionary = EOSEnvLoader.load_env("res://.env")
	if not eos_manager.initialize_eos(config):
		printerr("Error al inicializar EOS SDK")
		return

	print("EOS SDK Inicializado. Versión: ", eos_manager.get_eos_version())

	# 5. Iniciar sesión anónima (Device ID)
	eos_manager.login_anonymous("Jugador_PC")

func _on_login_completed(success: bool, puid: String, error_msg: String) -> void:
	if success:
		print("Login exitoso! Mi ProductUserId: ", puid)
	else:
		printerr("Fallo de autenticación: ", error_msg)

# -----------------------------------------------------------------------------
# FLUJO DEL ANFITRIÓN (HOST)
# -----------------------------------------------------------------------------
func host_game() -> void:
	# Crear lobby de hasta 5 jugadores
	eos_manager.create_lobby(5, BUCKET_NAME, true)

func _on_lobby_created(success: bool, lobby_id: String, error_msg: String) -> void:
	if not success:
		printerr("No se pudo crear el lobby: ", error_msg)
		return

	print("Lobby creado exitosamente con ID: ", lobby_id)

	# Configurar el transporte P2P como Host y asignarlo al árbol de Godot
	peer = EOSMultiplayerPeer.new()
	var err: Error = peer.create_host(SOCKET_NAME)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		print("Servidor P2P iniciado. ID Local: ", multiplayer.get_unique_id()) # Retorna 1
	else:
		printerr("Error al iniciar Host P2P: ", err)

# -----------------------------------------------------------------------------
# FLUJO DEL CLIENTE (JOIN)
# -----------------------------------------------------------------------------
func search_and_join() -> void:
	# Buscar lobbies públicos con nuestro bucket
	eos_manager.search_lobbies(BUCKET_NAME)

func _on_lobbies_found(lobbies: Array) -> void:
	if lobbies.is_empty():
		print("No se encontraron lobbies activos.")
		return

	var first_lobby: Dictionary = lobbies[0]
	print("Lobby encontrado: ", first_lobby.lobby_id, " Cupos disponibles: ", first_lobby.available_slots)

	# Unirse al primer lobby disponible
	eos_manager.join_lobby(first_lobby.lobby_id)

func _on_lobby_joined(success: bool, lobby_id: String, owner_puid: String, error_msg: String) -> void:
	if not success:
		printerr("No se pudo unir al lobby: ", error_msg)
		return

	print("Unido al lobby: ", lobby_id, " | Host PUID: ", owner_puid)

	# Configurar el transporte P2P como Cliente apuntando al Host
	peer = EOSMultiplayerPeer.new()
	var err: Error = peer.create_client(owner_puid, SOCKET_NAME)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		print("Cliente P2P iniciado. Conectando con Host. Mi ID: ", multiplayer.get_unique_id())
	else:
		printerr("Error al conectar Cliente P2P: ", err)

# -----------------------------------------------------------------------------
# EVENTOS DE RED MULTIJUGADOR Y RPC
# -----------------------------------------------------------------------------
func _on_peer_connected(peer_id: int) -> void:
	print("Jugador conectado a la red de Godot con ID: ", peer_id)
	if peer:
		var puid: String = peer.get_puid_from_peer_id(peer_id)
		print("  -> PUID de Epic asociado: ", puid)

func _on_peer_disconnected(peer_id: int) -> void:
	print("Jugador desconectado: ", peer_id)

func send_ping() -> void:
	rpc("ping_rpc", "Hola desde el peer " + str(multiplayer.get_unique_id()))

@rpc("any_peer", "call_local", "reliable")
func ping_rpc(mensaje: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	print("[RPC RECIBIDO] Emisor: ", sender_id, " Mensaje: ", mensaje)
```

class_name EOSEnvLoader
extends RefCounted

## Utilidad portable para cargar y parsear archivos de entorno (.env) en Godot 4.
## Diseñada para alimentar el diccionario de configuración de EOSManager.initialize_eos(config).

static func load_env(file_path: String = "res://.env") -> Dictionary:
	var config: Dictionary = {
		"product_name": "EOS_Godot_Game",
		"product_version": "1.0.0",
		"product_id": "",
		"sandbox_id": "",
		"deployment_id": "",
		"client_id": "",
		"client_secret": ""
	}

	if not FileAccess.file_exists(file_path):
		printerr("EOSEnvLoader: Archivo .env no encontrado en la ruta: ", file_path)
		return config

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		printerr("EOSEnvLoader: No se pudo abrir el archivo .env en: ", file_path)
		return config

	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()

		# Omitir líneas vacías o comentarios
		if line.is_empty() or line.begins_with("#"):
			continue

		var separator_idx: int = line.find("=")
		if separator_idx == -1:
			continue

		var raw_key: String = line.substr(0, separator_idx).strip_edges()
		var raw_value: String = line.substr(separator_idx + 1).strip_edges()

		# Quitar comillas simples o dobles envolventes
		if (raw_value.begins_with("\"") and raw_value.ends_with("\"")) or (raw_value.begins_with("'") and raw_value.ends_with("'")):
			if raw_value.length() >= 2:
				raw_value = raw_value.substr(1, raw_value.length() - 2)

		var key_lower: String = raw_key.to_lower()

		match key_lower:
			"product_name":
				config["product_name"] = raw_value
			"product_version":
				config["product_version"] = raw_value
			"product_id":
				config["product_id"] = raw_value
			"sandbox_id":
				config["sandbox_id"] = raw_value
			"deployment_id":
				config["deployment_id"] = raw_value
			"client_id":
				config["client_id"] = raw_value
			"client_secret":
				config["client_secret"] = raw_value
			_:
				config[key_lower] = raw_value
				config[raw_key] = raw_value

	file.close()
	return config

@tool
extends EditorPlugin

const DEFAULT_PORT := 6010
const MAX_CLIENTS := 8
const MAX_COMMANDS_PER_FRAME := 64

var _server := TCPServer.new()
var _clients: Array[Dictionary] = []
var _port := DEFAULT_PORT

func _enter_tree() -> void:
	_port = int(ProjectSettings.get_setting("main_city_mcp/bridge_port", DEFAULT_PORT))
	var err := _server.listen(_port, "127.0.0.1")
	if err != OK:
		push_error("Main City MCP Bridge: falha ao abrir 127.0.0.1:%d (erro %d)" % [_port, err])
		return
	set_process(true)
	print("Main City MCP Bridge online em 127.0.0.1:%d" % _port)

func _exit_tree() -> void:
	for item in _clients:
		var peer: StreamPeerTCP = item.get("peer")
		if is_instance_valid(peer):
			peer.disconnect_from_host()
	_clients.clear()
	_server.stop()
	set_process(false)

func _process(_delta: float) -> void:
	_accept_clients()
	_poll_clients()

func _accept_clients() -> void:
	while _server.is_connection_available() and _clients.size() < MAX_CLIENTS:
		var peer := _server.take_connection()
		if peer != null:
			_clients.append({"peer": peer, "buffer": ""})

func _poll_clients() -> void:
	var processed := 0
	for i in range(_clients.size() - 1, -1, -1):
		var item := _clients[i]
		var peer: StreamPeerTCP = item.get("peer")
		if not is_instance_valid(peer):
			_clients.remove_at(i)
			continue
		peer.poll()
		var status := peer.get_status()
		if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
			_clients.remove_at(i)
			continue
		var available := peer.get_available_bytes()
		if available <= 0:
			continue
		var chunk := peer.get_utf8_string(available)
		item["buffer"] = String(item.get("buffer", "")) + chunk
		while String(item["buffer"]).contains("\n") and processed < MAX_COMMANDS_PER_FRAME:
			var buffer := String(item["buffer"])
			var split_at := buffer.find("\n")
			var line := buffer.substr(0, split_at).strip_edges()
			item["buffer"] = buffer.substr(split_at + 1)
			if not line.is_empty():
				_handle_line(peer, line)
				processed += 1
		_clients[i] = item

func _handle_line(peer: StreamPeerTCP, line: String) -> void:
	var parsed = JSON.parse_string(line)
	if typeof(parsed) != TYPE_DICTIONARY:
		_send(peer, {"ok": false, "error": "JSON invalido"})
		return
	var response := _dispatch(parsed)
	_send(peer, response)

func _send(peer: StreamPeerTCP, payload: Dictionary) -> void:
	var bytes := (JSON.stringify(payload) + "\n").to_utf8_buffer()
	peer.put_data(bytes)

func _dispatch(request: Dictionary) -> Dictionary:
	var command := String(request.get("command", ""))
	match command:
		"ping":
			return {"ok": true, "result": {"bridge": "main-city", "version": "1.0.0", "port": _port}}
		"editor_info":
			return _editor_info()
		"scene_tree":
			return _scene_tree(int(request.get("max_depth", 8)), int(request.get("max_nodes", 1000)))
		"open_scene":
			return _open_scene(String(request.get("scene", "")))
		"save_scene":
			return _save_scene()
		"create_node":
			return _create_node(request)
		"create_primitive":
			return _create_primitive(request)
		"set_transform":
			return _set_transform(request)
		"set_property":
			return _set_property(request)
		"duplicate_node":
			return _duplicate_node(request)
		"delete_node":
			return _delete_node(request)
		"run_main":
			return _run_main()
		"stop_run":
			return _stop_run()
		"batch":
			return _batch(request)
		_:
			return {"ok": false, "error": "Comando desconhecido: %s" % command}

func _root() -> Node:
	return get_editor_interface().get_edited_scene_root()

func _find_node(node_path: String) -> Node:
	var root := _root()
	if root == null:
		return null
	if node_path.is_empty() or node_path == "." or node_path == root.name:
		return root
	return root.get_node_or_null(NodePath(node_path))

func _node_path(node: Node) -> String:
	var root := _root()
	if root == null or node == null:
		return ""
	if node == root:
		return "."
	return String(root.get_path_to(node))

func _editor_info() -> Dictionary:
	var root := _root()
	return {
		"ok": true,
		"result": {
			"godot": Engine.get_version_info(),
			"edited_scene": get_editor_interface().get_edited_scene_root().scene_file_path if root != null else "",
			"scene_root": root.name if root != null else "",
			"playing": get_editor_interface().is_playing_scene(),
			"project": ProjectSettings.get_setting("application/config/name", "")
		}
	}

func _scene_tree(max_depth: int, max_nodes: int) -> Dictionary:
	var root := _root()
	if root == null:
		return {"ok": false, "error": "Nenhuma cena aberta"}
	var out: Array = []
	_collect_tree(root, 0, clampi(max_depth, 0, 20), clampi(max_nodes, 1, 5000), out)
	return {"ok": true, "result": {"nodes": out, "count": out.size()}}

func _collect_tree(node: Node, depth: int, max_depth: int, max_nodes: int, out: Array) -> void:
	if out.size() >= max_nodes:
		return
	out.append({
		"path": _node_path(node),
		"name": node.name,
		"class": node.get_class(),
		"depth": depth,
		"owner": node.owner.name if node.owner != null else ""
	})
	if depth >= max_depth:
		return
	for child in node.get_children():
		if child is Node:
			_collect_tree(child, depth + 1, max_depth, max_nodes, out)
			if out.size() >= max_nodes:
				return

func _open_scene(scene: String) -> Dictionary:
	if not scene.begins_with("res://"):
		return {"ok": false, "error": "A cena precisa usar res://"}
	var err := get_editor_interface().open_scene_from_path(scene)
	return {"ok": err == OK, "result": {"scene": scene, "error_code": err}}

func _save_scene() -> Dictionary:
	var err := get_editor_interface().save_scene()
	return {"ok": err == OK, "result": {"error_code": err}}

func _create_node(request: Dictionary) -> Dictionary:
	var root := _root()
	if root == null:
		return {"ok": false, "error": "Nenhuma cena aberta"}
	var parent := _find_node(String(request.get("parent", ".")))
	if parent == null:
		return {"ok": false, "error": "Pai nao encontrado"}
	var node_class := String(request.get("class_name", "Node3D"))
	if not ClassDB.class_exists(node_class) or not ClassDB.is_parent_class(node_class, "Node"):
		return {"ok": false, "error": "Classe de Node invalida: %s" % node_class}
	var node := ClassDB.instantiate(node_class)
	if not (node is Node):
		return {"ok": false, "error": "Nao foi possivel instanciar %s" % node_class}
	node.name = String(request.get("name", node_class))
	parent.add_child(node)
	node.owner = root
	return {"ok": true, "result": {"path": _node_path(node), "class": node_class}}

func _create_primitive(request: Dictionary) -> Dictionary:
	var root := _root()
	if root == null:
		return {"ok": false, "error": "Nenhuma cena aberta"}
	var parent := _find_node(String(request.get("parent", ".")))
	if parent == null:
		return {"ok": false, "error": "Pai nao encontrado"}
	var shape_name := String(request.get("shape", "box"))
	var holder := Node3D.new()
	holder.name = String(request.get("name", "Primitive"))
	parent.add_child(holder)
	holder.owner = root
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Visual"
	holder.add_child(mesh_instance)
	mesh_instance.owner = root
	var size := _vec3(request.get("size", [1.0, 1.0, 1.0]), Vector3.ONE)
	var mesh: Mesh
	var collision_shape: Shape3D
	match shape_name:
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = maxf(0.01, size.x * 0.5)
			sphere.height = maxf(sphere.radius * 2.0, size.y)
			mesh = sphere
			var sshape := SphereShape3D.new()
			sshape.radius = sphere.radius
			collision_shape = sshape
		"cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = maxf(0.01, size.x * 0.5)
			cylinder.bottom_radius = maxf(0.01, size.z * 0.5)
			cylinder.height = maxf(0.01, size.y)
			mesh = cylinder
			var cshape := CylinderShape3D.new()
			cshape.radius = maxf(cylinder.top_radius, cylinder.bottom_radius)
			cshape.height = cylinder.height
			collision_shape = cshape
		"plane":
			var plane := PlaneMesh.new()
			plane.size = Vector2(maxf(0.01, size.x), maxf(0.01, size.z))
			mesh = plane
			var pshape := BoxShape3D.new()
			pshape.size = Vector3(maxf(0.01, size.x), maxf(0.05, size.y), maxf(0.01, size.z))
			collision_shape = pshape
		_:
			var box := BoxMesh.new()
			box.size = Vector3(maxf(0.01, size.x), maxf(0.01, size.y), maxf(0.01, size.z))
			mesh = box
			var bshape := BoxShape3D.new()
			bshape.size = box.size
			collision_shape = bshape
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = _color(request.get("color", [0.8, 0.8, 0.8, 1.0]), Color(0.8, 0.8, 0.8, 1.0))
	material.roughness = clampf(float(request.get("roughness", 0.8)), 0.0, 1.0)
	material.metallic = clampf(float(request.get("metallic", 0.0)), 0.0, 1.0)
	mesh_instance.material_override = material
	if bool(request.get("collision", true)):
		var body := StaticBody3D.new()
		body.name = "Fisica"
		holder.add_child(body)
		body.owner = root
		var collision := CollisionShape3D.new()
		collision.name = "Colisao"
		collision.shape = collision_shape
		body.add_child(collision)
		collision.owner = root
	holder.position = _vec3(request.get("position", [0.0, 0.0, 0.0]), Vector3.ZERO)
	holder.rotation_degrees = _vec3(request.get("rotation_degrees", [0.0, 0.0, 0.0]), Vector3.ZERO)
	return {"ok": true, "result": {"path": _node_path(holder), "shape": shape_name}}

func _set_transform(request: Dictionary) -> Dictionary:
	var node := _find_node(String(request.get("node", "")))
	if not (node is Node3D):
		return {"ok": false, "error": "Node3D nao encontrado"}
	if request.has("position"):
		node.position = _vec3(request["position"], node.position)
	if request.has("rotation_degrees"):
		node.rotation_degrees = _vec3(request["rotation_degrees"], node.rotation_degrees)
	if request.has("scale"):
		node.scale = _vec3(request["scale"], node.scale)
	return {"ok": true, "result": {"path": _node_path(node)}}

func _set_property(request: Dictionary) -> Dictionary:
	var node := _find_node(String(request.get("node", "")))
	if node == null:
		return {"ok": false, "error": "No nao encontrado"}
	var property_name := String(request.get("property", ""))
	if property_name.is_empty():
		return {"ok": false, "error": "Propriedade vazia"}
	var value = _decode_value(request.get("value"))
	node.set(property_name, value)
	return {"ok": true, "result": {"path": _node_path(node), "property": property_name}}

func _duplicate_node(request: Dictionary) -> Dictionary:
	var node := _find_node(String(request.get("node", "")))
	if node == null or node == _root():
		return {"ok": false, "error": "No invalido para duplicar"}
	var copy := node.duplicate(Node.DUPLICATE_USE_INSTANTIATION)
	copy.name = String(request.get("new_name", "%s_Copy" % node.name))
	node.get_parent().add_child(copy)
	_set_owner_recursive(copy, _root())
	return {"ok": true, "result": {"path": _node_path(copy)}}

func _delete_node(request: Dictionary) -> Dictionary:
	var node := _find_node(String(request.get("node", "")))
	if node == null or node == _root():
		return {"ok": false, "error": "No invalido para remover"}
	var old_path := _node_path(node)
	node.get_parent().remove_child(node)
	node.queue_free()
	return {"ok": true, "result": {"deleted": old_path}}

func _run_main() -> Dictionary:
	if get_editor_interface().is_playing_scene():
		return {"ok": true, "result": {"already_playing": true}}
	get_editor_interface().play_main_scene()
	return {"ok": true, "result": {"started": true}}

func _stop_run() -> Dictionary:
	if get_editor_interface().is_playing_scene():
		get_editor_interface().stop_playing_scene()
	return {"ok": true, "result": {"stopped": true}}

func _batch(request: Dictionary) -> Dictionary:
	var operations = request.get("operations", [])
	if typeof(operations) != TYPE_ARRAY:
		return {"ok": false, "error": "operations precisa ser Array"}
	var results: Array = []
	var limit := mini(operations.size(), 200)
	for i in range(limit):
		var operation = operations[i]
		if typeof(operation) != TYPE_DICTIONARY:
			results.append({"ok": false, "error": "Operacao invalida", "index": i})
			continue
		var response := _dispatch(operation)
		response["index"] = i
		results.append(response)
		if response.get("ok", false) == false:
			break
	return {"ok": true, "result": {"results": results}}

func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for child in node.get_children():
		if child is Node:
			_set_owner_recursive(child, owner)

func _vec3(value, fallback: Vector3) -> Vector3:
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector3(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)), float(value.get("z", fallback.z)))
	return fallback

func _color(value, fallback: Color) -> Color:
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		var alpha := float(value[3]) if value.size() >= 4 else 1.0
		return Color(float(value[0]), float(value[1]), float(value[2]), alpha)
	return fallback

func _decode_value(value):
	if typeof(value) != TYPE_DICTIONARY:
		return value
	var type_name := String(value.get("_type", ""))
	var raw = value.get("value")
	match type_name:
		"Vector3":
			return _vec3(raw, Vector3.ZERO)
		"Vector2":
			if typeof(raw) == TYPE_ARRAY and raw.size() >= 2:
				return Vector2(float(raw[0]), float(raw[1]))
		"Color":
			return _color(raw, Color.WHITE)
		"NodePath":
			return NodePath(String(raw))
	return value

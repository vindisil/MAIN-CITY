extends Node3D
## Main City - migração para City 1.
## Polícia / Exército / Hospital ficam preservados, porém inativos até os
## novos pontos das bases serem definidos neste mapa.
## Também centraliza o atalho ESC e corrige o spawn inicial na City 1.

@export var police_enabled: bool = false
@export var army_enabled: bool = false
@export var hospital_enabled: bool = false

const SAFE_SURFACE_WORDS := [
	"road", "street", "tarmac", "highway", "sidewalk", "pavement", "parking",
	"bridge", "ramp", "lane", "avenue", "rua", "asphalt", "asfalto",
	"ground", "terrain", "land", "solo", "terreno"
]

func _ready() -> void:
	# Precisa continuar recebendo ESC mesmo quando o menu pausa a árvore.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# A City 1 não usa as coordenadas do mapa antigo. Procuramos automaticamente
	# uma superfície livre perto do centro para o personagem nunca nascer preso.
	call_deferred("_place_player_on_safe_spawn")

func _place_player_on_safe_spawn() -> void:
	# Espera um frame para as colisões importadas da City 1 entrarem no espaço físico.
	await get_tree().physics_frame
	var player := get_node_or_null("Player") as CharacterBody3D
	if player == null:
		return

	var safe_position := _find_safe_spawn(player)
	if safe_position == Vector3.INF:
		# Último fallback: acima do piso global de segurança, longe do ponto antigo.
		safe_position = Vector3(40.0, 0.35, 40.0)

	player.velocity = Vector3.ZERO
	player.global_position = safe_position + Vector3(0.0, 0.12, 0.0)
	print("MAIN CITY / City 1: spawn seguro em ", player.global_position)

func _find_safe_spawn(player: CharacterBody3D) -> Vector3:
	var space := get_world_3d().direct_space_state
	var excluded: Array[RID] = [player.get_rid()]
	for vehicle in get_tree().get_nodes_in_group("vehicle"):
		if vehicle is CollisionObject3D:
			excluded.append((vehicle as CollisionObject3D).get_rid())

	# Procura em anéis cada vez maiores. Assim não dependemos de coordenadas
	# específicas do mapa antigo nem precisamos adivinhar onde existe uma rua.
	var radii := [0.0, 12.0, 24.0, 40.0, 60.0, 85.0, 115.0, 150.0, 200.0, 260.0]
	var directions := [
		Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
		Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1),
		Vector2(2, 1), Vector2(2, -1), Vector2(-2, 1), Vector2(-2, -1),
		Vector2(1, 2), Vector2(-1, 2), Vector2(1, -2), Vector2(-1, -2)
	]
	var first_clear_fallback := Vector3.INF

	for radius in radii:
		for dir in directions:
			var offset := Vector2.ZERO if radius == 0.0 else dir.normalized() * radius
			var from := Vector3(offset.x, 14.0, offset.y)
			var to := Vector3(offset.x, -4.0, offset.y)
			var ray := PhysicsRayQueryParameters3D.create(from, to)
			ray.exclude = excluded
			ray.collide_with_bodies = true
			ray.collide_with_areas = false
			var hit := space.intersect_ray(ray)
			if hit.is_empty():
				continue

			var point: Vector3 = hit.get("position", Vector3.INF)
			if point == Vector3.INF or point.y < -1.0 or point.y > 4.5:
				continue
			if not _spawn_clear(space, point, excluded):
				continue

			var collider := hit.get("collider") as Node
			if _is_safe_surface(collider):
				return point
			if first_clear_fallback == Vector3.INF:
				first_clear_fallback = point

	return first_clear_fallback

func _spawn_clear(space: PhysicsDirectSpaceState3D, ground_point: Vector3, excluded: Array[RID]) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.48
	capsule.height = 1.90
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, ground_point + Vector3(0.0, 1.08, 0.0))
	query.exclude = excluded
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return space.intersect_shape(query, 1).is_empty()

func _is_safe_surface(collider: Node) -> bool:
	if collider == null:
		return false
	var names := ""
	var current: Node = collider
	var depth := 0
	while current != null and depth < 5:
		names += " " + str(current.name).to_lower()
		current = current.get_parent()
		depth += 1
	for word in SAFE_SURFACE_WORDS:
		if names.contains(word):
			return true
	# O piso de segurança é válido desde que o volume acima esteja livre.
	return names.contains("fallbackground")

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return

	var player := get_node_or_null("Player")
	if player == null:
		return
	var menu = player.get("map_settings_menu")
	if menu == null or not is_instance_valid(menu):
		return

	if bool(menu.get("menu_open")):
		menu.call("set_menu", false)
	else:
		# Aba 1 = mapa. ESC abre direto no mapa geográfico da City 1.
		menu.call("open_page", 1)
	get_viewport().set_input_as_handled()

@tool
extends EditorScenePostImport
## MAIN CITY / City 1
## Gera colisões estáticas para ruas, prédios e estruturas importantes da cidade.
## Ignora props pequenos/decorativos para preservar desempenho no mobile.

const MAX_AUTO_COLLISIONS := 360
const COLLISION_WORDS := [
	"street", "road", "tarmac", "highway", "sidewalk", "ground", "floor",
	"bridge", "ramp", "curb", "parking", "pavement", "building", "build",
	"house", "wall", "fence", "garage", "tunnel", "stairs", "stair"
]
const SKIP_WORDS := [
	"tree", "leaf", "leaves", "grass", "lamp", "light", "wire", "cable",
	"sign", "decal", "banner", "flag", "pole", "antenna", "trash", "bench"
]

var _created := 0
var _skipped := 0

func _post_import(scene: Node) -> Object:
	_created = 0
	_skipped = 0
	_add_city_collisions(scene)
	print("MAIN CITY / City 1: %d colisões criadas; %d meshes decorativos ignorados." % [_created, _skipped])
	return scene

func _add_city_collisions(node: Node) -> void:
	if _created >= MAX_AUTO_COLLISIONS:
		return

	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if _should_skip(mesh_node):
			_skipped += 1
		elif _should_have_collision(mesh_node) and not _already_has_static_collision(mesh_node):
			mesh_node.create_trimesh_collision()
			_created += 1

	for child in node.get_children():
		if child is Node:
			_add_city_collisions(child)

func _should_skip(node: MeshInstance3D) -> bool:
	if node.mesh == null:
		return true
	var n := str(node.name).to_lower()
	for word in SKIP_WORDS:
		if n.contains(word):
			# Terreno grande com nome de grama ainda precisa ser físico.
			if word == "grass":
				var aabb := node.get_aabb()
				if aabb.size.x >= 20.0 and aabb.size.z >= 20.0:
					return false
			return true
	return false

func _should_have_collision(node: MeshInstance3D) -> bool:
	if node.mesh == null:
		return false

	var n := str(node.name).to_lower()
	for word in COLLISION_WORDS:
		if n.contains(word):
			return true

	# Fallback geométrico: estruturas grandes entram mesmo quando o nome veio genérico do Blender.
	var aabb := node.get_aabb()
	var footprint := aabb.size.x * aabb.size.z
	var large_structure := footprint >= 18.0 and aabb.size.y >= 0.35
	var broad_surface := footprint >= 80.0 and aabb.size.y <= 4.0
	return large_structure or broad_surface

func _already_has_static_collision(node: MeshInstance3D) -> bool:
	for child in node.get_children():
		if child is StaticBody3D:
			return true
	return false

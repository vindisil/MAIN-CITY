@tool
extends EditorScenePostImport
## Gera colisões somente nas superfícies grandes de circulação da City 1.
## Evita criar colisão trimesh em todos os prédios/props para proteger FPS mobile.

const MAX_AUTO_COLLISIONS := 180
const SURFACE_WORDS := [
	"street", "road", "tarmac", "highway", "sidewalk", "ground",
	"floor", "bridge", "ramp", "curb", "parking", "pavement"
]

var _created := 0

func _post_import(scene: Node) -> Object:
	_created = 0
	_add_surface_collisions(scene)
	print("MAIN CITY / City 1: %d colisões de superfície criadas no import." % _created)
	return scene

func _add_surface_collisions(node: Node) -> void:
	if _created >= MAX_AUTO_COLLISIONS:
		return

	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if _should_have_collision(mesh_node) and not _already_has_static_collision(mesh_node):
			mesh_node.create_trimesh_collision()
			_created += 1

	for child in node.get_children():
		if child is Node:
			_add_surface_collisions(child)

func _should_have_collision(node: MeshInstance3D) -> bool:
	if node.mesh == null:
		return false
	var n := str(node.name).to_lower()
	for word in SURFACE_WORDS:
		if n.contains(word):
			return true
	return false

func _already_has_static_collision(node: MeshInstance3D) -> bool:
	for child in node.get_children():
		if child is StaticBody3D:
			return true
	return false

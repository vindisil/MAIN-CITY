extends Node3D
## Ajuste da grama FBX do usuario na primeira ativacao do bairro importado.
@export var patch_size: float = 2.2
@export var max_blade_height: float = 0.82
func _ready() -> void:
    var source: Node3D = get_node_or_null("Model") as Node3D
    if source == null:
        return
    var shader_material := StandardMaterial3D.new()
    shader_material.albedo_texture = preload("res://assets/v002_grama/SF_Grass_Dif.png")
    shader_material.normal_enabled = true
    shader_material.normal_texture = preload("res://assets/v002_grama/SF_Grass_N.png")
    shader_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    shader_material.alpha_scissor_threshold = 0.46
    shader_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    shader_material.roughness = 0.95
    var points: Array[Vector3] = []
    var to_root := source.global_transform.affine_inverse()
    var pending: Array[Node] = [source]
    while not pending.is_empty():
        var node: Node = pending.pop_back() as Node
        if node is MeshInstance3D:
            var mesh_node: MeshInstance3D = node
            if mesh_node.mesh != null:
                for surface in range(mesh_node.mesh.get_surface_count()):
                    mesh_node.set_surface_override_material(surface, shader_material)
                mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                var box: AABB = mesh_node.get_aabb()
                var local_to_model: Transform3D = to_root * mesh_node.global_transform
                for i in range(8):
                    points.append(local_to_model * (box.position + Vector3(box.size.x * float(i & 1), box.size.y * float((i >> 1) & 1), box.size.z * float((i >> 2) & 1))))
        for child in node.get_children():
            pending.append(child)
    if points.is_empty():
        return
    var bounds: AABB = AABB(points[0], Vector3.ZERO)
    for p in points:
        bounds = bounds.expand(p)
    if bounds.size.x < 0.001 or bounds.size.z < 0.001:
        return
    var scale_factor: float = minf(patch_size / bounds.size.x, patch_size / bounds.size.z)
    if bounds.size.y > 0.001:
        scale_factor = minf(scale_factor, max_blade_height / bounds.size.y)
    source.scale = Vector3.ONE * scale_factor
    source.position = Vector3(-bounds.get_center().x * scale_factor, -bounds.position.y * scale_factor + 0.10, -bounds.get_center().z * scale_factor)

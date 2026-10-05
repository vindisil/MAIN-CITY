extends Node3D
## V30.7 - Shared four-wheel visual system for the newly imported vehicles.
## Their physical WheelFL/FR/RL/RR remain Godot VehicleWheel3D nodes, just
## like the BMW and GLS. Cylinder meshes are low-poly and share materials.
## Display-only: never adds a second collision/rigid body to a wheel.

func _ready() -> void:
    call_deferred("_prepare_visual_wheels")

func _prepare_visual_wheels() -> void:
    var vehicle := get_parent() as VehicleBody3D
    if vehicle == null:
        return
    var rubber := StandardMaterial3D.new()
    rubber.albedo_color = Color(0.048, 0.051, 0.057)
    rubber.roughness = 0.92
    var hub := StandardMaterial3D.new()
    hub.albedo_color = Color(0.24, 0.26, 0.28)
    hub.metallic = 0.72
    hub.roughness = 0.34
    for side in ["FL", "FR", "RL", "RR"]:
        var wheel := vehicle.get_node_or_null("Wheel" + side) as VehicleWheel3D
        if wheel == null or wheel.has_node("RodaVisualV30_7"):
            continue
        var radius: float = wheel.wheel_radius
        var pivot := Node3D.new()
        pivot.name = "RodaVisualV30_7"
        wheel.add_child(pivot)
        # CylinderMesh is oriented along Y, so rotate it onto the car's X axle.
        # Because it is parented to VehicleWheel3D, it spins, steers and moves
        # vertically along with the wheel's built-in suspension.
        pivot.rotation.z = PI * 0.5
        var tire_mesh := CylinderMesh.new()
        tire_mesh.top_radius = radius
        tire_mesh.bottom_radius = radius
        tire_mesh.height = radius * 0.70
        tire_mesh.radial_segments = 18
        var tire := MeshInstance3D.new()
        tire.name = "Pneu"
        tire.mesh = tire_mesh
        tire.material_override = rubber
        pivot.add_child(tire)
        var rim_mesh := CylinderMesh.new()
        rim_mesh.top_radius = radius * 0.50
        rim_mesh.bottom_radius = radius * 0.50
        rim_mesh.height = radius * 0.73
        rim_mesh.radial_segments = 12
        var rim := MeshInstance3D.new()
        rim.name = "Roda"
        rim.mesh = rim_mesh
        rim.material_override = hub
        pivot.add_child(rim)

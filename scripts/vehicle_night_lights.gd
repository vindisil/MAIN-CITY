extends Node3D

# Some imported vehicles have the front on local +Z, not -Z.
@export var front_is_positive_z: bool = false
## v0.0.9: dois feixes reais dianteiros, um por farol, gerando dois pontos
## luminosos no solo. Sem sombras; mobile ate 2 carros, desktop ate 4.
## Relogio BR real preservado: esta rotina so le o nivel noturno do mundo.

@export var front_left_position: Vector3 = Vector3(-0.72, 0.72, -2.45)
@export var front_right_position: Vector3 = Vector3(0.72, 0.72, -2.45)
@export var rear_left_position: Vector3 = Vector3(-0.72, 0.66, 2.28)
@export var rear_right_position: Vector3 = Vector3(0.72, 0.66, 2.28)
@export var front_range: float = 24.0
@export var rear_range: float = 4.5
@export var front_energy: float = 1.55
@export var rear_energy: float = 0.60
@export var detection_threshold: float = 0.16
@export var update_interval: float = 0.55

const MOBILE_REAL_LIGHT_LIMIT: int = 2
const DESKTOP_REAL_LIGHT_LIMIT: int = 4
const MOBILE_LIGHT_DISTANCE_SQ: float = 65.0 * 65.0
const DESKTOP_LIGHT_DISTANCE_SQ: float = 100.0 * 100.0

var _cycle: Node = null
var _player: Node3D = null
var _vehicle: VehicleBody3D = null
var _headlights: Array[SpotLight3D] = []
var _markers: Array[MeshInstance3D] = []
var _materials: Array[StandardMaterial3D] = []
var _scan: float = 999.0
var _last_level: float = -1.0
var _last_glow: bool = false
var _last_beam: bool = false

func _ready() -> void:
    set_process(false)
    call_deferred("_setup")

func _setup() -> void:
    _vehicle = get_parent() as VehicleBody3D
    var scene: Node = get_tree().current_scene
    if scene != null:
        _cycle = scene.get_node_or_null("BrasiliaDayNight")
        _player = scene.get_node_or_null("Player") as Node3D
    _make_marker("FarolFL", Color(1.0, 0.95, 0.84), front_left_position)
    _make_marker("FarolFR", Color(1.0, 0.95, 0.84), front_right_position)
    _make_marker("LanternaRL", Color(1.0, 0.09, 0.06), rear_left_position)
    _make_marker("LanternaRR", Color(1.0, 0.09, 0.06), rear_right_position)
    # Lanternas sao emissivas (sem OmniLight3D). Um feixe independente por
    # farol cria dois pontos de luz no asfalto; nao ativa sombras.
    for side in range(2):
        var pos: Vector3 = front_left_position if side == 0 else front_right_position
        var beam: SpotLight3D = SpotLight3D.new()
        beam.name = "FeixeDianteiroEsq" if side == 0 else "FeixeDianteiroDir"
        beam.position = pos + Vector3(0.0, 0.0, 0.045 if front_is_positive_z else -0.045)
        # Desce ambos os feixes e orienta-os para a frente real do modelo.
        beam.rotation_degrees = Vector3(-13.0, 180.0 if front_is_positive_z else 0.0, 0.0)
        beam.light_color = Color(1.0, 0.94, 0.84)
        beam.spot_range = front_range
        beam.spot_angle = 31.0
        beam.spot_angle_attenuation = 0.85
        beam.shadow_enabled = false
        beam.visible = false
        beam.light_energy = 0.0
        add_child(beam)
        _headlights.append(beam)
    _update_state(true)
    set_process(true)

func _process(delta: float) -> void:
    _scan += delta
    if _scan < update_interval:
        return
    _scan = 0.0
    _update_state()

func _night_level() -> float:
    if is_instance_valid(_cycle):
        var night: Variant = _cycle.get("street_lamp_level")
        if night != null:
            return clampf(float(night), 0.0, 1.0)
    return 0.0

func _is_nearest_active_vehicle() -> bool:
    if not is_instance_valid(_vehicle) or not is_instance_valid(_player):
        return false
    var driving: Node = _player.get("vehicle") as Node
    if driving == _vehicle:
        return true
    var view_position: Vector3 = _player.global_position
    if driving is Node3D:
        view_position = (driving as Node3D).global_position
    var d2: float = _vehicle.global_position.distance_squared_to(view_position)
    var max_d2: float = MOBILE_LIGHT_DISTANCE_SQ if OS.has_feature("mobile") else DESKTOP_LIGHT_DISTANCE_SQ
    if d2 > max_d2:
        return false
    var max_count: int = MOBILE_REAL_LIGHT_LIMIT if OS.has_feature("mobile") else DESKTOP_REAL_LIGHT_LIMIT
    var nearer: int = 0
    for candidate in get_tree().get_nodes_in_group("vehicle"):
        if candidate == _vehicle or not (candidate is VehicleBody3D):
            continue
        var other: VehicleBody3D = candidate as VehicleBody3D
        if not is_instance_valid(other):
            continue
        var other_d2: float = other.global_position.distance_squared_to(view_position)
        if other_d2 < d2 or (is_equal_approx(other_d2, d2) and other.get_instance_id() < _vehicle.get_instance_id()):
            nearer += 1
            if nearer >= max_count:
                return false
    return true

func _update_state(force: bool = false) -> void:
    var level: float = _night_level()
    var glow: bool = level > detection_threshold
    var beam: bool = glow and _is_nearest_active_vehicle()
    if not force and glow == _last_glow and beam == _last_beam and absf(level - _last_level) < 0.05:
        return
    _last_level = level
    _last_glow = glow
    _last_beam = beam
    for mesh in _markers:
        mesh.visible = glow
    for i in range(_materials.size()):
        var strength: float = 1.55 if i < 2 else 1.1
        _materials[i].emission_energy_multiplier = level * strength if glow else 0.0
    for lamp in _headlights:
        lamp.visible = beam
        # Dois feixes, com energia individual moderada para mobile.
        lamp.light_energy = level * front_energy * 0.68 if beam else 0.0

func _make_marker(marker_name: String, color: Color, marker_position: Vector3) -> void:
    var marker: MeshInstance3D = MeshInstance3D.new()
    marker.name = marker_name
    var box: BoxMesh = BoxMesh.new()
    box.size = Vector3(0.24, 0.12, 0.065)
    marker.mesh = box
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 0.0
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    marker.material_override = material
    marker.position = marker_position
    marker.visible = false
    marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(marker)
    _markers.append(marker)
    _materials.append(material)

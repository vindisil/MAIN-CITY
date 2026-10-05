extends Node3D
## Fixed pools: no per-shot mesh/material/timer allocations.
const IMPACT_SOUND = preload("res://assets/audio/impact.wav")
const TRACER_SPEED: float = 240.0
const TRACER_MAX_DISTANCE: float = 120.0
const TRACER_LENGTH: float = 2.8
const TRACER_INITIAL_LENGTH: float = 0.6
const TRACER_MIN_LIFE: float = 0.14
const TRACER_FADE_TIME: float = 0.055
var tracers: Array[MeshInstance3D] = []
var tracer_life: Array[float] = []
var tracer_duration: Array[float] = []
var tracer_starts: Array[Vector3] = []
var tracer_directions: Array[Vector3] = []
var tracer_distances: Array[float] = []
var tracer_bases: Array[Basis] = []
var tracer_fresh: Array[bool] = []
var marks: Array[MeshInstance3D] = []
var mark_life: Array[float] = []
var particles: Array[CPUParticles3D] = []
var sounds: Array[AudioStreamPlayer3D] = []
var tracer_index: int = 0
var impact_index: int = 0

func _ready() -> void:
    top_level = true
    global_transform = Transform3D.IDENTITY
    var tracer_mesh := BoxMesh.new()
    tracer_mesh.size = Vector3(.02, .02, 1.0)
    var glow := StandardMaterial3D.new()
    glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    glow.albedo_color = Color(1.0, .96, .72)
    glow.emission_enabled = true
    glow.emission = Color(1.0, .65, .22)
    glow.emission_energy_multiplier = 2.5
    tracer_mesh.material = glow
    var halo_mesh := BoxMesh.new()
    halo_mesh.size = Vector3(.06, .06, 1.0)
    var halo_material := StandardMaterial3D.new()
    halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    halo_material.albedo_color = Color(1.0, .48, .12, .38)
    halo_material.emission_enabled = true
    halo_material.emission = Color(1.0, .34, .07)
    halo_material.emission_energy_multiplier = 1.5
    halo_mesh.material = halo_material
    var mark_mesh := SphereMesh.new()
    mark_mesh.radius = .032
    mark_mesh.height = .064
    mark_mesh.radial_segments = 8
    mark_mesh.rings = 3
    var dark := StandardMaterial3D.new()
    dark.albedo_color = Color(.075, .07, .065)
    mark_mesh.material = dark
    var dust_mesh := SphereMesh.new()
    dust_mesh.radius = .018
    dust_mesh.height = .036
    dust_mesh.radial_segments = 6
    dust_mesh.rings = 3
    var dust := StandardMaterial3D.new()
    dust.albedo_color = Color(.57, .51, .43)
    dust_mesh.material = dust
    for i in range(12):
        var line := MeshInstance3D.new()
        line.mesh = tracer_mesh
        line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        line.visible = false
        add_child(line)
        var halo := MeshInstance3D.new()
        halo.mesh = halo_mesh
        halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        line.add_child(halo)
        tracers.append(line)
        tracer_life.append(0.0)
        tracer_duration.append(0.0)
        tracer_starts.append(Vector3.ZERO)
        tracer_directions.append(Vector3.FORWARD)
        tracer_distances.append(0.0)
        tracer_bases.append(Basis.IDENTITY)
        tracer_fresh.append(false)
    for i in range(24):
        var mark := MeshInstance3D.new()
        mark.mesh = mark_mesh
        mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mark.visible = false
        add_child(mark)
        marks.append(mark)
        mark_life.append(0.0)
        var puff := CPUParticles3D.new()
        puff.emitting = false
        puff.amount = 7
        puff.one_shot = true
        puff.explosiveness = 1.0
        puff.lifetime = .28
        puff.mesh = dust_mesh
        puff.local_coords = false
        puff.spread = 48
        puff.gravity = Vector3(0, -3, 0)
        puff.initial_velocity_min = .8
        puff.initial_velocity_max = 1.8
        puff.scale_amount_min = .2
        puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(puff)
        particles.append(puff)
        var sound := AudioStreamPlayer3D.new()
        sound.stream = IMPACT_SOUND
        sound.volume_db = -17
        sound.max_distance = 50
        add_child(sound)
        sounds.append(sound)
    set_process(false)

func _process(delta: float) -> void:
    var active := false
    for i in range(tracers.size()):
        if tracer_life[i] > 0.0:
            # Garante um primeiro frame saindo do cano, mesmo com FPS baixo.
            if tracer_fresh[i]:
                tracer_fresh[i] = false
            else:
                tracer_life[i] = maxf(0.0, tracer_life[i] - delta)
            if tracer_life[i] > 0.0:
                _place_tracer(i)
                active = true
            else:
                tracers[i].visible = false
    for i in range(marks.size()):
        if mark_life[i] > 0.0:
            mark_life[i] -= delta
            marks[i].visible = mark_life[i] > 0.0
            active = active or mark_life[i] > 0.0
    if not active:
        set_process(false)

func tracer(start: Vector3, end: Vector3) -> void:
    var distance := start.distance_to(end)
    if distance < .025 or tracers.is_empty():
        return
    var direction := (end-start)/distance
    distance = minf(distance, TRACER_MAX_DISTANCE)
    tracer_starts[tracer_index] = start
    tracer_directions[tracer_index] = direction
    tracer_distances[tracer_index] = distance
    tracer_bases[tracer_index] = Basis.looking_at(direction, Vector3.RIGHT if absf(direction.y) > .98 else Vector3.UP)
    var duration := maxf(TRACER_MIN_LIFE, maxf(0.0, distance - TRACER_INITIAL_LENGTH) / TRACER_SPEED + 0.04)
    tracer_duration[tracer_index] = duration
    tracer_life[tracer_index] = duration
    tracer_fresh[tracer_index] = true
    _place_tracer(tracer_index)
    set_process(true)
    tracer_index = (tracer_index + 1) % tracers.size()

func _place_tracer(index: int) -> void:
    var age := tracer_duration[index] - tracer_life[index]
    var head := minf(tracer_distances[index], TRACER_INITIAL_LENGTH + age * TRACER_SPEED)
    var length := minf(TRACER_LENGTH, head)
    var thickness := clampf(tracer_life[index] / TRACER_FADE_TIME, 0.25, 1.0)
    var orientation := tracer_bases[index]
    var basis := Basis(orientation.x * thickness, orientation.y * thickness, orientation.z * length)
    var center := tracer_starts[index] + tracer_directions[index] * (head - length * 0.5)
    tracers[index].global_transform = Transform3D(basis, center)
    tracers[index].visible = true

func impact(point: Vector3, surface_normal: Vector3, static_surface: bool) -> void:
    var normal := surface_normal.normalized() if surface_normal.length_squared() > .01 else Vector3.UP
    var mark := marks[impact_index]
    mark.global_transform = Transform3D(Basis(Quaternion(Vector3.BACK, normal)), point+normal*.012)
    mark.scale = Vector3(1, 1, .12)
    mark.visible = static_surface
    mark_life[impact_index] = 5.0 if static_surface else 0.0
    set_process(true)
    var puff := particles[impact_index]
    puff.global_position = point+normal*.02
    puff.direction = normal
    puff.restart()
    var sound := sounds[impact_index]
    sound.global_position = point
    sound.play()
    impact_index = (impact_index + 1) % marks.size()

func _exit_tree() -> void:
    for sound in sounds:
        if is_instance_valid(sound):
            sound.stop()
            sound.stream = null

extends Node3D
## Main City - otimizacao compartilhada da frota City 1.
## Nao substitui car.gd nem altera as configuracoes individuais de cada carro.
## Atua depois do controlador original com assistencias leves de estabilidade,
## suavizacao de forca e modo de repouso para veiculos estacionados.

@export_range(1.0, 15.0, 0.1) var engine_response: float = 7.5
@export_range(0.0, 1.5, 0.01) var lateral_stability: float = 0.42
@export_range(0.0, 4.0, 0.05) var yaw_stability: float = 1.25
@export_range(0.0, 3.0, 0.05) var downforce_coefficient: float = 0.95
@export_range(0.5, 8.0, 0.1) var parked_sleep_delay: float = 2.0
@export_range(0.20, 0.80, 0.01) var high_speed_steer_ratio: float = 0.42

var vehicles: Array[VehicleBody3D] = []
var smoothed_engine: Dictionary = {}
var parked_time: Dictionary = {}
var wheel_cache: Dictionary = {}
var audio_cache: Dictionary = {}

func _ready() -> void:
    # car.gd usa a prioridade padrao. Rodamos depois dele para suavizar o valor
    # final sem disputar os controles, marcha, HUD, camera ou logica de entrada.
    process_physics_priority = 100
    call_deferred("_cache_fleet")

func _cache_fleet() -> void:
    vehicles.clear()
    smoothed_engine.clear()
    parked_time.clear()
    wheel_cache.clear()
    audio_cache.clear()

    for child in get_children():
        if not (child is VehicleBody3D):
            continue
        var vehicle := child as VehicleBody3D
        vehicles.append(vehicle)
        vehicle.can_sleep = true
        var id := vehicle.get_instance_id()
        smoothed_engine[id] = vehicle.engine_force
        parked_time[id] = 0.0

        var wheels: Array[VehicleWheel3D] = []
        for wheel_name in ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]:
            var wheel := vehicle.get_node_or_null(wheel_name) as VehicleWheel3D
            if wheel != null:
                wheels.append(wheel)
        wheel_cache[id] = wheels
        audio_cache[id] = vehicle.get_node_or_null("EngineAudio")

func _physics_process(delta: float) -> void:
    if vehicles.is_empty():
        return

    for vehicle in vehicles:
        if not is_instance_valid(vehicle):
            continue
        var id := vehicle.get_instance_id()
        var driver: Variant = vehicle.get("driver")

        if driver == null:
            _update_parked_vehicle(vehicle, id, delta)
            continue

        if vehicle.sleeping:
            vehicle.sleeping = false
        # CCD fica ligado apenas no veiculo dirigido: mais seguranca em alta
        # velocidade sem pagar o custo em toda a frota estacionada.
        vehicle.continuous_cd = true
        parked_time[id] = 0.0
        _set_audio_paused(id, false)
        _smooth_engine_force(vehicle, id, delta)
        _apply_driving_assists(vehicle, id)

func _update_parked_vehicle(vehicle: VehicleBody3D, id: int, delta: float) -> void:
    vehicle.continuous_cd = false
    smoothed_engine[id] = 0.0

    var almost_stopped := (
        vehicle.linear_velocity.length_squared() < 0.0144
        and vehicle.angular_velocity.length_squared() < 0.0064
    )
    if not almost_stopped:
        parked_time[id] = 0.0
        _set_audio_paused(id, false)
        return

    var time_stopped: float = float(parked_time.get(id, 0.0)) + delta
    parked_time[id] = time_stopped
    if time_stopped >= parked_sleep_delay:
        # Dormir reduz o custo de fisica e audio da frota parada. Colisao ou
        # entrada do jogador acorda o corpo; nenhum veiculo e removido/sumido.
        vehicle.sleeping = true
        _set_audio_paused(id, true)

func _smooth_engine_force(vehicle: VehicleBody3D, id: int, delta: float) -> void:
    var target_force := vehicle.engine_force
    var previous_force: float = float(smoothed_engine.get(id, target_force))

    # Frenagem sempre vence de imediato: nunca deixa motor residual brigando
    # com o freio. A suavizacao existe somente para a entrada da aceleracao.
    if vehicle.brake > 5.0:
        vehicle.engine_force = 0.0
        smoothed_engine[id] = 0.0
        return

    var response := engine_response * (1.65 if absf(target_force) < 0.01 else 1.0)
    var alpha := 1.0 - exp(-delta * response)
    var result := lerpf(previous_force, target_force, alpha)
    if absf(result) < 0.5:
        result = 0.0
    vehicle.engine_force = result
    smoothed_engine[id] = result

func _apply_driving_assists(vehicle: VehicleBody3D, id: int) -> void:
    var wheels: Array = wheel_cache.get(id, [])
    var grounded := 0
    for item in wheels:
        if item is VehicleWheel3D and (item as VehicleWheel3D).is_in_contact():
            grounded += 1
    if grounded < 2:
        return

    var speed := vehicle.linear_velocity.length()
    if speed < 1.5:
        return

    # Direcao progressiva em alta velocidade. Em baixa velocidade o esterco
    # original de cada carro permanece exatamente como configurado na cena.
    var max_steer_value := float(vehicle.get("max_steer"))
    if max_steer_value > 0.01:
        var steer_fade := clampf((speed - 16.0) / 40.0, 0.0, 1.0)
        var steer_limit := max_steer_value * lerpf(1.0, high_speed_steer_ratio, steer_fade)
        vehicle.steering = clampf(vehicle.steering, -steer_limit, steer_limit)

    var steer_usage := clampf(absf(vehicle.steering) / maxf(max_steer_value, 0.10), 0.0, 1.0)
    var speed_factor := clampf((speed - 3.0) / 48.0, 0.0, 1.0)
    var horizontal_right := vehicle.global_transform.basis.x
    horizontal_right.y = 0.0
    if horizontal_right.length_squared() > 0.001:
        horizontal_right = horizontal_right.normalized()
        var lateral_speed := vehicle.linear_velocity.dot(horizontal_right)
        # Em reta a ajuda e completa; com volante esterçado ela recua para nao
        # matar a curva nem deixar o carro pesado/robotico.
        var turn_relief := lerpf(1.0, 0.35, steer_usage)
        var lateral_force := -horizontal_right * lateral_speed * vehicle.mass * lateral_stability * (0.30 + speed_factor * 0.70) * turn_relief
        var lateral_cap := vehicle.mass * 5.5
        if lateral_force.length() > lateral_cap:
            lateral_force = lateral_force.normalized() * lateral_cap
        vehicle.apply_central_force(lateral_force)

        # Amortece guinada excessiva principalmente quando o volante esta perto
        # do centro; em curvas intencionais a assistencia diminui automaticamente.
        var yaw_speed := vehicle.angular_velocity.dot(Vector3.UP)
        var yaw_factor := 1.0 - steer_usage * 0.72
        var yaw_torque := -Vector3.UP * yaw_speed * vehicle.mass * yaw_stability * speed_factor * yaw_factor
        var yaw_cap := vehicle.mass * 3.5
        if yaw_torque.length() > yaw_cap:
            yaw_torque = yaw_torque.normalized() * yaw_cap
        vehicle.apply_torque(yaw_torque)

    # Pressao aerodinamica moderada: melhora contato das rodas em velocidade sem
    # alterar suspensao, centro de massa ou altura individual de nenhum modelo.
    var contact_ratio := float(grounded) / 4.0
    var downforce := minf(speed * speed * downforce_coefficient, vehicle.mass * 9.81 * 0.30) * contact_ratio
    vehicle.apply_central_force(Vector3.DOWN * downforce)

func _set_audio_paused(id: int, paused: bool) -> void:
    var audio: Variant = audio_cache.get(id, null)
    if audio is AudioStreamPlayer3D and is_instance_valid(audio):
        (audio as AudioStreamPlayer3D).stream_paused = paused

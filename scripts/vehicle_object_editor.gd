extends PanelContainer
## BR1: independent H tab for parked and spawned driveable vehicles.
## Physics is paused only while a car is actively selected for editing.
const BLUE := Color("4b91ff")
const RED := Color("f04e64")
const PALE := Color("eaf1ff")
const DIM := Color("a7bcd3")
const AXES: Array[String] = ["X", "Y", "Z"]
const MODEL_LABELS: Array[String] = ["BMW", "MERCEDES GLS", "FORD RAPTOR", "RAPTOR POLICIAL", "BLINDADO", "BLINDADO 2", "URUS", "DUSTER POLICIAL"]
const MODEL_PATHS: Array[String] = ["res://scenes/v24_bmw.tscn", "res://scenes/v24_gls.tscn", "res://scenes/v30_6_raptor_dirigivel.tscn", "res://scenes/v0_0_1_raptor_policial.tscn", "res://scenes/v30_6_blindado_dirigivel.tscn", "res://scenes/v0_0_1_blindado_2.tscn", "res://scenes/v50_urus.tscn", "res://scenes/v51_duster_policia_dirigivel.tscn"]
var player: Node3D
var store = null
var go_home: Callable
var selected: VehicleBody3D
var previous_freeze: bool = false
var initial: Dictionary = {}
var selected_candidates: Array[int] = []
var model_choice: OptionButton
var nearby: OptionButton
var selected_label: Label
var status: Label
var values: Array = []
var xyz_sliders: Dictionary = {}
var ignore_changes: bool = false
var dirty: bool = false

func setup(owner_player: Node3D, vehicle_store: Node3D, back: Callable) -> void:
    player = owner_player
    store = vehicle_store
    go_home = back
    name = "EditorDeVeiculos"
    anchor_left = 1.0
    anchor_right = 1.0
    anchor_top = 0.0
    anchor_bottom = 1.0
    offset_left = -444.0
    offset_right = -12.0
    offset_top = 10.0
    offset_bottom = -10.0
    var style := StyleBoxFlat.new()
    style.bg_color = Color("0b192e")
    style.border_color = BLUE
    style.set_border_width_all(1)
    style.set_corner_radius_all(12)
    style.content_margin_left = 13
    style.content_margin_right = 13
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    add_theme_stylebox_override("panel", style)
    mouse_filter = Control.MOUSE_FILTER_STOP
    visible = false
    _build()

func _label(caption: String, font_size: int = 13, text_color: Color = PALE) -> Label:
    var item := Label.new()
    item.text = caption
    item.add_theme_color_override("font_color", text_color)
    item.add_theme_font_size_override("font_size", font_size)
    item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return item

func _button(caption: String, action: Callable, highlight: bool = false) -> Button:
    var item := Button.new()
    item.text = caption
    item.custom_minimum_size.y = 36
    item.add_theme_color_override("font_color", PALE)
    var skin := StyleBoxFlat.new()
    skin.bg_color = Color("843847") if highlight else Color("19334e")
    skin.border_color = RED if highlight else BLUE
    skin.set_border_width_all(1)
    skin.set_corner_radius_all(9)
    item.add_theme_stylebox_override("normal", skin)
    item.pressed.connect(action)
    return item

func _row(parent: VBoxContainer, buttons: Array) -> void:
    var line := HBoxContainer.new()
    line.add_theme_constant_override("separation", 5)
    for item in buttons:
        item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        line.add_child(item)
    parent.add_child(line)

func _add_number(layout: VBoxContainer, caption: String, help: String, minimum: float, maximum: float, step_value: float, value_index: int, default_value: float = 0.0) -> void:
    layout.add_child(_label(caption, 12, PALE))

    var number := SpinBox.new()
    number.min_value = minimum
    number.max_value = maximum
    number.step = step_value
    number.value = default_value
    number.allow_greater = value_index >= 0 and value_index < 6
    number.allow_lesser = value_index >= 0 and value_index < 6
    number.value_changed.connect(_value_changed.bind(value_index))

    if value_index >= 0 and value_index < 6:
        var slider := HSlider.new()
        slider.min_value = minimum
        slider.max_value = maximum
        slider.step = step_value
        slider.custom_minimum_size.y = 20
        slider.value = default_value
        slider.value_changed.connect(_xyz_slider_changed.bind(value_index))
        layout.add_child(slider)
        xyz_sliders[value_index] = slider

    var input_row := HBoxContainer.new()
    var input_label := _label("DIGITAR VALOR", 10, DIM)
    input_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    input_row.add_child(input_label)
    number.custom_minimum_size = Vector2(175, 34)
    input_row.add_child(number)
    layout.add_child(input_row)

    if not help.is_empty():
        layout.add_child(_label(help, 10, DIM))
    while values.size() <= value_index:
        values.append(null)
    values[value_index] = number

func _build() -> void:
    values.clear()
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    var layout := VBoxContainer.new()
    layout.custom_minimum_size.x = 410.0
    layout.add_theme_constant_override("separation", 7)
    scroll.add_child(layout)
    layout.add_child(_label("VEÍCULOS", 20))
    layout.add_child(_label("1. Selecione  →  2. Ajuste  →  3. Salve", 12, DIM))
    _row(layout, [_button("‹ CATEGORIAS", _go_back), _button("FECHAR", _go_back)])

    layout.add_child(_label("1 · SELECIONAR UM VEÍCULO", 13, BLUE))
    _row(layout, [_button("ATUALIZAR LISTA", _fill_nearby), _button("SELECIONAR NA MIRA", _select_aimed)])
    nearby = OptionButton.new()
    nearby.custom_minimum_size.y = 40.0
    nearby.item_selected.connect(_choose_nearby)
    layout.add_child(nearby)
    selected_label = _label("Nenhum veículo selecionado", 13, BLUE)
    layout.add_child(selected_label)

    layout.add_child(_label("2 · SUSPENSÃO E RODAS", 13, BLUE))
    _add_number(layout, "ALTURA DA SUSPENSÃO", "Maior = carro mais alto. Menor = carro mais baixo.", 0.03, 0.75, 0.005, 8, 0.22)
    _add_number(layout, "CURSO DA SUSPENSÃO", "Quanto a roda pode subir/descer ao passar em irregularidades.", 0.02, 0.80, 0.005, 9, 0.22)
    _add_number(layout, "LARGURA ENTRE AS RODAS", "Afasta/aproxima as rodas esquerda e direita (bitola).", 0.75, 4.50, 0.01, 10, 1.90)
    _add_number(layout, "COMPRIMENTO ENTRE OS EIXOS", "Distância entre rodas dianteiras e traseiras.", 1.20, 6.50, 0.01, 11, 3.00)
    _add_number(layout, "TAMANHO DOS PNEUS", "Aumenta/diminui o raio físico e visual das quatro rodas.", 0.20, 0.90, 0.005, 12, 0.40)

    layout.add_child(_label("VEÍCULO", 13, BLUE))
    _add_number(layout, "TAMANHO GERAL", "Escala carroceria, colisão e rodas de forma proporcional.", 0.85, 1.60, 0.01, 6, 1.06)
    _add_number(layout, "FORÇA DO MOTOR", "Aumente com cuidado: valores altos podem reduzir estabilidade.", 500.0, 9000.0, 50.0, 7, 3650.0)

    layout.add_child(_label("POSIÇÃO DO VEÍCULO", 13, BLUE))
    for axis_id in range(6):
        if axis_id == 3:
            layout.add_child(_label("ROTAÇÃO · graus", 12, BLUE))
        _add_number(layout, ("POSIÇÃO " if axis_id < 3 else "ROTAÇÃO ") + AXES[axis_id % 3], "", -10000.0 if axis_id < 3 else -720.0, 10000.0 if axis_id < 3 else 720.0, 0.05 if axis_id < 3 else 1.0, axis_id)

    _row(layout, [_button("↶ GIRAR VISÃO", _orbit.bind(-0.25)), _button("GIRAR VISÃO ↷", _orbit.bind(0.25))])
    _row(layout, [_button("DESFAZER AJUSTES", _undo), _button("REMOVER CRIADO", _remove)])

    layout.add_child(_label("ADICIONAR OUTRO VEÍCULO", 13, BLUE))
    model_choice = OptionButton.new()
    for label_value in MODEL_LABELS:
        model_choice.add_item(label_value)
    layout.add_child(model_choice)
    _row(layout, [_button("CRIAR NA FRENTE", _create, true), _button("DUPLICAR SELECIONADO", _duplicate)])

    layout.add_child(_label("3 · FINALIZAR", 13, BLUE))
    _row(layout, [_button("SALVAR VEÍCULOS", _save, true), _button("ATUALIZAR", _fill_nearby)])
    status = _label("Selecione um veículo vazio. Durante a edição ele fica travado para não sair do lugar.", 12, DIM)
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(status)
    layout.add_child(_label("SALVAR grava posição, motor, suspensão e rodas. Depois, quando você terminar o jogo, esses dados podem ser incorporados e o painel H removido.", 11, DIM))

func begin() -> void:
    visible = true
    _fill_nearby()
    _refresh_values()

func end() -> void:
    visible = false
    _release()

func _go_back() -> void:
    end()
    if go_home.is_valid():
        go_home.call()

func _release() -> void:
    if selected != null and is_instance_valid(selected):
        _remember()
        selected.freeze = previous_freeze
    selected = null

func _eligible(car: VehicleBody3D) -> bool:
    return car != null and is_instance_valid(car) and not car.is_queued_for_deletion() and car.has_method("_apply_vehicle_size") and car.get("driver") == null

func _fill_nearby() -> void:
    if nearby == null or not is_instance_valid(nearby):
        return
    nearby.clear()
    selected_candidates.clear()
    if player == null or not is_instance_valid(player):
        return
    var available: Array[VehicleBody3D] = []
    for node in get_tree().get_nodes_in_group("vehicle"):
        var car: VehicleBody3D = node as VehicleBody3D
        if _eligible(car) and car.global_position.distance_to(player.global_position) <= 175.0:
            available.append(car)
    available.sort_custom(func(a: VehicleBody3D, b: VehicleBody3D) -> bool:
        return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position))
    for car in available:
        if selected_candidates.size() >= 45:
            break
        selected_candidates.append(car.get_instance_id())
        nearby.add_item("%s · %.0f m" % [str(car.get("vehicle_name")), car.global_position.distance_to(player.global_position)])
    nearby.disabled = selected_candidates.is_empty()
    if selected_candidates.is_empty():
        nearby.add_item("Nenhum veículo vazio num raio de 175 m")
    else:
        nearby.select(-1)

func _choose_nearby(index: int) -> void:
    if index < 0 or index >= selected_candidates.size():
        return
    var candidate: Object = instance_from_id(selected_candidates[index])
    if not is_instance_valid(candidate) or not (candidate is VehicleBody3D):
        status.text = "O veículo saiu da área. Atualizando a lista..."
        call_deferred("_fill_nearby")
        return
    var car: VehicleBody3D = candidate as VehicleBody3D
    if not _eligible(car):
        status.text = "O veículo não está mais disponível para edição."
        call_deferred("_fill_nearby")
        return
    _choose(car)

func _select_aimed() -> void:
    var camera: Camera3D = player.get("camera") as Camera3D
    if camera == null:
        status.text = "Câmera indisponível."
        return
    var start: Vector3 = camera.global_position
    var query := PhysicsRayQueryParameters3D.create(start, start - camera.global_basis.z * 135.0)
    query.exclude = [(player as CollisionObject3D).get_rid()]
    var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
    var node: Node = hit.get("collider") as Node
    while node != null and not (node is VehicleBody3D):
        node = node.get_parent()
    var car: VehicleBody3D = node as VehicleBody3D
    if _eligible(car):
        _choose(car)
    else:
        status.text = "Mire em um veículo vazio para editar."

func _choose(car: VehicleBody3D) -> void:
    if not _eligible(car):
        status.text = "Saia do veículo e deixe-o parado antes de editar."
        return
    _release()
    selected = car
    previous_freeze = selected.freeze
    selected.linear_velocity = Vector3.ZERO
    selected.angular_velocity = Vector3.ZERO
    selected.freeze = true
    initial = store.capture(selected)
    selected_label.text = "SELECIONADO: %s" % str(selected.get("vehicle_name"))
    _refresh_values()
    status.text = "Edite o carro imóvel e clique SALVAR VEÍCULOS."

func _refresh_values() -> void:
    if selected == null or not is_instance_valid(selected):
        return
    ignore_changes = true
    var metrics: Dictionary = store.wheel_metrics(selected)
    var list_values: Array = [
        selected.global_position.x, selected.global_position.y, selected.global_position.z,
        selected.rotation_degrees.x, selected.rotation_degrees.y, selected.rotation_degrees.z,
        float(selected.get("overall_scale")), float(selected.get("engine_power")),
        float(metrics["suspension"]), float(metrics["travel"]), float(metrics["track"]),
        float(metrics["wheelbase"]), float(metrics["radius"])
    ]
    for index in range(mini(values.size(), list_values.size())):
        if values[index] != null:
            values[index].set_value_no_signal(float(list_values[index]))
        if xyz_sliders.has(index):
            (xyz_sliders[index] as HSlider).set_value_no_signal(float(list_values[index]))
    ignore_changes = false

func _value_changed(amount: float, axis: int) -> void:
    if xyz_sliders.has(axis):
        (xyz_sliders[axis] as HSlider).set_value_no_signal(amount)
    if ignore_changes or selected == null or not is_instance_valid(selected):
        return
    if not is_finite(amount):
        status.text = "Valor inválido ignorado. Use apenas números dentro do limite mostrado."
        _refresh_values()
        return
    if axis < 3:
        var target: Vector3 = selected.global_position
        target[axis] = amount
        selected.global_position = target
    elif axis < 6:
        var target_rotation: Vector3 = selected.rotation_degrees
        target_rotation[axis - 3] = amount
        selected.rotation_degrees = target_rotation
    elif axis == 6:
        var old_size: float = float(selected.get("overall_scale"))
        if not is_finite(old_size) or old_size <= 0.01:
            old_size = 1.06
        var factor: float = amount / old_size
        if is_finite(factor) and factor > 0.0 and selected.has_method("_apply_vehicle_size"):
            selected.call("_apply_vehicle_size", factor)
            selected.set("overall_scale", amount)
            _refresh_values()
    elif axis == 7:
        selected.set("engine_power", amount)
    else:
        var metrics: Dictionary = store.wheel_metrics(selected)
        var suspension: float = float(metrics["suspension"])
        var travel: float = float(metrics["travel"])
        var track: float = float(metrics["track"])
        var wheelbase: float = float(metrics["wheelbase"])
        var radius: float = float(metrics["radius"])
        match axis:
            8: suspension = amount
            9: travel = amount
            10: track = amount
            11: wheelbase = amount
            12: radius = amount
        store.apply_wheel_settings(selected, suspension, travel, track, wheelbase, radius)
    _remember()
    dirty = true
    status.text = "Alteração aplicada. Clique SALVAR VEÍCULOS quando terminar."

func _xyz_slider_changed(amount: float, axis: int) -> void:
    if axis < 0 or axis >= values.size() or values[axis] == null:
        return
    (values[axis] as SpinBox).set_value_no_signal(amount)
    _value_changed(amount, axis)

func _remember() -> void:
    if selected != null and is_instance_valid(selected):
        store.remember(selected)

func _create() -> void:
    if player == null or not is_instance_valid(player):
        return
    var camera: Camera3D = player.get("camera") as Camera3D
    var forward: Vector3 = -player.global_basis.z
    if camera != null:
        forward = -camera.global_basis.z
    forward.y = 0.0
    forward = forward.normalized()
    var location: Vector3 = player.global_position + forward * 13.0
    location.y = player.global_position.y + 1.1
    status.text = "Criando veículo dirigível, aguarde o modelo carregar..."
    var car: VehicleBody3D = store.spawn(model_choice.selected, location, player.global_rotation.y)
    if car == null:
        status.text = "Não foi possível criar este modelo."
        return
    dirty = true
    _choose(car)
    _fill_nearby()
    status.text = "Veículo criado. Ajuste o estacionamento e salve."

func _duplicate() -> void:
    if selected == null or not is_instance_valid(selected):
        status.text = "Selecione um veículo primeiro."
        return
    var origin: VehicleBody3D = selected
    var kind: int = int(origin.get_meta("vehicle_edit_kind", -1))
    if kind < 0:
        # Original cars are identified by their scene source, not by mesh name.
        var source_path: String = origin.scene_file_path
        kind = MODEL_PATHS.find(source_path)
    if kind < 0:
        status.text = "Para duplicar este veículo, escolha o modelo na lista ADICIONAR."
        return
    var copy_car: VehicleBody3D = store.spawn(kind, origin.global_position + Vector3(3.5, 0, 0), origin.rotation.y)
    if copy_car == null:
        status.text = "Falha ao duplicar o veículo."
        return
    var transforms: Dictionary = store.capture(origin)
    transforms["pos"] = [copy_car.global_position.x, copy_car.global_position.y, copy_car.global_position.z]
    store.apply_data(copy_car, transforms)
    dirty = true
    _choose(copy_car)
    _fill_nearby()

func _undo() -> void:
    if selected == null or not is_instance_valid(selected):
        return
    store.apply_data(selected, initial)
    _remember()
    _refresh_values()
    dirty = true
    status.text = "Posição inicial desta seleção restaurada; salve para manter."

func _remove() -> void:
    if selected == null or not is_instance_valid(selected):
        return
    var car: VehicleBody3D = selected
    if car.get_parent() != store.get("spawned_root"):
        status.text = "Veículo original protegido. Só os criados pelo editor podem ser removidos."
        return
    _release()
    if store.remove_spawned(car):
        dirty = true
        selected_label.text = "Nenhum veículo selecionado"
        status.text = "Veículo criado removido. Clique SALVAR VEÍCULOS."
        _fill_nearby()

func _orbit(angle: float) -> void:
    if player != null and is_instance_valid(player):
        player.set("cam_yaw", wrapf(float(player.get("cam_yaw")) + angle, -PI, PI))
        player.call("_update_camera_transform")

func _save() -> void:
    _remember()
    var result: Dictionary = store.save()
    if int(result["local"]) != OK:
        status.text = "Falha ao salvar neste dispositivo: %d" % int(result["local"])
        return
    dirty = false
    if int(result["project"]) == OK:
        status.text = "Salvo no projeto e no dispositivo. Inclua vehicle_edits.json no próximo ZIP."
    else:
        status.text = "Salvo neste dispositivo. Envie vehicle_edits.json para incorporar à versão distribuída."

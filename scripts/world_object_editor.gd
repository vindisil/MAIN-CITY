extends PanelContainer
## World editing tab in the H development panel. Objects are saved by the store
## and reapplied after world-streaming sector reloads. No edit-time update loop.
const BLUE := Color("4b91ff")
const RED := Color("f04e64")
const PALE := Color("eaf1ff")
const DIM := Color("a7bcd3")
const AXES: Array[String] = ["X", "Y", "Z"]
const KINDS: Array[String] = ["predio", "casa", "arvore", "montanha", "rocha", "poste", "muro", "cerca", "placa", "banco", "barreira", "caixa", "cone"]
const LABELS: Array[String] = ["PRÉDIO", "CASA", "ÁRVORE", "MONTANHA", "ROCHA", "POSTE", "MURO", "CERCA", "PLACA", "BANCO", "BARREIRA", "CAIXA", "CONE"]
var p: Node3D
var store = null
var go_home: Callable
var selected: Node3D = null
var initial_transform: Dictionary = {}
var current_kind: int = 0
# Keep object IDs, not Node3D references: world streaming/removal can free nodes
# while their names are still listed in the OptionButton.
var selected_candidates: Array[int] = []
var refreshing_nearby: bool = false
var filter_index: int = 0
var nearby: OptionButton
var category: OptionButton
var kind_option: OptionButton
var world_status: Label
var selected_name: Label
var spin_controls: Array[SpinBox] = []
var xyz_sliders: Array[HSlider] = []
var visible_choice: CheckBox
var ignore_changes: bool = false
var unsaved: bool = false
var root_city: Node3D

func setup(player: Node3D, world_store: Node3D, back: Callable) -> void:
    p = player
    store = world_store
    go_home = back
    root_city = p.get_parent().get_node_or_null("Cidade") as Node3D
    name = "EditorDoMundo"
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
    item.custom_minimum_size.y = 36.0
    item.add_theme_font_size_override("font_size", 13)
    item.add_theme_color_override("font_color", PALE)
    var skin := StyleBoxFlat.new()
    skin.bg_color = Color("843847") if highlight else Color("19334e")
    skin.border_color = RED if highlight else BLUE
    skin.set_border_width_all(1)
    skin.set_corner_radius_all(9)
    skin.content_margin_left = 8
    skin.content_margin_right = 8
    skin.content_margin_top = 7
    skin.content_margin_bottom = 7
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

func _build() -> void:
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    var layout := VBoxContainer.new()
    layout.custom_minimum_size.x = 383
    layout.add_theme_constant_override("separation", 7)
    scroll.add_child(layout)
    layout.add_child(_label("ESTRUTURAS · OBJETOS", 20))
    layout.add_child(_label("1. Escolha/crie  →  2. Posicione  →  3. Salve", 12, DIM))
    _row(layout, [_button("‹ CATEGORIAS", _go_back), _button("FECHAR PAINEL", _go_back)])
    layout.add_child(_label("1 · ADICIONAR OU SELECIONAR", 13, BLUE))
    kind_option = OptionButton.new()
    for kind_label in LABELS:
        kind_option.add_item(kind_label)
    kind_option.item_selected.connect(func(i: int) -> void: current_kind = i)
    layout.add_child(kind_option)
    _row(layout, [_button("CRIAR NA FRENTE", _create, true), _button("DUPLICAR", _duplicate)])
    layout.add_child(_label("OBJETOS JÁ EXISTENTES", 12, BLUE))
    category = OptionButton.new()
    for label_value in ["TODOS", "CONSTRUÇÕES", "ÁRVORES", "MONTANHAS / ROCHAS", "OBJETOS / OUTROS"]:
        category.add_item(label_value)
    category.item_selected.connect(_filter_changed)
    layout.add_child(category)
    _row(layout, [_button("LISTAR PRÓXIMOS", _fill_nearby), _button("SELECIONAR NA MIRA", _select_aimed)])
    nearby = OptionButton.new()
    nearby.custom_minimum_size.y = 38
    nearby.item_selected.connect(_choose_nearby)
    layout.add_child(nearby)
    selected_name = _label("Nenhum objeto selecionado", 13, BLUE)
    layout.add_child(selected_name)
    layout.add_child(_label("2 · POSIÇÃO · metros", 13, BLUE))
    for axis_id in range(9):
        if axis_id == 3:
            layout.add_child(_label("ROTAÇÃO · graus", 12, BLUE))
        if axis_id == 6:
            layout.add_child(_label("TAMANHO · escala", 12, BLUE))
        var caption: String = AXES[axis_id % 3]
        var title_row := HBoxContainer.new()
        title_row.add_child(_label(caption, 13))
        layout.add_child(title_row)

        var number := SpinBox.new()
        number.min_value = -10000.0 if axis_id < 3 else (-720.0 if axis_id < 6 else 0.05)
        number.max_value = 10000.0 if axis_id < 3 else (720.0 if axis_id < 6 else 24.0)
        number.step = 0.05 if axis_id < 3 else (1.0 if axis_id < 6 else 0.05)
        number.value = 1.0 if axis_id >= 6 else 0.0
        number.allow_greater = axis_id < 6
        number.allow_lesser = axis_id < 6
        number.value_changed.connect(_value_changed.bind(axis_id))
        spin_controls.append(number)

        var slider := HSlider.new()
        slider.min_value = number.min_value
        slider.max_value = number.max_value
        slider.step = number.step
        slider.custom_minimum_size.y = 20
        slider.value = number.value
        slider.value_changed.connect(_slider_changed.bind(axis_id))
        layout.add_child(slider)
        xyz_sliders.append(slider)

        var input_row := HBoxContainer.new()
        var input_label := _label("DIGITAR VALOR", 10, DIM)
        input_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        input_row.add_child(input_label)
        number.custom_minimum_size = Vector2(175, 34)
        input_row.add_child(number)
        layout.add_child(input_row)
    visible_choice = CheckBox.new()
    visible_choice.text = "OBJETO VISÍVEL"
    visible_choice.button_pressed = true
    visible_choice.toggled.connect(_visibility_changed)
    layout.add_child(visible_choice)
    _row(layout, [_button("↶ GIRAR CÂMERA", _orbit.bind(-0.25)), _button("GIRAR CÂMERA ↷", _orbit.bind(0.25))])
    _row(layout, [_button("DESFAZER AJUSTE", _undo), _button("REMOVER CRIADO", _remove)])
    layout.add_child(_label("3 · FINALIZAR", 13, BLUE))
    _row(layout, [_button("SALVAR MUNDO", _save, true), _button("ATUALIZAR LISTA", _fill_nearby)])
    world_status = _label("Salvar grava mundo e posições nesta máquina; no Godot também grava world_edits.json no projeto.", 12, DIM)
    layout.add_child(world_status)
    layout.add_child(_label("Blocos do mapa recarregam: alterações salvas são reaplicadas. " +
        "Itens de MultiMesh (lotes repetidos) não podem ser movidos individualmente neste painel; " +
        "use os objetos criados aqui ou uma cena individual.", 11, DIM))

func _go_back() -> void:
    if unsaved:
        _commit_selected()
        world_status.text = "Existem alterações não salvas. Use SALVAR MUNDO para persistir."
    if go_home.is_valid():
        go_home.call()

func begin() -> void:
    visible = true
    _fill_nearby()
    if selected != null and is_instance_valid(selected):
        _refresh_values()

func end() -> void:
    visible = false
    _commit_selected()

func _category_for(node: Node3D) -> int:
    var text_name: String = str(node.name).to_lower() + " " + str(node.get_meta("world_editor_kind", ""))
    if "arvor" in text_name or "tree" in text_name or "palmeira" in text_name:
        return 2
    if "montanha" in text_name or "mountain" in text_name or "rocha" in text_name or "rock" in text_name:
        return 3
    if "predio" in text_name or "building" in text_name or "casa" in text_name or "house" in text_name or "lote" in text_name:
        return 1
    return 4

func _eligible(node: Node3D) -> bool:
    if node == null or not is_instance_valid(node) or node == store or node == p:
        return false
    if node is MultiMeshInstance3D or node is VehicleBody3D or node is CharacterBody3D:
        return false
    if node.get_parent() == store.world:
        return true
    if store.key_of(node).is_empty():
        return false
    if str(node.name).begins_with("Setor_") or str(node.name).begins_with("group") or str(node.name).begins_with("Solid"):
        return false
    if node.scene_file_path != "":
        return true
    if node.get_parent() is Node3D and str(node.get_parent().scene_file_path) != "":
        return node.get_child_count() > 0 and not (node is CollisionShape3D)
    return false

func _filter_changed(index: int) -> void:
    filter_index = index
    _fill_nearby()

func _fill_nearby() -> void:
    if not is_instance_valid(nearby):
        return
    refreshing_nearby = true
    nearby.clear()
    nearby.disabled = true
    selected_candidates.clear()
    # Objects, sector roots or the editor store may be freed during streaming.
    if not is_instance_valid(p) or not is_instance_valid(root_city) or not is_instance_valid(store) or not is_instance_valid(store.world):
        refreshing_nearby = false
        return
    var options: Array[Node3D] = []
    if store.world != null:
        for item in store.world.get_children():
            if item is Node3D:
                options.append(item)
    # Streamed imported districts live directly under main, not under Cidade.
    for extra in p.get_parent().get_children():
        if extra is Node3D and extra != root_city and extra != store and _eligible(extra):
            options.append(extra)
    for sector in root_city.get_children():
        if not (sector is Node3D):
            continue
        if sector.scene_file_path != "" and not str(sector.name).begins_with("Setor_"):
            options.append(sector)
        for item in sector.get_children():
            if item is Node3D and _eligible(item):
                options.append(item)
            if item is Node3D and ("predio" in str(item.name).to_lower() or "arvor" in str(item.name).to_lower()):
                for inner in item.get_children():
                    if inner is Node3D and _eligible(inner):
                        options.append(inner)
    options.sort_custom(func(a: Node3D, b: Node3D) -> bool:
        return a.global_position.distance_squared_to(p.global_position) < b.global_position.distance_squared_to(p.global_position))
    for item in options:
        if selected_candidates.size() >= 60:
            break
        if not is_instance_valid(item) or item.is_queued_for_deletion():
            continue
        if item.global_position.distance_to(p.global_position) > 155.0:
            continue
        if filter_index != 0 and _category_for(item) != filter_index:
            continue
        selected_candidates.append(item.get_instance_id())
        nearby.add_item("%s · %.0f m" % [item.name, item.global_position.distance_to(p.global_position)])
    if selected_candidates.is_empty():
        nearby.add_item("Sem objetos individuais nesta área")
        nearby.disabled = true
    else:
        nearby.disabled = false
    # Clearing/rebuilding the option list must not select a stale row.
    nearby.select(-1)
    refreshing_nearby = false

func _choose_nearby(index: int) -> void:
    if refreshing_nearby or index < 0 or index >= selected_candidates.size():
        return
    # IDs do not retain freed Node3D objects. Resolve only at click time.
    var object_id: int = selected_candidates[index]
    var candidate: Object = instance_from_id(object_id)
    if not is_instance_valid(candidate) or not (candidate is Node3D):
        world_status.text = "Objeto removido do mapa. Atualizando lista..."
        call_deferred("_fill_nearby")
        return
    var target: Node3D = candidate as Node3D
    if target.is_queued_for_deletion() or not target.is_inside_tree():
        world_status.text = "Objeto indisponível. Atualizando lista..."
        call_deferred("_fill_nearby")
        return
    _choose(target)

func _select_aimed() -> void:
    if p == null or not is_instance_valid(p):
        return
    var camera: Camera3D = p.get("camera") as Camera3D
    if camera == null:
        world_status.text = "Câmera não está pronta."
        return
    var start: Vector3 = camera.global_position
    var ray_end: Vector3 = start - camera.global_basis.z * 145.0
    var query := PhysicsRayQueryParameters3D.create(start, ray_end)
    query.exclude = [(p as CollisionObject3D).get_rid()]
    var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        world_status.text = "Nenhum objeto atingido pela mira."
        return
    var item: Node3D = hit.get("collider") as Node3D
    if item == null:
        return
    if item.get_parent() == store.world:
        _choose(item)
        return
    var cursor: Node = item
    while cursor != null and cursor != root_city:
        if cursor is Node3D and _eligible(cursor) and not (cursor is CollisionShape3D):
            _choose(cursor)
            return
        cursor = cursor.get_parent()
    world_status.text = "A mira acertou parte agrupada do mapa. Escolha uma cena individual na lista."

func _choose(item: Variant) -> void:
    # Signals can arrive with a stale selection after an object is removed.
    # Do not take a typed Node3D argument until the instance is proven alive.
    if not is_instance_valid(item) or not (item is Node3D):
        world_status.text = "O objeto selecionado já foi removido. Atualize a lista."
        return
    var target: Node3D = item as Node3D
    if target.is_queued_for_deletion():
        world_status.text = "O objeto selecionado está sendo removido."
        return
    if not _eligible(target):
        world_status.text = "Este objeto não é editável individualmente."
        return
    _commit_selected()
    selected = target
    initial_transform = store.capture(selected)
    selected_name.text = "SELECIONADO: %s" % selected.name
    _refresh_values()
    world_status.text = "Ajuste valores e clique SALVAR MUNDO."

func _refresh_values() -> void:
    if selected == null or not is_instance_valid(selected):
        return
    ignore_changes = true
    var values: Array = [selected.position.x, selected.position.y, selected.position.z,
        selected.rotation_degrees.x, selected.rotation_degrees.y, selected.rotation_degrees.z,
        selected.scale.x, selected.scale.y, selected.scale.z]
    for index in range(spin_controls.size()):
        spin_controls[index].set_value_no_signal(float(values[index]))
        if xyz_sliders.size() > index:
            xyz_sliders[index].set_value_no_signal(float(values[index]))
    visible_choice.set_pressed_no_signal(selected.visible)
    ignore_changes = false

func _value_changed(value: float, axis: int) -> void:
    if xyz_sliders.size() > axis and axis >= 0:
        xyz_sliders[axis].set_value_no_signal(value)
    if ignore_changes or selected == null or not is_instance_valid(selected):
        return
    if axis < 3:
        var loc: Vector3 = selected.position
        loc[axis] = value
        selected.position = loc
    elif axis < 6:
        var rotation_now: Vector3 = selected.rotation_degrees
        rotation_now[axis - 3] = value
        selected.rotation_degrees = rotation_now
    else:
        var size_now: Vector3 = selected.scale
        size_now[axis - 6] = value
        selected.scale = size_now
    _commit_selected()
    unsaved = true
    world_status.text = "Alteração ao vivo. Clique SALVAR MUNDO para manter."

func _slider_changed(value: float, axis: int) -> void:
    if axis < 0 or spin_controls.size() <= axis:
        return
    spin_controls[axis].set_value_no_signal(value)
    _value_changed(value, axis)

func _visibility_changed(checked: bool) -> void:
    if selected != null and is_instance_valid(selected):
        store.set_visible_state(selected, checked)
        _commit_selected()
        unsaved = true

func _commit_selected() -> void:
    if selected == null or not is_instance_valid(selected):
        return
    if selected.get_parent() == store.world:
        store.remember_created(selected)
    else:
        store.remember_existing(selected)

func _create() -> void:
    if p == null or not is_instance_valid(p):
        return
    var camera: Camera3D = p.get("camera") as Camera3D
    var forward: Vector3 = -p.global_basis.z
    if camera != null:
        forward = -camera.global_basis.z
    forward.y = 0.0
    forward = forward.normalized()
    var location: Vector3 = p.global_position + forward * 15.0
    # Place on the nearby ground, unless the ray hits a building: in that case
    # use the player's ground height as a safe editable starting position.
    location.y = p.global_position.y
    var item: Node3D = store.add_object(KINDS[current_kind], location)
    if item != null:
        _choose(item)
        unsaved = true
        world_status.text = "Objeto criado. Posicione e clique SALVAR MUNDO."

func _duplicate() -> void:
    if selected == null or not is_instance_valid(selected):
        world_status.text = "Selecione um objeto antes de duplicar."
        return
    var kind: String = str(selected.get_meta("world_editor_kind", ""))
    if not KINDS.has(kind):
        world_status.text = "A duplicação está disponível para objetos criados neste painel."
        return
    var item: Node3D = store.add_object(kind, selected.global_position + Vector3(3, 0, 0))
    if item != null:
        item.rotation_degrees = selected.rotation_degrees
        item.scale = selected.scale
        _choose(item)
        unsaved = true

func _remove() -> void:
    if selected == null or not is_instance_valid(selected):
        return
    if selected.is_queued_for_deletion():
        return
    # Keep the original-world protection without deleting any existing assets.
    if not is_instance_valid(store) or not is_instance_valid(store.world) or selected.get_parent() != store.world:
        world_status.text = "Objetos originais não são excluídos por segurança. Desmarque OBJETO VISÍVEL para ocultar uma cena individual."
        return
    # Capture the current node and invalidate ALL UI references before freeing.
    # Otherwise OptionButton may emit item_selected with its old, freed Node3D.
    var to_remove: Node3D = selected
    selected = null
    initial_transform.clear()
    nearby.clear()
    nearby.disabled = true
    selected_candidates.clear()
    selected_name.text = "Nenhum objeto selecionado"
    if not store.remove_created(to_remove):
        world_status.text = "Não foi possível remover este objeto."
        call_deferred("_fill_nearby")
        return
    unsaved = true
    world_status.text = "Objeto criado removido. Clique SALVAR MUNDO."
    # queue_free() runs at the end of this frame; refresh only afterwards.
    call_deferred("_fill_nearby")

func _undo() -> void:
    if selected == null or not is_instance_valid(selected):
        return
    store.apply_data(selected, initial_transform)
    _commit_selected()
    _refresh_values()
    unsaved = true
    world_status.text = "Transformação restaurada. Clique SALVAR MUNDO para manter."

func _orbit(angle: float) -> void:
    if p != null and is_instance_valid(p):
        p.set("cam_yaw", wrapf(float(p.get("cam_yaw")) + angle, -PI, PI))
        p.call("_update_camera_transform")

func _save() -> void:
    _commit_selected()
    var result: Dictionary = store.save()
    if int(result["local"]) != OK:
        world_status.text = "Falha ao salvar: código %d" % int(result["local"])
        return
    unsaved = false
    if int(result["project"]) == OK:
        world_status.text = "SALVO no projeto e no dispositivo. world_edits.json será incluído na próxima versão."
    else:
        world_status.text = "SALVO neste dispositivo. Para incorporar em todas as versões, envie o arquivo world_edits.json salvo."

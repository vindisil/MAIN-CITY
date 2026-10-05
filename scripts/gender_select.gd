extends Control
## BR1 V0.5.19
## Seletor moderno com setas e painel translúcido.
## A cidade é pré-instanciada na tela de carregamento; depois da confirmação
## apenas aplicamos o gênero e anexamos a cena já pronta à árvore.

const GAME_STATE_SCRIPT = preload("res://scripts/game_state.gd")
const WORLD_PATH := "res://main.tscn"
const MALE_PATH := "res://assets/third_person_shooter/character.glb"
const FEMALE_PATH := "res://assets/third_person_shooter/character.glb"
const WEAPON_PATHS: Array[String] = [
    "res://assets/third_person_shooter/rifles/ak47.glb",
    "res://assets/third_person_shooter/pistol.glb",
    "res://assets/third_person_shooter/rifles/m4a1.glb",
    "res://assets/third_person_shooter/rifles/ar15.glb"
]

const GENDER_IDS: Array[String] = ["masculino", "feminino"]
const GENDER_TITLES: Array[String] = ["HOMEM", "MULHER"]
const GENDER_SYMBOLS: Array[String] = ["♂", "♀"]
const GENDER_SUBTITLES: Array[String] = [
    "Modelo Third Person Shooter",
    "Modelo Third Person Shooter"
]

var choosing: bool = false
var requested: Dictionary = {}
var pending_gender: String = ""
var selected_index: int = 0

var status_label: Label
var gender_title: Label
var gender_symbol: Label
var gender_subtitle: Label
var counter_label: Label
var left_button: Button
var right_button: Button
var confirm_button: Button
var interactive_buttons: Array[Button] = []


func _ensure_game_state() -> Node:
    var state: Node = get_tree().root.get_node_or_null("GameState")
    if state == null:
        state = GAME_STATE_SCRIPT.new()
        state.name = "GameState"
        get_tree().root.add_child(state)
        push_warning("GameState não foi inicializado pelo autoload; estado restaurado.")
    return state


func _selected_model_path() -> String:
    return FEMALE_PATH if pending_gender == "feminino" else MALE_PATH


func _needed_paths() -> Array[String]:
    var result: Array[String] = [WORLD_PATH]
    if not pending_gender.is_empty():
        result.append(_selected_model_path())
        result.append_array(WEAPON_PATHS)
    return result


func _request_path(path: String) -> bool:
    var state := _ensure_game_state()
    if state != null:
        var cache: Dictionary = state.get("startup_cache")
        if cache.get(path) is PackedScene:
            return true
    if bool(requested.get(path, false)):
        return true

    var err := ResourceLoader.load_threaded_request(
        path,
        "PackedScene",
        true,
        ResourceLoader.CACHE_MODE_REUSE
    )
    if err == OK or err == ERR_BUSY:
        requested[path] = true
        return true
    requested[path] = false
    return false


func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var state := _ensure_game_state()
    if state != null:
        state.set("selected_gender", "")

    _build_ui()
    _update_selector()

    # Fallback para executar gender_select.tscn isoladamente no editor.
    _request_path(WORLD_PATH)
    _request_path(MALE_PATH)
    _request_path(FEMALE_PATH)
    for weapon_path in WEAPON_PATHS:
        _request_path(weapon_path)

    if status_label != null:
        var prepared := state.get("prepared_world") as Node if state != null else null
        status_label.text = (
            "Cidade pronta • escolha e entre"
            if is_instance_valid(prepared)
            else "Preparando recursos em segundo plano..."
        )


func _process(_delta: float) -> void:
    if pending_gender.is_empty():
        return
    _try_enter_world()


func _unhandled_key_input(event: InputEvent) -> void:
    if choosing or not (event is InputEventKey):
        return
    var key := event as InputEventKey
    if not key.pressed or key.echo:
        return

    if key.keycode == KEY_LEFT or key.keycode == KEY_A:
        _cycle_gender(-1)
        get_viewport().set_input_as_handled()
    elif key.keycode == KEY_RIGHT or key.keycode == KEY_D:
        _cycle_gender(1)
        get_viewport().set_input_as_handled()
    elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE:
        _confirm_selection()
        get_viewport().set_input_as_handled()


func _all_ready() -> bool:
    var state := _ensure_game_state()
    var cache: Dictionary = state.get("startup_cache") if state != null else {}

    for path in _needed_paths():
        if cache.get(path) is PackedScene:
            continue
        if not _request_path(path):
            return false

        var status := ResourceLoader.load_threaded_get_status(path)
        if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            return false
        if status != ResourceLoader.THREAD_LOAD_LOADED:
            return false
    return true


func _try_enter_world() -> void:
    if not _all_ready():
        if status_label != null:
            status_label.text = "Preparando personagem..."
        return

    var state := _ensure_game_state()
    if state == null:
        choosing = false
        pending_gender = ""
        return

    var cache: Dictionary = state.get("startup_cache")
    for path in _needed_paths():
        if cache.get(path) is PackedScene:
            continue
        var resource := ResourceLoader.load_threaded_get(path)
        if resource is PackedScene:
            cache[path] = resource
        else:
            _load_failed(ERR_CANT_OPEN)
            return

    # Mantém somente o personagem escolhido referenciado na sessão.
    var unused_gender_path: String = MALE_PATH if pending_gender == "feminino" else FEMALE_PATH
    cache.erase(unused_gender_path)
    state.set("startup_cache", cache)
    state.set("selected_gender", pending_gender)

    # Caminho rápido: main.tscn já foi instanciada na tela de loading.
    var prepared := state.get("prepared_world") as Node
    if is_instance_valid(prepared):
        state.set("prepared_world", null)
        _activate_prepared_world(prepared)
        return

    # Fallback seguro para a execução isolada da cena no editor.
    var world := cache.get(WORLD_PATH) as PackedScene
    if world == null:
        _load_failed(ERR_CANT_OPEN)
        return

    var result := get_tree().change_scene_to_packed(world)
    if result != OK:
        _load_failed(result)


func _activate_prepared_world(world: Node) -> void:
    var tree := get_tree()
    var old_scene := tree.current_scene

    # selected_gender já foi gravado antes de inserir o mundo.
    # Assim o _ready do personagem cria diretamente homem ou mulher.
    tree.root.add_child(world)
    tree.current_scene = world

    if is_instance_valid(old_scene):
        old_scene.queue_free()


func _load_failed(code: int) -> void:
    push_error("Não foi possível carregar a cidade/personagem. Código: %s" % code)
    choosing = false
    pending_gender = ""

    var state := _ensure_game_state()
    if state != null:
        state.set("selected_gender", "")

    requested.clear()
    for button in interactive_buttons:
        if is_instance_valid(button):
            button.disabled = false

    if status_label != null:
        status_label.text = "Falha ao carregar. Tente novamente."


func _build_ui() -> void:
    var backdrop := ColorRect.new()
    backdrop.name = "FundoTransparente"
    backdrop.color = Color(0.012, 0.020, 0.034, 0.22)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(backdrop)

    var center := CenterContainer.new()
    center.name = "Centralizador"
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(center)

    var panel := PanelContainer.new()
    panel.name = "PainelGeneroModerno"
    var viewport_size := get_viewport_rect().size
    panel.custom_minimum_size = Vector2(minf(660.0, maxf(315.0, viewport_size.x - 30.0)), 380.0)
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.025, 0.040, 0.065, 0.50)
    panel_style.border_color = Color(0.66, 0.84, 1.0, 0.32)
    panel_style.set_border_width_all(1)
    panel_style.set_corner_radius_all(26)
    panel_style.content_margin_left = 28
    panel_style.content_margin_right = 28
    panel_style.content_margin_top = 22
    panel_style.content_margin_bottom = 22
    panel.add_theme_stylebox_override("panel", panel_style)
    center.add_child(panel)

    var column := VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 12)
    panel.add_child(column)

    var accent := ColorRect.new()
    accent.custom_minimum_size = Vector2(86, 3)
    accent.color = Color(0.68, 0.86, 1.0, 0.88)
    column.add_child(accent)

    var eyebrow := Label.new()
    eyebrow.text = "PERSONAGEM"
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    eyebrow.add_theme_font_size_override("font_size", 12)
    eyebrow.add_theme_color_override("font_color", Color(0.64, 0.80, 0.98, 0.92))
    column.add_child(eyebrow)

    var heading := Label.new()
    heading.text = "ESCOLHA SEU PERSONAGEM"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 28)
    heading.add_theme_color_override("font_color", Color(0.97, 0.985, 1.0))
    column.add_child(heading)

    counter_label = Label.new()
    counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    counter_label.add_theme_font_size_override("font_size", 11)
    counter_label.add_theme_color_override("font_color", Color(0.60, 0.67, 0.76, 0.92))
    column.add_child(counter_label)

    var frame := PanelContainer.new()
    frame.custom_minimum_size = Vector2(0, 176)
    var frame_style := StyleBoxFlat.new()
    frame_style.bg_color = Color(0.04, 0.07, 0.12, 0.34)
    frame_style.border_color = Color(0.54, 0.75, 0.97, 0.18)
    frame_style.set_border_width_all(1)
    frame_style.set_corner_radius_all(20)
    frame_style.content_margin_left = 14
    frame_style.content_margin_right = 14
    frame_style.content_margin_top = 14
    frame_style.content_margin_bottom = 14
    frame.add_theme_stylebox_override("panel", frame_style)
    column.add_child(frame)

    var selector := HBoxContainer.new()
    selector.name = "SeletorComSetas"
    selector.alignment = BoxContainer.ALIGNMENT_CENTER
    selector.add_theme_constant_override("separation", 18)
    selector.custom_minimum_size.y = 146
    frame.add_child(selector)

    left_button = _make_arrow_button("‹")
    left_button.tooltip_text = "Personagem anterior"
    left_button.pressed.connect(_cycle_gender.bind(-1))
    selector.add_child(left_button)
    interactive_buttons.append(left_button)

    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(300, 136)
    var card_style := StyleBoxFlat.new()
    card_style.bg_color = Color(0.08, 0.12, 0.18, 0.44)
    card_style.border_color = Color(0.55, 0.75, 0.95, 0.24)
    card_style.set_border_width_all(1)
    card_style.set_corner_radius_all(18)
    card_style.content_margin_left = 18
    card_style.content_margin_right = 18
    card_style.content_margin_top = 10
    card_style.content_margin_bottom = 10
    card.add_theme_stylebox_override("panel", card_style)
    selector.add_child(card)

    var card_column := VBoxContainer.new()
    card_column.alignment = BoxContainer.ALIGNMENT_CENTER
    card_column.add_theme_constant_override("separation", 2)
    card.add_child(card_column)

    gender_symbol = Label.new()
    gender_symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    gender_symbol.add_theme_font_size_override("font_size", 44)
    card_column.add_child(gender_symbol)

    gender_title = Label.new()
    gender_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    gender_title.add_theme_font_size_override("font_size", 24)
    gender_title.add_theme_color_override("font_color", Color.WHITE)
    card_column.add_child(gender_title)

    gender_subtitle = Label.new()
    gender_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    gender_subtitle.add_theme_font_size_override("font_size", 12)
    gender_subtitle.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86))
    card_column.add_child(gender_subtitle)

    right_button = _make_arrow_button("›")
    right_button.tooltip_text = "Próximo personagem"
    right_button.pressed.connect(_cycle_gender.bind(1))
    selector.add_child(right_button)
    interactive_buttons.append(right_button)

    confirm_button = Button.new()
    confirm_button.name = "EntrarNaCidade"
    confirm_button.text = "ENTRAR NA CIDADE"
    confirm_button.custom_minimum_size = Vector2(310, 50)
    confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    confirm_button.add_theme_font_size_override("font_size", 16)
    confirm_button.add_theme_color_override("font_color", Color.WHITE)

    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.08, 0.38, 0.72, 0.90)
    normal.border_color = Color(0.54, 0.82, 1.0, 0.65)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(15)
    normal.content_margin_top = 10
    normal.content_margin_bottom = 10
    confirm_button.add_theme_stylebox_override("normal", normal)

    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.12, 0.48, 0.88, 0.96)
    hover.border_color = Color(0.76, 0.92, 1.0, 0.92)
    confirm_button.add_theme_stylebox_override("hover", hover)

    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.055, 0.30, 0.60, 0.98)
    confirm_button.add_theme_stylebox_override("pressed", pressed)

    confirm_button.pressed.connect(_confirm_selection)
    column.add_child(confirm_button)
    interactive_buttons.append(confirm_button)

    var controls_hint := Label.new()
    controls_hint.text = "Use as setas ou A / D para escolher"
    controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    controls_hint.add_theme_font_size_override("font_size", 11)
    controls_hint.add_theme_color_override("font_color", Color(0.60, 0.67, 0.74, 0.78))
    column.add_child(controls_hint)

    status_label = Label.new()
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 11)
    status_label.add_theme_color_override("font_color", Color(0.51, 0.76, 0.92))
    column.add_child(status_label)

func _make_arrow_button(symbol: String) -> Button:
    var button := Button.new()
    button.text = symbol
    button.custom_minimum_size = Vector2(62, 62)
    button.add_theme_font_size_override("font_size", 38)
    button.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))

    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.08, 0.13, 0.20, 0.32)
    normal.border_color = Color(0.56, 0.76, 0.96, 0.24)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(31)
    button.add_theme_stylebox_override("normal", normal)

    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.13, 0.28, 0.47, 0.72)
    hover.border_color = Color(0.70, 0.90, 1.0, 0.76)
    button.add_theme_stylebox_override("hover", hover)

    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.08, 0.22, 0.39, 0.90)
    pressed.border_color = Color(0.62, 0.83, 1.0, 0.82)
    button.add_theme_stylebox_override("pressed", pressed)
    return button

func _cycle_gender(direction: int) -> void:
    if choosing:
        return
    selected_index = wrapi(selected_index + direction, 0, GENDER_IDS.size())
    _update_selector()


func _update_selector() -> void:
    if gender_title == null:
        return

    gender_title.text = GENDER_TITLES[selected_index]
    gender_symbol.text = GENDER_SYMBOLS[selected_index]
    gender_subtitle.text = GENDER_SUBTITLES[selected_index]
    counter_label.text = "%02d  /  %02d" % [selected_index + 1, GENDER_IDS.size()]

    var accent := (
        Color(0.45, 0.76, 1.0)
        if GENDER_IDS[selected_index] == "masculino"
        else Color(0.91, 0.57, 0.83)
    )
    gender_symbol.add_theme_color_override("font_color", accent)


func _confirm_selection() -> void:
    if choosing:
        return
    _select_gender(GENDER_IDS[selected_index])


func _select_gender(gender: String) -> void:
    if choosing or gender not in GENDER_IDS:
        return

    var state := _ensure_game_state()
    if state == null:
        push_error("Estado do jogo ausente: seleção não concluída.")
        return

    choosing = true
    pending_gender = gender
    state.set("selected_gender", gender)

    _request_path(_selected_model_path())
    for weapon_path in WEAPON_PATHS:
        _request_path(weapon_path)

    for button in interactive_buttons:
        if is_instance_valid(button):
            button.disabled = true

    if status_label != null:
        status_label.text = "Entrando..."

    _try_enter_world()

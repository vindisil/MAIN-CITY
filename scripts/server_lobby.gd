extends Control
## BR1 V0.5.23 - lobby sem véu escuro sobre a arte de fundo.

const LOADING_SCENE: String = "res://scenes/loading_screen.tscn"
const MENU_SCENE: String = "res://scenes/start_menu.tscn"
const GAME_STATE_SCRIPT = preload("res://scripts/game_state.gd")
const HERO_BG_PATH := "res://assets/ui_backgrounds/lobby_bg.jpg"

var enter_button: Button

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _build_lobby()

func _ensure_game_state() -> Node:
    var session: Node = get_tree().root.get_node_or_null("GameState")
    if session == null:
        session = GAME_STATE_SCRIPT.new()
        session.name = "GameState"
        get_tree().root.add_child(session)
    return session

func _panel_style(fill_color: Color, border_color: Color, border_width: int = 1, radius: int = 22) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill_color
    style.border_color = border_color
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 18
    style.content_margin_right = 18
    style.content_margin_top = 14
    style.content_margin_bottom = 14
    return style

func _button_style(fill_color: Color, edge_color: Color, radius: int = 14) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill_color
    style.border_color = edge_color
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    return style

func _style_button(control_button: Button, active: bool = true) -> void:
    control_button.focus_mode = Control.FOCUS_ALL if active else Control.FOCUS_NONE
    control_button.add_theme_font_size_override("font_size", 15)
    control_button.add_theme_color_override("font_color", Color(1, 1, 1) if active else Color(0.67, 0.73, 0.84))
    control_button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
    control_button.add_theme_stylebox_override("normal", _button_style(Color(0.07, 0.32, 0.68, 0.94) if active else Color(0.15, 0.19, 0.28, 0.80), Color(0.54, 0.80, 1.0, 0.86) if active else Color(0.35, 0.40, 0.49, 0.52)))
    control_button.add_theme_stylebox_override("hover", _button_style(Color(0.14, 0.43, 0.85, 0.98), Color(0.78, 0.90, 1.0, 0.95)))
    control_button.add_theme_stylebox_override("pressed", _button_style(Color(0.04, 0.22, 0.49, 0.98), Color(0.58, 0.76, 0.96, 0.94)))
    control_button.add_theme_stylebox_override("disabled", _button_style(Color(0.16, 0.18, 0.25, 0.72), Color(0.34, 0.37, 0.45, 0.42)))
    control_button.custom_minimum_size = Vector2(0, 46)

func _label(text_value: String, font_size: int, font_color: Color) -> Label:
    var element := Label.new()
    element.text = text_value
    element.add_theme_font_size_override("font_size", font_size)
    element.add_theme_color_override("font_color", font_color)
    element.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    element.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return element

func _build_lobby() -> void:
    var background := TextureRect.new()
    background.name = "FundoLobby"
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if ResourceLoader.exists(HERO_BG_PATH):
        background.texture = load(HERO_BG_PATH)
    add_child(background)

    var margins := MarginContainer.new()
    margins.name = "MargensSeguras"
    add_child(margins)
    margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margins.add_theme_constant_override("margin_left", 20)
    margins.add_theme_constant_override("margin_right", 20)
    margins.add_theme_constant_override("margin_top", 20)
    margins.add_theme_constant_override("margin_bottom", 20)

    var root := VBoxContainer.new()
    root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_theme_constant_override("separation", 14)
    margins.add_child(root)

    var top_bar := HBoxContainer.new()
    top_bar.add_theme_constant_override("separation", 10)
    root.add_child(top_bar)

    var back := Button.new()
    back.name = "Voltar"
    back.text = "← VOLTAR"
    back.custom_minimum_size = Vector2(150, 42)
    _style_button(back)
    back.pressed.connect(_back_to_menu)
    top_bar.add_child(back)

    var title_spacer := Control.new()
    title_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_bar.add_child(title_spacer)

    var body_center := CenterContainer.new()
    body_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(body_center)

    var shell := PanelContainer.new()
    shell.custom_minimum_size = Vector2(minf(1080.0, maxf(340.0, get_viewport_rect().size.x - 60.0)), 0)
    shell.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.07, 0.13, 0.40), Color(0.58, 0.78, 1.0, 0.22), 1, 28))
    body_center.add_child(shell)

    var shell_margin := MarginContainer.new()
    shell_margin.add_theme_constant_override("margin_left", 24)
    shell_margin.add_theme_constant_override("margin_right", 24)
    shell_margin.add_theme_constant_override("margin_top", 22)
    shell_margin.add_theme_constant_override("margin_bottom", 20)
    shell.add_child(shell_margin)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 12)
    shell_margin.add_child(content)

    var title := _label("ESCOLHA SEU SERVIDOR", 31, Color(1, 1, 1))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.add_child(title)
    var subtitle := _label("Painel moderno • cartões lado a lado • fundo transparente", 13, Color(0.75, 0.84, 0.96))
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.add_child(subtitle)

    var grid := GridContainer.new()
    grid.name = "GridServidores"
    var width := get_viewport_rect().size.x
    grid.columns = 1 if width < 760.0 else (2 if width < 1120.0 else 3)
    grid.add_theme_constant_override("h_separation", 12)
    grid.add_theme_constant_override("v_separation", 12)
    content.add_child(grid)

    _server_card(grid, "BR1", "Exploração livre, veículos, missões e evolução do personagem.", true)
    _server_card(grid, "BR2", "Novas experiências estão sendo preparadas.", false)
    _server_card(grid, "BR3", "Mais novidades em breve.", false)

    var note := _label("BR1: protótipo local • 0/500 é ilustrativo; ainda não há servidor multiplayer conectado.", 12, Color(0.73, 0.80, 0.91))
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.add_child(note)

func _server_card(parent_box: GridContainer, server_id: String, description: String, active: bool) -> void:
    var panel := PanelContainer.new()
    panel.name = "Servidor" + server_id
    panel.custom_minimum_size = Vector2(260, 250)
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_stylebox_override("panel", _panel_style(
        Color(0.05, 0.08, 0.14, 0.56),
        Color(0.35, 0.58, 0.96, 0.78) if active else Color(0.55, 0.23, 0.30, 0.58),
        2 if active else 1,
        22
    ))
    parent_box.add_child(panel)

    var card := VBoxContainer.new()
    card.size_flags_vertical = Control.SIZE_EXPAND_FILL
    card.add_theme_constant_override("separation", 10)
    panel.add_child(card)

    var status := Label.new()
    status.text = "● DISPONÍVEL" if active else "● EM DESENVOLVIMENTO"
    status.add_theme_font_size_override("font_size", 12)
    status.add_theme_color_override("font_color", Color(0.66, 0.92, 1.0) if active else Color(1.0, 0.72, 0.78))
    card.add_child(status)

    var heading := _label(server_id, 28, Color(0.96, 0.98, 1.0))
    card.add_child(heading)

    var desc := _label(description, 14, Color(0.87, 0.91, 0.96))
    desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    card.add_child(desc)

    var stats_panel := PanelContainer.new()
    stats_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.11, 0.18, 0.52), Color(0.55, 0.65, 0.82, 0.18), 1, 16))
    card.add_child(stats_panel)

    var stats_label := _label("0/500 jogadores" if active else "Servidor fechado por enquanto", 13, Color(0.67, 0.81, 1.0) if active else Color(0.65, 0.68, 0.76))
    stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stats_panel.add_child(stats_label)

    var action := Button.new()
    action.name = ("Iniciar" if active else "Indisponivel") + server_id
    action.text = "ENTRAR" if active else "EM BREVE"
    action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _style_button(action, active)
    action.disabled = not active
    if active:
        enter_button = action
        action.pressed.connect(_enter_br1)
    card.add_child(action)

func _enter_br1() -> void:
    if enter_button == null or enter_button.disabled:
        return
    enter_button.disabled = true
    var session: Node = _ensure_game_state()
    session.set("selected_server", "BR1")
    var error_code: Error = get_tree().change_scene_to_file(LOADING_SCENE)
    if error_code != OK:
        push_error("Falha ao carregar a tela inicial do BR1 (%s)." % error_code)
        enter_button.disabled = false

func _back_to_menu() -> void:
    get_tree().change_scene_to_file(MENU_SCENE)

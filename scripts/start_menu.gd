extends Control
## BR1 V0.5.23 - tela inicial sem véu escuro sobre a arte de fundo.

const GAME_STATE_SCRIPT = preload("res://scripts/game_state.gd")
const LOBBY_SCENE := "res://scenes/server_lobby.tscn"
const DISCORD_URL := "https://discord.gg/4Qg2gH6y6x"
const HERO_BG_PATH := "res://assets/ui_backgrounds/lobby_bg.jpg"

var servers_button: Button

func _ensure_game_state() -> Node:
    var state: Node = get_tree().root.get_node_or_null("GameState")
    if state == null:
        state = GAME_STATE_SCRIPT.new()
        state.name = "GameState"
        get_tree().root.add_child(state)
        push_warning("GameState nao foi inicializado pelo autoload; estado da sessao restaurado.")
    return state

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var state: Node = _ensure_game_state()
    state.set("selected_gender", "")
    state.set("startup_cache", {})
    state.set("selected_server", "")
    if state.has_method("reset_payday"):
        state.call("reset_payday")
    _build_menu()

func _button_style(fill: Color, border: Color, radius: int = 17) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 18
    style.content_margin_right = 18
    style.content_margin_top = 11
    style.content_margin_bottom = 11
    return style

func _build_menu() -> void:
    var compact: bool = get_viewport_rect().size.x < 760.0 or get_viewport_rect().size.y < 560.0

    var background := TextureRect.new()
    background.name = "FundoInicio"
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    if ResourceLoader.exists(HERO_BG_PATH):
        background.texture = load(HERO_BG_PATH)
    add_child(background)

    var top_line := ColorRect.new()
    top_line.color = Color(0.62, 0.84, 1.0, 0.75)
    top_line.anchor_right = 1.0
    top_line.anchor_bottom = 0.0
    top_line.offset_bottom = 2.0
    top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(top_line)

    var margins := MarginContainer.new()
    margins.name = "MargensIniciais"
    margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margins.add_theme_constant_override("margin_left", 28 if compact else 54)
    margins.add_theme_constant_override("margin_right", 28 if compact else 54)
    margins.add_theme_constant_override("margin_top", 24)
    margins.add_theme_constant_override("margin_bottom", 24)
    add_child(margins)

    var layout := VBoxContainer.new()
    layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
    layout.add_theme_constant_override("separation", 14)
    margins.add_child(layout)

    var hero_spacer := Control.new()
    hero_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    layout.add_child(hero_spacer)

    var badge := Label.new()
    badge.text = "MAIN CITY • ONLINE EM DESENVOLVIMENTO"
    badge.add_theme_font_size_override("font_size", 12)
    badge.add_theme_color_override("font_color", Color(0.73, 0.86, 1.0, 0.94))
    layout.add_child(badge)

    var title := Label.new()
    title.text = "ENTRE NA CIDADE"
    title.add_theme_font_size_override("font_size", 34 if compact else 42)
    title.add_theme_color_override("font_color", Color(1,1,1,1))
    layout.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Abra o lobby, escolha o servidor e continue seu progresso com um visual mais moderno."
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    subtitle.custom_minimum_size.x = 460 if not compact else 0
    subtitle.add_theme_font_size_override("font_size", 15)
    subtitle.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 0.92))
    layout.add_child(subtitle)

    var actions_panel := PanelContainer.new()
    actions_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    actions_panel.custom_minimum_size = Vector2(0, 112 if compact else 102)
    actions_panel.add_theme_stylebox_override("panel", _button_style(Color(0.04, 0.07, 0.12, 0.52), Color(0.57, 0.77, 1.0, 0.22), 24))
    layout.add_child(actions_panel)

    var action_margin := MarginContainer.new()
    action_margin.add_theme_constant_override("margin_left", 16)
    action_margin.add_theme_constant_override("margin_right", 16)
    action_margin.add_theme_constant_override("margin_top", 16)
    action_margin.add_theme_constant_override("margin_bottom", 16)
    actions_panel.add_child(action_margin)

    var actions: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
    actions.add_theme_constant_override("separation", 12)
    action_margin.add_child(actions)

    servers_button = Button.new()
    servers_button.name = "AbrirServidores"
    servers_button.text = "◈  SERVIDORES"
    servers_button.custom_minimum_size = Vector2(240, 54)
    servers_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    servers_button.add_theme_font_size_override("font_size", 18)
    servers_button.add_theme_color_override("font_color", Color.WHITE)
    servers_button.add_theme_stylebox_override("normal", _button_style(Color(0.06, 0.30, 0.68, 0.92), Color(0.55, 0.81, 1.0, 0.82), 16))
    servers_button.add_theme_stylebox_override("hover", _button_style(Color(0.12, 0.42, 0.86, 0.98), Color(0.77, 0.91, 1.0, 0.95), 16))
    servers_button.add_theme_stylebox_override("pressed", _button_style(Color(0.04, 0.22, 0.54, 0.98), Color(0.54, 0.75, 1.0, 0.95), 16))
    servers_button.pressed.connect(_open_lobby)
    actions.add_child(servers_button)

    var discord_button := Button.new()
    discord_button.name = "AbrirDiscord"
    discord_button.text = "💬  DISCORD"
    discord_button.tooltip_text = "Abrir a comunidade no Discord"
    discord_button.custom_minimum_size = Vector2(220, 54)
    discord_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    discord_button.add_theme_font_size_override("font_size", 18)
    discord_button.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
    discord_button.add_theme_stylebox_override("normal", _button_style(Color(0.18, 0.22, 0.42, 0.86), Color(0.71, 0.77, 1.0, 0.72), 16))
    discord_button.add_theme_stylebox_override("hover", _button_style(Color(0.28, 0.34, 0.66, 0.95), Color(0.83, 0.87, 1.0, 0.92), 16))
    discord_button.add_theme_stylebox_override("pressed", _button_style(Color(0.15, 0.19, 0.39, 0.98), Color(0.68, 0.76, 1.0, 0.90), 16))
    discord_button.pressed.connect(_on_discord_pressed)
    actions.add_child(discord_button)

    var footer := Label.new()
    footer.text = "Toque ou clique para continuar • visual moderno com fundo artístico"
    footer.add_theme_font_size_override("font_size", 11)
    footer.add_theme_color_override("font_color", Color(0.77, 0.83, 0.90, 0.70))
    layout.add_child(footer)

func _on_discord_pressed() -> void:
    var result: Error = OS.shell_open(DISCORD_URL)
    if result != OK:
        push_warning("Nao foi possivel abrir o convite Discord (erro %s)." % result)

func _open_lobby() -> void:
    if servers_button != null:
        servers_button.disabled = true
    var error_code: Error = get_tree().change_scene_to_file(LOBBY_SCENE)
    if error_code != OK:
        push_error("Falha ao abrir o lobby (%s)." % error_code)
        if servers_button != null:
            servers_button.disabled = false

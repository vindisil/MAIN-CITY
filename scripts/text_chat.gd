extends PanelContainer
## BR1 v0.5.25 - chat alinhado ate antes da loja; seta junto da carteira.
## Desktop: T ou clique no campo. Enter envia. Mobile: toque direto no campo.

signal message_sent(text: String)
signal command_entered(command: String, args: PackedStringArray)

const MAX_MESSAGES: int = 12
const TEXT := Color("e9f3ff")
const MUTED := Color("91a9c2")
const ACCENT := Color("55e4bf")

var player: Node = null
var log: RichTextLabel
var input: LineEdit
var collapse_button: Button
var body: VBoxContainer
var hint: Label
var messages: Array[String] = []
var typing: bool = false
var collapsed: bool = false

func setup(owner_player: Node) -> void:
    player = owner_player
    name = "ChatDeTexto"
    # Ocupa o espaco util entre o minimapa (esquerda) e HUD de armas/dinheiro (direita).
    anchor_left = 0.0
    anchor_right = 1.0
    anchor_top = 0.0
    anchor_bottom = 0.0
    offset_left = 250.0
    # Termina antes do botao da loja; a seta de recolher fica no limite direito do chat.
    offset_right = -446.0
    offset_top = 14.0
    offset_bottom = 218.0
    mouse_filter = Control.MOUSE_FILTER_PASS
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.018, 0.045, 0.075, 0.30)
    style.border_color = Color(0.28, 0.62, 0.80, 0.34)
    style.set_border_width_all(1)
    style.set_corner_radius_all(10)
    style.content_margin_left = 9
    style.content_margin_right = 9
    style.content_margin_top = 6
    style.content_margin_bottom = 7
    add_theme_stylebox_override("panel", style)
    _build()
    _set_typing_state(false)
    add_message("SISTEMA", "Chat pronto.")

func _build() -> void:
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 4)
    add_child(column)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 5)
    column.add_child(header)
    var title := Label.new()
    title.text = "CHAT"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 10)
    title.add_theme_color_override("font_color", ACCENT)
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    header.add_child(title)

    collapse_button = preload("res://scripts/mobile_action_button.gd").new()
    collapse_button.name = "RecolherChat"
    collapse_button.call("configure", "CHAT_FECHAR", "Recolher chat")
    collapse_button.custom_minimum_size = Vector2(28, 28)
    collapse_button.pressed.connect(toggle_collapsed)
    header.add_child(collapse_button)

    body = VBoxContainer.new()
    body.add_theme_constant_override("separation", 3)
    column.add_child(body)

    log = RichTextLabel.new()
    log.bbcode_enabled = false
    log.fit_content = false
    log.scroll_active = false
    log.custom_minimum_size = Vector2(0, 104)
    log.size_flags_vertical = Control.SIZE_EXPAND_FILL
    log.mouse_filter = Control.MOUSE_FILTER_IGNORE
    log.add_theme_font_size_override("normal_font_size", 12)
    log.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.96))
    log.add_theme_constant_override("outline_size", 2)
    log.add_theme_color_override("default_color", TEXT)
    body.add_child(log)

    input = LineEdit.new()
    input.placeholder_text = "T ou clique aqui..."
    input.max_length = 160
    input.custom_minimum_size.y = 32
    input.visible = true
    input.add_theme_font_size_override("font_size", 12)
    input.add_theme_color_override("font_color", Color(0.96, 0.985, 1.0, 1.0))
    input.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.98))
    input.add_theme_constant_override("outline_size", 1)
    input.text_submitted.connect(_submit)
    input.focus_entered.connect(_focus_entered)
    input.focus_exited.connect(_focus_lost)
    body.add_child(input)

    hint = Label.new()
    hint.text = "T ou clique no campo · ENTER envia"
    hint.add_theme_font_size_override("font_size", 10)
    hint.add_theme_color_override("font_outline_color", Color(0,0,0,0.95))
    hint.add_theme_constant_override("outline_size", 1)
    hint.add_theme_color_override("font_color", MUTED)
    hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    body.add_child(hint)

func handle_key(event: InputEventKey) -> bool:
    if not event.pressed or event.echo:
        return false
    if typing:
        if event.keycode == KEY_ESCAPE:
            close_input()
            return true
        # As demais teclas precisam chegar ao LineEdit para virarem texto.
        # Os sistemas de gameplay consultam br1_chat_typing e ficam bloqueados.
        return false
    if event.keycode == KEY_T and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
        open_input()
        return true
    return false

func is_typing() -> bool:
    return typing

func is_collapsed() -> bool:
    return collapsed

func toggle_collapsed() -> void:
    set_collapsed(not collapsed)

func set_collapsed(value: bool) -> void:
    collapsed = value
    if body != null:
        body.visible = not collapsed
    if collapse_button != null:
        collapse_button.call("configure", "CHAT_ABRIR" if collapsed else "CHAT_FECHAR", "Mostrar chat" if collapsed else "Recolher chat")
    if collapsed:
        _set_typing_state(false)
        if input != null:
            input.release_focus()
            input.clear()
        offset_bottom = 42.0
    else:
        offset_bottom = 218.0

func open_input() -> void:
    visible = true
    if collapsed:
        set_collapsed(false)
    _set_typing_state(true)
    input.visible = true
    input.editable = true
    input.grab_focus()

func close_input() -> void:
    _set_typing_state(false)
    input.release_focus()
    input.visible = true
    input.clear()

func dismiss_if_outside(point: Vector2) -> void:
    if not visible or get_global_rect().has_point(point):
        return
    set_collapsed(true)

func hide_chat() -> void:
    # Mantém o cabeçalho/setinha visível para o usuário poder abrir novamente.
    visible = true
    set_collapsed(true)

func show_chat() -> void:
    visible = true

func _focus_entered() -> void:
    if collapsed:
        set_collapsed(false)
    _set_typing_state(true)

func _set_typing_state(value: bool) -> void:
    typing = value
    if is_inside_tree():
        get_tree().set_meta("br1_chat_typing", value)

func _focus_lost() -> void:
    if typing and not input.has_focus():
        _set_typing_state(false)
        input.visible = true

func _submit(raw_text: String) -> void:
    var clean := raw_text.strip_edges()
    if clean.is_empty():
        close_input()
        return
    clean = clean.substr(0, mini(clean.length(), 160))
    if clean.begins_with("/"):
        _submit_command(clean)
    else:
        add_message("VOCÊ", clean)
        message_sent.emit(clean)
    input.clear()
    call_deferred("_refocus")

func _submit_command(raw_command: String) -> void:
    var command_line := raw_command.substr(1).strip_edges()
    if command_line.is_empty():
        add_message("SISTEMA", "Comando vazio.")
        return
    var parts := command_line.split(" ", false)
    var command := String(parts[0]).to_lower()
    var args := PackedStringArray()
    for i in range(1, parts.size()):
        args.append(String(parts[i]))
    command_entered.emit(command, args)

func _refocus() -> void:
    if typing and is_instance_valid(input):
        input.grab_focus()

func receive_message(author: String, text_value: String) -> void:
    add_message(author, text_value)

func add_message(author: String, text_value: String) -> void:
    visible = true
    var safe_author := author.strip_edges().substr(0, 24)
    var safe_text := text_value.strip_edges().replace("\n", " ").replace("\r", " ").substr(0, 180)
    if safe_text.is_empty():
        return
    messages.append("%s: %s" % [safe_author, safe_text])
    while messages.size() > MAX_MESSAGES:
        messages.pop_front()
    if is_instance_valid(log):
        log.clear()
        for line in messages:
            log.push_bold()
            log.add_text(line)
            log.pop()
            log.add_text("\n")

func _exit_tree() -> void:
    if get_tree() != null:
        get_tree().set_meta("br1_chat_typing", false)

extends Control
## V0.5.19: prepara recursos e pré-instancia a cidade antes da escolha de gênero.
## A barra mede ResourceLoader; nao representa criacao do mundo/compilacao de shaders.

const GAME_STATE_SCRIPT = preload("res://scripts/game_state.gd")

# O autoload deveria existir normalmente. Se o projeto estiver sendo executado
# a partir de uma cena importada sem o autoload, recrie o mesmo estado na raiz.
# Uma unica instancia e compartilhada pelo menu, carregamento e selecao.
func _ensure_game_state() -> Node:
    var state: Node = get_tree().root.get_node_or_null("GameState")
    if state == null:
        state = GAME_STATE_SCRIPT.new()
        state.name = "GameState"
        get_tree().root.add_child(state)
        push_warning("GameState nao foi inicializado pelo autoload; estado da sessao restaurado.")
    return state

const WORLD_PATH := "res://main.tscn"
const GENDER_PATH := "res://scenes/gender_select.tscn"
const HERO_BG_PATH := "res://assets/ui_backgrounds/loading_bg.jpg"
const CHARACTER_PATH := "res://assets/third_person_shooter/character.glb"
const RIFLE_PATH := "res://assets/third_person_shooter/rifles/ak47.glb"
const PISTOL_PATH := "res://assets/third_person_shooter/pistol.glb"
const STARTUP_SCENES: Array[String] = [
    WORLD_PATH,
    CHARACTER_PATH,
    RIFLE_PATH,
    PISTOL_PATH,
    "res://assets/third_person_shooter/rifles/m4a1.glb",
    "res://assets/third_person_shooter/rifles/ar15.glb",
    "res://assets/third_person_shooter/rifles/m16.glb",
    # Setores imediatamente ao redor do spawn (-8, 25).
    "res://scenes/city_chunks/cell_-1_0.tscn",
    "res://scenes/city_chunks/cell_0_0.tscn",
    "res://scenes/city_chunks/cell_-1_-1.tscn",
    "res://scenes/city_chunks/cell_0_-1.tscn"
]

var requested: Dictionary = {}
var cache: Dictionary = {}
var loading_started: bool = false
var transitioning: bool = false
var failed: bool = false
var started_at_msec: int = 0
var loading_bar: ProgressBar
var progress_text: Label
var status_text: Label
var back_button: Button

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _build_loading_ui()
    # O fundo recebe um frame na tela antes de iniciar a leitura dos modelos 3D.
    call_deferred("_start_requests")

func _start_requests() -> void:
    if not is_inside_tree():
        return
    started_at_msec = Time.get_ticks_msec()
    loading_started = true
    for path in STARTUP_SCENES:
        var err := ResourceLoader.load_threaded_request(path, "PackedScene", true, ResourceLoader.CACHE_MODE_REUSE)
        if err == OK or err == ERR_BUSY:
            requested[path] = true
        else:
            _fail("Não foi possível iniciar o carregamento de: " + path.get_file())
            return

func _process(_delta: float) -> void:
    if not loading_started or transitioning or failed:
        return
    var progress_total: float = 0.0
    var all_ready: bool = true
    for path in STARTUP_SCENES:
        if not bool(requested.get(path, false)):
            return
        var portion: Array = []
        var load_status := ResourceLoader.load_threaded_get_status(path, portion)
        if load_status == ResourceLoader.THREAD_LOAD_FAILED or load_status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            _fail("Não foi possível carregar: " + path.get_file())
            return
        if load_status == ResourceLoader.THREAD_LOAD_LOADED:
            progress_total += 1.0
        else:
            all_ready = false
            if not portion.is_empty():
                progress_total += clampf(float(portion[0]), 0.0, 0.99)
    var percent: float = progress_total / float(STARTUP_SCENES.size()) * 100.0
    loading_bar.value = percent
    progress_text.text = "%d%%" % roundi(percent)
    if not all_ready:
        status_text.text = "Preparando cidade, personagem, armas e setor inicial..."
        return
    status_text.text = "Tudo preparado. Abrindo seleção do personagem..."
    # Uma curta permanencia garante que a tela de carregamento seja visivel.
    if Time.get_ticks_msec() - started_at_msec < 70:
        return
    transitioning = true
    call_deferred("_finish_loading")

func _finish_loading() -> void:
    if not is_inside_tree():
        return

    # Só fazemos load_threaded_get quando o status já está LOADED.
    for path in STARTUP_SCENES:
        var resource := ResourceLoader.load_threaded_get(path)
        if resource == null:
            _fail("Recurso indisponível: " + path.get_file())
            return
        cache[path] = resource

    var state: Node = _ensure_game_state()
    state.set("startup_cache", cache)

    # V0.5.19: a parte pesada de PackedScene.instantiate() acontece AQUI,
    # ainda na tela de carregamento. O Node permanece fora da árvore, então
    # _ready() do mundo/personagem só roda depois da escolha de gênero.
    status_text.text = "Preparando cidade para entrada rápida..."
    var world_scene := cache.get(WORLD_PATH) as PackedScene
    if world_scene == null:
        _fail("Cena principal indisponível.")
        return

    var previous_world := state.get("prepared_world") as Node
    if is_instance_valid(previous_world):
        previous_world.free()

    var prepared := world_scene.instantiate()
    if prepared == null:
        _fail("Não foi possível preparar a cidade.")
        return
    state.set("prepared_world", prepared)

    status_text.text = "Cidade pronta. Abrindo seleção do personagem..."
    var err := get_tree().change_scene_to_file(GENDER_PATH)
    if err != OK:
        prepared.free()
        state.set("prepared_world", null)
        _fail("Não foi possível abrir a seleção de personagem.")

func _fail(message: String) -> void:
    failed = true
    transitioning = false
    push_error(message)
    status_text.text = message
    progress_text.text = "ERRO"
    back_button.visible = true

func _build_loading_ui() -> void:
    var background := TextureRect.new()
    background.name = "FundoCarregamento"
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if ResourceLoader.exists(HERO_BG_PATH):
        background.texture = load(HERO_BG_PATH)
    add_child(background)

    var overlay := ColorRect.new()
    overlay.color = Color(0.012, 0.020, 0.04, 0.42)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(overlay)

    var footer := PanelContainer.new()
    footer.name = "PainelCarregamento"
    footer.anchor_left = 0.05
    footer.anchor_top = 0.73
    footer.anchor_right = 0.95
    footer.anchor_bottom = 0.965
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.02, 0.035, 0.06, 0.64)
    panel_style.border_color = Color(0.62, 0.82, 1.0, 0.26)
    panel_style.set_border_width_all(1)
    panel_style.set_corner_radius_all(24)
    panel_style.content_margin_left = 24
    panel_style.content_margin_right = 24
    panel_style.content_margin_top = 18
    panel_style.content_margin_bottom = 18
    footer.add_theme_stylebox_override("panel", panel_style)
    add_child(footer)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 9)
    footer.add_child(content)

    var heading := Label.new()
    heading.text = "CARREGANDO BR1"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 30)
    heading.add_theme_color_override("font_color", Color(1.0, 0.98, 0.96))
    content.add_child(heading)

    var sub := Label.new()
    sub.text = "Prepare-se para entrar na cidade"
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.add_theme_font_size_override("font_size", 13)
    sub.add_theme_color_override("font_color", Color(0.78, 0.86, 0.96))
    content.add_child(sub)

    var progress_shell := HBoxContainer.new()
    progress_shell.add_theme_constant_override("separation", 10)
    content.add_child(progress_shell)

    loading_bar = ProgressBar.new()
    loading_bar.name = "ProgressoReal"
    loading_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    loading_bar.custom_minimum_size = Vector2(0, 22)
    loading_bar.min_value = 0
    loading_bar.max_value = 100
    loading_bar.value = 0
    loading_bar.show_percentage = false
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0.08, 0.11, 0.17, 0.92)
    bg.set_corner_radius_all(8)
    loading_bar.add_theme_stylebox_override("background", bg)
    var fg := StyleBoxFlat.new()
    fg.bg_color = Color(0.14, 0.63, 0.98, 0.98)
    fg.set_corner_radius_all(8)
    loading_bar.add_theme_stylebox_override("fill", fg)
    progress_shell.add_child(loading_bar)

    progress_text = Label.new()
    progress_text.name = "Percentual"
    progress_text.text = "0%"
    progress_text.custom_minimum_size = Vector2(58, 0)
    progress_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    progress_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    progress_text.add_theme_font_size_override("font_size", 17)
    progress_text.add_theme_color_override("font_color", Color(1, 1, 1))
    progress_shell.add_child(progress_text)

    status_text = Label.new()
    status_text.name = "EtapaDoCarregamento"
    status_text.text = "Iniciando carregamento..."
    status_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    status_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_text.add_theme_font_size_override("font_size", 14)
    status_text.add_theme_color_override("font_color", Color(0.83, 0.86, 0.90))
    content.add_child(status_text)

    back_button = Button.new()
    back_button.name = "VoltarAoMenu"
    back_button.text = "VOLTAR AO MENU"
    back_button.custom_minimum_size = Vector2(260, 46)
    back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    back_button.visible = false
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.12, 0.17, 0.28, 0.92)
    normal.border_color = Color(0.64, 0.78, 0.96, 0.70)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(14)
    back_button.add_theme_stylebox_override("normal", normal)
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.18, 0.27, 0.44, 0.98)
    hover.border_color = Color(0.80, 0.90, 1.0, 0.92)
    back_button.add_theme_stylebox_override("hover", hover)
    back_button.pressed.connect(_return_to_menu)
    content.add_child(back_button)

func _return_to_menu() -> void:
    get_tree().change_scene_to_file("res://scenes/server_lobby.tscn")

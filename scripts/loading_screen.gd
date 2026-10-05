extends Control
## MAIN CITY / CITY 1
## Carregamento exclusivo da cidade nova. Nenhum chunk ou cena do mapa antigo
## participa mais do fluxo Menu -> Lobby -> Loading -> Gênero -> City 1.

const GAME_STATE_SCRIPT = preload("res://scripts/game_state.gd")
const WORLD_PATH := "res://main.tscn"
const CITY1_PATH := "res://assets/City1/City 1_MAIN_CITY_TEXTURED_MOBILE_GLB_FIX.glb"
const GENDER_PATH := "res://scenes/gender_select.tscn"
const LOBBY_PATH := "res://scenes/server_lobby.tscn"

const STARTUP_SCENES: Array[String] = [
	WORLD_PATH,
	CITY1_PATH,
	"res://assets/third_person_shooter/character.glb",
	"res://assets/third_person_shooter/rifles/ak47.glb",
	"res://assets/third_person_shooter/pistol.glb",
	"res://assets/third_person_shooter/rifles/m4a1.glb",
	"res://assets/third_person_shooter/rifles/ar15.glb",
	"res://assets/third_person_shooter/rifles/m16.glb"
]

var requested: Dictionary = {}
var cache: Dictionary = {}
var loading_started := false
var transitioning := false
var failed := false
var loading_bar: ProgressBar
var progress_text: Label
var status_text: Label
var back_button: Button

func _ensure_game_state() -> Node:
	var state := get_tree().root.get_node_or_null("GameState")
	if state == null:
		state = GAME_STATE_SCRIPT.new()
		state.name = "GameState"
		get_tree().root.add_child(state)
	return state

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_status_ui()
	call_deferred("_start_requests")

func _build_status_ui() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.32)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var footer := PanelContainer.new()
	footer.anchor_left = 0.08
	footer.anchor_right = 0.92
	footer.anchor_top = 0.76
	footer.anchor_bottom = 0.95
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.065, 0.78)
	style.border_color = Color(0.45, 0.78, 1.0, 0.30)
	style.set_border_width_all(1)
	style.set_corner_radius_all(20)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	footer.add_theme_stylebox_override("panel", style)
	add_child(footer)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	footer.add_child(column)

	var title := Label.new()
	title.text = "CARREGANDO MAIN CITY • CITY 1"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	column.add_child(title)

	status_text = Label.new()
	status_text.text = "Preparando a nova cidade..."
	status_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_text.add_theme_font_size_override("font_size", 13)
	column.add_child(status_text)

	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 10)
	column.add_child(progress_row)

	loading_bar = ProgressBar.new()
	loading_bar.min_value = 0
	loading_bar.max_value = 100
	loading_bar.show_percentage = false
	loading_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loading_bar.custom_minimum_size.y = 20
	progress_row.add_child(loading_bar)

	progress_text = Label.new()
	progress_text.text = "0%"
	progress_text.custom_minimum_size.x = 58
	progress_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_row.add_child(progress_text)

	back_button = Button.new()
	back_button.text = "VOLTAR AO LOBBY"
	back_button.visible = false
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(func(): get_tree().change_scene_to_file(LOBBY_PATH))
	column.add_child(back_button)

func _start_requests() -> void:
	if not is_inside_tree():
		return
	loading_started = true
	for path in STARTUP_SCENES:
		if not ResourceLoader.exists(path):
			_fail("Arquivo ausente: " + path.get_file())
			return
		var err := ResourceLoader.load_threaded_request(path, "PackedScene", true, ResourceLoader.CACHE_MODE_REUSE)
		if err == OK or err == ERR_BUSY:
			requested[path] = true
		else:
			_fail("Falha ao preparar: " + path.get_file())
			return

func _process(_delta: float) -> void:
	if not loading_started or transitioning or failed:
		return
	var total := 0.0
	var all_ready := true
	for path in STARTUP_SCENES:
		if not bool(requested.get(path, false)):
			all_ready = false
			continue
		var portion: Array = []
		var status := ResourceLoader.load_threaded_get_status(path, portion)
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_fail("Falha ao carregar: " + path.get_file())
			return
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			total += 1.0
		else:
			all_ready = false
			if not portion.is_empty():
				total += clampf(float(portion[0]), 0.0, 0.99)

	var percent := total / float(STARTUP_SCENES.size()) * 100.0
	loading_bar.value = percent
	progress_text.text = "%d%%" % roundi(percent)
	status_text.text = "Preparando City 1, personagem, armas e veículos..."
	if all_ready:
		transitioning = true
		call_deferred("_finish_loading")

func _finish_loading() -> void:
	for path in STARTUP_SCENES:
		var resource := ResourceLoader.load_threaded_get(path)
		if not (resource is PackedScene):
			_fail("Recurso inválido: " + path.get_file())
			return
		cache[path] = resource

	var state := _ensure_game_state()
	state.set("startup_cache", cache)

	var previous := state.get("prepared_world") as Node
	if is_instance_valid(previous):
		previous.free()

	status_text.text = "Instanciando exclusivamente a City 1..."
	var world_scene := cache.get(WORLD_PATH) as PackedScene
	var prepared := world_scene.instantiate() if world_scene != null else null
	if prepared == null:
		_fail("Não foi possível preparar a City 1.")
		return
	state.set("prepared_world", prepared)

	status_text.text = "City 1 pronta. Abrindo personagem..."
	var err := get_tree().change_scene_to_file(GENDER_PATH)
	if err != OK:
		prepared.free()
		state.set("prepared_world", null)
		_fail("Não foi possível abrir a seleção de personagem.")

func _fail(message: String) -> void:
	failed = true
	transitioning = false
	push_error(message)
	if is_instance_valid(status_text):
		status_text.text = message
	if is_instance_valid(progress_text):
		progress_text.text = "ERRO"
	if is_instance_valid(back_button):
		back_button.visible = true

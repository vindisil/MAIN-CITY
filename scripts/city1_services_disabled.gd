extends Node3D
## Main City - migração para City 1.
## Polícia / Exército / Hospital ficam preservados, porém inativos até os
## novos pontos das bases serem definidos neste mapa.
## O spawn NÃO é mais escolhido automaticamente: usa apenas o ponto salvo
## pelo comando /setaspawn. Sem ponto salvo, mantém a posição definida em main.tscn.

@export var police_enabled: bool = false
@export var army_enabled: bool = false
@export var hospital_enabled: bool = false

# v2 ignora o arquivo antigo que continha o spawn preso em X=0 / Z=8.
const SPAWN_CONFIG_PATH := "user://main_city_spawn_v2.cfg"
const SPAWN_CONFIG_SECTION := "city1"
const SPAWN_CONFIG_KEY := "position"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Aplica somente o spawn salvo manualmente na versão atual.
	# Sem spawn salvo, não altera a posição fixa de main.tscn.
	call_deferred("_apply_saved_spawn")

func _apply_saved_spawn() -> void:
	await get_tree().physics_frame
	var player := get_node_or_null("Player") as CharacterBody3D
	if player == null:
		return

	var saved_spawn := _load_saved_spawn()
	if saved_spawn == Vector3.INF:
		return

	player.velocity = Vector3.ZERO
	player.global_position = saved_spawn
	print("MAIN CITY / City 1: spawn fixado aplicado em ", saved_spawn)

func _load_saved_spawn() -> Vector3:
	var config := ConfigFile.new()
	if config.load(SPAWN_CONFIG_PATH) != OK:
		return Vector3.INF
	var saved: Variant = config.get_value(SPAWN_CONFIG_SECTION, SPAWN_CONFIG_KEY, null)
	if typeof(saved) != TYPE_VECTOR3:
		return Vector3.INF
	return saved

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return

	var player := get_node_or_null("Player")
	if player == null:
		return
	var menu = player.get("map_settings_menu")
	if menu == null or not is_instance_valid(menu):
		return

	if bool(menu.get("menu_open")):
		menu.call("set_menu", false)
	else:
		menu.call("open_page", 1)
	get_viewport().set_input_as_handled()

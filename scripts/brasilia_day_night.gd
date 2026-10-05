extends Node3D
## Cidade v0.0.31 — 24 horas do mundo em 2 horas reais; BR civil independente.
## O horario civil de Brasilia e UTC-3. A fonte e o relogio do dispositivo,
## mas NAO o fuso horario configurado pelo jogador. Nao requer acesso a rede.
## preview_hour = -1 simula o horario do MUNDO; o relogio BR nunca e alterado.

const BRASILIA_UTC_OFFSET_SECONDS: int = -3 * 60 * 60
# 1 dia completo de jogo a cada 2 horas reais (12x).
const CYCLE_DURATION_REAL_SECONDS: float = 2.0 * 60.0 * 60.0
const GAME_TIME_SCALE: float = 86400.0 / CYCLE_DURATION_REAL_SECONDS
# Em cada bloco de 2 horas do horario BR, o jogo inicia o periodo da manha.
const CYCLE_START_HOUR: float = 6.0
const LIGHT_INTERVAL_SECONDS: float = 2.0
const SKY_INTERVAL_SECONDS: float = 16.0

@export_range(-1.0, 23.99, 0.01) var preview_hour: float = -1.0

@onready var sunlight: DirectionalLight3D = get_parent().get_node("Sun") as DirectionalLight3D
@onready var world_environment: WorldEnvironment = get_parent().get_node("WorldEnvironment") as WorldEnvironment
@onready var player: CharacterBody3D = get_parent().get_node("Player") as CharacterBody3D

var sky_material: ProceduralSkyMaterial
var clock_label: Label
var light_elapsed: float = LIGHT_INTERVAL_SECONDS
var sky_elapsed: float = SKY_INTERVAL_SECONDS
var street_lamp_level: float = 0.0

func _ready() -> void:
	var env: Environment = world_environment.environment
	# main.tscn tem recursos de ceu/ambiente locais a esta cena; duplica-los
	# impede que alteracoes do clima modifiquem outras cenas que os compartilhem.
	env = env.duplicate(true) as Environment
	world_environment.environment = env
	var sky: Sky = env.sky
	sky_material = sky.sky_material as ProceduralSkyMaterial
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	clock_label = player.get("brasilia_clock") as Label
	_update_clock_and_lighting(true)

func _process(delta: float) -> void:
	light_elapsed += delta
	sky_elapsed += delta
	if light_elapsed < LIGHT_INTERVAL_SECONDS:
		return
	_update_clock_and_lighting(false)

func _brasilia_seconds() -> float:
	return Time.get_unix_time_from_system() + float(BRASILIA_UTC_OFFSET_SECONDS)

func _game_hour() -> float:
	if preview_hour >= 0.0:
		return preview_hour
	# Usa o relogio real como ancora: reiniciar o jogo nao reinicia o ciclo.
	# BR 00:00, 02:00, 04:00... -> 06:00 do jogo (manha).
	# Apos 30 min -> 12:00; 60 min -> 18:00; 90 min -> 00:00;
	# apos 120 min -> 06:00 novamente. O modulo garante repeticao exata.
	var elapsed_in_cycle: float = fposmod(_brasilia_seconds(), CYCLE_DURATION_REAL_SECONDS)
	return fposmod(CYCLE_START_HOUR + elapsed_in_cycle * GAME_TIME_SCALE / 3600.0, 24.0)

func _update_clock_and_lighting(force_sky: bool) -> void:
	var hour: float = _game_hour()
	# HUD mostra SEMPRE a hora civil real de Brasilia, sem aceleracao ou preview.
	var brasilia_now: float = fposmod(_brasilia_seconds(), 86400.0)
	if clock_label != null:
		var hour_number: int = int(floor(brasilia_now / 3600.0))
		var minute_number: int = int(floor(fposmod(brasilia_now / 60.0, 60.0)))
		clock_label.text = "BR %02d:%02d" % [hour_number, minute_number]
		clock_label.tooltip_text = "BR: horario real de Brasilia (UTC-3) | Jogo %02d:%02d | 24h do jogo = 2h reais" % [int(floor(hour)), int(floor(fposmod(hour * 60.0, 60.0)))]

	# O periodo noturno e um unico intervalo continuo: 18:45..05:00,
	# incluindo toda a madrugada, sem trocar de intensidade a meia-noite.
	var sunrise: float = smoothstep(4.4, 6.0, hour)
	var sunset: float = 1.0 - smoothstep(17.35, 18.75, hour)
	var daylight: float = sunrise * sunset
	street_lamp_level = 1.0 - daylight
	var lamp_system: Node = get_parent().get_node_or_null("StreetLamps")
	if lamp_system != null:
		lamp_system.call("set_night_level", street_lamp_level)
	var early_warmth: float = clampf(1.0 - absf(hour - 6.1) / 1.45, 0.0, 1.0)
	var late_warmth: float = clampf(1.0 - absf(hour - 18.05) / 1.5, 0.0, 1.0)
	var warmth: float = maxf(early_warmth, late_warmth)

	# Uma luz direcional e iluminacao ambiente: sem luzes por setor nem
	# recalculo de sombras a cada frame; preserva o carregamento progressivo.
	sunlight.light_energy = (0.25 + 0.42 * daylight) * daylight
	sunlight.light_color = Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.56, 0.36), warmth * 0.75)
	sunlight.rotation_degrees = Vector3(-lerpf(8.0, 66.0, maxf(0.0, sin((hour - 5.0) * PI / 13.75))), -115.0 + hour * 11.0, 0.0)
	var ui: CanvasLayer = player.get("modern_ui") as CanvasLayer
	var selected_quality: int = 0 if ui == null else int(ui.get("quality"))
	var effective_quality: int = (1 if OS.has_feature("mobile") else 2) if selected_quality == 0 else selected_quality
	sunlight.shadow_enabled = daylight > 0.18 and effective_quality > 1

	var env: Environment = world_environment.environment
	# Noite mais legivel sem adicionar luzes reais ou sombras extras.
	env.ambient_light_color = Color(0.43, 0.51, 0.67).lerp(Color(0.79, 0.83, 0.88), daylight)
	env.ambient_light_energy = lerpf(0.34, 0.38, daylight)
	env.fog_light_color = Color(0.075, 0.105, 0.17).lerp(Color(0.67, 0.77, 0.82), daylight)
	light_elapsed = 0.0

	# Alterar o ceu procedural e relativamente caro em GPUs de entrada;
	# atualiza-lo a cada 16 s (nao a cada frame) evita recompilacoes constantes.
	if force_sky or sky_elapsed >= SKY_INTERVAL_SECONDS:
		_update_sky(daylight, warmth)
		sky_elapsed = 0.0

func _update_sky(daylight: float, warmth: float) -> void:
	var night_top := Color(0.020, 0.035, 0.075)
	var day_top := Color(0.20, 0.42, 0.66)
	var night_horizon := Color(0.065, 0.095, 0.16)
	var day_horizon := Color(0.75, 0.82, 0.84)
	sky_material.sky_top_color = night_top.lerp(day_top, daylight)
	sky_material.sky_horizon_color = night_horizon.lerp(day_horizon, daylight).lerp(Color(0.80, 0.36, 0.21), warmth * 0.48)
	sky_material.ground_horizon_color = Color(0.070, 0.095, 0.145).lerp(Color(0.75, 0.82, 0.84), daylight)
	sky_material.ground_bottom_color = Color(0.025, 0.035, 0.055).lerp(Color(0.25, 0.28, 0.29), daylight)

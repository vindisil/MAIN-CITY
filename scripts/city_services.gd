extends Node3D

const BAIRROS = preload("res://scripts/neighborhoods.gd")
const WEAPONS = preload("res://scripts/tps_weapons.gd")
const DUSTER_POLICE_PATH := "res://scenes/v51_duster_policia_dirigivel.tscn"
const BLINDADO_POLICE_PATH := "res://scenes/v30_6_blindado_dirigivel.tscn"
const HOSPITAL_AMBULANCE_PATH := "res://scenes/v60_ambulancia_hospital.tscn"
const HOSPITAL_DUTY_CHECKPOINT := Vector3(240.0, 0.45, -206.8)
const HOSPITAL_AMBULANCE_CHECKPOINT := Vector3(222.0, 0.45, -222.8)
const HOSPITAL_AMBULANCE_SPAWN_POINT := Vector3(286.0, 0.20, -186.0)
const HOSPITAL_AMBULANCE_SPAWN_ROTATION_Y := PI / 2.0

# Base militar existente em cell_2_2, origem mundial aproximada (880, 0.2, 946).
const ARMY_HAMMER_PATH := "res://scenes/v70_hammer_militar.tscn"
const ARMY_TRUCK_PATH := "res://scenes/v70_caminhao_militar.tscn"
const ARMY_DUTY_CHECKPOINT := Vector3(849.0, 0.55, 958.0)
const ARMY_HAMMER_CHECKPOINT := Vector3(903.0, 0.55, 954.0)
const ARMY_HAMMER_SPAWN_POINT := Vector3(903.0, 0.55, 964.0)
const ARMY_HAMMER_SPAWN_ROTATION_Y := 0.0
const ARMY_TRUCK_CHECKPOINT := Vector3(930.0, 0.55, 954.0)
const ARMY_TRUCK_SPAWN_POINT := Vector3(930.0, 0.55, 964.0)
const ARMY_TRUCK_SPAWN_ROTATION_Y := 0.0
const ARMY_TRIGGER_RADIUS := 4.5
const ARMY_TRIGGER_MAX_HEIGHT := 4.0

# Dois pontos separados na MESMA base policial que já existe em cell_-3_-3.
# 1) dentro da delegacia: entrar/sair de serviço.
# 2) garagem: retirar/guardar a viatura.
const POLICE_DUTY_CHECKPOINT := Vector3(-722.0, 0.25, -734.4)
const POLICE_GARAGE_CHECKPOINT := Vector3(-774.0, 0.25, -706.5)
const POLICE_VEHICLE_SPAWN_POINT := Vector3(-774.0, 0.35, -713.0)
const POLICE_VEHICLE_SPAWN_ROTATION_Y := PI
const POLICE_ARMORED_CHECKPOINT := Vector3(-770.0, 0.25, -734.0)
const POLICE_ARMORED_SPAWN_POINT := Vector3(-770.0, 0.35, -746.0)
const POLICE_ARMORED_SPAWN_ROTATION_Y := PI
const POLICE_ARMORY_CHECKPOINT := Vector3(-742.5, 0.25, -751.0)
const POLICE_TRIGGER_RADIUS := 2.6
const POLICE_TRIGGER_MAX_HEIGHT := 3.0

var player: Node3D
var district_label: Label
var last_district: String = ""
var notice: Label

var vehicle_panel: PanelContainer
var vehicle_panel_title: Label
var vehicle_panel_hint: Label
var vehicle_button: Button
var vehicle_store_button: Button

var duty_panel: PanelContainer
var duty_panel_title: Label
var duty_panel_hint: Label
var police_role_button: Button

var armored_panel: PanelContainer
var armored_panel_title: Label
var armored_panel_hint: Label
var armored_button: Button
var armored_store_button: Button
var armory_panel: PanelContainer
var armory_panel_title: Label
var armory_panel_hint: Label
var rifle_button: Button

var police_mouse_released: bool = false
var toast_time := 0.0
var timer := 0.0
var visited: Dictionary = {}
var service_cooldown := 0.0
var active_police_vehicle: Node3D = null
var police_duty_checkpoint_root: Node3D = null
var police_garage_checkpoint_root: Node3D = null
var duster_police_scene: PackedScene = null
var duster_load_requested: bool = false
var active_armored_vehicle: Node3D = null
var police_armored_checkpoint_root: Node3D = null
var police_armory_checkpoint_root: Node3D = null
var armored_scene: PackedScene = null
var rifle_infinite_active: bool = false

var hospital_duty_panel: PanelContainer
var hospital_duty_title: Label
var hospital_duty_hint: Label
var medic_role_button: Button
var hospital_ambulance_panel: PanelContainer
var hospital_ambulance_title: Label
var hospital_ambulance_hint: Label
var hospital_ambulance_button: Button
var hospital_ambulance_store_button: Button
var hospital_duty_checkpoint_root: Node3D = null
var hospital_ambulance_checkpoint_root: Node3D = null
var hospital_ambulance_scene: PackedScene = null
var active_hospital_ambulance: Node3D = null

var army_duty_panel: PanelContainer
var army_duty_title: Label
var army_duty_hint: Label
var military_role_button: Button
var army_rifle_button: Button
var army_hammer_panel: PanelContainer
var army_hammer_title: Label
var army_hammer_hint: Label
var army_hammer_button: Button
var army_hammer_store_button: Button
var army_truck_panel: PanelContainer
var army_truck_title: Label
var army_truck_hint: Label
var army_truck_button: Button
var army_truck_store_button: Button
var army_duty_checkpoint_root: Node3D = null
var army_hammer_checkpoint_root: Node3D = null
var army_truck_checkpoint_root: Node3D = null
var army_hammer_scene: PackedScene = null
var army_truck_scene: PackedScene = null
var active_army_hammer: Node3D = null
var active_army_truck: Node3D = null

func _ready() -> void:
	player = get_node("Player")
	var ui := CanvasLayer.new()
	ui.layer = 12
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	district_label = null
	notice = Label.new()
	notice.anchor_left = .5
	notice.anchor_right = .5
	notice.offset_left = -260
	notice.offset_right = 260
	notice.offset_top = 47
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_color_override("font_color",Color("edcc83"))
	notice.add_theme_font_size_override("font_size",14)
	root.add_child(notice)
	_create_police_vehicle_panel(root)
	_create_police_duty_panel(root)
	_create_police_armored_panel(root)
	_create_police_armory_panel(root)
	_create_hospital_duty_panel(root)
	_create_hospital_ambulance_panel(root)
	_create_army_duty_panel(root)
	_create_army_hammer_panel(root)
	_create_army_truck_panel(root)
	_create_police_checkpoint_markers()
	_create_hospital_checkpoint_markers()
	_create_army_checkpoint_markers()
	_toast("BEM-VINDO À CIDADE  •  Explore para ganhar XP")

func _process(delta: float) -> void:
	toast_time -= delta
	service_cooldown = maxf(0,service_cooldown-delta)
	if toast_time <= 0 and notice != null:
		notice.text = ""
	if not is_instance_valid(player):
		return
	var position_now: Vector3 = player.global_position
	if player.get("vehicle") != null:
		position_now = player.get("vehicle").global_position
	_update_police_duty()
	_update_police_garage(position_now)
	_update_police_armored_garage(position_now)
	_update_police_armory()
	_maintain_police_rifle_infinite()
	_update_hospital_duty()
	_update_hospital_ambulance(position_now)
	_update_army_duty()
	_update_army_hammer(position_now)
	_update_army_truck(position_now)
	_update_police_mouse_mode((duty_panel != null and duty_panel.visible) or (vehicle_panel != null and vehicle_panel.visible) or (armored_panel != null and armored_panel.visible) or (armory_panel != null and armory_panel.visible) or (hospital_duty_panel != null and hospital_duty_panel.visible) or (hospital_ambulance_panel != null and hospital_ambulance_panel.visible) or (army_duty_panel != null and army_duty_panel.visible) or (army_hammer_panel != null and army_hammer_panel.visible) or (army_truck_panel != null and army_truck_panel.visible))
	timer += delta
	if timer < .25:
		return
	timer = 0
	var district: String = BAIRROS.name_at_world(Vector2(position_now.x,position_now.z))
	if district != last_district:
		last_district = district
		var district_state: Node = get_node_or_null("/root/GameState")
		if district_state == null and is_instance_valid(player):
			district_state = player.get("game_state") as Node
		if is_instance_valid(district_state) and district_state.has_signal("game_notice"):
			district_state.emit_signal("game_notice","BAIRRO","Você entrou em %s." % district)
	var tile := Vector2i(floori(position_now.x/160),floori(position_now.z/160))
	var key := str(tile)
	if not visited.has(key):
		var xp_state: Node = get_node_or_null("/root/GameState")
		if xp_state == null and is_instance_valid(player):
			xp_state = player.get("game_state") as Node
		if is_instance_valid(xp_state) and xp_state.has_method("add_xp"):
			xp_state.call("add_xp", 20)
			visited[key] = true
			if visited.size() > 1:
				_toast("NOVO QUARTEIRÃO  +20 XP")
	# Service pads já existentes.
	var hospital_distance := Vector2(position_now.x-240,position_now.z+192).length()
	var police_distance := Vector2(position_now.x+720,position_now.z+675).length()
	var army_distance := Vector2(position_now.x-880,position_now.z-925).length()
	if service_cooldown<=0 and player.get("vehicle")==null:
		if hospital_distance<12 and player.get("health")<100:
			player.set("health",100.0)
			player.call("_refresh_vitals")
			_toast("HOSPITAL  •  Vida restaurada")
			service_cooldown=10
		elif (police_distance<12 or army_distance<12) and player.get("armor")<100:
			player.set("armor",100.0)
			player.call("_refresh_vitals")
			_toast("BASE  •  Colete restaurado")
			service_cooldown=10

func _marker_group_position(group_name: StringName, fallback: Vector3) -> Vector3:
	for item in get_tree().get_nodes_in_group(group_name):
		if item is Node3D and is_instance_valid(item):
			return (item as Node3D).global_position
	return fallback

func _player_at_checkpoint(fallback: Vector3, marker_root: Node3D, group_name: StringName) -> bool:
	if not is_instance_valid(player) or player.get("vehicle") != null:
		return false
	var pos: Vector3 = player.global_position
	var marker_position: Vector3 = _marker_group_position(group_name, fallback)
	if is_instance_valid(marker_root):
		marker_position = marker_root.global_position
	var horizontal_distance: float = Vector2(pos.x - marker_position.x, pos.z - marker_position.z).length()
	return horizontal_distance <= POLICE_TRIGGER_RADIUS and absf(pos.y - marker_position.y) <= POLICE_TRIGGER_MAX_HEIGHT

func _player_at_checkpoint_custom(fallback: Vector3, marker_root: Node3D, group_name: StringName, radius: float, max_height: float) -> bool:
	if not is_instance_valid(player) or player.get("vehicle") != null:
		return false
	var pos: Vector3 = player.global_position
	var marker_position: Vector3 = _marker_group_position(group_name, fallback)
	if is_instance_valid(marker_root):
		marker_position = marker_root.global_position
	var horizontal_distance: float = Vector2(pos.x - marker_position.x, pos.z - marker_position.z).length()
	return horizontal_distance <= radius and absf(pos.y - marker_position.y) <= max_height

func _player_at_police_duty_checkpoint() -> bool:
	return _player_at_checkpoint(POLICE_DUTY_CHECKPOINT, police_duty_checkpoint_root, &"police_duty_spawn")

func _player_at_police_garage_checkpoint() -> bool:
	return _player_at_checkpoint(POLICE_GARAGE_CHECKPOINT, police_garage_checkpoint_root, &"police_garage_spawn")

func _player_at_police_armored_checkpoint() -> bool:
	return _player_at_checkpoint(POLICE_ARMORED_CHECKPOINT, police_armored_checkpoint_root, &"police_armored_garage_spawn")

func _player_at_police_armory_checkpoint() -> bool:
	return _player_at_checkpoint(POLICE_ARMORY_CHECKPOINT, police_armory_checkpoint_root, &"police_armory_spawn")

func _player_at_hospital_duty_checkpoint() -> bool:
	return _player_at_checkpoint(HOSPITAL_DUTY_CHECKPOINT, hospital_duty_checkpoint_root, &"hospital_duty_spawn")

func _player_at_hospital_ambulance_checkpoint() -> bool:
	return _player_at_checkpoint(HOSPITAL_AMBULANCE_CHECKPOINT, hospital_ambulance_checkpoint_root, &"hospital_ambulance_spawn")

func _player_at_army_duty_checkpoint() -> bool:
	if not _army_marker_loaded(&"army_duty_spawn"):
		return false
	return _player_at_checkpoint_custom(ARMY_DUTY_CHECKPOINT, army_duty_checkpoint_root, &"army_duty_spawn", ARMY_TRIGGER_RADIUS, ARMY_TRIGGER_MAX_HEIGHT)

func _player_at_army_hammer_checkpoint() -> bool:
	if not _army_marker_loaded(&"army_hammer_garage_spawn"):
		return false
	return _player_at_checkpoint_custom(ARMY_HAMMER_CHECKPOINT, army_hammer_checkpoint_root, &"army_hammer_garage_spawn", ARMY_TRIGGER_RADIUS, ARMY_TRIGGER_MAX_HEIGHT)

func _player_at_army_truck_checkpoint() -> bool:
	if not _army_marker_loaded(&"army_truck_garage_spawn"):
		return false
	return _player_at_checkpoint_custom(ARMY_TRUCK_CHECKPOINT, army_truck_checkpoint_root, &"army_truck_garage_spawn", ARMY_TRIGGER_RADIUS, ARMY_TRIGGER_MAX_HEIGHT)

func _update_hospital_duty() -> void:
	if hospital_duty_panel == null:
		return
	var inside := _player_at_hospital_duty_checkpoint()
	hospital_duty_panel.visible = inside
	if not inside:
		return
	var on_duty := player.has_method("is_medic_role") and bool(player.call("is_medic_role"))
	hospital_duty_title.text = "HOSPITAL  •  SERVIÇO MÉDICO"
	hospital_duty_hint.text = "Você está em serviço. Ambulâncias liberadas." if on_duty else "Entre em serviço para ficar amarelo e liberar a garagem de ambulâncias."
	medic_role_button.text = "SAIR DO SERVIÇO MÉDICO" if on_duty else "SEJA MÉDICO"

func _update_hospital_ambulance(position_now: Vector3) -> void:
	if hospital_ambulance_panel == null:
		return
	var checkpoint := _marker_group_position(&"hospital_ambulance_spawn", HOSPITAL_AMBULANCE_CHECKPOINT)
	var dist := Vector2(position_now.x - checkpoint.x, position_now.z - checkpoint.z).length()
	if dist < 120.0 and hospital_ambulance_scene == null:
		hospital_ambulance_scene = ResourceLoader.load(HOSPITAL_AMBULANCE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	var inside := _player_at_hospital_ambulance_checkpoint()
	hospital_ambulance_panel.visible = inside
	if not inside:
		return
	var on_duty := player.has_method("is_medic_role") and bool(player.call("is_medic_role"))
	var has_vehicle := is_instance_valid(active_hospital_ambulance) and not active_hospital_ambulance.is_queued_for_deletion()
	var occupied := has_vehicle and active_hospital_ambulance.get("driver") != null
	hospital_ambulance_title.text = "GARAGEM DO HOSPITAL  •  AMBULÂNCIA"
	hospital_ambulance_button.disabled = not on_duty or has_vehicle
	hospital_ambulance_store_button.disabled = not has_vehicle or occupied
	if not on_duty:
		hospital_ambulance_hint.text = "Entre em serviço como médico dentro do hospital."
	elif occupied:
		hospital_ambulance_hint.text = "Saia da ambulância antes de guardá-la."
	elif has_vehicle:
		hospital_ambulance_hint.text = "Ambulância retirada. Guarde-a para liberar outra."
	else:
		hospital_ambulance_hint.text = "Retire a ambulância desta garagem."
	if on_duty and not bool(get_tree().get_meta("br1_chat_typing", false)) and Input.is_action_just_pressed("interact") and not has_vehicle:
		_request_hospital_ambulance()

func _toggle_medic_role() -> void:
	if not _player_at_hospital_duty_checkpoint() or not is_instance_valid(player):
		return
	if not player.has_method("set_medic_role"):
		_toast("HOSPITAL  •  Sistema médico indisponível")
		return
	var active := player.has_method("is_medic_role") and bool(player.call("is_medic_role"))
	player.call("set_medic_role", not active)
	_toast("HOSPITAL  •  Você saiu do serviço médico" if active else "HOSPITAL  •  MÉDICO EM SERVIÇO  •  AMBULÂNCIAS LIBERADAS", false)
	_update_hospital_duty()
	_update_hospital_ambulance(player.global_position)

func _request_hospital_ambulance() -> void:
	if not _player_at_hospital_ambulance_checkpoint():
		return
	if not (player.has_method("is_medic_role") and bool(player.call("is_medic_role"))):
		_toast("HOSPITAL  •  Entre em serviço como médico primeiro")
		return
	if is_instance_valid(active_hospital_ambulance) and not active_hospital_ambulance.is_queued_for_deletion():
		_toast("HOSPITAL  •  Guarde a ambulância atual primeiro")
		return
	var spawn_point := _marker_group_position(&"hospital_ambulance_vehicle_spawn", HOSPITAL_AMBULANCE_SPAWN_POINT)
	if not _spawn_area_clear(spawn_point):
		_toast("HOSPITAL  •  Vaga da ambulância ocupada")
		return
	if hospital_ambulance_scene == null:
		hospital_ambulance_scene = ResourceLoader.load(HOSPITAL_AMBULANCE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	if hospital_ambulance_scene == null:
		_toast("HOSPITAL  •  Ambulância indisponível")
		return
	var ambulance := hospital_ambulance_scene.instantiate() as Node3D
	if ambulance == null:
		_toast("HOSPITAL  •  Falha ao criar ambulância")
		return
	get_tree().current_scene.add_child(ambulance)
	ambulance.global_position = _project_point_to_ground(spawn_point, ambulance) + Vector3.UP * 0.06
	ambulance.rotation.y = HOSPITAL_AMBULANCE_SPAWN_ROTATION_Y
	active_hospital_ambulance = ambulance
	_toast("HOSPITAL  •  AMBULÂNCIA LIBERADA")

func _store_hospital_ambulance() -> void:
	if not _player_at_hospital_ambulance_checkpoint():
		return
	if not is_instance_valid(active_hospital_ambulance) or active_hospital_ambulance.is_queued_for_deletion():
		_toast("HOSPITAL  •  Nenhuma ambulância para guardar")
		return
	if active_hospital_ambulance.get("driver") != null:
		_toast("HOSPITAL  •  Saia da ambulância antes de guardar")
		return
	active_hospital_ambulance.queue_free()
	active_hospital_ambulance = null
	_toast("HOSPITAL  •  AMBULÂNCIA GUARDADA")

func _update_army_duty() -> void:
	if army_duty_panel == null:
		return
	var inside := _player_at_army_duty_checkpoint()
	army_duty_panel.visible = inside
	if not inside:
		return
	var on_duty := player.has_method("is_military_role") and bool(player.call("is_military_role"))
	army_duty_title.text = "EXÉRCITO  •  SERVIÇO MILITAR"
	army_duty_hint.text = "AK-47 e garagem militar liberadas." if on_duty else "Entre em serviço para liberar AK-47, Hammer e caminhão."
	military_role_button.text = "SAIR DO EXÉRCITO" if on_duty else "SEJA MILITAR"
	army_rifle_button.disabled = not on_duty

func _take_army_rifle() -> void:
	if not _player_at_army_duty_checkpoint() or not player.is_military_role():
		return
	_equip_service_rifle(WEAPONS.ARMY_SLOT)
	_toast("EXÉRCITO  •  AK-47 RETIRADA")

func _equip_service_rifle(slot: int) -> void:
	player.call("_select_weapon", slot)
	var ammo: Array = player.get("magazine_ammo")
	var reserve: Array = player.get("reserve_ammo")
	if slot < ammo.size() and slot < reserve.size():
		ammo[slot] = WEAPONS.MAGAZINE[slot]
		reserve[slot] = maxi(int(reserve[slot]), WEAPONS.RESERVE[slot])
	player.call("_refresh_weapon_hud")

func _toggle_military_role() -> void:
	if not _player_at_army_duty_checkpoint() or not is_instance_valid(player):
		return
	if not player.has_method("set_military_role"):
		_toast("EXÉRCITO  •  Sistema militar indisponível")
		return
	var active := player.has_method("is_military_role") and bool(player.call("is_military_role"))
	player.call("set_military_role", not active)
	_toast("EXÉRCITO  •  Você saiu do serviço militar" if active else "EXÉRCITO  •  MILITAR EM SERVIÇO  •  GARAGEM LIBERADA", false)
	_update_army_duty()
	_update_army_hammer(player.global_position)
	_update_army_truck(player.global_position)

func _update_army_hammer(position_now: Vector3) -> void:
	if army_hammer_panel == null:
		return
	var checkpoint := _marker_group_position(&"army_hammer_garage_spawn", ARMY_HAMMER_CHECKPOINT)
	if Vector2(position_now.x-checkpoint.x, position_now.z-checkpoint.z).length() < 130.0 and army_hammer_scene == null:
		army_hammer_scene = ResourceLoader.load(ARMY_HAMMER_PATH, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	var inside := _player_at_army_hammer_checkpoint()
	army_hammer_panel.visible = inside
	if not inside:
		return
	var on_duty := player.has_method("is_military_role") and bool(player.call("is_military_role"))
	var has_vehicle := is_instance_valid(active_army_hammer) and not active_army_hammer.is_queued_for_deletion()
	var occupied := has_vehicle and active_army_hammer.get("driver") != null
	army_hammer_title.text = "GARAGEM MILITAR  •  HAMMER"
	army_hammer_button.disabled = not on_duty or has_vehicle
	army_hammer_store_button.disabled = not has_vehicle or occupied
	if not on_duty:
		army_hammer_hint.text = "Entre em serviço militar antes de retirar o Hammer."
	elif occupied:
		army_hammer_hint.text = "Saia do Hammer antes de guardá-lo."
	elif has_vehicle:
		army_hammer_hint.text = "Hammer em uso. Guarde-o para liberar outro."
	else:
		army_hammer_hint.text = "Retire o Hammer da vaga militar."
	if on_duty and not bool(get_tree().get_meta("br1_chat_typing", false)) and Input.is_action_just_pressed("interact") and not has_vehicle:
		_request_army_hammer()

func _request_army_hammer() -> void:
	if not _player_at_army_hammer_checkpoint():
		return
	if not (player.has_method("is_military_role") and bool(player.call("is_military_role"))):
		_toast("EXÉRCITO  •  Entre em serviço militar primeiro")
		return
	if is_instance_valid(active_army_hammer) and not active_army_hammer.is_queued_for_deletion():
		_toast("EXÉRCITO  •  Guarde o Hammer atual primeiro")
		return
	var spawn_point := _marker_group_position(&"army_hammer_vehicle_spawn", ARMY_HAMMER_SPAWN_POINT)
	if not _spawn_area_clear(spawn_point):
		_toast("EXÉRCITO  •  Vaga do Hammer ocupada")
		return
	if army_hammer_scene == null:
		army_hammer_scene = ResourceLoader.load(ARMY_HAMMER_PATH, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	if army_hammer_scene == null:
		_toast("EXÉRCITO  •  Hammer indisponível")
		return
	var vehicle := army_hammer_scene.instantiate() as Node3D
	if vehicle == null:
		_toast("EXÉRCITO  •  Falha ao criar Hammer")
		return
	get_tree().current_scene.add_child(vehicle)
	vehicle.global_position = _project_point_to_ground(spawn_point, vehicle) + Vector3.UP * 0.08
	vehicle.rotation.y = ARMY_HAMMER_SPAWN_ROTATION_Y
	active_army_hammer = vehicle
	_toast("EXÉRCITO  •  HAMMER LIBERADO")

func _store_army_hammer() -> void:
	if not _player_at_army_hammer_checkpoint():
		return
	if not is_instance_valid(active_army_hammer) or active_army_hammer.is_queued_for_deletion():
		_toast("EXÉRCITO  •  Nenhum Hammer para guardar")
		return
	if active_army_hammer.get("driver") != null:
		_toast("EXÉRCITO  •  Saia do Hammer antes de guardar")
		return
	active_army_hammer.queue_free()
	active_army_hammer = null
	_toast("EXÉRCITO  •  HAMMER GUARDADO")

func _update_army_truck(position_now: Vector3) -> void:
	if army_truck_panel == null:
		return
	var checkpoint := _marker_group_position(&"army_truck_garage_spawn", ARMY_TRUCK_CHECKPOINT)
	if Vector2(position_now.x-checkpoint.x, position_now.z-checkpoint.z).length() < 145.0 and army_truck_scene == null:
		army_truck_scene = ResourceLoader.load(ARMY_TRUCK_PATH, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	var inside := _player_at_army_truck_checkpoint()
	army_truck_panel.visible = inside
	if not inside:
		return
	var on_duty := player.has_method("is_military_role") and bool(player.call("is_military_role"))
	var has_vehicle := is_instance_valid(active_army_truck) and not active_army_truck.is_queued_for_deletion()
	var occupied := has_vehicle and active_army_truck.get("driver") != null
	army_truck_title.text = "GARAGEM MILITAR  •  CAMINHÃO"
	army_truck_button.disabled = not on_duty or has_vehicle
	army_truck_store_button.disabled = not has_vehicle or occupied
	if not on_duty:
		army_truck_hint.text = "Entre em serviço militar antes de retirar o caminhão."
	elif occupied:
		army_truck_hint.text = "Saia do caminhão antes de guardá-lo."
	elif has_vehicle:
		army_truck_hint.text = "Caminhão em uso. Guarde-o para liberar outro."
	else:
		army_truck_hint.text = "Retire o caminhão da garagem pesada."
	if on_duty and not bool(get_tree().get_meta("br1_chat_typing", false)) and Input.is_action_just_pressed("interact") and not has_vehicle:
		_request_army_truck()

func _request_army_truck() -> void:
	if not _player_at_army_truck_checkpoint():
		return
	if not (player.has_method("is_military_role") and bool(player.call("is_military_role"))):
		_toast("EXÉRCITO  •  Entre em serviço militar primeiro")
		return
	if is_instance_valid(active_army_truck) and not active_army_truck.is_queued_for_deletion():
		_toast("EXÉRCITO  •  Guarde o caminhão atual primeiro")
		return
	var spawn_point := _marker_group_position(&"army_truck_vehicle_spawn", ARMY_TRUCK_SPAWN_POINT)
	if not _spawn_area_clear(spawn_point):
		_toast("EXÉRCITO  •  Vaga do caminhão ocupada")
		return
	if army_truck_scene == null:
		army_truck_scene = ResourceLoader.load(ARMY_TRUCK_PATH, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	if army_truck_scene == null:
		_toast("EXÉRCITO  •  Caminhão indisponível")
		return
	var vehicle := army_truck_scene.instantiate() as Node3D
	if vehicle == null:
		_toast("EXÉRCITO  •  Falha ao criar Caminhão")
		return
	get_tree().current_scene.add_child(vehicle)
	vehicle.global_position = _project_point_to_ground(spawn_point, vehicle) + Vector3.UP * 0.10
	vehicle.rotation.y = ARMY_TRUCK_SPAWN_ROTATION_Y
	active_army_truck = vehicle
	_toast("EXÉRCITO  •  CAMINHÃO LIBERADO")

func _store_army_truck() -> void:
	if not _player_at_army_truck_checkpoint():
		return
	if not is_instance_valid(active_army_truck) or active_army_truck.is_queued_for_deletion():
		_toast("EXÉRCITO  •  Nenhum caminhão para guardar")
		return
	if active_army_truck.get("driver") != null:
		_toast("EXÉRCITO  •  Saia do caminhão antes de guardar")
		return
	active_army_truck.queue_free()
	active_army_truck = null
	_toast("EXÉRCITO  •  CAMINHÃO GUARDADO")

func _update_police_duty() -> void:
	if duty_panel == null:
		return
	var inside_area := _player_at_police_duty_checkpoint()
	duty_panel.visible = inside_area
	if not inside_area:
		return
	var on_duty: bool = player.has_method("is_police_role") and bool(player.call("is_police_role"))
	duty_panel_title.text = "DELEGACIA  •  SERVIÇO POLICIAL"
	duty_panel_hint.text = "Você está em serviço." if on_duty else "Entre em serviço para liberar uniforme azul, colete, arsenal e viaturas."
	police_role_button.text = "SAIR DA POLÍCIA" if on_duty else "SEJA POLICIAL"

func _update_police_garage(position_now: Vector3) -> void:
	if vehicle_panel == null:
		return
	var garage_position := _marker_group_position(&"police_garage_spawn", POLICE_GARAGE_CHECKPOINT)
	var police_distance: float = Vector2(position_now.x - garage_position.x, position_now.z - garage_position.z).length()
	if police_distance < 110.0:
		_warmup_police_vehicle()
	var inside_area: bool = _player_at_police_garage_checkpoint()
	vehicle_panel.visible = inside_area
	if not inside_area:
		return
	var has_vehicle: bool = is_instance_valid(active_police_vehicle) and not active_police_vehicle.is_queued_for_deletion()
	var occupied: bool = has_vehicle and active_police_vehicle.get("driver") != null
	var on_duty: bool = player.has_method("is_police_role") and bool(player.call("is_police_role"))
	vehicle_panel_title.text = "GARAGEM POLICIAL  •  DUSTER"
	vehicle_button.disabled = has_vehicle or not on_duty
	vehicle_store_button.disabled = not has_vehicle or occupied
	if not on_duty:
		vehicle_panel_hint.text = "Entre em serviço dentro da delegacia antes de retirar uma viatura."
	elif occupied:
		vehicle_panel_hint.text = "A viatura está em uso. Saia dela antes de guardar."
	elif has_vehicle:
		vehicle_panel_hint.text = "Viatura retirada. Guarde-a para liberar uma nova."
	else:
		vehicle_panel_hint.text = "Retire a Duster policial desta garagem."
	if on_duty and not bool(get_tree().get_meta("br1_chat_typing", false)) and Input.is_action_just_pressed("interact") and not has_vehicle:
		_request_police_vehicle()

func _update_police_armored_garage(position_now: Vector3) -> void:
	if armored_panel == null:
		return
	var checkpoint := _marker_group_position(&"police_armored_garage_spawn", POLICE_ARMORED_CHECKPOINT)
	var distance := Vector2(position_now.x - checkpoint.x, position_now.z - checkpoint.z).length()
	if distance < 115.0 and armored_scene == null:
		armored_scene = ResourceLoader.load(BLINDADO_POLICE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	var inside := _player_at_police_armored_checkpoint()
	armored_panel.visible = inside
	if not inside:
		return
	var has_vehicle := is_instance_valid(active_armored_vehicle) and not active_armored_vehicle.is_queued_for_deletion()
	var occupied := has_vehicle and active_armored_vehicle.get("driver") != null
	var on_duty := player.has_method("is_police_role") and bool(player.call("is_police_role"))
	armored_panel_title.text = "GARAGEM DE BLINDADOS"
	armored_button.disabled = has_vehicle or not on_duty
	armored_store_button.disabled = not has_vehicle or occupied
	if not on_duty:
		armored_panel_hint.text = "Entre em serviço antes de retirar um blindado."
	elif occupied:
		armored_panel_hint.text = "Saia do blindado antes de guardar."
	elif has_vehicle:
		armored_panel_hint.text = "Blindado em uso. Guarde-o para liberar outro."
	else:
		armored_panel_hint.text = "Retire o blindado policial desta garagem."
	if on_duty and not bool(get_tree().get_meta("br1_chat_typing", false)) and Input.is_action_just_pressed("interact") and not has_vehicle:
		_request_armored_vehicle()

func _spawn_area_clear(point: Vector3) -> bool:
	var world := get_world_3d()
	if world == null:
		return true
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.2, 2.5, 9.5)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 1.35)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hits := world.direct_space_state.intersect_shape(query, 24)
	for hit in hits:
		var collider: Object = hit.get("collider")
		if collider == player:
			continue
		if collider is VehicleBody3D or collider is RigidBody3D or collider is CharacterBody3D:
			return false
	return true

func _request_armored_vehicle() -> void:
	if not _player_at_police_armored_checkpoint():
		return
	if not (player.has_method("is_police_role") and bool(player.call("is_police_role"))):
		_toast("BLINDADOS  •  Entre em serviço primeiro")
		return
	if is_instance_valid(active_armored_vehicle) and not active_armored_vehicle.is_queued_for_deletion():
		_toast("BLINDADOS  •  Guarde o blindado atual primeiro")
		return
	var spawn_point := _marker_group_position(&"police_armored_vehicle_spawn", POLICE_ARMORED_SPAWN_POINT)
	if not _spawn_area_clear(spawn_point):
		_toast("BLINDADOS  •  Vaga ocupada")
		return
	if armored_scene == null:
		armored_scene = ResourceLoader.load(BLINDADO_POLICE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	if armored_scene == null:
		_toast("BLINDADOS  •  Modelo indisponível")
		return
	var blindado := armored_scene.instantiate() as Node3D
	if blindado == null:
		_toast("BLINDADOS  •  Falha ao criar veículo")
		return
	get_tree().current_scene.add_child(blindado)
	blindado.global_position = _project_point_to_ground(spawn_point, blindado) + Vector3.UP * 0.12
	blindado.rotation.y = POLICE_ARMORED_SPAWN_ROTATION_Y
	active_armored_vehicle = blindado
	_toast("BLINDADOS  •  BLINDADO POLICIAL LIBERADO")

func _store_armored_vehicle() -> void:
	if not _player_at_police_armored_checkpoint():
		return
	if not is_instance_valid(active_armored_vehicle) or active_armored_vehicle.is_queued_for_deletion():
		_toast("BLINDADOS  •  Nenhum blindado para guardar")
		return
	if active_armored_vehicle.get("driver") != null:
		_toast("BLINDADOS  •  Saia do veículo antes de guardar")
		return
	active_armored_vehicle.queue_free()
	active_armored_vehicle = null
	_toast("BLINDADOS  •  BLINDADO GUARDADO")

func _update_police_armory() -> void:
	if armory_panel == null:
		return
	var inside := _player_at_police_armory_checkpoint()
	armory_panel.visible = inside
	if not inside:
		return
	var on_duty := player.has_method("is_police_role") and bool(player.call("is_police_role"))
	armory_panel_title.text = "ARSENAL POLICIAL"
	rifle_button.disabled = not on_duty
	armory_panel_hint.text = "M16 liberada com munição de serviço." if on_duty else "Entre em serviço para acessar o armamento."
	if on_duty and not bool(get_tree().get_meta("br1_chat_typing", false)) and Input.is_action_just_pressed("interact"):
		_take_police_rifle()

func _take_police_rifle() -> void:
	if not _player_at_police_armory_checkpoint():
		return
	if not (player.has_method("is_police_role") and bool(player.call("is_police_role"))):
		_toast("ARSENAL  •  Entre em serviço primeiro")
		return
	rifle_infinite_active = true
	_equip_service_rifle(WEAPONS.POLICE_SLOT)
	_toast("ARSENAL  •  M16 RETIRADA")

func _maintain_police_rifle_infinite() -> void:
	if not rifle_infinite_active or not is_instance_valid(player):
		return
	if not (player.has_method("is_police_role") and bool(player.call("is_police_role"))):
		rifle_infinite_active = false
		return
	var ammo: Variant = player.get("magazine_ammo")
	if ammo is Array and ammo.size() > WEAPONS.POLICE_SLOT and int(ammo[WEAPONS.POLICE_SLOT]) < WEAPONS.MAGAZINE[WEAPONS.POLICE_SLOT]:
		ammo[WEAPONS.POLICE_SLOT] = WEAPONS.MAGAZINE[WEAPONS.POLICE_SLOT]
		if player.has_method("_refresh_weapon_hud"):
			player.call("_refresh_weapon_hud")

func _update_police_mouse_mode(any_panel_open: bool) -> void:
	if OS.has_feature("mobile"):
		return
	if any_panel_open:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			police_mouse_released = true
	elif police_mouse_released:
		police_mouse_released = false
		# O Main City usa mouse livre fora da mira; não força captura aqui.
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _warmup_police_vehicle() -> void:
	if duster_police_scene != null:
		return
	if not duster_load_requested:
		var error := ResourceLoader.load_threaded_request(DUSTER_POLICE_PATH, "PackedScene", true, ResourceLoader.CACHE_MODE_REUSE)
		if error == OK or error == ERR_BUSY:
			duster_load_requested = true
		else:
			return
	var status := ResourceLoader.load_threaded_get_status(DUSTER_POLICE_PATH)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		duster_police_scene = ResourceLoader.load_threaded_get(DUSTER_POLICE_PATH) as PackedScene
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		duster_load_requested = false

func _get_police_vehicle_scene() -> PackedScene:
	if duster_police_scene != null:
		return duster_police_scene
	_warmup_police_vehicle()
	if duster_police_scene != null:
		return duster_police_scene
	return ResourceLoader.load(DUSTER_POLICE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene

func _request_police_vehicle() -> void:
	if not _player_at_police_garage_checkpoint():
		return
	if not (player.has_method("is_police_role") and bool(player.call("is_police_role"))):
		_toast("GARAGEM POLICIAL  •  Entre em serviço primeiro")
		return
	if is_instance_valid(active_police_vehicle) and not active_police_vehicle.is_queued_for_deletion():
		_toast("GARAGEM POLICIAL  •  Guarde a viatura atual primeiro")
		return
	var packed := _get_police_vehicle_scene()
	if packed == null:
		_toast("GARAGEM POLICIAL  •  Viatura ainda carregando")
		return
	duster_police_scene = packed
	var viatura := packed.instantiate() as Node3D
	if viatura == null:
		_toast("GARAGEM POLICIAL  •  Erro ao carregar a viatura")
		return
	get_tree().current_scene.add_child(viatura)
	var spawn_point := _marker_group_position(&"police_vehicle_spawn", POLICE_VEHICLE_SPAWN_POINT)
	viatura.global_position = _project_point_to_ground(spawn_point, viatura) + Vector3.UP * 0.12
	viatura.rotation.y = POLICE_VEHICLE_SPAWN_ROTATION_Y
	active_police_vehicle = viatura
	_toast("GARAGEM POLICIAL  •  DUSTER POLICIAL LIBERADA")
	_update_police_garage(player.global_position)

func _store_police_vehicle() -> void:
	if not _player_at_police_garage_checkpoint():
		return
	if not is_instance_valid(active_police_vehicle) or active_police_vehicle.is_queued_for_deletion():
		_toast("GARAGEM POLICIAL  •  Nenhuma viatura para guardar")
		return
	if active_police_vehicle.get("driver") != null:
		_toast("GARAGEM POLICIAL  •  Saia da viatura antes de guardar")
		return
	active_police_vehicle.queue_free()
	active_police_vehicle = null
	_toast("GARAGEM POLICIAL  •  VIATURA GUARDADA")
	_update_police_garage(player.global_position)

func _toggle_police_role() -> void:
	if not _player_at_police_duty_checkpoint() or not is_instance_valid(player):
		return
	if not player.has_method("set_police_role"):
		_toast("DELEGACIA  •  Sistema policial indisponível")
		return
	var active: bool = player.has_method("is_police_role") and bool(player.call("is_police_role"))
	player.call("set_police_role", not active)
	if active:
		rifle_infinite_active = false
		_toast("POLÍCIA  •  Você saiu de serviço",false)
	else:
		# A M16 e retirada no ponto fisico do Arsenal.
		# A arma passa a ser retirada somente no ponto físico do Arsenal.
		if player.has_method("_select_weapon"):
			player.call("_select_weapon", -1)
		rifle_infinite_active = false
		_toast("POLÍCIA  •  Em serviço  •  Arsenal e viaturas liberados",false)
	_update_police_duty()
	_update_police_garage(player.global_position)
	_update_police_armored_garage(player.global_position)
	_update_police_armory()

func _panel_style(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.09, 0.93)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _create_police_vehicle_panel(root: Control) -> void:
	vehicle_panel = PanelContainer.new()
	vehicle_panel.anchor_left = 0.5
	vehicle_panel.anchor_right = 0.5
	vehicle_panel.anchor_top = 1.0
	vehicle_panel.anchor_bottom = 1.0
	vehicle_panel.offset_left = -220.0
	vehicle_panel.offset_right = 220.0
	vehicle_panel.offset_top = -255.0
	vehicle_panel.offset_bottom = -85.0
	vehicle_panel.visible = false
	vehicle_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	vehicle_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.16,0.45,1.0,0.95)))
	root.add_child(vehicle_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vehicle_panel.add_child(vb)
	vehicle_panel_title = Label.new()
	vehicle_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vehicle_panel_title.add_theme_font_size_override("font_size", 18)
	vehicle_panel_title.add_theme_color_override("font_color", Color(0.82,0.91,1.0,1.0))
	vb.add_child(vehicle_panel_title)
	vehicle_panel_hint = Label.new()
	vehicle_panel_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vehicle_panel_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vehicle_panel_hint.add_theme_font_size_override("font_size", 13)
	vehicle_panel_hint.add_theme_color_override("font_color", Color(0.85,0.90,0.95,1.0))
	vb.add_child(vehicle_panel_hint)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 9)
	vb.add_child(actions)
	vehicle_button = Button.new()
	vehicle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vehicle_button.custom_minimum_size = Vector2(0, 42)
	vehicle_button.text = "PUXAR VIATURA"
	vehicle_button.pressed.connect(_request_police_vehicle)
	actions.add_child(vehicle_button)
	vehicle_store_button = Button.new()
	vehicle_store_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vehicle_store_button.custom_minimum_size = Vector2(0, 42)
	vehicle_store_button.text = "GUARDAR VIATURA"
	vehicle_store_button.pressed.connect(_store_police_vehicle)
	vehicle_store_button.disabled = true
	actions.add_child(vehicle_store_button)

func _create_police_duty_panel(root: Control) -> void:
	duty_panel = PanelContainer.new()
	duty_panel.anchor_left = 0.5
	duty_panel.anchor_right = 0.5
	duty_panel.anchor_top = 1.0
	duty_panel.anchor_bottom = 1.0
	duty_panel.offset_left = -215.0
	duty_panel.offset_right = 215.0
	duty_panel.offset_top = -245.0
	duty_panel.offset_bottom = -85.0
	duty_panel.visible = false
	duty_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	duty_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.12,0.39,1.0,0.95)))
	root.add_child(duty_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	duty_panel.add_child(vb)
	duty_panel_title = Label.new()
	duty_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	duty_panel_title.add_theme_font_size_override("font_size", 18)
	duty_panel_title.add_theme_color_override("font_color", Color(0.78,0.90,1.0,1.0))
	vb.add_child(duty_panel_title)
	duty_panel_hint = Label.new()
	duty_panel_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	duty_panel_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	duty_panel_hint.add_theme_font_size_override("font_size", 13)
	duty_panel_hint.add_theme_color_override("font_color", Color(0.88,0.92,0.98,1.0))
	vb.add_child(duty_panel_hint)
	police_role_button = Button.new()
	police_role_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	police_role_button.custom_minimum_size = Vector2(0, 44)
	police_role_button.text = "SEJA POLICIAL"
	police_role_button.pressed.connect(_toggle_police_role)
	vb.add_child(police_role_button)

func _create_police_armored_panel(root: Control) -> void:
	armored_panel = PanelContainer.new()
	armored_panel.anchor_left = 0.5
	armored_panel.anchor_right = 0.5
	armored_panel.anchor_top = 1.0
	armored_panel.anchor_bottom = 1.0
	armored_panel.offset_left = -220.0
	armored_panel.offset_right = 220.0
	armored_panel.offset_top = -255.0
	armored_panel.offset_bottom = -85.0
	armored_panel.visible = false
	armored_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	armored_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.10,0.35,0.86,0.95)))
	root.add_child(armored_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	armored_panel.add_child(vb)
	armored_panel_title = Label.new()
	armored_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	armored_panel_title.add_theme_font_size_override("font_size", 17)
	vb.add_child(armored_panel_title)
	armored_panel_hint = Label.new()
	armored_panel_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	armored_panel_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	armored_panel_hint.add_theme_font_size_override("font_size", 13)
	vb.add_child(armored_panel_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	vb.add_child(row)
	armored_button = Button.new()
	armored_button.text = "RETIRAR BLINDADO"
	armored_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	armored_button.custom_minimum_size = Vector2(0, 42)
	armored_button.pressed.connect(_request_armored_vehicle)
	row.add_child(armored_button)
	armored_store_button = Button.new()
	armored_store_button.text = "GUARDAR BLINDADO"
	armored_store_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	armored_store_button.custom_minimum_size = Vector2(0, 42)
	armored_store_button.pressed.connect(_store_armored_vehicle)
	row.add_child(armored_store_button)

func _create_police_armory_panel(root: Control) -> void:
	armory_panel = PanelContainer.new()
	armory_panel.anchor_left = 0.5
	armory_panel.anchor_right = 0.5
	armory_panel.anchor_top = 1.0
	armory_panel.anchor_bottom = 1.0
	armory_panel.offset_left = -205.0
	armory_panel.offset_right = 205.0
	armory_panel.offset_top = -225.0
	armory_panel.offset_bottom = -85.0
	armory_panel.visible = false
	armory_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	armory_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.17,0.46,1.0,0.95)))
	root.add_child(armory_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	armory_panel.add_child(vb)
	armory_panel_title = Label.new()
	armory_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	armory_panel_title.add_theme_font_size_override("font_size", 17)
	vb.add_child(armory_panel_title)
	armory_panel_hint = Label.new()
	armory_panel_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	armory_panel_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	armory_panel_hint.add_theme_font_size_override("font_size", 13)
	vb.add_child(armory_panel_hint)
	rifle_button = Button.new()
	rifle_button.text = "PEGAR M16"
	rifle_button.custom_minimum_size = Vector2(0, 42)
	rifle_button.pressed.connect(_take_police_rifle)
	vb.add_child(rifle_button)

func _create_hospital_duty_panel(root: Control) -> void:
	hospital_duty_panel = PanelContainer.new()
	hospital_duty_panel.anchor_left = 0.5
	hospital_duty_panel.anchor_right = 0.5
	hospital_duty_panel.anchor_top = 1.0
	hospital_duty_panel.anchor_bottom = 1.0
	hospital_duty_panel.offset_left = -220.0
	hospital_duty_panel.offset_right = 220.0
	hospital_duty_panel.offset_top = -245.0
	hospital_duty_panel.offset_bottom = -85.0
	hospital_duty_panel.visible = false
	hospital_duty_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hospital_duty_panel.add_theme_stylebox_override("panel", _panel_style(Color(1.0,0.76,0.08,0.96)))
	root.add_child(hospital_duty_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	hospital_duty_panel.add_child(vb)
	hospital_duty_title = Label.new()
	hospital_duty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hospital_duty_title.add_theme_font_size_override("font_size", 18)
	vb.add_child(hospital_duty_title)
	hospital_duty_hint = Label.new()
	hospital_duty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hospital_duty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hospital_duty_hint.add_theme_font_size_override("font_size", 13)
	vb.add_child(hospital_duty_hint)
	medic_role_button = Button.new()
	medic_role_button.custom_minimum_size = Vector2(0, 44)
	medic_role_button.text = "SEJA MÉDICO"
	medic_role_button.pressed.connect(_toggle_medic_role)
	vb.add_child(medic_role_button)

func _create_hospital_ambulance_panel(root: Control) -> void:
	hospital_ambulance_panel = PanelContainer.new()
	hospital_ambulance_panel.anchor_left = 0.5
	hospital_ambulance_panel.anchor_right = 0.5
	hospital_ambulance_panel.anchor_top = 1.0
	hospital_ambulance_panel.anchor_bottom = 1.0
	hospital_ambulance_panel.offset_left = -230.0
	hospital_ambulance_panel.offset_right = 230.0
	hospital_ambulance_panel.offset_top = -255.0
	hospital_ambulance_panel.offset_bottom = -85.0
	hospital_ambulance_panel.visible = false
	hospital_ambulance_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hospital_ambulance_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.10,0.75,0.92,0.96)))
	root.add_child(hospital_ambulance_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	hospital_ambulance_panel.add_child(vb)
	hospital_ambulance_title = Label.new()
	hospital_ambulance_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hospital_ambulance_title.add_theme_font_size_override("font_size", 18)
	vb.add_child(hospital_ambulance_title)
	hospital_ambulance_hint = Label.new()
	hospital_ambulance_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hospital_ambulance_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hospital_ambulance_hint.add_theme_font_size_override("font_size", 13)
	vb.add_child(hospital_ambulance_hint)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 9)
	vb.add_child(actions)
	hospital_ambulance_button = Button.new()
	hospital_ambulance_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hospital_ambulance_button.custom_minimum_size = Vector2(0, 42)
	hospital_ambulance_button.text = "RETIRAR AMBULÂNCIA"
	hospital_ambulance_button.pressed.connect(_request_hospital_ambulance)
	actions.add_child(hospital_ambulance_button)
	hospital_ambulance_store_button = Button.new()
	hospital_ambulance_store_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hospital_ambulance_store_button.custom_minimum_size = Vector2(0, 42)
	hospital_ambulance_store_button.text = "GUARDAR AMBULÂNCIA"
	hospital_ambulance_store_button.pressed.connect(_store_hospital_ambulance)
	actions.add_child(hospital_ambulance_store_button)

func _make_checkpoint_marker(name_text: String, point: Vector3, color: Color, caption: String) -> Node3D:
	var root := Node3D.new()
	root.name = name_text
	add_child(root)
	root.global_position = _project_point_to_ground(point) + Vector3.UP * 0.55
	var sphere := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.48
	sphere_mesh.height = 0.96
	sphere.mesh = sphere_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.7
	mat.roughness = 0.30
	sphere.material_override = mat
	root.add_child(sphere)
	var ring := MeshInstance3D.new()
	ring.position.y = -0.46
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.05
	cylinder.bottom_radius = 1.05
	cylinder.height = 0.05
	ring.mesh = cylinder
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(color.r, color.g, color.b, 0.62)
	ring_mat.emission_enabled = true
	ring_mat.emission = color
	ring_mat.emission_energy_multiplier = 1.1
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = ring_mat
	root.add_child(ring)
	var label := Label3D.new()
	label.text = caption
	label.position = Vector3(0, 1.35, 0)
	label.font_size = 22
	label.pixel_size = 0.014
	label.modulate = Color(0.88,0.95,1.0,1.0)
	label.outline_modulate = Color(0.01,0.02,0.05,1.0)
	root.add_child(label)
	return root

func _create_army_duty_panel(root: Control) -> void:
	army_duty_panel = PanelContainer.new()
	army_duty_panel.anchor_left = 0.5; army_duty_panel.anchor_right = 0.5
	army_duty_panel.anchor_top = 1.0; army_duty_panel.anchor_bottom = 1.0
	army_duty_panel.offset_left = -220; army_duty_panel.offset_right = 220
	army_duty_panel.offset_top = -245; army_duty_panel.offset_bottom = -80
	army_duty_panel.visible = false
	army_duty_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	army_duty_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.22,0.55,0.18,0.95)))
	root.add_child(army_duty_panel)
	var vb := VBoxContainer.new(); army_duty_panel.add_child(vb)
	army_duty_title = Label.new(); army_duty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; army_duty_title.add_theme_font_size_override("font_size",18); vb.add_child(army_duty_title)
	army_duty_hint = Label.new(); army_duty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; army_duty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; vb.add_child(army_duty_hint)
	military_role_button = Button.new(); military_role_button.custom_minimum_size = Vector2(0,44); military_role_button.text = "SEJA MILITAR"; military_role_button.pressed.connect(_toggle_military_role); vb.add_child(military_role_button)
	army_rifle_button = Button.new()
	army_rifle_button.text = "PEGAR AK-47"
	army_rifle_button.custom_minimum_size = Vector2(0, 44)
	army_rifle_button.pressed.connect(_take_army_rifle)
	vb.add_child(army_rifle_button)

func _create_army_hammer_panel(root: Control) -> void:
	army_hammer_panel = PanelContainer.new()
	army_hammer_panel.anchor_left = 0.5; army_hammer_panel.anchor_right = 0.5
	army_hammer_panel.anchor_top = 1.0; army_hammer_panel.anchor_bottom = 1.0
	army_hammer_panel.offset_left = -220; army_hammer_panel.offset_right = 220
	army_hammer_panel.offset_top = -255; army_hammer_panel.offset_bottom = -75
	army_hammer_panel.visible = false; army_hammer_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	army_hammer_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.20,0.48,0.16,0.95))); root.add_child(army_hammer_panel)
	var vb := VBoxContainer.new(); army_hammer_panel.add_child(vb)
	army_hammer_title = Label.new(); army_hammer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; army_hammer_title.add_theme_font_size_override("font_size",18); vb.add_child(army_hammer_title)
	army_hammer_hint = Label.new(); army_hammer_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; army_hammer_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; vb.add_child(army_hammer_hint)
	var actions := HBoxContainer.new(); vb.add_child(actions)
	army_hammer_button = Button.new(); army_hammer_button.text = "RETIRAR HAMMER"; army_hammer_button.custom_minimum_size = Vector2(0,42); army_hammer_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; army_hammer_button.pressed.connect(_request_army_hammer); actions.add_child(army_hammer_button)
	army_hammer_store_button = Button.new(); army_hammer_store_button.text = "GUARDAR"; army_hammer_store_button.custom_minimum_size = Vector2(0,42); army_hammer_store_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; army_hammer_store_button.pressed.connect(_store_army_hammer); actions.add_child(army_hammer_store_button)

func _create_army_truck_panel(root: Control) -> void:
	army_truck_panel = PanelContainer.new()
	army_truck_panel.anchor_left = 0.5; army_truck_panel.anchor_right = 0.5
	army_truck_panel.anchor_top = 1.0; army_truck_panel.anchor_bottom = 1.0
	army_truck_panel.offset_left = -220; army_truck_panel.offset_right = 220
	army_truck_panel.offset_top = -255; army_truck_panel.offset_bottom = -75
	army_truck_panel.visible = false; army_truck_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	army_truck_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.18,0.42,0.14,0.95))); root.add_child(army_truck_panel)
	var vb := VBoxContainer.new(); army_truck_panel.add_child(vb)
	army_truck_title = Label.new(); army_truck_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; army_truck_title.add_theme_font_size_override("font_size",18); vb.add_child(army_truck_title)
	army_truck_hint = Label.new(); army_truck_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; army_truck_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; vb.add_child(army_truck_hint)
	var actions := HBoxContainer.new(); vb.add_child(actions)
	army_truck_button = Button.new(); army_truck_button.text = "RETIRAR CAMINHÃO"; army_truck_button.custom_minimum_size = Vector2(0,42); army_truck_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; army_truck_button.pressed.connect(_request_army_truck); actions.add_child(army_truck_button)
	army_truck_store_button = Button.new(); army_truck_store_button.text = "GUARDAR"; army_truck_store_button.custom_minimum_size = Vector2(0,42); army_truck_store_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; army_truck_store_button.pressed.connect(_store_army_truck); actions.add_child(army_truck_store_button)

func _create_police_checkpoint_markers() -> void:
	police_duty_checkpoint_root = _make_checkpoint_marker("CheckpointServicoPolicial", POLICE_DUTY_CHECKPOINT, Color(0.10,0.34,1.0,1.0), "SERVIÇO POLICIAL")
	police_garage_checkpoint_root = _make_checkpoint_marker("CheckpointGaragemPolicial", POLICE_GARAGE_CHECKPOINT, Color(0.08,0.62,1.0,1.0), "RETIRAR VIATURA")
	police_armored_checkpoint_root = _make_checkpoint_marker("CheckpointGaragemBlindados", POLICE_ARMORED_CHECKPOINT, Color(0.10,0.35,0.92,1.0), "BLINDADOS")
	police_armory_checkpoint_root = _make_checkpoint_marker("CheckpointArsenalM16", POLICE_ARMORY_CHECKPOINT, Color(0.16,0.48,1.0,1.0), "PEGAR M16")

func _create_hospital_checkpoint_markers() -> void:
	hospital_duty_checkpoint_root = _make_checkpoint_marker("CheckpointServicoMedico", HOSPITAL_DUTY_CHECKPOINT, Color(1.0,0.76,0.08,1.0), "SEJA MÉDICO")
	hospital_ambulance_checkpoint_root = _make_checkpoint_marker("CheckpointAmbulanciaHospital", HOSPITAL_AMBULANCE_CHECKPOINT, Color(0.10,0.78,0.92,1.0), "AMBULÂNCIA")

func _create_army_checkpoint_markers() -> void:
	# Os checkpoints militares ficam exclusivamente dentro da base do Exército.
	# Não criar cópias globais: isso evita marcadores/spawns flutuando na rua.
	army_duty_checkpoint_root = null
	army_hammer_checkpoint_root = null
	army_truck_checkpoint_root = null

func _army_marker_loaded(group_name: StringName) -> bool:
	for item in get_tree().get_nodes_in_group(group_name):
		if item is Node3D and is_instance_valid(item):
			return true
	return false

func _project_point_to_ground(point: Vector3, excluded: Node = null) -> Vector3:
	var world := get_world_3d()
	if world == null:
		return point
	var from := point + Vector3.UP * 4.5
	var to := point + Vector3.DOWN * 8.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collision_mask = 1
	var excludes: Array[RID] = []
	if excluded != null and excluded is CollisionObject3D:
		excludes.append((excluded as CollisionObject3D).get_rid())
	query.exclude = excludes
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return point
	return hit["position"] as Vector3

func _toast(message: String, send_to_chat: bool = true) -> void:
	notice.text = message
	toast_time = 4.0
	if not send_to_chat:
		return
	var state: Node = get_node_or_null("/root/GameState")
	if state == null and is_instance_valid(player):
		state = player.get("game_state") as Node
	if is_instance_valid(state) and state.has_signal("game_notice"):
		state.emit_signal("game_notice","SISTEMA",message)

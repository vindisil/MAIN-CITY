import * as z from 'zod/v4';
import fs from 'node:fs/promises';
import path from 'node:path';
import net from 'node:net';
import { spawn, execFile } from 'node:child_process';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);
const BRIDGE_HOST = process.env.MAIN_CITY_BRIDGE_HOST || '127.0.0.1';
const BRIDGE_PORT = Number(process.env.MAIN_CITY_BRIDGE_PORT || 6010);
const MAX_BRIDGE_RESPONSE = 8 * 1024 * 1024;
const runningProcesses = new Map();

function textResult(text) {
  return { content: [{ type: 'text', text: String(text) }] };
}

function jsonResult(value) {
  return textResult(JSON.stringify(value, null, 2));
}

async function exists(full) {
  try {
    await fs.access(full);
    return true;
  } catch {
    return false;
  }
}

function makePathHelpers(projectRoot) {
  function insideRoot(candidate) {
    const relative = path.relative(projectRoot, candidate);
    return relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative));
  }

  function resolveProjectPath(relativePath = '.') {
    const candidate = path.resolve(projectRoot, relativePath);
    if (!insideRoot(candidate)) throw new Error('Caminho fora da pasta MAIN-CITY bloqueado.');
    return candidate;
  }

  function relative(candidate) {
    return path.relative(projectRoot, candidate).replaceAll('\\', '/');
  }

  return { resolveProjectPath, relative };
}

async function resolveExecutable(candidate) {
  if (!candidate) return null;
  if (candidate.includes('/') || candidate.includes('\\')) {
    const full = path.resolve(candidate);
    return (await exists(full)) ? full : null;
  }
  try {
    const checker = process.platform === 'win32' ? 'where.exe' : 'which';
    const { stdout } = await execFileAsync(checker, [candidate], { windowsHide: true });
    return stdout.split(/\r?\n/).map(line => line.trim()).find(Boolean) || null;
  } catch {
    return null;
  }
}

async function findGodot() {
  const candidates = [
    process.env.MAIN_CITY_GODOT,
    'godot',
    'godot4',
    'Godot_v4.6.2-stable_win64.exe',
    'Godot_v4.6.2-stable_mono_win64.exe'
  ];
  for (const candidate of candidates) {
    const resolved = await resolveExecutable(candidate);
    if (resolved) return resolved;
  }
  return null;
}

async function godotExec(projectRoot, args, timeoutSeconds = 120) {
  const exe = await findGodot();
  if (!exe) {
    throw new Error('Godot não encontrado. Coloque o Godot no PATH ou defina MAIN_CITY_GODOT com o caminho completo do executável 4.6.2.');
  }
  try {
    const { stdout, stderr } = await execFileAsync(exe, args, {
      cwd: projectRoot,
      windowsHide: true,
      maxBuffer: 16 * 1024 * 1024,
      timeout: Math.max(5, timeoutSeconds) * 1000
    });
    return { executable: exe, exit_code: 0, stdout: stdout.trim(), stderr: stderr.trim() };
  } catch (error) {
    return {
      executable: exe,
      exit_code: Number.isInteger(error.code) ? error.code : null,
      stdout: String(error.stdout || '').trim(),
      stderr: String(error.stderr || error.message || '').trim(),
      timed_out: Boolean(error.killed)
    };
  }
}

function bridgeRequest(payload, timeoutMs = 8000) {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host: BRIDGE_HOST, port: BRIDGE_PORT });
    let buffer = '';
    let settled = false;

    const finish = (fn, value) => {
      if (settled) return;
      settled = true;
      socket.destroy();
      fn(value);
    };

    socket.setTimeout(timeoutMs);
    socket.on('connect', () => socket.write(`${JSON.stringify(payload)}\n`));
    socket.on('data', chunk => {
      buffer += chunk.toString('utf8');
      if (buffer.length > MAX_BRIDGE_RESPONSE) {
        finish(reject, new Error('Resposta do Godot Bridge excedeu 8 MB.'));
        return;
      }
      const newline = buffer.indexOf('\n');
      if (newline < 0) return;
      const line = buffer.slice(0, newline).trim();
      try {
        const parsed = JSON.parse(line);
        if (parsed.ok === false) finish(reject, new Error(parsed.error || 'Godot Bridge retornou erro.'));
        else finish(resolve, parsed);
      } catch (error) {
        finish(reject, new Error(`Resposta inválida do Godot Bridge: ${error.message}`));
      }
    });
    socket.on('timeout', () => finish(reject, new Error('Timeout no Godot Bridge. Confirme que o plugin Main City MCP Bridge está ativo no editor.')));
    socket.on('error', error => finish(reject, new Error(`Godot Bridge indisponível em ${BRIDGE_HOST}:${BRIDGE_PORT}: ${error.message}`)));
  });
}

function safeName(value) {
  const result = value.normalize('NFKD').replace(/[^a-zA-Z0-9_-]+/g, '_').replace(/^_+|_+$/g, '');
  if (!result) throw new Error('Nome inválido.');
  return result.slice(0, 64);
}

function npcScriptTemplate(walkSpeed, runSpeed, detectionRange) {
  return `extends CharacterBody3D\n\nenum State { IDLE, WANDER, CHASE, FLEE }\n\n@export var walk_speed := ${walkSpeed}\n@export var run_speed := ${runSpeed}\n@export var detection_range := ${detectionRange}\n@export var wander_radius := 18.0\n@export var idle_min := 1.0\n@export var idle_max := 4.0\n\n@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D\nvar state: State = State.IDLE\nvar target: Node3D\nvar home_position := Vector3.ZERO\nvar idle_left := 0.0\n\nfunc _ready() -> void:\n\thome_position = global_position\n\tidle_left = randf_range(idle_min, idle_max)\n\nfunc _physics_process(delta: float) -> void:\n\t_target_nearby_player()\n\tmatch state:\n\t\tState.IDLE:\n\t\t\tvelocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)\n\t\t\tvelocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)\n\t\t\tidle_left -= delta\n\t\t\tif idle_left <= 0.0:\n\t\t\t\t_pick_wander_point()\n\t\tState.WANDER:\n\t\t\t_follow_navigation(walk_speed)\n\t\tState.CHASE:\n\t\t\tif is_instance_valid(target):\n\t\t\t\tnavigation_agent.target_position = target.global_position\n\t\t\t\t_follow_navigation(run_speed)\n\t\t\telse:\n\t\t\t\tstate = State.IDLE\n\tif not is_on_floor():\n\t\tvelocity.y -= 24.0 * delta\n\tmove_and_slide()\n\nfunc _target_nearby_player() -> void:\n\tvar players := get_tree().get_nodes_in_group("player")\n\tvar nearest: Node3D\n\tvar nearest_d := detection_range\n\tfor candidate in players:\n\t\tif candidate is Node3D:\n\t\t\tvar d := global_position.distance_to(candidate.global_position)\n\t\t\tif d < nearest_d:\n\t\t\t\tnearest = candidate\n\t\t\t\tnearest_d = d\n\tif nearest != null:\n\t\ttarget = nearest\n\t\tstate = State.CHASE\n\telif state == State.CHASE:\n\t\ttarget = null\n\t\tstate = State.IDLE\n\t\tidle_left = randf_range(idle_min, idle_max)\n\nfunc _pick_wander_point() -> void:\n\tvar angle := randf() * TAU\n\tvar distance := randf_range(4.0, wander_radius)\n\tnavigation_agent.target_position = home_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)\n\tstate = State.WANDER\n\nfunc _follow_navigation(speed: float) -> void:\n\tif navigation_agent.is_navigation_finished():\n\t\tstate = State.IDLE\n\t\tidle_left = randf_range(idle_min, idle_max)\n\t\treturn\n\tvar next := navigation_agent.get_next_path_position()\n\tvar dir := global_position.direction_to(next)\n\tdir.y = 0.0\n\tif dir.length_squared() > 0.001:\n\t\tdir = dir.normalized()\n\t\tvelocity.x = dir.x * speed\n\t\tvelocity.z = dir.z * speed\n\t\trotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 0.15)\n`;
}

function npcSceneTemplate(scriptPath, name) {
  return `[gd_scene load_steps=4 format=3]\n\n[ext_resource type="Script" path="res://${scriptPath}" id="1"]\n\n[sub_resource type="CapsuleShape3D" id="shape"]\nradius = 0.38\nheight = 1.8\n\n[sub_resource type="CapsuleMesh" id="mesh"]\nradius = 0.36\nheight = 1.8\n\n[node name="${name}" type="CharacterBody3D" groups=["npc"]]\nscript = ExtResource("1")\n\n[node name="CollisionShape3D" type="CollisionShape3D" parent="."]\nshape = SubResource("shape")\n\n[node name="Visual" type="MeshInstance3D" parent="."]\nmesh = SubResource("mesh")\n\n[node name="NavigationAgent3D" type="NavigationAgent3D" parent="."]\npath_height_offset = 0.9\npath_desired_distance = 0.4\ntarget_desired_distance = 0.8\navoidance_enabled = true\nradius = 0.45\nheight = 1.8\n`;
}

export function registerGodotControlTools(server, { projectRoot }) {
  const { resolveProjectPath, relative } = makePathHelpers(projectRoot);

  server.registerTool('godot_info', {
    description: 'Localiza o executável Godot e informa a versão.',
    inputSchema: z.object({})
  }, async () => {
    const exe = await findGodot();
    if (!exe) return jsonResult({ found: false, hint: 'Defina MAIN_CITY_GODOT com o caminho do Godot 4.6.2.' });
    const result = await godotExec(projectRoot, ['--version'], 15);
    return jsonResult({ found: true, ...result });
  });

  server.registerTool('godot_validate_project', {
    description: 'Abre o projeto em modo editor/headless e encerra para validar parser/importação.',
    inputSchema: z.object({ timeout_seconds: z.number().int().min(5).max(600).default(180) })
  }, async ({ timeout_seconds }) => jsonResult(await godotExec(projectRoot, ['--headless', '--editor', '--quit', '--path', projectRoot], timeout_seconds)));

  server.registerTool('godot_check_script', {
    description: 'Executa --check-only em um script GDScript.',
    inputSchema: z.object({ file: z.string().min(1), timeout_seconds: z.number().int().min(5).max(120).default(30) })
  }, async ({ file, timeout_seconds }) => {
    const full = resolveProjectPath(file);
    if (path.extname(full).toLowerCase() !== '.gd') throw new Error('Informe um arquivo .gd.');
    return jsonResult(await godotExec(projectRoot, ['--headless', '--path', projectRoot, '--script', full, '--check-only'], timeout_seconds));
  });

  server.registerTool('godot_start_project', {
    description: 'Inicia o projeto Godot em processo separado.',
    inputSchema: z.object({ scene: z.string().optional() })
  }, async ({ scene }) => {
    const exe = await findGodot();
    if (!exe) throw new Error('Godot não encontrado. Defina MAIN_CITY_GODOT.');
    const args = ['--path', projectRoot];
    if (scene) args.push(scene.startsWith('res://') ? scene : `res://${scene.replaceAll('\\', '/')}`);
    const child = spawn(exe, args, { cwd: projectRoot, windowsHide: false, stdio: 'ignore' });
    runningProcesses.set(child.pid, child);
    child.once('exit', () => runningProcesses.delete(child.pid));
    child.unref();
    return jsonResult({ started: true, pid: child.pid, scene: scene || '(main scene)', executable: exe });
  });

  server.registerTool('godot_stop_process', {
    description: 'Encerra um processo iniciado por godot_start_project nesta sessão.',
    inputSchema: z.object({ pid: z.number().int().positive() })
  }, async ({ pid }) => {
    const child = runningProcesses.get(pid);
    if (!child) throw new Error('PID não pertence a um processo iniciado por este MCP ou já terminou.');
    child.kill('SIGTERM');
    runningProcesses.delete(pid);
    return jsonResult({ stopped: true, pid });
  });

  server.registerTool('godot_bridge_ping', {
    description: 'Testa a ponte local com o editor Godot aberto.',
    inputSchema: z.object({})
  }, async () => jsonResult(await bridgeRequest({ command: 'ping' })));

  server.registerTool('godot_editor_info', {
    description: 'Retorna versão do Godot, cena editada e estado de execução.',
    inputSchema: z.object({})
  }, async () => jsonResult(await bridgeRequest({ command: 'editor_info' })));

  server.registerTool('godot_scene_tree', {
    description: 'Lê a árvore da cena atualmente aberta no editor.',
    inputSchema: z.object({ max_depth: z.number().int().min(0).max(20).default(8), max_nodes: z.number().int().min(1).max(5000).default(1000) })
  }, async ({ max_depth, max_nodes }) => jsonResult(await bridgeRequest({ command: 'scene_tree', max_depth, max_nodes }, 15000)));

  server.registerTool('godot_open_scene', {
    description: 'Abre uma cena res:// dentro do editor.',
    inputSchema: z.object({ scene: z.string().min(1) })
  }, async ({ scene }) => jsonResult(await bridgeRequest({ command: 'open_scene', scene })));

  server.registerTool('godot_save_scene', {
    description: 'Salva a cena atualmente editada.',
    inputSchema: z.object({})
  }, async () => jsonResult(await bridgeRequest({ command: 'save_scene' })));

  server.registerTool('godot_create_node', {
    description: 'Cria um Node por classe na cena aberta.',
    inputSchema: z.object({ parent: z.string().default('.'), class_name: z.string().min(1), name: z.string().min(1) })
  }, async args => jsonResult(await bridgeRequest({ command: 'create_node', ...args })));

  server.registerTool('godot_create_primitive', {
    description: 'Cria box/sphere/cylinder/plane 3D com material e Fisica/Colisao opcionais.',
    inputSchema: z.object({
      parent: z.string().default('.'),
      name: z.string().min(1),
      shape: z.enum(['box', 'sphere', 'cylinder', 'plane']),
      position: z.array(z.number()).length(3).default([0, 0, 0]),
      rotation_degrees: z.array(z.number()).length(3).default([0, 0, 0]),
      size: z.array(z.number()).length(3).default([1, 1, 1]),
      color: z.array(z.number()).min(3).max(4).default([0.8, 0.8, 0.8, 1]),
      roughness: z.number().min(0).max(1).default(0.8),
      metallic: z.number().min(0).max(1).default(0),
      collision: z.boolean().default(true)
    })
  }, async args => jsonResult(await bridgeRequest({ command: 'create_primitive', ...args }, 15000)));

  server.registerTool('godot_set_node_transform', {
    description: 'Altera posição, rotação e escala de um Node3D.',
    inputSchema: z.object({
      node: z.string().min(1),
      position: z.array(z.number()).length(3).optional(),
      rotation_degrees: z.array(z.number()).length(3).optional(),
      scale: z.array(z.number()).length(3).optional()
    })
  }, async args => jsonResult(await bridgeRequest({ command: 'set_transform', ...args })));

  server.registerTool('godot_set_node_property', {
    description: 'Altera propriedade de um nó. Vector3/Vector2/Color podem usar {_type, value}.',
    inputSchema: z.object({ node: z.string().min(1), property: z.string().min(1), value: z.any() })
  }, async args => jsonResult(await bridgeRequest({ command: 'set_property', ...args })));

  server.registerTool('godot_duplicate_node', {
    description: 'Duplica um nó e seus filhos na cena aberta.',
    inputSchema: z.object({ node: z.string().min(1), new_name: z.string().min(1) })
  }, async args => jsonResult(await bridgeRequest({ command: 'duplicate_node', ...args })));

  server.registerTool('godot_delete_node', {
    description: 'Remove um nó da cena aberta. Exige confirm=true.',
    inputSchema: z.object({ node: z.string().min(1), confirm: z.boolean() })
  }, async ({ node, confirm }) => {
    if (!confirm) throw new Error('Operação cancelada: confirm precisa ser true.');
    return jsonResult(await bridgeRequest({ command: 'delete_node', node }));
  });

  server.registerTool('godot_batch_operations', {
    description: 'Executa até 200 operações do Godot Bridge em lote. Útil para casas, muros, bases e cenários completos.',
    inputSchema: z.object({ operations: z.array(z.record(z.string(), z.any())).min(1).max(200) })
  }, async ({ operations }) => jsonResult(await bridgeRequest({ command: 'batch', operations }, 30000)));

  server.registerTool('godot_run_main_scene', {
    description: 'Executa a cena principal pelo editor Godot.',
    inputSchema: z.object({})
  }, async () => jsonResult(await bridgeRequest({ command: 'run_main' })));

  server.registerTool('godot_stop_running_scene', {
    description: 'Para a execução atual do projeto pelo editor.',
    inputSchema: z.object({})
  }, async () => jsonResult(await bridgeRequest({ command: 'stop_run' })));

  server.registerTool('create_npc_template', {
    description: 'Cria uma base NPC 3D com CharacterBody3D, NavigationAgent3D e estados IDLE/WANDER/CHASE. Depois pode receber modelo e AnimationTree humanos.',
    inputSchema: z.object({
      name: z.string().min(1),
      directory: z.string().default('scenes/npc'),
      walk_speed: z.number().min(0.1).max(20).default(2.4),
      run_speed: z.number().min(0.1).max(30).default(5.5),
      detection_range: z.number().min(1).max(200).default(15)
    })
  }, async ({ name, directory, walk_speed, run_speed, detection_range }) => {
    const safe = safeName(name);
    const dir = directory.replaceAll('\\', '/').replace(/^\/+|\/+$/g, '');
    const sceneRelative = `${dir}/${safe}.tscn`;
    const scriptRelative = `scripts/npc/${safe}.gd`;
    const sceneFull = resolveProjectPath(sceneRelative);
    const scriptFull = resolveProjectPath(scriptRelative);
    if (await exists(sceneFull) || await exists(scriptFull)) {
      throw new Error('Cena ou script do NPC já existe. Escolha outro nome ou edite o existente.');
    }
    await fs.mkdir(path.dirname(sceneFull), { recursive: true });
    await fs.mkdir(path.dirname(scriptFull), { recursive: true });
    await fs.writeFile(scriptFull, npcScriptTemplate(walk_speed, run_speed, detection_range), 'utf8');
    await fs.writeFile(sceneFull, npcSceneTemplate(scriptRelative, safe), 'utf8');
    return jsonResult({
      created: [relative(sceneFull), relative(scriptFull)],
      note: 'NPC funcional básico criado. Para movimento humano real, troque o CapsuleMesh pelo personagem e conecte AnimationTree/retarget.'
    });
  });
}

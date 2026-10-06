# -*- coding: utf-8 -*-
"""
MAIN CITY - unir 3 cidades Blender lado a lado, sem alterar escala/rotacao.

Uso (Blender 4/5):
  blender --background --python tools/merge_three_cities_blender.py -- \
    --city1 "source_cities/City 1.blend" \
    --city2 "source_cities/City 2(2).blend" \
    --city3 "source_cities/city cyles.zip" \
    --output "build/MAIN_CITY_3_CIDADES.blend" \
    --export-glb "build/MAIN_CITY_3_CIDADES.glb"

Regras do merge:
- CITY_1 fica exatamente na origem/autoria original.
- CITY_2 vai para a direita da CITY_1.
- CITY_3 vai para a direita da CITY_2.
- Nao muda escala nem rotacao dos mapas.
- Tenta alinhar automaticamente uma estrada de borda com a estrada de borda
  da proxima cidade usando apenas TRANSLACAO X/Y/Z.
- Se nao encontrar estrada pelos nomes, usa o bounding box como fallback.
- Cameras e luzes dos mapas importados sao ignoradas para evitar duplicacao.
- Cada cidade fica numa Collection propria: CITY_1, CITY_2, CITY_3.
"""

import argparse
import os
import sys
import tempfile
import zipfile
from mathutils import Vector
import bpy

ROAD_WORDS = (
    "road", "roads", "street", "streets", "rua", "ruas", "avenida", "avenue",
    "highway", "asphalt", "asfalto", "lane", "2lane", "4lane", "estrada",
    "pista", "roadway", "bridge", "ponte"
)


def _argv_after_double_dash():
    argv = sys.argv
    return argv[argv.index("--") + 1:] if "--" in argv else []


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--city1", required=True)
    parser.add_argument("--city2", required=True)
    parser.add_argument("--city3", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--export-glb", default="")
    parser.add_argument("--road-gap", type=float, default=0.20,
                        help="Pequena folga entre as bordas das estradas conectadas.")
    return parser.parse_args(_argv_after_double_dash())


def clean_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        if collection.users == 0:
            bpy.data.collections.remove(collection)


def resolve_blend(path, temp_dir, label):
    path = os.path.abspath(path)
    if path.lower().endswith(".blend"):
        if not os.path.isfile(path):
            raise FileNotFoundError(path)
        return path
    if path.lower().endswith(".zip"):
        if not os.path.isfile(path):
            raise FileNotFoundError(path)
        with zipfile.ZipFile(path, "r") as zf:
            blends = [n for n in zf.namelist() if n.lower().endswith(".blend") and not n.endswith("/")]
            if not blends:
                raise RuntimeError(f"{label}: ZIP nao contem arquivo .blend: {path}")
            # Prefere o maior .blend do ZIP, normalmente a cena completa.
            blends.sort(key=lambda n: zf.getinfo(n).file_size, reverse=True)
            chosen = blends[0]
            zf.extract(chosen, temp_dir)
            return os.path.join(temp_dir, chosen)
    raise RuntimeError(f"{label}: formato nao suportado: {path}")


def append_city(blend_path, collection_name):
    wrapper = bpy.data.collections.new(collection_name)
    bpy.context.scene.collection.children.link(wrapper)

    # Carrega todos os objetos da cena-fonte. Isso preserva hierarquias, meshes,
    # materiais e transformacoes autorais sem usar Link externo.
    with bpy.data.libraries.load(blend_path, link=False) as (data_from, data_to):
        data_to.objects = list(data_from.objects)

    loaded = []
    for obj in data_to.objects:
        if obj is None:
            continue
        if obj.type in {"CAMERA", "LIGHT"}:
            continue
        if len(obj.users_collection) == 0:
            wrapper.objects.link(obj)
        else:
            # Um objeto carregado pode vir ligado a uma collection de biblioteca;
            # garante tambem a visibilidade pela collection da cidade.
            if wrapper not in obj.users_collection:
                wrapper.objects.link(obj)
        loaded.append(obj)

    # Remove cameras/luzes que vieram como dependencias e ficaram sem uso desejado.
    for obj in list(data_to.objects):
        if obj is not None and obj.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(obj, do_unlink=True)

    root = bpy.data.objects.new(collection_name + "_ROOT", None)
    root.empty_display_type = "PLAIN_AXES"
    wrapper.objects.link(root)

    loaded_set = set(loaded)
    for obj in loaded:
        if obj.parent is None or obj.parent not in loaded_set:
            world = obj.matrix_world.copy()
            obj.parent = root
            obj.matrix_world = world

    return {"name": collection_name, "collection": wrapper, "root": root, "objects": loaded}


def object_world_bbox(obj):
    if obj.type not in {"MESH", "CURVE", "SURFACE", "FONT", "META"}:
        return None
    try:
        pts = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    except Exception:
        return None
    if not pts:
        return None
    mins = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    maxs = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mins, maxs


def city_bbox(city):
    boxes = [object_world_bbox(o) for o in city["objects"]]
    boxes = [b for b in boxes if b is not None]
    if not boxes:
        p = city["root"].matrix_world.translation.copy()
        return p.copy(), p.copy()
    mins = Vector((min(b[0].x for b in boxes), min(b[0].y for b in boxes), min(b[0].z for b in boxes)))
    maxs = Vector((max(b[1].x for b in boxes), max(b[1].y for b in boxes), max(b[1].z for b in boxes)))
    return mins, maxs


def road_candidates(city):
    result = []
    for obj in city["objects"]:
        name = obj.name.lower()
        if not any(word in name for word in ROAD_WORDS):
            continue
        box = object_world_bbox(obj)
        if box is None:
            continue
        mins, maxs = box
        size = maxs - mins
        # Descarta pecas minusculas que apenas contenham uma palavra de estrada.
        if max(size.x, size.y) < 2.0:
            continue
        result.append((obj, mins, maxs, (mins + maxs) * 0.5, size))
    return result


def choose_edge_road(city, side):
    """side='left' ou 'right'. Retorna estrada mais proxima da borda X da cidade."""
    cmin, cmax = city_bbox(city)
    roads = road_candidates(city)
    if not roads:
        return None
    edge_x = cmin.x if side == "left" else cmax.x

    def score(item):
        _, mins, maxs, center, size = item
        road_edge = mins.x if side == "left" else maxs.x
        edge_distance = abs(road_edge - edge_x)
        # Leve preferencia por estradas maiores; borda continua sendo prioridade.
        length_bonus = max(size.x, size.y) * 0.015
        return edge_distance - length_bonus

    roads.sort(key=score)
    return roads[0]


def translate_city(city, delta):
    city["root"].location += delta
    bpy.context.view_layer.update()


def align_next_city(left_city, right_city, gap=0.20):
    left_bbox = city_bbox(left_city)
    right_bbox = city_bbox(right_city)
    left_road = choose_edge_road(left_city, "right")
    right_road = choose_edge_road(right_city, "left")

    if left_road and right_road:
        _, lmin, lmax, lcenter, _ = left_road
        _, rmin, rmax, rcenter, _ = right_road
        # Encosta as bordas X das duas estradas e sincroniza centro Y e nivel Z.
        delta = Vector((
            (lmax.x + gap) - rmin.x,
            lcenter.y - rcenter.y,
            lcenter.z - rcenter.z,
        ))
        translate_city(right_city, delta)
        method = f"ROAD: {left_road[0].name} -> {right_road[0].name}"
    else:
        # Fallback seguro: cidades lado a lado, centros Y alinhados e base Z igual.
        lmin, lmax = left_bbox
        rmin, rmax = right_bbox
        delta = Vector((
            (lmax.x + gap) - rmin.x,
            ((lmin.y + lmax.y) * 0.5) - ((rmin.y + rmax.y) * 0.5),
            lmin.z - rmin.z,
        ))
        translate_city(right_city, delta)
        method = "BBOX fallback"

    return method, delta


def save_outputs(output_blend, export_glb=""):
    output_blend = os.path.abspath(output_blend)
    os.makedirs(os.path.dirname(output_blend), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=output_blend)

    if export_glb:
        export_glb = os.path.abspath(export_glb)
        os.makedirs(os.path.dirname(export_glb), exist_ok=True)
        bpy.ops.export_scene.gltf(
            filepath=export_glb,
            export_format="GLB",
            use_selection=False,
            export_cameras=False,
            export_lights=False,
        )


def main():
    args = parse_args()
    clean_scene()

    with tempfile.TemporaryDirectory(prefix="main_city_merge_") as temp_dir:
        city1_path = resolve_blend(args.city1, temp_dir, "CITY_1")
        city2_path = resolve_blend(args.city2, temp_dir, "CITY_2")
        city3_path = resolve_blend(args.city3, temp_dir, "CITY_3")

        city1 = append_city(city1_path, "CITY_1")
        city2 = append_city(city2_path, "CITY_2")
        city3 = append_city(city3_path, "CITY_3")
        bpy.context.view_layer.update()

        # CITY_1 nao e movida. CITY_2 e CITY_3 recebem apenas translacao.
        method12, delta12 = align_next_city(city1, city2, args.road_gap)
        method23, delta23 = align_next_city(city2, city3, args.road_gap)

        print("MAIN CITY MERGE")
        print("CITY_1 -> CITY_2:", method12, "delta", tuple(round(v, 4) for v in delta12))
        print("CITY_2 -> CITY_3:", method23, "delta", tuple(round(v, 4) for v in delta23))
        print("Escalas e rotacoes originais preservadas.")

        save_outputs(args.output, args.export_glb)
        print("Blend salvo em:", os.path.abspath(args.output))
        if args.export_glb:
            print("GLB salvo em:", os.path.abspath(args.export_glb))


if __name__ == "__main__":
    main()

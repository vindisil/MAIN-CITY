# -*- coding: utf-8 -*-
"""MAIN CITY - monta 3 cidades lado a lado para edicao manual posterior.

Regras:
- CITY_1 permanece exatamente onde veio do arquivo original.
- CITY_2 fica a direita da CITY_1.
- CITY_3 fica a direita da CITY_2.
- Escala e rotacao dos mapas nao sao alteradas.
- Z e alinhado pela base real da cidade, nunca por poste/lampada/placa.
- Estradas sao usadas somente para um ajuste Y seguro entre as bordas.
- Camera e luz dos mapas importados sao descartadas.
- Cada cidade fica em sua propria Collection e ROOT.
"""

import argparse
import os
import sys
import tempfile
import zipfile

import bpy
from mathutils import Vector

ROAD_TOKENS = (
    "road", "roads", "street", "streets", "rua", "ruas", "avenida", "avenue",
    "highway", "asphalt", "asfalto", "2lane", "4lane", "estrada", "pista",
    "roadway", "bridge", "ponte"
)
ROAD_EXCLUDES = (
    "lamp", "light", "pole", "sign", "signage", "traffic", "signal",
    "antenna", "tree", "guardrail", "barrier", "fence", "post"
)


def _argv_after_double_dash():
    argv = sys.argv
    return argv[argv.index("--") + 1:] if "--" in argv else []


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--city1", required=True)
    p.add_argument("--city2", required=True)
    p.add_argument("--city3", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--export-glb", default="")
    p.add_argument("--city-gap", type=float, default=12.0)
    p.add_argument("--road-gap", type=float, default=0.20)
    return p.parse_args(_argv_after_double_dash())


def clean_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for c in list(bpy.data.collections):
        if c.users == 0:
            bpy.data.collections.remove(c)


def resolve_blend(path, temp_dir, label):
    path = os.path.abspath(path)
    if path.lower().endswith(".blend"):
        if not os.path.isfile(path):
            raise FileNotFoundError(path)
        return path

    if path.lower().endswith(".zip"):
        if not os.path.isfile(path):
            raise FileNotFoundError(path)
        dest = os.path.join(temp_dir, label)
        os.makedirs(dest, exist_ok=True)
        with zipfile.ZipFile(path, "r") as zf:
            blends = [n for n in zf.namelist() if n.lower().endswith(".blend") and not n.endswith("/")]
            if not blends:
                raise RuntimeError(f"{label}: ZIP nao contem .blend: {path}")
            blends.sort(key=lambda n: zf.getinfo(n).file_size, reverse=True)
            chosen = blends[0]
            # Extrai o ZIP inteiro para preservar texturas/arquivos relativos da City 3.
            zf.extractall(dest)
            return os.path.join(dest, chosen)

    raise RuntimeError(f"{label}: formato nao suportado: {path}")


def append_city(blend_path, collection_name):
    wrapper = bpy.data.collections.new(collection_name)
    bpy.context.scene.collection.children.link(wrapper)

    with bpy.data.libraries.load(blend_path, link=False) as (data_from, data_to):
        data_to.objects = list(data_from.objects)

    loaded = []
    for obj in data_to.objects:
        if obj is None:
            continue
        if obj.type in {"CAMERA", "LIGHT"}:
            continue
        if wrapper not in obj.users_collection:
            wrapper.objects.link(obj)
        loaded.append(obj)

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

    bpy.context.view_layer.update()
    return {"name": collection_name, "collection": wrapper, "root": root, "objects": loaded}


def object_world_bbox(obj):
    if obj.type != "MESH":
        return None
    try:
        pts = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    except Exception:
        return None
    if not pts:
        return None
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx


def city_bbox(city):
    boxes = [object_world_bbox(o) for o in city["objects"]]
    boxes = [b for b in boxes if b is not None]
    if not boxes:
        p = city["root"].matrix_world.translation.copy()
        return p.copy(), p.copy()
    mn = Vector((min(b[0].x for b in boxes), min(b[0].y for b in boxes), min(b[0].z for b in boxes)))
    mx = Vector((max(b[1].x for b in boxes), max(b[1].y for b in boxes), max(b[1].z for b in boxes)))
    return mn, mx


def road_candidates(city):
    cmin, cmax = city_bbox(city)
    city_x = max(cmax.x - cmin.x, 1.0)
    city_y = max(cmax.y - cmin.y, 1.0)
    result = []

    for obj in city["objects"]:
        if obj.type != "MESH":
            continue
        name = obj.name.lower()
        if any(bad in name for bad in ROAD_EXCLUDES):
            continue
        if not any(token in name for token in ROAD_TOKENS):
            continue

        box = object_world_bbox(obj)
        if box is None:
            continue
        mn, mx = box
        size = mx - mn
        footprint_long = max(size.x, size.y)
        footprint_short = min(size.x, size.y)
        z_size = max(size.z, 0.0)

        # Uma estrada precisa ter uma superficie relevante. Isso elimina postes,
        # placas e pequenos props mesmo quando seus nomes contem "street/highway".
        if footprint_long < max(8.0, min(city_x, city_y) * 0.015):
            continue
        if footprint_short < 1.5:
            continue
        if z_size > footprint_long * 0.45:
            continue

        center = (mn + mx) * 0.5
        area = max(size.x * size.y, 0.01)
        result.append({"obj": obj, "min": mn, "max": mx, "center": center, "size": size, "area": area})

    return result


def edge_roads(city, side):
    cmin, cmax = city_bbox(city)
    span_x = max(cmax.x - cmin.x, 1.0)
    edge = cmin.x if side == "left" else cmax.x
    tolerance = max(25.0, span_x * 0.18)
    candidates = []

    for r in road_candidates(city):
        road_edge = r["min"].x if side == "left" else r["max"].x
        dist = abs(road_edge - edge)
        if dist <= tolerance:
            candidates.append((dist, -r["area"], r))

    candidates.sort(key=lambda item: (item[0], item[1]))
    return [item[2] for item in candidates[:12]]


def translate_city(city, delta):
    city["root"].location += delta
    bpy.context.view_layer.update()


def place_side_by_side(left_city, right_city, city_gap):
    """Posicionamento deterministico. Nao depende de nomes de estrada."""
    lmin, lmax = city_bbox(left_city)
    rmin, rmax = city_bbox(right_city)

    # 1) Encosta a proxima cidade a direita.
    # 2) Alinha o centro Y das duas cidades.
    # 3) Alinha o piso/base Z, nunca o centro Z de uma estrada.
    delta = Vector((
        (lmax.x + city_gap) - rmin.x,
        ((lmin.y + lmax.y) * 0.5) - ((rmin.y + rmax.y) * 0.5),
        lmin.z - rmin.z,
    ))
    translate_city(right_city, delta)
    return delta


def safe_road_y_sync(left_city, right_city):
    """Ajusta somente Y, escolhendo o par de estradas de borda mais proximo.

    Nunca altera X/Z e nunca permite um salto grande que desalinhe as cidades.
    """
    left = edge_roads(left_city, "right")
    right = edge_roads(right_city, "left")
    if not left or not right:
        return "CENTER/BBOX (sem estrada confiavel)", 0.0

    lmin, lmax = city_bbox(left_city)
    rmin, rmax = city_bbox(right_city)
    y_span = max(lmax.y - lmin.y, rmax.y - rmin.y, 1.0)
    max_adjust = max(30.0, y_span * 0.18)

    best = None
    for lr in left:
        for rr in right:
            dy = lr["center"].y - rr["center"].y
            score = abs(dy) - min(lr["area"], rr["area"]) * 0.0005
            if best is None or score < best[0]:
                best = (score, dy, lr, rr)

    _, dy, lr, rr = best
    if abs(dy) > max_adjust:
        return f"CENTER/BBOX (road rejeitada: {lr['obj'].name} -> {rr['obj'].name}, dy={dy:.2f})", 0.0

    translate_city(right_city, Vector((0.0, dy, 0.0)))
    return f"ROAD_Y: {lr['obj'].name} -> {rr['obj'].name}", dy


def bbox_text(city):
    mn, mx = city_bbox(city)
    return (
        f"min=({mn.x:.2f},{mn.y:.2f},{mn.z:.2f}) "
        f"max=({mx.x:.2f},{mx.y:.2f},{mx.z:.2f}) "
        f"size=({mx.x-mn.x:.2f},{mx.y-mn.y:.2f},{mx.z-mn.z:.2f})"
    )


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
            export_draco_mesh_compression_enable=False,
        )


def main():
    args = parse_args()
    clean_scene()

    with tempfile.TemporaryDirectory(prefix="main_city_merge_") as temp_dir:
        c1_path = resolve_blend(args.city1, temp_dir, "CITY_1")
        c2_path = resolve_blend(args.city2, temp_dir, "CITY_2")
        c3_path = resolve_blend(args.city3, temp_dir, "CITY_3")

        city1 = append_city(c1_path, "CITY_1")
        city2 = append_city(c2_path, "CITY_2")
        city3 = append_city(c3_path, "CITY_3")
        bpy.context.view_layer.update()

        print("MAIN CITY MERGE - BOUNDS ORIGINAIS")
        print("CITY_1", bbox_text(city1))
        print("CITY_2", bbox_text(city2))
        print("CITY_3", bbox_text(city3))

        d12 = place_side_by_side(city1, city2, args.city_gap)
        method12, road_dy12 = safe_road_y_sync(city1, city2)

        d23 = place_side_by_side(city2, city3, args.city_gap)
        method23, road_dy23 = safe_road_y_sync(city2, city3)

        print("MAIN CITY MERGE - POSICIONAMENTO")
        print("CITY_1 -> CITY_2 base delta:", tuple(round(v, 4) for v in d12), method12, "road_dy", round(road_dy12, 4))
        print("CITY_2 -> CITY_3 base delta:", tuple(round(v, 4) for v in d23), method23, "road_dy", round(road_dy23, 4))
        print("MAIN CITY MERGE - BOUNDS FINAIS")
        print("CITY_1", bbox_text(city1))
        print("CITY_2", bbox_text(city2))
        print("CITY_3", bbox_text(city3))
        print("Escalas e rotacoes originais preservadas; somente translacao aplicada.")

        save_outputs(args.output, args.export_glb)

        if not os.path.isfile(args.output) or os.path.getsize(args.output) <= 0:
            raise RuntimeError("BLEND final nao foi criado corretamente")
        if args.export_glb and (not os.path.isfile(args.export_glb) or os.path.getsize(args.export_glb) <= 0):
            raise RuntimeError("GLB final nao foi criado corretamente")

        print("BLEND_OK", os.path.abspath(args.output), os.path.getsize(args.output))
        if args.export_glb:
            print("GLB_OK", os.path.abspath(args.export_glb), os.path.getsize(args.export_glb))


if __name__ == "__main__":
    main()

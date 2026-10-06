# -*- coding: utf-8 -*-
"""Diagnostica materiais/texturas de um .blend ou ZIP com .blend sem alterar o mapa."""
import argparse
import os
import sys
import tempfile
import zipfile
import bpy


def argv_after_dashdash():
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def args():
    p = argparse.ArgumentParser()
    p.add_argument("--source", required=True)
    p.add_argument("--label", required=True)
    return p.parse_args(argv_after_dashdash())


def resolve(source, temp_dir):
    source = os.path.abspath(source)
    if source.lower().endswith(".blend"):
        return source
    if source.lower().endswith(".zip"):
        with zipfile.ZipFile(source, "r") as zf:
            blends = [n for n in zf.namelist() if n.lower().endswith(".blend") and not n.endswith("/")]
            if not blends:
                raise RuntimeError("ZIP sem .blend")
            blends.sort(key=lambda n: zf.getinfo(n).file_size, reverse=True)
            zf.extractall(temp_dir)
            return os.path.join(temp_dir, blends[0])
    raise RuntimeError("Formato nao suportado")


def walk_nodes(node_tree, seen=None):
    if node_tree is None:
        return []
    if seen is None:
        seen = set()
    ptr = node_tree.as_pointer()
    if ptr in seen:
        return []
    seen.add(ptr)
    nodes = []
    for n in node_tree.nodes:
        nodes.append(n)
        if n.type == "GROUP" and getattr(n, "node_tree", None) is not None:
            nodes.extend(walk_nodes(n.node_tree, seen))
    return nodes


def main():
    a = args()
    with tempfile.TemporaryDirectory(prefix="main_city_diag_") as td:
        path = resolve(a.source, td)
        with bpy.data.libraries.load(path, link=False) as (src, dst):
            dst.materials = list(src.materials)
            dst.images = list(src.images)
            dst.textures = list(src.textures)

        materials = [m for m in dst.materials if m is not None]
        images = [im for im in dst.images if im is not None]
        textures = [t for t in dst.textures if t is not None]
        tex_nodes = []
        group_nodes = 0
        principled = 0
        mats_with_tex = 0
        mats_without_nodes = 0

        for m in materials:
            if not m.use_nodes or m.node_tree is None:
                mats_without_nodes += 1
                continue
            nodes = walk_nodes(m.node_tree)
            local_tex = [n for n in nodes if n.type == "TEX_IMAGE"]
            if local_tex:
                mats_with_tex += 1
                tex_nodes.extend((m, n) for n in local_tex)
            group_nodes += sum(1 for n in nodes if n.type == "GROUP")
            principled += sum(1 for n in nodes if n.type == "BSDF_PRINCIPLED")

        with_image = [(m, n) for m, n in tex_nodes if getattr(n, "image", None) is not None]
        without_image = [(m, n) for m, n in tex_nodes if getattr(n, "image", None) is None]

        print("CITY_MATERIAL_DIAG", a.label)
        print("SOURCE_BLEND", path)
        print("MATERIAL_COUNT", len(materials))
        print("SOURCE_IMAGE_DATABLOCKS", len(images))
        print("SOURCE_TEXTURE_DATABLOCKS", len(textures))
        print("MATERIALS_WITH_TEX_IMAGE", mats_with_tex)
        print("TEX_IMAGE_NODES", len(tex_nodes))
        print("TEX_IMAGE_WITH_IMAGE", len(with_image))
        print("TEX_IMAGE_WITHOUT_IMAGE", len(without_image))
        print("GROUP_NODES", group_nodes)
        print("PRINCIPLED_NODES", principled)
        print("MATERIALS_WITHOUT_NODES", mats_without_nodes)

        for im in images[:300]:
            print("IMAGE_DB", im.name, "|", im.filepath, "|", im.filepath_raw, "|", im.source)

        for tex in textures[:300]:
            image = getattr(tex, "image", None)
            print("LEGACY_TEXTURE", tex.name, "|", getattr(tex, "type", ""), "|", image.name if image else "NO_IMAGE", "|", image.filepath if image else "")

        for m, n in with_image[:120]:
            im = n.image
            print("MAT_TEX", m.name, "|", n.name, "|", im.name, "|", im.filepath)
        for m, n in without_image[:120]:
            print("MAT_TEX_MISSING_IMAGE", m.name, "|", n.name)
        for m in materials[:300]:
            print("MAT_DB", m.name, "| diffuse", tuple(round(v, 4) for v in m.diffuse_color))
            if not m.use_nodes or m.node_tree is None:
                print("MAT_NO_NODES", m.name)
            elif not any(n.type == "TEX_IMAGE" for n in walk_nodes(m.node_tree)):
                print("MAT_NO_IMAGE_NODE", m.name)


if __name__ == "__main__":
    main()

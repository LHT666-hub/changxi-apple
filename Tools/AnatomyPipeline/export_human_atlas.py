"""Export aligned, region-scoped anatomy assets from Human-Atlas/BodyParts3D.

Run with Blender in background mode, for example:
  CHANGXI_ATLAS_DIR=/path/to/Human-Atlas/public/models \
  CHANGXI_ANATOMY_OUT=/tmp/changxi-anatomy \
  blender --background --factory-startup --python export_human_atlas.py

The packed source contains one shared coordinate system for skin, muscles, and
bones. We crop all three layers with the same medical region volume, combine
each layer for mobile rendering, then export one USD file per region.
"""

from __future__ import annotations

import bpy
import json
import os
import struct
from pathlib import Path


ATLAS_DIR = Path(os.environ["CHANGXI_ATLAS_DIR"])
OUTPUT_DIR = Path(os.environ.get("CHANGXI_ANATOMY_OUT", "/tmp/changxi-anatomy"))
MANIFEST = json.loads((ATLAS_DIR / "atlas.json").read_text())
PARTS = MANIFEST["parts"]
CHUNKS = [ATLAS_DIR / Path(chunk["url"]).name for chunk in MANIFEST["chunks"]]

SYSTEMS = {"surface": "integumentary", "muscle": "muscular", "skeleton": "skeletal"}
COLORS = {
    "surface": (0.41, 0.59, 0.67, 1.0),
    "muscle": (0.66, 0.26, 0.22, 1.0),
    "skeleton": (0.86, 0.82, 0.70, 1.0),
}
TRIANGLE_BUDGETS = {"surface": 32_000, "muscle": 55_000, "skeleton": 55_000}


def inside(region: str, x: float, y: float, z: float) -> bool:
    """Shared Y-up clipping volume for every anatomy layer."""
    horizontal = abs(x)
    if region == "head":
        # Preserve the jaw and a short neck reference, without pulling the
        # shoulder girdle into a head-focused view.
        return y >= 1.42 and horizontal < (0.13 if y < 1.49 else 0.22)
    if region == "neck":
        return 1.23 <= y < 1.48 and horizontal < 0.24
    if region in {"torso", "back"}:
        return 0.82 <= y < 1.43 and horizontal < 0.27
    if region == "arms":
        return 0.62 <= y < 1.45 and horizontal >= 0.16
    # Separate left and right lower limbs and omit the central pelvic surface.
    return y < 0.91 and horizontal >= 0.045


def part_data(part: dict) -> tuple[list[tuple[float, float, float]], tuple[int, ...]]:
    blob = CHUNKS[part["chunk"]].read_bytes()
    vertices = list(struct.iter_unpack("<fff", blob[part["positions"]:part["positions"] + part["vertexCount"] * 12]))
    indices = struct.unpack_from(f'<{part["indexCount"]}I', blob, part["indices"])
    return vertices, indices


def layer_geometry(region: str, layer: str) -> tuple[list[tuple[float, float, float]], list[tuple[int, int, int]], int]:
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, int, int]] = []
    source_triangles = 0
    for part in PARTS:
        if part["system"] != SYSTEMS[layer]:
            continue
        if layer == "surface" and part["name"].lower() != "skin":
            continue
        source_vertices, indices = part_data(part)
        source_triangles += len(indices) // 3
        used: set[int] = set()
        chosen: list[tuple[int, int, int]] = []
        for offset in range(0, len(indices), 3):
            triangle = indices[offset:offset + 3]
            center = tuple(sum(source_vertices[index][axis] for index in triangle) / 3 for axis in range(3))
            if inside(region, *center):
                chosen.append(triangle)
                used.update(triangle)
        if not chosen:
            continue
        ordered = sorted(used)
        remap = {old: len(vertices) + new for new, old in enumerate(ordered)}
        # Human-Atlas is Y-up; Blender/USD authoring is Z-up.
        vertices.extend((source_vertices[index][0], source_vertices[index][2], source_vertices[index][1]) for index in ordered)
        faces.extend(tuple(remap[index] for index in triangle) for triangle in chosen)
    return vertices, faces, source_triangles


def make_material(layer: str):
    value = bpy.data.materials.new(f"cx_{layer}")
    value.diffuse_color = COLORS[layer]
    value.metallic = 0.0
    value.roughness = 0.74
    return value


def export_region(region: str) -> dict:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    exported = {}
    for layer in SYSTEMS:
        vertices, faces, source_triangles = layer_geometry(region, layer)
        if not faces:
            raise RuntimeError(f"{region}/{layer} contains no triangles")
        mesh = bpy.data.meshes.new(f"CX_{region}_{layer}_mesh")
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        for polygon in mesh.polygons:
            polygon.use_smooth = True
        obj = bpy.data.objects.new(f"{layer}__{region}", mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.data.materials.append(make_material(layer))
        estimated_triangles = len(faces)
        if layer == "surface":
            subdivision = obj.modifiers.new(name="CX_Medical_Surface_Smoothing", type="SUBSURF")
            subdivision.subdivision_type = "CATMULL_CLARK"
            subdivision.levels = 1
            subdivision.render_levels = 1
            estimated_triangles *= 4
        if estimated_triangles > TRIANGLE_BUDGETS[layer]:
            modifier = obj.modifiers.new(name="CX_Mobile_Decimate", type="DECIMATE")
            modifier.ratio = TRIANGLE_BUDGETS[layer] / estimated_triangles
        # SceneKit does not reliably evaluate USD subdivision schemes. Bake the
        # modifiers here so the iOS asset contains the smoothed mobile mesh.
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
        obj.select_set(True)
        exported[layer] = {
            "vertices_before_decimation": len(vertices),
            "triangles_before_decimation": len(faces),
            "source_layer_triangles": source_triangles,
        }
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.usd_export(
        filepath=str(OUTPUT_DIR / f"{region}.usdc"),
        selected_objects_only=True,
        # The app applies accessible medical materials at runtime. Omitting
        # Blender materials also prevents an unnecessary external EXR world
        # texture from leaking into otherwise self-contained USD assets.
        export_materials=False,
        convert_world_material=False,
        export_lights=False,
        export_cameras=False,
        evaluation_mode="RENDER",
    )
    return exported


inventory = {}
for region in ("head", "neck", "torso", "back", "arms", "legs"):
    inventory[region] = export_region(region)
print("CHANGXI_HUMAN_ATLAS_EXPORT=" + json.dumps(inventory, ensure_ascii=False))

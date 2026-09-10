"""Build lightweight, region-scoped USD anatomy assets for ChangXi.

The script intersects Z-Anatomy's system collections with its body-part
collections, so a file never contains the whole body disguised by camera zoom.

Environment:
  CHANGXI_ANATOMY_OUT  Output directory. Defaults to /tmp/changxi-anatomy.
  CHANGXI_EXPORT       Set to 1 to export; otherwise print an inventory only.
"""

from __future__ import annotations

import bpy
import json
import os
from pathlib import Path


SYSTEMS = {
    "muscle": "4: Muscular system",
    "skeleton": "1: Skeletal system",
}

REGIONS = {
    "head": ["Head"],
    "neck": ["Neck"],
    "torso": ["Trunk"],
    # Back uses trunk surface regions, but deeper layers are overridden below.
    "back": ["Trunk"],
    "arms": ["Left upper limb", "Right upper limb", "Left hand", "Right hand"],
    "legs": ["Left lower limb", "Right lower limb", "Left foot", "Right foot"],
}

MUSCLE_KEYWORDS = {
    "head": ("frontal", "occipital", "temporalis", "masseter", "bucinator", "orbicularis", "zygomatic", "nasalis"),
    "neck": ("sternocleidomastoid", "trapezius", "scalene", "levator scapulae", "splenius"),
    "torso": ("pectoralis", "rectus abdominis", "external abdominal oblique", "serratus anterior", "latissimus", "trapezius"),
    "back": ("trapezius", "latissimus", "longissimus", "iliocostalis", "spinalis", "multifidus", "gluteus maximus"),
    "arms": ("deltoid", "biceps", "triceps", "brachialis", "brachioradialis", "flexor", "extensor", "pronator", "supinator"),
    "legs": ("gluteus", "rectus femoris", "vastus", "sartorius", "adductor", "biceps femoris", "semitendinosus", "semimembranosus", "gastrocnemius", "soleus", "tibialis", "fibularis"),
}

TRIANGLE_BUDGETS = {"surface": 18000, "muscle": 28000, "skeleton": 28000}

COLORS = {
    "surface": (0.33, 0.53, 0.68, 1.0),
    "muscle": (0.64, 0.22, 0.20, 1.0),
    "skeleton": (0.82, 0.79, 0.67, 1.0),
}

SURFACE_JSON = Path(os.environ.get(
    "CHANGXI_SURFACE_JSON",
    Path(__file__).resolve().parents[2] / "ChangXi/Resources/PainModels/pain-body-v1.json",
))


def objects_under(collection: bpy.types.Collection) -> set[bpy.types.Object]:
    result = set(collection.objects)
    for child in collection.children:
        result |= objects_under(child)
    return result


def anatomy_mesh(obj: bpy.types.Object) -> bool:
    """Exclude hierarchy glyphs and text-like helper meshes from the atlas."""
    if obj.type != "MESH" or len(obj.data.polygons) == 0:
        return False
    return not obj.name.endswith((".g", ".j", ".i"))


def source_sets() -> tuple[dict[str, set], dict[str, set]]:
    systems = {}
    for layer, name in SYSTEMS.items():
        collection = bpy.data.collections.get(name)
        if collection is None:
            raise RuntimeError(f"Missing Z-Anatomy system collection: {name}")
        systems[layer] = {obj for obj in objects_under(collection) if anatomy_mesh(obj)}

    regions = {}
    for region, names in REGIONS.items():
        objects = set()
        for name in names:
            collection = bpy.data.collections.get(name)
            if collection is None:
                raise RuntimeError(f"Missing Z-Anatomy region collection: {name}")
            objects |= objects_under(collection)
        regions[region] = {obj for obj in objects if anatomy_mesh(obj)}
    return systems, regions


def material(name: str, color: tuple[float, float, float, float]):
    value = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    value.diffuse_color = color
    value.metallic = 0.0
    value.roughness = 0.72
    return value


def includes_surface_point(region: str, x: float, y: float, z: float) -> bool:
    horizontal = abs(x)
    if region == "head":
        return y >= 1.67
    if region == "neck":
        return 1.43 <= y < 1.73 and horizontal < 0.39
    if region in {"torso", "back"}:
        return 0.84 <= y < 1.57 and horizontal < 0.34
    if region == "arms":
        return 0.72 <= y < 1.56 and horizontal >= 0.20
    return y < 1.06


def surface_shell(region: str) -> bpy.types.Object:
    """Create a calm, continuous outer shell instead of atlas region tiles."""
    source = json.loads(SURFACE_JSON.read_text())
    vertices = source["vertices"]
    indices = source["indices"]
    selected_faces = []
    used = set()
    for offset in range(0, len(indices), 3):
        face = indices[offset:offset + 3]
        center = [sum(vertices[index][axis] for index in face) / 3 for axis in range(3)]
        if includes_surface_point(region, *center):
            selected_faces.append(face)
            used.update(face)

    ordered = sorted(used)
    remap = {old: new for new, old in enumerate(ordered)}
    # Source is Y-up; Blender and the atlas are Z-up.
    shell_vertices = [(vertices[index][0], vertices[index][2], vertices[index][1]) for index in ordered]
    shell_faces = [[remap[index] for index in face] for face in selected_faces]
    mesh = bpy.data.meshes.new(f"CX_{region}_surface_mesh")
    mesh.from_pydata(shell_vertices, [], shell_faces)
    mesh.update()
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    shell = bpy.data.objects.new(f"surface__{region}_outer_shell", mesh)
    bpy.context.scene.collection.objects.link(shell)
    bevel = shell.modifiers.new(name="CX_Soft_Edge", type="BEVEL")
    bevel.width = 0.0015
    bevel.segments = 2
    return shell


def export_region(region: str, layers: dict[str, list[bpy.types.Object]], output: Path):
    layers = dict(layers)
    generated_surface = surface_shell(region)
    layers["surface"] = [generated_surface]
    originals = []
    for obj in bpy.context.selected_objects:
        obj.select_set(False)

    for layer, objects in layers.items():
        layer_material = material(f"cx_{layer}", COLORS[layer])
        total_faces = sum(len(obj.data.polygons) for obj in objects)
        ratio = min(1.0, TRIANGLE_BUDGETS[layer] / max(1, total_faces))
        for obj in objects:
            modifier = None
            if ratio < 0.98 and len(obj.data.polygons) >= 40:
                modifier = obj.modifiers.new(name="CX_Mobile_Decimate", type="DECIMATE")
                modifier.ratio = max(0.08, ratio)
            originals.append((obj, obj.name, list(obj.data.materials), obj.hide_viewport, obj.hide_render, modifier))
            obj.name = f"{layer}__{obj.name}"
            obj.data.materials.clear()
            obj.data.materials.append(layer_material)
            obj.hide_viewport = False
            obj.hide_render = False
            obj.hide_set(False)
            obj.select_set(True)

    output.mkdir(parents=True, exist_ok=True)
    target = output / f"{region}.usdc"
    bpy.ops.wm.usd_export(
        filepath=str(target),
        selected_objects_only=True,
        export_materials=True,
        relative_paths=True,
        evaluation_mode="RENDER",
    )

    for obj, name, materials, hidden_view, hidden_render, modifier in originals:
        obj.name = name
        obj.data.materials.clear()
        for item in materials:
            obj.data.materials.append(item)
        obj.hide_viewport = hidden_view
        obj.hide_render = hidden_render
        obj.select_set(False)
        if modifier is not None:
            obj.modifiers.remove(modifier)
    mesh = generated_surface.data
    bpy.data.objects.remove(generated_surface, do_unlink=True)
    bpy.data.meshes.remove(mesh)


systems, regions = source_sets()
back_collection = bpy.data.collections.get("Back")
back_objects = {obj for obj in objects_under(back_collection) if anatomy_mesh(obj)} if back_collection else set()
inventory = {}
selected_by_region = {}
for region, region_objects in regions.items():
    selected_by_region[region] = {}
    inventory[region] = {}
    for layer, system_objects in systems.items():
        scoped_region = back_objects if region == "back" and layer != "surface" else region_objects
        objects = scoped_region & system_objects
        if layer == "muscle":
            keywords = MUSCLE_KEYWORDS[region]
            objects = {obj for obj in objects if any(word in obj.name.lower() for word in keywords)}
        objects = sorted(objects, key=lambda obj: obj.name)
        selected_by_region[region][layer] = objects
        inventory[region][layer] = {
            "objects": len(objects),
            "faces_before_decimation": sum(len(obj.data.polygons) for obj in objects),
            "examples": [obj.name for obj in objects[:8]],
        }
    inventory[region]["surface"] = {"source": str(SURFACE_JSON), "kind": "continuous outer shell"}

print("CHANGXI_ANATOMY_INVENTORY=" + json.dumps(inventory, ensure_ascii=False))
if os.environ.get("CHANGXI_EXPORT") == "1":
    destination = Path(os.environ.get("CHANGXI_ANATOMY_OUT", "/tmp/changxi-anatomy"))
    for region, layers in selected_by_region.items():
        export_region(region, layers, destination)
    print(f"CHANGXI_ANATOMY_OUTPUT={destination}")

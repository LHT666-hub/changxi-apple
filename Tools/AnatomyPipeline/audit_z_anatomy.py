"""Audit candidate outer-surface meshes and atlas scale in Z-Anatomy.

Run with Blender in background mode. This intentionally does not modify or
export the source scene; it is a diagnostic companion to export_z_anatomy.py.
"""

import bpy
import json


SURFACE_TERMS = (
    "skin", "cutaneous", "integument", "body surface", "external surface",
    "region", "eyelid", "external nose", "auricle", "lip",
)


def world_bounds(objects):
    points = []
    for obj in objects:
        if obj.type != "MESH" or not obj.bound_box:
            continue
        points.extend(obj.matrix_world @ __import__("mathutils").Vector(corner) for corner in obj.bound_box)
    if not points:
        return None
    return {
        "min": [min(point[axis] for point in points) for axis in range(3)],
        "max": [max(point[axis] for point in points) for axis in range(3)],
    }


candidates = [
    obj for obj in bpy.data.objects
    if obj.type == "MESH" and any(term in obj.name.lower() for term in SURFACE_TERMS)
]
print("CHANGXI_SURFACE_CANDIDATES=" + json.dumps({
    "count": len(candidates),
    "names": [obj.name for obj in candidates[:250]],
    "bounds": world_bounds(candidates),
}, ensure_ascii=False))

for collection_name in ("Head", "Neck", "Trunk", "Left upper limb", "Right upper limb"):
    collection = bpy.data.collections.get(collection_name)
    if collection:
        meshes = [obj for obj in collection.all_objects if obj.type == "MESH" and len(obj.data.polygons)]
        print("CHANGXI_REGION_BOUNDS=" + json.dumps({
            "collection": collection_name,
            "meshes": len(meshes),
            "bounds": world_bounds(meshes),
        }, ensure_ascii=False))

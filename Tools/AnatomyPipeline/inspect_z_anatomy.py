"""Print a compact inventory of a Z-Anatomy Blender scene.

Run with:
  blender --background Startup.blend --python inspect_z_anatomy.py
"""

import bpy
import json


def walk(collection, depth=0):
    meshes = [obj for obj in collection.objects if obj.type == "MESH"]
    if meshes:
        print(json.dumps({
            "path": collection.name,
            "depth": depth,
            "mesh_count": len(meshes),
            "examples": [obj.name for obj in meshes[:8]],
        }, ensure_ascii=False))
    for child in collection.children:
        walk(child, depth + 1)


print(json.dumps({
    "objects": len(bpy.data.objects),
    "meshes": sum(obj.type == "MESH" for obj in bpy.data.objects),
    "collections": len(bpy.data.collections),
}, ensure_ascii=False))
walk(bpy.context.scene.collection)

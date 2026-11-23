"""
dino_maker.py - builds cute low-poly dinos for Fling for Fossils and exports FBX.

HOW TO RUN (Blender 3.6 or newer, including 4.x and 5.x):
  1. Open Blender, click the "Scripting" tab at the top.
  2. In the text editor, click Open and pick this file.
  3. Change DINOS_TO_BUILD below if you want other dinos, then press the
     Run Script button (the play arrow).
  4. The FBX files land in a "DinoModels" folder on your Desktop, and the last
     dino stays in the scene so you can look at it.

Each dino is made of separate meshes named by role. The game colours them from
src/shared/Config/Dinos.luau, so the Blender colours are only a preview:
  Body, Head            main colour      (Head is separate so Baby dinos get big heads)
  Belly, HeadBelly      lighter colour
  Accent, HeadAccent    spikes, plates, stripes (darker colour)
  Bone, HeadBone        claws, teeth, horns (cream)
  EyeL, EyeR            eyes (stay dark, even on Gold/Rainbow)
  EyeShineL, EyeShineR  the white sparkle in each eye
Anything whose name starts with "Head" or "Eye" grows with the head on Baby dinos.

Units: 1 Blender unit is about 1 stud. The game rescales each model to its
height anyway. The dino faces -Y in Blender (the "Front" view looks at its face).
"""

import math
import os

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

# Which dinos to build when you press Run Script. Names are dino Ids from Dinos.luau.
DINOS_TO_BUILD = ["TRex"]

OUTPUT_FOLDER = os.path.join(os.path.expanduser("~"), "Desktop", "DinoModels")

# Lower = more triangles. 0.16 keeps a whole dino around 2-3k triangles (fine on phones).
BLOB_RESOLUTION = 0.18
# After the blobs are turned into meshes, keep this share of the triangles.
DECIMATE_RATIO = 0.35

# Preview colours in Blender (0-255, like Color3.fromRGB). Keep them in step
# with Color / Belly / Accent in Dinos.luau so Blender shows the in-game look.
FIXED_COLOURS = {
    "Bone": (245, 236, 215),
    "Eye": (25, 20, 28),
    "EyeShine": (255, 255, 255),
}


# --------------------------------------------------------------------------
# Small building blocks
# --------------------------------------------------------------------------


class Part:
    """Collects shapes for one named mesh (one MeshPart in Roblox)."""

    def __init__(self, name, role):
        self.name = name
        self.role = role
        self.blobs = []  # (centre, radii, rotation) - melted together smoothly
        self.solids = []  # bmesh-building functions - hard shapes like spikes

    def blob(self, co, radii, rot=(0, 0, 0)):
        if isinstance(radii, (int, float)):
            radii = (radii, radii, radii)
        self.blobs.append((Vector(co), Vector(radii), Euler([math.radians(a) for a in rot])))
        return self

    def cone(self, base, tip, radius, sides=6):
        self.solids.append(("cone", Vector(base), Vector(tip), radius, sides))
        return self

    def ball(self, co, radius, squash=(1, 1, 1), segments=10):
        self.solids.append(("ball", Vector(co), radius, Vector(squash), segments))
        return self


def mirror(co):
    return (-co[0], co[1], co[2])


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.metaballs, bpy.data.materials):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def srgb_to_linear(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material_for(role, colours):
    name = "Dino_" + role
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        rgb = colours.get(role) or FIXED_COLOURS.get(role) or (180, 180, 180)
        colour = tuple(srgb_to_linear(c) for c in rgb)
        mat.diffuse_color = (*colour, 1.0)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
            bsdf.inputs["Roughness"].default_value = 0.6
    return mat


def evaluated_mesh(obj, name):
    """Returns a plain mesh copy of obj with modifiers/metaballs applied."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    return bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))


def blobs_to_mesh(part):
    """Melts the part's blobs together with metaballs, then converts to a mesh."""
    mb = bpy.data.metaballs.new("mb_" + part.name)
    mb.resolution = BLOB_RESOLUTION
    mb.render_resolution = BLOB_RESOLUTION
    mb.threshold = 0.6
    mb_obj = bpy.data.objects.new("mb_" + part.name, mb)
    bpy.context.scene.collection.objects.link(mb_obj)
    for co, radii, rot in part.blobs:
        el = mb.elements.new(type="ELLIPSOID")
        el.co = co
        # A lone element of radius r and size s reaches about 0.574 * r * s.
        biggest = max(radii)
        el.radius = biggest / 0.574
        el.size_x, el.size_y, el.size_z = (radii.x / biggest, radii.y / biggest, radii.z / biggest)
        el.rotation = rot.to_quaternion()
        el.stiffness = 2.0
    bpy.context.view_layer.update()
    mesh = evaluated_mesh(mb_obj, part.name)
    bpy.data.objects.remove(mb_obj, do_unlink=True)
    bpy.data.metaballs.remove(mb)
    bpy.context.view_layer.update()

    obj = bpy.data.objects.new(part.name + "_blobs", mesh)
    bpy.context.scene.collection.objects.link(obj)
    # Only the big parts get thinned out; small ones look jagged if decimated.
    if DECIMATE_RATIO < 1 and len(mesh.polygons) > 1000:
        mod = obj.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = DECIMATE_RATIO
        bpy.context.view_layer.update()
        decimated = evaluated_mesh(obj, part.name)
        obj.modifiers.clear()
        old = obj.data
        obj.data = decimated
        bpy.data.meshes.remove(old)
    return obj


def solids_to_bmesh(part, bm):
    for solid in part.solids:
        if solid[0] == "cone":
            _, base, tip, radius, sides = solid
            axis = tip - base
            length = axis.length
            res = bmesh.ops.create_cone(
                bm, cap_ends=True, cap_tris=False, segments=sides,
                radius1=radius, radius2=0.0, depth=length,
            )
            rot = axis.to_track_quat("Z", "Y").to_matrix().to_4x4()
            mat = Matrix.Translation((base + tip) / 2) @ rot
            bmesh.ops.transform(bm, matrix=mat, verts=res["verts"])
        elif solid[0] == "ball":
            _, co, radius, squash, segments = solid
            res = bmesh.ops.create_uvsphere(
                bm, u_segments=segments, v_segments=max(4, segments // 2 + 1), radius=radius,
            )
            mat = Matrix.Translation(co) @ Matrix.Diagonal((*squash, 1.0))
            bmesh.ops.transform(bm, matrix=mat, verts=res["verts"])


def build_part(part, collection, colours):
    pieces = []
    if part.blobs:
        pieces.append(blobs_to_mesh(part))
    if part.solids:
        mesh = bpy.data.meshes.new(part.name + "_solids")
        bm = bmesh.new()
        solids_to_bmesh(part, bm)
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(part.name + "_solids", mesh)
        bpy.context.scene.collection.objects.link(obj)
        pieces.append(obj)
    if not pieces:
        return None

    # Join everything for this part into one object.
    for other in bpy.context.scene.objects:
        other.select_set(False)
    for p in pieces:
        p.select_set(True)
    bpy.context.view_layer.objects.active = pieces[0]
    if len(pieces) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = part.name
    obj.data.name = part.name

    # Put the object's origin in the middle of its shape (Roblox does the same).
    verts = [v.co for v in obj.data.vertices]
    centre = Vector([(min(v[i] for v in verts) + max(v[i] for v in verts)) / 2 for i in range(3)])
    obj.data.transform(Matrix.Translation(-centre))
    obj.location = centre

    obj.data.materials.clear()
    obj.data.materials.append(material_for(part.role, colours))
    smooth = part.role in ("Body", "Belly", "Eye", "EyeShine")
    for poly in obj.data.polygons:
        poly.use_smooth = smooth

    for c in obj.users_collection:
        c.objects.unlink(obj)
    collection.objects.link(obj)
    return obj


# --------------------------------------------------------------------------
# Shared body bits (reused by many dinos)
# --------------------------------------------------------------------------


def add_eyes(parts, centre, radius, shine_offset=(0.0, -0.1, 0.1)):
    """Big shiny cartoon eyes. centre is the right eye (x > 0); the left is mirrored."""
    for side, sign in (("R", 1), ("L", -1)):
        c = Vector((centre[0] * sign, centre[1], centre[2]))
        parts["Eye" + side] = Part("Eye" + side, "Eye").ball(c, radius, segments=12)
        s = c + Vector((shine_offset[0] * sign + 0.25 * radius * sign, shine_offset[1] - 0.75 * radius, shine_offset[2] + 0.2 * radius))
        parts["EyeShine" + side] = Part("EyeShine" + side, "EyeShine").ball(s, radius * 0.32, segments=8)


def spine_spikes(part, points, sizes, lean=0.35):
    """Little spikes along the back. points: list of (y, z) on the centre line."""
    for (y, z), size in zip(points, sizes):
        base = Vector((0, y, z))
        tip = base + Vector((0, lean * size, size))
        part.cone(base - Vector((0, 0, size * 0.35)), tip, size * 0.55, sides=5)


# --------------------------------------------------------------------------
# Dinos
# --------------------------------------------------------------------------


def build_trex():
    """Chibi T. rex: giant head, tiny arms, chunky legs, stubby tail."""
    P = {}
    body = P["Body"] = Part("Body", "Body")
    # Torso: pear shape leaning forward.
    body.blob((0, 0.4, 2.55), (1.35, 1.55, 1.35), rot=(-15, 0, 0))
    body.blob((0, -0.55, 3.35), (0.95, 0.9, 1.0))  # chest/neck
    # Tail: a short curve getting thinner.
    body.blob((0, 1.85, 2.45), (0.85, 1.0, 0.8))
    body.blob((0, 2.85, 2.2), (0.6, 0.85, 0.55))
    body.blob((0, 3.7, 2.05), (0.42, 0.65, 0.4))
    body.blob((0, 4.45, 2.05), (0.26, 0.5, 0.26), rot=(-10, 0, 0))
    # Legs: big thighs, short shins, flat feet.
    for sign in (1, -1):
        body.blob((0.95 * sign, 0.55, 1.75), (0.6, 0.85, 0.8))
        body.blob((0.95 * sign, 0.45, 0.85), (0.42, 0.45, 0.55))
        body.blob((0.95 * sign, 0.05, 0.25), (0.5, 0.75, 0.28))
        # Tiny arms.
        body.blob((0.75 * sign, -1.25, 2.6), (0.2, 0.42, 0.2), rot=(40, 0, 0))

    belly = P["Belly"] = Part("Belly", "Belly")
    belly.blob((0, -0.8, 2.35), (0.95, 0.55, 1.05), rot=(-15, 0, 0))
    belly.blob((0, -1.15, 3.2), (0.62, 0.35, 0.6))

    head = P["Head"] = Part("Head", "Body")
    head.blob((0, -1.35, 4.45), (1.25, 1.25, 1.05))  # skull
    head.blob((0, -2.45, 4.25), (0.95, 0.95, 0.72))  # snout
    head.blob((0, -2.05, 3.65), (0.85, 1.05, 0.42))  # jaw

    hbelly = P["HeadBelly"] = Part("HeadBelly", "Belly")
    hbelly.blob((0, -2.3, 3.5), (0.7, 0.9, 0.3))  # light chin

    bone = P["Bone"] = Part("Bone", "Bone")
    for sign in (1, -1):
        for dx in (-0.25, 0.0, 0.25):
            base = Vector((0.95 * sign + dx, -0.6, 0.2))
            bone.cone(base, base + Vector((0, -0.28, -0.05)), 0.11, sides=5)
        hand = Vector((0.78 * sign, -1.62, 2.38))
        bone.cone(hand, hand + Vector((0, -0.15, -0.12)), 0.07, sides=4)

    hbone = P["HeadBone"] = Part("HeadBone", "Bone")
    # Two rows of chunky teeth peeking out of the smile.
    # Two cute fangs poking out of the top jaw.
    for x in (-0.45, 0.45):
        hbone.cone((x, -3.2, 4.02), (x, -3.24, 3.66), 0.13, sides=4)

    accent = P["Accent"] = Part("Accent", "Accent")
    spine_spikes(accent, [(0.0, 3.85), (0.85, 3.75), (1.75, 3.3), (2.7, 2.9), (3.55, 2.55), (4.3, 2.4)],
                 [0.5, 0.52, 0.45, 0.36, 0.27, 0.18])
    haccent = P["HeadAccent"] = Part("HeadAccent", "Accent")
    spine_spikes(haccent, [(-1.75, 5.45), (-1.0, 5.45), (-0.35, 5.1)], [0.38, 0.48, 0.46])

    add_eyes(P, centre=(0.78, -2.05, 4.85), radius=0.33)
    return P


# Dino Id -> (builder, preview colours). Colours match Dinos.luau.
BUILDERS = {
    "TRex": (build_trex, {"Body": (95, 170, 80), "Belly": (240, 230, 170), "Accent": (240, 150, 60)}),
}


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------


def export_fbx(collection, path):
    for obj in bpy.context.view_layer.objects:
        obj.select_set(obj.name in collection.objects)
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL",
        mesh_smooth_type="FACE",
        use_mesh_modifiers=True,
        add_leaf_bones=False,
        bake_anim=False,
        path_mode="AUTO",
    )


def build(dino_id):
    if dino_id not in BUILDERS:
        raise ValueError("No builder for dino '%s' yet. Known: %s" % (dino_id, ", ".join(BUILDERS)))
    clear_scene()
    collection = bpy.data.collections.get(dino_id) or bpy.data.collections.new(dino_id)
    if collection.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(collection)
    builder, colours = BUILDERS[dino_id]
    parts = builder()
    tris = 0
    for part in parts.values():
        obj = build_part(part, collection, colours)
        if obj:
            tris += sum(len(p.vertices) - 2 for p in obj.data.polygons)
    os.makedirs(OUTPUT_FOLDER, exist_ok=True)
    path = os.path.join(OUTPUT_FOLDER, dino_id + ".fbx")
    export_fbx(collection, path)
    print("Built %s: %d triangles, saved to %s" % (dino_id, tris, path))
    return collection


def main():
    for dino_id in DINOS_TO_BUILD:
        build(dino_id)


if __name__ == "__main__":
    main()

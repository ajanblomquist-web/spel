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
src/shared/Config/DinoLooks.luau, so the Blender colours are only a preview:
  Body, Head            main colour      (Head is separate so Baby dinos get big heads)
  Belly, HeadBelly      lighter colour
  Accent, HeadAccent    spikes, plates, sails, frills, crests, wings, crystals
  Pattern               stripes, spots and lava cracks
  Bone, HeadBone        claws, teeth, horns (cream)
  HeadMouth             inside of the mouth and nostrils (dark red)
  HeadTongue            tongue (pink)
  HeadCheek             blush on the cheeks (pink)
  EyeL, EyeR            eyes (stay dark, even on Gold/Rainbow)
  EyeShineL, EyeShineR  the white sparkles in each eye
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
# Leave it as ["All"] to build every dino (takes a minute or two).
DINOS_TO_BUILD = ["All"]

OUTPUT_FOLDER = os.path.join(os.path.expanduser("~"), "Desktop", "DinoModels")

# Lower = more triangles and smoother shapes. Parts can set their own.
BLOB_RESOLUTION = 0.15
# After the blobs are turned into meshes, keep this share of the triangles.
DECIMATE_RATIO = 0.4

# Preview colours in Blender (0-255, like Color3.fromRGB). Keep them in step
# with DinoLooks.luau so Blender shows the in-game look.
FIXED_COLOURS = {
    "Bone": (245, 236, 215),
    "Eye": (25, 20, 28),
    "EyeShine": (255, 255, 255),
    "Mouth": (120, 30, 45),
    "Tongue": (240, 110, 130),
    "Cheek": (255, 140, 150),
}


# --------------------------------------------------------------------------
# Small building blocks
# --------------------------------------------------------------------------


class Part:
    """Collects shapes for one named mesh (one MeshPart in Roblox)."""

    def __init__(self, name, role, resolution=None, smooth=None):
        self.name = name
        self.role = role
        self.resolution = resolution or BLOB_RESOLUTION
        self.smooth = smooth
        self.blobs = []  # (centre, radii, rotation, carve) - melted together smoothly
        self.solids = []  # hard shapes like spikes, claws and plates
        self.decals = []  # shapes stuck onto another part's surface

    def blob(self, co, radii, rot=(0, 0, 0)):
        if isinstance(radii, (int, float)):
            radii = (radii, radii, radii)
        self.blobs.append((Vector(co), Vector(radii), Euler([math.radians(a) for a in rot]), False))
        return self

    def carve(self, co, radii, rot=(0, 0, 0)):
        """Scoops a blob-shaped hole out of this part's blobs (e.g. an open mouth)."""
        if isinstance(radii, (int, float)):
            radii = (radii, radii, radii)
        self.blobs.append((Vector(co), Vector(radii), Euler([math.radians(a) for a in rot]), True))
        return self

    def decal(self, onto, start, direction, size, thickness, sink=0.45, spin=0.0, segments=8):
        """A flat oval stuck onto the surface of part `onto`. A ray is shot from `start`
        along `direction`; the oval sits where it hits, lying flat on the surface.
        size is (width, height) of the oval, thickness how much it bulges out."""
        self.decals.append((onto, Vector(start), Vector(direction).normalized(), size, thickness, sink, spin, segments))
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
    mb.resolution = part.resolution
    mb.render_resolution = part.resolution
    mb.threshold = 0.6
    mb_obj = bpy.data.objects.new("mb_" + part.name, mb)
    bpy.context.scene.collection.objects.link(mb_obj)
    for co, radii, rot, carve in part.blobs:
        el = mb.elements.new(type="ELLIPSOID")
        el.use_negative = carve
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
        elif solid[0] == "oval":
            _, co, rotation, radii, segments = solid
            res = bmesh.ops.create_uvsphere(
                bm, u_segments=segments, v_segments=max(4, segments // 2 + 1), radius=1.0,
            )
            mat = Matrix.Translation(co) @ rotation @ Matrix.Diagonal((*radii, 1.0))
            bmesh.ops.transform(bm, matrix=mat, verts=res["verts"])


def place_decals(part, built):
    """Turns the part's decals into ovals lying on the surfaces of already built parts."""
    from mathutils.bvhtree import BVHTree

    trees = {}
    for onto, start, direction, size, thickness, sink, spin, segments in part.decals:
        target = built.get(onto)
        if target is None:
            continue
        if onto not in trees:
            mesh = target.data.copy()
            mesh.transform(target.matrix_world)
            bm = bmesh.new()
            bm.from_mesh(mesh)
            trees[onto] = BVHTree.FromBMesh(bm)
            bm.free()
            bpy.data.meshes.remove(mesh)
        hit, normal, _, _ = trees[onto].ray_cast(start, direction)
        if hit is None:
            print("  decal on %s missed (from %s)" % (onto, tuple(start)))
            continue
        normal = normal.normalized()
        if normal.dot(direction) > 0:
            normal = -normal
        # Lie flat on the surface: local Z = surface normal, local Y points "up" as much as it can.
        up = Vector((0, 0, 1)) if abs(normal.z) < 0.9 else Vector((0, 1, 0))
        x_axis = up.cross(normal).normalized()
        y_axis = normal.cross(x_axis).normalized()
        rotation = Matrix((x_axis, y_axis, normal)).transposed().to_4x4()
        rotation = rotation @ Matrix.Rotation(math.radians(spin), 4, "Z")
        centre = hit - normal * thickness * sink
        part.solids.append(("oval", centre, rotation, Vector((size[0] / 2, size[1] / 2, thickness)), segments))


def build_part(part, collection, colours, built):
    if part.decals:
        place_decals(part, built)
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
    smooth = part.smooth if part.smooth is not None else part.role != "Bone" and part.role != "Accent"
    for poly in obj.data.polygons:
        poly.use_smooth = smooth

    for c in obj.users_collection:
        c.objects.unlink(obj)
    collection.objects.link(obj)
    return obj


# --------------------------------------------------------------------------
# Shared body bits (reused by many dinos)
# --------------------------------------------------------------------------


def add_eyes(parts, centre, radius):
    """Big shiny cartoon eyes with two sparkles. centre is the right eye (x > 0)."""
    for side, sign in (("R", 1), ("L", -1)):
        c = Vector((centre[0] * sign, centre[1], centre[2]))
        parts["Eye" + side] = Part("Eye" + side, "Eye").ball(c, radius, squash=(1, 0.8, 1.1), segments=16)
        shine = Part("EyeShine" + side, "EyeShine")
        # Both sparkles sit on the front-top of the eye, towards the outside.
        big = c + Vector((0.2 * radius * sign, -0.72 * radius, 0.38 * radius))
        small = c + Vector((-0.25 * radius * sign, -0.78 * radius, -0.3 * radius))
        shine.ball(big, radius * 0.3, segments=10)
        shine.ball(small, radius * 0.15, segments=8)
        parts["EyeShine" + side] = shine


def spine_spikes(part, points, sizes, lean=0.35, sides=6, width=0.55):
    """Chunky spikes along the back. points: list of (y, z) on the centre line."""
    for (y, z), size in zip(points, sizes):
        base = Vector((0, y, z))
        tip = base + Vector((0, lean * size, size))
        part.cone(base - Vector((0, 0, size * 0.4)), tip, size * width, sides=sides)


def get(P, name, role, **kw):
    """The part called name, made on first use."""
    if name not in P:
        P[name] = Part(name, role, **kw)
    return P[name]


def lerp(a, b, t):
    return a + (b - a) * t


class Frame:
    """Where a body plan put things, so features (sails, frills...) can find them."""

    def __init__(self):
        self.spine = []  # (y, z) points along the top of the back, head to tail tip
        self.head = None  # head centre
        self.head_scale = 1.0
        self.snout = 1.0
        self.width = 1.0
        self.tail_tip = None
        self.hips = None  # (x, y, z) of the right thigh
        self.shoulders = None  # (x, y, z) of the right arm / front leg


# --------------------------------------------------------------------------
# Heads
# --------------------------------------------------------------------------


def add_head(P, F, centre, scale=1.0, snout=1.0, width=1.0, teeth="fangs", eye=1.0, head_spikes=True,
             brows=True, stripes=True):
    """The smiling cartoon head from the T. rex, moved and stretched.

    snout > 1 makes a longer face (Spinosaurus), width < 1 a narrower one.
    teeth: "fangs" (meat eaters), "small" (little teeth only), "none" (plant eaters).
    """
    S = Vector(centre)

    def y_of(y):
        # Stretch only the front of the face, not the skull.
        return y if y > -0.6 else -0.6 + (y + 0.6) * snout

    def H(x, y, z):
        return S + Vector((x * width, y_of(y), z)) * scale

    def R(rx, ry, rz, front=False):
        return (rx * width * scale, ry * (snout if front else 1) * scale, rz * scale)

    F.head, F.head_scale, F.snout = S, scale, snout

    head = get(P, "Head", "Body", resolution=0.13 * max(0.6, scale))
    head.blob(H(0, 0, 0), R(1.25, 1.25, 1.05))  # skull
    head.blob(H(0, -1.1, -0.08), R(0.98, 1.0, 0.66, True))  # upper snout
    head.blob(H(0, -0.8, -0.92), R(0.88, 1.05, 0.42, True))  # lower jaw
    for sign in (1, -1):
        if brows:
            head.blob(H(0.66 * sign, -0.5, 0.7), R(0.42, 0.42, 0.24), rot=(0, 15 * sign, 0))
        head.blob(H(0.85 * sign, -0.65, -0.55), R(0.35, 0.5, 0.35))  # corner of the smile
    head.carve(H(0, -1.7, -0.58), R(0.78, 0.7, 0.17, True))  # the smile

    get(P, "HeadMouth", "Mouth", resolution=0.1 * max(0.6, scale)).blob(
        H(0, -1.3, -0.58), R(0.72, 0.6, 0.2, True))
    get(P, "HeadTongue", "Tongue", resolution=0.08 * max(0.6, scale)).blob(
        H(0, -1.45, -0.66), R(0.4, 0.42, 0.1, True))

    if teeth != "none":
        hbone = get(P, "HeadBone", "Bone")
        xs = (-0.58, -0.36, -0.13, 0.13, 0.36, 0.58)
        for x in xs:
            fang = teeth == "fangs" and abs(x) == 0.36
            length = (0.22 if fang else 0.13) * scale
            top = H(x, -1.92 + x * x * 0.75, -0.44)
            hbone.cone(top, top + Vector((0, -0.03, -length)), (0.1 if fang else 0.07) * scale, sides=5)

    get(P, "HeadBelly", "Belly").decal("Head", H(0, -1.05, -2.0), (0, -0.15, 1), (1.05 * scale * width, 1.35 * scale * snout), 0.07 * scale)
    cheek = get(P, "HeadCheek", "Cheek")
    nostril = get(P, "HeadNostril", "Mouth")
    for sign in (1, -1):
        cheek.decal("Head", H(2.5 * sign, -0.8, -0.2), (-sign, -0.25, 0), (0.42 * scale, 0.3 * scale), 0.05 * scale)
        nostril.decal("Head", H(0.22 * sign, -3.6, 0.7), (0, 1, -0.45), (0.14 * scale, 0.09 * scale), 0.04 * scale, sink=0.6)
        if stripes:
            get(P, "Pattern", "Pattern").decal("Head", H(0.55 * sign, 0.55, 2.0), (sign * 0.3, 0, -1), (0.5 * scale, 0.26 * scale), 0.05 * scale, sink=0.3)

    if head_spikes:
        haccent = get(P, "HeadAccent", "Accent")
        pts = [(H(0, -0.55, 0.95).y, H(0, -0.55, 0.95).z), (H(0, 0.1, 1.12).y, H(0, 0.1, 1.12).z),
               (H(0, 0.75, 0.95).y, H(0, 0.75, 0.95).z)]
        spine_spikes(haccent, pts, [0.34 * scale, 0.46 * scale, 0.44 * scale])

    e = H(0.76, -0.77, 0.38)
    add_eyes(P, centre=(e.x, e.y, e.z), radius=0.36 * scale * eye)
    return H


# --------------------------------------------------------------------------
# Body plans
# --------------------------------------------------------------------------


def theropod(P, width=1.0, legs=1.0, tail=1.0, neck=0.0, head=1.0, snout=1.0, arms=1.0, teeth="fangs",
             spikes=True, spots=True, head_spikes=None, torso=1.0):
    """Two legs, small arms, big head. The defaults make the T. rex."""
    F = Frame()
    F.width = width
    lift = (legs - 1) * 1.9
    body = get(P, "Body", "Body")
    body.blob((0, 0.4, 2.55 + lift), (1.35 * width * torso, 1.55 * torso, 1.35 * torso), rot=(-15, 0, 0))
    body.blob((0, -0.55, 3.35 + lift), (0.95 * width, 0.9, 1.0))  # chest
    # Neck, from the chest up to the head.
    neck_top = Vector((0, -0.9 - 0.3 * neck, 4.0 + lift + neck))
    steps = 1 + int(neck * 2.5)
    for i in range(steps):
        t = i / max(1, steps - 1) if steps > 1 else 0
        c = Vector((0, -0.9, 4.0 + lift)).lerp(neck_top, t)
        body.blob(c, (0.75 * width - 0.15 * t * min(neck, 1), 0.7, 0.7))
    # Tail: a curve that lifts a little at the tip.
    tail_pts = []
    for y, z, r in ((1.85, 2.45, 0.85), (2.8, 2.2, 0.62), (3.65, 2.08, 0.45), (4.4, 2.1, 0.3), (5.0, 2.22, 0.18)):
        ty = 1.85 + (y - 1.85) * tail
        body.blob((0, ty, z + lift), (r * width, r * 1.25 * tail, r * 0.95))
        tail_pts.append((ty, z + lift + r * 0.95))
    F.tail_tip = Vector((0, tail_pts[-1][0], tail_pts[-1][1]))
    for sign in (1, -1):
        x = 0.97 * width * sign
        body.blob((0.95 * width * sign, 0.5, 1.8 * legs), (0.62, 0.85, 0.82 * min(legs, 1.3)))  # thigh
        body.blob((x + 0.03 * sign, 0.1, 1.25 * legs), (0.42, 0.42, 0.42))  # knee
        body.blob((x, 0.45, 0.75 * legs), (0.38, 0.38, 0.5 * legs))  # shin
        body.blob((x, 0.05, 0.25), (0.5, 0.65, 0.26))  # foot
        for dx in (-0.27, 0.0, 0.27):
            body.blob((x + dx, -0.6, 0.2), (0.15, 0.28, 0.17))  # toe
        # Arm: upper arm, forearm, two fingers.
        a = arms
        ax = 0.92 * width * sign
        body.blob((ax, -1.1, 2.85 + lift), (0.22 * a, 0.34 * a, 0.22 * a), rot=(30, 0, 0))
        body.blob((ax + 0.03 * sign, -1.1 - 0.4 * a, 2.85 + lift - 0.25 * a), (0.17 * a, 0.32 * a, 0.17 * a), rot=(-35, 0, 0))
        for dx in (-0.08, 0.08):
            body.blob((ax + 0.03 * sign + dx * a, -1.1 - 0.68 * a, 2.85 + lift - 0.4 * a), (0.09 * a, 0.15 * a, 0.09 * a), rot=(-45, 0, 0))
    F.hips = Vector((0.95 * width, 0.5, 1.8 * legs))
    F.shoulders = Vector((0.92 * width, -1.1, 2.85 + lift))

    belly = get(P, "Belly", "Belly", resolution=0.1)
    for y, z, w in ((-0.9, 1.9, 0.72), (-1.12, 2.32, 0.88), (-1.22, 2.75, 0.9), (-1.28, 3.18, 0.78), (-1.3, 3.6, 0.6)):
        belly.blob((0, y * torso, z + lift), (w * width * torso, 0.4, 0.24), rot=(-20, 0, 0))

    if spots:
        pattern = get(P, "Pattern", "Pattern")
        for y in (0.3, 1.1, 1.9, 2.75, 3.6):
            y = 1.85 + (y - 1.85) * tail if y > 1.85 else y
            for side in (-1, 0, 1):
                pattern.decal("Body", (side * 3.0, y, 7.0 + lift), (-side * 0.6, 0, -1), (0.9 if side == 0 else 0.7, 0.3), 0.06, sink=0.3)
        for sign in (1, -1):
            for y, z, size in ((0.2, 2.2, 0.32), (0.8, 2.75, 0.24), (1.3, 2.0, 0.2), (-0.3, 2.9, 0.18)):
                pattern.decal("Body", (3 * sign, y, z + lift), (-sign, 0, 0), (size, size * 0.8), 0.04)

    # Back line: neck, back, tail.
    F.spine = [(-0.6 - 0.3 * neck, 4.55 + lift + neck * 0.9), (0.1, 3.95 + lift), (0.9, 3.85 + lift),
               (1.75, 3.4 + lift)] + [(y, z) for y, z in tail_pts[1:]]
    if spikes:
        sizes = [0.42, 0.5, 0.52, 0.46, 0.38, 0.3, 0.22, 0.15]
        spine_spikes(get(P, "Accent", "Accent"), F.spine, sizes)

    # Toe claws.
    bone = get(P, "Bone", "Bone")
    for sign in (1, -1):
        for dx in (-0.27, 0.0, 0.27):
            base = Vector((0.97 * width * sign + dx, -0.82, 0.2))
            bone.cone(base, base + Vector((0, -0.22, -0.08)), 0.09, sides=6)
        ax = 0.92 * width * sign + 0.03 * sign
        for dx in (-0.08, 0.08):
            tip = Vector((ax + dx * arms, -1.1 - 0.78 * arms, 2.85 + lift - 0.47 * arms))
            bone.cone(tip, tip + Vector((0, -0.08, -0.14)) * arms, 0.06 * arms, sides=5)

    hs = head
    centre = (0, -1.35 - 0.3 * neck + (1 - hs) * 0.4, 4.5 + lift + neck - (1 - hs) * 0.9)
    add_head(P, F, centre, scale=hs, snout=snout, teeth=teeth,
             head_spikes=spikes if head_spikes is None else head_spikes)
    return F


def quadruped(P, width=1.0, legs=1.0, length=1.0, tail=1.0, neck=0.0, head=0.85, snout=0.9, teeth="none",
              spots=True, head_height=0.0, sprawl=0.0, toes=3):
    """Four legs, a round barrel body and a big low head (Triceratops, Stegosaurus...)."""
    F = Frame()
    F.width = width
    h = 1.9 * legs  # height of the body centre
    body = get(P, "Body", "Body")
    body.blob((0, 0.3, h), (1.3 * width, 1.9 * length, 1.15))  # barrel
    body.blob((0, -1.3 * length, h + 0.15), (1.0 * width, 0.9, 0.95))  # shoulders
    body.blob((0, 1.6 * length, h + 0.1), (1.05 * width, 0.9, 0.95))  # hips
    # Neck forward (and up for long necks).
    neck_base = Vector((0, -1.9 * length, h + 0.3))
    neck_top = Vector((0, -2.3 * length - 0.6 * neck, h + 0.6 + neck * 1.6 + head_height))
    steps = 2 + int(neck * 3)
    for i in range(steps):
        t = i / (steps - 1)
        r = lerp(0.8, 0.55 if neck > 0.5 else 0.7, t)
        body.blob(neck_base.lerp(neck_top, t), (r * width, r, r))
    # Tail.
    tail_pts = []
    for i, (dy, dz, r) in enumerate(((0.6, -0.05, 0.8), (1.5, -0.25, 0.6), (2.35, -0.4, 0.43), (3.1, -0.5, 0.29), (3.7, -0.52, 0.17))):
        y = 1.6 * length + dy * tail
        z = h + dz * (0.6 + 0.4 * legs)
        body.blob((0, y, z), (r * width, r * 1.3 * tail, r * 0.95))
        tail_pts.append((y, z + r * 0.95))
    F.tail_tip = Vector((0, tail_pts[-1][0], tail_pts[-1][1]))
    # Legs.
    legs_at = [(-1.25 * length, 0.85), (1.45 * length, 0.9)]
    bone = get(P, "Bone", "Bone")
    for ly, lx in legs_at:
        for sign in (1, -1):
            x = (lx * width + sprawl * 0.5) * sign
            body.blob((lx * width * sign, ly, h - 0.45), (0.55, 0.6, 0.7))  # upper leg
            body.blob((x, ly, lerp(0.25, h - 0.45, 0.45)), (0.4, 0.42, 0.55 * legs))  # lower leg
            body.blob((x, ly - 0.1, 0.22), (0.47, 0.55, 0.24))  # foot
            offsets = (-0.25, 0.0, 0.25) if toes == 3 else (-0.18, 0.18)
            for dx in offsets:
                body.blob((x + dx, ly - 0.55, 0.18), (0.15, 0.22, 0.15))
                nail = Vector((x + dx, ly - 0.72, 0.17))
                bone.ball(nail, 0.1, squash=(1, 0.8, 0.9), segments=8)
    F.hips = Vector((0.9 * width, 1.45 * length, h))
    F.shoulders = Vector((0.85 * width, -1.25 * length, h))

    belly = get(P, "Belly", "Belly", resolution=0.1)
    for i in range(4):
        y = lerp(-1.2, 1.3, i / 3) * length
        belly.blob((0, y, h - 0.95), (0.85 * width, 0.5, 0.25))

    if spots:
        pattern = get(P, "Pattern", "Pattern")
        for sign in (1, -1):
            for y, dz, size in ((-0.6, 0.3, 0.36), (0.2, 0.55, 0.3), (0.9, 0.2, 0.34), (1.6, 0.5, 0.26), (0.4, -0.2, 0.22)):
                pattern.decal("Body", (4 * sign, y * length, h + dz), (-sign, 0, 0), (size, size * 0.8), 0.04)

    F.spine = [(neck_top.y + 0.3, neck_top.z + 0.6), (-1.3 * length, h + 1.1), (-0.4 * length, h + 1.2), (0.5 * length, h + 1.2),
               (1.4 * length, h + 1.1)] + tail_pts[1:]

    hs = head
    centre = neck_top + Vector((0, -0.75 * hs, 0.35 * hs))
    add_head(P, F, centre, scale=hs, snout=snout, teeth=teeth, head_spikes=False)
    return F


def pterosaur(P):
    """Pteranodon: small round body standing on its legs, big wings held out."""
    F = Frame()
    body = get(P, "Body", "Body")
    body.blob((0, 0.2, 2.2), (1.0, 1.1, 1.2), rot=(-20, 0, 0))
    body.blob((0, -0.4, 3.1), (0.65, 0.6, 0.7))  # neck
    for sign in (1, -1):
        body.blob((0.55 * sign, 0.3, 1.2), (0.35, 0.4, 0.5))
        body.blob((0.55 * sign, 0.25, 0.5), (0.22, 0.22, 0.45))
        body.blob((0.55 * sign, 0.0, 0.15), (0.3, 0.45, 0.17))
        for dx in (-0.15, 0.0, 0.15):
            body.blob((0.55 * sign + dx, -0.4, 0.12), (0.08, 0.2, 0.1))
        # Wing arm: shoulder, elbow, the long wing finger.
        body.blob((1.05 * sign, -0.1, 2.75), (0.35, 0.3, 0.3))
        body.blob((1.9 * sign, 0.05, 3.15), (0.6, 0.18, 0.18), rot=(0, -20 * sign, 0))
        body.blob((3.1 * sign, 0.15, 3.35), (0.75, 0.13, 0.13), rot=(0, 10 * sign, 0))
        body.blob((4.1 * sign, 0.3, 3.05), (0.45, 0.1, 0.1), rot=(0, 30 * sign, 0))
    belly = get(P, "Belly", "Belly", resolution=0.1)
    belly.blob((0, -0.55, 2.1), (0.7, 0.45, 0.85), rot=(-20, 0, 0))
    # Wing skin.
    wing = get(P, "Accent", "Accent", smooth=True)
    for sign in (1, -1):
        wing.blob((1.4 * sign, 0.45, 2.5), (0.7, 0.45, 0.6), rot=(0, 0, 0))
        wing.blob((2.4 * sign, 0.5, 2.85), (0.9, 0.35, 0.55))
        wing.blob((3.4 * sign, 0.55, 2.95), (0.75, 0.25, 0.4))
        wing.blob((4.0 * sign, 0.55, 2.85), (0.4, 0.15, 0.25))
    bone = get(P, "Bone", "Bone")
    for sign in (1, -1):
        for dx in (-0.15, 0.0, 0.15):
            base = Vector((0.55 * sign + dx, -0.55, 0.12))
            bone.cone(base, base + Vector((0, -0.15, -0.05)), 0.05, sides=5)
        hand = Vector((2.6 * sign, -0.05, 3.35))
        bone.cone(hand, hand + Vector((0, -0.2, 0.05)), 0.07, sides=5)
    pattern = get(P, "Pattern", "Pattern")
    for sign in (1, -1):
        for y, z, s in ((0.2, 2.6, 0.3), (0.7, 2.0, 0.24)):
            pattern.decal("Body", (3 * sign, y, z), (-sign, 0, 0), (s, s * 0.8), 0.04)
    F.spine = [(-0.3, 3.7), (0.3, 3.3), (0.9, 2.8)]
    F.tail_tip = Vector((0, 1.2, 1.8))
    get(P, "Body", "Body").blob((0, 1.15, 1.75), (0.18, 0.4, 0.18), rot=(30, 0, 0))  # tiny tail
    H = add_head(P, F, (0, -0.75, 3.85), scale=0.78, snout=2.1, width=0.75, teeth="none", head_spikes=False, stripes=False)
    # The long backwards crest.
    crest = get(P, "HeadAccent", "Accent")
    crest.blob(H(0, 1.2, 0.75), (0.18, 0.75, 0.32), rot=(-25, 0, 0))
    crest.blob(H(0, 2.0, 1.1), (0.14, 0.55, 0.22), rot=(-30, 0, 0))
    return F


def sauropod(P, **kw):
    """Long neck, long tail, little head (Brachiosaurus)."""
    opts = dict(width=1.05, legs=1.5, length=1.15, tail=1.5, neck=1.6, head=0.62, snout=0.9, head_height=0.6)
    opts.update(kw)
    return quadruped(P, **opts)


# --------------------------------------------------------------------------
# Features
# --------------------------------------------------------------------------


def sail(P, F, height=1.6, start=1, end=5, role="Accent", name="Accent", spines=True):
    """A tall fin along the back (Spinosaurus, Dimetrodon)."""
    part = get(P, name, role, smooth=True)
    pts = F.spine[start:end]
    n = len(pts)
    for i, (y, z) in enumerate(pts):
        t = i / max(1, n - 1)
        hgt = height * math.sin(math.pi * lerp(0.15, 0.85, t))
        part.blob((0, y, z + hgt * 0.45), (0.12, 0.55, hgt * 0.55))
        if spines:
            get(P, "Bone", "Bone").cone((0, y, z), (0, y + 0.05, z + hgt * 0.95), 0.06, sides=4)
    return part


def back_plates(P, F, sizes, name="Accent"):
    """Big diamond plates in two rows (Stegosaurus)."""
    part = get(P, name, "Accent", smooth=False)
    pts = F.spine[1:]
    # Spread the plates evenly from the shoulders to the middle of the tail.
    y0, y1 = pts[0][0], pts[min(len(pts) - 1, 5)][0]
    for i, s in enumerate(sizes):
        t = i / max(1, len(sizes) - 1)
        y = lerp(y0, y1, t)
        # Height of the back here, from the spine points.
        z = next((lerp(a[1], b[1], (y - a[0]) / (b[0] - a[0])) for a, b in zip(pts, pts[1:]) if a[0] <= y <= b[0]), pts[0][1])
        side = 1 if i % 2 == 0 else -1
        x = side * 0.18
        # A plate: a flat diamond, standing up and leaning out a little.
        part.solids.append(("oval", Vector((x, y, z + s * 0.45)),
                            Matrix.Rotation(math.radians(side * 10), 4, "Y") @ Matrix.Rotation(math.radians(45), 4, "X"),
                            Vector((0.09, s * 0.48, s * 0.48)), 4))
    return part


def tail_spikes(P, F, count=2, size=0.6):
    """The thagomizer: spikes at the end of the tail."""
    bone = get(P, "Bone", "Bone")
    tip = F.tail_tip
    for i in range(count):
        y = tip.y - 0.3 - i * 0.45
        for sign in (1, -1):
            base = Vector((0.1 * sign, y, tip.z - 0.15))
            bone.cone(base, base + Vector((size * 0.75 * sign, size * 0.3, size * 0.55)), 0.12, sides=6)


def tail_club(P, F, size=0.7, name="Accent"):
    part = get(P, name, "Accent")
    tip = F.tail_tip
    part.blob((0, tip.y + 0.2, tip.z - 0.1), (size * 1.25, size, size * 0.8))
    for sign in (1, -1):
        part.blob((size * 0.9 * sign, tip.y + 0.2, tip.z - 0.1), (size * 0.5, size * 0.6, size * 0.5))


def armour(P, F, rows=3, name="Accent", spikes=True, ice=False):
    """Rounded bumps over the back, with spikes along the sides (Ankylosaurus)."""
    part = get(P, name, "Accent")
    for i, (y, z) in enumerate(F.spine[1:5]):
        for k in range(-(rows // 2), rows // 2 + 1):
            x = k * 0.55 * F.width
            dz = -abs(k) * 0.22
            part.decal("Body", (x * 1.2, y, z + 3), (x * 0.25, 0, -1), (0.55, 0.48), 0.2, sink=0.2, segments=8)
    if spikes:
        bone = get(P, "Bone", "Bone")
        for y, _ in F.spine[1:5]:
            for sign in (1, -1):
                base = Vector((1.25 * F.width * sign, y, F.spine[2][1] - 0.85))
                tip = base + Vector((0.5 * sign, 0.05, 0.05))
                if ice:
                    get(P, "Accent", "Accent").cone(base, tip + Vector((0, 0, 0.2)), 0.15, sides=4)
                else:
                    bone.cone(base, tip, 0.14, sides=6)


def frill(P, F, size=1.0, spikes=0):
    """The big shield behind the head (Triceratops, Protoceratops)."""
    S = F.head
    s = F.head_scale * size
    part = get(P, "HeadAccent", "Accent", smooth=True)
    centre = S + Vector((0, 0.75 * F.head_scale, 0.75 * F.head_scale))
    part.blob(centre, (1.75 * s, 0.22 * s, 1.3 * s), rot=(-28, 0, 0))
    # A lighter rim and little bumps around the edge.
    if spikes:
        hb = get(P, "HeadBone", "Bone")
        for i in range(spikes):
            a = math.radians(lerp(-80, 80, i / max(1, spikes - 1)))
            edge = centre + Vector((math.sin(a) * 1.75 * s, 0.25 * s * math.cos(a), math.cos(a) * 1.3 * s * 0.9))
            hb.cone(edge, edge + Vector((math.sin(a) * 0.35 * s, 0.15 * s, math.cos(a) * 0.35 * s)), 0.12 * s, sides=5)


def horns(P, F, brow=True, nose=True, length=1.0):
    S, s = F.head, F.head_scale
    hb = get(P, "HeadBone", "Bone")
    if brow:
        for sign in (1, -1):
            base = S + Vector((0.55 * sign, -0.45, 0.85)) * s
            hb.cone(base, base + Vector((0.12 * sign, -0.75, 0.95)) * s * length, 0.2 * s, sides=8)
    if nose:
        base = S + Vector((0, -0.6 - 1.1 * F.snout, 0.6)) * s
        hb.cone(base, base + Vector((0, -0.2, 0.55)) * s * length, 0.17 * s, sides=8)


def beak(P, F):
    """A small hooked beak tip on the front of the snout (plant eaters)."""
    S, s = F.head, F.head_scale
    tip = S + Vector((0, -0.6 - 1.42 * F.snout, 0.05)) * s
    get(P, "HeadBone", "Bone", smooth=True).blob(tip, (0.42 * s, 0.22 * s, 0.3 * s), rot=(-25, 0, 0))


def head_crest(P, F, kind="tube"):
    S, s = F.head, F.head_scale
    part = get(P, "HeadAccent", "Accent", smooth=True)
    if kind == "tube":  # Parasaurolophus: long tube sweeping back
        for i in range(5):
            t = i / 4
            part.blob(S + Vector((0, lerp(-0.3, 2.3, t), lerp(1.0, 2.0, t))) * s, (0.38 * s, 0.5 * s, 0.38 * s))
    elif kind == "feathers":  # a fluffy tuft
        for dy, dz, r in ((-0.2, 1.05, 0.32), (0.25, 1.2, 0.36), (0.7, 1.1, 0.3), (1.0, 0.85, 0.22)):
            part.blob(S + Vector((0, dy, dz)) * s, (0.18 * s, r * s, r * s))
    elif kind == "flame":  # three flame licks
        for dy, h in ((-0.3, 0.8), (0.25, 1.1), (0.75, 0.7)):
            base = S + Vector((0, dy, 0.85)) * s
            part.cone(base, base + Vector((0, 0.35, h)) * s, 0.28 * s, sides=6)


def feathers(P, F, arm=False, tail=True, name="Accent"):
    """Fluffy feather tufts on the arms and tail tip (raptors)."""
    part = get(P, name, "Accent", smooth=True)
    if tail:
        tip = F.tail_tip
        for i, r in enumerate((0.32, 0.38, 0.3)):
            part.blob((0, tip.y - 0.4 + i * 0.45, tip.z + 0.05), (r * 1.2, 0.35, r))
    if arm:
        sx, sy, sz = F.shoulders
        for sign in (1, -1):
            part.blob((sx * sign + 0.15 * sign, sy - 0.15, sz - 0.2), (0.12, 0.45, 0.3), rot=(-30, 0, 0))


def sickle_claws(P, F):
    bone = get(P, "Bone", "Bone")
    for sign in (1, -1):
        base = Vector((F.width * 0.97 * sign + 0.3 * sign, -0.15, 0.45))
        bone.cone(base, base + Vector((0.05 * sign, -0.35, 0.3)), 0.11, sides=6)


def big_claws(P, F, length=0.9):
    """Long scythe claws on the hands (Therizinosaurus)."""
    bone = get(P, "Bone", "Bone")
    sx, sy, sz = F.shoulders
    for sign in (1, -1):
        for dx in (-0.12, 0.0, 0.12):
            base = Vector((sx * sign + 0.05 * sign + dx, sy - 0.85, sz - 0.6))
            bone.cone(base, base + Vector((0, -length * 0.45, -length)), 0.08, sides=6)


def crystals(P, F, count=6, size=0.7, name="Accent", where="back"):
    """Pointy crystals (amber, ice, meteor rock) sticking out of the back."""
    part = get(P, name, "Accent", smooth=False)
    pts = F.spine[1:1 + count] if where == "back" else F.spine
    for i, (y, z) in enumerate(pts[:count]):
        s = size * (1 - 0.08 * i)
        for k, (dx, lean) in enumerate(((0, 0), (0.35, 0.5), (-0.35, -0.5))):
            if k and i % 2:
                continue
            base = Vector((dx, y, z - 0.3))
            tip = base + Vector((lean * s * 0.8, 0.1, s * (1.7 if k == 0 else 1.2)))
            part.cone(base, tip, s * 0.34, sides=5)


def lava_cracks(P, F, count=14, name="Pattern"):
    """Glowing zig-zag cracks on the sides (Volcano and Magma dinos)."""
    part = get(P, name, "Pattern")
    y0, y1 = F.spine[1][0], F.spine[-3][0]
    for sign in (1, -1):
        for i in range(count // 2):
            y = lerp(y0, y1, i / max(1, count // 2 - 1))
            z = F.spine[min(len(F.spine) - 1, 1 + i % 3)][1] - 0.9 - (i % 2) * 0.5
            part.decal("Body", (4 * sign, y, z), (-sign, 0, 0), (0.55, 0.12), 0.05, spin=35 if i % 2 else -35, sink=0.3)


def snow_caps(P, F, name="Accent"):
    """Little snow patches on the back and head (Snow dinos)."""
    part = get(P, name, "Accent", smooth=True)
    for y, z in F.spine[1:4]:
        part.decal("Body", (0, y, z + 3), (0, 0, -1), (0.8, 0.6), 0.1, sink=0.2, segments=10)
    get(P, "HeadAccent", "Accent", smooth=True).decal("Head", F.head + Vector((0, 0, 3)), (0, 0, -1), (0.9 * F.head_scale, 0.8 * F.head_scale), 0.12 * F.head_scale, sink=0.2, segments=10)


def volcano_top(P, F):
    """A smoking little volcano cone on the back (Volcano Titan)."""
    y, z = F.spine[3]
    part = get(P, "Accent", "Accent")
    part.cone((0, y, z - 0.5), (0, y, z + 2.2), 1.6, sides=9)
    get(P, "Pattern", "Pattern").ball((0, y, z + 1.65), 0.55, squash=(1, 1, 0.45), segments=10)


# --------------------------------------------------------------------------
# Dinos
# --------------------------------------------------------------------------
# Each function builds one dino. Colours (0-255) are the preview colours and match
# src/shared/Config/DinoLooks.luau, which is what the game uses.


def build_trex():
    P = {}
    theropod(P)
    return P


def build_compsognathus():
    P = {}
    F = theropod(P, width=0.75, legs=1.15, tail=1.4, neck=0.5, head=0.85, arms=0.9, teeth="small", torso=0.85,
                 spikes=False)
    feathers(P, F, arm=False)
    return P


def build_snowcompy():
    P = {}
    F = theropod(P, width=0.75, legs=1.15, tail=1.4, neck=0.5, head=0.85, arms=0.9, teeth="small", torso=0.85,
                 spikes=False)
    head_crest(P, F, "feathers")
    snow_caps(P, F)
    return P


def raptor(P, crest="feathers"):
    F = theropod(P, width=0.8, legs=1.2, tail=1.5, neck=0.35, head=0.85, snout=1.25, arms=1.25, teeth="fangs",
                 spikes=False, torso=0.9)
    feathers(P, F)
    sickle_claws(P, F)
    if crest:
        head_crest(P, F, crest)
    return F


def build_velociraptor():
    P = {}
    raptor(P)
    return P


def build_amberraptor():
    P = {}
    F = raptor(P, crest=None)
    crystals(P, F, count=4, size=0.6, name="Accent")
    return P


def build_frostraptor():
    P = {}
    F = raptor(P, crest=None)
    crystals(P, F, count=5, size=0.65)
    snow_caps(P, F, name="Belly")
    return P


def build_emberraptor():
    P = {}
    raptor(P, crest="flame")
    return P


def build_spinosaurus():
    P = {}
    F = theropod(P, width=0.9, tail=1.35, neck=0.3, head=0.9, snout=1.6, arms=1.35, teeth="small", spikes=False,
                 head_spikes=False)
    sail(P, F, height=2.4, start=1, end=6)
    return P


def build_blizzardspino():
    P = {}
    F = theropod(P, width=0.9, tail=1.35, neck=0.3, head=0.9, snout=1.6, arms=1.35, teeth="small", spikes=False,
                 head_spikes=False)
    sail(P, F, height=2.4, start=1, end=6)
    crystals(P, F, count=3, size=0.5, name="HeadAccent", where="back")
    snow_caps(P, F, name="Belly")
    return P


def build_infernospino():
    P = {}
    F = theropod(P, width=0.9, tail=1.35, neck=0.3, head=0.9, snout=1.6, arms=1.35, teeth="fangs", spikes=False,
                 head_spikes=False)
    sail(P, F, height=2.6, start=1, end=6)
    lava_cracks(P, F, count=10)
    return P


def build_meteorrex():
    P = {}
    F = theropod(P, spots=False)
    crystals(P, F, count=5, size=0.8, name="Accent")
    lava_cracks(P, F, count=12)
    horns(P, F, nose=False, length=0.7)
    return P


def build_amberrex():
    P = {}
    F = theropod(P, spikes=False, head_spikes=False)
    crystals(P, F, count=6, size=0.75)
    return P


def build_therizinosaurus():
    P = {}
    F = theropod(P, width=1.05, legs=1.1, tail=0.8, neck=1.0, head=0.65, arms=1.7, teeth="none", spikes=False,
                 head_spikes=False, torso=1.1)
    head_crest(P, F, "feathers")
    feathers(P, F, tail=True)
    big_claws(P, F, length=1.0)
    beak(P, F)
    return P


def build_protoceratops():
    P = {}
    F = quadruped(P, width=0.95, legs=0.85, length=0.85, tail=0.85, head=0.95, snout=0.85)
    frill(P, F, size=0.75)
    beak(P, F)
    return P


def build_triceratops():
    P = {}
    F = quadruped(P, width=1.1, length=1.05, head=1.0, snout=0.9)
    frill(P, F, size=1.0, spikes=7)
    horns(P, F, length=1.4)
    beak(P, F)
    return P


def build_stegosaurus():
    P = {}
    F = quadruped(P, width=1.0, length=1.1, tail=1.2, head=0.7, snout=1.0, legs=1.05, head_height=-0.6)
    back_plates(P, F, [1.0, 1.4, 1.7, 1.8, 1.6, 1.3, 1.0, 0.7])
    tail_spikes(P, F)
    beak(P, F)
    return P


def build_magmastego():
    P = {}
    F = quadruped(P, width=1.0, length=1.1, tail=1.2, head=0.7, snout=1.0, legs=1.05, head_height=-0.6, spots=False)
    back_plates(P, F, [1.0, 1.4, 1.7, 1.8, 1.6, 1.3, 1.0, 0.7])
    tail_spikes(P, F)
    lava_cracks(P, F, count=10)
    return P


def build_ankylosaurus():
    P = {}
    F = quadruped(P, width=1.3, legs=0.8, length=1.0, tail=1.1, head=0.85, snout=0.8, spots=False, head_height=-0.4)
    armour(P, F)
    tail_club(P, F)
    beak(P, F)
    return P


def build_glacierankylo():
    P = {}
    F = quadruped(P, width=1.3, legs=0.8, length=1.0, tail=1.1, head=0.85, snout=0.8, spots=False, head_height=-0.4)
    armour(P, F, ice=True)
    tail_club(P, F)
    crystals(P, F, count=3, size=0.55)
    return P


def build_parasaurolophus():
    P = {}
    F = quadruped(P, width=0.95, legs=1.25, length=0.95, tail=1.25, neck=0.5, head=0.85, snout=1.15, head_height=0.3)
    head_crest(P, F, "tube")
    beak(P, F)
    return P


def build_dimetrodon():
    P = {}
    F = quadruped(P, width=1.0, legs=0.65, length=1.0, tail=1.3, head=0.85, snout=1.1, teeth="fangs", sprawl=0.5,
                  head_height=-0.5)
    sail(P, F, height=2.0, start=1, end=6)
    return P


def build_brachiosaurus():
    P = {}
    sauropod(P)
    return P


def build_volcanotitan():
    P = {}
    F = sauropod(P, spots=False)
    volcano_top(P, F)
    lava_cracks(P, F, count=14)
    return P


def build_pteranodon():
    P = {}
    pterosaur(P)
    return P


def C(body, belly, accent, pattern):
    return {"Body": body, "Belly": belly, "Accent": accent, "Pattern": pattern}


# Dino Id -> (builder, preview colours).
BUILDERS = {
    "Compsognathus": (build_compsognathus, C((140, 200, 90), (245, 240, 180), (255, 200, 60), (100, 160, 70))),
    "Protoceratops": (build_protoceratops, C((230, 170, 120), (250, 230, 200), (240, 110, 90), (200, 140, 100))),
    "Velociraptor": (build_velociraptor, C((220, 130, 70), (250, 225, 180), (90, 160, 220), (170, 90, 50))),
    "Stegosaurus": (build_stegosaurus, C((120, 180, 120), (230, 240, 190), (240, 120, 90), (90, 140, 90))),
    "Triceratops": (build_triceratops, C((130, 140, 210), (230, 230, 250), (250, 180, 80), (100, 110, 180))),
    "Ankylosaurus": (build_ankylosaurus, C((170, 140, 100), (240, 225, 190), (120, 95, 70), (140, 110, 80))),
    "Parasaurolophus": (build_parasaurolophus, C((80, 180, 180), (230, 250, 240), (250, 130, 160), (60, 140, 150))),
    "Pteranodon": (build_pteranodon, C((230, 130, 100), (250, 230, 200), (250, 180, 90), (190, 100, 80))),
    "TRex": (build_trex, C((95, 170, 80), (240, 230, 170), (240, 150, 60), (65, 130, 60))),
    "Spinosaurus": (build_spinosaurus, C((70, 130, 190), (220, 235, 245), (250, 110, 90), (50, 100, 160))),
    "Brachiosaurus": (build_brachiosaurus, C((150, 190, 130), (240, 240, 200), (110, 150, 100), (120, 160, 105))),
    "MeteorRex": (build_meteorrex, C((90, 60, 75), (200, 150, 140), (255, 120, 40), (255, 190, 60))),
    "Dimetrodon": (build_dimetrodon, C((220, 130, 70), (250, 220, 170), (130, 100, 220), (180, 90, 50))),
    "AmberRaptor": (build_amberraptor, C((205, 125, 55), (255, 235, 170), (255, 225, 90), (200, 120, 40))),
    "Therizinosaurus": (build_therizinosaurus, C((170, 130, 90), (240, 220, 190), (240, 200, 90), (130, 95, 65))),
    "AmberRex": (build_amberrex, C((215, 120, 45), (255, 230, 160), (255, 225, 90), (210, 110, 30))),
    "SnowCompy": (build_snowcompy, C((200, 225, 250), (255, 255, 255), (255, 255, 255), (160, 195, 235))),
    "FrostRaptor": (build_frostraptor, C((95, 165, 235), (235, 248, 255), (240, 252, 255), (100, 160, 220))),
    "GlacierAnkylo": (build_glacierankylo, C((120, 180, 230), (225, 240, 255), (215, 245, 255), (90, 140, 200))),
    "BlizzardSpino": (build_blizzardspino, C((170, 210, 245), (255, 255, 255), (110, 180, 255), (140, 185, 235))),
    "EmberRaptor": (build_emberraptor, C((255, 110, 40), (255, 220, 150), (255, 220, 60), (180, 60, 30))),
    "MagmaStego": (build_magmastego, C((110, 45, 35), (200, 120, 90), (255, 150, 40), (255, 120, 30))),
    "InfernoSpino": (build_infernospino, C((230, 70, 25), (255, 210, 130), (255, 220, 60), (255, 160, 40))),
    "VolcanoTitan": (build_volcanotitan, C((90, 40, 35), (190, 110, 80), (70, 45, 40), (255, 120, 30))),
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
    built = {}
    # Parts without decals first, so decals have surfaces to stick to.
    for part in sorted(parts.values(), key=lambda p: bool(p.decals)):
        obj = build_part(part, collection, colours, built)
        if obj:
            built[part.name] = obj
            tris += sum(len(p.vertices) - 2 for p in obj.data.polygons)
    os.makedirs(OUTPUT_FOLDER, exist_ok=True)
    path = os.path.join(OUTPUT_FOLDER, dino_id + ".fbx")
    export_fbx(collection, path)
    print("Built %s: %d triangles, saved to %s" % (dino_id, tris, path))
    return collection


def main():
    ids = list(BUILDERS) if DINOS_TO_BUILD == ["All"] else DINOS_TO_BUILD
    for dino_id in ids:
        build(dino_id)


if __name__ == "__main__":
    main()

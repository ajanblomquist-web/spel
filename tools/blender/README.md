# Dino models from Blender

`dino_maker.py` builds all 24 dinos as cute, chunky cartoon models (open smiling
mouth, sparkly eyes, blush, belly, stripes and spots, toes and claws, plus each
dino's own frills, horns, plates, sails, crests, wings, crystals or lava) and
saves each as an FBX file you import into Studio. Previews are in `previews/`.

## Make the FBX (Blender 3.6 or newer)

1. Open Blender. Close the splash screen.
2. Click the **Scripting** tab at the top of the window.
3. In the big text panel, click **Open** and pick `tools/blender/dino_maker.py`.
4. Press **Run Script** (the ▶ button above the text).
5. Wait a minute or two. One `.fbx` per dino (`TRex.fbx`, `Triceratops.fbx` ...)
   is saved in a **DinoModels** folder on your Desktop, and the last dino stays
   in the 3D view.

To build just one or a few, change `DINOS_TO_BUILD` near the top of the script,
for example `["TRex", "Triceratops"]`.

## Put it in the game (Roblox Studio)

1. Open the game in Studio.
2. **File > Import 3D** (or the **Import 3D** button on the Home tab) and pick
   `Desktop/DinoModels/TRex.fbx`. Do steps 2 to 5 once for each dino.
3. Leave the import settings as they are, but make sure **Merge Meshes** is off
   (each part needs its own name). Click **Import**.
4. In the Explorer, find the new model called `TRex` in Workspace. If
   ReplicatedStorage has no folder called `DinoModels`, add one (right-click
   ReplicatedStorage > Insert Object > Folder, rename it `DinoModels`).
5. Drag the `TRex` model into `ReplicatedStorage > DinoModels`. The name must be
   exactly the dino Id, `TRex` (the file name is already the Id).
6. Press Play, open chat and type `/dino TRex`. A T. rex appears on your first
   pedestal. Try `/dino TRex gold`, `/dino TRex rainbow`, `/dino TRex baby` or
   `/dino TRex huge` to see the variants. This command only works in Studio.

You don't need the Roblox Blender add-on for this. Gold, Rainbow, Baby and the
size variants all come from this one model automatically.

## How the game uses the model

- Each mesh is named by its job (`Body`, `Head`, `Belly`, `Accent`, `Pattern`,
  `Bone`, `HeadMouth`, `HeadTongue`, `HeadCheek`, `HeadNostril`, `EyeL`,
  `EyeShineL` ...). The game paints them with the dino's `Color`, `Belly`,
  `Accent` and `Pattern` from `src/shared/Config/DinoLooks.luau`, so changing a
  colour there needs no new export. Eyes, mouth, tongue and cheeks keep their
  colours on Gold and Rainbow dinos. Lava and fire parts glow (`Glow`).
- The game scales the model to the dino's `Height` in DinoLooks (6 studs if not
  set), but never longer than 11 or wider than 5.5 studs so it fits its pedestal, and
  turns it so the head faces the front, so the export size and direction don't
  matter.
- On Baby dinos, everything named `Head...` or `Eye...` grows to make a big head.

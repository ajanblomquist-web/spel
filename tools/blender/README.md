# Dino models from Blender

`dino_maker.py` builds cute, chunky cartoon dinos from code (open smiling mouth with teeth
and tongue, sparkly eyes, blush, belly plates, stripes and spots, toes and claws) and saves each as an
FBX file you import into Studio. Right now it knows one dino, the T. rex, as a
test of the look. Once the look is right, the rest get added to the same script.

## Make the FBX (Blender 3.6 or newer)

1. Open Blender. Close the splash screen.
2. Click the **Scripting** tab at the top of the window.
3. In the big text panel, click **Open** and pick `tools/blender/dino_maker.py`.
4. Press **Run Script** (the ▶ button above the text).
5. The T. rex appears in the 3D view, and `TRex.fbx` is saved in a
   **DinoModels** folder on your Desktop.

To build other dinos later, change `DINOS_TO_BUILD` near the top of the script.

## Put it in the game (Roblox Studio)

1. Open the game in Studio.
2. **File > Import 3D** (or the **Import 3D** button on the Home tab) and pick
   `Desktop/DinoModels/TRex.fbx`.
3. Leave the import settings as they are, but make sure **Merge Meshes** is off
   (each part needs its own name). Click **Import**.
4. In the Explorer, find the new model called `TRex` in Workspace. If
   ReplicatedStorage has no folder called `DinoModels`, add one (right-click
   ReplicatedStorage > Insert Object > Folder, rename it `DinoModels`).
5. Drag the `TRex` model into `ReplicatedStorage > DinoModels`. The name must be
   exactly the dino Id, `TRex`.
6. Press Play, open chat and type `/dino TRex`. A T. rex appears on your first
   pedestal. Try `/dino TRex gold`, `/dino TRex rainbow`, `/dino TRex baby` or
   `/dino TRex huge` to see the variants. This command only works in Studio.

You don't need the Roblox Blender add-on for this. Gold, Rainbow, Baby and the
size variants all come from this one model automatically.

## How the game uses the model

- Each mesh is named by its job (`Body`, `Head`, `Belly`, `Accent`, `Pattern`,
  `Bone`, `HeadMouth`, `HeadTongue`, `HeadCheek`, `HeadNostril`, `EyeL`,
  `EyeShineL` ...). The game paints them with the dino's `Color`, `Belly`,
  `Accent` and `Pattern` from `src/shared/Config/Dinos.luau`, so changing a
  colour there needs no new export. Eyes, mouth, tongue and cheeks keep their
  colours on Gold and Rainbow dinos.
- The game scales the model to the dino's `Height` (6 studs if not set), and
  turns it so the head faces the front, so the export size and direction don't
  matter.
- On Baby dinos, everything named `Head...` or `Eye...` grows to make a big head.

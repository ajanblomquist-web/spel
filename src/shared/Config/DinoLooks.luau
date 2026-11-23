-- DinoLooks.luau
-- How the 3D dino models (made with tools/blender/dino_maker.py) look in game.
-- Each model is painted by part: Color (skin), Belly, Accent (spikes, plates,
-- sails, frills, crystals) and Pattern (stripes, spots, lava cracks).
-- Height is how tall the model stands in studs (before Big/Huge sizes). It is
-- also kept within MaxLength/MaxWidth studs so it fits its pedestal.
-- Glow = "Pattern" or "Accent" makes those parts glow (Neon), for lava and fire.
-- A dino without an entry here uses its Dinos.luau Color and default sizes.

export type Look = {
	Color: Color3?,
	Belly: Color3?,
	Accent: Color3?,
	Pattern: Color3?,
	Height: number?,
	MaxLength: number?,
	MaxWidth: number?,
	Glow: string?,
}

local DinoLooks: { [string]: Look } = {
	Compsognathus = {
		Color = Color3.fromRGB(140, 200, 90),
		Belly = Color3.fromRGB(245, 240, 180),
		Accent = Color3.fromRGB(255, 200, 60),
		Pattern = Color3.fromRGB(100, 160, 70),
		Height = 4,
	},
	Protoceratops = {
		Color = Color3.fromRGB(230, 170, 120),
		Belly = Color3.fromRGB(250, 230, 200),
		Accent = Color3.fromRGB(240, 110, 90),
		Pattern = Color3.fromRGB(200, 140, 100),
		Height = 4.5,
	},
	Velociraptor = {
		Color = Color3.fromRGB(220, 130, 70),
		Belly = Color3.fromRGB(250, 225, 180),
		Accent = Color3.fromRGB(90, 160, 220),
		Pattern = Color3.fromRGB(170, 90, 50),
		Height = 5,
	},
	Stegosaurus = {
		Color = Color3.fromRGB(120, 180, 120),
		Belly = Color3.fromRGB(230, 240, 190),
		Accent = Color3.fromRGB(240, 120, 90),
		Pattern = Color3.fromRGB(90, 140, 90),
		Height = 6,
	},
	Triceratops = {
		Color = Color3.fromRGB(130, 140, 210),
		Belly = Color3.fromRGB(230, 230, 250),
		Accent = Color3.fromRGB(250, 180, 80),
		Pattern = Color3.fromRGB(100, 110, 180),
		Height = 6,
	},
	Ankylosaurus = {
		Color = Color3.fromRGB(170, 140, 100),
		Belly = Color3.fromRGB(240, 225, 190),
		Accent = Color3.fromRGB(120, 95, 70),
		Pattern = Color3.fromRGB(140, 110, 80),
		Height = 4.5,
	},
	Parasaurolophus = {
		Color = Color3.fromRGB(80, 180, 180),
		Belly = Color3.fromRGB(230, 250, 240),
		Accent = Color3.fromRGB(250, 130, 160),
		Pattern = Color3.fromRGB(60, 140, 150),
		Height = 6.5,
	},
	Pteranodon = {
		Color = Color3.fromRGB(230, 130, 100),
		Belly = Color3.fromRGB(250, 230, 200),
		Accent = Color3.fromRGB(250, 180, 90),
		Pattern = Color3.fromRGB(190, 100, 80),
		Height = 5,
		MaxWidth = 9,
	},
	TRex = {
		Color = Color3.fromRGB(95, 170, 80),
		Belly = Color3.fromRGB(240, 230, 170),
		Accent = Color3.fromRGB(240, 150, 60),
		Pattern = Color3.fromRGB(65, 130, 60),
		Height = 7,
	},
	Spinosaurus = {
		Color = Color3.fromRGB(70, 130, 190),
		Belly = Color3.fromRGB(220, 235, 245),
		Accent = Color3.fromRGB(250, 110, 90),
		Pattern = Color3.fromRGB(50, 100, 160),
		Height = 7.5,
	},
	Brachiosaurus = {
		Color = Color3.fromRGB(150, 190, 130),
		Belly = Color3.fromRGB(240, 240, 200),
		Accent = Color3.fromRGB(110, 150, 100),
		Pattern = Color3.fromRGB(120, 160, 105),
		Height = 10,
	},
	MeteorRex = {
		Color = Color3.fromRGB(90, 60, 75),
		Belly = Color3.fromRGB(200, 150, 140),
		Accent = Color3.fromRGB(255, 120, 40),
		Pattern = Color3.fromRGB(255, 190, 60),
		Height = 8,
		Glow = "Pattern",
	},
	Dimetrodon = {
		Color = Color3.fromRGB(220, 130, 70),
		Belly = Color3.fromRGB(250, 220, 170),
		Accent = Color3.fromRGB(130, 100, 220),
		Pattern = Color3.fromRGB(180, 90, 50),
		Height = 4,
	},
	AmberRaptor = {
		Color = Color3.fromRGB(205, 125, 55),
		Belly = Color3.fromRGB(255, 235, 170),
		Accent = Color3.fromRGB(255, 225, 90),
		Pattern = Color3.fromRGB(200, 120, 40),
		Height = 5.2,
	},
	Therizinosaurus = {
		Color = Color3.fromRGB(170, 130, 90),
		Belly = Color3.fromRGB(240, 220, 190),
		Accent = Color3.fromRGB(240, 200, 90),
		Pattern = Color3.fromRGB(130, 95, 65),
		Height = 7,
	},
	AmberRex = {
		Color = Color3.fromRGB(215, 120, 45),
		Belly = Color3.fromRGB(255, 230, 160),
		Accent = Color3.fromRGB(255, 225, 90),
		Pattern = Color3.fromRGB(210, 110, 30),
		Height = 7.5,
	},
	SnowCompy = {
		Color = Color3.fromRGB(200, 225, 250),
		Belly = Color3.fromRGB(255, 255, 255),
		Accent = Color3.fromRGB(255, 255, 255),
		Pattern = Color3.fromRGB(160, 195, 235),
		Height = 4,
	},
	FrostRaptor = {
		Color = Color3.fromRGB(95, 165, 235),
		Belly = Color3.fromRGB(235, 248, 255),
		Accent = Color3.fromRGB(240, 252, 255),
		Pattern = Color3.fromRGB(100, 160, 220),
		Height = 5.2,
	},
	GlacierAnkylo = {
		Color = Color3.fromRGB(120, 180, 230),
		Belly = Color3.fromRGB(225, 240, 255),
		Accent = Color3.fromRGB(215, 245, 255),
		Pattern = Color3.fromRGB(90, 140, 200),
		Height = 5,
	},
	BlizzardSpino = {
		Color = Color3.fromRGB(170, 210, 245),
		Belly = Color3.fromRGB(255, 255, 255),
		Accent = Color3.fromRGB(110, 180, 255),
		Pattern = Color3.fromRGB(140, 185, 235),
		Height = 8,
	},
	EmberRaptor = {
		Color = Color3.fromRGB(255, 110, 40),
		Belly = Color3.fromRGB(255, 220, 150),
		Accent = Color3.fromRGB(255, 220, 60),
		Pattern = Color3.fromRGB(180, 60, 30),
		Height = 5.2,
		Glow = "Accent",
	},
	MagmaStego = {
		Color = Color3.fromRGB(110, 45, 35),
		Belly = Color3.fromRGB(200, 120, 90),
		Accent = Color3.fromRGB(255, 150, 40),
		Pattern = Color3.fromRGB(255, 120, 30),
		Height = 6.5,
		Glow = "Pattern",
	},
	InfernoSpino = {
		Color = Color3.fromRGB(230, 70, 25),
		Belly = Color3.fromRGB(255, 210, 130),
		Accent = Color3.fromRGB(255, 220, 60),
		Pattern = Color3.fromRGB(255, 160, 40),
		Height = 8,
		Glow = "Pattern",
	},
	VolcanoTitan = {
		Color = Color3.fromRGB(90, 40, 35),
		Belly = Color3.fromRGB(190, 110, 80),
		Accent = Color3.fromRGB(70, 45, 40),
		Pattern = Color3.fromRGB(255, 120, 30),
		Height = 11,
		Glow = "Pattern",
	},
}

return DinoLooks

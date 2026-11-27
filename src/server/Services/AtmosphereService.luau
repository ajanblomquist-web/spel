-- AtmosphereService.luau
-- Sets the look of the whole game: a warm, bright late-afternoon sun, a soft
-- haze, gentle colour grading and subtle bloom and sun rays. Everything is made
-- from code (no uploaded assets) and kept bright so it reads well on phones.
--
-- NOTE: Lighting.Technology can't be changed by a running script (it is
-- plugin-only), so set it once in Studio: Lighting > Technology > Future (or
-- ShadowMap for lighter phones). The code tries anyway and ignores the error.

local Lighting = game:GetService("Lighting")

local AtmosphereService = {}

-- Removes anything we are about to create, so a place that already has these
-- objects doesn't end up with two of them.
local function clearOld()
	for _, child in Lighting:GetChildren() do
		if
			child:IsA("Atmosphere")
			or child:IsA("Sky")
			or child:IsA("ColorCorrectionEffect")
			or child:IsA("BloomEffect")
			or child:IsA("SunRaysEffect")
			or child:IsA("BlurEffect")
			or child:IsA("DepthOfFieldEffect")
		then
			child:Destroy()
		end
	end
end

local function make(className: string, props: { [string]: any }): Instance
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = Lighting
	return instance
end

function AtmosphereService.Init()
	clearOld()

	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)

	Lighting.ClockTime = 16.4 -- late afternoon: warm light, long soft shadows
	Lighting.GeographicLatitude = 25
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(112, 106, 118)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 146, 156)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 232, 196)
	Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.ExposureCompensation = 0.25
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35
	Lighting.FogEnd = 100000

	make("Sky", {
		Name = "Sky",
		SunAngularSize = 14,
		StarCount = 0,
	})

	make("Atmosphere", {
		Name = "Haze",
		Density = 0.26,
		Offset = 0.25,
		Color = Color3.fromRGB(226, 205, 178),
		Decay = Color3.fromRGB(232, 170, 120),
		Glare = 0.15,
		Haze = 1.1,
	})

	make("ColorCorrectionEffect", {
		Name = "WarmGrade",
		Brightness = 0.02,
		Contrast = 0.08,
		Saturation = 0.18,
		TintColor = Color3.fromRGB(255, 245, 232),
	})

	make("BloomEffect", {
		Name = "SoftBloom",
		Intensity = 0.3,
		Size = 22,
		Threshold = 1.05,
	})

	make("SunRaysEffect", {
		Name = "SoftRays",
		Intensity = 0.07,
		Spread = 0.6,
	})
end

return AtmosphereService

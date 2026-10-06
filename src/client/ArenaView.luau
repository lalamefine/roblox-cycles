--!strict
-- Décor local de l'arène : sol sombre, quadrillage lumineux, bordures, ambiance de nuit et bloom.
-- Rien n'est répliqué : chaque client construit son décor.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local GRID_EVERY = 8 -- une ligne du quadrillage toutes les 8 cases
local BORDER_HEIGHT = 4

local ArenaView = {}

local function part(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Parent = parent
	return p
end

function ArenaView.build(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "ArenaView"

	local span = Config.ARENA_SIZE * Config.CELL_STUDS
	local half = span / 2

	local floor = part("Sol", Vector3.new(span, 1, span), Vector3.new(0, -0.5, 0), Color3.fromRGB(8, 10, 22), folder)
	floor.Material = Enum.Material.SmoothPlastic

	local lineColor = Color3.fromRGB(30, 80, 140)
	for i = 0, Config.ARENA_SIZE, GRID_EVERY do
		local offset = -half + i * Config.CELL_STUDS
		local a = part("LigneX", Vector3.new(0.15, 0.05, span), Vector3.new(offset, 0.03, 0), lineColor, folder)
		local b = part("LigneZ", Vector3.new(span, 0.05, 0.15), Vector3.new(0, 0.03, offset), lineColor, folder)
		a.Transparency = 0.5
		b.Transparency = 0.5
	end

	local borderColor = Color3.fromRGB(200, 230, 255)
	local y = BORDER_HEIGHT / 2
	part("Bord", Vector3.new(span + 1, BORDER_HEIGHT, 0.5), Vector3.new(0, y, -half - 0.25), borderColor, folder)
	part("Bord", Vector3.new(span + 1, BORDER_HEIGHT, 0.5), Vector3.new(0, y, half + 0.25), borderColor, folder)
	part("Bord", Vector3.new(0.5, BORDER_HEIGHT, span + 1), Vector3.new(-half - 0.25, y, 0), borderColor, folder)
	part("Bord", Vector3.new(0.5, BORDER_HEIGHT, span + 1), Vector3.new(half + 0.25, y, 0), borderColor, folder)

	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(25, 25, 45)
	Lighting.OutdoorAmbient = Color3.fromRGB(25, 25, 45)
	-- Bloom léger et serré : un halo autour du néon sans flouter toute l'image.
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 8
	bloom.Threshold = 0.9
	bloom.Parent = Lighting
	-- Couleurs un peu plus franches pour que les néons ressortent sur le sol sombre.
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Saturation = 0.15
	grade.Contrast = 0.1
	grade.Parent = Lighting

	folder.Parent = workspace
	return folder
end

return ArenaView

--!strict
-- Effets visuels locaux : explosion d'une moto, onde de choc au sol, colonne de lumière à la
-- réapparition, étincelles dans les virages, échappement des motos et dissolution des murs.
-- Les particules passent par quelques émetteurs partagés (un par couleur et par type) que l'on
-- déplace avant chaque Emit : pas d'instance créée par étincelle.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Juice = require(ReplicatedStorage.Shared.Juice)

local Vfx = {}

local folder: Folder? = nil
local anchor: Part? = nil
-- Émetteurs partagés, par type d'effet puis par couleur (hexadécimal).
local emitters: { [string]: { [string]: { att: Attachment, emitter: ParticleEmitter } } } = {}

local function root(): Folder
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "Effets"
		f.Parent = workspace
		folder = f
	end
	return folder :: Folder
end

local function anchorPart(): Part
	if not anchor then
		local p = Instance.new("Part")
		p.Name = "Emetteurs"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.one
		p.CFrame = CFrame.identity
		p.Parent = root()
		anchor = p
	end
	return anchor :: Part
end

local function fade(color: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.15, color),
		ColorSequenceKeypoint.new(1, color),
	})
end

-- Réglages de chaque type d'émetteur ; la couleur est appliquée à la création.
local KINDS: { [string]: (ParticleEmitter, Color3) -> () } = {
	-- Gerbe d'étincelles d'une explosion : rapides, retombent au sol.
	burst = function(e, color)
		e.Color = fade(color)
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Lifetime = NumberRange.new(0.5, 1.1)
		e.Speed = NumberRange.new(18, 45)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, -40, 0)
		e.Drag = 2
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.6) })
		e.Squash = NumberSequence.new(1.5)
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
	end,
	-- Éclats plus gros et lents, qui flottent et s'éteignent : les morceaux de la moto.
	shards = function(e, color)
		e.Color = ColorSequence.new(color)
		e.LightEmission = 0.8
		e.LightInfluence = 0
		e.Lifetime = NumberRange.new(0.8, 1.6)
		e.Speed = NumberRange.new(6, 16)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, -12, 0)
		e.Drag = 1
		e.RotSpeed = NumberRange.new(-360, 360)
		e.Rotation = NumberRange.new(0, 360)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	end,
	-- Petites étincelles qui jaillissent au ras du sol dans un virage.
	sparks = function(e, color)
		e.Color = fade(color)
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Lifetime = NumberRange.new(0.15, 0.35)
		e.Speed = NumberRange.new(8, 18)
		e.SpreadAngle = Vector2.new(70, 20)
		e.Acceleration = Vector3.new(0, -30, 0)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
		e.Squash = NumberSequence.new(2)
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
	end,
}

local function emitterFor(kind: string, color: Color3): (Attachment, ParticleEmitter)
	local byColor = emitters[kind]
	if not byColor then
		byColor = {}
		emitters[kind] = byColor
	end
	local key = color:ToHex()
	local entry = byColor[key]
	if not entry then
		local att = Instance.new("Attachment")
		att.Name = `{kind}_{key}`
		att.Parent = anchorPart()
		local e = Instance.new("ParticleEmitter")
		e.Enabled = false
		e.Rate = 0
		e.LockedToPart = false
		KINDS[kind](e, color)
		e.Parent = att
		entry = { att = att, emitter = e }
		byColor[key] = entry
	end
	return entry.att, entry.emitter
end

local function emit(kind: string, color: Color3, cframe: CFrame, count: number)
	local att, e = emitterFor(kind, color)
	att.WorldCFrame = cframe
	e:Emit(count)
end

local function neon(name: string, shape: Enum.PartType, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	return p
end

local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

-- Détruit une instance temporaire après `seconds`.
local function expire(instance: Instance, seconds: number)
	task.delay(seconds, function()
		instance:Destroy()
	end)
end

-- Anneau plat au sol qui s'élargit (ou se resserre) en s'effaçant.
local function ring(position: Vector3, color: Color3, from: number, to: number, seconds: number)
	local r = neon("Onde", Enum.PartType.Cylinder, color)
	-- Un cylindre Roblox est couché le long de X : on le redresse pour qu'il soit à plat.
	local flat = CFrame.new(position.X, 0.1, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	r.Size = Vector3.new(0.1, from, from)
	r.CFrame = flat
	r.Transparency = 0.1
	r.Parent = root()
	tween(r, seconds, { Size = Vector3.new(0.1, to, to), Transparency = 1 })
	expire(r, seconds)
end

-- Explosion d'une moto : éclair, gerbe d'étincelles, éclats et onde de choc au sol.
function Vfx.explode(position: Vector3, color: Color3)
	local at = CFrame.new(position)
	emit("burst", color, at, 45)
	emit("shards", color, at, 14)

	local flash = neon("Eclair", Enum.PartType.Ball, Color3.new(1, 1, 1))
	flash.Size = Vector3.one * 2
	flash.Position = position
	flash.Transparency = 0
	flash.Parent = root()
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 30
	light.Brightness = 8
	light.Parent = flash
	tween(flash, 0.35, { Size = Vector3.one * 11, Transparency = 1, Color = color })
	tween(light, 0.5, { Brightness = 0 })
	expire(flash, 0.5)

	ring(position, color, 2, 28, 0.55)
end

-- Colonne de lumière et anneau qui se referme au point de réapparition.
function Vfx.respawn(position: Vector3, color: Color3)
	local height = 40
	local beam = neon("Colonne", Enum.PartType.Cylinder, color)
	-- Cylindre debout : son axe X passe à la verticale.
	beam.CFrame = CFrame.new(position.X, height / 2, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	beam.Size = Vector3.new(height, 3, 3)
	beam.Transparency = 0.2
	beam.Parent = root()
	tween(beam, 0.7, { Size = Vector3.new(height, 0.1, 0.1), Transparency = 1 }, Enum.EasingStyle.Quart)
	expire(beam, 0.7)

	ring(position, color, 16, 1, 0.45)
	emit("sparks", color, CFrame.lookAt(position, position + Vector3.yAxis), 16)
end

-- Étincelles projetées vers l'extérieur d'un virage.
function Vfx.turnSparks(position: Vector3, outward: Vector3, color: Color3)
	local base = Vector3.new(position.X, 0.2, position.Z)
	emit("sparks", color, CFrame.lookAt(base, base + outward + Vector3.yAxis * 0.4), 8)
end

-- Échappement lumineux à l'arrière d'une moto, détruit avec elle.
function Vfx.attachExhaust(bike: BasePart, color: Color3)
	local att = Instance.new("Attachment")
	att.Name = "Echappement"
	att.Position = Vector3.new(0, -bike.Size.Y / 2 + 0.2, bike.Size.Z / 2)
	att.Parent = bike
	local e = Instance.new("ParticleEmitter")
	e.Color = fade(color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = 40
	e.Lifetime = NumberRange.new(0.15, 0.3)
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(25, 25)
	e.EmissionDirection = Enum.NormalId.Back
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.LockedToPart = false
	e.Parent = att
end

-- Fait fondre des murs dans le sol avant de les détruire. Les Parts n'appartiennent plus à
-- l'appelant : Vfx s'en charge.
function Vfx.dissolve(parts: { BasePart })
	local seconds = Juice.WALL_DISSOLVE_SECONDS
	for _, p in parts do
		local size = p.Size
		tween(p, seconds, {
			Size = Vector3.new(size.X, 0.05, size.Z),
			Position = Vector3.new(p.Position.X, 0.05, p.Position.Z),
			Transparency = 1,
		}, Enum.EasingStyle.Quad)
		expire(p, seconds)
	end
end

return Vfx

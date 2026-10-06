--!strict
-- Effets sonores locaux. Les sons sont ceux livrés avec le client Roblox (rbxasset://sounds/...),
-- toujours disponibles sans téléversement ni droits d'auteur. Pour en changer, remplacer `id`
-- par un rbxassetid:// de la bibliothèque audio de Roblox (Creator Store, sons publiés par Roblox).

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Juice = require(ReplicatedStorage.Shared.Juice)

export type Cue = { id: string, volume: number, speed: number }

local BANK: { [string]: Cue } = {
	countdown = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, speed = 1 },
	go = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, speed = 1.5 },
	turn = { id = "rbxasset://sounds/swoosh.wav", volume = 0.18, speed = 1.6 },
	crash = { id = "rbxasset://sounds/collide.wav", volume = 0.9, speed = 0.8 },
	crashFar = { id = "rbxasset://sounds/collide.wav", volume = 0.5, speed = 1 },
	derez = { id = "rbxasset://sounds/Rocket whoosh 01.wav", volume = 0.35, speed = 1.4 },
	kill = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8, speed = 2 },
	respawn = { id = "rbxasset://sounds/Launching rocket.wav", volume = 0.4, speed = 1.3 },
	victory = { id = "rbxasset://sounds/victory.wav", volume = 0.7, speed = 1 },
	defeat = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, speed = 0.5 },
	-- Ronronnement continu de sa propre moto : à renseigner avec un son en boucle de la
	-- bibliothèque Roblox ; laissé vide, la moto roule en silence.
	engine = { id = "", volume = 0.25, speed = 1 },
}

local Sfx = {}

local group: SoundGroup? = nil
local cache: { [string]: Sound } = {}
local rng = Random.new()

local function soundGroup(): SoundGroup
	if not group then
		local g = Instance.new("SoundGroup")
		g.Name = "Effets"
		g.Volume = 1
		g.Parent = SoundService
		group = g
	end
	return group :: SoundGroup
end

-- Modèle d'un son, cloné à chaque lecture pour que plusieurs instances se chevauchent.
local function template(name: string): Sound?
	local cue = BANK[name]
	if not cue or cue.id == "" then
		return nil
	end
	local s = cache[name]
	if not s then
		local created = Instance.new("Sound")
		created.Name = name
		created.SoundId = cue.id
		created.Volume = cue.volume
		created.PlaybackSpeed = cue.speed
		created.SoundGroup = soundGroup()
		cache[name] = created
		s = created
	end
	return s
end

-- Joue un son d'interface (non positionné). `gain` multiplie son volume (atténuation, 0 à 1).
function Sfx.play(name: string, gain: number?)
	local base = template(name)
	local g = gain or 1
	if not base or g <= 0 then
		return
	end
	local s = base:Clone()
	s.Volume = base.Volume * g
	s.PlaybackSpeed = Juice.jitterPitch(base.PlaybackSpeed, rng:NextNumber())
	s.Parent = soundGroup()
	s.Ended:Once(function()
		s:Destroy()
	end)
	s:Play()
	-- Filet de sécurité si le son ne se charge pas (Ended ne viendrait jamais).
	task.delay(10, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

-- Joue un son émis à `position` dans le monde, atténué selon la distance à la caméra.
function Sfx.playAt(name: string, position: Vector3)
	local camera = workspace.CurrentCamera
	local distance = if camera then (camera.CFrame.Position - position).Magnitude else 0
	Sfx.play(name, Juice.distanceGain(distance))
end

local engine: Sound? = nil

-- Lance ou coupe le ronronnement de sa moto (sans effet tant que BANK.engine est vide).
function Sfx.engine(on: boolean)
	local base = template("engine")
	if not base then
		return
	end
	if on and not engine then
		local s = base:Clone()
		s.Looped = true
		s.Parent = soundGroup()
		s:Play()
		engine = s
	elseif not on and engine then
		engine:Destroy()
		engine = nil
	end
end

-- Précharge les sons pour que le premier crash ne soit pas muet.
function Sfx.preload()
	local list: { Instance } = {}
	for name in BANK do
		local s = template(name)
		if s then
			table.insert(list, s)
		end
	end
	task.spawn(function()
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(list)
		end)
	end)
end

return Sfx

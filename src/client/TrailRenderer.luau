--!strict
-- Rendu local des motos et de leurs murs à partir des messages du serveur.
-- Un mur = une Part étirée par segment droit ; le segment en cours s'allonge à chaque image,
-- en interpolant entre les deux derniers ticks pour un mouvement fluide.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Grid = require(ReplicatedStorage.Shared.Grid)
local Protocol = require(ReplicatedStorage.Shared.Protocol)

local WALL_Y = Config.WALL_HEIGHT / 2
local BIKE_SIZE = Vector3.new(1.2, 1.4, 3.2)

type View = {
	info: Protocol.Rider,
	color: Color3,
	alive: boolean,
	segments: { BasePart },
	current: BasePart?,
	cornerX: number,
	cornerZ: number,
	prevX: number,
	prevZ: number,
	x: number,
	z: number,
	dir: number,
	bike: BasePart?,
}

local TrailRenderer = {}

local folder: Folder? = nil
local views: { [number]: View } = {}
local tickClock = 0

local function world(x: number, z: number): Vector3
	local wx, wz = Grid.toWorld(x, z, Config.ARENA_SIZE, Config.CELL_STUDS)
	return Vector3.new(wx, WALL_Y, wz)
end

local function forward(dir: number): Vector3
	local d = Grid.DIRS[dir]
	return Vector3.new(d[1], 0, d[2])
end

local function colorOf(index: number): Color3
	local rgb = Config.COLORS[((index - 1) % #Config.COLORS) + 1]
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function newPart(name: string, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Parent = folder
	return p
end

-- Place une Part le long du segment a -> b (alignés sur un axe).
local function fitWall(p: BasePart, a: Vector3, b: Vector3)
	local t = Config.WALL_THICKNESS
	p.Size = Vector3.new(math.abs(b.X - a.X) + t, Config.WALL_HEIGHT, math.abs(b.Z - a.Z) + t)
	p.Position = (a + b) / 2
end

local function clearWalls(v: View)
	for _, s in v.segments do
		s:Destroy()
	end
	v.segments = {}
	if v.current then
		v.current:Destroy()
		v.current = nil
	end
end

local function destroyView(v: View)
	clearWalls(v)
	if v.bike then
		v.bike:Destroy()
		v.bike = nil
	end
end

local function makeBike(v: View)
	local bike = newPart(`Moto_{v.info.name}`, v.color)
	bike.Size = BIKE_SIZE
	local light = Instance.new("PointLight")
	light.Color = v.color
	light.Range = 12
	light.Brightness = 2
	light.Parent = bike
	v.bike = bike
end

-- Repart de zéro à partir d'un état complet (début de manche ou arrivée en cours de partie).
function TrailRenderer.reset(snapshot: Protocol.Snapshot)
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "Motos"
		f.Parent = workspace
		folder = f
	end
	for _, v in views do
		destroyView(v)
	end
	views = {}
	for _, info in snapshot.riders do
		local v: View = {
			info = info,
			color = colorOf(info.color),
			alive = info.alive,
			segments = {},
			current = nil,
			cornerX = info.x,
			cornerZ = info.z,
			prevX = info.x,
			prevZ = info.z,
			x = info.x,
			z = info.z,
			dir = info.dir,
			bike = nil,
		}
		local path = info.path
		local cleared = not info.alive and Config.TRAIL_CLEARS_ON_DEATH
		if not cleared then
			for i = 1, #path - 2, 2 do
				local seg = newPart("Mur", v.color)
				fitWall(seg, world(path[i], path[i + 1]), world(path[i + 2], path[i + 3]))
				table.insert(v.segments, seg)
			end
			v.cornerX, v.cornerZ = path[#path - 1], path[#path]
			v.current = newPart("Mur", v.color)
		end
		if info.alive then
			makeBike(v)
		end
		views[info.id] = v
	end
	tickClock = os.clock()
	TrailRenderer.render()
end

function TrailRenderer.applyTick(tick: Protocol.Tick)
	local m = tick.moves
	for i = 1, #m, 4 do
		local v = views[m[i]]
		if v then
			local x, z, dir = m[i + 1], m[i + 2], m[i + 3]
			if dir ~= v.dir and v.current then
				-- Virage à l'ancienne tête : le segment en cours devient fixe.
				fitWall(v.current, world(v.cornerX, v.cornerZ), world(v.x, v.z))
				table.insert(v.segments, v.current)
				v.current = newPart("Mur", v.color)
				v.cornerX, v.cornerZ = v.x, v.z
			end
			v.prevX, v.prevZ = v.x, v.z
			v.x, v.z, v.dir = x, z, dir
		end
	end
	for _, id in tick.dead do
		local v = views[id]
		if v and v.alive then
			v.alive = false
			v.prevX, v.prevZ = v.x, v.z
			local boom = Instance.new("Explosion")
			boom.BlastPressure = 0
			boom.BlastRadius = 6 -- taille visuelle ; aucun effet physique (pression et joints à 0)
			boom.DestroyJointRadiusPercent = 0
			boom.Position = world(v.x, v.z)
			boom.Parent = workspace
			if v.bike then
				v.bike:Destroy()
				v.bike = nil
			end
		end
	end
	for _, id in tick.cleared do
		local v = views[id]
		if v then
			clearWalls(v)
		end
	end
	tickClock = os.clock()
end

-- Position affichée de la tête d'une moto (interpolée) et sa direction.
local function headOf(v: View): (Vector3, Vector3)
	local alpha = math.clamp((os.clock() - tickClock) * Config.TICK_RATE, 0, 1)
	local a, b = world(v.prevX, v.prevZ), world(v.x, v.z)
	return a:Lerp(b, alpha), forward(v.dir)
end

-- À appeler à chaque image.
function TrailRenderer.render()
	for _, v in views do
		local head, fwd = headOf(v)
		if v.current then
			fitWall(v.current, world(v.cornerX, v.cornerZ), head)
		end
		if v.bike then
			-- La moto roule devant son mur.
			v.bike.CFrame = CFrame.lookAt(head + fwd * (BIKE_SIZE.Z / 2), head + fwd * BIKE_SIZE.Z)
		end
	end
end

-- Tête de la moto d'un participant pour la caméra ; nil s'il n'existe pas.
function TrailRenderer.focus(id: number): (Vector3?, Vector3?)
	local v = views[id]
	if not v then
		return nil, nil
	end
	return headOf(v)
end

function TrailRenderer.isAlive(id: number): boolean
	local v = views[id]
	return v ~= nil and v.alive
end

function TrailRenderer.aliveCount(): (number, number)
	local alive, total = 0, 0
	for _, v in views do
		total += 1
		if v.alive then
			alive += 1
		end
	end
	return alive, total
end

return TrailRenderer

--!strict
-- Rendu local des motos et de leurs murs à partir des messages du serveur.
-- Un mur = une suite de coins reliés à la tête ; il est redessiné à chaque image depuis la tête
-- interpolée entre les deux derniers ticks, sur au plus Config.TRAIL_MAX_LENGTH cases, ce qui fait
-- avancer la queue au même rythme que la tête. Une Part étirée par segment droit, réutilisées.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Grid = require(ReplicatedStorage.Shared.Grid)
local Juice = require(ReplicatedStorage.Shared.Juice)
local Protocol = require(ReplicatedStorage.Shared.Protocol)

local Vfx = require(script.Parent.Vfx)

local WALL_Y = Config.WALL_HEIGHT / 2
local BIKE_SIZE = Vector3.new(1.2, 1.4, 3.2)
local TRAIL_REACH = Config.TRAIL_MAX_LENGTH - 1 -- longueur du mur derrière la tête, en cases
-- Coins gardés un peu au-delà du mur, car la tête affichée a jusqu'à une case de retard.
local PATH_KEEP = Config.TRAIL_MAX_LENGTH + 2

type View = {
	info: Protocol.Rider,
	color: Color3,
	alive: boolean,
	path: { number }, -- coins du mur, le dernier relié à la tête ; vide si le mur est effacé
	walls: { BasePart },
	prevX: number,
	prevZ: number,
	x: number,
	z: number,
	dir: number,
	bike: BasePart?,
	lean: number, -- inclinaison affichée de la moto, en degrés (positive : vers la droite)
}

local TrailRenderer = {}

local folder: Folder? = nil
local views: { [number]: View } = {}
local tickClock = 0
local renderClock = os.clock()

local function world(x: number, z: number): Vector3
	local wx, wz = Grid.toWorld(x, z, Config.ARENA_SIZE, Config.CELL_STUDS)
	return Vector3.new(wx, WALL_Y, wz)
end

local function forward(dir: number): Vector3
	local d = Grid.DIRS[dir]
	return Vector3.new(d[1], 0, d[2])
end

function TrailRenderer.teamColor(team: number): Color3
	local rgb = Config.TEAMS[((team - 1) % #Config.TEAMS) + 1].color
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

-- Garde exactement `count` Parts de mur pour cette moto.
local function useWalls(v: View, count: number)
	for i = #v.walls + 1, count do
		v.walls[i] = newPart("Mur", v.color)
	end
	for i = #v.walls, count + 1, -1 do
		v.walls[i]:Destroy()
		v.walls[i] = nil
	end
end

local function destroyView(v: View)
	useWalls(v, 0)
	if v.bike then
		v.bike:Destroy()
		v.bike = nil
	end
end

local function makeBike(v: View)
	if v.bike then
		return
	end
	local bike = newPart(`Moto_{v.info.name}`, v.color)
	bike.Size = BIKE_SIZE
	local light = Instance.new("PointLight")
	light.Color = v.color
	light.Range = 12
	light.Brightness = 2
	light.Parent = bike
	Vfx.attachExhaust(bike, v.color)
	v.lean = 0
	v.bike = bike
end

-- Repart de zéro à partir d'un état complet (changement de phase, arrivée ou départ d'un joueur).
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
		local cleared = not info.alive and Config.TRAIL_CLEARS_ON_DEATH
		local v: View = {
			info = info,
			color = TrailRenderer.teamColor(info.team),
			alive = info.alive,
			path = if cleared then {} else table.clone(info.path),
			walls = {},
			prevX = info.x,
			prevZ = info.z,
			x = info.x,
			z = info.z,
			dir = info.dir,
			bike = nil,
			lean = 0,
		}
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
			if dir ~= v.dir and #v.path > 0 then
				-- Virage à l'ancienne tête : elle devient un coin du mur.
				table.insert(v.path, v.x)
				table.insert(v.path, v.z)
			end
			if dir ~= v.dir and v.alive then
				local sign = Juice.turnSign(v.dir, dir)
				v.lean = sign * Juice.LEAN_ANGLE
				-- L'élan emporte les étincelles dans l'ancienne direction.
				Vfx.turnSparks(world(v.x, v.z), forward(v.dir), v.color)
			end
			v.prevX, v.prevZ = v.x, v.z
			v.x, v.z, v.dir = x, z, dir
			if #v.path > 0 then
				Grid.trimPath(v.path, x, z, PATH_KEEP)
			end
		end
	end
	for _, id in tick.dead do
		local v = views[id]
		if v and v.alive then
			v.alive = false
			v.prevX, v.prevZ = v.x, v.z
			Vfx.explode(world(v.x, v.z), v.color)
			if v.bike then
				v.bike:Destroy()
				v.bike = nil
			end
		end
	end
	for _, id in tick.cleared do
		local v = views[id]
		if v then
			v.path = {}
			-- Les Parts du mur partent fondre dans le sol ; la moto en recrée à sa réapparition.
			Vfx.dissolve(v.walls)
			v.walls = {}
		end
	end
	local s = tick.spawns
	for i = 1, #s, 4 do
		local v = views[s[i]]
		if v then
			v.alive = true
			v.x, v.z, v.dir = s[i + 1], s[i + 2], s[i + 3]
			v.prevX, v.prevZ = v.x, v.z
			v.path = { v.x, v.z }
			makeBike(v)
			Vfx.respawn(world(v.x, v.z), v.color)
		end
	end
	tickClock = os.clock()
end

-- Position affichée de la tête d'une moto, en cases (interpolée), et sa direction.
local function headCell(v: View): (number, number)
	local alpha = math.clamp((os.clock() - tickClock) * Config.TICK_RATE, 0, 1)
	return v.prevX + (v.x - v.prevX) * alpha, v.prevZ + (v.z - v.prevZ) * alpha
end

-- Redessine le mur depuis la tête en remontant les coins, sur TRAIL_REACH cases au plus.
local function drawTrail(v: View, hx: number, hz: number)
	local path = v.path
	if #path == 0 then
		useWalls(v, 0)
		return
	end
	local segments = {}
	local px, pz = hx, hz
	local remaining = TRAIL_REACH
	for i = #path - 1, 1, -2 do
		local cx, cz = path[i], path[i + 1]
		local len = math.abs(cx - px) + math.abs(cz - pz)
		if len >= remaining then
			local k = if len > 0 then remaining / len else 0
			table.insert(segments, { px, pz, px + (cx - px) * k, pz + (cz - pz) * k })
			break
		end
		if len > 0 then
			table.insert(segments, { px, pz, cx, cz })
		end
		remaining -= len
		px, pz = cx, cz
	end
	useWalls(v, #segments)
	for i, seg in segments do
		fitWall(v.walls[i], world(seg[1], seg[2]), world(seg[3], seg[4]))
	end
end

-- À appeler à chaque image.
function TrailRenderer.render()
	local now = os.clock()
	local dt = now - renderClock
	renderClock = now
	for _, v in views do
		local hx, hz = headCell(v)
		drawTrail(v, hx, hz)
		if v.bike then
			local head, fwd = world(hx, hz), forward(v.dir)
			-- La moto roule devant son mur.
			v.lean = Juice.approach(v.lean, 0, Juice.LEAN_RECOVER, dt)
			v.bike.CFrame = CFrame.lookAt(head + fwd * (BIKE_SIZE.Z / 2), head + fwd * BIKE_SIZE.Z)
				* CFrame.Angles(0, 0, -math.rad(v.lean))
		end
	end
end

-- Tête de la moto d'un participant pour la caméra ; nil s'il n'existe pas.
function TrailRenderer.focus(id: number): (Vector3?, Vector3?)
	local v = views[id]
	if not v then
		return nil, nil
	end
	local hx, hz = headCell(v)
	return world(hx, hz), forward(v.dir)
end

function TrailRenderer.isAlive(id: number): boolean
	local v = views[id]
	return v ~= nil and v.alive
end

return TrailRenderer

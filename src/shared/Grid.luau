--!strict
-- Grille de l'arène : directions, virages, occupation des cases par les murs, avance des motos
-- et détection des collisions. Module pur : aucune API Roblox, testable sous Lune.
--
-- Coordonnées entières de 0 à size - 1 sur les axes X et Z. Directions : 0 = nord (-Z),
-- 1 = est (+X), 2 = sud (+Z), 3 = ouest (-X).

local Grid = {}
Grid.__index = Grid

export type Dir = number
export type Turn = number -- -1 = gauche, 1 = droite

export type Cycle = {
	id: number,
	x: number,
	z: number,
	dir: Dir,
	alive: boolean,
	turns: { Turn }, -- virages en attente, appliqués un par tick
}

export type Grid = typeof(setmetatable(
	{} :: {
		size: number,
		cells: { [number]: number }, -- clé de case -> id du propriétaire du mur
		owned: { [number]: { number } }, -- id -> clés des cases qu'il occupe
	},
	Grid
))

Grid.DIRS = table.freeze({
	[0] = table.freeze({ 0, -1 }),
	[1] = table.freeze({ 1, 0 }),
	[2] = table.freeze({ 0, 1 }),
	[3] = table.freeze({ -1, 0 }),
})

function Grid.turn(dir: Dir, turn: Turn): Dir
	return (dir + turn) % 4
end

function Grid.ahead(x: number, z: number, dir: Dir): (number, number)
	local d = Grid.DIRS[dir]
	return x + d[1], z + d[2]
end

function Grid.new(size: number): Grid
	assert(size >= 4 and size % 1 == 0, "size doit être un entier >= 4")
	return setmetatable({ size = size, cells = {}, owned = {} }, Grid) :: any
end

function Grid.key(self: Grid, x: number, z: number): number
	return z * self.size + x
end

function Grid.inBounds(self: Grid, x: number, z: number): boolean
	return x >= 0 and z >= 0 and x < self.size and z < self.size
end

-- Vrai si la case est dans l'arène et sans mur.
function Grid.isFree(self: Grid, x: number, z: number): boolean
	return self:inBounds(x, z) and self.cells[self:key(x, z)] == nil
end

function Grid.ownerAt(self: Grid, x: number, z: number): number?
	return self.cells[self:key(x, z)]
end

function Grid.occupy(self: Grid, x: number, z: number, id: number)
	local k = self:key(x, z)
	assert(self.cells[k] == nil, "case déjà occupée")
	self.cells[k] = id
	local list = self.owned[id]
	if not list then
		list = {}
		self.owned[id] = list
	end
	table.insert(list, k)
end

-- Efface le mur d'une moto ; renvoie le nombre de cases libérées.
function Grid.clearOwner(self: Grid, id: number): number
	local list = self.owned[id]
	if not list then
		return 0
	end
	for _, k in list do
		self.cells[k] = nil
	end
	self.owned[id] = nil
	return #list
end

function Grid.newCycle(id: number, x: number, z: number, dir: Dir): Cycle
	return { id = id, x = x, z = z, dir = dir, alive = true, turns = {} }
end

-- Mémorise un virage demandé par le joueur. Renvoie faux si la file est pleine.
function Grid.queueTurn(cycle: Cycle, turn: Turn, maxQueued: number): boolean
	if not cycle.alive or #cycle.turns >= maxQueued then
		return false
	end
	table.insert(cycle.turns, turn)
	return true
end

-- Avance toutes les motos vivantes d'une case. Une moto est éliminée si sa case suivante
-- sort de l'arène, porte déjà un mur, ou est visée par une autre moto au même tick (face-à-face).
-- Une moto éliminée reste sur place. Renvoie les ids éliminés à ce tick, dans l'ordre de `cycles`.
function Grid.step(self: Grid, cycles: { Cycle }): { number }
	local targets: { [Cycle]: number } = {}
	local claims: { [number]: number } = {}
	for _, c in cycles do
		if c.alive then
			local turn = table.remove(c.turns, 1)
			if turn then
				c.dir = Grid.turn(c.dir, turn)
			end
			local nx, nz = Grid.ahead(c.x, c.z, c.dir)
			if self:isFree(nx, nz) then
				local k = self:key(nx, nz)
				targets[c] = k
				claims[k] = (claims[k] or 0) + 1
			else
				targets[c] = -1
			end
		end
	end

	local eliminated = {}
	for _, c in cycles do
		local k = targets[c]
		if k ~= nil then
			if k < 0 or claims[k] > 1 then
				c.alive = false
				table.insert(eliminated, c.id)
			else
				c.x, c.z = Grid.ahead(c.x, c.z, c.dir)
				self:occupy(c.x, c.z, c.id)
			end
		end
	end
	return eliminated
end

-- Position dans le monde (X, Z en studs) du centre d'une case ; l'arène est centrée sur l'origine.
function Grid.toWorld(x: number, z: number, size: number, cellStuds: number): (number, number)
	local half = (size - 1) / 2
	return (x - half) * cellStuds, (z - half) * cellStuds
end

-- Points d'apparition répartis sur un cercle autour du centre, chacun tourné vers le centre
-- selon l'axe dominant. Les cases renvoyées sont distinctes et à au moins `margin` cases du bord.
function Grid.spawnPoints(size: number, count: number, margin: number): { { x: number, z: number, dir: Dir } }
	local center = (size - 1) / 2
	local radius = math.max(1, center - margin)
	local points = {}
	for i = 0, count - 1 do
		local angle = (i / count) * 2 * math.pi
		local x = math.floor(center + radius * math.cos(angle) + 0.5)
		local z = math.floor(center + radius * math.sin(angle) + 0.5)
		local dx, dz = center - x, center - z
		local dir: Dir
		if math.abs(dx) >= math.abs(dz) then
			dir = if dx > 0 then 1 else 3
		else
			dir = if dz > 0 then 2 else 0
		end
		table.insert(points, { x = x, z = z, dir = dir })
	end
	return points
end

return Grid

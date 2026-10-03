--!strict
-- Grille de l'arène : directions, virages, occupation des cases par les murs, avance des motos,
-- détection des collisions, murs de longueur limitée et choix des apparitions.
-- Module pur : aucune API Roblox, testable sous Lune.
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

-- File des cases d'un mur : `keys[first]` est la plus ancienne (la queue), `keys[last]` la tête.
export type Trail = { first: number, last: number, keys: { [number]: number } }

export type Grid = typeof(setmetatable(
	{} :: {
		size: number,
		cells: { [number]: number }, -- clé de case -> id du propriétaire du mur
		owned: { [number]: Trail }, -- id -> cases qu'il occupe, de la plus ancienne à la plus récente
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
	local trail = self.owned[id]
	if not trail then
		trail = { first = 1, last = 0, keys = {} }
		self.owned[id] = trail
	end
	trail.last += 1
	trail.keys[trail.last] = k
end

-- Nombre de cases occupées par le mur d'une moto (tête comprise).
function Grid.trailLength(self: Grid, id: number): number
	local trail = self.owned[id]
	return if trail then trail.last - trail.first + 1 else 0
end

-- Raccourcit le mur d'une moto à `maxCells` cases en libérant les plus anciennes.
-- Renvoie le nombre de cases libérées.
function Grid.trim(self: Grid, id: number, maxCells: number): number
	local trail = self.owned[id]
	if not trail then
		return 0
	end
	local freed = 0
	while trail.last - trail.first + 1 > maxCells do
		local k = trail.keys[trail.first]
		trail.keys[trail.first] = nil
		trail.first += 1
		if self.cells[k] == id then
			self.cells[k] = nil
		end
		freed += 1
	end
	return freed
end

-- Efface le mur d'une moto ; renvoie le nombre de cases libérées.
function Grid.clearOwner(self: Grid, id: number): number
	local trail = self.owned[id]
	if not trail then
		return 0
	end
	for i = trail.first, trail.last do
		self.cells[trail.keys[i]] = nil
	end
	self.owned[id] = nil
	return trail.last - trail.first + 1
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
-- Une moto éliminée reste sur place. Renvoie les ids éliminés à ce tick, dans l'ordre de `cycles`,
-- et pour chacun l'id du propriétaire du mur percuté (absent pour la bordure ou un face-à-face).
function Grid.step(self: Grid, cycles: { Cycle }): ({ number }, { [number]: number })
	local targets: { [Cycle]: number } = {}
	local claims: { [number]: number } = {}
	local hitBy: { [number]: number } = {}
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
				if self:inBounds(nx, nz) then
					hitBy[c.id] = self.cells[self:key(nx, nz)]
				end
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
	return eliminated, hitBy
end

-- Position dans le monde (X, Z en studs) du centre d'une case ; l'arène est centrée sur l'origine.
function Grid.toWorld(x: number, z: number, size: number, cellStuds: number): (number, number)
	local half = (size - 1) / 2
	return (x - half) * cellStuds, (z - half) * cellStuds
end

-- Apparitions de départ d'une équipe : une ligne à `margin` cases de son bord, tournée vers l'autre.
-- Équipe 1 à l'ouest face à l'est, équipe 2 à l'est face à l'ouest.
function Grid.teamSpawns(
	size: number,
	margin: number,
	team: number,
	count: number
): { { x: number, z: number, dir: Dir } }
	local x = if team == 1 then margin else size - 1 - margin
	local dir: Dir = if team == 1 then 1 else 3
	local span = size - 1 - 2 * margin
	local points = {}
	for i = 1, count do
		local z = margin + math.floor(span * i / (count + 1) + 0.5)
		table.insert(points, { x = x, z = z, dir = dir })
	end
	return points
end

export type SpawnQuery = {
	team: number, -- moitié de l'arène où chercher (1 = ouest, 2 = est)
	margin: number, -- distance minimale au bord
	clearAhead: number, -- cases libres exigées devant l'apparition
	enemies: { number }, -- têtes adverses à plat : x1, z1, x2, z2, ...
	minEnemyDistance: number, -- distance minimale (de Manhattan) à une tête adverse
	attempts: number,
}

-- Cherche au hasard une case de réapparition sûre dans la moitié de l'équipe, tournée vers le centre.
-- `rng(a, b)` renvoie un entier dans [a, b]. Renvoie nil si aucune case ne convient.
function Grid.findSpawn(
	self: Grid,
	query: SpawnQuery,
	rng: (number, number) -> number
): { x: number, z: number, dir: Dir }?
	local half = self.size // 2
	local x0 = if query.team == 1 then query.margin else half
	local x1 = if query.team == 1 then half - 1 else self.size - 1 - query.margin
	local dir: Dir = if query.team == 1 then 1 else 3
	local d = Grid.DIRS[dir]
	for _ = 1, query.attempts do
		local x = rng(x0, x1)
		local z = rng(query.margin, self.size - 1 - query.margin)
		local ok = self:isFree(x, z)
		for step = 1, query.clearAhead do
			if not ok then
				break
			end
			ok = self:isFree(x + d[1] * step, z + d[2] * step)
		end
		local e = query.enemies
		for i = 1, #e - 1, 2 do
			if not ok then
				break
			end
			ok = math.abs(e[i] - x) + math.abs(e[i + 1] - z) >= query.minEnemyDistance
		end
		if ok then
			return { x = x, z = z, dir = dir }
		end
	end
	return nil
end

-- Coins d'un mur (x1, z1, x2, z2, ...) dont le dernier est relié à la tête (hx, hz).
-- Retire les premiers coins devenus inutiles pour un mur de `maxCells` cases : le mur visible
-- s'étend de la tête jusqu'à `maxCells - 1` cases en arrière.
function Grid.trimPath(path: { number }, hx: number, hz: number, maxCells: number)
	local reach = maxCells - 1
	-- Longueur du mur depuis chaque coin jusqu'à la tête, en partant de la tête.
	local dist = math.abs(hx - path[#path - 1]) + math.abs(hz - path[#path])
	local keepFrom = #path - 1
	local i = #path - 3
	while i >= 1 and dist < reach do
		dist += math.abs(path[i + 2] - path[i]) + math.abs(path[i + 3] - path[i + 1])
		keepFrom = i
		i -= 2
	end
	if keepFrom > 1 then
		table.move(path, keepFrom, #path, 1)
		for j = #path, #path - keepFrom + 2, -1 do
			path[j] = nil
		end
	end
end

return Grid

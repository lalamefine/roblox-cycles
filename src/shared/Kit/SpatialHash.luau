--!strict
-- Grille de hachage spatial 2D (plan XZ) pour les requêtes de proximité.
-- Module pur : aucune API Roblox, testable sous Lune.

local SpatialHash = {}
SpatialHash.__index = SpatialHash

export type Entry<T> = {
	id: T,
	x: number,
	z: number,
}

type Cell<T> = { [T]: boolean }

export type SpatialHash<T> = typeof(setmetatable(
	{} :: {
		cellSize: number,
		cells: { [number]: Cell<T> },
		entries: { [T]: Entry<T> },
		count: number,
	},
	SpatialHash
))

-- Clé de cellule entière ; supporte des coordonnées de -2^20 à 2^20 cellules.
local OFFSET = 1048576
local SPAN = 2097152

local function cellKey(cx: number, cz: number): number
	return (cx + OFFSET) * SPAN + (cz + OFFSET)
end

function SpatialHash.new<T>(cellSize: number): SpatialHash<T>
	assert(cellSize > 0, "cellSize doit être > 0")
	return setmetatable({
		cellSize = cellSize,
		cells = {},
		entries = {},
		count = 0,
	}, SpatialHash) :: any
end

function SpatialHash.insert<T>(self: SpatialHash<T>, id: T, x: number, z: number)
	if self.entries[id] then
		self:move(id, x, z)
		return
	end
	local entry = { id = id, x = x, z = z }
	self.entries[id] = entry
	self.count += 1
	local key = cellKey(math.floor(x / self.cellSize), math.floor(z / self.cellSize))
	local cell = self.cells[key]
	if not cell then
		cell = {}
		self.cells[key] = cell
	end
	cell[id] = true
end

function SpatialHash.remove<T>(self: SpatialHash<T>, id: T): boolean
	local entry = self.entries[id]
	if not entry then
		return false
	end
	local key = cellKey(math.floor(entry.x / self.cellSize), math.floor(entry.z / self.cellSize))
	local cell = self.cells[key]
	if cell then
		cell[id] = nil
		if next(cell) == nil then
			self.cells[key] = nil
		end
	end
	self.entries[id] = nil
	self.count -= 1
	return true
end

function SpatialHash.move<T>(self: SpatialHash<T>, id: T, x: number, z: number)
	local entry = self.entries[id]
	if not entry then
		self:insert(id, x, z)
		return
	end
	local size = self.cellSize
	local oldKey = cellKey(math.floor(entry.x / size), math.floor(entry.z / size))
	local newKey = cellKey(math.floor(x / size), math.floor(z / size))
	entry.x = x
	entry.z = z
	if oldKey == newKey then
		return
	end
	local oldCell = self.cells[oldKey]
	if oldCell then
		oldCell[id] = nil
		if next(oldCell) == nil then
			self.cells[oldKey] = nil
		end
	end
	local newCell = self.cells[newKey]
	if not newCell then
		newCell = {}
		self.cells[newKey] = newCell
	end
	newCell[id] = true
end

function SpatialHash.get<T>(self: SpatialHash<T>, id: T): Entry<T>?
	return self.entries[id]
end

-- Renvoie les entrées à distance <= radius de (x, z).
function SpatialHash.queryRadius<T>(self: SpatialHash<T>, x: number, z: number, radius: number): { Entry<T> }
	local result = {}
	local size = self.cellSize
	local minX, maxX = math.floor((x - radius) / size), math.floor((x + radius) / size)
	local minZ, maxZ = math.floor((z - radius) / size), math.floor((z + radius) / size)
	local r2 = radius * radius
	for cx = minX, maxX do
		for cz = minZ, maxZ do
			local cell = self.cells[cellKey(cx, cz)]
			if cell then
				for id in cell do
					local e = self.entries[id]
					local dx, dz = e.x - x, e.z - z
					if dx * dx + dz * dz <= r2 then
						table.insert(result, e)
					end
				end
			end
		end
	end
	return result
end

return SpatialHash

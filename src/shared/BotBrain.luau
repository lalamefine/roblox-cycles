--!strict
-- Pilote des bots : à chaque tick, choisit tout droit, gauche ou droite.
-- Chaque option sûre est notée par l'espace libre accessible depuis sa case (remplissage borné),
-- pour éviter de s'enfermer dans un cul-de-sac. Module pur : aucune API Roblox.

local Grid = require("./Grid")

local BotBrain = {}

export type Options = {
	floodCap: number, -- cases explorées au plus par option
	mistakeChance: number, -- probabilité de prendre une option sûre au hasard
}

-- Nombre de cases libres atteignables depuis (x, z), plafonné à `cap`.
function BotBrain.reachable(grid: Grid.Grid, x: number, z: number, cap: number): number
	if not grid:isFree(x, z) then
		return 0
	end
	local seen = { [grid:key(x, z)] = true }
	local queue = { x, z }
	local head = 1
	local count = 0
	while head < #queue and count < cap do
		local cx, cz = queue[head], queue[head + 1]
		head += 2
		count += 1
		for dir = 0, 3 do
			local nx, nz = Grid.ahead(cx, cz, dir)
			if grid:isFree(nx, nz) then
				local k = grid:key(nx, nz)
				if not seen[k] then
					seen[k] = true
					table.insert(queue, nx)
					table.insert(queue, nz)
				end
			end
		end
	end
	return count
end

-- Renvoie le virage à appliquer : -1 (gauche), 0 (tout droit) ou 1 (droite).
-- `rng` renvoie un nombre dans [0, 1[ (Random:NextNumber côté serveur, déterministe en test).
function BotBrain.choose(grid: Grid.Grid, cycle: Grid.Cycle, options: Options, rng: () -> number): Grid.Turn
	local safe: { Grid.Turn } = {}
	local best: Grid.Turn = 0
	local bestScore = -1
	for _, turn in { 0, -1, 1 } do
		local dir = Grid.turn(cycle.dir, turn)
		local nx, nz = Grid.ahead(cycle.x, cycle.z, dir)
		if grid:isFree(nx, nz) then
			table.insert(safe, turn)
			-- Léger bonus pour tout droit : trajectoires plus lisibles et moins de zigzags.
			local score = BotBrain.reachable(grid, nx, nz, options.floodCap) + (if turn == 0 then 0.5 else 0)
			if score > bestScore then
				best, bestScore = turn, score
			end
		end
	end
	if #safe > 1 and rng() < options.mistakeChance then
		return safe[math.floor(rng() * #safe) + 1]
	end
	return best
end

return BotBrain

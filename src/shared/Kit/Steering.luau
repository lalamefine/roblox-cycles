--!strict
-- Comportements de pilotage 2D (plan XZ) pour les bots : chercher, fuir, errer.
-- Module pur : renvoie des directions normalisées (dx, dz), testable sous Lune.

local Steering = {}

local function normalize(dx: number, dz: number): (number, number)
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 1e-6 then
		return 0, 0
	end
	return dx / len, dz / len
end
Steering.normalize = normalize

function Steering.seek(fromX: number, fromZ: number, toX: number, toZ: number): (number, number)
	return normalize(toX - fromX, toZ - fromZ)
end

function Steering.flee(fromX: number, fromZ: number, threatX: number, threatZ: number): (number, number)
	return normalize(fromX - threatX, fromZ - threatZ)
end

-- Errance : tourne l'angle courant d'une valeur aléatoire bornée.
-- rng : fonction renvoyant un nombre dans [0, 1).
function Steering.wander(angle: number, maxTurn: number, rng: () -> number): (number, number, number)
	local newAngle = angle + (rng() * 2 - 1) * maxTurn
	return math.cos(newAngle), math.sin(newAngle), newAngle
end

-- Repousse vers l'intérieur d'une arène carrée centrée en (0, 0) quand on approche du bord.
-- Renvoie la direction corrigée.
function Steering.keepInside(
	x: number,
	z: number,
	dx: number,
	dz: number,
	halfSize: number,
	margin: number
): (number, number)
	local px, pz = 0, 0
	if x > halfSize - margin then
		px = -1
	elseif x < -halfSize + margin then
		px = 1
	end
	if z > halfSize - margin then
		pz = -1
	elseif z < -halfSize + margin then
		pz = 1
	end
	if px == 0 and pz == 0 then
		return dx, dz
	end
	return normalize(dx + px * 2, dz + pz * 2)
end

-- Combine des directions pondérées : { {dx, dz, poids}, ... }.
function Steering.blend(parts: { { number } }): (number, number)
	local sx, sz = 0, 0
	for _, p in parts do
		sx += p[1] * p[3]
		sz += p[2] * p[3]
	end
	return normalize(sx, sz)
end

return Steering

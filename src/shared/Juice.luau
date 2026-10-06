--!strict
-- Réglages et formules des effets visuels et sonores (« juice »). Module pur : aucune API Roblox.
-- Le client s'en sert pour doser les secousses de caméra, les sons et les particules.

local Juice = {
	-- Secousse de caméra : un « trauma » entre 0 et 1, dont l'amplitude affichée est trauma²
	SHAKE_DECAY = 1.6, -- trauma perdu par seconde
	SHAKE_MAX_OFFSET = 1.2, -- décalage maximal de la caméra, en studs
	SHAKE_MAX_ROLL = 4, -- roulis maximal, en degrés
	SHAKE_OWN_DEATH = 0.9, -- trauma quand sa propre moto explose
	SHAKE_NEARBY_DEATH = 0.6, -- trauma d'une explosion collée à la caméra
	SHAKE_RANGE = 70, -- au-delà de cette distance (studs), une explosion ne secoue plus
	SHAKE_KILL = 0.25, -- petit coup quand on élimine quelqu'un

	-- Champ de vision
	FOV_BASE = 70,
	FOV_GO_KICK = 12, -- élargissement au départ (« GO ! »), en degrés
	FOV_RECOVER = 3, -- vitesse de retour à FOV_BASE (par seconde, exponentielle)

	-- Moto
	LEAN_ANGLE = 22, -- inclinaison dans un virage, en degrés
	LEAN_RECOVER = 7, -- vitesse de redressement (par seconde, exponentielle)

	-- Murs
	WALL_DISSOLVE_SECONDS = 0.6, -- durée de la dissolution d'un mur effacé

	-- Sons : volume relatif d'un son positionné selon la distance à la caméra
	SOUND_NEAR = 20, -- volume plein en deçà (studs)
	SOUND_FAR = 160, -- silence au-delà (studs)
	PITCH_JITTER = 0.06, -- variation aléatoire de hauteur, ± en proportion
}

-- Trauma après `dt` secondes de décroissance.
function Juice.decay(trauma: number, dt: number): number
	return math.max(0, trauma - Juice.SHAKE_DECAY * dt)
end

-- Ajoute un coup au trauma courant, plafonné à 1.
function Juice.addTrauma(trauma: number, amount: number): number
	return math.clamp(trauma + amount, 0, 1)
end

-- Amplitude de la secousse (0 à 1) : trauma² pour que les petits coups restent discrets.
function Juice.shakeAmount(trauma: number): number
	return trauma * trauma
end

-- Trauma causé par une explosion à `distance` studs de la caméra : linéaire jusqu'à SHAKE_RANGE.
function Juice.explosionTrauma(distance: number): number
	if distance ~= distance or distance >= Juice.SHAKE_RANGE then
		return 0
	end
	return Juice.SHAKE_NEARBY_DEATH * (1 - math.max(0, distance) / Juice.SHAKE_RANGE)
end

-- Volume relatif (0 à 1) d'un son à `distance` studs de l'auditeur.
function Juice.distanceGain(distance: number): number
	if distance ~= distance or distance >= Juice.SOUND_FAR then
		return 0
	end
	if distance <= Juice.SOUND_NEAR then
		return 1
	end
	local t = (distance - Juice.SOUND_NEAR) / (Juice.SOUND_FAR - Juice.SOUND_NEAR)
	return (1 - t) * (1 - t)
end

-- Sens d'un virage entre deux directions de Grid (0 haut, 1 droite...) : 1 droite, -1 gauche, 0 aucun.
function Juice.turnSign(from: number, to: number): number
	local d = (to - from) % 4
	if d == 1 then
		return 1
	elseif d == 3 then
		return -1
	end
	return 0
end

-- Rapproche `value` de `target` de façon exponentielle, indépendamment de la cadence d'images.
function Juice.approach(value: number, target: number, speed: number, dt: number): number
	return target + (value - target) * math.exp(-speed * dt)
end

-- Hauteur de lecture d'un son, avec une variation tirée de `roll` (0 à 1) pour éviter la répétition.
function Juice.jitterPitch(base: number, roll: number): number
	return base * (1 + (roll * 2 - 1) * Juice.PITCH_JITTER)
end

return table.freeze(Juice)

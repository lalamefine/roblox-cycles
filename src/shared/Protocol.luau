--!strict
-- Noms des remotes et forme des messages entre serveur et client. Module pur : aucune API Roblox.
--
-- Client -> serveur (intentions seulement) :
--   Ready()       : le client est prêt, le serveur lui renvoie un Snapshot
--   Turn(turn)    : virage demandé, -1 (gauche) ou 1 (droite)
-- Serveur -> clients :
--   Snapshot(s)   : état complet, à chaque changement de phase et pour un client qui arrive
--   Tick(t)       : avance des motos, une fois par tick de course

local Protocol = {
	READY = "Ready",
	TURN = "Turn",
	SNAPSHOT = "Snapshot",
	TICK = "Tick",
}

export type Phase = "Waiting" | "Countdown" | "Racing" | "Results"

export type Rider = {
	id: number,
	name: string,
	userId: number, -- 0 pour un bot
	color: number, -- index dans Config.COLORS
	alive: boolean,
	x: number,
	z: number,
	dir: number,
	path: { number }, -- coins du mur à plat : x1, z1, x2, z2, ... (le premier est l'apparition)
}

export type Snapshot = {
	roundId: number,
	phase: Phase,
	riders: { Rider },
	timer: number, -- secondes restantes (attente, compte à rebours, résultats) ou écoulées (course)
	winner: number?, -- id du vainqueur pendant les résultats ; nil en cas d'égalité
}

export type Tick = {
	moves: { number }, -- à plat : id, x, z, dir pour chaque moto vivante
	dead: { number }, -- ids éliminés à ce tick
	cleared: { number }, -- ids dont le mur disparaît
}

function Protocol.isValidTurn(value: any): boolean
	return typeof(value) == "number" and (value == 1 or value == -1)
end

return table.freeze(Protocol)

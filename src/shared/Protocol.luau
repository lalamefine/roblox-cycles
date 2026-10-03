--!strict
-- Noms des remotes et forme des messages entre serveur et client. Module pur : aucune API Roblox.
--
-- Client -> serveur (intentions seulement) :
--   Ready()       : le client est prêt, le serveur lui renvoie un Snapshot
--   Turn(turn)    : virage demandé, -1 (gauche) ou 1 (droite)
-- Serveur -> clients :
--   Snapshot(s)   : état complet, à chaque changement de phase et pour un client qui arrive
--   Ranking(r)    : top du classement Elo, à chaque rafraîchissement et pour un client qui arrive
--   Tick(t)       : avance des motos, éliminations et réapparitions, une fois par tick de match

local Protocol = {
	READY = "Ready",
	TURN = "Turn",
	SNAPSHOT = "Snapshot",
	TICK = "Tick",
	RANKING = "Ranking",
}

export type Phase = "Waiting" | "Countdown" | "Playing" | "Results"

export type Rider = {
	id: number,
	name: string,
	userId: number, -- 0 pour un bot
	team: number, -- index dans Config.TEAMS
	alive: boolean,
	x: number,
	z: number,
	dir: number,
	path: { number }, -- coins du mur à plat : x1, z1, x2, z2, ... ; le mur va du premier coin à la tête
	kills: number,
	deaths: number,
	elo: number?, -- cote du joueur ; nil pour un bot
	eloDelta: number?, -- variation de cote du dernier match, pendant les résultats
}

export type Snapshot = {
	roundId: number,
	phase: Phase,
	riders: { Rider },
	timer: number, -- secondes restantes dans la phase
	teamKills: { number }, -- éliminations par équipe
	winnerTeam: number?, -- équipe gagnante pendant les résultats ; nil en cas d'égalité
}

export type Tick = {
	moves: { number }, -- à plat : id, x, z, dir pour chaque moto vivante
	dead: { number }, -- ids éliminés à ce tick
	killers: { number }, -- pour chaque id de `dead`, l'id crédité de l'élimination (0 : aucun)
	cleared: { number }, -- ids dont le mur disparaît
	spawns: { number }, -- à plat : id, x, z, dir pour chaque moto qui réapparaît
}

export type RankingEntry = { rank: number, name: string, elo: number }

function Protocol.isValidTurn(value: any): boolean
	return typeof(value) == "number" and (value == 1 or value == -1)
end

return table.freeze(Protocol)

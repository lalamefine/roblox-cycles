--!strict
-- Déroulement d'un match à mort par équipe : attente -> compte à rebours -> match -> résultats -> attente.
-- Pendant le match, une moto détruite réapparaît après un délai ; chaque élimination d'un adversaire
-- rapporte un point à l'équipe du tueur. À la fin du temps, l'équipe qui a le plus d'éliminations gagne,
-- puis celle qui a le moins de morts ; sinon égalité.
-- Module pur : aucune API Roblox. Le serveur appelle `update` à chaque tick avec le temps écoulé,
-- `kill` pour chaque moto détruite et `takeRespawns` pour savoir qui faire réapparaître.

local Round = {}
Round.__index = Round

export type Phase = "Waiting" | "Countdown" | "Playing" | "Results"

export type Settings = {
	countdown: number,
	duration: number, -- durée du match, en secondes
	resultsDuration: number,
	respawnDelay: number,
}

export type Stats = { kills: number, deaths: number }

export type Outcome = {
	winnerTeam: number?, -- nil en cas d'égalité
	teamKills: { number },
	teamDeaths: { number },
}

export type Round = typeof(setmetatable(
	{} :: {
		settings: Settings,
		phase: Phase,
		timer: number, -- temps restant dans la phase en cours
		teamOf: { [number]: number },
		stats: { [number]: Stats },
		teamKills: { number },
		teamDeaths: { number },
		alive: { [number]: boolean },
		respawnIn: { [number]: number }, -- id -> secondes avant réapparition
		outcome: Outcome?,
	},
	Round
))

export type Entry = { id: number, team: number }

function Round.new(settings: Settings): Round
	return setmetatable({
		settings = settings,
		phase = "Waiting" :: Phase,
		timer = 0,
		teamOf = {},
		stats = {},
		teamKills = { 0, 0 },
		teamDeaths = { 0, 0 },
		alive = {},
		respawnIn = {},
		outcome = nil,
	}, Round) :: any
end

-- Lance le compte à rebours avec ces participants (joueurs et bots), répartis en équipes 1 et 2.
function Round.start(self: Round, entries: { Entry })
	assert(self.phase == "Waiting", "un match est déjà en cours")
	assert(#entries >= 2, "il faut au moins deux participants")
	self.phase = "Countdown"
	self.timer = self.settings.countdown
	self.teamOf, self.stats, self.alive, self.respawnIn = {}, {}, {}, {}
	self.teamKills, self.teamDeaths = { 0, 0 }, { 0, 0 }
	self.outcome = nil
	for _, e in entries do
		assert(e.team == 1 or e.team == 2, "équipe 1 ou 2")
		self.teamOf[e.id] = e.team
		self.stats[e.id] = { kills = 0, deaths = 0 }
		self.alive[e.id] = true
	end
end

function Round.isAlive(self: Round, id: number): boolean
	return self.alive[id] == true
end

-- Enregistre la destruction de `victim`, percutée dans le mur de `wallOwner` (nil : bordure ou
-- face-à-face). Renvoie l'id crédité de l'élimination : un adversaire seulement, jamais soi-même
-- ni un coéquipier. Ignoré hors match ou si la moto est déjà détruite.
function Round.kill(self: Round, victim: number, wallOwner: number?): (boolean, number?)
	if self.phase ~= "Playing" or not self.alive[victim] then
		return false, nil
	end
	local team = self.teamOf[victim]
	self.alive[victim] = nil
	self.respawnIn[victim] = self.settings.respawnDelay
	self.stats[victim].deaths += 1
	self.teamDeaths[team] += 1
	local killer = wallOwner
	if killer == nil or self.teamOf[killer] == nil or self.teamOf[killer] == team then
		return true, nil
	end
	self.stats[killer].kills += 1
	self.teamKills[self.teamOf[killer]] += 1
	return true, killer
end

-- Ids dont le délai de réapparition est écoulé ; ils redeviennent vivants.
-- Le serveur les replace sur la grille, ou appelle `delayRespawn` s'il ne trouve pas de place.
function Round.takeRespawns(self: Round): { number }
	local ready = {}
	if self.phase ~= "Playing" then
		return ready
	end
	for id, t in self.respawnIn do
		if t <= 0 then
			table.insert(ready, id)
		end
	end
	table.sort(ready)
	for _, id in ready do
		self.respawnIn[id] = nil
		self.alive[id] = true
	end
	return ready
end

function Round.delayRespawn(self: Round, id: number, seconds: number)
	self.alive[id] = nil
	self.respawnIn[id] = seconds
end

local function decide(kills: { number }, deaths: { number }): number?
	if kills[1] ~= kills[2] then
		return if kills[1] > kills[2] then 1 else 2
	end
	if deaths[1] ~= deaths[2] then
		return if deaths[1] < deaths[2] then 1 else 2
	end
	return nil
end

-- Fait avancer le temps. Renvoie la nouvelle phase si elle a changé, sinon nil.
function Round.update(self: Round, dt: number): Phase?
	if self.phase == "Countdown" then
		self.timer -= dt
		if self.timer <= 0 then
			self.phase = "Playing"
			self.timer = self.settings.duration
			return self.phase
		end
	elseif self.phase == "Playing" then
		self.timer -= dt
		for id, t in self.respawnIn do
			self.respawnIn[id] = t - dt
		end
		if self.timer <= 0 then
			self.outcome = {
				winnerTeam = decide(self.teamKills, self.teamDeaths),
				teamKills = table.clone(self.teamKills),
				teamDeaths = table.clone(self.teamDeaths),
			}
			self.phase = "Results"
			self.timer = self.settings.resultsDuration
			return self.phase
		end
	elseif self.phase == "Results" then
		self.timer -= dt
		if self.timer <= 0 then
			self.phase = "Waiting"
			self.timer = 0
			return self.phase
		end
	end
	return nil
end

return Round

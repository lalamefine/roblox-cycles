--!strict
-- Déroulement d'une manche : attente -> compte à rebours -> course -> résultats -> attente.
-- Module pur : aucune API Roblox. Le serveur appelle `update` à chaque tick avec le temps écoulé,
-- et `eliminate` pour chaque moto détruite ; les changements de phase sont renvoyés pour être diffusés.

local Round = {}
Round.__index = Round

export type Phase = "Waiting" | "Countdown" | "Racing" | "Results"

export type Settings = {
	countdown: number,
	timeLimit: number,
	resultsDuration: number,
}

export type Outcome = {
	winner: number?, -- nil en cas d'égalité
	survivors: { number }, -- motos encore en vie à la fin (plusieurs si limite de temps)
	order: { number }, -- ordre d'élimination, du premier éliminé au dernier
}

export type Round = typeof(setmetatable(
	{} :: {
		settings: Settings,
		phase: Phase,
		timer: number, -- temps restant dans la phase (compte à rebours, résultats) ou écoulé (course)
		riders: { number },
		alive: { [number]: boolean },
		aliveCount: number,
		order: { number },
		outcome: Outcome?,
	},
	Round
))

function Round.new(settings: Settings): Round
	return setmetatable({
		settings = settings,
		phase = "Waiting" :: Phase,
		timer = 0,
		riders = {},
		alive = {},
		aliveCount = 0,
		order = {},
		outcome = nil,
	}, Round) :: any
end

-- Lance le compte à rebours avec ces participants (joueurs et bots). Il en faut au moins deux.
function Round.start(self: Round, riders: { number })
	assert(self.phase == "Waiting", "une manche est déjà en cours")
	assert(#riders >= 2, "il faut au moins deux participants")
	self.phase = "Countdown"
	self.timer = self.settings.countdown
	self.riders = table.clone(riders)
	self.alive = {}
	for _, id in riders do
		self.alive[id] = true
	end
	self.aliveCount = #riders
	self.order = {}
	self.outcome = nil
end

function Round.isAlive(self: Round, id: number): boolean
	return self.alive[id] == true
end

function Round.survivors(self: Round): { number }
	local list = {}
	for _, id in self.riders do
		if self.alive[id] then
			table.insert(list, id)
		end
	end
	return list
end

-- Élimine un participant pendant la course. Ignoré hors course ou s'il est déjà éliminé.
function Round.eliminate(self: Round, id: number): boolean
	if self.phase ~= "Racing" or not self.alive[id] then
		return false
	end
	self.alive[id] = nil
	self.aliveCount -= 1
	table.insert(self.order, id)
	return true
end

local function finish(self: Round)
	local survivors = self:survivors()
	self.outcome = {
		winner = if #survivors == 1 then survivors[1] else nil,
		survivors = survivors,
		order = table.clone(self.order),
	}
	self.phase = "Results"
	self.timer = self.settings.resultsDuration
end

-- Fait avancer le temps. Renvoie la nouvelle phase si elle a changé, sinon nil.
-- La fin de course est vérifiée à chaque appel : appeler `eliminate` pour tout le tick d'abord,
-- puis `update`, pour que deux motos détruites au même tick donnent une égalité.
function Round.update(self: Round, dt: number): Phase?
	if self.phase == "Countdown" then
		self.timer -= dt
		if self.timer <= 0 then
			self.phase = "Racing"
			self.timer = 0
			return self.phase
		end
	elseif self.phase == "Racing" then
		self.timer += dt
		if self.aliveCount <= 1 or self.timer >= self.settings.timeLimit then
			finish(self)
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

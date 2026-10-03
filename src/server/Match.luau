--!strict
-- Boucle de jeu serveur : match à mort par équipe avec réapparition, avance des motos à pas fixe,
-- murs de longueur limitée, bots, score par équipe.
-- Le serveur fait autorité ; les clients n'envoient que des virages (Protocol.TURN).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local Round = require(Shared.Round)
local BotBrain = require(Shared.BotBrain)
local Protocol = require(Shared.Protocol)
local Net = require(Shared.Kit.Net)

local TICK_DT = 1 / Config.TICK_RATE
local MAX_STEPS_PER_FRAME = 5
local SPAWN_ATTEMPTS = 60

type Rider = {
	id: number,
	team: number,
	name: string,
	player: Player?,
	cycle: Grid.Cycle,
	path: { number },
	eloDelta: number?,
}

-- Joueur présent à la fin d'un match, avec son équipe et ses statistiques de la partie.
export type Participant = { player: Player, team: number, kills: number, deaths: number }

export type Hooks = {
	-- Cote affichée d'un joueur (nil si son profil n'est pas encore chargé).
	ratingOf: (player: Player) -> number?,
	-- Un client vient de se connecter (pour lui envoyer ce qui ne passe pas par l'instantané).
	onReady: (player: Player) -> (),
	-- Fin de match : renvoie la variation de cote de chaque joueur, pour l'afficher.
	onMatchEnd: (outcome: Round.Outcome, participants: { Participant }) -> { [Player]: number },
}

local Match = {}

local hooks: Hooks? = nil
local rng = Random.new()
local round = Round.new({
	countdown = Config.COUNTDOWN,
	duration = Config.MATCH_DURATION,
	resultsDuration = Config.RESULTS_DURATION,
	respawnDelay = Config.RESPAWN_DELAY,
})
local grid = Grid.new(Config.ARENA_SIZE)
local riders: { Rider } = {}
local riderByPlayer: { [Player]: Rider } = {}
local cycles: { Grid.Cycle } = {}
local roundId = 0
local lobbyTimer = Config.LOBBY_WAIT
local botOptions: BotBrain.Options = {
	floodCap = Config.BOT_FLOOD_CAP,
	mistakeChance = Config.BOT_MISTAKE_CHANCE,
}

local function botName(id: number): string
	return `Bot {id}`
end

local function snapshot(): Protocol.Snapshot
	local list: { Protocol.Rider } = {}
	for _, r in riders do
		local stats = round.stats[r.id] or { kills = 0, deaths = 0 }
		table.insert(list, {
			id = r.id,
			name = r.name,
			userId = if r.player then r.player.UserId else 0,
			team = r.team,
			alive = r.cycle.alive,
			x = r.cycle.x,
			z = r.cycle.z,
			dir = r.cycle.dir,
			path = r.path,
			kills = stats.kills,
			deaths = stats.deaths,
			elo = if r.player and hooks then hooks.ratingOf(r.player) else nil,
			eloDelta = r.eloDelta,
		})
	end
	return {
		roundId = roundId,
		phase = round.phase,
		riders = list,
		timer = if round.phase == "Waiting" then lobbyTimer else round.timer,
		teamKills = table.clone(round.teamKills),
		winnerTeam = if round.phase == "Results" and round.outcome then round.outcome.winnerTeam else nil,
	}
end

local function broadcastSnapshot()
	Net.event(Protocol.SNAPSHOT):FireAllClients(snapshot())
end

local function humansIn(team: number): number
	local n = 0
	for _, r in riders do
		if r.team == team and r.player then
			n += 1
		end
	end
	return n
end

-- Confie à un joueur la moto d'un bot, dans l'équipe qui compte le moins d'humains.
-- Renvoie faux si toutes les places sont prises par des joueurs.
local function seat(player: Player): boolean
	if riderByPlayer[player] then
		return true
	end
	local first = if humansIn(1) <= humansIn(2) then 1 else 2
	for _, team in { first, 3 - first } do
		for _, r in riders do
			if r.team == team and r.player == nil then
				r.player = player
				r.name = player.DisplayName
				r.cycle.turns = {}
				riderByPlayer[player] = r
				return true
			end
		end
	end
	return false
end

local function startRound()
	roundId += 1
	grid = Grid.new(Config.ARENA_SIZE)
	riders, riderByPlayer, cycles = {}, {}, {}

	local entries: { Round.Entry } = {}
	for team = 1, 2 do
		local points = Grid.teamSpawns(Config.ARENA_SIZE, Config.SPAWN_MARGIN, team, Config.TEAM_SIZE)
		for _, p in points do
			local id = #riders + 1
			local cycle = Grid.newCycle(id, p.x, p.z, p.dir)
			grid:occupy(p.x, p.z, id)
			table.insert(riders, {
				id = id,
				team = team,
				name = botName(id),
				player = nil,
				cycle = cycle,
				path = { p.x, p.z },
				eloDelta = nil,
			})
			table.insert(cycles, cycle)
			table.insert(entries, { id = id, team = team })
		end
	end
	for _, player in Players:GetPlayers() do
		seat(player)
	end
	round:start(entries)
	broadcastSnapshot()
end

local function enemyHeads(team: number): { number }
	local heads = {}
	for _, r in riders do
		if r.team ~= team and r.cycle.alive then
			table.insert(heads, r.cycle.x)
			table.insert(heads, r.cycle.z)
		end
	end
	return heads
end

local function respawn(r: Rider): boolean
	local spot = grid:findSpawn({
		team = r.team,
		margin = Config.SPAWN_MARGIN,
		clearAhead = Config.SPAWN_CLEAR_AHEAD,
		enemies = enemyHeads(r.team),
		minEnemyDistance = Config.SPAWN_MIN_ENEMY_DISTANCE,
		attempts = SPAWN_ATTEMPTS,
	}, function(a, b)
		return rng:NextInteger(a, b)
	end)
	if not spot then
		return false
	end
	grid:clearOwner(r.id)
	local c = r.cycle
	c.x, c.z, c.dir, c.alive, c.turns = spot.x, spot.z, spot.dir, true, {}
	grid:occupy(spot.x, spot.z, r.id)
	r.path = { spot.x, spot.z }
	return true
end

local function play()
	-- Les bots décident avant que tout le monde avance.
	for _, r in riders do
		if r.cycle.alive and r.player == nil then
			local turn = BotBrain.choose(grid, r.cycle, botOptions, function()
				return rng:NextNumber()
			end)
			r.cycle.turns = if turn ~= 0 then { turn } else {}
		end
	end

	local before: { [number]: { number } } = {}
	for _, r in riders do
		before[r.id] = { r.cycle.x, r.cycle.z, r.cycle.dir }
	end

	local dead, hitBy = grid:step(cycles)

	local moves = {}
	for _, r in riders do
		local c = r.cycle
		if c.alive then
			local b = before[r.id]
			if c.dir ~= b[3] then
				-- Virage : la case quittée devient un coin du mur.
				table.insert(r.path, b[1])
				table.insert(r.path, b[2])
			end
			grid:trim(r.id, Config.TRAIL_MAX_LENGTH)
			Grid.trimPath(r.path, c.x, c.z, Config.TRAIL_MAX_LENGTH)
			table.insert(moves, r.id)
			table.insert(moves, c.x)
			table.insert(moves, c.z)
			table.insert(moves, c.dir)
		end
	end

	local killers = {}
	local cleared = {}
	for _, id in dead do
		local _, killer = round:kill(id, hitBy[id])
		table.insert(killers, killer or 0)
		if Config.TRAIL_CLEARS_ON_DEATH then
			grid:clearOwner(id)
			table.insert(cleared, id)
		end
	end

	local spawns = {}
	for _, id in round:takeRespawns() do
		local r = riders[id]
		if respawn(r) then
			table.insert(spawns, id)
			table.insert(spawns, r.cycle.x)
			table.insert(spawns, r.cycle.z)
			table.insert(spawns, r.cycle.dir)
		else
			round:delayRespawn(id, Config.RESPAWN_RETRY)
		end
	end

	local tick: Protocol.Tick = { moves = moves, dead = dead, killers = killers, cleared = cleared, spawns = spawns }
	Net.event(Protocol.TICK):FireAllClients(tick)
end

local function finishRound()
	local outcome = round.outcome
	if not outcome or not hooks then
		return
	end
	local participants: { Participant } = {}
	for _, r in riders do
		if r.player and r.player.Parent then
			local stats = round.stats[r.id]
			table.insert(participants, {
				player = r.player,
				team = r.team,
				kills = stats.kills,
				deaths = stats.deaths,
			})
		end
	end
	local deltas = hooks.onMatchEnd(outcome, participants)
	for _, r in riders do
		r.eloDelta = if r.player then deltas[r.player] else nil
	end
end

local function step()
	if round.phase == "Waiting" then
		if #Players:GetPlayers() == 0 then
			lobbyTimer = Config.LOBBY_WAIT
			return
		end
		lobbyTimer -= TICK_DT
		if lobbyTimer <= 0 then
			startRound()
		end
		return
	end

	if round.phase == "Playing" then
		play()
	end
	local changed = round:update(TICK_DT)
	if changed == "Results" then
		finishRound()
	elseif changed == "Waiting" then
		lobbyTimer = Config.LOBBY_WAIT
	end
	if changed then
		broadcastSnapshot()
	end
end

function Match.start(matchHooks: Hooks)
	hooks = matchHooks
	Players.CharacterAutoLoads = false
	Net.setup({ events = { Protocol.READY, Protocol.TURN, Protocol.SNAPSHOT, Protocol.TICK, Protocol.RANKING } })

	Net.onServerEvent(Protocol.READY, function(player: Player)
		Net.event(Protocol.SNAPSHOT):FireClient(player, snapshot())
		matchHooks.onReady(player)
	end, { burst = 2, perSecond = 0.5 })

	Net.onServerEvent(Protocol.TURN, function(player: Player, turn: any)
		if not Protocol.isValidTurn(turn) or round.phase ~= "Playing" then
			return
		end
		local rider = riderByPlayer[player]
		if rider then
			Grid.queueTurn(rider.cycle, turn, Config.MAX_QUEUED_TURNS)
		end
	end, { burst = 10, perSecond = 15 })

	-- Un joueur qui arrive en cours de match reprend la moto d'un bot.
	Players.PlayerAdded:Connect(function(player)
		if (round.phase == "Countdown" or round.phase == "Playing") and seat(player) then
			broadcastSnapshot()
		end
	end)

	-- Un joueur qui part laisse sa moto à un bot ; son équipe garde ses éliminations.
	Players.PlayerRemoving:Connect(function(player)
		local rider = riderByPlayer[player]
		riderByPlayer[player] = nil
		if not rider then
			return
		end
		rider.player = nil
		rider.name = botName(rider.id)
		if round.phase ~= "Waiting" then
			broadcastSnapshot()
		end
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		local steps = 0
		while accumulator >= TICK_DT and steps < MAX_STEPS_PER_FRAME do
			accumulator -= TICK_DT
			steps += 1
			step()
		end
		if steps == MAX_STEPS_PER_FRAME then
			-- Serveur en retard : on abandonne le retard plutôt que d'accélérer la partie.
			accumulator = 0
		end
	end)
end

return Match

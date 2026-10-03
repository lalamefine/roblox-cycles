--!strict
-- Boucle de jeu serveur : salle d'attente, manches, avance des motos à pas fixe, bots, victoires.
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
local Signal = require(Shared.Kit.Signal)

local TICK_DT = 1 / Config.TICK_RATE
local MAX_STEPS_PER_FRAME = 5

type Rider = {
	id: number,
	name: string,
	player: Player?,
	color: number,
	cycle: Grid.Cycle,
	path: { number },
}

local Match = {}
-- Fin de manche : vainqueur (nil si égalité) et joueurs humains qui ont participé.
Match.RoundEnded = Signal.new() :: Signal.Signal<Player?, { Player }>

local rng = Random.new()
local round = Round.new({
	countdown = Config.COUNTDOWN,
	timeLimit = Config.ROUND_TIME_LIMIT,
	resultsDuration = Config.RESULTS_DURATION,
})
local grid = Grid.new(Config.ARENA_SIZE)
local riders: { Rider } = {}
local riderByPlayer: { [Player]: Rider } = {}
local cycles: { Grid.Cycle } = {}
local roundId = 0
local lobbyTimer = Config.LOBBY_WAIT
local pendingDead: { number } = {}
local botOptions: BotBrain.Options = {
	floodCap = Config.BOT_FLOOD_CAP,
	mistakeChance = Config.BOT_MISTAKE_CHANCE,
}

local function snapshot(): Protocol.Snapshot
	local list: { Protocol.Rider } = {}
	for _, r in riders do
		table.insert(list, {
			id = r.id,
			name = r.name,
			userId = if r.player then r.player.UserId else 0,
			color = r.color,
			alive = r.cycle.alive,
			x = r.cycle.x,
			z = r.cycle.z,
			dir = r.cycle.dir,
			path = r.path,
		})
	end
	local winner = nil
	if round.phase == "Results" and round.outcome then
		winner = round.outcome.winner
	end
	return {
		roundId = roundId,
		phase = round.phase,
		riders = list,
		timer = if round.phase == "Waiting" then lobbyTimer else round.timer,
		winner = winner,
	}
end

local function broadcastSnapshot()
	Net.event(Protocol.SNAPSHOT):FireAllClients(snapshot())
end

local function startRound()
	roundId += 1
	grid = Grid.new(Config.ARENA_SIZE)
	riders, riderByPlayer, cycles, pendingDead = {}, {}, {}, {}

	local humans = Players:GetPlayers()
	local points = Grid.spawnPoints(Config.ARENA_SIZE, Config.MAX_RIDERS, Config.SPAWN_MARGIN)
	-- Mélange des apparitions pour varier les duels d'une manche à l'autre.
	for i = #points, 2, -1 do
		local j = rng:NextInteger(1, i)
		points[i], points[j] = points[j], points[i]
	end

	local ids = {}
	for i = 1, Config.MAX_RIDERS do
		local p = points[i]
		local player: Player? = humans[i]
		local cycle = Grid.newCycle(i, p.x, p.z, p.dir)
		grid:occupy(p.x, p.z, i)
		local rider: Rider = {
			id = i,
			name = if player then player.DisplayName else `Bot {i}`,
			player = player,
			color = i,
			cycle = cycle,
			path = { p.x, p.z },
		}
		table.insert(riders, rider)
		table.insert(cycles, cycle)
		table.insert(ids, i)
		if player then
			riderByPlayer[player] = rider
		end
	end
	round:start(ids)
	broadcastSnapshot()
end

local function eliminateNow(rider: Rider)
	rider.cycle.alive = false
	table.insert(pendingDead, rider.id)
end

local function race()
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

	local dead = grid:step(cycles)
	for _, id in pendingDead do
		table.insert(dead, id)
	end
	pendingDead = {}

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
			table.insert(moves, r.id)
			table.insert(moves, c.x)
			table.insert(moves, c.z)
			table.insert(moves, c.dir)
		end
	end

	local cleared = {}
	for _, id in dead do
		round:eliminate(id)
		if Config.TRAIL_CLEARS_ON_DEATH then
			grid:clearOwner(id)
			table.insert(cleared, id)
		end
	end

	local tick: Protocol.Tick = { moves = moves, dead = dead, cleared = cleared }
	Net.event(Protocol.TICK):FireAllClients(tick)
end

local function finishRound()
	local outcome = round.outcome
	local winner: Player? = nil
	local participants = {}
	for _, r in riders do
		if r.player and r.player.Parent then
			table.insert(participants, r.player)
			if outcome and outcome.winner == r.id then
				winner = r.player
			end
		end
	end
	Match.RoundEnded:Fire(winner, participants)
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

	if round.phase == "Racing" then
		race()
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

function Match.start()
	Players.CharacterAutoLoads = false
	Net.setup({ events = { Protocol.READY, Protocol.TURN, Protocol.SNAPSHOT, Protocol.TICK } })

	Net.onServerEvent(Protocol.READY, function(player: Player)
		Net.event(Protocol.SNAPSHOT):FireClient(player, snapshot())
	end, { burst = 2, perSecond = 0.5 })

	Net.onServerEvent(Protocol.TURN, function(player: Player, turn: any)
		if not Protocol.isValidTurn(turn) or round.phase ~= "Racing" then
			return
		end
		local rider = riderByPlayer[player]
		if rider then
			Grid.queueTurn(rider.cycle, turn, Config.MAX_QUEUED_TURNS)
		end
	end, { burst = 10, perSecond = 15 })

	Players.PlayerRemoving:Connect(function(player)
		local rider = riderByPlayer[player]
		riderByPlayer[player] = nil
		if not rider or not rider.cycle.alive then
			return
		end
		if round.phase == "Racing" then
			eliminateNow(rider)
		else
			-- Départ pendant le compte à rebours : un bot reprend la moto.
			rider.player = nil
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

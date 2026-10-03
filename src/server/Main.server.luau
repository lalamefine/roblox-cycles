--!strict
-- Point d'entrée serveur de RobloxCycles : profils, cote Elo, classements et match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Elo = require(ReplicatedStorage.Shared.Elo)
local Protocol = require(ReplicatedStorage.Shared.Protocol)
local Net = require(ReplicatedStorage.Shared.Kit.Net)
local Data = require(script.Parent.KitServer.Data)
local Leaderboard = require(script.Parent.KitServer.Leaderboard)
local Match = require(script.Parent.Match)

local RANKING_SIZE = 10

local wins = Leaderboard.new("RobloxCycles_Wins")
-- La cote peut baisser : on garde la dernière, pas la meilleure.
local elo = Leaderboard.new("RobloxCycles_Elo", { size = RANKING_SIZE, keepBest = false })

Data.configure({
	storeName = "RobloxCycles_PlayerData_v1",
	template = { wins = 0, rounds = 0, elo = Config.ELO_START, kills = 0, deaths = 0 },
})

local function setStat(player: Player, name: string, value: number)
	local stats = player:FindFirstChild("leaderstats")
	local v = stats and stats:FindFirstChild(name)
	if v and v:IsA("IntValue") then
		v.Value = value
	end
end

-- Cote et victoires visibles dans la liste des joueurs.
Data.ProfileLoaded:Connect(function(player, profile)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local function stat(name: string, initial: number)
		local value = Instance.new("IntValue")
		value.Name = name
		value.Value = initial
		value.Parent = stats
	end
	stat("Elo", profile.data.elo)
	stat("Victoires", profile.data.wins)
	stats.Parent = player
	elo:submit(player.UserId, profile.data.elo)
end)

local function ratingOf(player: Player): number?
	local profile = Data.get(player)
	return if profile then profile.data.elo else nil
end

-- Top du classement avec les noms des joueurs (mis en cache, la résolution peut attendre le réseau).
local names: { [number]: string } = {}
local ranking: { Protocol.RankingEntry } = {}

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local resolved = if ok and type(name) == "string" then name else `#{userId}`
	names[userId] = resolved
	return resolved
end

elo.Updated:Connect(function(entries)
	task.spawn(function()
		local list: { Protocol.RankingEntry } = {}
		for _, e in entries do
			table.insert(list, { rank = e.rank, name = nameOf(e.userId), elo = e.score })
		end
		ranking = list
		Net.event(Protocol.RANKING):FireAllClients(ranking)
	end)
end)

local function onMatchEnd(outcome, participants: { Match.Participant }): { [Player]: number }
	-- Cote moyenne de chaque équipe : joueurs présents à la fin, bots à leur cote fixe.
	local ratings: { { number } } = { {}, {} }
	for _, p in participants do
		table.insert(ratings[p.team], ratingOf(p.player) or Config.ELO_START)
	end
	for team = 1, 2 do
		while #ratings[team] < Config.TEAM_SIZE do
			table.insert(ratings[team], Config.ELO_BOT)
		end
	end
	local delta1, delta2 = Elo.teamDeltas(ratings[1], ratings[2], outcome.winnerTeam, Config.ELO_K)

	local deltas: { [Player]: number } = {}
	for _, p in participants do
		local profile = Data.get(p.player)
		if profile then
			local d = if p.team == 1 then delta1 else delta2
			local data = profile.data
			data.rounds += 1
			data.kills += p.kills
			data.deaths += p.deaths
			data.elo = math.max(0, data.elo + d)
			deltas[p.player] = d
			if outcome.winnerTeam == p.team then
				data.wins += 1
				wins:submit(p.player.UserId, data.wins)
				setStat(p.player, "Victoires", data.wins)
			end
			elo:submit(p.player.UserId, data.elo)
			setStat(p.player, "Elo", data.elo)
		end
	end
	return deltas
end

Match.start({
	ratingOf = ratingOf,
	onReady = function(player)
		Net.event(Protocol.RANKING):FireClient(player, ranking)
	end,
	onMatchEnd = onMatchEnd,
})

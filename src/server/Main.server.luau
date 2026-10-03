--!strict
-- Point d'entrée serveur de RobloxCycles.

local Data = require(script.Parent.KitServer.Data)
local Leaderboard = require(script.Parent.KitServer.Leaderboard)
local Match = require(script.Parent.Match)

local wins = Leaderboard.new("RobloxCycles_Wins")

Data.configure({
	storeName = "RobloxCycles_PlayerData_v1",
	template = { wins = 0, rounds = 0 },
})

-- Victoires visibles dans la liste des joueurs.
Data.ProfileLoaded:Connect(function(player, profile)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local value = Instance.new("IntValue")
	value.Name = "Victoires"
	value.Value = profile.data.wins
	value.Parent = stats
	stats.Parent = player
end)

Match.RoundEnded:Connect(function(winner, participants)
	for _, player in participants do
		local profile = Data.get(player)
		if profile then
			profile.data.rounds += 1
		end
	end
	if not winner then
		return
	end
	local profile = Data.get(winner)
	if profile then
		profile.data.wins += 1
		wins:submit(winner.UserId, profile.data.wins)
		local stats = winner:FindFirstChild("leaderstats")
		local value = stats and stats:FindFirstChild("Victoires")
		if value and value:IsA("IntValue") then
			value.Value = profile.data.wins
		end
	end
end)

Match.start()

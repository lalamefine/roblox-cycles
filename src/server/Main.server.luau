--!strict
-- Point d'entrée serveur du modèle. Chaque jeu remplace ce fichier.

local Net = require(game:GetService("ReplicatedStorage").Shared.Kit.Net)
local Data = require(script.Parent.KitServer.Data)

Net.setup({ events = { "Hello" } })

Data.configure({
	storeName = "RobloxCycles_PlayerData_v1",
	template = { visits = 0 },
})

Data.ProfileLoaded:Connect(function(player, profile)
	profile.data.visits += 1
	Net.event("Hello"):FireClient(player, profile.data.visits)
end)

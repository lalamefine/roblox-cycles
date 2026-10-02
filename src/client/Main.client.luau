--!strict
-- Point d'entrée client du modèle. Chaque jeu remplace ce fichier.

local Net = require(game:GetService("ReplicatedStorage").Shared.Kit.Net)

Net.event("Hello").OnClientEvent:Connect(function(visits: number)
	print(`roblox-kit fonctionne : visite n°{visits}`)
end)

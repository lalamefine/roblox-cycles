--!strict
-- Cote Elo par équipe. La cote d'une équipe est la moyenne de celles de ses membres (bots compris,
-- à une cote fixe) ; chaque membre humain gagne ou perd le même nombre de points.
-- Module pur : aucune API Roblox.

local Elo = {}

-- Probabilité de victoire de A contre B.
function Elo.expected(ratingA: number, ratingB: number): number
	return 1 / (1 + 10 ^ ((ratingB - ratingA) / 400))
end

local function average(ratings: { number }): number
	assert(#ratings > 0, "équipe vide")
	local sum = 0
	for _, r in ratings do
		sum += r
	end
	return sum / #ratings
end

-- Variation de cote de chaque équipe, arrondie à l'entier. `winnerTeam` : 1, 2 ou nil (égalité).
function Elo.teamDeltas(team1: { number }, team2: { number }, winnerTeam: number?, k: number): (number, number)
	local expected1 = Elo.expected(average(team1), average(team2))
	local score1 = if winnerTeam == 1 then 1 elseif winnerTeam == 2 then 0 else 0.5
	local delta = math.floor(k * (score1 - expected1) + 0.5)
	return delta, -delta
end

return Elo

--!strict
-- Constantes d'équilibrage de RobloxCycles. Module pur : aucune API Roblox.
-- Les distances sont en cases de grille ; une case mesure CELL_STUDS studs dans le monde.

local Config = {
	-- Arène
	ARENA_SIZE = 128, -- côté de l'arène carrée, en cases
	CELL_STUDS = 2, -- taille d'une case en studs
	SPAWN_MARGIN = 16, -- distance minimale entre une apparition et le bord, en cases

	-- Mouvement : une moto avance d'une case par tick
	TICK_RATE = 15, -- ticks serveur par seconde (15 cases/s, soit 30 studs/s)
	MAX_QUEUED_TURNS = 2, -- virages mémorisés d'avance, pour enchaîner un demi-tour serré
	TRAIL_CLEARS_ON_DEATH = true, -- le mur d'une moto éliminée disparaît, comme dans Tron

	-- Manche
	MAX_RIDERS = 6, -- places par manche, complétées par des bots
	COUNTDOWN = 3, -- secondes avant le départ
	ROUND_TIME_LIMIT = 120, -- au-delà, la manche se termine sur une égalité entre survivants
	RESULTS_DURATION = 5, -- secondes d'affichage du vainqueur

	-- Bots
	BOT_FLOOD_CAP = 200, -- cases explorées au plus pour estimer l'espace libre d'une option
	BOT_MISTAKE_CHANCE = 0.02, -- probabilité de choisir une option sûre au hasard plutôt que la meilleure
}

return table.freeze(Config)

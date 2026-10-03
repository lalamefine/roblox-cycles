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
	TRAIL_MAX_LENGTH = 80, -- cases d'un mur, tête comprise (un peu plus de 5 s de course)

	-- Match à mort par équipe
	LOBBY_WAIT = 5, -- secondes d'attente entre deux matchs dès qu'un joueur est présent
	TEAM_SIZE = 4, -- places par équipe, complétées par des bots
	COUNTDOWN = 3, -- secondes avant le départ
	MATCH_DURATION = 180, -- durée d'un match ; l'équipe qui a le plus d'éliminations gagne
	RESULTS_DURATION = 8, -- secondes d'affichage du score final
	RESPAWN_DELAY = 3, -- secondes entre la destruction d'une moto et sa réapparition
	RESPAWN_RETRY = 0.5, -- nouvel essai si aucune case de réapparition sûre n'est libre
	SPAWN_CLEAR_AHEAD = 12, -- cases libres exigées devant une réapparition
	SPAWN_MIN_ENEMY_DISTANCE = 16, -- distance minimale entre une réapparition et une tête adverse

	-- Classement Elo
	ELO_START = 1000, -- cote d'un nouveau joueur
	ELO_BOT = 1000, -- cote fixe d'un bot dans le calcul de la moyenne d'équipe
	ELO_K = 32, -- variation maximale par match

	-- Bots
	BOT_FLOOD_CAP = 200, -- cases explorées au plus pour estimer l'espace libre d'une option
	BOT_MISTAKE_CHANCE = 0.02, -- probabilité de choisir une option sûre au hasard plutôt que la meilleure

	-- Rendu (client)
	WALL_HEIGHT = 3, -- hauteur des murs de lumière, en studs
	WALL_THICKNESS = 0.4, -- épaisseur des murs, en studs
	-- Équipes : nom et couleur en RVB 0-255 (convertie en Color3 côté client)
	TEAMS = {
		{ name = "Cyan", color = { 0, 230, 255 } },
		{ name = "Orange", color = { 255, 140, 0 } },
	},
}

return table.freeze(Config)

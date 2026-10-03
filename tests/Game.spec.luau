--!strict
local framework = require("./framework")
local Config = require("../src/shared/Config")
local Grid = require("../src/shared/Grid")
local Round = require("../src/shared/Round")
local BotBrain = require("../src/shared/BotBrain")
local Protocol = require("../src/shared/Protocol")
local Elo = require("../src/shared/Elo")

local function spawn(grid: Grid.Grid, id: number, x: number, z: number, dir: number): Grid.Cycle
	grid:occupy(x, z, id)
	return Grid.newCycle(id, x, z, dir)
end

local function fixed(value: number): () -> number
	return function()
		return value
	end
end

return function(t: framework.T)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Config", function()
		it("place les apparitions loin du bord", function()
			expect(Config.SPAWN_MARGIN * 2).toBeLessThan(Config.ARENA_SIZE)
		end)
	end)

	describe("Grid", function()
		it("tourne à gauche et à droite sans demi-tour", function()
			expect(Grid.turn(0, 1)).toBe(1)
			expect(Grid.turn(0, -1)).toBe(3)
			expect(Grid.turn(3, 1)).toBe(0)
		end)

		it("avance d'une case et laisse un mur", function()
			local g = Grid.new(10)
			local c = spawn(g, 1, 5, 5, 1)
			expect(#g:step({ c })).toBe(0)
			expect(c.x).toBe(6)
			expect(g:ownerAt(5, 5)).toBe(1)
			expect(g:ownerAt(6, 5)).toBe(1)
		end)

		it("applique un virage en attente par tick", function()
			local g = Grid.new(10)
			local c = spawn(g, 1, 5, 5, 0)
			expect(Grid.queueTurn(c, 1, 2)).toBeTruthy()
			expect(Grid.queueTurn(c, 1, 2)).toBeTruthy()
			expect(Grid.queueTurn(c, 1, 2)).toBeFalsy()
			g:step({ c })
			expect(c.dir).toBe(1)
			expect(c.x).toBe(6)
			g:step({ c })
			expect(c.dir).toBe(2)
			expect(c.z).toBe(6)
		end)

		it("élimine en sortant de l'arène", function()
			local g = Grid.new(10)
			local c = spawn(g, 1, 9, 0, 1)
			local out = g:step({ c })
			expect(out[1]).toBe(1)
			expect(c.alive).toBeFalsy()
			expect(c.x).toBe(9)
		end)

		it("élimine en touchant un mur, y compris le sien", function()
			local g = Grid.new(10)
			local c = spawn(g, 1, 5, 5, 0)
			for _ = 1, 4 do
				Grid.queueTurn(c, 1, 4)
			end
			-- Est, sud, ouest, puis nord : retour sur la case de départ.
			for _ = 1, 3 do
				expect(#g:step({ c })).toBe(0)
			end
			local out = g:step({ c })
			expect(out[1]).toBe(1)
		end)

		it("élimine les deux motos d'un face-à-face sur la même case", function()
			local g = Grid.new(10)
			local a = spawn(g, 1, 3, 5, 1)
			local b = spawn(g, 2, 5, 5, 3)
			local out = g:step({ a, b })
			expect(#out).toBe(2)
			expect(g:ownerAt(4, 5)).toBe(nil)
		end)

		it("élimine celui qui entre dans la tête d'un autre", function()
			local g = Grid.new(10)
			local a = spawn(g, 1, 3, 5, 1)
			local b = spawn(g, 2, 4, 5, 0)
			local out = g:step({ a, b })
			expect(#out).toBe(1)
			expect(out[1]).toBe(1)
			expect(b.alive).toBeTruthy()
		end)

		it("efface le mur d'une moto éliminée", function()
			local g = Grid.new(10)
			local c = spawn(g, 7, 2, 2, 1)
			g:step({ c })
			g:step({ c })
			expect(g:clearOwner(7)).toBe(3)
			expect(g:isFree(2, 2)).toBeTruthy()
			expect(g:clearOwner(7)).toBe(0)
		end)

		it("désigne le propriétaire du mur percuté", function()
			local g = Grid.new(10)
			g:occupy(6, 5, 4)
			local c = spawn(g, 1, 5, 5, 1)
			local edge = spawn(g, 2, 9, 0, 1)
			local out, hitBy = g:step({ c, edge })
			expect(#out).toBe(2)
			expect(hitBy[1]).toBe(4)
			expect(hitBy[2]).toBe(nil)
		end)

		it("ne désigne personne dans un face-à-face", function()
			local g = Grid.new(10)
			local a = spawn(g, 1, 3, 5, 1)
			local b = spawn(g, 2, 5, 5, 3)
			local _, hitBy = g:step({ a, b })
			expect(hitBy[1]).toBe(nil)
			expect(hitBy[2]).toBe(nil)
		end)

		it("raccourcit le mur à sa longueur maximale en libérant la queue", function()
			local g = Grid.new(20)
			local c = spawn(g, 1, 0, 5, 1)
			for _ = 1, 9 do
				g:step({ c })
				g:trim(1, 4)
			end
			expect(g:trailLength(1)).toBe(4)
			expect(g:isFree(5, 5)).toBeTruthy()
			expect(g:ownerAt(6, 5)).toBe(1)
			expect(g:ownerAt(9, 5)).toBe(1)
			expect(g:clearOwner(1)).toBe(4)
			expect(g:isFree(9, 5)).toBeTruthy()
		end)

		it("laisse passer une moto là où la queue d'un mur vient de s'effacer", function()
			local g = Grid.new(20)
			local wall = spawn(g, 1, 5, 0, 2) -- descend le long de x = 5
			for _ = 1, 3 do
				g:step({ wall })
				g:trim(1, 3)
			end
			-- Le mur occupe z = 1 à 3 ; la case (5, 0) est libre de nouveau.
			local c = spawn(g, 2, 4, 0, 1)
			local out = g:step({ c })
			expect(#out).toBe(0)
			expect(c.x).toBe(5)
		end)

		it("aligne les équipes face à face, loin du bord", function()
			local size, margin = Config.ARENA_SIZE, Config.SPAWN_MARGIN
			local g = Grid.new(size)
			for team = 1, 2 do
				local points = Grid.teamSpawns(size, margin, team, Config.TEAM_SIZE)
				expect(#points).toBe(Config.TEAM_SIZE)
				for i, p in points do
					expect(p.z >= margin and p.z < size - margin).toBeTruthy()
					expect(p.dir).toBe(if team == 1 then 1 else 3)
					expect(g:isFree(p.x, p.z)).toBeTruthy()
					g:occupy(p.x, p.z, team * 10 + i)
				end
				expect(points[1].x).toBe(if team == 1 then margin else size - 1 - margin)
			end
		end)

		it("trouve une réapparition libre, dégagée et loin des adversaires", function()
			local g = Grid.new(40)
			local seq = 0
			local rng = function(a: number, b: number): number
				seq += 1
				return a + (seq * 7) % (b - a + 1)
			end
			local query = {
				team = 1,
				margin = 2,
				clearAhead = 5,
				enemies = { 10, 10 },
				minEnemyDistance = 6,
				attempts = 100,
			}
			for _ = 1, 20 do
				local spot = g:findSpawn(query, rng)
				expect(spot ~= nil).toBeTruthy()
				local s = spot :: { x: number, z: number, dir: number }
				expect(s.x < 20).toBeTruthy()
				expect(s.dir).toBe(1)
				for step = 0, 5 do
					expect(g:isFree(s.x + step, s.z)).toBeTruthy()
				end
				expect(math.abs(s.x - 10) + math.abs(s.z - 10) >= 6).toBeTruthy()
			end
		end)

		it("renonce à réapparaître quand la moitié de l'équipe est pleine", function()
			local g = Grid.new(10)
			for x = 0, 4 do
				for z = 0, 9 do
					g:occupy(x, z, 9)
				end
			end
			local query = { team = 1, margin = 0, clearAhead = 2, enemies = {}, minEnemyDistance = 0, attempts = 20 }
			expect(g:findSpawn(query, function(a, _)
				return a
			end)).toBe(nil)
		end)

		it("oublie les coins qui sortent du mur", function()
			-- Coins (0,0) -> (10,0) -> (10,10), tête en (5,10) : 10 + 10 + 5 cases.
			local path = { 0, 0, 10, 0, 10, 10 }
			Grid.trimPath(path, 5, 10, 30)
			expect(#path).toBe(6)
			Grid.trimPath(path, 5, 10, 16) -- 15 cases derrière la tête : le premier coin est inutile
			expect(#path).toBe(4)
			expect(path[1]).toBe(10)
			expect(path[2]).toBe(0)
			Grid.trimPath(path, 5, 10, 4)
			expect(#path).toBe(2)
			expect(path[1]).toBe(10)
			expect(path[2]).toBe(10)
		end)
	end)

	describe("Grid.toWorld", function()
		it("centre l'arène sur l'origine", function()
			local x1, z1 = Grid.toWorld(0, 0, 4, 2)
			local x2, z2 = Grid.toWorld(3, 3, 4, 2)
			expect(x1).toBe(-3)
			expect(z1).toBe(-3)
			expect(x2).toBe(3)
			expect(z2).toBe(3)
		end)
	end)

	describe("Protocol", function()
		it("n'accepte que -1 et 1 comme virage", function()
			expect(Protocol.isValidTurn(1)).toBeTruthy()
			expect(Protocol.isValidTurn(-1)).toBeTruthy()
			expect(Protocol.isValidTurn(0)).toBeFalsy()
			expect(Protocol.isValidTurn(2)).toBeFalsy()
			expect(Protocol.isValidTurn(0 / 0)).toBeFalsy()
			expect(Protocol.isValidTurn("1")).toBeFalsy()
			expect(Protocol.isValidTurn(nil)).toBeFalsy()
		end)

		it("définit deux équipes", function()
			expect(#Config.TEAMS).toBe(2)
		end)
	end)

	describe("Round", function()
		local settings = { countdown = 3, duration = 60, resultsDuration = 5, respawnDelay = 2 }
		local entries = { { id = 1, team = 1 }, { id = 2, team = 1 }, { id = 3, team = 2 }, { id = 4, team = 2 } }

		local function playing(): Round.Round
			local r = Round.new(settings)
			r:start(entries)
			r:update(3)
			return r
		end

		it("enchaîne compte à rebours, match, résultats et attente", function()
			local r = Round.new(settings)
			r:start(entries)
			expect(r.phase).toBe("Countdown")
			expect(r:update(2)).toBe(nil)
			expect(r:update(1)).toBe("Playing")
			expect(r:update(59)).toBe(nil)
			expect(r:update(1)).toBe("Results")
			expect(r:update(5)).toBe("Waiting")
		end)

		it("crédite l'adversaire, pas soi-même ni un coéquipier", function()
			local r = playing()
			local _, killer = r:kill(3, 1)
			expect(killer).toBe(1)
			_, killer = r:kill(2, 1)
			expect(killer).toBe(nil)
			_, killer = r:kill(4, 4)
			expect(killer).toBe(nil)
			_, killer = r:kill(1, nil)
			expect(killer).toBe(nil)
			expect(r.stats[1].kills).toBe(1)
			expect(r.stats[1].deaths).toBe(1)
			expect(r.teamKills[1]).toBe(1)
			expect(r.teamKills[2]).toBe(0)
			expect(r.teamDeaths[1]).toBe(2)
			expect(r.teamDeaths[2]).toBe(2)
		end)

		it("ignore les destructions hors match ou en double", function()
			local r = Round.new(settings)
			r:start(entries)
			expect((r:kill(1, 3))).toBeFalsy()
			r:update(3)
			expect((r:kill(1, 3))).toBeTruthy()
			expect((r:kill(1, 3))).toBeFalsy()
			expect(r.stats[3].kills).toBe(1)
		end)

		it("fait réapparaître après le délai", function()
			local r = playing()
			r:kill(3, 1)
			expect(r:isAlive(3)).toBeFalsy()
			r:update(1.5)
			expect(#r:takeRespawns()).toBe(0)
			r:update(0.5)
			local ready = r:takeRespawns()
			expect(#ready).toBe(1)
			expect(ready[1]).toBe(3)
			expect(r:isAlive(3)).toBeTruthy()
			expect(#r:takeRespawns()).toBe(0)
		end)

		it("retarde une réapparition sans place libre", function()
			local r = playing()
			r:kill(3, 1)
			r:update(2)
			r:takeRespawns()
			r:delayRespawn(3, 0.5)
			expect(r:isAlive(3)).toBeFalsy()
			r:update(0.5)
			expect(r:takeRespawns()[1]).toBe(3)
		end)

		it("donne la victoire à l'équipe qui a le plus d'éliminations", function()
			local r = playing()
			r:kill(3, 1)
			r:kill(4, 2)
			r:update(2)
			r:takeRespawns()
			r:kill(1, 3)
			r:update(60)
			local outcome = r.outcome :: Round.Outcome
			expect(outcome.winnerTeam).toBe(1)
			expect(outcome.teamKills[1]).toBe(2)
			expect(outcome.teamKills[2]).toBe(1)
		end)

		it("départage au nombre de morts, sinon égalité", function()
			local r = playing()
			r:kill(3, 1)
			r:kill(1, 3)
			r:kill(2, nil) -- l'équipe 1 s'est écrasée une fois de plus
			r:update(60)
			expect((r.outcome :: Round.Outcome).winnerTeam).toBe(2)

			local tie = playing()
			tie:kill(3, 1)
			tie:kill(1, 3)
			tie:update(60)
			expect((tie.outcome :: Round.Outcome).winnerTeam).toBe(nil)
		end)
	end)

	describe("Elo", function()
		it("donne 50 % à deux cotes égales", function()
			expect(Elo.expected(1200, 1200)).toBe(0.5)
		end)

		it("fait gagner au vainqueur ce que perd le vaincu", function()
			local d1, d2 = Elo.teamDeltas({ 1000, 1000 }, { 1000, 1000 }, 1, 32)
			expect(d1).toBe(16)
			expect(d2).toBe(-16)
			local t1, t2 = Elo.teamDeltas({ 1000 }, { 1000 }, nil, 32)
			expect(t1).toBe(0)
			expect(t2).toBe(0)
		end)

		it("récompense davantage une victoire contre une équipe plus forte", function()
			local upset = Elo.teamDeltas({ 1000, 1000 }, { 1400, 1400 }, 1, 32)
			local expectedWin = Elo.teamDeltas({ 1400, 1400 }, { 1000, 1000 }, 1, 32)
			expect(upset > 16).toBeTruthy()
			expect(expectedWin < 16).toBeTruthy()
			expect(upset + expectedWin).toBe(32)
		end)
	end)

	describe("BotBrain", function()
		local options = { floodCap = 200, mistakeChance = 0 }

		it("compte l'espace libre accessible", function()
			local g = Grid.new(4)
			expect(BotBrain.reachable(g, 0, 0, 100)).toBe(16)
			expect(BotBrain.reachable(g, 0, 0, 5)).toBe(5)
			g:occupy(1, 1, 1)
			expect(BotBrain.reachable(g, 1, 1, 100)).toBe(0)
		end)

		it("continue tout droit quand la voie est libre", function()
			local g = Grid.new(20)
			local c = spawn(g, 1, 10, 10, 0)
			expect(BotBrain.choose(g, c, options, fixed(0.5))).toBe(0)
		end)

		it("évite le bord de l'arène", function()
			local g = Grid.new(20)
			local c = spawn(g, 1, 10, 0, 0)
			local turn = BotBrain.choose(g, c, options, fixed(0.5))
			expect(turn ~= 0).toBeTruthy()
		end)

		it("choisit le côté qui offre le plus d'espace", function()
			-- Un mur vertical en x = 3 sépare une petite zone à gauche d'une grande à droite.
			local g = Grid.new(20)
			for z = 0, 19 do
				if z ~= 10 then
					g:occupy(3, z, 9)
				end
			end
			for x = 0, 19 do
				if x ~= 3 then
					g:occupy(x, 9, 9)
				end
			end
			g:occupy(3, 10, 1)
			local c = Grid.newCycle(1, 3, 10, 2)
			-- Face au sud : gauche = est (grande zone), droite = ouest (petite zone).
			expect(BotBrain.choose(g, c, options, fixed(0.5))).toBe(-1)
		end)

		it("utilise les mêmes directions que la grille", function()
			local g = Grid.new(4)
			local c = spawn(g, 1, 1, 1, 1)
			g:occupy(2, 1, 2)
			g:occupy(1, 0, 2)
			-- Est et nord bloqués : seule la droite (sud) est sûre.
			expect(BotBrain.choose(g, c, options, fixed(0.5))).toBe(1)
		end)
	end)
end

--!strict
local framework = require("./framework")
local Config = require("../src/shared/Config")
local Grid = require("../src/shared/Grid")
local Round = require("../src/shared/Round")
local BotBrain = require("../src/shared/BotBrain")
local Protocol = require("../src/shared/Protocol")

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

		it("donne des apparitions distinctes, dans l'arène et tournées vers le centre", function()
			local size, margin = Config.ARENA_SIZE, Config.SPAWN_MARGIN
			local points = Grid.spawnPoints(size, Config.MAX_RIDERS, margin)
			expect(#points).toBe(Config.MAX_RIDERS)
			local g = Grid.new(size)
			local center = (size - 1) / 2
			for i, p in points do
				expect(p.x >= margin and p.x < size - margin).toBeTruthy()
				expect(p.z >= margin and p.z < size - margin).toBeTruthy()
				expect(g:isFree(p.x, p.z)).toBeTruthy()
				g:occupy(p.x, p.z, i)
				local nx, nz = Grid.ahead(p.x, p.z, p.dir)
				local before = math.abs(p.x - center) + math.abs(p.z - center)
				expect(math.abs(nx - center) + math.abs(nz - center)).toBeLessThan(before)
			end
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

		it("donne une couleur à chaque place", function()
			expect(#Config.COLORS >= Config.MAX_RIDERS).toBeTruthy()
		end)
	end)

	describe("Round", function()
		local settings = { countdown = 3, timeLimit = 60, resultsDuration = 5 }

		it("enchaîne compte à rebours, course, résultats et attente", function()
			local r = Round.new(settings)
			r:start({ 1, 2, 3 })
			expect(r.phase).toBe("Countdown")
			expect(r:update(2)).toBe(nil)
			expect(r:update(1)).toBe("Racing")
			r:eliminate(2)
			expect(r:update(0.1)).toBe(nil)
			r:eliminate(3)
			expect(r:update(0.1)).toBe("Results")
			local outcome = r.outcome :: Round.Outcome
			expect(outcome.winner).toBe(1)
			expect(outcome.order[1]).toBe(2)
			expect(outcome.order[2]).toBe(3)
			expect(r:update(5)).toBe("Waiting")
		end)

		it("déclare une égalité si les derniers tombent au même tick", function()
			local r = Round.new(settings)
			r:start({ 1, 2 })
			r:update(3)
			r:eliminate(1)
			r:eliminate(2)
			r:update(0.1)
			local outcome = r.outcome :: Round.Outcome
			expect(outcome.winner).toBe(nil)
			expect(#outcome.survivors).toBe(0)
		end)

		it("termine sur une égalité à la limite de temps", function()
			local r = Round.new(settings)
			r:start({ 1, 2, 3 })
			r:update(3)
			r:eliminate(3)
			expect(r:update(60)).toBe("Results")
			local outcome = r.outcome :: Round.Outcome
			expect(outcome.winner).toBe(nil)
			expect(#outcome.survivors).toBe(2)
		end)

		it("ignore les éliminations hors course ou en double", function()
			local r = Round.new(settings)
			r:start({ 1, 2, 3 })
			expect(r:eliminate(1)).toBeFalsy()
			r:update(3)
			expect(r:eliminate(1)).toBeTruthy()
			expect(r:eliminate(1)).toBeFalsy()
			expect(r.aliveCount).toBe(2)
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

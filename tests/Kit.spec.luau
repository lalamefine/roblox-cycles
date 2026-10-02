--!strict
local framework = require("./framework")
local SpatialHash = require("../src/shared/Kit/SpatialHash")
local RateLimiter = require("../src/shared/Kit/RateLimiter")
local Steering = require("../src/shared/Kit/Steering")
local Signal = require("../src/shared/Kit/Signal")

return function(t: framework.T)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("SpatialHash", function()
		it("trouve les entrées dans le rayon et ignore les autres", function()
			local h = SpatialHash.new(10)
			h:insert("a", 0, 0)
			h:insert("b", 5, 5)
			h:insert("c", 50, 50)
			h:insert("d", -12, 3)
			local found = {}
			for _, e in h:queryRadius(0, 0, 13) do
				found[e.id] = true
			end
			expect(found.a).toBeTruthy()
			expect(found.b).toBeTruthy()
			expect(found.d).toBeTruthy()
			expect(found.c).toBeFalsy()
		end)

		it("suit les déplacements entre cellules", function()
			local h = SpatialHash.new(10)
			h:insert(1, 0, 0)
			h:move(1, 100, 100)
			expect(#h:queryRadius(0, 0, 5)).toBe(0)
			expect(#h:queryRadius(100, 100, 1)).toBe(1)
		end)

		it("tient le compte à jour", function()
			local h = SpatialHash.new(4)
			h:insert(1, 0, 0)
			h:insert(2, 1, 1)
			h:insert(1, 3, 3)
			expect(h.count).toBe(2)
			expect(h:remove(1)).toBe(true)
			expect(h:remove(1)).toBe(false)
			expect(h.count).toBe(1)
		end)

		it("gère les coordonnées négatives", function()
			local h = SpatialHash.new(8)
			h:insert("n", -1000, -1000)
			expect(#h:queryRadius(-1001, -999, 3)).toBe(1)
		end)
	end)

	describe("RateLimiter", function()
		it("bloque au-delà de la rafale puis se recharge", function()
			local now = 0
			local rl = RateLimiter.new(3, 1, function()
				return now
			end)
			expect(rl:allow("p")).toBe(true)
			expect(rl:allow("p")).toBe(true)
			expect(rl:allow("p")).toBe(true)
			expect(rl:allow("p")).toBe(false)
			now = 1
			expect(rl:allow("p")).toBe(true)
			expect(rl:allow("p")).toBe(false)
		end)

		it("isole les clés", function()
			local rl = RateLimiter.new(1, 0, function()
				return 0
			end)
			expect(rl:allow("a")).toBe(true)
			expect(rl:allow("b")).toBe(true)
			expect(rl:allow("a")).toBe(false)
		end)
	end)

	describe("Steering", function()
		it("seek et flee renvoient des directions unitaires opposées", function()
			local sx, sz = Steering.seek(0, 0, 3, 4)
			expect(sx).toBeNear(0.6)
			expect(sz).toBeNear(0.8)
			local fx, fz = Steering.flee(0, 0, 3, 4)
			expect(fx).toBeNear(-0.6)
			expect(fz).toBeNear(-0.8)
		end)

		it("keepInside ramène vers le centre près du bord", function()
			local dx, _ = Steering.keepInside(99, 0, 1, 0, 100, 5)
			expect(dx).toBeLessThan(0)
		end)

		it("normalize gère le vecteur nul", function()
			local x, z = Steering.normalize(0, 0)
			expect(x).toBe(0)
			expect(z).toBe(0)
		end)
	end)

	describe("Signal", function()
		it("Once ne se déclenche qu'une fois", function()
			local s = Signal.new()
			local n = 0
			s:Once(function()
				n += 1
			end)
			s:Fire()
			s:Fire()
			expect(n).toBe(1)
		end)

		it("Disconnect pendant Fire ne casse pas l'itération", function()
			local s = Signal.new()
			local calls = 0
			local c1
			c1 = s:Connect(function()
				calls += 1
				c1:Disconnect()
			end)
			s:Connect(function()
				calls += 1
			end)
			s:Fire()
			s:Fire()
			expect(calls).toBe(3)
		end)
	end)
end

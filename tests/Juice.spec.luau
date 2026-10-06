--!strict
local framework = require("./framework")
local Juice = require("../src/shared/Juice")

return function(t: framework.T)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Juice", function()
		it("fait retomber le trauma sans passer sous zéro", function()
			expect(Juice.decay(1, 0.25)).toBeNear(1 - Juice.SHAKE_DECAY * 0.25)
			expect(Juice.decay(0.1, 10)).toBe(0)
		end)

		it("plafonne le trauma cumulé à 1", function()
			expect(Juice.addTrauma(0.8, 0.9)).toBe(1)
			expect(Juice.addTrauma(0.2, 0.3)).toBeNear(0.5)
		end)

		it("garde les petites secousses discrètes (trauma²)", function()
			expect(Juice.shakeAmount(0.5)).toBeNear(0.25)
			expect(Juice.shakeAmount(1)).toBe(1)
		end)

		it("secoue moins une explosion lointaine, plus du tout hors de portée", function()
			expect(Juice.explosionTrauma(0)).toBeNear(Juice.SHAKE_NEARBY_DEATH)
			expect(Juice.explosionTrauma(Juice.SHAKE_RANGE / 2)).toBeNear(Juice.SHAKE_NEARBY_DEATH / 2)
			expect(Juice.explosionTrauma(Juice.SHAKE_RANGE)).toBe(0)
			expect(Juice.explosionTrauma(0 / 0)).toBe(0)
		end)

		it("atténue les sons avec la distance", function()
			expect(Juice.distanceGain(0)).toBe(1)
			expect(Juice.distanceGain(Juice.SOUND_NEAR)).toBe(1)
			local mid = Juice.distanceGain((Juice.SOUND_NEAR + Juice.SOUND_FAR) / 2)
			expect(mid).toBeGreaterThan(0)
			expect(mid).toBeLessThan(1)
			expect(Juice.distanceGain(Juice.SOUND_FAR)).toBe(0)
			expect(Juice.distanceGain(0 / 0)).toBe(0)
		end)

		it("reconnaît le sens d'un virage", function()
			expect(Juice.turnSign(0, 1)).toBe(1)
			expect(Juice.turnSign(0, 3)).toBe(-1)
			expect(Juice.turnSign(3, 0)).toBe(1)
			expect(Juice.turnSign(2, 2)).toBe(0)
			expect(Juice.turnSign(0, 2)).toBe(0)
		end)

		it("rapproche une valeur de sa cible sans la dépasser", function()
			local v = Juice.approach(10, 0, 5, 0.1)
			expect(v).toBeGreaterThan(0)
			expect(v).toBeLessThan(10)
			expect(Juice.approach(10, 0, 5, 0)).toBe(10)
		end)

		it("fait varier la hauteur d'un son dans la marge prévue", function()
			expect(Juice.jitterPitch(1, 0.5)).toBeNear(1)
			expect(Juice.jitterPitch(1, 0)).toBeNear(1 - Juice.PITCH_JITTER)
			expect(Juice.jitterPitch(2, 1)).toBeNear(2 * (1 + Juice.PITCH_JITTER))
		end)
	end)
end

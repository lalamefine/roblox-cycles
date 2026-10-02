--!strict
-- Mini framework de test pour Lune : describe / it / expect.

export type Expect = {
	toBe: (expected: any) -> (),
	toBeNear: (expected: number, epsilon: number?) -> (),
	toBeTruthy: () -> (),
	toBeFalsy: () -> (),
	toBeGreaterThan: (n: number) -> (),
	toBeLessThan: (n: number) -> (),
}

export type T = {
	describe: (name: string, fn: () -> ()) -> (),
	it: (name: string, fn: () -> ()) -> (),
	expect: (value: any) -> Expect,
}

local framework = {}

local passed, failed = 0, 0
local failures: { string } = {}
local prefix: { string } = {}

local function fail(msg: string)
	error(msg, 3)
end

local function expect(value: any): Expect
	local e = {} :: any
	function e.toBe(expected)
		if value ~= expected then
			fail(`attendu {tostring(expected)}, obtenu {tostring(value)}`)
		end
	end
	function e.toBeNear(expected: number, epsilon: number?)
		if math.abs(value - expected) > (epsilon or 1e-6) then
			fail(`attendu ~{expected}, obtenu {value}`)
		end
	end
	function e.toBeTruthy()
		if not value then
			fail(`attendu une valeur vraie, obtenu {tostring(value)}`)
		end
	end
	function e.toBeFalsy()
		if value then
			fail(`attendu une valeur fausse, obtenu {tostring(value)}`)
		end
	end
	function e.toBeGreaterThan(n: number)
		if not (value > n) then
			fail(`attendu > {n}, obtenu {value}`)
		end
	end
	function e.toBeLessThan(n: number)
		if not (value < n) then
			fail(`attendu < {n}, obtenu {value}`)
		end
	end
	return e
end

local t: T = {
	describe = function(name: string, fn: () -> ())
		table.insert(prefix, name)
		fn()
		table.remove(prefix)
	end,
	it = function(name: string, fn: () -> ())
		local full = table.concat(prefix, " > ") .. " > " .. name
		local ok, err = pcall(fn)
		if ok then
			passed += 1
		else
			failed += 1
			table.insert(failures, full .. "\n    " .. tostring(err))
		end
	end,
	expect = expect,
}

function framework.run(specs: { (T) -> () }): boolean
	for _, spec in specs do
		spec(t)
	end
	for _, f in failures do
		print("ÉCHEC " .. f)
	end
	print(`{passed} réussi(s), {failed} échec(s)`)
	return failed == 0
end

return framework

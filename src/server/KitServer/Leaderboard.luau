--!strict
-- Classement global (OrderedDataStore) avec écritures regroupées pour respecter
-- les quotas, et lecture périodique du top N mise en cache.

local DataStoreService = game:GetService("DataStoreService")

local Signal = require(game:GetService("ReplicatedStorage").Shared.Kit.Signal)

export type Entry = { userId: number, score: number, rank: number }

export type Leaderboard = {
	name: string,
	-- Propose un score : seul le meilleur depuis la dernière écriture est envoyé.
	submit: (self: Leaderboard, userId: number, score: number) -> (),
	top: (self: Leaderboard) -> { Entry },
	Updated: Signal.Signal<{ Entry }>,
}

local Leaderboard = {}

export type Options = {
	size: number?, -- taille du top (défaut 50)
	flushSeconds: number?, -- intervalle d'écriture (défaut 60)
	refreshSeconds: number?, -- intervalle de lecture (défaut 120)
}

function Leaderboard.new(name: string, options: Options?): Leaderboard
	local opts: Options = options or {}
	local size = opts.size or 50
	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, name)
	if not ok then
		warn("[Leaderboard] indisponible :", name, store)
	end

	local pending: { [number]: number } = {}
	local cache: { Entry } = {}
	local updated = Signal.new() :: Signal.Signal<{ Entry }>

	local self = {
		name = name,
		Updated = updated,
	} :: any

	function self.submit(_: Leaderboard, userId: number, score: number)
		local s = math.floor(score)
		if s > (pending[userId] or -math.huge) then
			pending[userId] = s
		end
	end

	function self.top(_: Leaderboard): { Entry }
		return cache
	end

	local function flush()
		if not ok then
			return
		end
		local batch = pending
		pending = {}
		for userId, score in batch do
			pcall(function()
				(store :: OrderedDataStore):UpdateAsync(tostring(userId), function(old: number?): any
					if old and old >= score then
						return nil
					end
					return score
				end)
			end)
		end
	end

	local function refresh()
		if not ok then
			return
		end
		local success, pages = pcall(function()
			return (store :: OrderedDataStore):GetSortedAsync(false, size)
		end)
		if not success then
			return
		end
		local entries = {}
		for i, item in (pages :: DataStorePages):GetCurrentPage() do
			table.insert(entries, { userId = tonumber(item.key) or 0, score = item.value, rank = i })
		end
		cache = entries
		updated:Fire(entries)
	end

	task.spawn(function()
		while true do
			task.wait(opts.flushSeconds or 60)
			flush()
		end
	end)
	task.spawn(function()
		refresh()
		while true do
			task.wait(opts.refreshSeconds or 120)
			refresh()
		end
	end)
	game:BindToClose(flush)

	return self
end

return Leaderboard

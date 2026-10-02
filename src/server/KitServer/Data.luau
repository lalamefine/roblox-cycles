--!strict
-- Sauvegarde joueur avec verrou de session (évite la duplication entre serveurs),
-- réconciliation avec un modèle par défaut, sauvegarde automatique et à la fermeture.
-- Si les DataStores sont indisponibles (Studio sans accès API), bascule en mémoire.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Signal = require(game:GetService("ReplicatedStorage").Shared.Kit.Signal)

local LOCK_EXPIRY = 30 * 60 -- un verrou plus vieux que 30 min est considéré abandonné
local LOAD_ATTEMPTS = 5
local MAX_RECEIPTS = 50

export type Meta = {
	receipts: { string },
	createdAt: number,
	version: number,
}

export type Profile = {
	data: { [string]: any },
	meta: Meta,
	released: boolean,
}

type Stored = {
	data: { [string]: any },
	meta: Meta,
	lock: { jobId: string, time: number }?,
}

export type Config = {
	storeName: string,
	template: { [string]: any },
	autosaveSeconds: number?,
	-- Migrations appliquées dans l'ordre : migrations[i] fait passer de la version i-1 à i.
	migrations: { (data: { [string]: any }) -> () }?,
}

local Data = {}
Data.ProfileLoaded = Signal.new() :: Signal.Signal<Player, Profile>

local config: Config? = nil
local store: DataStore? = nil
local memoryOnly = false
local profiles: { [Player]: Profile } = {}

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value :: any do
		out[k] = deepCopy(v)
	end
	return out :: any
end

local function reconcile(target: { [string]: any }, template: { [string]: any })
	for k, v in template do
		if target[k] == nil then
			target[k] = deepCopy(v)
		elseif type(v) == "table" and type(target[k]) == "table" then
			reconcile(target[k], v)
		end
	end
end

local function key(userId: number): string
	return "u_" .. tostring(userId)
end

local function migrate(stored: Stored)
	local migrations = (config :: Config).migrations or {}
	while stored.meta.version < #migrations do
		stored.meta.version += 1
		migrations[stored.meta.version](stored.data)
	end
end

function Data.configure(cfg: Config)
	assert(config == nil, "Data.configure appelé deux fois")
	config = cfg
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(cfg.storeName)
	end)
	if ok then
		store = result
	else
		memoryOnly = true
		warn("[Data] DataStores indisponibles, données en mémoire seulement :", result)
	end
	-- En Studio sans « accès aux services API », chaque appel renvoie une 403 :
	-- on bascule en mémoire au lieu de réessayer puis d'expulser le joueur.
	if not memoryOnly and RunService:IsStudio() then
		local probeOk, probeErr = pcall(function()
			(store :: DataStore):GetAsync("__studio_probe")
		end)
		if not probeOk then
			memoryOnly = true
			warn("[Data] Studio sans accès API, données en mémoire seulement :", probeErr)
		end
	end

	Players.PlayerAdded:Connect(Data._load)
	for _, p in Players:GetPlayers() do
		task.spawn(Data._load, p)
	end
	Players.PlayerRemoving:Connect(Data._release)

	task.spawn(function()
		local period = cfg.autosaveSeconds or 90
		while true do
			task.wait(period)
			for player in profiles do
				task.spawn(Data.save, player)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and memoryOnly then
			return
		end
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				Data._release(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait()
		end
	end)
end

function Data._load(player: Player)
	local cfg = config :: Config
	local profile: Profile? = nil

	if memoryOnly then
		profile = {
			data = deepCopy(cfg.template),
			meta = { receipts = {}, createdAt = os.time(), version = #(cfg.migrations or {}) },
			released = false,
		}
	else
		for attempt = 1, LOAD_ATTEMPTS do
			local steal = attempt == LOAD_ATTEMPTS
			local ok, err = pcall(function()
				(store :: DataStore):UpdateAsync(key(player.UserId), function(old: Stored?): Stored?
					local stored: Stored = old
						or {
							data = deepCopy(cfg.template),
							meta = { receipts = {}, createdAt = os.time(), version = #(cfg.migrations or {}) },
							lock = nil,
						}
					local lock = stored.lock
					if lock and lock.jobId ~= game.JobId and os.time() - lock.time < LOCK_EXPIRY and not steal then
						return nil -- verrouillé ailleurs : on réessaie
					end
					stored.lock = { jobId = game.JobId, time = os.time() }
					migrate(stored)
					reconcile(stored.data, cfg.template)
					profile = { data = stored.data, meta = stored.meta, released = false }
					return stored
				end)
			end)
			if profile then
				break
			end
			if not ok then
				warn("[Data] échec de chargement", player.UserId, err)
			end
			task.wait(attempt * 2)
		end
	end

	if not player:IsDescendantOf(Players) then
		if profile and not memoryOnly then
			profiles[player] = profile
			Data._release(player)
		end
		return
	end
	if not profile then
		player:Kick("Impossible de charger tes données, réessaie dans un instant.")
		return
	end
	profiles[player] = profile
	Data.ProfileLoaded:Fire(player, profile)
end

local function write(player: Player, release: boolean): boolean
	local profile = profiles[player]
	if not profile or memoryOnly then
		return memoryOnly
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(player.UserId), function(old: Stored?): Stored?
			if old and old.lock and old.lock.jobId ~= game.JobId then
				return nil -- un autre serveur a repris la session : ne pas écraser
			end
			return {
				data = profile.data,
				meta = profile.meta,
				lock = if release then nil else { jobId = game.JobId, time = os.time() },
			}
		end)
	end)
	if not ok then
		warn("[Data] échec de sauvegarde", player.UserId, err)
	end
	return ok
end

function Data.save(player: Player): boolean
	return write(player, false)
end

function Data._release(player: Player)
	local profile = profiles[player]
	if not profile or profile.released then
		return
	end
	profile.released = true
	write(player, true)
	profiles[player] = nil
end

-- Renvoie le profil chargé, ou nil s'il ne l'est pas (encore).
function Data.get(player: Player): Profile?
	return profiles[player]
end

-- Attend le profil (jusqu'à timeout secondes).
function Data.waitFor(player: Player, timeout: number?): Profile?
	local deadline = os.clock() + (timeout or 30)
	while not profiles[player] and player:IsDescendantOf(Players) and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

function Data.hasReceipt(profile: Profile, receiptId: string): boolean
	return table.find(profile.meta.receipts, receiptId) ~= nil
end

function Data.addReceipt(profile: Profile, receiptId: string)
	local receipts = profile.meta.receipts
	table.insert(receipts, receiptId)
	while #receipts > MAX_RECEIPTS do
		table.remove(receipts, 1)
	end
end

return Data

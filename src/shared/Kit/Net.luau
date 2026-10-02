--!strict
-- Remotes centralisés. Le serveur les crée (Net.setup), le client les attend.
-- Toute entrée client passe par Net.onServerEvent, qui applique un limiteur de débit :
-- le serveur ne fait jamais confiance au client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RateLimiter = require(script.Parent.RateLimiter)

local FOLDER_NAME = "KitRemotes"

export type Definition = {
	events: { string }?,
	unreliable: { string }?,
	functions: { string }?,
}

local Net = {}

local function folder(): Folder
	if RunService:IsServer() then
		local f = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not f then
			f = Instance.new("Folder")
			f.Name = FOLDER_NAME
			f.Parent = ReplicatedStorage
		end
		return f :: Folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

-- Serveur uniquement : crée tous les remotes déclarés. À appeler au démarrage.
function Net.setup(def: Definition)
	assert(RunService:IsServer(), "Net.setup est réservé au serveur")
	local f = folder()
	local function make(className: string, names: { string }?)
		if not names then
			return
		end
		for _, name in names do
			if not f:FindFirstChild(name) then
				local r = Instance.new(className)
				r.Name = name
				r.Parent = f
			end
		end
	end
	make("RemoteEvent", def.events)
	make("UnreliableRemoteEvent", def.unreliable)
	make("RemoteFunction", def.functions)
end

function Net.event(name: string): RemoteEvent
	return folder():WaitForChild(name) :: RemoteEvent
end

function Net.unreliable(name: string): UnreliableRemoteEvent
	return folder():WaitForChild(name) :: UnreliableRemoteEvent
end

function Net.func(name: string): RemoteFunction
	return folder():WaitForChild(name) :: RemoteFunction
end

export type ServerHandlerOptions = {
	-- Rafale maximale et débit soutenu par joueur (défaut : 20 / 10 par seconde).
	burst: number?,
	perSecond: number?,
}

-- Serveur : branche un handler limité en débit. Les appels hors quota sont ignorés.
function Net.onServerEvent(
	name: string,
	handler: (player: Player, ...any) -> (),
	options: ServerHandlerOptions?
): RBXScriptConnection
	local opts: ServerHandlerOptions = options or {}
	local limiter = RateLimiter.new(opts.burst or 20, opts.perSecond or 10)
	local remote = folder():WaitForChild(name)
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		limiter:forget(p)
	end)
	-- RemoteEvent et UnreliableRemoteEvent exposent le même OnServerEvent.
	local signal: RBXScriptSignal = (remote :: any).OnServerEvent
	return signal:Connect(function(player: Player, ...)
		if limiter:allow(player) then
			handler(player, ...)
		end
	end)
end

return Net

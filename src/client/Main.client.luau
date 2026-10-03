--!strict
-- Point d'entrée client de RobloxCycles : reçoit l'état du serveur, affiche, envoie les virages.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Protocol = require(Shared.Protocol)
local Net = require(Shared.Kit.Net)

local ArenaView = require(script.Parent.ArenaView)
local CameraRig = require(script.Parent.CameraRig)
local Hud = require(script.Parent.Hud)
local Input = require(script.Parent.Input)
local TrailRenderer = require(script.Parent.TrailRenderer)

local localPlayer = Players.LocalPlayer :: Player

local state: Protocol.Snapshot? = nil
local myId: number? = nil
local phaseClock = 0 -- os.clock() à la réception de la phase en cours
local goUntil = 0

ArenaView.build()
Hud.build()

local function nameOf(id: number?): string
	if state and id then
		for _, r in state.riders do
			if r.id == id then
				return r.name
			end
		end
	end
	return "?"
end

Net.event(Protocol.SNAPSHOT).OnClientEvent:Connect(function(s: Protocol.Snapshot)
	local newRound = state == nil or state.roundId ~= s.roundId
	state = s
	phaseClock = os.clock()
	if newRound then
		myId = nil
		for _, r in s.riders do
			if r.userId ~= 0 and r.userId == localPlayer.UserId then
				myId = r.id
			end
		end
		TrailRenderer.reset(s)
		local _, fwd = TrailRenderer.focus(myId or 0)
		if fwd then
			CameraRig.snapForward(fwd)
		end
	end
	if s.phase == "Racing" then
		goUntil = os.clock() + 1
	end
end)

Net.event(Protocol.TICK).OnClientEvent:Connect(function(t: Protocol.Tick)
	TrailRenderer.applyTick(t)
end)

Input.bind(function(turn: number)
	if state and state.phase == "Racing" and myId and TrailRenderer.isAlive(myId) then
		Net.event(Protocol.TURN):FireServer(turn)
	end
end)

local function updateHud()
	local s = state
	if not s then
		Hud.message("Connexion…")
		return
	end
	local elapsed = os.clock() - phaseClock
	local alive, total = TrailRenderer.aliveCount()
	Hud.status(if s.phase == "Racing" then `En lice : {alive}/{total}` else "")
	if s.phase == "Waiting" then
		Hud.message(`Prochaine manche dans {math.max(0, math.ceil(s.timer - elapsed))}`)
	elseif s.phase == "Countdown" then
		local left = math.ceil(s.timer - elapsed)
		Hud.message(if myId then tostring(math.max(1, left)) else `Spectateur : départ dans {math.max(1, left)}`)
	elseif s.phase == "Racing" then
		if os.clock() < goUntil then
			Hud.message("GO !")
		elseif myId and not TrailRenderer.isAlive(myId) then
			Hud.message("Éliminé !")
		else
			Hud.message("")
		end
	elseif s.phase == "Results" then
		if s.winner == nil then
			Hud.message("Égalité !")
		elseif s.winner == myId then
			Hud.message("Victoire !")
		else
			Hud.message(`{nameOf(s.winner)} gagne la manche`)
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	TrailRenderer.render()
	local head, fwd = nil, nil
	local s = state
	if s and myId and (s.phase == "Countdown" or s.phase == "Racing") and TrailRenderer.isAlive(myId) then
		head, fwd = TrailRenderer.focus(myId)
	end
	CameraRig.update(dt, head, fwd)
	updateHud()
end)

Net.event(Protocol.READY):FireServer()

--!strict
-- Point d'entrée client de RobloxCycles : reçoit l'état du serveur, affiche, envoie les virages.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Protocol = require(Shared.Protocol)
local Net = require(Shared.Kit.Net)

local ArenaView = require(script.Parent.ArenaView)
local CameraRig = require(script.Parent.CameraRig)
local Hud = require(script.Parent.Hud)
local Input = require(script.Parent.Input)
local TrailRenderer = require(script.Parent.TrailRenderer)

local FEED_SIZE = 5
local FEED_SECONDS = 6
local GO_SECONDS = 1

local localPlayer = Players.LocalPlayer :: Player

local state: Protocol.Snapshot? = nil
local riders: { [number]: Protocol.Rider } = {}
local myId: number? = nil
local phaseClock = 0 -- os.clock() à la réception de l'état en cours
local goUntil = 0
local respawnAt = 0
local killedBy: number? = nil
local feed: { { text: string, time: number } } = {}
local ranking: { Protocol.RankingEntry } = {}

ArenaView.build()
Hud.build()

local function teamName(team: number): string
	return Hud.color(TrailRenderer.teamColor(team), Config.TEAMS[team].name)
end

local function riderName(id: number): string
	local r = riders[id]
	if not r then
		return "?"
	end
	return Hud.color(TrailRenderer.teamColor(r.team), Hud.escape(r.name))
end

local function pushFeed(text: string)
	table.insert(feed, { text = text, time = os.clock() })
	if #feed > FEED_SIZE then
		table.remove(feed, 1)
	end
end

Net.event(Protocol.SNAPSHOT).OnClientEvent:Connect(function(s: Protocol.Snapshot)
	local newRound = state == nil or state.roundId ~= s.roundId
	local previous = state
	state = s
	phaseClock = os.clock()
	riders = {}
	local wasMe = myId
	myId = nil
	for _, r in s.riders do
		riders[r.id] = r
		if r.userId ~= 0 and r.userId == localPlayer.UserId then
			myId = r.id
		end
	end
	if newRound then
		feed = {}
		killedBy = nil
	end
	TrailRenderer.reset(s)
	if myId and (newRound or wasMe ~= myId) then
		local _, fwd = TrailRenderer.focus(myId)
		if fwd then
			CameraRig.snapForward(fwd)
		end
	end
	if s.phase == "Playing" and (previous == nil or previous.phase ~= "Playing") then
		goUntil = os.clock() + GO_SECONDS
	end
end)

Net.event(Protocol.TICK).OnClientEvent:Connect(function(t: Protocol.Tick)
	TrailRenderer.applyTick(t)
	local s = state
	if not s then
		return
	end
	for i, victim in t.dead do
		local killer = t.killers[i]
		local v = riders[victim]
		if v then
			v.deaths += 1
		end
		local k = if killer ~= 0 then riders[killer] else nil
		if k then
			k.kills += 1
			s.teamKills[k.team] += 1
			pushFeed(`{riderName(killer)} ⟶ {riderName(victim)}`)
		else
			pushFeed(`{riderName(victim)} s'est écrasé`)
		end
		if victim == myId then
			respawnAt = os.clock() + Config.RESPAWN_DELAY
			killedBy = if k then killer else nil
		end
	end
	local spawns = t.spawns
	local mine = myId
	for i = 1, #spawns, 4 do
		if mine and spawns[i] == mine then
			local _, fwd = TrailRenderer.focus(mine)
			if fwd then
				CameraRig.snapForward(fwd)
			end
		end
	end
end)

Net.event(Protocol.RANKING).OnClientEvent:Connect(function(r: { Protocol.RankingEntry })
	ranking = r
end)

Input.bind(function(turn: number)
	if state and state.phase == "Playing" and myId and TrailRenderer.isAlive(myId) then
		Net.event(Protocol.TURN):FireServer(turn)
	end
end)

local function clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function updateHud()
	local s = state
	if not s then
		Hud.message("Connexion…")
		return
	end
	local left = s.timer - (os.clock() - phaseClock)
	local now = os.clock()

	local inMatch = s.phase ~= "Waiting"
	Hud.score(
		if inMatch
			then `{teamName(1)} {s.teamKills[1]}   {clock(if s.phase == "Playing" then left else 0)}   {s.teamKills[2]} {teamName(
				2
			)}`
			else ""
	)

	local me = if myId then riders[myId] else nil
	if me and inMatch then
		local line = `{me.kills} élimination{if me.kills > 1 then "s" else ""} · {me.deaths} mort{if me.deaths
				> 1
			then "s"
			else ""}`
		if s.phase == "Results" and me.eloDelta then
			line ..= ` · Elo {if me.eloDelta >= 0 then "+" else ""}{me.eloDelta}`
		end
		Hud.status(line)
	else
		Hud.status(if inMatch then "Spectateur" else "")
	end

	local lines = {}
	for _, entry in feed do
		if now - entry.time < FEED_SECONDS then
			table.insert(lines, entry.text)
		end
	end
	Hud.feed(lines)

	if s.phase == "Waiting" or s.phase == "Results" then
		local rows = { "Classement Elo" }
		for _, e in ranking do
			table.insert(rows, `{e.rank}. {Hud.escape(e.name)}  {e.elo}`)
		end
		Hud.ranking(if #ranking > 0 then rows else {})
	else
		Hud.ranking({})
	end

	if s.phase == "Waiting" then
		Hud.message(`Prochain match dans {math.max(0, math.ceil(left))}`)
	elseif s.phase == "Countdown" then
		local n = math.max(1, math.ceil(left))
		Hud.message(if me then `Équipe {teamName(me.team)}\n{n}` else `Départ dans {n}`)
	elseif s.phase == "Playing" then
		if now < goUntil then
			Hud.message("GO !")
		elseif myId and not TrailRenderer.isAlive(myId) then
			local by = if killedBy then `Éliminé par {riderName(killedBy)}` else "Éliminé !"
			Hud.message(`{by}\nRetour dans {math.max(1, math.ceil(respawnAt - now))}`)
		else
			Hud.message("")
		end
	elseif s.phase == "Results" then
		local k = s.teamKills
		if s.winnerTeam == nil then
			Hud.message(`Égalité {k[1]} à {k[2]}`)
		else
			local w = s.winnerTeam :: number
			local verdict = if me and me.team == w then "Victoire !" elseif me then "Défaite" else ""
			-- À éliminations égales, l'équipe qui a le moins de morts l'emporte.
			local how = if k[1] == k[2] then " (moins de morts)" else ""
			Hud.message(`{verdict}\nL'équipe {teamName(w)} gagne {k[w]} à {k[3 - w]}{how}`)
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	TrailRenderer.render()
	local head, fwd = nil, nil
	local s = state
	if s and myId and (s.phase == "Countdown" or s.phase == "Playing") and TrailRenderer.isAlive(myId) then
		head, fwd = TrailRenderer.focus(myId)
	end
	CameraRig.update(dt, head, fwd)
	updateHud()
end)

Net.event(Protocol.READY):FireServer()

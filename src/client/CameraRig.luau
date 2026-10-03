--!strict
-- Caméra scriptée : poursuite derrière sa moto pendant la course, vue d'ensemble sinon.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local CHASE_BACK = 16
local CHASE_UP = 8
local LOOK_AHEAD = 12
local TURN_SMOOTHING = 8 -- plus grand = la caméra suit les virages plus vite
local OVERVIEW_SMOOTHING = 2

local CameraRig = {}

local smoothedForward = Vector3.new(0, 0, -1)

local function overviewCFrame(): CFrame
	local span = Config.ARENA_SIZE * Config.CELL_STUDS
	return CFrame.lookAt(Vector3.new(0, span * 0.75, span * 0.55), Vector3.zero)
end

-- `head` et `forward` : moto suivie, ou nil pour la vue d'ensemble.
function CameraRig.update(dt: number, head: Vector3?, forward: Vector3?)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local target: CFrame
	local smoothing: number
	if head and forward then
		local k = 1 - math.exp(-TURN_SMOOTHING * dt)
		smoothedForward = smoothedForward:Lerp(forward, k)
		if smoothedForward.Magnitude < 1e-3 then
			smoothedForward = forward
		end
		local f = smoothedForward.Unit
		target = CFrame.lookAt(head - f * CHASE_BACK + Vector3.yAxis * CHASE_UP, head + f * LOOK_AHEAD)
		smoothing = 20
	else
		target = overviewCFrame()
		smoothing = OVERVIEW_SMOOTHING
	end
	camera.CFrame = camera.CFrame:Lerp(target, 1 - math.exp(-smoothing * dt))
end

-- Recale immédiatement la direction (début de manche) pour éviter un tour de caméra.
function CameraRig.snapForward(forward: Vector3)
	smoothedForward = forward
end

return CameraRig

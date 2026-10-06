--!strict
-- Caméra scriptée : poursuite derrière sa moto pendant la course, vue d'ensemble sinon.
-- Secousses (explosions) et coups de champ de vision (départ) par-dessus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Juice = require(ReplicatedStorage.Shared.Juice)

local CHASE_BACK = 16
local CHASE_UP = 8
local LOOK_AHEAD = 12
local TURN_SMOOTHING = 8 -- plus grand = la caméra suit les virages plus vite
local OVERVIEW_SMOOTHING = 2

local CameraRig = {}

local smoothedForward = Vector3.new(0, 0, -1)
local trauma = 0
local fov = Juice.FOV_BASE
local base = CFrame.identity -- position lissée, sans la secousse
local started = false

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
	if not started then
		base = camera.CFrame
		started = true
	end
	base = base:Lerp(target, 1 - math.exp(-smoothing * dt))

	-- Secousse : bruit de Perlin plutôt que hasard pur, pour un tremblement continu.
	trauma = Juice.decay(trauma, dt)
	local amount = Juice.shakeAmount(trauma)
	local shake = CFrame.identity
	if amount > 0 then
		local t = os.clock() * 25
		local offset = Juice.SHAKE_MAX_OFFSET * amount
		shake = CFrame.new(math.noise(t, 0.3) * offset, math.noise(t, 7.1) * offset, 0)
			* CFrame.Angles(0, 0, math.rad(Juice.SHAKE_MAX_ROLL * amount * math.noise(t, 13.7)))
	end
	camera.CFrame = base * shake

	fov = Juice.approach(fov, Juice.FOV_BASE, Juice.FOV_RECOVER, dt)
	camera.FieldOfView = fov
end

-- Ajoute une secousse (0 à 1), cumulée avec celle en cours.
function CameraRig.shake(amount: number)
	trauma = Juice.addTrauma(trauma, amount)
end

-- Élargit brièvement le champ de vision, qui revient ensuite seul à la normale.
function CameraRig.kickFov(degrees: number)
	fov = Juice.FOV_BASE + degrees
end

function CameraRig.position(): Vector3
	return base.Position
end

-- Recale immédiatement la direction (début de manche) pour éviter un tour de caméra.
function CameraRig.snapForward(forward: Vector3)
	smoothedForward = forward
end

return CameraRig

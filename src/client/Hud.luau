--!strict
-- Interface : grand message central (attente, compte à rebours, victoire) et compteur de survivants.

local Players = game:GetService("Players")

local Hud = {}

local center: TextLabel
local corner: TextLabel

local function label(parent: Instance, size: UDim2, position: UDim2, textSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Font = Enum.Font.GothamBlack
	l.TextSize = textSize
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	l.TextStrokeColor3 = Color3.fromRGB(0, 120, 200)
	l.Text = ""
	l.Parent = parent
	return l
end

function Hud.build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	center = label(gui, UDim2.new(1, 0, 0, 80), UDim2.fromScale(0.5, 0.3), 48)
	corner = label(gui, UDim2.fromOffset(260, 30), UDim2.new(0.5, 0, 0, 12), 22)
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
end

function Hud.message(text: string)
	center.Text = text
end

function Hud.status(text: string)
	corner.Text = text
end

return Hud

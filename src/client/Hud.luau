--!strict
-- Interface : grand message central, score des équipes et chrono en haut, statistiques personnelles,
-- fil des éliminations à droite et classement Elo à gauche (entre les matchs).

local Players = game:GetService("Players")

local Hud = {}

local center: TextLabel
local score: TextLabel
local status: TextLabel
local feed: TextLabel
local ranking: TextLabel

local function label(parent: Instance, size: UDim2, position: UDim2, anchor: Vector2, textSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.AnchorPoint = anchor
	l.Font = Enum.Font.GothamBlack
	l.TextSize = textSize
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	l.TextStrokeColor3 = Color3.fromRGB(0, 120, 200)
	l.RichText = true
	l.Text = ""
	l.Parent = parent
	return l
end

local function list(parent: Instance, position: UDim2, anchor: Vector2, alignX: Enum.TextXAlignment): TextLabel
	local l = label(parent, UDim2.fromOffset(280, 240), position, anchor, 18)
	l.Font = Enum.Font.GothamBold
	l.TextXAlignment = alignX
	l.TextYAlignment = Enum.TextYAlignment.Top
	return l
end

function Hud.build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	local top = Vector2.new(0.5, 0)
	center = label(gui, UDim2.new(1, 0, 0, 120), UDim2.fromScale(0.5, 0.3), top, 48)
	score = label(gui, UDim2.fromOffset(420, 34), UDim2.new(0.5, 0, 0, 10), top, 28)
	status = label(gui, UDim2.fromOffset(420, 26), UDim2.new(0.5, 0, 0, 46), top, 20)
	feed = list(gui, UDim2.new(1, -16, 0, 90), Vector2.new(1, 0), Enum.TextXAlignment.Right)
	ranking = list(gui, UDim2.fromOffset(16, 90), Vector2.new(0, 0), Enum.TextXAlignment.Left)
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
end

-- Échappe un texte libre (nom de joueur) pour l'afficher en texte enrichi.
function Hud.escape(text: string): string
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- Couleur d'un texte enrichi au format attendu par <font color>.
function Hud.color(c: Color3, text: string): string
	return `<font color="#{c:ToHex()}">{text}</font>`
end

function Hud.message(text: string)
	center.Text = text
end

function Hud.score(text: string)
	score.Text = text
end

function Hud.status(text: string)
	status.Text = text
end

function Hud.feed(lines: { string })
	feed.Text = table.concat(lines, "\n")
end

function Hud.ranking(lines: { string })
	ranking.Text = table.concat(lines, "\n")
end

return Hud

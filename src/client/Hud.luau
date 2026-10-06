--!strict
-- Interface : grand message central, score des équipes et chrono en haut, statistiques personnelles,
-- fil des éliminations à droite et classement Elo à gauche (entre les matchs).
-- Effets : le message central « claque » quand il change, éclair plein écran, annonce « +1 ».

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Hud = {}

local center: TextLabel
local score: TextLabel
local status: TextLabel
local feed: TextLabel
local ranking: TextLabel
local flashFrame: Frame
local popup: TextLabel
local centerScale: UIScale
local popupScale: UIScale
local popupToken = 0

local function play(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService
		:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		:Play()
end

local function scaler(parent: Instance): UIScale
	local s = Instance.new("UIScale")
	s.Parent = parent
	return s
end

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
	centerScale = scaler(center)
	popup = label(gui, UDim2.new(1, 0, 0, 50), UDim2.fromScale(0.5, 0.48), top, 36)
	popup.TextTransparency = 1
	popup.TextStrokeTransparency = 1
	popupScale = scaler(popup)
	flashFrame = Instance.new("Frame")
	flashFrame.Name = "Eclair"
	flashFrame.Size = UDim2.fromScale(1, 1)
	flashFrame.BackgroundTransparency = 1
	flashFrame.BorderSizePixel = 0
	flashFrame.ZIndex = 10
	flashFrame.Parent = gui
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
	if center.Text == text then
		return
	end
	center.Text = text
	if text ~= "" then
		centerScale.Scale = 1.35
		play(centerScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

-- Éclair plein écran de la couleur donnée, qui s'efface ; `strength` de 0 à 1.
function Hud.flash(color: Color3, strength: number)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = 1 - math.clamp(strength, 0, 1)
	play(flashFrame, 0.5, { BackgroundTransparency = 1 })
end

-- Courte annonce sous le message central (« +1 élimination »), qui grossit puis s'efface.
function Hud.popup(text: string)
	popupToken += 1
	local token = popupToken
	popup.Text = text
	popup.TextTransparency = 0
	popup.TextStrokeTransparency = 0.4
	popupScale.Scale = 1.8
	play(popupScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.9, function()
		if token == popupToken then
			play(popup, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
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

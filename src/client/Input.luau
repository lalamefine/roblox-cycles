--!strict
-- Commandes : gauche / droite au clavier (QWERTY et AZERTY), à la manette et en tactile.

local ContextActionService = game:GetService("ContextActionService")

local Input = {}

function Input.bind(onTurn: (turn: number) -> ())
	local function handler(turn: number)
		return function(_: string, state: Enum.UserInputState, _: InputObject): Enum.ContextActionResult
			if state == Enum.UserInputState.Begin then
				onTurn(turn)
			end
			return Enum.ContextActionResult.Sink
		end
	end
	ContextActionService:BindAction(
		"VirageGauche",
		handler(-1),
		true,
		Enum.KeyCode.A,
		Enum.KeyCode.Q,
		Enum.KeyCode.Left,
		Enum.KeyCode.ButtonL1,
		Enum.KeyCode.DPadLeft
	)
	ContextActionService:BindAction(
		"VirageDroite",
		handler(1),
		true,
		Enum.KeyCode.D,
		Enum.KeyCode.Right,
		Enum.KeyCode.ButtonR1,
		Enum.KeyCode.DPadRight
	)
	ContextActionService:SetTitle("VirageGauche", "◀")
	ContextActionService:SetTitle("VirageDroite", "▶")
	ContextActionService:SetPosition("VirageGauche", UDim2.new(0.05, 0, 0.55, 0))
	ContextActionService:SetPosition("VirageDroite", UDim2.new(1, -110, 0.55, 0))
end

return Input

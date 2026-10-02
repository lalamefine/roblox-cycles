--!strict
-- Fine couche au-dessus d'AnalyticsService pour garder des noms d'événements cohérents
-- entre les jeux. Les tableaux de bord se lisent dans le Creator Hub (Analytics).

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

local function safe(fn: () -> ())
	local ok, err = pcall(fn :: any)
	if not ok then
		warn("[Analytics]", err)
	end
end

-- Étape d'un entonnoir ponctuel (ex. onboarding) : steps numérotés à partir de 1.
function Analytics.onboarding(player: Player, step: number, stepName: string)
	safe(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

-- Entonnoir récurrent (ex. une partie) : sessionId distingue chaque passage.
function Analytics.funnel(player: Player, funnelName: string, sessionId: string, step: number, stepName: string)
	safe(function()
		AnalyticsService:LogFunnelStepEvent(player, funnelName, sessionId, step, stepName)
	end)
end

-- Économie virtuelle : source (gain) ou sink (dépense) d'une monnaie du jeu.
function Analytics.economy(
	player: Player,
	isSource: boolean,
	currency: string,
	amount: number,
	endingBalance: number,
	transactionType: Enum.AnalyticsEconomyTransactionType,
	itemSku: string?
)
	safe(function()
		AnalyticsService:LogEconomyEvent(
			player,
			if isSource then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
			currency,
			amount,
			endingBalance,
			transactionType.Name,
			itemSku
		)
	end)
end

-- Événement custom avec une valeur numérique (ex. "MaxMass", 1234).
function Analytics.custom(player: Player, eventName: string, value: number?)
	safe(function()
		AnalyticsService:LogCustomEvent(player, eventName, value or 1)
	end)
end

return Analytics

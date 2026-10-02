--!strict
-- Game Passes et Developer Products.
-- ProcessReceipt est idempotent : chaque reçu est noté dans le profil (Data) avant
-- de répondre PurchaseGranted, donc un produit n'est jamais accordé deux fois.
-- Un id à 0 signifie « pas encore créé dans le Creator Hub » : l'offre est ignorée.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Data = require(script.Parent.Data)
local Signal = require(game:GetService("ReplicatedStorage").Shared.Kit.Signal)

export type Product = {
	id: number,
	name: string,
	-- Applique l'effet. Renvoie false si impossible maintenant (ex. joueur mort) :
	-- Roblox représentera le reçu plus tard.
	grant: (player: Player, profile: Data.Profile) -> boolean,
}

export type Pass = {
	id: number,
	name: string,
	-- Appelé au chargement si le joueur possède le passe, et juste après un achat.
	onOwned: ((player: Player) -> ())?,
}

local Shop = {}
Shop.PassOwned = Signal.new() :: Signal.Signal<Player, Pass>
Shop.ProductGranted = Signal.new() :: Signal.Signal<Player, Product>

local productsById: { [number]: Product } = {}
local passesById: { [number]: Pass } = {}
local passesByName: { [string]: Pass } = {}
local productsByName: { [string]: Product } = {}
local ownership: { [Player]: { [number]: boolean } } = {}

local function checkPasses(player: Player)
	local owned = {}
	ownership[player] = owned
	for id, pass in passesById do
		local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
		if ok and has then
			owned[id] = true
			if pass.onOwned then
				task.spawn(pass.onOwned, player)
			end
			Shop.PassOwned:Fire(player, pass)
		end
	end
end

function Shop.configure(cfg: { products: { Product }?, passes: { Pass }? })
	local productList: { Product } = cfg.products or {}
	local passList: { Pass } = cfg.passes or {}
	for _, p in productList do
		productsByName[p.name] = p
		if p.id ~= 0 then
			productsById[p.id] = p
		end
	end
	for _, p in passList do
		passesByName[p.name] = p
		if p.id ~= 0 then
			passesById[p.id] = p
		end
	end

	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local product = productsById[receipt.ProductId]
		if not player or not product then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local profile = Data.get(player)
		if not profile then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local receiptId = tostring(receipt.PurchaseId)
		if Data.hasReceipt(profile, receiptId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local ok, granted = pcall(product.grant, player, profile)
		if not ok then
			warn("[Shop] erreur dans grant", product.name, granted)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if not granted then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		Data.addReceipt(profile, receiptId)
		if not Data.save(player) then
			-- Le reçu est noté en mémoire : le prochain appel répondra PurchaseGranted sans re-accorder.
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		Shop.ProductGranted:Fire(player, product)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = passesById[passId]
		if not purchased or not pass then
			return
		end
		local owned = ownership[player]
		if owned and not owned[passId] then
			owned[passId] = true
			if pass.onOwned then
				task.spawn(pass.onOwned, player)
			end
			Shop.PassOwned:Fire(player, pass)
		end
	end)

	Players.PlayerAdded:Connect(checkPasses)
	for _, p in Players:GetPlayers() do
		task.spawn(checkPasses, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		ownership[p] = nil
	end)
end

function Shop.owns(player: Player, passName: string): boolean
	local pass = passesByName[passName]
	if not pass or pass.id == 0 then
		return false
	end
	local owned = ownership[player]
	return owned ~= nil and owned[pass.id] == true
end

-- Ouvre la fenêtre d'achat (à appeler côté serveur, ex. depuis un remote limité en débit).
function Shop.promptPass(player: Player, passName: string)
	local pass = passesByName[passName]
	if pass and pass.id ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
	end
end

function Shop.promptProduct(player: Player, productName: string)
	local product = productsByName[productName]
	if product and product.id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, product.id)
	end
end

return Shop

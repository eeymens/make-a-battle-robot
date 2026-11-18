-- Fabrika sistemi: arsa atama, hurda üretimi, toplama, upgrade satın alma, çevrimdışı kazanç.
-- Kural: bütün hesap sunucuda. Client sadece ProximityPrompt'u tetikler.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)
local GamePasses = require(ReplicatedStorage.Shared.Config.GamePasses)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ProductsConfig = require(ReplicatedStorage.Shared.Config.Products)
local PlotBuilder = require(script.Parent.PlotBuilder)
local Events = require(script.Parent.Events)

type State = {
	PlotIndex: number,
	Data: any,
	Rate: number,
	Capacity: number,
	Passes: { [string]: boolean },
	LastAction: number,
	BoostActive: boolean,
	BoxFullNotified: boolean,
}

local TycoonService = {}

local DataService
local notifyRemote: RemoteEvent
local plotsFolder: Folder
local plotOwners: { [number]: Player? } = {}
local states: { [Player]: State } = {}

---------------------------------------------------------------- yardımcılar

local function notify(player: Player, text: string, kind: string?)
	notifyRemote:FireClient(player, { Text = text, Kind = kind or "info" })
end

local function getPlot(index: number): Model
	return plotsFolder:FindFirstChild("Plot" .. index) :: Model
end

local function ownsPass(player: Player, passName: string): boolean
	local id = GamePasses[passName]
	if not id or id == 0 then
		return false
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
	return ok and owns == true
end

local function boostActive(state: State): boolean
	return os.time() < (state.Data.BoostUntil or 0)
end

local function passMultiplier(state: State): number
	local mult = if state.Passes.DoubleScrap then 2 else 1
	if boostActive(state) then
		mult *= ProductsConfig.Products.Boost.Multiplier
	end
	return mult
end

local function recalculate(state: State)
	state.BoostActive = boostActive(state)
	state.Rate = Formulas.Rate(state.Data, passMultiplier(state))
	state.Capacity = Formulas.Capacity(state.Data, state.Rate)
end

local function setLabel(part: Instance?, guiName: string, text: string)
	if not part then
		return
	end
	local gui = part:FindFirstChild(guiName)
	local label = gui and gui:FindFirstChild("Label")
	if label then
		(label :: TextLabel).Text = text
	end
end

local function canAct(state: State): boolean
	local now = os.clock()
	if now - state.LastAction < Economy.ActionCooldown then
		return false
	end
	state.LastAction = now
	return true
end

---------------------------------------------------------------- görsel güncelleme

local function updatePads(state: State)
	local plot = getPlot(state.PlotIndex)
	local pads = plot:FindFirstChild("Pads")
	if not pads then
		return
	end
	for _, upgrade in Upgrades.Ordered do
		local pad = pads:FindFirstChild(upgrade.Id)
		local level = state.Data.Upgrades[upgrade.Id] or 0
		local text
		if level >= upgrade.MaxLevel then
			text = `{upgrade.Name}\nMAKS ({level})`
		else
			local cost = Formulas.UpgradeCost(upgrade.Id, level)
			text = `{upgrade.Name} [{level}/{upgrade.MaxLevel}]\n{upgrade.Description}\n{Util.FormatNumber(cost)} Hurda`
		end
		setLabel(pad, "PadGui", text)
	end
end

local function updateBox(state: State)
	local plot = getPlot(state.PlotIndex)
	local text = `{Util.FormatNumber(state.Data.Stored)} / {Util.FormatNumber(state.Capacity)}`
	if state.Data.Stored >= state.Capacity then
		text ..= "\nKUTU DOLU!"
	end
	setLabel(plot:FindFirstChild("Box"), "BoxGui", text)
end

local function updateAttributes(player: Player, state: State)
	player:SetAttribute("Scrap", math.floor(state.Data.Scrap))
	player:SetAttribute("Stored", math.floor(state.Data.Stored))
	player:SetAttribute("Rate", state.Rate)
	player:SetAttribute("Capacity", state.Capacity)
	player:SetAttribute("BoostUntil", state.Data.BoostUntil or 0)

	local leaderstats = player:FindFirstChild("leaderstats")
	local scrapValue = leaderstats and leaderstats:FindFirstChild("Hurda")
	if scrapValue then
		(scrapValue :: IntValue).Value = math.floor(state.Data.Scrap)
	end
end

local function refreshAll(player: Player, state: State)
	updatePads(state)
	updateBox(state)
	updateAttributes(player, state)
end

---------------------------------------------------------------- diğer servisler için API

function TycoonService.Notify(player: Player, text: string, kind: string?)
	notify(player, text, kind)
end

-- Rate limit: false dönerse işlemi yapma
function TycoonService.CanAct(player: Player): boolean
	local state = states[player]
	return state ~= nil and canAct(state)
end

function TycoonService.HasPass(player: Player, passName: string): boolean
	local state = states[player]
	return state ~= nil and state.Passes[passName] == true
end

function TycoonService.GetPlot(player: Player): Model?
	local state = states[player]
	return if state then getPlot(state.PlotIndex) else nil
end

-- Veri başka bir servis tarafından değiştirilince (rebirth, boost, pass) üretimi yeniden hesapla
function TycoonService.Refresh(player: Player)
	local state = states[player]
	if state then
		recalculate(state)
		refreshAll(player, state)
	end
end

function TycoonService.GetRate(player: Player): number
	local state = states[player]
	return if state then state.Rate else 0
end

-- Hurda harca; yetmezse false döner ve hiçbir şey değişmez
function TycoonService.TrySpend(player: Player, amount: number): boolean
	local state = states[player]
	if not state or state.Data.Scrap < amount then
		return false
	end
	state.Data.Scrap -= amount
	updateAttributes(player, state)
	return true
end

-- Arena ödülü gibi dışarıdan gelen hurda
function TycoonService.GiveScrap(player: Player, amount: number)
	local state = states[player]
	if state and amount > 0 then
		state.Data.Scrap += amount
		state.Data.Stats.TotalScrap += amount
		updateAttributes(player, state)
	end
end

function TycoonService.SetTrophies(player: Player, trophies: number)
	player:SetAttribute("Trophies", trophies)
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Kupa")
	if value then
		(value :: IntValue).Value = trophies
	end
end

-- teleportToPlot aşağıda tanımlı; çağrı anında hazır olur
local teleportToPlot

function TycoonService.TeleportHome(player: Player)
	if player.Character then
		task.spawn(teleportToPlot, player, player.Character)
	end
end

---------------------------------------------------------------- oyun aksiyonları

local function addScrap(state: State, amount: number)
	state.Data.Scrap += amount
	state.Data.Stats.TotalScrap += amount
end

function TycoonService.Collect(player: Player)
	local state = states[player]
	if not state or not canAct(state) then
		return
	end
	local amount = math.floor(state.Data.Stored)
	if amount <= 0 then
		return
	end
	state.Data.Stored -= amount
	state.BoxFullNotified = false
	addScrap(state, amount)
	updateBox(state)
	updateAttributes(player, state)
	Events.Fire("CollectScrap", player, amount)
end

function TycoonService.BuyUpgrade(player: Player, upgradeId: string)
	local state = states[player]
	local upgrade = Upgrades.ById[upgradeId]
	if not state or not upgrade or not canAct(state) then
		return
	end

	local level = state.Data.Upgrades[upgradeId] or 0
	if level >= upgrade.MaxLevel then
		notify(player, `{upgrade.Name} zaten maksimum seviyede.`, "info")
		return
	end

	local cost = Formulas.UpgradeCost(upgradeId, level)
	if state.Data.Scrap < cost then
		notify(player, `Yetersiz hurda: {Util.FormatNumber(cost - state.Data.Scrap)} daha lazım.`, "error")
		return
	end

	state.Data.Scrap -= cost
	state.Data.Upgrades[upgradeId] = level + 1
	recalculate(state)
	refreshAll(player, state)
	notify(player, `{upgrade.Name} seviye {level + 1}!`, "success")
	Events.Fire("BuyUpgrade", player, 1)
end

---------------------------------------------------------------- oyuncu giriş / çıkış

teleportToPlot = function(player: Player, character: Model)
	local state = states[player]
	if not state then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	-- Roblox karakteri SpawnLocation'a yerleştirmeyi CharacterAdded'dan SONRA bitirebiliyor;
	-- hemen ışınlarsak geri çekiliyor. Karakter dünyaya girene kadar bekle, sonra biraz daha.
	if not character:IsDescendantOf(Workspace) then
		character.AncestryChanged:Wait()
	end
	task.wait(0.5)
	local spawnPoint = getPlot(state.PlotIndex):FindFirstChild("SpawnPoint") :: BasePart?
	if spawnPoint and character.Parent and states[player] then
		character:PivotTo(spawnPoint.CFrame + Vector3.new(0, 3, 0))
	end
end

local function claimPlot(player: Player): number?
	for index = 1, PlotBuilder.PlotCount do
		if plotOwners[index] == nil then
			plotOwners[index] = player
			return index
		end
	end
	return nil
end

local function createLeaderstats(player: Player, data)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local scrap = Instance.new("IntValue")
	scrap.Name = "Hurda"
	scrap.Parent = leaderstats
	local trophies = Instance.new("IntValue")
	trophies.Name = "Kupa"
	trophies.Value = data.Trophies
	trophies.Parent = leaderstats
	leaderstats.Parent = player
	player:SetAttribute("Trophies", data.Trophies)
end

local function onLoaded(player: Player, data)
	local plotIndex = claimPlot(player)
	if not plotIndex then
		player:Kick("Sunucu dolu, başka bir sunucuya katıl.")
		return
	end

	local state: State = {
		PlotIndex = plotIndex,
		Data = data,
		Rate = 0,
		Capacity = 0,
		Passes = {
			DoubleScrap = ownsPass(player, "DoubleScrap"),
			AutoCollect = ownsPass(player, "AutoCollect"),
			LuckyCrate = ownsPass(player, "LuckyCrate"),
			ExtraGarage = ownsPass(player, "ExtraGarage"),
			VIP = ownsPass(player, "VIP"),
		},
		LastAction = 0,
		BoostActive = false,
		BoxFullNotified = false,
	}
	states[player] = state
	recalculate(state)

	-- Çevrimdışı kazanç (boost çevrimdışıyken sayılmaz)
	if data.LastOnline > 0 then
		local offlineRate = Formulas.Rate(data, if state.Passes.DoubleScrap then 2 else 1)
		local elapsed = math.clamp(os.time() - data.LastOnline, 0, Formulas.OfflineMaxSeconds(data))
		local earned = math.floor(offlineRate * Economy.OfflineRatio * elapsed)
		if earned > 0 then
			addScrap(state, earned)
			player:SetAttribute("OfflineEarned", earned)
			notify(player, `Sen yokken fabrikan {Util.FormatNumber(earned)} hurda üretti!`, "success")
		end
	end

	createLeaderstats(player, data)
	player:SetAttribute("PlotIndex", plotIndex)
	local signText = `{player.DisplayName}'ın Fabrikası`
	if state.Passes.VIP then
		signText = "★ VIP ★\n" .. signText
	end
	setLabel(getPlot(plotIndex):FindFirstChild("Sign"), "OwnerGui", signText)
	refreshAll(player, state)

	player.CharacterAdded:Connect(function(character)
		teleportToPlot(player, character)
	end)
	if player.Character then
		task.spawn(teleportToPlot, player, player.Character)
	end
end

local function onReleasing(player: Player, _data)
	local state = states[player]
	if not state then
		return
	end
	states[player] = nil
	plotOwners[state.PlotIndex] = nil

	-- Arsayı sıfırla
	local plot = getPlot(state.PlotIndex)
	local robot = plot:FindFirstChild("Robot")
	if robot then
		robot:Destroy()
	end
	setLabel(plot:FindFirstChild("Sign"), "OwnerGui", "Boş Arsa")
	setLabel(plot:FindFirstChild("Box"), "BoxGui", "")
	local pads = plot:FindFirstChild("Pads")
	if pads then
		for _, pad in pads:GetChildren() do
			setLabel(pad, "PadGui", "")
		end
	end
end

local function onPassPurchased(player: Player, passId: number, purchased: boolean)
	local state = states[player]
	if not purchased or not state then
		return
	end
	for name, id in GamePasses do
		if id ~= 0 and id == passId then
			state.Passes[name] = true
			Events.Fire("PassPurchased", player, id)
		end
	end
	recalculate(state)
	refreshAll(player, state)
	notify(player, "Satın alma için teşekkürler!", "success")
end

---------------------------------------------------------------- prompt bağlantıları

local function ownerOfPrompt(prompt: ProximityPrompt, player: Player): boolean
	local plot = prompt:FindFirstAncestorWhichIsA("Model")
	local state = states[player]
	return plot ~= nil and state ~= nil and plot.Name == "Plot" .. state.PlotIndex
end

local function connectPlot(plot: Model)
	local box = plot:FindFirstChild("Box")
	local collectPrompt = box and box:FindFirstChild("CollectPrompt") :: ProximityPrompt?
	if collectPrompt then
		collectPrompt.Triggered:Connect(function(player)
			if ownerOfPrompt(collectPrompt, player) then
				TycoonService.Collect(player)
			else
				notify(player, "Bu senin fabrikan değil!", "error")
			end
		end)
	end

	local pads = plot:FindFirstChild("Pads")
	if pads then
		for _, pad in pads:GetChildren() do
			local prompt = pad:FindFirstChild("BuyPrompt") :: ProximityPrompt?
			if prompt then
				prompt.Triggered:Connect(function(player)
					if ownerOfPrompt(prompt, player) then
						TycoonService.BuyUpgrade(player, pad.Name)
					else
						notify(player, "Bu senin fabrikan değil!", "error")
					end
				end)
			end
		end
	end
end

---------------------------------------------------------------- başlatma

local function ensureGround()
	if Workspace:FindFirstChild("Baseplate") then
		return
	end
	local ground = Instance.new("Part")
	ground.Name = "Baseplate"
	ground.Anchored = true
	ground.Size = Vector3.new(512, 2, 512)
	ground.CFrame = CFrame.new(0, -1, 0)
	ground.Color = Color3.fromRGB(90, 94, 100)
	ground.Material = Enum.Material.Concrete
	ground.Parent = Workspace
end

local function productionTick()
	for player, state in states do
		local data = state.Data

		-- Boost başladı ya da bitti: üretimi yeniden hesapla
		if boostActive(state) ~= state.BoostActive then
			recalculate(state)
			updatePads(state)
			if not state.BoostActive then
				notify(player, "3x Boost bitti.", "info")
			end
		end

		local produced = state.Rate * Economy.TickInterval
		if state.Passes.AutoCollect then
			addScrap(state, produced)
		else
			data.Stored = math.min(data.Stored + produced, state.Capacity)
			if data.Stored >= state.Capacity and not state.BoxFullNotified then
				state.BoxFullNotified = true
				Events.Fire("BoxFull", player, 1)
			end
		end
		data.Stats.PlayTime += Economy.TickInterval

		updateBox(state)
		updateAttributes(player, state)
	end
end

function TycoonService.Init(dataService)
	DataService = dataService
	notifyRemote = Remotes.Event("Notify")

	ensureGround()

	-- Haritada elle yapılmış "Plots" klasörü varsa onu kullan, yoksa kodla oluştur
	local existing = Workspace:FindFirstChild("Plots")
	if existing then
		plotsFolder = existing :: Folder
	else
		plotsFolder = Instance.new("Folder")
		plotsFolder.Name = "Plots"
		plotsFolder.Parent = Workspace
		for index = 1, PlotBuilder.PlotCount do
			PlotBuilder.Build(index, plotsFolder)
		end
	end
	for index = 1, PlotBuilder.PlotCount do
		connectPlot(getPlot(index))
	end

	DataService.OnLoaded(onLoaded)
	DataService.OnReleasing(onReleasing)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPassPurchased)

	task.spawn(function()
		while true do
			task.wait(Economy.TickInterval)
			productionTick()
		end
	end)
end

return TycoonService

-- Parça sistemi: envanter, kasa açma (olasılık + pity), parça takma, birleştirme (fuse),
-- ve oyuncunun robotunu arsasındaki kaidede gösterme.
-- Client'tan gelen her istek sunucuda doğrulanır.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Crates = require(ReplicatedStorage.Shared.Config.Crates)
local Items = require(ReplicatedStorage.Shared.Items)
local RobotStats = require(ReplicatedStorage.Shared.RobotStats)
local RobotBuilder = require(ReplicatedStorage.Shared.RobotBuilder)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rebirth = require(ReplicatedStorage.Shared.Config.Rebirth)
local PlotBuilder = require(script.Parent.PlotBuilder)
local Events = require(script.Parent.Events)

local PartService = {}

local DataService
local TycoonService
local inventoryEvent: RemoteEvent
local crateEvent: RemoteEvent
local rng = Random.new()

---------------------------------------------------------------- yardımcılar

local function addItem(data, key: string, amount: number)
	local count = (data.Inventory[key] or 0) + amount
	data.Inventory[key] = if count > 0 then count else nil
end

local function snapshot(player: Player, data)
	return {
		Inventory = data.Inventory,
		Equipped = data.Equipped,
		Stats = RobotStats.Compute(data.Equipped),
		SincePity = data.CrateStats.SincePity,
		HasExtraGarage = TycoonService.HasPass(player, "ExtraGarage"),
		ActiveGarage = data.ActiveGarage or 1,
	}
end

local function push(player: Player, data)
	inventoryEvent:FireClient(player, snapshot(player, data))
end

-- Oyuncunun robotunu arsasındaki kaidede (yeniden) oluştur
local function updateDisplay(player: Player, data)
	local plot = TycoonService.GetPlot(player)
	local stand = plot and plot:FindFirstChild("RobotStand") :: BasePart?
	if not plot or not stand then
		return
	end

	local old = plot:FindFirstChild("Robot")
	if old then
		old:Destroy()
	end

	local cframe = stand.CFrame * CFrame.new(0, stand.Size.Y / 2, 0)
	local robot = RobotBuilder.Build(data.Equipped, cframe, true)
	local stats = RobotStats.Compute(data.Equipped)
	PlotBuilder.MakeBillboard(robot.PrimaryPart :: BasePart, "PowerGui", Vector2.new(160, 40), 9).Text = `Güç: {stats.Power}`
	player:SetAttribute("Power", stats.Power)
	robot.Parent = plot
end

local function rollRarity(player: Player, data, crate): string
	local lucky = TycoonService.HasPass(player, "LuckyCrate")
	local tokenLuck = 1 + Rebirth.Level(data, "CrateLuck") * Rebirth.ById.CrateLuck.Value
	local forceHighTier = data.CrateStats.SincePity + 1 >= crate.PityThreshold
	local minIndex = crate.MinRarityIndex or 1

	local weights = {}
	local total = 0
	for _, rarityId in Rarities.Ordered do
		local rarity = Rarities.ById[rarityId]
		local weight = rarity.Weight
		local highTier = rarity.Index >= Rarities.HighTierIndex
		if highTier then
			weight *= tokenLuck
			if lucky then
				weight *= 1.5
			end
		end
		if (forceHighTier and not highTier) or rarity.Index < minIndex then
			weight = 0
		end
		weights[rarityId] = weight
		total += weight
	end

	local roll = rng:NextNumber() * total
	for _, rarityId in Rarities.Ordered do
		roll -= weights[rarityId]
		if roll <= 0 then
			return rarityId
		end
	end
	return Rarities.Ordered[#Rarities.Ordered]
end

---------------------------------------------------------------- aksiyonlar

-- Kasayı ücretsiz ver (günlük ödül, Robux ürünü). Ödeme kontrolü çağıranda.
local function grantCrate(player: Player, data, crate)
	local rarityId = rollRarity(player, data, crate)
	local part = Parts.List[rng:NextInteger(1, #Parts.List)]

	data.CrateStats.Opened += 1
	if Rarities.ById[rarityId].Index >= Rarities.HighTierIndex then
		data.CrateStats.SincePity = 0
	else
		data.CrateStats.SincePity += 1
	end

	addItem(data, Items.Key(part.Id, rarityId), 1)
	-- Önce animasyon, sonra envanter: sonuç garajda animasyondan önce görünmesin
	crateEvent:FireClient(player, { PartId = part.Id, Rarity = rarityId })
	push(player, data)
	Events.Fire("OpenCrate", player, 1)
end

function PartService.OpenCrate(player: Player, crateId: any): boolean
	local data = DataService.Get(player)
	local crate = typeof(crateId) == "string" and Crates[crateId]
	-- Cost 0 olan kasalar (Mega) hurdayla açılamaz
	if not data or not crate or crate.Cost <= 0 or not TycoonService.CanAct(player) then
		return false
	end

	if not TycoonService.TrySpend(player, crate.Cost) then
		TycoonService.Notify(player, `Kasa için {crate.Cost} hurda lazım.`, "error")
		Events.Fire("CrateBlocked", player, 1)
		return false
	end

	grantCrate(player, data, crate)
	return true
end

-- Sunucu içinden bedava kasa (günlük ödül, VIP, Mega Kasa ürünü)
function PartService.GiveCrate(player: Player, crateId: string): boolean
	local data = DataService.Get(player)
	local crate = Crates[crateId]
	if not data or not crate then
		return false
	end
	grantCrate(player, data, crate)
	return true
end

-- Ekstra Garaj: takılı robot ile ikinci robotu yer değiştir
function PartService.SwapLoadout(player: Player): boolean
	local data = DataService.Get(player)
	if not data or not TycoonService.HasPass(player, "ExtraGarage") or not TycoonService.CanAct(player) then
		return false
	end
	if next(data.SecondLoadout) == nil then
		-- İlk kullanım: ikinci garaja hediye başlangıç robotu
		for slot, partId in Parts.Starter do
			data.SecondLoadout[slot] = { PartId = partId, Rarity = "Common" }
		end
	end
	data.Equipped, data.SecondLoadout = data.SecondLoadout, data.Equipped
	data.ActiveGarage = if data.ActiveGarage == 2 then 1 else 2
	updateDisplay(player, data)
	push(player, data)
	return true
end

function PartService.Equip(player: Player, key: any): boolean
	local data = DataService.Get(player)
	local partId, rarityId = Items.Parse(key)
	if not data or not partId or not rarityId or not TycoonService.CanAct(player) then
		return false
	end
	if (data.Inventory[key] or 0) < 1 then
		return false
	end

	local slot = Parts.ById[partId].Slot
	local current = data.Equipped[slot]

	addItem(data, key, -1)
	if current then
		addItem(data, Items.Key(current.PartId, current.Rarity), 1)
	end
	data.Equipped[slot] = { PartId = partId, Rarity = rarityId }

	updateDisplay(player, data)
	push(player, data)
	return true
end

function PartService.Fuse(player: Player, key: any): boolean
	local data = DataService.Get(player)
	local partId, rarityId = Items.Parse(key)
	if not data or not partId or not rarityId or not TycoonService.CanAct(player) then
		return false
	end

	local nextRarity = Rarities.Next(rarityId)
	if not nextRarity then
		TycoonService.Notify(player, "Mythic zaten en üst seviye.", "info")
		return false
	end
	if (data.Inventory[key] or 0) < 3 then
		TycoonService.Notify(player, "Birleştirmek için aynı parçadan 3 tane lazım.", "error")
		return false
	end

	addItem(data, key, -3)
	addItem(data, Items.Key(partId, nextRarity), 1)
	push(player, data)
	TycoonService.Notify(player, `Birleştirildi: {Items.DisplayName(partId, nextRarity)}!`, "success")
	Events.Fire("FusePart", player, 1)
	return true
end

---------------------------------------------------------------- giriş / çıkış

local function onLoaded(player: Player, data)
	-- Yeni oyuncuya başlangıç robotu
	if next(data.Equipped) == nil then
		for slot, partId in Parts.Starter do
			data.Equipped[slot] = { PartId = partId, Rarity = "Common" }
		end
	end
	updateDisplay(player, data)
	push(player, data)
end

---------------------------------------------------------------- başlatma

function PartService.Init(dataService, tycoonService)
	DataService = dataService
	TycoonService = tycoonService
	inventoryEvent = Remotes.Event("InventoryUpdated")
	crateEvent = Remotes.Event("CrateOpened")

	Remotes.Function("GetInventory").OnServerInvoke = function(player)
		local data = DataService.Get(player)
		return if data then snapshot(player, data) else nil
	end
	Remotes.Function("OpenCrate").OnServerInvoke = PartService.OpenCrate
	Remotes.Function("EquipPart").OnServerInvoke = PartService.Equip
	Remotes.Function("FusePart").OnServerInvoke = PartService.Fuse
	Remotes.Function("SwapLoadout").OnServerInvoke = PartService.SwapLoadout

	-- Ekstra Garaj pass'i oyun içinde alınınca garaj ekranı güncellensin
	Events.Connect("PassPurchased", function(player)
		local data = DataService.Get(player)
		if data then
			push(player, data)
		end
	end)

	-- Arsadaki kasa makineleri
	local plots = workspace:WaitForChild("Plots")
	for index = 1, PlotBuilder.PlotCount do
		local plot = plots:FindFirstChild("Plot" .. index)
		local machine = plot and plot:FindFirstChild("CrateMachine")
		local prompt = machine and machine:FindFirstChild("CratePrompt") :: ProximityPrompt?
		if prompt then
			prompt.Triggered:Connect(function(player)
				if TycoonService.GetPlot(player) == plot then
					PartService.OpenCrate(player, "Basic")
				else
					TycoonService.Notify(player, "Bu senin fabrikan değil!", "error")
				end
			end)
		end
	end

	DataService.OnLoaded(onLoaded)
end

return PartService

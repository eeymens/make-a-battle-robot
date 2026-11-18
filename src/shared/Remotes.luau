-- Tüm RemoteEvent / RemoteFunction'lar burada tanımlanır.
-- Sunucu Setup() ile oluşturur, client Event()/Function() ile bekleyip alır.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local EVENTS = {
	"Notify", -- sunucu -> client: { Text: string, Kind: "info" | "success" | "error" }
	"InventoryUpdated", -- sunucu -> client: envanter + takılı parçalar + statlar
	"CrateOpened", -- sunucu -> client: { PartId, Rarity } (kasa animasyonu için)

	-- Arena
	"ArenaQueue", -- sunucu -> client: { InQueue: boolean }
	"ArenaMatchStarted", -- sunucu -> client: { ArenaIndex, Side, Opponent, Countdown, Duration, AbilityName, AbilityCooldown }
	"ArenaMatchEnded", -- sunucu -> client: { Won, Reason, Reward, TrophyDelta, Trophies, League, LeagueUp }
	"ArenaFx", -- sunucu -> client: { Type = "hit" | "ability", ... }
	"ArenaInput", -- client -> sunucu: Vector3 yön (dünya, y=0)
	"ArenaAbility", -- client -> sunucu: ()
	"ArenaLeaveQueue", -- client -> sunucu: ()

	-- Aşama 4
	"RebirthUpdated", -- sunucu -> client: { Rebirths, Tokens, Cost, TokenUpgrades }
	"DailyUpdated", -- sunucu -> client: { LoginDay, CanClaimLogin, Quests, ... }
	"Offer", -- sunucu -> client: { Kind = "product" | "pass", Key, Text }
}

local FUNCTIONS = {
	"GetInventory", -- client -> sunucu: () -> snapshot?
	"OpenCrate", -- client -> sunucu: (crateId) -> boolean
	"EquipPart", -- client -> sunucu: (itemKey) -> boolean
	"FusePart", -- client -> sunucu: (itemKey) -> boolean
	"SwapLoadout", -- client -> sunucu: () -> boolean (Ekstra Garaj)
	"GetRebirth", -- client -> sunucu: () -> snapshot?
	"Rebirth", -- client -> sunucu: () -> boolean
	"BuyTokenNode", -- client -> sunucu: (nodeId) -> boolean
	"GetDaily", -- client -> sunucu: () -> snapshot?
	"ClaimLogin", -- client -> sunucu: () -> boolean
	"ClaimQuest", -- client -> sunucu: (index) -> boolean
}

local Remotes = {}

function Remotes.Setup()
	assert(RunService:IsServer(), "Remotes.Setup sadece sunucuda çağrılır")
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

local function getFolder()
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

function Remotes.Event(name: string): RemoteEvent
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	return getFolder():WaitForChild(name) :: RemoteFunction
end

return Remotes

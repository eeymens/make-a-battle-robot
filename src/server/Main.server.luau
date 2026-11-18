-- Sunucu giriş noktası. Sıra önemli: önce remote'lar, sonra dinleyiciler, en son veri yükleme.
-- DataService.OnLoaded callback'leri kayıt sırasıyla çalışır:
--   Tycoon (arsa atanır) -> Part (robot arsaya konur) -> Daily (VIP kasası, görevler)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Services = script.Parent.Services
local DataService = require(Services.DataService)
local TycoonService = require(Services.TycoonService)
local PartService = require(Services.PartService)
local ArenaService = require(Services.ArenaService)
local LeaderboardService = require(Services.LeaderboardService)
local RebirthService = require(Services.RebirthService)
local MonetizationService = require(Services.MonetizationService)
local DailyService = require(Services.DailyService)

Remotes.Setup()
TycoonService.Init(DataService)
PartService.Init(DataService, TycoonService)
ArenaService.Init(DataService, TycoonService)
RebirthService.Init(DataService, TycoonService)
MonetizationService.Init(DataService, TycoonService, PartService, ArenaService)
DailyService.Init(DataService, TycoonService, PartService)
DataService.Init() -- oyuncuları yüklemeye başlar
LeaderboardService.Init(DataService) -- IsMemoryOnly bilgisi DataService.Init'ten sonra belli olur

print("[Robot Arena Tycoon] Sunucu hazır" .. (if DataService.IsMemoryOnly() then " (veri kaydı KAPALI)" else ""))

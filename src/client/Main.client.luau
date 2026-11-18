-- Client giriş noktası. Menü butonları ekleniş sırasına göre değil LayoutOrder'a göre dizilir.

local HUD = require(script.Parent.HUD)
local ScrapVisuals = require(script.Parent.ScrapVisuals)
local GarageUI = require(script.Parent.GarageUI)
local CrateUI = require(script.Parent.CrateUI)
local ArenaController = require(script.Parent.ArenaController)
local ShopUI = require(script.Parent.ShopUI)
local RebirthUI = require(script.Parent.RebirthUI)
local DailyUI = require(script.Parent.DailyUI)

HUD.Init()
ScrapVisuals.Init()
GarageUI.Init()
CrateUI.Init()
ArenaController.Init()
ShopUI.Init()
RebirthUI.Init()
DailyUI.Init()

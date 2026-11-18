-- Sunucu içi basit olay sistemi. Servisler birbirini require etmeden haberleşir.
-- Örnek: TycoonService "BuyUpgrade" yayınlar, DailyService görev ilerlemesini sayar.
--
-- Olaylar (player, amount):
--   CollectScrap, BuyUpgrade, OpenCrate, FusePart, PlayMatch, WinMatch, LoseMatch, Rebirth,
--   CrateBlocked (hurda yetmedi), BoxFull

local Events = {}

local listeners: { [string]: { (Player, number) -> () } } = {}

function Events.Connect(name: string, callback: (Player, number) -> ())
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], callback)
end

function Events.Fire(name: string, player: Player, amount: number?)
	local list = listeners[name]
	if not list then
		return
	end
	for _, callback in list do
		task.spawn(callback, player, amount or 1)
	end
end

return Events

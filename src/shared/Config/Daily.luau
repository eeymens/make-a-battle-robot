-- Günlük giriş ödülü (7 günlük seri) ve günlük görevler.
-- Gün = UTC gün numarası (os.time() // 86400). Bir gün kaçırılırsa seri 1'e döner.

local Daily = {}

-- Hurda ödülü = max(Minimum, fabrika üretimi × ProductionSeconds) × Mult
Daily.LoginRewards = {
	{ Mult = 1 },
	{ Mult = 1.5 },
	{ Mult = 1, Crate = "Basic" },
	{ Mult = 2 },
	{ Mult = 2.5 },
	{ Mult = 3 },
	{ Mult = 3, Crate = "Mega" }, -- 7. gün: Epic+ garantili kasa
}
Daily.LoginMinimum = 500
Daily.LoginProductionSeconds = 2 * 60

-- Görev havuzu. Her gün bu havuzdan 3 tane seçilir (herkese aynı 3'ü).
-- Target: sayı ya da "üretim × saniye" (RateSeconds) olarak.
Daily.QuestsPerDay = 3
Daily.QuestPool = {
	{ Type = "CollectScrap", Text = "Kutudan %s hurda topla", RateSeconds = 5 * 60, Minimum = 1000 },
	{ Type = "BuyUpgrade", Text = "%s fabrika upgrade'i al", Target = 5 },
	{ Type = "OpenCrate", Text = "%s kasa aç", Target = 3 },
	{ Type = "PlayMatch", Text = "Arenada %s maç oyna", Target = 3 },
	{ Type = "WinMatch", Text = "Arenada %s maç kazan", Target = 2 },
	{ Type = "FusePart", Text = "%s parça birleştir", Target = 1 },
}
-- Görev ödülü: max(Minimum, üretim × saniye)
Daily.QuestRewardProductionSeconds = 3 * 60
Daily.QuestRewardMinimum = 750

function Daily.Today(): number
	return os.time() // 86400
end

return Daily

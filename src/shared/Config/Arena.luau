-- Arena ayarları: maç süresi, silah davranışları, yetenekler, ligler ve ödüller.
-- Denge değişikliği için sadece bu dosyayı düzenle.

local Arena = {}

-- Maç
Arena.MatchDuration = 90 -- saniye; süre biterse kalan can yüzdesi yüksek olan kazanır
Arena.Countdown = 3
Arena.Radius = 38 -- platform yarıçapı; dışına çıkan robot düşer ve kaybeder
Arena.FloorHeight = 30 -- platform üst yüzeyinin yüksekliği
Arena.Count = 3 -- aynı anda kaç maç oynanabilir (6 oyuncu = 3 maç)
Arena.BotWaitSeconds = 10 -- kuyrukta bu kadar bekleyince bot rakip gelir
Arena.PowerMatchRatio = 1.6 -- iki oyuncunun gücü en fazla bu oranda farklıysa eşleşir
Arena.ResultSeconds = 4 -- maç sonu ekranı

-- Hareket
Arena.TurnRate = math.rad(220) -- derece/sn
Arena.Friction = 3.5 -- savrulma hızının saniyede sönme oranı
Arena.InputTimeout = 0.6 -- oyuncu bu kadar süre yön vermezse robot kendi saldırır
Arena.MassDivisor = 15 -- savrulma direnci = ağırlık / bu sayı

-- Silahlar. Range = gövde kenarından menzil, Arc = vuruş açısı (önden), Interval = vuruşlar arası
Arena.Weapons = {
	Saw = {
		Range = 2.5,
		Arc = math.rad(70),
		Interval = 0.3,
		DamageFactor = 0.35,
		Knockback = 4,
		Ability = { Id = "Turbo", Name = "Turbo", Cooldown = 8, Duration = 2.5, SpeedMult = 1.8, DamageMult = 1.5 },
	},
	HammerArm = {
		Range = 3.5,
		Arc = math.rad(60),
		Interval = 1.1,
		DamageFactor = 1.1,
		Knockback = 26,
		Ability = { Id = "Shockwave", Name = "Şok Dalgası", Cooldown = 10, Radius = 9, DamageFactor = 1.5, Knockback = 34 },
	},
	Flamethrower = {
		Range = 6,
		Arc = math.rad(40),
		Interval = 0.2,
		DamageFactor = 0.22,
		Knockback = 0.5,
		Burn = { Duration = 3, DpsFactor = 0.3 },
		Ability = { Id = "Inferno", Name = "Alev Patlaması", Cooldown = 9, Duration = 2, RangeBonus = 4, DamageMult = 2 },
	},
}

-- Ligler (kupa sayısına göre). Mult = ödül çarpanı
Arena.Leagues = {
	{ Name = "Bronz", Min = 0, Mult = 1, Color = Color3.fromRGB(205, 127, 50) },
	{ Name = "Gümüş", Min = 300, Mult = 1.25, Color = Color3.fromRGB(192, 192, 192) },
	{ Name = "Altın", Min = 800, Mult = 1.5, Color = Color3.fromRGB(241, 196, 15) },
	{ Name = "Elmas", Min = 1600, Mult = 2, Color = Color3.fromRGB(93, 173, 226) },
	{ Name = "Şampiyon", Min = 3000, Mult = 3, Color = Color3.fromRGB(231, 76, 60) },
}

-- Ödüller. Galibiyet hurdası = max(BaseWin, fabrika üretimi × RateSeconds) × lig çarpanı
Arena.Rewards = {
	BaseWin = 50,
	RateSeconds = 25, -- arena geliri fabrika gelirinin ~%30'u olsun diye
	LoserRatio = 0.3,
	TrophyWin = 25,
	TrophyWinBot = 15, -- bota karşı kazanmak biraz daha az kupa verir
	TrophyLoss = 15,
}

-- Arena merkezinin (platform üst yüzeyi) dünya konumu. Sunucu ve client aynı hesabı kullanır.
function Arena.GetCenter(index: number): Vector3
	return Vector3.new((index - 2) * 140, Arena.FloorHeight, 420)
end

function Arena.GetLeague(trophies: number)
	local league = Arena.Leagues[1]
	for _, candidate in Arena.Leagues do
		if trophies >= candidate.Min then
			league = candidate
		end
	end
	return league
end

return Arena

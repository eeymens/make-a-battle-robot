-- Arena: kuyruk, eşleştirme, bot rakip, maç simülasyonu, ödül ve kupa.
--
-- Maçın tamamı sunucuda hesaplanır (konum, hasar, savrulma). Robot modelleri AlignPosition ile
-- hesaplanan konuma çekilir; böylece client'larda fizik replikasyonu sayesinde akıcı görünür
-- ama hile yapılamaz. Client sadece yön (ArenaInput) ve yetenek (ArenaAbility) gönderir.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arena = require(ReplicatedStorage.Shared.Config.Arena)
local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local RobotStats = require(ReplicatedStorage.Shared.RobotStats)
local RobotBuilder = require(ReplicatedStorage.Shared.RobotBuilder)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rebirth = require(ReplicatedStorage.Shared.Config.Rebirth)
local ProductsConfig = require(ReplicatedStorage.Shared.Config.Products)
local ArenaBuilder = require(script.Parent.ArenaBuilder)
local Events = require(script.Parent.Events)

local ArenaService = {}

local DataService
local TycoonService
local arenasFolder: Folder
local rng = Random.new()

local remotes = {} :: { [string]: RemoteEvent }

local queue: { Player } = {}
local queuedAt: { [Player]: number } = {}
local matches: { [number]: any } = {} -- arena index -> match
local playerMatch: { [Player]: any } = {}
local lastInputAt: { [Player]: number } = {}

local BOT_NAMES = { "Paslı Pete", "Vida Vedat", "Çark Ceren", "Turbo Tayfun", "Hurdacı Hasan", "Somun Selin", "Kıvılcım Kaan" }

---------------------------------------------------------------- yardımcılar

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function forwardOf(heading: number): Vector3
	return Vector3.new(-math.sin(heading), 0, -math.cos(heading))
end

local function headingOf(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

local function matchPlayers(match): { Player }
	local list = {}
	for _, fighter in match.Fighters do
		if fighter.Player and fighter.Player.Parent then
			table.insert(list, fighter.Player)
		end
	end
	return list
end

local function fx(match, payload)
	for _, player in matchPlayers(match) do
		remotes.ArenaFx:FireClient(player, payload)
	end
end

local function otherFighter(match, fighter)
	return if match.Fighters[1] == fighter then match.Fighters[2] else match.Fighters[1]
end

local function setCharacterParked(player: Player, spot: BasePart?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	if spot then
		character:PivotTo(spot.CFrame + Vector3.new(0, 3, 0))
		root.Anchored = true
	else
		root.Anchored = false
	end
end

---------------------------------------------------------------- dövüşçü oluşturma

-- Bot için oyuncunun ekipmanına benzer güçte ama farklı parçalardan bir robot
local function botEquipment(reference)
	local equipped = {}
	for _, slot in Parts.Slots do
		local item = reference[slot]
		if item then
			local options = {}
			for _, part in Parts.List do
				if part.Slot == slot then
					table.insert(options, part.Id)
				end
			end
			equipped[slot] = { PartId = options[rng:NextInteger(1, #options)], Rarity = item.Rarity }
		end
	end
	return equipped
end

local function makeFighter(match, side: number, name: string, equipped, player: Player?, statMult: number)
	local stats = RobotStats.Compute(equipped)
	local weaponId = if equipped.Weapon then equipped.Weapon.PartId else "Saw"
	local weapon = Arena.Weapons[weaponId] or Arena.Weapons.Saw

	-- 1. taraf +Z'de -Z'ye bakar, 2. taraf -Z'de +Z'ye bakar
	local startPos = Vector3.new(0, 0, if side == 1 then 14 else -14)
	local heading = if side == 1 then 0 else math.pi

	local model = RobotBuilder.Build(equipped, CFrame.new(match.Center + startPos) * CFrame.Angles(0, heading, 0), false)
	model.Name = "Robot" .. side
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end

	local root = model.PrimaryPart :: BasePart
	local attachment = Instance.new("Attachment")
	attachment.Parent = root

	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Attachment0 = attachment
	alignPosition.MaxForce = 1e7
	alignPosition.Responsiveness = 80
	alignPosition.Position = root.Position
	alignPosition.Parent = root

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.MaxTorque = 1e7
	alignOrientation.Responsiveness = 60
	alignOrientation.CFrame = root.CFrame.Rotation
	alignOrientation.Parent = root

	local hp = math.max(1, math.floor(stats.HP * statMult))
	model:SetAttribute("Side", side)
	model:SetAttribute("DisplayName", name)
	model:SetAttribute("HP", hp)
	model:SetAttribute("MaxHP", hp)
	model:SetAttribute("Power", math.floor(stats.Power * statMult))
	model.Parent = match.Folder
	pcall(function()
		root:SetNetworkOwner(nil) -- fizik sunucuda kalsın
	end)

	return {
		Side = side,
		Name = name,
		Player = player,
		Model = model,
		AlignPosition = alignPosition,
		AlignOrientation = alignOrientation,
		Weapon = weapon,
		Damage = math.max(1, stats.Damage * statMult),
		Speed = math.max(6, stats.Speed),
		Radius = RobotBuilder.BodyRadius(equipped.Body and equipped.Body.PartId),
		Mass = math.clamp(stats.Weight / Arena.MassDivisor, 0.6, 2.5),
		Pos = startPos,
		Heading = heading,
		Knock = Vector3.zero,
		HP = hp,
		MaxHP = hp,
		AttackTimer = 0.5,
		AbilityReadyAt = 0,
		TurboUntil = 0,
		InfernoUntil = 0,
		BurnUntil = 0,
		BurnDps = 0,
		Input = Vector3.zero,
		InputAt = 0,
		Out = false,
	}
end

---------------------------------------------------------------- savaş

local function applyDamage(fighter, amount: number)
	if amount <= 0 or fighter.HP <= 0 then
		return
	end
	fighter.HP = math.max(0, fighter.HP - amount)
	fighter.Model:SetAttribute("HP", math.ceil(fighter.HP))
end

local function useAbility(match, fighter, now: number)
	if match.State ~= "fight" or now < fighter.AbilityReadyAt or fighter.Out then
		return
	end
	local ability = fighter.Weapon.Ability
	fighter.AbilityReadyAt = now + ability.Cooldown

	if ability.Id == "Turbo" then
		fighter.TurboUntil = now + ability.Duration
	elseif ability.Id == "Inferno" then
		fighter.InfernoUntil = now + ability.Duration
	elseif ability.Id == "Shockwave" then
		local enemy = otherFighter(match, fighter)
		local offset = flat(enemy.Pos - fighter.Pos)
		local distance = offset.Magnitude
		if distance - enemy.Radius <= ability.Radius then
			local direction = if distance > 0.01 then offset / distance else forwardOf(fighter.Heading)
			applyDamage(enemy, fighter.Damage * ability.DamageFactor)
			enemy.Knock += direction * (ability.Knockback / enemy.Mass)
		end
	end

	fx(match, {
		Type = "ability",
		Ability = ability.Id,
		Side = fighter.Side,
		Position = match.Center + fighter.Pos,
	})
end

local function stepFighter(match, fighter, enemy, now: number, dt: number)
	-- Yanma hasarı
	if now < fighter.BurnUntil then
		applyDamage(fighter, fighter.BurnDps * dt)
	end

	local toEnemy = flat(enemy.Pos - fighter.Pos)
	local distance = toEnemy.Magnitude
	local dirToEnemy = if distance > 0.01 then toEnemy / distance else forwardOf(fighter.Heading)

	-- İstenen yön: oyuncu yön veriyorsa o, vermiyorsa robot kendi saldırır
	local desired
	local manual = fighter.Player ~= nil and now - fighter.InputAt < Arena.InputTimeout and fighter.Input.Magnitude > 0.1
	if manual then
		desired = fighter.Input.Unit
	else
		desired = dirToEnemy
		if not fighter.Player then
			-- Bot: hafif yan yan dolaşarak yaklaşır
			local side = Vector3.new(-dirToEnemy.Z, 0, dirToEnemy.X)
			desired = (dirToEnemy + side * 0.35 * math.sin(now * 1.3 + fighter.Side * 2)).Unit
		end
		-- Kenara yaklaşınca merkeze dön
		local fromCenter = fighter.Pos.Magnitude
		if fromCenter > Arena.Radius - 8 and fromCenter > 0.01 then
			desired = (desired - fighter.Pos.Unit * 1.5).Unit
		end
	end

	-- Dönüş (tank gibi: önce döner, sonra gider)
	local diff = (headingOf(desired) - fighter.Heading + math.pi) % (2 * math.pi) - math.pi
	local maxTurn = Arena.TurnRate * dt
	fighter.Heading += math.clamp(diff, -maxTurn, maxTurn)
	local forward = forwardOf(fighter.Heading)
	local alignment = math.max(forward:Dot(desired), 0)

	local speed = fighter.Speed
	local ability = fighter.Weapon.Ability
	local turbo = now < fighter.TurboUntil
	if turbo then
		speed *= ability.SpeedMult
	end

	fighter.Pos += (forward * speed * (0.25 + 0.75 * alignment) + fighter.Knock) * dt
	fighter.Knock *= math.max(0, 1 - Arena.Friction * dt)

	-- Saldırı
	fighter.AttackTimer -= dt
	local inferno = now < fighter.InfernoUntil
	local range = fighter.Weapon.Range + (if inferno then ability.RangeBonus else 0)
	local edgeDistance = distance - fighter.Radius - enemy.Radius
	local angle = math.acos(math.clamp(forward:Dot(dirToEnemy), -1, 1))

	if fighter.AttackTimer <= 0 and edgeDistance <= range and angle <= fighter.Weapon.Arc / 2 then
		fighter.AttackTimer = fighter.Weapon.Interval
		local mult = 1
		if turbo then
			mult *= ability.DamageMult
		end
		if inferno then
			mult *= ability.DamageMult
		end
		local damage = fighter.Damage * fighter.Weapon.DamageFactor * mult
		applyDamage(enemy, damage)
		enemy.Knock += dirToEnemy * (fighter.Weapon.Knockback / enemy.Mass)
		local burn = fighter.Weapon.Burn
		if burn then
			enemy.BurnUntil = now + burn.Duration
			enemy.BurnDps = fighter.Damage * burn.DpsFactor
		end
		fx(match, {
			Type = "hit",
			Side = enemy.Side,
			Amount = math.floor(damage * 10) / 10,
			Position = match.Center + enemy.Pos + Vector3.new(0, 4, 0),
		})
	end

	-- Bot yeteneği menzildeyken kullanır
	if not fighter.Player and now >= fighter.AbilityReadyAt and edgeDistance <= range + 2 then
		useAbility(match, fighter, now)
	end
end

local function separate(a, b)
	local offset = flat(b.Pos - a.Pos)
	local distance = offset.Magnitude
	local minimum = a.Radius + b.Radius
	if distance < minimum then
		local normal = if distance > 0.01 then offset / distance else Vector3.xAxis
		local push = (minimum - distance) / 2
		a.Pos -= normal * push
		b.Pos += normal * push
	end
end

---------------------------------------------------------------- maç akışı

local endMatch -- ileri bildirim

local function step(match, dt: number)
	local now = os.clock()
	if match.State == "countdown" then
		if now >= match.FightAt then
			match.State = "fight"
		end
		return
	end
	if match.State ~= "fight" then
		return
	end

	local a, b = match.Fighters[1], match.Fighters[2]
	stepFighter(match, a, b, now, dt)
	stepFighter(match, b, a, now, dt)
	separate(a, b)

	for _, fighter in match.Fighters do
		if not fighter.Out and fighter.Pos.Magnitude > Arena.Radius then
			-- Platformdan düştü: hizalamayı kapat, yerçekimi halletsin
			fighter.Out = true
			fighter.AlignPosition.Enabled = false
			fighter.AlignOrientation.Enabled = false
		end
		if not fighter.Out then
			fighter.AlignPosition.Position = match.Center + fighter.Pos
			fighter.AlignOrientation.CFrame = CFrame.Angles(0, fighter.Heading, 0)
		end
	end

	local timeLeft = math.max(0, math.ceil(match.EndAt - now))
	if timeLeft ~= match.Folder:GetAttribute("TimeLeft") then
		match.Folder:SetAttribute("TimeLeft", timeLeft)
	end

	local winner, reason
	if a.Out or a.HP <= 0 then
		winner, reason = b, if a.Out then "ringout" else "destroyed"
	elseif b.Out or b.HP <= 0 then
		winner, reason = a, if b.Out then "ringout" else "destroyed"
	elseif now >= match.EndAt then
		winner = if a.HP / a.MaxHP >= b.HP / b.MaxHP then a else b
		reason = "time"
	end
	if winner then
		endMatch(match, winner, reason)
	end
end

local function rewardPlayer(match, fighter, won: boolean, reason: string)
	local player = fighter.Player
	local data = player and DataService.Get(player)
	if not player or not data then
		return
	end

	local rewards = Arena.Rewards
	local leagueBefore = Arena.GetLeague(data.Trophies)
	local rate = player:GetAttribute("Rate") or 0
	local tokenBonus = 1 + Rebirth.Level(data, "ArenaBonus") * Rebirth.ById.ArenaBonus.Value
	local base = math.max(rewards.BaseWin, rate * rewards.RateSeconds) * leagueBefore.Mult * tokenBonus
	local scrap = math.floor(if won then base else base * rewards.LoserRatio)

	local trophyDelta
	if won then
		trophyDelta = if match.IsBot then rewards.TrophyWinBot else rewards.TrophyWin
		data.Stats.Wins = (data.Stats.Wins or 0) + 1
	else
		trophyDelta = -math.min(rewards.TrophyLoss, data.Trophies)
		data.Stats.Losses = (data.Stats.Losses or 0) + 1
	end
	data.Trophies += trophyDelta
	TycoonService.GiveScrap(player, scrap)
	TycoonService.SetTrophies(player, data.Trophies)

	local leagueAfter = Arena.GetLeague(data.Trophies)
	remotes.ArenaMatchEnded:FireClient(player, {
		Won = won,
		Reason = reason,
		Reward = scrap,
		TrophyDelta = trophyDelta,
		Trophies = data.Trophies,
		League = leagueAfter.Name,
		LeagueUp = leagueAfter.Min > leagueBefore.Min,
	})

	Events.Fire("PlayMatch", player, 1)
	Events.Fire(if won then "WinMatch" else "LoseMatch", player, 1)
end

local function cleanup(match)
	if match.Folder then
		match.Folder:Destroy()
	end
	matches[match.Index] = nil
	for _, fighter in match.Fighters do
		local player = fighter.Player
		if player then
			playerMatch[player] = nil
			if player.Parent then
				setCharacterParked(player, nil)
				TycoonService.TeleportHome(player)
			end
		end
	end
end

endMatch = function(match, winner, reason: string)
	if match.State == "ended" then
		return
	end
	match.State = "ended"
	for _, fighter in match.Fighters do
		rewardPlayer(match, fighter, fighter == winner, reason)
	end
	task.delay(Arena.ResultSeconds, cleanup, match)
end

local function startMatch(index: number, playerA: Player, playerB: Player?)
	local dataA = DataService.Get(playerA)
	local dataB = playerB and DataService.Get(playerB)
	if not dataA or (playerB and not dataB) then
		for _, player in { playerA, playerB } do
			if player and player.Parent then
				remotes.ArenaQueue:FireClient(player, { InQueue = false })
			end
		end
		return
	end

	local arenaModel = arenasFolder:FindFirstChild("Arena" .. index) :: Model
	local folder = Instance.new("Folder")
	folder.Name = "Match"
	folder:SetAttribute("TimeLeft", Arena.MatchDuration)
	folder.Parent = arenaModel

	local now = os.clock()
	local match = {
		Index = index,
		Center = ArenaBuilder.GetCenter(index),
		Folder = folder,
		Fighters = {},
		IsBot = playerB == nil,
		State = "countdown",
		FightAt = now + Arena.Countdown,
		EndAt = now + Arena.Countdown + Arena.MatchDuration,
	}
	matches[index] = match

	match.Fighters[1] = makeFighter(match, 1, playerA.DisplayName, dataA.Equipped, playerA, 1)
	if playerB then
		match.Fighters[2] = makeFighter(match, 2, playerB.DisplayName, dataB.Equipped, playerB, 1)
	else
		-- Bot biraz daha zayıf başlar ki yeni oyuncular ilk maçları kazanabilsin
		local botName = BOT_NAMES[rng:NextInteger(1, #BOT_NAMES)] .. " (Bot)"
		match.Fighters[2] = makeFighter(match, 2, botName, botEquipment(dataA.Equipped), nil, rng:NextNumber(0.8, 0.95))
	end

	for _, fighter in match.Fighters do
		local player = fighter.Player
		if player then
			playerMatch[player] = match
			local spot = arenaModel:FindFirstChild("Spot" .. fighter.Side) :: BasePart?
			setCharacterParked(player, spot)
			local enemy = otherFighter(match, fighter)
			local ability = fighter.Weapon.Ability
			remotes.ArenaQueue:FireClient(player, { InQueue = false })
			remotes.ArenaMatchStarted:FireClient(player, {
				ArenaIndex = index,
				Side = fighter.Side,
				Opponent = enemy.Name,
				Countdown = Arena.Countdown,
				Duration = Arena.MatchDuration,
				AbilityName = ability.Name,
				AbilityCooldown = ability.Cooldown,
			})
		end
	end
end

-- Tamir Kiti (Robux): devam eden maçta canın %50'si, maç başına 1 kez.
-- Uygulanamazsa false döner (MonetizationService o zaman karşılığında hurda verir).
function ArenaService.Repair(player: Player): boolean
	local match = playerMatch[player]
	if not match or match.State ~= "fight" then
		return false
	end
	for _, fighter in match.Fighters do
		if fighter.Player == player and not fighter.Repaired and not fighter.Out and fighter.HP > 0 then
			fighter.Repaired = true
			fighter.HP = math.min(fighter.MaxHP, fighter.HP + fighter.MaxHP * ProductsConfig.Products.Repair.HealRatio)
			fighter.Model:SetAttribute("HP", math.ceil(fighter.HP))
			fx(match, { Type = "ability", Ability = "Repair", Side = fighter.Side, Position = match.Center + fighter.Pos })
			return true
		end
	end
	return false
end

---------------------------------------------------------------- kuyruk

local function removeFromQueue(player: Player)
	local index = table.find(queue, player)
	if index then
		table.remove(queue, index)
	end
	queuedAt[player] = nil
end

function ArenaService.JoinQueue(player: Player)
	if playerMatch[player] or table.find(queue, player) then
		return
	end
	if not DataService.Get(player) or not TycoonService.GetPlot(player) then
		return
	end
	table.insert(queue, player)
	queuedAt[player] = os.clock()
	remotes.ArenaQueue:FireClient(player, { InQueue = true })
	TycoonService.Notify(player, "Rakip aranıyor...", "info")
end

function ArenaService.LeaveQueue(player: Player)
	if table.find(queue, player) then
		removeFromQueue(player)
		remotes.ArenaQueue:FireClient(player, { InQueue = false })
	end
end

local function freeArena(): number?
	for index = 1, Arena.Count do
		if not matches[index] then
			return index
		end
	end
	return nil
end

local function powerOf(player: Player): number
	return math.max(1, player:GetAttribute("Power") or 1)
end

local function matchmake()
	-- 1) Benzer güçteki iki oyuncuyu eşleştir
	local i = 1
	while i <= #queue do
		local a = queue[i]
		local paired = false
		for j = i + 1, #queue do
			local b = queue[j]
			local ratio = math.max(powerOf(a), powerOf(b)) / math.min(powerOf(a), powerOf(b))
			local arena = freeArena()
			if ratio <= Arena.PowerMatchRatio and arena then
				removeFromQueue(b)
				removeFromQueue(a)
				startMatch(arena, a, b)
				paired = true
				break
			end
		end
		if not paired then
			i += 1
		end
	end

	-- 2) Uzun bekleyenlere bot rakip
	local now = os.clock()
	for _, player in table.clone(queue) do
		local arena = freeArena()
		if not arena then
			break
		end
		if now - (queuedAt[player] or now) >= Arena.BotWaitSeconds then
			removeFromQueue(player)
			startMatch(arena, player, nil)
		end
	end
end

---------------------------------------------------------------- başlatma

local function onPlayerRemoving(player: Player)
	removeFromQueue(player)
	lastInputAt[player] = nil
	local match = playerMatch[player]
	if match and match.State ~= "ended" then
		for _, fighter in match.Fighters do
			if fighter.Player == player then
				fighter.HP = 0
				endMatch(match, otherFighter(match, fighter), "left")
			end
		end
	end
	playerMatch[player] = nil
end

function ArenaService.Init(dataService, tycoonService)
	DataService = dataService
	TycoonService = tycoonService

	for _, name in { "ArenaQueue", "ArenaMatchStarted", "ArenaMatchEnded", "ArenaFx", "ArenaInput", "ArenaAbility", "ArenaLeaveQueue" } do
		remotes[name] = Remotes.Event(name)
	end

	arenasFolder = ArenaBuilder.Build()

	local gate = arenasFolder:FindFirstChild("ArenaGate")
	local prompt = gate and gate:FindFirstChild("JoinPrompt", true) :: ProximityPrompt?
	if prompt then
		prompt.Triggered:Connect(ArenaService.JoinQueue)
	end

	remotes.ArenaLeaveQueue.OnServerEvent:Connect(ArenaService.LeaveQueue)

	remotes.ArenaInput.OnServerEvent:Connect(function(player, direction)
		local match = playerMatch[player]
		if not match or typeof(direction) ~= "Vector3" then
			return
		end
		-- NaN / sonsuz değerleri reddet
		if direction.X ~= direction.X or direction.Z ~= direction.Z or math.abs(direction.X) > 10 or math.abs(direction.Z) > 10 then
			return
		end
		local now = os.clock()
		if now - (lastInputAt[player] or 0) < 0.03 then
			return -- saniyede ~30'dan fazla mesaj yok sayılır
		end
		lastInputAt[player] = now
		local move = flat(direction)
		if move.Magnitude > 1 then
			move = move.Unit
		end
		for _, fighter in match.Fighters do
			if fighter.Player == player then
				fighter.Input = move
				fighter.InputAt = now
			end
		end
	end)

	remotes.ArenaAbility.OnServerEvent:Connect(function(player)
		local match = playerMatch[player]
		if not match then
			return
		end
		for _, fighter in match.Fighters do
			if fighter.Player == player then
				useAbility(match, fighter, os.clock())
			end
		end
	end)

	Players.PlayerRemoving:Connect(onPlayerRemoving)

	RunService.Heartbeat:Connect(function(dt)
		local clamped = math.min(dt, 0.1)
		for _, match in matches do
			step(match, clamped)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			matchmake()
		end
	end)
end

return ArenaService

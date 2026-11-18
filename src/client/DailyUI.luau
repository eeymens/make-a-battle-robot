-- Günlük paneli: 7 günlük giriş ödülü serisi ve 3 günlük görev.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Daily = require(ReplicatedStorage.Shared.Config.Daily)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)
local UIKit = require(script.Parent.UIKit)
local SideMenu = require(script.Parent.SideMenu)

local player = Players.LocalPlayer
local C = UIKit.Colors
local ORANGE = Color3.fromRGB(230, 126, 34)

local DailyUI = {}

local snapshot = nil
local panel: Frame
local dayCards: { Frame } = {}
local dayLabels: { TextLabel } = {}
local claimButton: TextButton
local questRows: { { Text: TextLabel, Bar: Frame, Button: TextButton } } = {}
local busy = false

local function invoke(name: string, arg)
	if busy then
		return
	end
	busy = true
	pcall(function()
		Remotes.Function(name):InvokeServer(arg)
	end)
	busy = false
end

local function render()
	if not snapshot then
		return
	end
	for day, card in dayCards do
		local reward = Daily.LoginRewards[day]
		local claimedToday = not snapshot.CanClaimLogin and day <= snapshot.LoginDay
		local claimedStreak = snapshot.CanClaimLogin and day < snapshot.LoginDay
		local isNext = snapshot.CanClaimLogin and day == snapshot.LoginDay
		card.BackgroundColor3 = if isNext then ORANGE elseif claimedToday or claimedStreak then C.CardHover else C.Card
		local amount = Util.FormatNumber(snapshot.LoginBase * reward.Mult)
		local crateText = if reward.Crate == "Mega" then "\n+Mega Kasa" elseif reward.Crate then "\n+Kasa" else ""
		local check = if claimedToday or claimedStreak then "✓ " else ""
		dayLabels[day].Text = `{check}{day}. gün\n{amount}{crateText}`
	end
	claimButton.Visible = snapshot.CanClaimLogin
	claimButton.Text = `{snapshot.LoginDay}. gün ödülünü al!`

	for i, row in questRows do
		local quest = snapshot.Quests[i]
		if quest then
			row.Text.Text = `{quest.Text}  ({Util.FormatNumber(quest.Progress)}/{Util.FormatNumber(quest.Target)})`
			row.Bar.Size = UDim2.fromScale(math.clamp(quest.Progress / quest.Target, 0, 1), 1)
			local done = quest.Progress >= quest.Target
			if quest.Claimed then
				row.Button.Text = "Alındı"
				row.Button.BackgroundColor3 = C.Card
			elseif done then
				row.Button.Text = `+{Util.FormatNumber(snapshot.QuestReward)}`
				row.Button.BackgroundColor3 = C.Good
			else
				row.Button.Text = `{Util.FormatNumber(snapshot.QuestReward)}`
				row.Button.BackgroundColor3 = C.Card
			end
		end
	end
end

local function build()
	local content
	panel, content = SideMenu.CreatePanel("GÜNLÜK", Vector2.new(640, 430), ORANGE)

	UIKit.Label({
		Text = "Her gün gir, seriyi bozma! 7. gün Mega Kasa.",
		Font = Enum.Font.GothamMedium,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 20),
		Parent = content,
	})
	local count = #Daily.LoginRewards
	for day = 1, count do
		local card = UIKit.Frame({
			Position = UDim2.new((day - 1) / count, 2, 0, 26),
			Size = UDim2.new(1 / count, -4, 0, 76),
			Parent = content,
		})
		UIKit.Corner(card, 8)
		dayLabels[day] = UIKit.Label({
			Text = "",
			Font = Enum.Font.GothamMedium,
			Size = UDim2.new(1, -8, 1, -8),
			Position = UDim2.fromOffset(4, 4),
			Parent = card,
		})
		dayCards[day] = card
	end
	claimButton = UIKit.Button({
		Text = "",
		BackgroundColor3 = ORANGE,
		Position = UDim2.fromOffset(0, 110),
		Size = UDim2.new(1, 0, 0, 40),
		Visible = false,
		Parent = content,
	})
	claimButton.MouseButton1Click:Connect(function()
		invoke("ClaimLogin", nil)
	end)

	UIKit.Label({
		Text = "Günlük Görevler",
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(0, 162),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = content,
	})
	for i = 1, Daily.QuestsPerDay do
		local row = UIKit.Frame({
			Position = UDim2.fromOffset(0, 192 + (i - 1) * 56),
			Size = UDim2.new(1, 0, 0, 50),
			Parent = content,
		})
		UIKit.Corner(row, 8)
		local text = UIKit.Label({
			Text = "",
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -150, 0, 22),
			Parent = row,
		})
		local back = UIKit.Frame({
			Position = UDim2.fromOffset(10, 30),
			Size = UDim2.new(1, -150, 0, 12),
			BackgroundColor3 = C.Panel,
			Parent = row,
		})
		UIKit.Corner(back, 6)
		local fill = UIKit.Frame({
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = ORANGE,
			Parent = back,
		})
		UIKit.Corner(fill, 6)
		local button = UIKit.Button({
			Text = "",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(120, 34),
			Parent = row,
		})
		button.MouseButton1Click:Connect(function()
			invoke("ClaimQuest", i)
		end)
		questRows[i] = { Text = text, Bar = fill, Button = button }
	end
end

function DailyUI.Init()
	build()
	SideMenu.AddButton("GÜNLÜK", ORANGE, 4, function()
		if SideMenu.Toggle(panel) then
			render()
		end
	end, "DailyReady")

	Remotes.Event("DailyUpdated").OnClientEvent:Connect(function(newSnapshot)
		snapshot = newSnapshot
		render()
	end)

	task.spawn(function()
		for _ = 1, 30 do
			local ok, result = pcall(function()
				return Remotes.Function("GetDaily"):InvokeServer()
			end)
			if ok and result then
				snapshot = snapshot or result
				render()
				return
			end
			task.wait(1)
		end
	end)
end

return DailyUI

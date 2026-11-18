-- Rebirth paneli: ilerleme çubuğu, rebirth butonu (iki kez onay) ve token ağacı.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rebirth = require(ReplicatedStorage.Shared.Config.Rebirth)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)
local UIKit = require(script.Parent.UIKit)
local SideMenu = require(script.Parent.SideMenu)

local player = Players.LocalPlayer
local C = UIKit.Colors
local PURPLE = Color3.fromRGB(155, 89, 182)

local RebirthUI = {}

local snapshot = nil
local panel: Frame
local infoLabel: TextLabel
local progressFill: Frame
local progressLabel: TextLabel
local rebirthButton: TextButton
local tokensLabel: TextLabel
local nodeRows: { [string]: { Level: TextLabel, Button: TextButton } } = {}
local confirmUntil = 0
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
	local scrap = player:GetAttribute("Scrap") or 0
	local cost = snapshot.Cost
	local currentMult = 1 + snapshot.Rebirths * Economy.RebirthMultiplierPerRebirth
	local nextMult = currentMult + Economy.RebirthMultiplierPerRebirth

	infoLabel.Text = `Rebirth: {snapshot.Rebirths}   ·   Üretim çarpanı: x{currentMult} → x{nextMult}`
	progressFill.Size = UDim2.fromScale(math.clamp(scrap / cost, 0, 1), 1)
	progressLabel.Text = `{Util.FormatNumber(scrap)} / {Util.FormatNumber(cost)} Hurda`

	local ready = scrap >= cost
	rebirthButton.BackgroundColor3 = if ready then PURPLE else C.Card
	if os.clock() < confirmUntil then
		rebirthButton.Text = "Emin misin? Fabrika sıfırlanır! (tekrar bas)"
	else
		rebirthButton.Text = if ready then "REBIRTH!" else "Yeterli hurda yok"
	end

	tokensLabel.Text = `Token: {snapshot.Tokens}`
	for _, node in Rebirth.Tree do
		local row = nodeRows[node.Id]
		local level = (snapshot.TokenUpgrades and snapshot.TokenUpgrades[node.Id]) or 0
		row.Level.Text = `{level}/{node.MaxLevel}`
		if level >= node.MaxLevel then
			row.Button.Text = "MAKS"
			row.Button.BackgroundColor3 = C.Card
		else
			row.Button.Text = `{node.Cost} token`
			row.Button.BackgroundColor3 = if snapshot.Tokens >= node.Cost then PURPLE else C.Card
		end
	end
end

local function build()
	local content
	panel, content = SideMenu.CreatePanel("REBIRTH", Vector2.new(600, 470), PURPLE)

	infoLabel = UIKit.Label({
		Text = "",
		Font = Enum.Font.GothamMedium,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = content,
	})
	UIKit.Label({
		Text = "Hurda ve fabrika upgrade'leri sıfırlanır. Parçalar, robot ve kupalar kalır.",
		Font = Enum.Font.GothamMedium,
		TextColor3 = C.Muted,
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = content,
	})

	local bar = UIKit.Frame({
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = C.Card,
		Parent = content,
	})
	UIKit.Corner(bar, 8)
	progressFill = UIKit.Frame({
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = PURPLE,
		Parent = bar,
	})
	UIKit.Corner(progressFill, 8)
	progressLabel = UIKit.Label({
		Text = "",
		Size = UDim2.fromScale(1, 1),
		Parent = bar,
	})

	rebirthButton = UIKit.Button({
		Text = "REBIRTH!",
		Position = UDim2.fromOffset(0, 88),
		Size = UDim2.new(1, 0, 0, 44),
		Parent = content,
	})
	rebirthButton.MouseButton1Click:Connect(function()
		if not snapshot or (player:GetAttribute("Scrap") or 0) < snapshot.Cost then
			return
		end
		if os.clock() < confirmUntil then
			confirmUntil = 0
			invoke("Rebirth", nil)
		else
			confirmUntil = os.clock() + 3
			render()
			task.delay(3.1, render)
		end
	end)

	tokensLabel = UIKit.Label({
		Text = "Token: 0",
		TextColor3 = PURPLE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(0, 144),
		Size = UDim2.new(1, 0, 0, 26),
		Parent = content,
	})

	for i, node in Rebirth.Tree do
		local row = UIKit.Frame({
			Position = UDim2.fromOffset(0, 176 + (i - 1) * 46),
			Size = UDim2.new(1, 0, 0, 40),
			Parent = content,
		})
		UIKit.Corner(row, 8)
		UIKit.Label({
			Text = node.Name,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(10, 3),
			Size = UDim2.new(0.5, 0, 0, 18),
			Parent = row,
		})
		UIKit.Label({
			Text = node.Description,
			Font = Enum.Font.GothamMedium,
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(10, 21),
			Size = UDim2.new(0.6, 0, 0, 15),
			Parent = row,
		})
		local level = UIKit.Label({
			Text = "0",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -130, 0.5, 0),
			Size = UDim2.fromOffset(50, 22),
			Parent = row,
		})
		local button = UIKit.Button({
			Text = "",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(110, 30),
			Parent = row,
		})
		button.MouseButton1Click:Connect(function()
			invoke("BuyTokenNode", node.Id)
		end)
		nodeRows[node.Id] = { Level = level, Button = button }
	end
end

function RebirthUI.Init()
	build()
	SideMenu.AddButton("REBIRTH", PURPLE, 3, function()
		if SideMenu.Toggle(panel) then
			render()
		end
	end)

	Remotes.Event("RebirthUpdated").OnClientEvent:Connect(function(newSnapshot)
		snapshot = newSnapshot
		render()
	end)
	player:GetAttributeChangedSignal("Scrap"):Connect(function()
		if panel.Visible then
			render()
		end
	end)

	task.spawn(function()
		for _ = 1, 30 do
			local ok, result = pcall(function()
				return Remotes.Function("GetRebirth"):InvokeServer()
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

return RebirthUI

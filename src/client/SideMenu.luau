-- Sol alttaki menü butonları (Garaj, Mağaza, Rebirth, Günlük) ve panel yönetimi:
-- aynı anda tek panel açık olur. Ortak panel iskeleti de burada.

local Players = game:GetService("Players")

local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local C = UIKit.Colors

local SideMenu = {}

local screen: ScreenGui
local column: Frame
local panels: { Frame } = {}
local buttonCount = 0

local function ensureScreen()
	if screen then
		return
	end
	screen = Instance.new("ScreenGui")
	screen.Name = "Menus"
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.DisplayOrder = 2

	column = UIKit.Frame({
		Name = "Buttons",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(150, 300),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	local layout = Instance.new("UIListLayout")
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = column
	UIKit.AutoScale(column, 900)

	screen.Parent = player:WaitForChild("PlayerGui")
end

function SideMenu.GetScreen(): ScreenGui
	ensureScreen()
	return screen
end

-- Sol alta buton ekler. Badge attribute'u true olunca butonda kırmızı nokta görünür.
function SideMenu.AddButton(text: string, color: Color3, order: number, onClick: () -> (), badgeAttribute: string?): TextButton
	ensureScreen()
	buttonCount += 1
	local button = UIKit.Button({
		Name = text,
		Text = text,
		LayoutOrder = order,
		BackgroundColor3 = color,
		TextColor3 = if color == C.Accent then Color3.fromRGB(20, 20, 20) else Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(150, 50),
		Parent = column,
	})
	button.MouseButton1Click:Connect(onClick)

	if badgeAttribute then
		local badge = UIKit.Frame({
			Name = "Badge",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = C.Bad,
			Visible = false,
			Parent = button,
		})
		UIKit.Corner(badge, 8)
		local function update()
			badge.Visible = player:GetAttribute(badgeAttribute) == true
		end
		player:GetAttributeChangedSignal(badgeAttribute):Connect(update)
		update()
	end
	return button
end

-- Ortada başlıklı, kapatma butonlu boş panel. content'e içerik ekle.
function SideMenu.CreatePanel(title: string, size: Vector2, accent: Color3): (Frame, Frame)
	ensureScreen()
	local panel = UIKit.Frame({
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = C.Panel,
		Visible = false,
		Parent = screen,
	})
	UIKit.Corner(panel, 14)
	UIKit.Stroke(panel, accent, 2)
	UIKit.AutoScale(panel, size.X + 60)

	UIKit.Label({
		Text = title,
		Font = Enum.Font.GothamBlack,
		TextColor3 = accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -80, 0, 34),
		Parent = panel,
	})
	local close = UIKit.Button({
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = C.Bad,
		Parent = panel,
	})
	close.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	local content = UIKit.Frame({
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 56),
		Size = UDim2.new(1, -32, 1, -72),
		Parent = panel,
	})

	table.insert(panels, panel)
	return panel, content
end

-- Paneli aç/kapat; açılırken diğer panelleri kapatır
function SideMenu.Toggle(panel: GuiObject, open: boolean?)
	local target = if open == nil then not panel.Visible else open
	if target then
		for _, other in panels do
			if other ~= panel then
				other.Visible = false
			end
		end
	end
	panel.Visible = target
	return target
end

-- Başka modüllerin kendi panellerini de "tek panel" kuralına katması için
function SideMenu.Register(panel: Frame)
	table.insert(panels, panel)
end

return SideMenu

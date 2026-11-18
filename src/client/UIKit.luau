-- Küçük UI yardımcıları: her ekranda aynı görünüm için.

local UIKit = {}

UIKit.Colors = {
	Panel = Color3.fromRGB(20, 22, 26),
	Card = Color3.fromRGB(34, 37, 43),
	CardHover = Color3.fromRGB(46, 50, 58),
	Text = Color3.fromRGB(240, 240, 240),
	Muted = Color3.fromRGB(160, 165, 172),
	Accent = Color3.fromRGB(241, 196, 15),
	Good = Color3.fromRGB(46, 204, 113),
	Bad = Color3.fromRGB(231, 76, 60),
	Blue = Color3.fromRGB(52, 152, 219),
}

function UIKit.Corner(parent: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
	return corner
end

function UIKit.Padding(parent: Instance, px: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, px)
	padding.PaddingRight = UDim.new(0, px)
	padding.PaddingTop = UDim.new(0, px)
	padding.PaddingBottom = UDim.new(0, px)
	padding.Parent = parent
	return padding
end

function UIKit.Stroke(parent: Instance, color: Color3, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function UIKit.Frame(props): Frame
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = UIKit.Colors.Card
	for key, value in props do
		(frame :: any)[key] = value
	end
	return frame
end

function UIKit.Label(props): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextColor3 = UIKit.Colors.Text
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	for key, value in props do
		(label :: any)[key] = value
	end
	return label
end

function UIKit.Button(props): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = UIKit.Colors.Blue
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	for key, value in props do
		(button :: any)[key] = value
	end
	UIKit.Corner(button, 8)
	return button
end

-- Küçük ekranlarda (telefon) paneli küçült
function UIKit.AutoScale(gui: GuiObject, designWidth: number)
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local camera = workspace.CurrentCamera
	local function update()
		local width = camera.ViewportSize.X
		scale.Scale = math.clamp(width / designWidth, 0.55, 1)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
	return scale
end

return UIKit

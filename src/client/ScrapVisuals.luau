-- Sadece görsel: oyuncunun kendi fabrikasında toplayıcıdan kutuya giden hurda küpleri.
-- Client'ta oluşturulur, sunucuya yük bindirmez ve ekonomiyi etkilemez.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local ScrapVisuals = {}

local MAX_PER_SECOND = 6
local MIN_PER_SECOND = 0.5
local TRAVEL_TIME = 2.5

local SCRAP_COLORS = {
	Color3.fromRGB(149, 165, 166),
	Color3.fromRGB(127, 140, 141),
	Color3.fromRGB(211, 84, 0),
	Color3.fromRGB(189, 195, 199),
}

local visualsFolder: Folder

local function getMyPlot(): Model?
	local index = player:GetAttribute("PlotIndex")
	local plots = Workspace:FindFirstChild("Plots")
	if not index or not plots then
		return nil
	end
	return plots:FindFirstChild("Plot" .. index) :: Model?
end

local function spawnScrap(plot: Model)
	local collector = plot:FindFirstChild("Collector") :: BasePart?
	local box = plot:FindFirstChild("Box") :: BasePart?
	local conveyor = plot:FindFirstChild("Conveyor") :: BasePart?
	if not (collector and box and conveyor) then
		return
	end

	local beltY = conveyor.Position.Y + conveyor.Size.Y / 2 + 0.5
	local startPos = Vector3.new(collector.Position.X, beltY, collector.Position.Z)
	local endPos = Vector3.new(box.Position.X, beltY, box.Position.Z)
	-- Toplayıcıdan biraz önde başla, kutudan biraz önce bit
	local direction = (endPos - startPos).Unit
	startPos += direction * (collector.Size.Z / 2)
	endPos -= direction * (box.Size.Z / 2)

	local size = 0.6 + math.random() * 0.6
	local scrap = Instance.new("Part")
	scrap.Name = "Scrap"
	scrap.Anchored = true
	scrap.CanCollide = false
	scrap.CanQuery = false
	scrap.CanTouch = false
	scrap.CastShadow = false
	scrap.Size = Vector3.new(size, size, size)
	scrap.Color = SCRAP_COLORS[math.random(#SCRAP_COLORS)]
	scrap.Material = Enum.Material.Metal
	scrap.CFrame = CFrame.new(startPos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
	scrap.Parent = visualsFolder

	local tween = TweenService:Create(scrap, TweenInfo.new(TRAVEL_TIME, Enum.EasingStyle.Linear), {
		Position = endPos,
	})
	tween:Play()
	tween.Completed:Connect(function()
		scrap:Destroy()
	end)
end

function ScrapVisuals.Init()
	visualsFolder = Instance.new("Folder")
	visualsFolder.Name = "ScrapVisuals"
	visualsFolder.Parent = Workspace

	task.spawn(function()
		while true do
			local rate = player:GetAttribute("Rate") or 0
			local stored = player:GetAttribute("Stored") or 0
			local capacity = player:GetAttribute("Capacity") or 0
			local plot = getMyPlot()

			-- Kutu doluysa bant durur
			local boxFull = capacity > 0 and stored >= capacity
			if plot and rate > 0 and not boxFull then
				spawnScrap(plot)
			end

			local perSecond = math.clamp(rate / 5, MIN_PER_SECOND, MAX_PER_SECOND)
			task.wait(1 / perSecond)
		end
	end)
end

return ScrapVisuals

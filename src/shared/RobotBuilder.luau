-- Takılı parçalardan robot modeli oluşturur (Roblox primitive'leriyle, model dosyası gerekmez).
-- Sonra AI/elle yapılmış meshler gelince her parçanın görseli ReplicatedStorage'daki modelle değiştirilebilir.
--
-- Koordinatlar: Root yerde, robotun ortasında. Yukarı +Y, ön -Z (Roblox LookVector).
-- anchored=false verilirse parçalar Root'a weld edilir (arenada fizik için).

local Rarities = require(script.Parent.Config.Rarities)

local RobotBuilder = {}

local BODY_SIZES = {
	TinCan = Vector3.new(4, 2.6, 5),
	SteelChassis = Vector3.new(5, 2.8, 6),
	TitanCore = Vector3.new(6, 3.2, 7),
}

local BODY_COLORS = {
	TinCan = Color3.fromRGB(160, 165, 170),
	SteelChassis = Color3.fromRGB(95, 105, 120),
	TitanCore = Color3.fromRGB(55, 60, 75),
}

-- Gövdenin yerden yüksekliği hareket parçasına göre değişir
local RIDE_HEIGHT = {
	Wheels = 1.4,
	Treads = 1.2,
	SpiderLegs = 2.6,
}

local function tint(base: Color3, rarityId: string): Color3
	local rarity = Rarities.ById[rarityId]
	if not rarity or rarity.Index == 1 then
		return base
	end
	return base:Lerp(rarity.Color, 0.45)
end

type Context = {
	Model: Model,
	Root: BasePart,
	Anchored: boolean,
}

local function addPart(ctx: Context, name: string, size: Vector3, offset: CFrame, color: Color3, props: { [string]: any }?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Metal
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = ctx.Root.CFrame * offset
	part.Anchored = ctx.Anchored
	if props then
		for key, value in props do
			(part :: any)[key] = value
		end
	end
	if not ctx.Anchored then
		part.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = ctx.Root
		weld.Part1 = part
		weld.Parent = part
	end
	part.Parent = ctx.Model
	return part
end

-- Legendary ve Mythic parçalara parlayan bir şerit ekle
local function addGlow(ctx: Context, name: string, size: Vector3, offset: CFrame, rarityId: string)
	local rarity = Rarities.ById[rarityId]
	if rarity and rarity.Index >= Rarities.HighTierIndex then
		addPart(ctx, name .. "Glow", size, offset, rarity.Color, { Material = Enum.Material.Neon, CanCollide = false })
	end
end

---------------------------------------------------------------- parça görselleri

local function buildMovement(ctx: Context, item, body: Vector3)
	local w, l = body.X, body.Z
	local color = tint(Color3.fromRGB(30, 30, 33), item.Rarity)

	if item.PartId == "Wheels" then
		for _, x in { -1, 1 } do
			for _, z in { -1, 1 } do
				-- Silindirin ekseni X: tekerlek yana bakar
				addPart(ctx, "Wheel", Vector3.new(0.8, 2.4, 2.4), CFrame.new(x * (w / 2 + 0.4), 1.2, z * (l / 2 - 1)), color, {
					Shape = Enum.PartType.Cylinder,
					Material = Enum.Material.SmoothPlastic,
				})
			end
		end
	elseif item.PartId == "Treads" then
		for _, x in { -1, 1 } do
			addPart(ctx, "Tread", Vector3.new(1.2, 2, l + 0.6), CFrame.new(x * (w / 2 + 0.6), 1, 0), color, {
				Material = Enum.Material.Fabric,
			})
		end
	elseif item.PartId == "SpiderLegs" then
		for _, x in { -1, 1 } do
			for _, z in { -1, 1 } do
				addPart(
					ctx,
					"Leg",
					Vector3.new(0.5, 3.4, 0.5),
					CFrame.new(x * (w / 2 + 0.7), 1.5, z * (l / 2 - 0.8)) * CFrame.Angles(0, 0, -x * 0.4),
					color
				)
			end
		end
	end
	addGlow(ctx, "Movement", Vector3.new(w + 0.2, 0.2, 0.2), CFrame.new(0, RIDE_HEIGHT[item.PartId] - 0.1, -l / 2), item.Rarity)
end

local function buildBody(ctx: Context, item, body: Vector3, h: number)
	addPart(ctx, "Body", body, CFrame.new(0, h + body.Y / 2, 0), tint(BODY_COLORS[item.PartId], item.Rarity))
	-- "Göz": önde küçük bir sensör
	addPart(ctx, "Eye", Vector3.new(body.X * 0.5, 0.4, 0.2), CFrame.new(0, h + body.Y * 0.75, -body.Z / 2 - 0.1), Color3.fromRGB(0, 255, 200), {
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	addGlow(ctx, "Body", Vector3.new(body.X + 0.1, 0.25, body.Z + 0.1), CFrame.new(0, h + body.Y * 0.35, 0), item.Rarity)
end

local function buildWeapon(ctx: Context, item, body: Vector3, h: number)
	local l = body.Z
	local midY = h + body.Y / 2
	local color = tint(Color3.fromRGB(200, 200, 205), item.Rarity)

	if item.PartId == "Saw" then
		addPart(ctx, "SawArm", Vector3.new(0.5, 0.5, 1.4), CFrame.new(0, midY, -l / 2 - 0.6), Color3.fromRGB(60, 60, 65))
		addPart(ctx, "SawBlade", Vector3.new(0.3, 3.2, 3.2), CFrame.new(0, midY, -l / 2 - 1.6), color, {
			Shape = Enum.PartType.Cylinder,
		})
	elseif item.PartId == "HammerArm" then
		local topY = h + body.Y + 0.4
		addPart(ctx, "HammerArm", Vector3.new(0.6, 0.6, 3), CFrame.new(0, topY, -l / 2 + 0.6), Color3.fromRGB(60, 60, 65))
		addPart(ctx, "HammerHead", Vector3.new(1.6, 1.4, 1.4), CFrame.new(0, topY, -l / 2 - 1.4), color)
	elseif item.PartId == "Flamethrower" then
		-- Silindiri Y ekseninde 90° döndürünce ekseni Z olur: öne bakan namlu
		addPart(ctx, "Nozzle", Vector3.new(2.4, 0.8, 0.8), CFrame.new(0, midY, -l / 2 - 1.2) * CFrame.Angles(0, math.pi / 2, 0), color, {
			Shape = Enum.PartType.Cylinder,
		})
		addPart(ctx, "FuelTank", Vector3.new(2, 1.2, 1.2), CFrame.new(0, h + body.Y + 0.6, 0.5) * CFrame.Angles(0, math.pi / 2, 0), tint(Color3.fromRGB(192, 57, 43), item.Rarity), {
			Shape = Enum.PartType.Cylinder,
		})
	end
	addGlow(ctx, "Weapon", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, midY + 0.6, -l / 2 - 0.3), item.Rarity)
end

local function buildArmor(ctx: Context, item, body: Vector3, h: number)
	local w, bh, l = body.X, body.Y, body.Z
	local midY = h + bh / 2

	if item.PartId == "ScrapPlate" then
		local color = tint(Color3.fromRGB(139, 90, 60), item.Rarity)
		for _, x in { -1, 1 } do
			addPart(ctx, "Plate", Vector3.new(0.3, bh * 0.8, l * 0.8), CFrame.new(x * (w / 2 + 0.15), midY, 0), color, {
				Material = Enum.Material.CorrodedMetal,
			})
		end
	elseif item.PartId == "CompositeShield" then
		local color = tint(Color3.fromRGB(127, 140, 160), item.Rarity)
		addPart(ctx, "TopShield", Vector3.new(w + 0.4, 0.4, l + 0.4), CFrame.new(0, h + bh + 0.2, 0), color)
		for _, x in { -1, 1 } do
			addPart(ctx, "SideShield", Vector3.new(0.3, bh, l * 0.9), CFrame.new(x * (w / 2 + 0.15), midY, 0), color)
		end
	elseif item.PartId == "ReactiveArmor" then
		local color = tint(Color3.fromRGB(80, 90, 70), item.Rarity)
		for _, x in { -1, 1 } do
			addPart(ctx, "HeavyPlate", Vector3.new(0.5, bh, l), CFrame.new(x * (w / 2 + 0.25), midY, 0), color)
			for _, z in { -1, 0, 1 } do
				addPart(ctx, "ReactiveBlock", Vector3.new(0.6, 0.8, 0.8), CFrame.new(x * (w / 2 + 0.8), midY, z * l / 3), color:Lerp(Color3.new(0, 0, 0), 0.2))
			end
		end
	end
	addGlow(ctx, "Armor", Vector3.new(w + 0.8, 0.15, 0.15), CFrame.new(0, h + bh - 0.1, -l / 2 - 0.1), item.Rarity)
end

-- Arena çarpışmaları için gövdenin yaklaşık yarıçapı
function RobotBuilder.BodyRadius(bodyPartId: string?): number
	local size = BODY_SIZES[bodyPartId or "TinCan"] or BODY_SIZES.TinCan
	return math.max(size.X, size.Z) / 2
end

---------------------------------------------------------------- ana fonksiyon

-- equipped: { Body, Weapon, Movement, Armor } -> { PartId, Rarity }
-- cframe: robotun yerdeki merkezi ve yönü
function RobotBuilder.Build(equipped, cframe: CFrame, anchored: boolean): Model
	local model = Instance.new("Model")
	model.Name = "Robot"

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.Anchored = anchored
	root.CFrame = cframe
	root.Parent = model
	model.PrimaryPart = root

	local ctx: Context = { Model = model, Root = root, Anchored = anchored }

	local bodyItem = equipped.Body or { PartId = "TinCan", Rarity = "Common" }
	local body = BODY_SIZES[bodyItem.PartId] or BODY_SIZES.TinCan
	local movement = equipped.Movement
	local h = if movement then RIDE_HEIGHT[movement.PartId] or 1.4 else 1.4

	buildBody(ctx, bodyItem, body, h)
	if movement then
		buildMovement(ctx, movement, body)
	end
	if equipped.Weapon then
		buildWeapon(ctx, equipped.Weapon, body, h)
	end
	if equipped.Armor then
		buildArmor(ctx, equipped.Armor, body, h)
	end

	return model
end

return RobotBuilder

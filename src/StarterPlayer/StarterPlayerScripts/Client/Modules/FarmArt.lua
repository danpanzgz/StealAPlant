--!strict

local FarmArt = {}

local function pixel(parent: Instance, name: string, size: UDim2, position: UDim2, color: Color3, zIndex: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.ZIndex = zIndex
	frame.Parent = parent
	return frame
end

local function createArtFrame(parent: Instance, name: string, width: number, height: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromOffset(width, height)
	frame.BackgroundTransparency = 1
	frame.ZIndex = if parent:IsA("GuiObject") then parent.ZIndex + 1 else 1
	frame.Parent = parent
	return frame
end

function FarmArt.CreateEggIcon(parent: Instance, rarityColor: Color3, name: string?): Frame
	local art = createArtFrame(parent, name or "EggArt", 52, 56)
	local z = art.ZIndex
	local rows = {
		{ width = 16, y = 2 },
		{ width = 28, y = 8 },
		{ width = 38, y = 15 },
		{ width = 42, y = 22 },
		{ width = 38, y = 29 },
		{ width = 30, y = 36 },
		{ width = 20, y = 43 },
		{ width = 12, y = 49 },
	}

	for _, row in ipairs(rows) do
		local x = math.floor((52 - row.width) / 2)
		pixel(art, "EggOutline", UDim2.fromOffset(row.width, 7), UDim2.fromOffset(x, row.y), Color3.fromRGB(102, 71, 46), z)
		local shellColor = if row.y < 15 then Color3.fromRGB(255, 246, 216) else Color3.fromRGB(249, 220, 159)
		pixel(art, "EggShell", UDim2.fromOffset(row.width - 4, 5), UDim2.fromOffset(x + 2, row.y + 1), shellColor, z + 1)
	end

	pixel(art, "RarityBand", UDim2.fromOffset(35, 7), UDim2.fromOffset(9, 23), rarityColor, z + 2)
	pixel(art, "ShellShine", UDim2.fromOffset(5, 6), UDim2.fromOffset(15, 11), Color3.fromRGB(255, 255, 238), z + 3)
	pixel(art, "EggSpeckleA", UDim2.fromOffset(3, 3), UDim2.fromOffset(33, 17), rarityColor:Lerp(Color3.new(1, 1, 1), 0.35), z + 3)
	pixel(art, "EggSpeckleB", UDim2.fromOffset(3, 3), UDim2.fromOffset(17, 36), rarityColor:Lerp(Color3.new(1, 1, 1), 0.35), z + 3)
	return art
end

function FarmArt.CreateSeedPackIcon(parent: Instance, rarityColor: Color3, name: string?): Frame
	local art = createArtFrame(parent, name or "SeedPackArt", 52, 56)
	local z = art.ZIndex
	pixel(art, "BagShadow", UDim2.fromOffset(40, 35), UDim2.fromOffset(6, 14), Color3.fromRGB(102, 67, 43), z)
	pixel(art, "BagBody", UDim2.fromOffset(34, 31), UDim2.fromOffset(9, 15), Color3.fromRGB(190, 133, 70), z + 1)
	pixel(art, "BagFold", UDim2.fromOffset(28, 8), UDim2.fromOffset(12, 9), Color3.fromRGB(222, 174, 99), z + 2)
	pixel(art, "BagTie", UDim2.fromOffset(12, 5), UDim2.fromOffset(20, 12), Color3.fromRGB(109, 74, 44), z + 3)
	pixel(art, "RarityPatch", UDim2.fromOffset(15, 13), UDim2.fromOffset(18, 27), rarityColor, z + 3)
	pixel(art, "SeedA", UDim2.fromOffset(4, 5), UDim2.fromOffset(20, 29), Color3.fromRGB(255, 242, 190), z + 4)
	pixel(art, "SeedB", UDim2.fromOffset(4, 5), UDim2.fromOffset(27, 33), Color3.fromRGB(255, 242, 190), z + 4)
	pixel(art, "BagBase", UDim2.fromOffset(30, 4), UDim2.fromOffset(11, 48), Color3.fromRGB(124, 81, 46), z + 2)
	return art
end

function FarmArt.CreateGearIcon(parent: Instance, gearId: string, rarityColor: Color3, name: string?): Frame
	local art = createArtFrame(parent, name or "GearArt", 52, 56)
	local z = art.ZIndex
	if gearId == "WaterCan" or gearId == "Sprinkler" then
		pixel(art, "CanBody", UDim2.fromOffset(27, 21), UDim2.fromOffset(10, 23), Color3.fromRGB(105, 163, 178), z + 1)
		pixel(art, "CanTop", UDim2.fromOffset(23, 5), UDim2.fromOffset(12, 19), Color3.fromRGB(72, 126, 144), z + 2)
		pixel(art, "CanHandleOuter", UDim2.fromOffset(8, 16), UDim2.fromOffset(30, 14), Color3.fromRGB(83, 115, 91), z)
		pixel(art, "CanHandleInner", UDim2.fromOffset(4, 9), UDim2.fromOffset(32, 18), Color3.fromRGB(246, 233, 196), z + 1)
		pixel(art, "CanSpout", UDim2.fromOffset(12, 5), UDim2.fromOffset(34, 25), Color3.fromRGB(72, 126, 144), z + 2)
		pixel(art, "CanRose", UDim2.fromOffset(7, 7), UDim2.fromOffset(43, 24), rarityColor, z + 3)
	else
		pixel(art, "TotemBase", UDim2.fromOffset(30, 9), UDim2.fromOffset(11, 43), Color3.fromRGB(105, 69, 43), z)
		pixel(art, "TotemBody", UDim2.fromOffset(22, 31), UDim2.fromOffset(15, 11), Color3.fromRGB(151, 100, 54), z + 1)
		pixel(art, "TotemTop", UDim2.fromOffset(30, 8), UDim2.fromOffset(11, 7), Color3.fromRGB(190, 133, 70), z + 2)
		pixel(art, "TotemRune", UDim2.fromOffset(8, 12), UDim2.fromOffset(22, 20), rarityColor, z + 3)
		pixel(art, "TotemGlow", UDim2.fromOffset(4, 4), UDim2.fromOffset(24, 24), Color3.fromRGB(255, 245, 196), z + 4)
	end
	return art
end

function FarmArt.CreatePetIcon(parent: Instance, petData: any, name: string?): Frame
	local art = createArtFrame(parent, name or "PetArt", 52, 56)
	local z = art.ZIndex
	local bodyColor = petData.color
	local accent = petData.accentColor
	local feature = petData.feature

	if feature == "ears" or feature == "longEars" or feature == "roundEars" then
		local earHeight = if feature == "longEars" then 17 else 11
		pixel(art, "LeftEar", UDim2.fromOffset(10, earHeight), UDim2.fromOffset(9, 4), accent, z)
		pixel(art, "RightEar", UDim2.fromOffset(10, earHeight), UDim2.fromOffset(33, 4), accent, z)
	elseif feature == "wings" or feature == "fins" then
		pixel(art, "LeftWing", UDim2.fromOffset(9, 19), UDim2.fromOffset(3, 21), accent, z)
		pixel(art, "RightWing", UDim2.fromOffset(9, 19), UDim2.fromOffset(40, 21), accent, z)
	elseif feature == "antlers" or feature == "horn" or feature == "crown" then
		pixel(art, "CrownLeft", UDim2.fromOffset(7, 12), UDim2.fromOffset(15, 4), accent, z)
		pixel(art, "CrownMiddle", UDim2.fromOffset(7, 16), UDim2.fromOffset(23, 0), accent, z)
		pixel(art, "CrownRight", UDim2.fromOffset(7, 12), UDim2.fromOffset(31, 4), accent, z)
	end

	pixel(art, "PetBody", UDim2.fromOffset(34, 30), UDim2.fromOffset(9, 17), bodyColor, z + 1)
	pixel(art, "LeftEyeWhite", UDim2.fromOffset(7, 9), UDim2.fromOffset(16, 25), Color3.fromRGB(255, 249, 225), z + 2)
	pixel(art, "RightEyeWhite", UDim2.fromOffset(7, 9), UDim2.fromOffset(29, 25), Color3.fromRGB(255, 249, 225), z + 2)
	pixel(art, "LeftPupil", UDim2.fromOffset(3, 6), UDim2.fromOffset(19, 27), Color3.fromRGB(47, 49, 39), z + 3)
	pixel(art, "RightPupil", UDim2.fromOffset(3, 6), UDim2.fromOffset(32, 27), Color3.fromRGB(47, 49, 39), z + 3)
	pixel(art, "PetNose", UDim2.fromOffset(6, 5), UDim2.fromOffset(23, 37), accent, z + 3)
	pixel(art, "PetCollar", UDim2.fromOffset(24, 4), UDim2.fromOffset(14, 44), Color3.fromRGB(135, 81, 52), z + 3)
	pixel(art, "PetTag", UDim2.fromOffset(6, 6), UDim2.fromOffset(23, 48), accent, z + 4)
	pixel(art, "LeftFoot", UDim2.fromOffset(11, 5), UDim2.fromOffset(12, 49), accent, z + 2)
	pixel(art, "RightFoot", UDim2.fromOffset(11, 5), UDim2.fromOffset(29, 49), accent, z + 2)

	if feature == "beak" then
		pixel(art, "Beak", UDim2.fromOffset(12, 6), UDim2.fromOffset(20, 38), accent, z + 4)
	elseif feature == "gills" then
		for index = 1, 3 do
			pixel(art, "GillLeft", UDim2.fromOffset(5, 3), UDim2.fromOffset(4, 28 + index * 4), accent, z + 2)
			pixel(art, "GillRight", UDim2.fromOffset(5, 3), UDim2.fromOffset(43, 28 + index * 4), accent, z + 2)
		end
	end

	return art
end

function FarmArt.CreateCropIcon(parent: Instance, plantId: string, cropColor: Color3, name: string?): Frame
	local art = createArtFrame(parent, name or "CropArt", 52, 56)
	local z = art.ZIndex
	local greens = Color3.fromRGB(79, 144, 67)
	pixel(art, "PotOutline", UDim2.fromOffset(42, 10), UDim2.fromOffset(5, 43), Color3.fromRGB(107, 69, 43), z)
	pixel(art, "PotRim", UDim2.fromOffset(42, 4), UDim2.fromOffset(5, 42), Color3.fromRGB(161, 111, 63), z + 1)
	pixel(art, "PlantStem", UDim2.fromOffset(5, 21), UDim2.fromOffset(24, 22), greens, z + 1)
	pixel(art, "PlantLeafLeft", UDim2.fromOffset(14, 6), UDim2.fromOffset(11, 25), Color3.fromRGB(116, 179, 78), z + 2)
	pixel(art, "PlantLeafRight", UDim2.fromOffset(14, 6), UDim2.fromOffset(27, 21), greens, z + 2)

	if plantId == "Carrot" then
		pixel(art, "CropTop", UDim2.fromOffset(12, 8), UDim2.fromOffset(20, 26), cropColor, z + 2)
		pixel(art, "CropMiddle", UDim2.fromOffset(8, 8), UDim2.fromOffset(22, 33), cropColor, z + 2)
		pixel(art, "CropTip", UDim2.fromOffset(4, 6), UDim2.fromOffset(24, 39), cropColor, z + 2)
	elseif plantId == "Sunflower" or string.find(plantId, "Flower") or string.find(plantId, "Orchid") or plantId == "EmberRose" then
		pixel(art, "FlowerLeft", UDim2.fromOffset(10, 8), UDim2.fromOffset(13, 14), cropColor, z + 2)
		pixel(art, "FlowerRight", UDim2.fromOffset(10, 8), UDim2.fromOffset(29, 14), cropColor, z + 2)
		pixel(art, "FlowerTop", UDim2.fromOffset(8, 9), UDim2.fromOffset(20, 9), cropColor, z + 2)
		pixel(art, "FlowerCore", UDim2.fromOffset(8, 8), UDim2.fromOffset(22, 17), Color3.fromRGB(119, 80, 46), z + 3)
	elseif plantId == "Pumpkin" or plantId == "Watermelon" then
		pixel(art, "CropFruit", UDim2.fromOffset(24, 20), UDim2.fromOffset(14, 24), cropColor, z + 2)
		pixel(art, "FruitHighlight", UDim2.fromOffset(4, 14), UDim2.fromOffset(19, 27), cropColor:Lerp(Color3.new(1, 1, 1), 0.25), z + 3)
	elseif plantId == "Corn" or plantId == "Pineapple" then
		pixel(art, "CropFruit", UDim2.fromOffset(14, 20), UDim2.fromOffset(19, 19), cropColor, z + 2)
		pixel(art, "FruitBand", UDim2.fromOffset(18, 4), UDim2.fromOffset(17, 28), Color3.fromRGB(244, 191, 76), z + 3)
	else
		pixel(art, "CropFruitLeft", UDim2.fromOffset(11, 11), UDim2.fromOffset(15, 27), cropColor, z + 2)
		pixel(art, "CropFruitRight", UDim2.fromOffset(11, 11), UDim2.fromOffset(27, 31), cropColor, z + 2)
		pixel(art, "FruitShine", UDim2.fromOffset(4, 4), UDim2.fromOffset(18, 29), cropColor:Lerp(Color3.new(1, 1, 1), 0.5), z + 3)
	end

	return art
end

return FarmArt

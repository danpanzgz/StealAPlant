--!strict
--[[
	PlantController.lua
	Gestiona la interacción de "plantar" en un plot vacío. La cosecha NO
	pasa por aquí: se resuelve enteramente en el servidor al disparar el
	ProximityPrompt (ver PlantService.lua), porque no necesita ningún dato
	adicional del cliente. Plantar sí necesita que el jugador elija qué
	semilla usar, así que aquí mostramos un selector rápido y llamamos al
	RemoteFunction PlantSeed con la elección.

	Se apoya en ProximityPromptService, la API nativa de Roblox para
	interacciones por proximidad: funciona igual en PC (tecla E), consola
	(botón) y móvil (botón táctil automático en pantalla), cumpliendo el
	requisito de controles intuitivos y mobile-first sin reinventar un
	sistema de input propio.
]]

local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local PlantConfig = require(ReplicatedStorage.Shared.Config.PlantConfig)

local Client = script.Parent.Parent
local ClientState = require(Client.ClientState)
local UI = require(Client.UI)

local player = Players.LocalPlayer

local PlantController = {}

local plantSeedFn = Net.GetRemoteFunction("PlantSeed")

local pickerFrame: Frame
local pickerList: ScrollingFrame
local hud: any

local function restoreSlapTool()
	if player:GetAttribute("CarryingStolenPlant") == true then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = backpack and backpack:FindFirstChild("Farm Slap Stick")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if tool and tool:IsA("Tool") and humanoid then
		humanoid:EquipTool(tool)
	end
end

local function clearSeedTools(shouldRestoreSlap: boolean)
	local function clear(container: Instance?)
		if not container then
			return
		end
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("SeedTool") == true then
				child:Destroy()
			end
		end
	end
	clear(player:FindFirstChildOfClass("Backpack"))
	clear(player.Character)
	if shouldRestoreSlap then
		task.defer(restoreSlapTool)
	end
end

function PlantController.ClearSeedTools(shouldRestoreSlap: boolean?)
	clearSeedTools(shouldRestoreSlap ~= false)
end

function PlantController.RestoreSlapTool()
	restoreSlapTool()
end

function PlantController.EquipSeed(plantId: string): boolean
	if player:GetAttribute("CarryingStolenPlant") == true then
		if hud then
			hud.Push("No puedes llevar más objetos hasta volver a tu jardín.", "warn")
		end
		return false
	end
	local plantData = PlantConfig[plantId]
	if not plantData or (ClientState.Inventory.seeds[plantId] or 0) <= 0 then
		return false
	end
	clearSeedTools(false)

	local tool = Instance.new("Tool")
	tool.Name = plantData.displayName .. " Seeds"
	tool.ToolTip = "Toca una parcela de tu jardín para plantar"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("SeedTool", true)
	tool:SetAttribute("PlantId", plantId)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Ball
	handle.Size = Vector3.new(0.7, 0.7, 0.7)
	handle.Color = plantData.color
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	tool.Activated:Connect(function()
		local mouse = player:GetMouse()
		local target = mouse.Target
		if not target then
			return
		end
		local result = plantSeedFn:InvokeServer(mouse.Hit.Position, plantId)
		if result and result.success then
			if hud then
				hud.Push("Plantaste " .. plantData.displayName .. " Seeds en tu jardín", "good")
			end
			-- La semilla sigue en la mano mientras queden: planta varias seguidas.
			task.delay(0.25, function()
				if (ClientState.Inventory.seeds[plantId] or 0) <= 0 then
					clearSeedTools(true)
				end
			end)
		elseif hud then
			hud.Fail(result and result.reason)
		end
	end)
	tool.Parent = player:WaitForChild("Backpack")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:EquipTool(tool)
	end
	return true
end

local function closePicker()
	if pickerFrame then
		pickerFrame.Visible = false
	end
end

local function openSeedPicker(plotIndex: number, hudController: any)
	for _, child in ipairs(pickerList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local hasAnySeed = false

	for plantId, count in pairs(ClientState.Inventory.seeds or {}) do
		if count > 0 then
			local plantData = PlantConfig[plantId]
			if plantData then
				hasAnySeed = true
				local row = Instance.new("TextButton")
				row.Size = UDim2.new(1, -16, 0, 52)
				row.BackgroundColor3 = UI.Colors.Card
				row.BorderSizePixel = 3
				row.BorderColor3 = Color3.fromRGB(112, 78, 43)
				row.Text = plantData.displayName .. "  x" .. count
				row.TextColor3 = UI.Colors.Text
				row.Font = Enum.Font.Arcade
				row.TextScaled = true
				row.Selectable = true
				row.Parent = pickerList

				row.Activated:Connect(function()
					if not PlantController.EquipSeed(plantId) then
						hudController.ShowNotification("No tienes esas semillas", Color3.fromRGB(255, 110, 110))
						return
					end
					local result = plantSeedFn:InvokeServer(plotIndex, plantId)
					if result and result.success then
						hudController.ShowNotification("Plantaste " .. plantData.displayName .. " Seeds", Color3.fromRGB(120, 255, 140))
						closePicker()
					else
						local reason = (result and result.reason) or "error"
						hudController.Fail(reason)
					end
				end)
			end
		end
	end

	if not hasAnySeed then
		hudController.ShowNotification("No tienes semillas. Visita la tienda 🌱", Color3.fromRGB(255, 200, 90))
		return
	end

	pickerFrame.Visible = true
end

local function buildPicker(hudController: any)
	local screenGui = hudController.GetScreenGui()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local widthScale = if viewport.X <= 640 then 0.96 else 0.72
	local heightScale = if viewport.X <= 640 then 0.46 else 0.38

	pickerFrame = Instance.new("Frame")
	pickerFrame.Name = "SeedPicker"
	pickerFrame.Visible = false
	pickerFrame.AnchorPoint = Vector2.new(0.5, 1)
	pickerFrame.Position = UDim2.new(0.5, 0, 1, -18)
	pickerFrame.Size = UDim2.new(widthScale, 0, heightScale, 0)
	pickerFrame.BackgroundColor3 = UI.Colors.Panel
	pickerFrame.BorderSizePixel = 4
	pickerFrame.BorderColor3 = UI.Colors.Gold
	pickerFrame.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -56, 0, 36)
	title.Position = UDim2.new(0, 16, 0, 8)
	title.Text = "Elige una semilla"
	title.TextColor3 = Color3.fromRGB(255, 244, 211)
	title.Font = Enum.Font.Arcade
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = pickerFrame

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0, 36, 0, 36)
	closeButton.Position = UDim2.new(1, -44, 0, 8)
	closeButton.BackgroundColor3 = UI.Colors.Grey
	closeButton.BorderSizePixel = 3
	closeButton.BorderColor3 = Color3.fromRGB(74, 48, 30)
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.fromRGB(255, 244, 211)
	closeButton.Font = Enum.Font.Arcade
	closeButton.TextScaled = true
	closeButton.Selectable = true
	closeButton.Parent = pickerFrame
	closeButton.Activated:Connect(closePicker)

	pickerList = Instance.new("ScrollingFrame")
	pickerList.BackgroundTransparency = 1
	pickerList.Position = UDim2.new(0, 10, 0, 48)
	pickerList.Size = UDim2.new(1, -20, 1, -56)
	pickerList.CanvasSize = UDim2.new(0, 0, 0, 0)
	pickerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	pickerList.ScrollBarThickness = 6
	pickerList.Parent = pickerFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = pickerList
end

function PlantController.Init(hudController: any)
	hud = hudController
	buildPicker(hudController)
	player:GetAttributeChangedSignal("CarryingStolenPlant"):Connect(function()
		if player:GetAttribute("CarryingStolenPlant") == true then
			clearSeedTools(false)
			hud.Push("Lleva la flor a tu jardín; no puedes usar objetos mientras tanto.", "warn")
		end
	end)
	Net.GetRemoteEvent("InventoryUpdated").OnClientEvent:Connect(function(inventory: any)
		ClientState.SetInventoryFromSnapshot(inventory)
		local containers = {}
		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack then
			table.insert(containers, backpack)
		end
		if player.Character then
			table.insert(containers, player.Character)
		end
		for _, container in ipairs(containers) do
			if container then
				for _, tool in ipairs(container:GetChildren()) do
					if tool:IsA("Tool") and tool:GetAttribute("SeedTool") == true then
						local plantId = tool:GetAttribute("PlantId")
						if type(plantId) == "string" and (ClientState.Inventory.seeds[plantId] or 0) <= 0 then
							tool:Destroy()
						end
					end
				end
			end
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, triggeringPlayer: Player)
		if triggeringPlayer ~= player then
			return
		end
		if prompt.Name ~= "Interact" then
			return
		end
		local plotPart = prompt.Parent
		if not plotPart or not plotPart:IsA("BasePart") then
			return
		end
		local ownerUserId = plotPart:GetAttribute("OwnerUserId")
		if ownerUserId ~= player.UserId then
			return -- interacción con jardín ajeno = robo, lo maneja StealController (próxima iteración)
		end
		if prompt.ActionText ~= "Plant" then
			return -- "Harvest" ya se resuelve enteramente en servidor
		end

		local plotIndex = plotPart:GetAttribute("PlotIndex")
		if type(plotIndex) == "number" then
			openSeedPicker(plotIndex, hudController)
		end
	end)
end

return PlantController

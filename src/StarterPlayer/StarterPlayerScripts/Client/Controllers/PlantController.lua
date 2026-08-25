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

local player = Players.LocalPlayer

local PlantController = {}

local plantSeedFn = Net.GetRemoteFunction("PlantSeed")

local pickerFrame: Frame
local pickerList: ScrollingFrame

local function closePicker()
	if pickerFrame then
		pickerFrame.Visible = false
	end
end

local function openSeedPicker(plotIndex: number, hudController: any)
	for _, child in ipairs(pickerList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local hasAnySeed = false

	for plantId, count in pairs(ClientState.Inventory) do
		if count > 0 then
			hasAnySeed = true
			local plantData = PlantConfig[plantId]
			if plantData then
				local row = Instance.new("TextButton")
				row.Size = UDim2.new(1, -16, 0, 52)
				row.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
				row.Text = plantData.displayName .. "  x" .. count
				row.TextColor3 = Color3.fromRGB(255, 255, 255)
				row.Font = Enum.Font.GothamBold
				row.TextScaled = true
				row.Parent = pickerList

				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 8)
				corner.Parent = row

				row.Activated:Connect(function()
					row.Active = false
					local result = plantSeedFn:InvokeServer(plotIndex, plantId)
					row.Active = true
					if result and result.success then
						ClientState.AdjustInventory(plantId, -1)
						hudController.ShowNotification("Planted " .. plantData.displayName, Color3.fromRGB(120, 255, 140))
						closePicker()
					else
						local reason = (result and result.reason) or "error"
						hudController.ShowNotification("Can't plant: " .. reason, Color3.fromRGB(255, 110, 110))
					end
				end)
			end
		end
	end

	if not hasAnySeed then
		hudController.ShowNotification("No seeds! Visit the Seed Shop 🌱", Color3.fromRGB(255, 200, 90))
		return
	end

	pickerFrame.Visible = true
end

local function buildPicker(hudController: any)
	local screenGui = hudController.GetScreenGui()

	pickerFrame = Instance.new("Frame")
	pickerFrame.Name = "SeedPicker"
	pickerFrame.Visible = false
	pickerFrame.AnchorPoint = Vector2.new(0.5, 1)
	pickerFrame.Position = UDim2.new(0.5, 0, 1, -20)
	pickerFrame.Size = UDim2.new(0.85, 0, 0.4, 0)
	pickerFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	pickerFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = pickerFrame

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -50, 0, 36)
	title.Position = UDim2.new(0, 16, 0, 6)
	title.Text = "Choose a seed"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = pickerFrame

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0, 36, 0, 36)
	closeButton.Position = UDim2.new(1, -44, 0, 6)
	closeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 66)
	closeButton.Text = "✕"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextScaled = true
	closeButton.Parent = pickerFrame
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeButton
	closeButton.Activated:Connect(closePicker)

	pickerList = Instance.new("ScrollingFrame")
	pickerList.BackgroundTransparency = 1
	pickerList.Position = UDim2.new(0, 8, 0, 48)
	pickerList.Size = UDim2.new(1, -16, 1, -56)
	pickerList.CanvasSize = UDim2.new(0, 0, 0, 0)
	pickerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	pickerList.ScrollBarThickness = 6
	pickerList.Parent = pickerFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = pickerList
end

function PlantController.Init(hudController: any)
	buildPicker(hudController)

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

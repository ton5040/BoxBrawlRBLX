local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local remoteEvents = {}
local BindableEventsFolder = ReplicatedStorage:WaitForChild("BindableEvents")
local bindableEvents = {}
local RemoteFunctionsFolder = ReplicatedStorage:WaitForChild("RemoteFunctions")
local remoteFunctions = {}
local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera


local ingame = false
local playergui = player:WaitForChild("PlayerGui")
local ingamegui = playergui:WaitForChild("IngameGui")
local inventorygui = playergui:WaitForChild("InventoryGui")
local HUDFrame = ingamegui:WaitForChild("HUDFrame")
local sidebuttons = HUDFrame:WaitForChild("SideButtons")
local controlsgui = playergui:WaitForChild("ControlsGui")
local controlscore = controlsgui:WaitForChild("MainFrame"):FindFirstChild("ControlsCore")


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local mouse = player:GetMouse()
local moveStrength = 3
local ChosenDirection = Vector3.zero
local usingAbility1 = false
local usingAbility2 = false
local countdowning = false

local spectating = false

local GlobalVariablesFolder =  workspace:WaitForChild("GlobalVariables")


function getGlobalVariable(varName)
	if GlobalVariablesFolder:FindFirstChild(varName) then
		return GlobalVariablesFolder:FindFirstChild(varName).Value
	else
		return nil
	end
end


local championsPage = inventorygui.MainFrame.Main.Body.Champions
local championTemplate = championsPage:WaitForChild("SelectionBox")
local characters = ReplicatedStorage.Characters
function loadCharacters()
	for i, v in pairs(characters:GetChildren()) do
		if v:IsA("Folder") then
			local newChampion = championTemplate:Clone()
			newChampion.Name = v.Name
			newChampion.ChampionName.Text = v.Name
			local newRig = v.Rig:Clone()
			newRig.Parent = newChampion.ViewportFrame.WorldModel
			newRig:PivotTo(CFrame.new(0,0,0)) --* CFrame.Angles(0,math.rad(180),0))
			
			--play animation
			local animator = Instance.new("Animator")
			animator.Parent = newRig.Humanoid
			local anim = Instance.new("Animation")
			anim.AnimationId = v.MenuAnimation.Value
			local track = animator:LoadAnimation(anim)
			track.Priority = Enum.AnimationPriority.Idle
			track.Looped = true
			track:Play()

			--set camera
			local newCamera = Instance.new("Camera")
			newCamera.Parent = newChampion.ViewportFrame
			newChampion.ViewportFrame.CurrentCamera = newCamera
			newCamera.CFrame = CFrame.new(0,2,-3) * CFrame.Angles(math.rad(15),math.rad(-180),0)
			
			if newRig:FindFirstChild("Camera") then
				newCamera.CFrame = newRig.Camera.CFrame
				newRig.Camera:Destroy()
			end
			
			
			--locked outline
			local lockedhightlight = Instance.new("Highlight")
			lockedhightlight.FillTransparency = 1
			lockedhightlight.FillColor = Color3.new(1,1,1)
			lockedhightlight.OutlineTransparency = 0
			lockedhightlight.OutlineColor = Color3.new(1,0,0)
			lockedhightlight.DepthMode = Enum.HighlightDepthMode.Occluded
			lockedhightlight.Parent = newRig
			
			
			--newChampion.MouseButton1Click:Connect(function()
				--
			--end)
			
			newChampion.Visible = true
			newChampion.Parent = championsPage
			
			
		end
	end
end

loadCharacters()

sidebuttons.Spectate.MouseButton1Click:Connect(function()
	remoteEvents.setSpectating(not spectating)
end)

sidebuttons.Inventory.MouseButton1Click:Connect(function()
	inventorygui.Enabled = not inventorygui.Enabled
end)

function remoteEvents.updateGlobalVariables(varName, value)
	if GlobalVariablesFolder:FindFirstChild(varName) then
		GlobalVariablesFolder:FindFirstChild(varName).Value = value
	end
end

function remoteEvents.Countdown(timer)
	ingamegui.HUDFrame.Timer.TimerImage.TextLabel.Text = timer
	countdowning = true
	task.spawn(function()
		while countdowning == true do
			task.wait(1)
			if countdowning == true then
				ingamegui.HUDFrame.Timer.TimerImage.TextLabel.Text = timer - 1
			end
			timer = timer - 1
			if timer <= 0 then
				countdowning = false
				ingamegui.HUDFrame.Timer.TimerImage.TextLabel.Text = ""
			end
		end
	end)
end

function remoteEvents.UpdatePlayerCamera()
	if not player.Character or not player.Character:FindFirstChild("Humanoid") then return end
	RemoteEventsFolder.UpdateFocus:FireServer(spectating)
	if spectating == true and getGlobalVariable("SpectateBlock") then
		camera.CameraSubject = getGlobalVariable("SpectateBlock")
	else
		camera.CameraSubject = player.Character.Humanoid
	end
end

function remoteEvents.setIngame(value)
	ingame = value
	--ingamegui.Enabled = value TODO:  make it only a part of the GUI
	if value == true then
		spectating = false
	end
	remoteEvents.UpdatePlayerCamera()
end

function remoteEvents.setSpectating(value)
	print("LOCAL set spectating", value)
	spectating = value
	remoteEvents.UpdatePlayerCamera()
end

function remoteFunctions.getGameplayInfo()
	return {
		["moveStrength"] = moveStrength,
		["ChosenDirection"] = ChosenDirection,
		["usingAbility1"] = usingAbility1,
		["usingAbility2"] = usingAbility2
	}
end

-- RemoteFunctions
local missingRF = {}
for _, remote in ipairs(RemoteFunctionsFolder:GetChildren()) do
	if remote:IsA("RemoteFunction") then
		local handler = remoteFunctions[remote.Name]
		if type(handler) == "function" then remote.OnClientInvoke = handler else table.insert(missingRF, remote.Name) end
	end
end
if #missingRF > 0 then warn("[Client] Missing RemoteFunction handlers:", table.concat(missingRF, ", ")) end

-- RemoteEvents
local missingRE = {}
for _, remote in ipairs(RemoteEventsFolder:GetChildren()) do
	if remote:IsA("RemoteEvent") then
		local handler = remoteEvents[remote.Name]
		if type(handler) == "function" then remote.OnClientEvent:Connect(handler) else table.insert(missingRE, remote.Name) end
	end
end
if #missingRE > 0 then warn("[Client] Missing RemoteEvent handlers:", table.concat(missingRE, ", ")) end

-- BindableEvents
local missingBE = {}
for _, bindable in ipairs(BindableEventsFolder:GetChildren()) do
	if bindable:IsA("BindableEvent") then
		local handler = bindableEvents[bindable.Name]
		if type(handler) == "function" then bindable.Event:Connect(handler) else table.insert(missingBE, bindable.Name) end
	end
end
if #missingBE > 0 then warn("[Client] Missing BindableEvent handlers:", table.concat(missingBE, ", ")) end


-- MovementBehavior /////////////////////////////////////////////////////////////////////////////

--get q and e input 

function increaseStrength()
	moveStrength = math.clamp(moveStrength + 1, 2, 10)
end

function decreaseStrength()
	moveStrength = math.clamp(moveStrength - 1, 2, 10)
end

local UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Q then
		decreaseStrength()
	elseif input.KeyCode == Enum.KeyCode.E then
		increaseStrength()
	end
end)

controlscore.PowerLow.MouseButton1Click:Connect(function()
	decreaseStrength()
end)

controlscore.PowerHigh.MouseButton1Click:Connect(function()
	increaseStrength()
end)


-- MovementGUI ///////////////////////////////////////////////////////////////////////////
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ========================
-- CONFIG
-- ========================
local MIN_LENGTH = 1
local MAX_LENGTH = 12
local BASE_HEIGHT = 0.5
local RADIUS = 4


-- ========================
-- INDICADOR
-- ========================
local indicator = Instance.new("Part")
indicator.Name = "DirectionIndicator"
indicator.Anchored = true
indicator.CanCollide = false
indicator.Material = Enum.Material.Neon
indicator.Size = Vector3.new(0.3, 0.3, MIN_LENGTH)
indicator.Parent = workspace

-- Highlight
local highlight = Instance.new("Highlight")
highlight.Adornee = indicator
highlight.FillTransparency = 0.5
highlight.OutlineTransparency = 0
highlight.Parent = indicator

-- ========================
-- UTILIDADES
-- ========================
local function getColorFromStrength(strength)
	local t = math.clamp((strength - 1) / 9, 0, 1)

	if t < 0.5 then
		-- Verde -> Amarelo
		return Color3.new(
			t * 2,
			1,
			0
		)
	else
		-- Amarelo -> Vermelho
		return Color3.new(
			1,
			1 - (t - 0.5) * 2,
			0
		)
	end
end

-- ========================
-- LOOP
-- ========================


RunService.RenderStepped:Connect(function()
	if not player.Character then return end
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	if ingame == false then
		indicator.Transparency = 1
		return
	else
		indicator.Transparency = 0
	end

	-- direção horizontal da câmera
	local look = camera.CFrame.LookVector
	local direction = Vector3.new(look.X, 0, look.Z)
	if direction.Magnitude < 0.01 then return end
	direction = direction.Unit

	ChosenDirection = direction

	-- tamanho baseado na força
	local length = MIN_LENGTH + (MAX_LENGTH - MIN_LENGTH) * ((moveStrength - 1) / 9)
	indicator.Size = Vector3.new(0.3, 0.3, length)
	
	-- cor baseada na força
	local color = getColorFromStrength(moveStrength)
	indicator.Color = color
	highlight.FillColor = color
	highlight.OutlineColor = color

	-- posição
	local basePos = Vector3.new(
		root.Position.X,
		root.Position.Y + BASE_HEIGHT,
		root.Position.Z
	)

	-- distância da base da seta ao jogador
	local BASE_OFFSET = 1

	-- posição da base (origem da seta)
	local baseIndicatorPos = basePos + direction * BASE_OFFSET

	-- empurra o centro da seta para frente metade do tamanho
	local centerOffset = direction * (length / 2)

	indicator.CFrame = CFrame.lookAt(
		baseIndicatorPos + centerOffset,
		baseIndicatorPos + direction
	)

end)



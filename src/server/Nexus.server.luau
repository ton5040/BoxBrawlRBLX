-- Nexus.lua

local modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local RoundModule = require(modules:WaitForChild("RoundModule"))
local Round = RoundModule.new()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerObjects = {}
local playerCharacters = {}
local PlayerClass = require(modules.PlayerClass)


local GlobalVariablesFolder =  workspace:WaitForChild("GlobalVariables")

function getGlobalVariable(varName)
	if GlobalVariablesFolder:FindFirstChild(varName) then
		return GlobalVariablesFolder:FindFirstChild(varName).Value
	else
		return nil
	end
end

function setGlobalVariable(varName, value)
	if GlobalVariablesFolder:FindFirstChild(varName) then
		GlobalVariablesFolder:FindFirstChild(varName).Value = value
	end
end

--local CharacterClass = require(ReplicatedStorage:WaitForChild("Modules").Character.CharacterClass)

game.Players.PlayerAdded:Connect(function(player)
	local playerObject = PlayerClass.new(player)
	PlayerObjects[player.Name] = playerObject
	--autoload
	Round:AddPlayer(playerObject)
	player.Chatted:Connect(function(message)
		if not playerObject.CharacterClass then return end
		--starts with emote
		if message:sub(1,7) == "/emote " then
			local emoteName = message:sub(8)
			playerObject.CharacterClass:PlayEmote(emoteName)
		end
		if message:sub(1,2) == "re" then
			playerObject.CharacterClass:PlayEmote(ReplicatedStorage.Emotes:GetChildren()[math.random(1,#ReplicatedStorage.Emotes:GetChildren())].Name)
		end
		if message:sub(1,2) == "se" then
			playerObject.CharacterClass:StopEmote()
		end
		if message:sub(1,11) == "/resetround" then
			Round:EndRound()
		end
		if message:sub(1,4) == "/afk" then
			playerObject.Playing = not playerObject.Playing
		end
	end)
	
end)

game.Players.PlayerRemoving:Connect(function(player)
	--save, but autosave too.
	local playerObject = PlayerObjects[player.Name]
	if playerObject then
		Round:RemovePlayer(playerObject)
	end
	playerCharacters[player.Name] = nil
end)

function addBot(botObj)
	local playerObject = PlayerClass.new(botObj)
	PlayerObjects[botObj] = playerObject
	Round:AddPlayer(playerObject)
end

addBot(ReplicatedStorage:WaitForChild("Bots"):WaitForChild("mechanzaki"))

addBot(ReplicatedStorage:WaitForChild("Bots"):WaitForChild("JUL10"))


-- Remote and Bindables Handler /////////////////////////////////


local RemoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local remoteEvents = {}
local BindableEventsFolder = ReplicatedStorage:WaitForChild("BindableEvents")
local bindableEvents = {}
local RemoteFunctionsFolder = ReplicatedStorage:WaitForChild("RemoteFunctions")
local remoteFunctions = {}
local BindableFunctionsFolder = ReplicatedStorage:WaitForChild("BindableFunctions")
local bindableFunctions = {}

local blankBindableEvents = {}
local blankRemoteEvents = {"UpdatePlayerCamera", "setIngame", "Countdown", "Notify", "updateGlobalVariables"}
local blankRemoteFunctions = {"getGameplayInfo"}
local blankBindableFunctions = {}

function remoteEvents.UpdateFocus(player, spectating)
	if not player then return end
	RemoteEventsFolder.updateGlobalVariables:FireClient(player, "SpectateBlock", getGlobalVariable("SpectateBlock"))
	if spectating == true and getGlobalVariable("SpectateBlock") then
		print("SERVER set spectating to block", spectating)
		player.ReplicationFocus = getGlobalVariable("SpectateBlock")
		player:AddReplicationFocus(getGlobalVariable("SpectateBlock"))
	else
		print("SERVER set spectating to player", spectating)
		player.ReplicationFocus = player.Character
		pcall(function()
			player:RemoveReplicationFocus(getGlobalVariable("SpectateBlock"))
		end)
	end
end

function bindableEvents.PlayerDeath(player)
	local playerObject = PlayerObjects[player.Name]
	if playerObject then
		--Round:RemovePlayer(playerObject)
		task.delay(1,function()
			player:LoadCharacter()
			player.ReplicationFocus = player.Character
		end)
	end
end

for _, child in ipairs(blankBindableEvents) do
	remoteEvents[child] = function() end
end

for _, child in ipairs(blankRemoteEvents) do
	remoteEvents[child] = function() end
end

for _, child in ipairs(blankRemoteFunctions) do
	remoteFunctions[child] = function() end
end

for _, child in ipairs(blankBindableFunctions) do
	bindableFunctions[child] = function() end
end


-- RemoteFunctions
for remoteName, handler in pairs(remoteFunctions) do
	local remote = RemoteFunctionsFolder:FindFirstChild(remoteName)
	if not remote then
		remote = Instance.new("RemoteFunction")
		remote.Name = remoteName
		remote.Parent = RemoteFunctionsFolder
	end
	if type(handler) == "function" then
		remote.OnServerInvoke = function(player, ...)
			return handler(player, ...)
		end
	else
		warn("[Server] Missing RemoteFunction handler for:", remoteName)
	end
end

-- RemoteEvents
for remoteName, handler in pairs(remoteEvents) do
	local remote = RemoteEventsFolder:FindFirstChild(remoteName)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = RemoteEventsFolder
	end
	if type(handler) == "function" then
		remote.OnServerEvent:Connect(function(player, ...)
			handler(player, ...)
		end)
	else
		warn("[Server] Missing RemoteEvent handler for:", remoteName)
	end
end

-- BindableEvents
for bindableName, handler in pairs(bindableEvents) do
	local bindable = BindableEventsFolder:FindFirstChild(bindableName)
	if not bindable then
		bindable = Instance.new("BindableEvent")
		bindable.Name = bindableName
		bindable.Parent = BindableEventsFolder
	end
	if type(handler) == "function" then
		bindable.Event:Connect(function(...)
			handler(...)
		end)
	else
		warn("[Server] Missing BindableEvent handler for:", bindableName)
	end
end

-- BindableFunctions
for bindableName, handler in pairs(bindableFunctions) do
	local bindable = BindableFunctionsFolder:FindFirstChild(bindableName)
	if not bindable then
		bindable = Instance.new("BindableFunction")
		bindable.Name = bindableName
		bindable.Parent = BindableFunctionsFolder
	end
	if type(handler) == "function" then
		bindable.OnInvoke = function(...)
			return handler(...)
		end
	else
		warn("[Server] Missing BindableFunction handler for:", bindableName)
	end
end

-- ROUND -- //////////////////////////////////////////////////

Round.OnCollectActions = function(players)
	for _, player in ipairs(players) do
		task.spawn(function()
			if player.Bot == true then return end
			if not player.Player then return end
			local info
			pcall(function()				
				info = RemoteFunctionsFolder.getGameplayInfo:InvokeClient(player.Player)
			end)
			if not info then return end
			player.CharacterClass.Direction = info.ChosenDirection
			player.CharacterClass.Power = info.moveStrength
			player.CharacterClass.UsingAbility1 = info.usingAbility1
			player.CharacterClass.UsingAbility2 = info.usingAbility2
		end)
	end
end

Round.OnExecuteActions = function(players)
	for _, player in ipairs(players) do
		task.spawn(function()
			player.CharacterClass:ApplyMovement(player)
		end)
	end
end

Round.OnArenaShrink = function(size)
	-- diminuir arena
end

Round.OnTurnEnd = function()
	for k, player in PlayerObjects do
		if player.CharacterClass then
			player.CharacterClass:ChargeFury()
		end
	end
end

Round.OnPlayerEliminated = function(player)
	print(player.Name, "foi eliminado")
	player.CharacterClass.Alive = false
	player.CharacterClass:Death()
end

Round.OnClashPrelude = function()
	for k, player in PlayerObjects do
		print("Player:", player.Name, "Bot:", player.Bot)
		if player.CharacterClass then
			print("Alive: ", player.CharacterClass.Alive)
			player.CharacterClass:ShowIntent()
		end
	end
end

Round.OnRoundEnd = function()
	for k, player in PlayerObjects do
		if player.CharacterClass then
			player.CharacterClass:Death()
			player.CharacterClass.Alive = false
		end
	end
end




task.wait(10)
Round:StartRound()

--ALIVEPLAYERS E PLAYERS, DIFERENTE DA TABELA DE PLAYERS DO NEXUS. TEM QUE MESCLAR AS DUAS OU DEIXAR APENAS ALIVE PLAYERS 
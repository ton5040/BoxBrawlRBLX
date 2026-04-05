-- RoundManager.lua
local Round = {}
Round.__index = Round

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local maps = game:GetService("ReplicatedStorage"):WaitForChild("Maps")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local remoteEvents = {}
local BindableEventsFolder = ReplicatedStorage:WaitForChild("BindableEvents")
local bindableEvents = {}
local RemoteFunctionsFolder = ReplicatedStorage:WaitForChild("RemoteFunctions")
local remoteFunctions = {}
local BindableFunctionsFolder = ReplicatedStorage:WaitForChild("BindableFunctions")
local bindableFunctions = {}

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


--=====================================================
-- Constructor (called ONCE when server starts)
--=====================================================
function Round.new()
	print("[Round] Initializing Turn Based Round")

	local self = setmetatable({}, Round)

	-- Core state
	self.Players = {}          -- all players in the match
	self.AlivePlayers = {}    -- players still alive
	self.RoundActive = false
	self.MapBase = maps.MapRotation:FindFirstChild('BasicMap')
	self.MapFunctions = nil
	print(self.MapBase)
	self.CurrentMap = nil
	-- Turn system
	self.CurrentTurn = 0
	self.TurnActive = false
	self.ChoiceDuration = 10   -- seconds to choose action
	self.ExecutionDelay = 4   -- small delay before execution
	self.IntermissionTime = 8

	-- Arena
	self.ArenaSize = 100        -- abstract value, you decide what it means

	--=====================================================
	-- Hooks (YOU implement elsewhere)
	--=====================================================
	self.OnRoundStart = function() end
	self.OnRoundEnd = function(winner) end

	self.OnTurnStart = function(turnNumber) end
	self.OnCollectActions = function(players) end
	self.OnExecuteActions = function(players) end
	self.OnTurnEnd = function(turnNumber) end

	self.OnPlayerEliminated = function(player) end
	self.OnArenaShrink = function(newArenaSize) end

	return self
end

--=====================================================
-- Player management
--=====================================================
function Round:AddPlayer(playerData)
	table.insert(self.Players, playerData)
end

function Round:RemovePlayer(playerData)
	print("[Round] Removing player:", playerData.Player.Name)
	for i, p in ipairs(self.AlivePlayers) do
		if p == playerData then
			print("[Round] Found and removed from alive list")
			table.remove(self.AlivePlayers, i)
			self.OnPlayerEliminated(playerData)
			break
		end
	end
end

function Round:BindDeadzones(deadzones)
	for _, zone in ipairs(deadzones:GetChildren()) do
		zone.Touched:Connect(function(hit)
			if hit and hit.Parent and hit.Parent:FindFirstChild("Humanoid") then
				hit.Parent:Destroy()
			end
		end)
	end
end

function Round:ReloadMap()
	if self.CurrentMap then
		self.CurrentMap:Destroy()
		setGlobalVariable("SpectateBlock", nil)
		self.MapFunctions = nil
	end
	self.CurrentMap = self.MapBase:Clone()
	self.MapFunctions = require(self.CurrentMap.MapF)
	self.CurrentMap.Parent = workspace
	self:BindDeadzones(self.CurrentMap.Deadzones)
	setGlobalVariable("SpectateBlock", self.CurrentMap.CameraBlock) 
	print("[Round] Map reloaded:", self.CurrentMap.Name)
end

--=====================================================
-- Round control
--=====================================================
function Round:StartRound()
	if self.RoundActive then return end

	self:ReloadMap()

	self.RoundActive = true
	self.CurrentTurn = 0

	self.AlivePlayers = {}
	self:SpawnAllPlayers()

	print("[Round] Round started")
	self.OnRoundStart()

	print("Players:", #self.Players)
	print("AlivePlayers:", #self.AlivePlayers)

	task.spawn(function()
		self:TurnLoop()
	end)
end

function Round:SpawnAllPlayers()
	local playerCount = #self.Players
	local radius = 10 -- Adjust this to control how spread out players are

	local angleStep = (2 * math.pi) / playerCount
	local index = 0

	for _, playerData in ipairs(self.Players) do
		if playerData.Playing == false then continue end
		table.insert(self.AlivePlayers, playerData)
		playerData:CreateCharacter()

		-- Calculate offset position around the circle
		local angle = angleStep * index
		local offsetX = math.cos(angle) * radius
		local offsetZ = math.sin(angle) * radius

		local spawnCFrame = self.CurrentMap.Spawn.CFrame * CFrame.new(offsetX, 0, offsetZ)
		playerData.CharacterClass:SpawnPlayer(spawnCFrame)

		index += 1
	end
end

function Round:EndRound(winner)
	self.RoundActive = false
	self.TurnActive = false

	print("[Round] Round ended. Winner:", winner and winner.Name or "None")
	self.OnRoundEnd(winner)
	
	task.wait(self.IntermissionTime)
	self:StartRound()
end

--=====================================================
-- Turn Loop
--=====================================================
function Round:TurnLoop()
	while self.RoundActive do
		if #self.AlivePlayers <= 1 then
			self:EndRound(self.AlivePlayers[1])
			--notify intermission
			break
		end

		self.CurrentTurn += 1
		self.TurnActive = true

		print("[Round] Turn", self.CurrentTurn, "started")
		self.OnTurnStart(self.CurrentTurn)
		RemoteEventsFolder.Countdown:FireAllClients(self.ChoiceDuration -  1)

		--=====================================
		-- Phase 1: Collect player actions
		--=====================================
		task.wait(self.ChoiceDuration/2)
		self.OnCollectActions(self.AlivePlayers)
		task.wait(self.ChoiceDuration/2)
		self.OnCollectActions(self.AlivePlayers)
		task.wait(1)
		self.OnClashPrelude()
		task.wait(1)
		--=====================================
		-- Phase 2: Execute actions
		--=====================================
		self.OnExecuteActions(self.AlivePlayers)
		task.wait(self.ExecutionDelay)


		--=====================================
		-- Phase 3: Resolve deaths (external logic sets alive/dead)
		--=====================================
		self:CleanupDeadPlayers()

		--=====================================
		-- Phase 4: Shrink arena
		--=====================================
		self:ShrinkArena()
		self.OnTurnEnd(self.CurrentTurn)
		self.TurnActive = false

		task.wait(0.5)
	end
end

--=====================================================
-- Helpers
--=====================================================
function Round:CleanupDeadPlayers()
	for i = #self.AlivePlayers, 1, -1 do
		local player = self.AlivePlayers[i]
		if not player.CharacterClass or player.CharacterClass.Alive == false then
			table.remove(self.AlivePlayers, i)
			self.OnPlayerEliminated(player)
		end
	end
end

function Round:ShrinkArena()
	self.MapFunctions.Shrink(self.CurrentMap.GamePlate)
end

return Round

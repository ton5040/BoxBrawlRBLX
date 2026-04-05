-- ServerScriptService/PlayerClass.lua
local PlayerClass = {}
PlayerClass.__index = PlayerClass

-- Constructor
function PlayerClass.new(player)
	local self = setmetatable({}, PlayerClass)

	self.Player = player
	self.Bot = not player:IsA("Player") -- true if this is a bot
	self.Playing = true
	self.Ozals = 0 --ozals
	self.VS = 0
	self.Name = player.Name	
	self.Level = 1
	self.Inventory = {}
	self.CharacterClass = nil
	self.CurrentCharacter = "Basic"
	self.Lives = 0
	
	self.totalDamage = 0
	self.totalDamageThisLife = 0
	
	self.totalPoints = 0
	self.totalKills = 0
	self.totalAssists = 0
	self.totalAssistsThisLife = 0
	self.totalDeaths = 0
	self.totalPointsThisLife = 0
	self.totalKillsThisLife = 0
	self.totalDeathsThisLife = 0
	
	self.inGame = false
	self.configs = {Music = 0.9}
	self.ownedCharacters = {"Basic"}
	self.ownedEmotes = {}
	self.ownedAuras = {}
	self.ownedStickers = {}
	self.ownedTitles = {}
	self.ownedPasses = {}
	

	return self
end

function PlayerClass:CreateCharacter()
	if self.CharacterClass then
		self.CharacterClass:Death()
	end
	self.CharacterClass = require(game.ReplicatedStorage.Modules.CharacterClass).new(self)
end

function PlayerClass:ResetTemporaryStats()
	self.Lives = 0
	self.totalPointsThisLife = 0
	self.totalKillsThisLife = 0
	self.totalDamageThisLife = 0
	self.totalDeathsThisLife = 0
	self.totalAssistsThisLife = 0
end

function PlayerClass:GetSaveTable()
	local tabn = {}
	local stufftosave = {""}
	for i,v in pairs(stufftosave) do
		tabn[v] = self[v]
	end
	return tabn
end

function PlayerClass:GetSyncTable()
	local tabn = {}
	local stufftosave = {""}  --TODO:::FIX
	for i,v in pairs(stufftosave) do
		tabn[v] = self[v]
	end
	return tabn
		
end

function deepCopy(orig)
	if type(orig) ~= "table" then return orig end
	local copy = {}
	for k, v in pairs(orig) do
		copy[k] = deepCopy(v)
	end
	return copy
end

function PlayerClass:LoadTable(tabn)
	for i,v in pairs(tabn) do
		self[i] = deepCopy(v)
	end
end


return PlayerClass

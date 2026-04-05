-- CharacterClass.lua
local CharacterClass = {}
CharacterClass.__index = CharacterClass

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RigsFolder = ReplicatedStorage:WaitForChild("Rigs")
local DEFAULT_RIG_NAME = "BasicRig"
local BoxFolder = ReplicatedStorage:WaitForChild("Box")
local DEFAULT_MOUNT = "pillow"

local RemoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local remoteEvents = {}
local BindableEventsFolder = ReplicatedStorage:WaitForChild("BindableEvents")
local bindableEvents = {}
local RemoteFunctionsFolder = ReplicatedStorage:WaitForChild("RemoteFunctions")
local remoteFunctions = {}
local BindableFunctionsFolder = ReplicatedStorage:WaitForChild("BindableFunctions")
local bindableFunctions = {}

local emoteFolder = ReplicatedStorage:WaitForChild("Emotes")


--========================================
-- Constructor
--========================================
function CharacterClass.new(playerObject)
	local self = setmetatable({}, CharacterClass)

	self.PlayerObject = playerObject
	self.Player = playerObject.Player

	self.Character = nil
	self.Root = nil

	-- Turn-based data
	self.Direction = Vector3.zero
	self.Power = 1
	self.Fury = 20
	self.MaxFury = 100
	self.FuryRegen = 20

	self.Alive = false
	self.LoadPlayerSkin = true
	

	return self
end

function CharacterClass:ChargeFury()
	-- PLAYVFX()
	if self.Fury < self.MaxFury then
		self.Fury = math.min(self.Fury + self.FuryRegen, self.MaxFury)
	end
end

--========================================
-- Spawn custom character
--========================================
function CharacterClass:SpawnPlayer(spawnCFrame)
	if self.Character then
		self:Death()
	end


	local rigTemplate = RigsFolder:FindFirstChild(DEFAULT_RIG_NAME)
	if not rigTemplate then
		warn("[CharacterClass] Rig not found:", DEFAULT_RIG_NAME)
		return
	end

	local rig = rigTemplate:Clone()
	rig.Name = self.Player.Name .. "_Character"

	if not rig.PrimaryPart then
		warn("[CharacterClass] Rig has no PrimaryPart")
		return
	end


	rig:SetPrimaryPartCFrame(spawnCFrame or CFrame.new(0, 10, 0))
	rig.Parent = Workspace
	

	if self.LoadPlayerSkin and self.Player:IsA("Player") and self.Player.UserId > 0 then
		local humanoidDescription = game.Players:GetHumanoidDescriptionFromUserIdAsync(self.Player.UserId)
		rig.Humanoid:ApplyDescription(humanoidDescription)
		rig.LowerTorso.Root.C0 = CFrame.new(0, 1.35, 0)
		task.delay(0.5,function()
			local  c = rig:GetChildren()
			for i = 1, #c do
				if c[i]:IsA("Accessory") then
					local c2 = c[i]:GetChildren()
					for i2 = 1, #c2 do
						if c2[i2]:IsA("BasePart") then
							c2[i2].CanCollide = false
							c2[i2].Massless = true
						end
					end
				end
			end
		end)
	end
	
	if self.Player:IsA("Player") then
		self.Player.ReplicationFocus = rig
	end
	
	self.Character = rig
	self.Root = rig.PrimaryPart
	self.Alive = true
	rig.Humanoid:ChangeState(Enum.HumanoidStateType.None)
	
	local boxrig = BoxFolder:FindFirstChild(DEFAULT_MOUNT):Clone()
	self:EquipVisualItem("Mount", self.Root, boxrig, boxrig:FindFirstChild("Offset").Value)
	
	if boxrig:FindFirstChild("Animations") then
		if boxrig:FindFirstChild("Animations"):FindFirstChild("idle1") then
			local track = boxrig:FindFirstChild("Animations"):FindFirstChild("idle1").Value
			local track2 = boxrig:FindFirstChild("Animations"):FindFirstChild("idle2").Value
			local Animate = rig:FindFirstChild("Animate")
			Animate.idle.Animation1.AnimationId = track
			Animate.idle.Animation2.AnimationId = track2
			task.delay(1,function()
				Animate.Enabled = true
			end)
		end
	end
	

	if self.Player:IsA("Player") then
		self.Player.Character = rig
		RemoteEventsFolder.UpdatePlayerCamera:FireClient(self.Player)
		RemoteEventsFolder.setIngame:FireClient(self.Player, true)
		
	end
	
	if rig:WaitForChild("Hitbox") then
		rig.Hitbox:SetNetworkOwner(nil)
	end
	

	task.spawn(function()
		while wait(0.5) do
			print("ALIVE")
			if not self.Character or self.Character.Parent == nil or not self.Root or self.Root.Parent == nil then
				print("DEAD")
				self:Death()
				break
				
			end
		end
	end)

	print("[CharacterClass] Spawned character for", self.Player.Name)
end

--========================================
-- Set chosen direction
--========================================
function CharacterClass:SetDirection(direction)
	if typeof(direction) ~= "Vector3" then
		warn("[CharacterClass] Direction must be Vector3")
		return
	end

	self.Direction = direction.Unit
end

--========================================
-- Set power (1–10)
--========================================
function CharacterClass:SetPower(power)
	if typeof(power) ~= "number" then return end

	power = math.clamp(math.floor(power), 1, 10)
	self.Power = power
end

function CharacterClass:ShowIntent()
	if not self.Character then return end
	if not self.Root then return end

	if self.Direction.Magnitude < 0.01 then return end

	--========================
	-- CONFIG
	--========================
	local MIN_LENGTH = 1
	local MAX_LENGTH = 10
	local BASE_OFFSET = 1.5
	local HEIGHT_OFFSET = 0.5

	--========================
	-- GIRAR PERSONAGEM (horizontal)
	--========================
	local dir = Vector3.new(self.Direction.X, 0, self.Direction.Z).Unit
	local rootPos = self.Root.Position

	local start = self.Root.CFrame
	local goal  = CFrame.lookAt(rootPos, rootPos + dir)

	for i = 1, 10 do
		self.Root.CFrame = start:Lerp(goal, (i/10)^2) -- alpha 0..1 [web:17]
		task.wait(0.03)
	end

	--========================
	-- CALCULAR FORÇA
	--========================
	local t = math.clamp((self.Power - 1) / 9, 0, 1)
	local length = MIN_LENGTH + (MAX_LENGTH - MIN_LENGTH) * t

	local color
	if t < 0.5 then
		color = Color3.new(t * 2, 1, 0) -- verde → amarelo
	else
		color = Color3.new(1, 1 - (t - 0.5) * 2, 0) -- amarelo → vermelho
	end

	--========================
	-- CRIAR / REUSAR SETA
	--========================
	local arrow = self.Character:FindFirstChild("IntentArrow")

	if not arrow then
		arrow = Instance.new("Part")
		arrow.Name = "IntentArrow"
		arrow.Anchored = true
		arrow.Massless = true
		arrow.CanCollide = false
		arrow.Material = Enum.Material.Neon
		arrow.Size = Vector3.new(0.25, 0.25, length)
		arrow.Parent = self.Character

		local highlight = Instance.new("Highlight")
		highlight.Name = "Highlight"
		highlight.FillTransparency = 0.4
		highlight.OutlineTransparency = 0
		highlight.Parent = arrow
	end

	--========================
	-- ATUALIZAR SETA
	--========================
	arrow.Size = Vector3.new(0.25, 0.25, length)
	arrow.Color = color

	local highlight = arrow:FindFirstChild("Highlight")
	if highlight then
		highlight.Adornee = arrow
		highlight.FillColor = color
		highlight.OutlineColor = color
	end

	--========================
	-- POSICIONAR SETA (ORIGEM PERTO DO PLAYER)
	--========================
	local basePos = rootPos + Vector3.new(0, HEIGHT_OFFSET, 0)
	local startPos = basePos + dir * BASE_OFFSET
	local centerPos = startPos + dir * (length / 2)

	arrow.CFrame = CFrame.lookAt(
		centerPos,
		centerPos + dir
	)
	
	task.delay(2,function()
		arrow:Destroy()
	end)

end





--========================================
-- Apply movement using Direction + Power
--========================================
function CharacterClass:ApplyMovement()
	if not self.Alive then return end
	if not self.Root then return end
	if self.Direction.Magnitude < 0.01 then return end

	-- remove qualquer força anterior
	for _, v in ipairs(self.Root:GetChildren()) do
		if v:IsA("LinearVelocity") then
			v:Destroy()
		end
	end

	-- força base (ajuste fino aqui)
	local MIN_FORCE = 3
	local MAX_FORCE = 60

	local t = (self.Power - 1) / 9
	local force = MIN_FORCE + (MAX_FORCE - MIN_FORCE) * t

	-- direção horizontal garantida
	local direction = Vector3.new(
		self.Direction.X,
		0,
		self.Direction.Z
	).Unit

	-- attachment obrigatório
	local attachment = self.Root:FindFirstChild("MoveAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "MoveAttachment"
		attachment.Parent = self.Root
	end

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "TurnImpulse"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = direction * force
	velocity.Parent = self.Root

	-- remove depois de um curto tempo (impulso, não aceleração infinita)
	task.delay(0.001, function()
		if velocity then
			velocity:Destroy()
		end
	end)
end

function CharacterClass:StopEmote()
	if self.playingEmote then
		self.playingEmote:Stop()
		self.playingEmote:Destroy()
		self.playingEmote = nil
	end

	-- parar música atual
	if self.playingMusic then
		self.playingMusic:Stop()
		self.playingMusic:Destroy()
		self.playingMusic = nil
	end
	if self.Character:FindFirstChild("Animate") then
		self.Character.Animate.Enabled = false
		task.wait(0.05)
		self.Character.Animate.Enabled = true
	end
end

function CharacterClass:PlayEmote(emoteName)
	if not self.Character then return end

	local humanoid = self.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- garante Animator (best practice)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	if self.playingEmote then
		self.playingEmote:Stop()
		self.playingEmote:Destroy()
		self.playingEmote = nil
	end

	-- parar música atual
	if self.playingMusic then
		self.playingMusic:Stop()
		self.playingMusic:Destroy()
		self.playingMusic = nil
	end
	

	local emote = emoteFolder:FindFirstChild(emoteName)
	if not emote then
		warn("Emote not found:", emoteName)
		return
	end

	local animIdValue = emote:FindFirstChild("AnimId")
	if not animIdValue or animIdValue.ClassName ~= "StringValue" then
		warn("AnimId StringValue missing for emote:", emoteName)
		return
	end

	-- criar Animation dinamicamente
	local animation = Instance.new("Animation")
	animation.AnimationId = animIdValue.Value

	local track = animator:LoadAnimation(animation)
	track.Looped = true
	track:Play()

	self.playingEmote = track

	-- destruir animation quando parar
	track.Stopped:Once(function()
		if animation then
			animation:Destroy()
		end
	end)

	-- som opcional
	local sound = emote:FindFirstChildOfClass("Sound")
	if sound and self.Character:FindFirstChild("Head") then
		self.playingMusic = sound:Clone()
		self.playingMusic.Parent = self.Character.Head
		self.playingMusic:Play()
	end
end

--// EquipVisualItem: Attaches a visual item to a target (Attachment or BasePart) 
function CharacterClass:EquipVisualItem(itemSlot: string, target: Instance, toolModel: Instance, offset: CFrame?)
	if not self.Character or not itemSlot or not toolModel then return end

	self._equippedVisualItems = self._equippedVisualItems or {}
	self:UnequipVisualItem(itemSlot) -- Remove same-named item if already equipped

	local char = self.Character
	local clone = toolModel:Clone()
	clone.Name = "VisualItem_" .. itemSlot
	clone.Parent = char

	local primary = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
	if not primary then
		warn("EquipVisualItem: No primary part found in", itemSlot)
		clone:Destroy()
		return
	end
	primary.Name = "VisualPrimary_" .. itemSlot
	offset = offset or CFrame.new()

	-- Create Motor6D for animatable attachment
	if target:IsA("Attachment") then
		local targetPart = target.Parent
		if not targetPart or not targetPart:IsA("BasePart") then
			warn("EquipVisualItem: Attachment target parent invalid for", itemSlot)
			clone:Destroy()
			return
		end

		local motor = Instance.new("Motor6D")
		motor.Name = "VisualMotor_" .. itemSlot
		motor.Part0 = targetPart
		motor.Part1 = primary
		motor.C0 = target.CFrame
		motor.C1 = offset
		motor.Parent = targetPart
	else
		if not target:IsA("BasePart") then
			warn("EquipVisualItem: Invalid target type for", itemSlot)
			clone:Destroy()
			return
		end

		local motor = Instance.new("Motor6D")
		motor.Name = "VisualMotor_" .. itemSlot
		motor.Part0 = target
		motor.Part1 = primary
		motor.C0 = CFrame.new()
		motor.C1 = offset
		motor.Parent = target
	end

	-- Disable collisions for all item parts
	for _, part in pairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Massless = true
			part.CollisionGroup = "VisualItems"
		end
	end

	self._equippedVisualItems[itemSlot] = clone
	print(`[VisualItem] Equipped {itemSlot} on {self.Name}`)
end


--// UnequipVisualItem: Removes the visual item
function CharacterClass:UnequipVisualItem(itemSlot: string)
	if not self._equippedVisualItems then return end
	local item = self._equippedVisualItems[itemSlot]
	if item then
		local visualMotor = nil

		-- Find and destroy the Motor6D associated with this item
		for _, obj in pairs(self.Character:GetDescendants()) do
			if obj:IsA("Motor6D") and obj.Name == "VisualMotor_" .. itemSlot then
				visualMotor = obj
				break
			end
		end

		if visualMotor then
			visualMotor:Destroy()
		end

		item:Destroy()
		self._equippedVisualItems[itemSlot] = nil
		print(`[VisualItem] Unequipped {itemSlot} from {self.Name}`)
	end
end

--========================================
-- Kill character
--========================================
function CharacterClass:Death()
	if self.Alive == false then return end

	self.Alive = false

	self.Character:Destroy()
	self.Character = nil
	self.Root = nil

	if self.Player:IsA("Player") then
		RemoteEventsFolder.setIngame:FireClient(self.Player, false)
	end

	print("[CharacterClass] Character died for", self.Player.Name)
	BindableEventsFolder.PlayerDeath:Fire(self.Player)
end

return CharacterClass

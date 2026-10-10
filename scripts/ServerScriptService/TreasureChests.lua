-- Studio配置: ServerScriptService > TreasureChests（ModuleScript）
-- 役割: 飛距離に応じて宝箱を落とし（光の柱 → 空から落下 → 土ぼこり）、本人が開けたら武器を引いて渡す。
--       状態は持たず、宝箱ごとの情報は宝箱のモデルの属性（OwnerUserId・Tier・Opened）に持たせる。
--       宝箱をもらった一番遠い線は、プレイヤーの属性 ChestLineReached に持たせる（PlayerData を作ったら保存する）。
--       宝箱は Workspace > TreasureChests に置く（全員に見える）。開けられるのは飛ばした本人だけ。
--       開ける合図（ProximityPrompt）は ChestService が受けて open を呼ぶ。
--       空を光らせる・着地で揺らす・当たったものの表示は、本人の画面だけに出すので、プレイヤー側（ChestReward）が行う

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local ChestLoot = require(ReplicatedStorage.Shared.ChestLoot)
local ChestBuilder = require(ServerScriptService.ChestBuilder)
local WeaponInventory = require(ServerScriptService.WeaponInventory)

local config = CombatConfig.Chests
local chestDroppedEvent = ReplicatedStorage.Remotes.ChestDropped
local chestOpenedEvent = ReplicatedStorage.Remotes.ChestOpened

local TreasureChests = {}

TreasureChests.PROMPT_NAME = "OpenChestPrompt"

local function getFolder()
	return workspace:FindFirstChild("TreasureChests")
end

-- 真上から下へ調べて地面の高さを探す（キャラクターと宝箱は無視する）。見つからなければ fallbackY
local function findGroundY(x, z, fromY, fallbackY)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { getFolder() }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then table.insert(ignore, player.Character) end
	end
	for _, model in ipairs(workspace:GetChildren()) do
		if model:FindFirstChildOfClass("Humanoid") then table.insert(ignore, model) end -- Noob など
	end
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -fromY - 500, 0), params)
	return if result then result.Position.Y else fallbackY
end

-- 光の柱（地面から DropHeight まで）。ふわっと現れる
local function createPillar(groundPosition, color)
	local pillar = Instance.new("Part")
	pillar.Name = "ChestPillar"
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Size = Vector3.new(config.DropHeight, config.PillarWidth, config.PillarWidth)
	-- 円柱は X 軸が長さの向きなので、Z 軸まわりに90°回して縦にする
	pillar.CFrame = CFrame.new(groundPosition + Vector3.new(0, config.DropHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Color = color
	pillar.Material = Enum.Material.Neon
	pillar.Transparency = 1
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanQuery = false
	pillar.CastShadow = false
	pillar.Parent = getFolder()
	TweenService:Create(pillar, TweenInfo.new(0.15), { Transparency = 0.55 }):Play()
	return pillar
end

-- 着地した場所から土ぼこりを舞わせる
local function puffDust(groundPosition)
	local holder = Instance.new("Part")
	holder.Name = "ChestDust"
	holder.Size = Vector3.new(1, 1, 1)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CFrame = CFrame.new(groundPosition)
	holder.Parent = getFolder()

	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(190, 170, 140))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.6, 1)
	dust.Speed = NumberRange.new(8, 14)
	dust.SpreadAngle = Vector2.new(180, 10) -- 横へ円く広げる
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Acceleration = Vector3.new(0, 2, 0)
	dust.Drag = 4
	dust.Rate = 0
	dust.Parent = holder
	dust:Emit(config.DustCount)
	Debris:AddItem(holder, 2)
end

-- 宝箱を1つ落とす。angle は叩いた人から見た落ちる向き（ラジアン）
local function dropChest(player, tierIndex, angle)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local tier = config.Tiers[tierIndex]

	local distance = config.DropDistance[1] + math.random() * (config.DropDistance[2] - config.DropDistance[1])
	local x = root.Position.X + math.cos(angle) * distance
	local z = root.Position.Z + math.sin(angle) * distance
	local groundY = findGroundY(x, z, root.Position.Y + 50, root.Position.Y - 3)
	local groundPosition = Vector3.new(x, groundY, z)
	-- 正面を叩いた人に向ける
	local center = groundPosition + Vector3.new(0, ChestBuilder.HALF_HEIGHT, 0)
	local landedCFrame = CFrame.lookAt(center, Vector3.new(root.Position.X, center.Y, root.Position.Z))

	chestDroppedEvent:FireClient(player, groundPosition, config.PillarTime + config.FallTime)
	local pillar = createPillar(groundPosition, tier.Color)
	task.wait(config.PillarTime)

	local chest = ChestBuilder.build(tier)
	chest:SetAttribute("OwnerUserId", player.UserId)
	chest:SetAttribute("Tier", tierIndex)
	local skyCFrame = landedCFrame + Vector3.new(0, config.DropHeight, 0)
	chest:PivotTo(skyCFrame)
	chest.Parent = getFolder()

	-- 落下。だんだん速くなる（経過の2乗）。固定した部品なので毎フレーム置き直す
	local startedAt = os.clock()
	while true do
		local progress = math.min((os.clock() - startedAt) / config.FallTime, 1)
		chest:PivotTo(skyCFrame:Lerp(landedCFrame, progress * progress))
		if progress >= 1 then break end
		RunService.Heartbeat:Wait()
	end

	puffDust(groundPosition)
	TweenService:Create(pillar, TweenInfo.new(config.PillarFadeTime), { Transparency = 1 }):Play()
	Debris:AddItem(pillar, config.PillarFadeTime)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = TreasureChests.PROMPT_NAME
	prompt.ActionText = "Open"
	prompt.ObjectText = tier.Name .. " Chest"
	prompt.KeyboardKeyCode = config.PromptKey
	prompt.GamepadKeyCode = config.PromptGamepadKey
	prompt.MaxActivationDistance = config.PromptDistance
	prompt.HoldDuration = config.PromptHoldDuration
	prompt.RequiresLineOfSight = false
	prompt.Parent = chest.PrimaryPart
end

-- 50 m の倍数の線を初めて超えたら、超えた線ごとに1つ宝箱を落とす（いきなり120 m なら50 m の箱と100 m の箱）。
-- 同じ線では1回しか出さない（50 m でもらったら、次は100 m を超えたとき）。
-- landDelay は相手が着地するまでの秒数。飛距離の数字が止まってから落とし始める
function TreasureChests.dropForDistance(player, distance, landDelay)
	local lines = ChestLoot.getNewLines(distance, player:GetAttribute("ChestLineReached") or 0)
	if #lines == 0 then return end
	-- 落とす前に書いておく（落ちてくるまでの間に続けて当てても、同じ線で2回出さないように）
	player:SetAttribute("ChestLineReached", lines[#lines])
	-- 叩いた人の周りに、向きを均等にずらして散らす（向きを箱ごとにばらばらに決めると、重なって落ちることがあった）。
	-- 少ないときも間を空けるため、5つ以下なら72°ずつにする
	local baseAngle = math.random() * 2 * math.pi
	local spacing = 2 * math.pi / math.max(#lines, 5)
	task.delay(landDelay + config.DropDelay, function()
		for index, line in ipairs(lines) do
			if not player.Parent then return end -- 待っている間にゲームを抜けた
			task.spawn(dropChest, player, ChestLoot.getTierIndex(line), baseAngle + index * spacing)
			task.wait(config.Interval)
		end
	end)
end

-- 本人が開けたら、ふたを開いて武器を引き、持っていなければ渡す。少し置いて宝箱を消す
function TreasureChests.open(player, chest)
	if chest:GetAttribute("OwnerUserId") ~= player.UserId or chest:GetAttribute("Opened") then return end
	chest:SetAttribute("Opened", true)
	local prompt = chest.PrimaryPart:FindFirstChild(TreasureChests.PROMPT_NAME)
	if prompt then prompt:Destroy() end

	local weapon = ChestLoot.roll(config.Tiers[chest:GetAttribute("Tier")])
	local isNew = weapon ~= nil and WeaponInventory.grant(player, weapon.Id)

	-- ふたを開ける（勢いよく開いて、最後はゆっくり止まる）
	local startedAt = os.clock()
	while true do
		local progress = math.min((os.clock() - startedAt) / config.LidOpenTime, 1)
		ChestBuilder.setLidAngle(chest, config.LidOpenAngle * (1 - (1 - progress) ^ 3))
		if progress >= 1 then break end
		RunService.Heartbeat:Wait()
	end

	-- ふたが開ききってから見せる
	if weapon then
		chestOpenedEvent:FireClient(player, weapon.Id, isNew)
	end
	Debris:AddItem(chest, config.RemoveDelay)
end

-- ゲームを抜けたプレイヤーの宝箱を片付ける（ほかの人は開けられないため）
function TreasureChests.removeOwnedBy(player)
	local folder = getFolder()
	if not folder then return end
	for _, chest in ipairs(folder:GetChildren()) do
		if chest:GetAttribute("OwnerUserId") == player.UserId then
			chest:Destroy()
		end
	end
end

return TreasureChests

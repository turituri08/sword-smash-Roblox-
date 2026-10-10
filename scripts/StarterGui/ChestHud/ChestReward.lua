-- Studio配置: StarterGui > ChestHud (ScreenGui) > ChestReward（LocalScript）
-- 役割: 宝箱のプレイヤー側の演出と表示。
--       ・自分の宝箱が落ちてくるとき（Remotes.ChestDropped）、画面を一瞬明るくして空が光ったように見せ、着地でカメラを揺らす
--       ・自分の宝箱を開けたとき（Remotes.ChestOpened）、当たった武器の名前とレア度を画面の上のほうに出す。初めてなら NEW! を添える
--       ・ほかの人の宝箱は開けられないので、開けるボタン（ProximityPrompt）をこの画面では出さない
--       UIの部品はgitの写しだけで中身が分かるよう、Studioで配置せずここで組み立てる。
-- ChestHud は ResetOnSpawn = false にしておく（リスポーンのたびに作り直されないように）

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local screenGui = script.Parent
local config = CombatConfig.Chests

local SHAKE_BINDING = "ChestLandShake"
local PROMPT_NAME = "OpenChestPrompt" -- TreasureChests.PROMPT_NAME と同じ（サーバーのモジュールはプレイヤー側から読めない）

-- ほかの人の宝箱の開けるボタンを消す（Enabled をこの画面でだけ切る）。
-- 部品は近づいたときに届くことがある（StreamingEnabled）ので、後から届いた分も見る
local function hideOthersPrompt(instance)
	if not instance:IsA("ProximityPrompt") or instance.Name ~= PROMPT_NAME then return end
	local chest = instance:FindFirstAncestor("TreasureChest")
	if chest and chest:GetAttribute("OwnerUserId") ~= player.UserId then
		instance.Enabled = false
	end
end

local chestFolder = workspace:WaitForChild("TreasureChests")
chestFolder.DescendantAdded:Connect(hideOthersPrompt)
for _, descendant in ipairs(chestFolder:GetDescendants()) do
	hideOthersPrompt(descendant)
end

-- 空が光る: 画面全体を一瞬明るくして戻す
local flash = Instance.new("ColorCorrectionEffect")
flash.Name = "ChestSkyFlash"
flash.Brightness = 0
flash.Parent = Lighting

local function flashSky()
	flash.Brightness = config.SkyFlash
	TweenService:Create(flash, TweenInfo.new(config.SkyFlashTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
end

-- 着地の揺れ: 標準のカメラ処理が毎フレームカメラを置き直した直後に傾ける（傾きが積み重ならない）
local function shakeCamera()
	local startedAt = os.clock()
	RunService:UnbindFromRenderStep(SHAKE_BINDING) -- 前の揺れが残っていれば置き換える
	RunService:BindToRenderStep(SHAKE_BINDING, Enum.RenderPriority.Camera.Value + 1, function()
		local elapsed = os.clock() - startedAt
		if elapsed >= config.LandShakeTime then
			RunService:UnbindFromRenderStep(SHAKE_BINDING)
			return
		end
		local strength = config.LandShakeAngle * (1 - elapsed / config.LandShakeTime)
		local pitch = strength * math.sin(elapsed * 40)
		local camera = workspace.CurrentCamera
		camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(pitch), 0, 0)
	end)
end

remotes:WaitForChild("ChestDropped").OnClientEvent:Connect(function(_, landDelay)
	flashSky()
	task.delay(landDelay, shakeCamera)
end)

-- 当たったものの表示。新しく開けたら前の表示と入れ替える
local currentReward = nil

local function createLabel(parent, text, textSize, color, position)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Size = UDim2.fromOffset(400, textSize + 8)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = color
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
	label.Parent = parent
	return label
end

local function showReward(weaponId, isNew)
	local weapon = Weapons.get(weaponId)
	if not weapon then return end
	local rarity = Weapons.getRarity(weapon.Rarity)

	if currentReward then currentReward:Destroy() end
	local frame = Instance.new("Frame")
	frame.Name = "Reward"
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.3)
	frame.Size = UDim2.fromOffset(400, 120)
	frame.Parent = screenGui
	currentReward = frame

	createLabel(frame, rarity.Name, 24, rarity.Color, UDim2.new(0.5, 0, 0, 16))
	createLabel(frame, weapon.Name .. " " .. weapon.Template, 48, Color3.new(1, 1, 1), UDim2.new(0.5, 0, 0, 62))
	if isNew then
		local newLabel = createLabel(frame, "NEW!", 30, config.NewColor, UDim2.new(1, -40, 0, 26))
		newLabel.Rotation = 12
	end

	-- ポンと大きくなって出る（大きな文字なので、拡大してもカクつきは目立たない）
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = frame
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	task.delay(config.RewardShowTime, function()
		if currentReward ~= frame then return end
		local fade = TweenInfo.new(0.3)
		for _, descendant in ipairs(frame:GetDescendants()) do
			if descendant:IsA("TextLabel") then
				TweenService:Create(descendant, fade, { TextTransparency = 1 }):Play()
			elseif descendant:IsA("UIStroke") then
				TweenService:Create(descendant, fade, { Transparency = 1 }):Play()
			end
		end
		task.wait(0.3)
		frame:Destroy()
		if currentReward == frame then currentReward = nil end
	end)
end

remotes:WaitForChild("ChestOpened").OnClientEvent:Connect(showReward)

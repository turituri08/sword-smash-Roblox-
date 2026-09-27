-- Studio配置: StarterGui > DistanceHud (ScreenGui) > TargetCamera（LocalScript）
-- 役割: 左下の小画面に、飛ばした対象を後ろの右斜め上から追いかけて映す。数字（DistanceDisplay）と同じ間だけ表示する。
-- Robloxではゲーム画面を別のカメラで映した小画面を直接置けないため、ViewportFrame を使う。
-- ViewportFrame は中に入れた物体しか描かないので、背景と対象を複製して入れる
-- （Terrain・パーティクル・照明の演出は映らない）。

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatConfig"))
local distanceResultEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DistanceResult")

local screenGui = script.Parent
local displayConfig = CombatConfig.DistanceDisplay
local cameraConfig = displayConfig.TargetCamera

-- 左下の小画面。高さは幅から16:9で決まる
local viewport = Instance.new("ViewportFrame")
viewport.Name = "TargetView" -- スクリプト名（TargetCamera）と被らない名前にする
viewport.AnchorPoint = Vector2.new(0, 1)
viewport.Position = UDim2.new(0, 16, 1, -16)
viewport.Size = UDim2.fromScale(cameraConfig.WidthScale, 1)
viewport.BackgroundColor3 = Color3.fromRGB(150, 200, 255) -- 空の代わり
viewport.Ambient = Color3.fromRGB(160, 160, 160)
viewport.LightColor = Color3.new(1, 1, 1)
viewport.LightDirection = Vector3.new(-1, -2, -1)
viewport.Visible = false
viewport.Parent = screenGui

local aspect = Instance.new("UIAspectRatioConstraint")
aspect.AspectRatio = 16 / 9
aspect.Parent = viewport
Instance.new("UICorner").Parent = viewport
local stroke = Instance.new("UIStroke")
stroke.Thickness = 3
stroke.Color = Color3.new(1, 1, 1)
stroke.Parent = viewport

local camera = Instance.new("Camera")
camera.FieldOfView = cameraConfig.FieldOfView
camera.Parent = viewport
viewport.CurrentCamera = camera

-- Clone は Archivable が false の物を複製しない（プレイヤーのキャラクターは false）ため、一時的に true にする
local function cloneInstance(instance)
	local archivable = instance.Archivable
	instance.Archivable = true
	local copy = instance:Clone()
	instance.Archivable = archivable
	return copy
end

local function isInsideCharacter(instance)
	local model = instance:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then return true end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return false
end

-- 動かない部品（Baseplate など）は届いた時に1回だけ複製する。毎フレーム位置を写すのは対象だけで済む。
-- StreamingEnabled がオンだと部品はプレイヤー側へ少しずつ届き、離れると外されるため、
-- 開始時の1回だけでなく、届いた・外された時にも小画面の中を合わせる
local backgroundCopies = {} -- 本物の部品 → 小画面の中の複製

local function addBackgroundPart(part)
	if backgroundCopies[part] then return end
	if not part:IsA("BasePart") or not part.Anchored or part:IsA("Terrain") or isInsideCharacter(part) then return end

	local copy = cloneInstance(part)
	-- 子の部品はそれぞれ別に複製されるので、二重にならないよう外す
	for _, child in ipairs(copy:GetChildren()) do
		if child:IsA("BasePart") or child:IsA("LuaSourceContainer") then
			child:Destroy()
		end
	end
	copy.Parent = viewport
	backgroundCopies[part] = copy
end

local function removeBackgroundPart(part)
	local copy = backgroundCopies[part]
	if copy then
		copy:Destroy()
		backgroundCopies[part] = nil
	end
end

-- 対象を複製し、本物と複製の部位を対にしておく（毎フレームこの対で位置を写す）。
-- 対応は「対象から見た名前の道筋」で探す（Archivable が false の物は複製されず、並び順では対応が崩れるため）
local function copyTarget(target)
	local copy = cloneInstance(target)
	local partPairs = {}
	for _, realPart in ipairs(target:GetDescendants()) do
		if realPart:IsA("BasePart") then
			local names = {}
			local current = realPart
			while current ~= target do
				table.insert(names, 1, current.Name)
				current = current.Parent
			end
			local copyPart = copy
			for _, name in ipairs(names) do
				copyPart = copyPart and copyPart:FindFirstChild(name)
			end
			if copyPart then
				copyPart.Anchored = true
				partPairs[realPart] = copyPart
			end
		end
	end
	for _, descendant in ipairs(copy:GetDescendants()) do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	return copy, partPairs
end

local targetCopy = nil
local followConnection = nil
-- 表示中に次の打撃が来たら、古い表示を消す予約を打ち切るための番号
local currentShowId = 0

local function stopFollowing()
	if followConnection then
		followConnection:Disconnect()
		followConnection = nil
	end
	if targetCopy then
		targetCopy:Destroy()
		targetCopy = nil
	end
	viewport.Visible = false
end

-- direction は飛ばした水平の向き。カメラは対象の後ろ・右・上にずらして置き、奥へ飛んでいく姿を追う
local function follow(target, direction)
	local rootPart = target:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local partPairs
	targetCopy, partPairs = copyTarget(target)
	targetCopy.Parent = viewport
	viewport.Visible = true

	local right = direction:Cross(Vector3.yAxis) -- 飛ぶ向きに対して右
	local cameraOffset = -direction * cameraConfig.BackDistance
		+ right * cameraConfig.SideDistance
		+ Vector3.new(0, cameraConfig.Height, 0)
	followConnection = RunService.RenderStepped:Connect(function()
		if not rootPart.Parent then return end -- 対象が消えた（リスポーンなど）ら最後の姿のまま止める
		for realPart, copyPart in pairs(partPairs) do
			copyPart.CFrame = realPart.CFrame
		end
		camera.CFrame = CFrame.lookAt(rootPart.Position + cameraOffset, rootPart.Position)
	end)
end

distanceResultEvent.OnClientEvent:Connect(function(_distance, flightTime, _isNewBest, target, direction)
	if not target or not direction then return end
	currentShowId += 1
	local showId = currentShowId

	stopFollowing()
	follow(target, direction)

	-- 数字の表示（滞空時間＋止まってからの表示時間）と同じだけ映してから消す
	task.delay(flightTime + displayConfig.ResultHoldTime, function()
		if showId == currentShowId then
			stopFollowing()
		end
	end)
end)

workspace.DescendantAdded:Connect(addBackgroundPart)
workspace.DescendantRemoving:Connect(removeBackgroundPart)
for _, part in ipairs(workspace:GetDescendants()) do
	addBackgroundPart(part)
end

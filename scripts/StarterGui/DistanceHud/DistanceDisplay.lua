-- Studio配置: StarterGui > DistanceHud (ScreenGui) > DistanceDisplay（LocalScript）
-- 役割: 叩いたときの飛距離と、ベスト記録を画面に表示する。
--       飛距離はサーバーが叩いた瞬間に計算して送ってくる。ここでは受け取った値を見せるだけ。
--       UIの部品はgitの写しだけで中身が分かるよう、Studioで配置せずここで組み立てる。
-- DistanceHud は ResetOnSpawn = false にしておく（リスポーンのたびに作り直されないように）

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CombatConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatConfig"))
local distanceResultEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DistanceResult")

local player = Players.LocalPlayer
local screenGui = script.Parent
local displayConfig = CombatConfig.DistanceDisplay

local function formatDistance(distance)
	return string.format("%.1f %s", distance, displayConfig.Unit)
end

local function createLabel(properties)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	for key, value in pairs(properties) do
		label[key] = value
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
	label.Parent = screenGui
	return label
end

-- 画面上部の中央に出す大きな数字。右上のBESTより少し上になるよう、上へ20ピクセルずらす
local distanceLabel = createLabel({
	Name = "Distance",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, -20),
	Size = UDim2.fromScale(0.5, 0.15),
	Visible = false,
})
-- 数字が止まった瞬間に一瞬大きくするための拡大率
local distanceScale = Instance.new("UIScale")
distanceScale.Parent = distanceLabel

local newRecordLabel = createLabel({
	Name = "NewRecord",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.15, -20), -- 数字のすぐ下
	Size = UDim2.fromScale(0.3, 0.06),
	Text = "NEW RECORD!",
	TextColor3 = Color3.fromRGB(255, 210, 60),
	Visible = false,
})

-- 右上に常に出すベスト記録
local bestLabel = createLabel({
	Name = "Best",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 16),
	Size = UDim2.fromScale(0.2, 0.05),
	TextXAlignment = Enum.TextXAlignment.Right,
})

local function updateBest()
	bestLabel.Text = "BEST " .. formatDistance(player:GetAttribute("BestDistance") or 0)
end
player:GetAttributeChangedSignal("BestDistance"):Connect(updateBest)
updateBest()

-- 表示中に次の打撃が来たら、古い表示の続き（数字の増加や消去）を打ち切るための番号
local currentShowId = 0

-- 0から計算値まで、滞空時間をかけて一定の速さで増やす。
-- 水平方向の移動は時間に比例するので、一定の速さにすると飛んでいる体の位置と数字が合う
local function showDistance(distance, flightTime, isNewBest)
	currentShowId += 1
	local showId = currentShowId

	distanceLabel.Text = formatDistance(0)
	distanceLabel.Visible = true
	distanceScale.Scale = 1
	newRecordLabel.Visible = false

	local elapsed = 0
	while elapsed < flightTime do
		elapsed += RunService.RenderStepped:Wait()
		if showId ~= currentShowId then return end
		distanceLabel.Text = formatDistance(distance * math.min(elapsed / flightTime, 1))
	end

	-- 着地（計算上）：計算値ぴったりで止めて、一瞬大きくする
	distanceLabel.Text = formatDistance(distance)
	distanceScale.Scale = 1.3
	TweenService:Create(distanceScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	newRecordLabel.Visible = isNewBest

	task.wait(displayConfig.ResultHoldTime)
	if showId ~= currentShowId then return end
	distanceLabel.Visible = false
	newRecordLabel.Visible = false
end

distanceResultEvent.OnClientEvent:Connect(showDistance)

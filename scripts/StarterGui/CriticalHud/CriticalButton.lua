-- Studio配置: StarterGui > CriticalHud (ScreenGui) > CriticalButton（LocalScript）
-- 役割: 会心の一撃のゲージと発動ボタンを、画面の右下に出す。丸いボタンの周りの目盛りが、当てた回数で1つずつ光る。
--       満タンになったら、L1（コントローラー）・E（キーボード）・ボタンのタップ（スマホ・タブレット）でサーバーに発動を頼む。
--       ゲージの数と発動中かどうかは、サーバーが書くプレイヤーの属性（CriticalCharge・CriticalActive）を読んで表示するだけ。
--       UIの部品はgitの写しだけで中身が分かるよう、Studioで配置せずここで組み立てる。
-- CriticalHud は ResetOnSpawn = false にしておく（リスポーンのたびに作り直されないように）

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local CombatConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatConfig"))
local activateEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CriticalActivate")

local player = Players.LocalPlayer
local screenGui = script.Parent
local critical = CombatConfig.Critical
local buttonConfig = critical.Button

local button = Instance.new("TextButton")
button.Name = "ActivateButton" -- このスクリプト（CriticalButton）と同じ名前にすると、探すときに取り違える
button.AnchorPoint = Vector2.new(1, 1)
button.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
button.BackgroundTransparency = 0.3
button.AutoButtonColor = false
button.Text = ""
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.5, 0) -- 丸くする
corner.Parent = button
local border = Instance.new("UIStroke")
border.Color = buttonConfig.FilledColor
border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
border.Parent = button
button.Parent = screenGui

local function createLabel(properties)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	for key, value in pairs(properties) do
		label[key] = value
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	label.Parent = button
	return label
end

-- 文字を収める枠の大きさ（ボタンの直径に対する割合）。押すボタン名は、下地の丸の上下に余白を取るぶん文字の高さを小さくする
local STATUS_TEXT_AREA = Vector2.new(0.6, 0.3)
local KEY_TEXT_AREA = Vector2.new(0.42, 0.3)
local KEY_PADDING = 0.15 -- 押すボタン名の下地の丸の、上下の余白（下地の高さに対する割合）

-- 真ん中の文字（溜めている間は「3/10」、満タンで「READY」、発動中は「ON!」）
local statusLabel = createLabel({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(STATUS_TEXT_AREA.X, STATUS_TEXT_AREA.Y),
})

-- 押すボタン名（L1 / E）。スマホ・タブレットではボタンそのものを押すので出さない。
-- ボタンの左上の角に、暗い丸の下地を付けて目盛りより手前に出す（重なると目盛りに隠れて読めなかった）
local keyLabel = createLabel({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.1, 0.1),
	Size = UDim2.fromScale(KEY_TEXT_AREA.X, KEY_TEXT_AREA.Y),
	TextColor3 = buttonConfig.FilledColor,
	BackgroundColor3 = Color3.fromRGB(20, 20, 20),
	BackgroundTransparency = 0,
	ZIndex = 2,
})
local keyCorner = Instance.new("UICorner")
keyCorner.CornerRadius = UDim.new(0.5, 0)
keyCorner.Parent = keyLabel
local keyPadding = Instance.new("UIPadding") -- 文字を下地の丸の内側に収める
keyPadding.PaddingTop = UDim.new(KEY_PADDING, 0)
keyPadding.PaddingBottom = UDim.new(KEY_PADDING, 0)
keyPadding.Parent = keyLabel

-- 今のボタンの直径（ピクセル）。入力に合わせて layout で変える
local buttonDiameter = buttonConfig.Size

-- 文字の大きさを、枠に収まる一番大きな整数に決める（ボタンの大きさや文字が変わったときに呼ぶ）
local function fitText(label, area, verticalPadding)
	local maxWidth = buttonDiameter * area.X
	local maxHeight = buttonDiameter * area.Y * (1 - 2 * verticalPadding)
	local size = math.max(math.floor(maxHeight), 1)
	while size > 1 do
		local bounds = TextService:GetTextSize(label.Text, size, label.Font, Vector2.new(10000, 10000))
		if bounds.X <= maxWidth and bounds.Y <= maxHeight then break end
		size -= 1
	end
	label.TextSize = size
end

local function fitAllText()
	fitText(statusLabel, STATUS_TEXT_AREA, 0)
	fitText(keyLabel, KEY_TEXT_AREA, KEY_PADDING)
end

-- 周りの目盛り。上から時計回りに MaxCharge 個並べ、当てた回数だけ光らせる
local dots = {}
for index = 1, critical.MaxCharge do
	local angle = (index - 1) / critical.MaxCharge * 2 * math.pi
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5 + 0.38 * math.sin(angle), 0.5 - 0.38 * math.cos(angle))
	dot.Size = UDim2.fromScale(0.13, 0.13)
	dot.BorderSizePixel = 0
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(0.5, 0)
	dotCorner.Parent = dot
	dot.Parent = button
	table.insert(dots, dot)
end

local function getCharge()
	return player:GetAttribute("CriticalCharge") or 0
end

local function isActive()
	return player:GetAttribute("CriticalActive") == true
end

local function isReady()
	return not isActive() and getCharge() >= critical.MaxCharge
end

local function refresh()
	local charge = getCharge()
	local active = isActive()
	for index, dot in ipairs(dots) do
		dot.BackgroundColor3 = if active or index <= charge then buttonConfig.FilledColor else buttonConfig.EmptyColor
	end
	statusLabel.Text = if active then "ON!" elseif isReady() then "READY" else string.format("%d/%d", charge, critical.MaxCharge)
	fitText(statusLabel, STATUS_TEXT_AREA, 0)
	statusLabel.TextColor3 = if active or isReady() then buttonConfig.FilledColor else Color3.new(1, 1, 1)
	-- 満タンの明滅（下の RenderStepped）で変えた色を、満タンでなくなったら戻す
	keyLabel.TextColor3 = buttonConfig.FilledColor
	border.Color = buttonConfig.FilledColor
	border.Thickness = if active or isReady() then 3 else 1
	border.Transparency = if active or isReady() then 0 else 0.6
end
player:GetAttributeChangedSignal("CriticalCharge"):Connect(refresh)
player:GetAttributeChangedSignal("CriticalActive"):Connect(refresh)
refresh()

-- 満タンの間、READY と押すボタン名の文字、ボタンの縁を、金色から白っぽい金色へゆっくり明滅させて「押せる」ことを知らせる。
-- 大きさを伸び縮みさせる形は、文字が整数の大きさでしか描かれないため、小さな文字が1ピクセル刻みでカクカク動いた。
-- 色の変化なら途切れずになめらかに動く
RunService.RenderStepped:Connect(function()
	if not isReady() then return end
	local glow = (1 - math.cos(os.clock() * 2 * math.pi / buttonConfig.ReadyPulseTime)) / 2 -- 0〜1をなめらかに往復する
	local color = buttonConfig.FilledColor:Lerp(buttonConfig.ReadyGlowColor, glow)
	statusLabel.TextColor3 = color
	keyLabel.TextColor3 = color
	border.Color = color
end)

-- 満タンのときだけ発動を頼む（発動してよいかはサーバーがもう一度確かめる）
local function tryActivate()
	if not isReady() then return false end
	activateEvent:FireServer()
	return true
end

button.Activated:Connect(tryActivate)
-- L1 は左の人差し指なので、R2 で溜めながらでも押せる
ContextActionService:BindAction("ActivateCritical", function(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	return if tryActivate() then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.ButtonL1, Enum.KeyCode.E)

-- 最後に使った入力に合わせて、ボタンの位置と押すボタン名を変える
local function isGamepad(inputType)
	return inputType.Name:match("^Gamepad") ~= nil
end

local function layout(inputType)
	if inputType == Enum.UserInputType.Touch then
		-- スマホ・タブレット: 右下のジャンプボタンの真上に、ジャンプボタンの TouchScale 倍の大きさで、右端をそろえて置く
		-- （ジャンプボタンの位置は Roblox 標準の配置に合わせた値）
		local viewport = workspace.CurrentCamera.ViewportSize -- ScreenGui の大きさは、出たばかりだとまだ0のことがある
		local isSmallScreen = math.min(viewport.X, viewport.Y) <= 500
		local jumpSize = if isSmallScreen then 70 else 120
		local rightInset = if isSmallScreen then 25 else 50 -- ジャンプボタンの右端の、画面の右端からの距離
		local jumpTop = if isSmallScreen then 90 else 210 -- ジャンプボタンの上端の、画面の下端からの距離
		buttonDiameter = math.round(jumpSize * buttonConfig.TouchScale)
		button.Position = UDim2.new(1, -rightInset, 1, -(jumpTop + buttonConfig.TouchGap))
		keyLabel.Visible = false
	else
		buttonDiameter = buttonConfig.Size
		button.Position = UDim2.new(1, -buttonConfig.Margin, 1, -buttonConfig.Margin)
		keyLabel.Visible = true
		keyLabel.Text = if isGamepad(inputType) then "L1" else "E"
	end
	button.Size = UDim2.fromOffset(buttonDiameter, buttonDiameter)
	fitAllText()
end

local function onInputTypeChanged(inputType)
	-- ボタン名と配置に関係する入力（タッチ・コントローラー・キーを押す・マウスのボタンを押す）だけ見る。
	-- マウスを動かしただけで切り替えると、コントローラーで遊んでいても、画面の上でマウスが少し動いただけで E に変わってしまう
	if inputType == Enum.UserInputType.Touch or isGamepad(inputType)
		or inputType == Enum.UserInputType.Keyboard or inputType.Name:match("^MouseButton") then
		layout(inputType)
	end
end

UserInputService.LastInputTypeChanged:Connect(onInputTypeChanged)
local initialInput = UserInputService:GetLastInputType()
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	initialInput = Enum.UserInputType.Touch
end
layout(if initialInput == Enum.UserInputType.None then Enum.UserInputType.Keyboard else initialInput)

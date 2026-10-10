-- Studio配置: StarterGui > SprintHud (ScreenGui) > SprintButton（LocalScript）
-- 役割: 走る操作を受けて、サーバーに走る／歩くの合図（Remotes.SprintInput）を送る。歩く速さを変えるのはサーバー（MovementSpeed）。
--       キーボードは左 Ctrl を押している間だけ走る（Minecraft と同じキー。Shift は Roblox 標準のシフトロックと重なる）。
--       コントローラーは L3、スマホ・タブレットは画面のボタンで、押すたびに走る／歩くを切り替える
--       （スティックを押し込み続けるのは指が疲れ、画面のボタンを押し続けると右手の親指がふさがって振れないため）。
--       走れるのは、サーバーがプレイヤーの属性 CanSprint を付けているとき（シングルプレイ）だけ。
--       UIの部品はgitの写しだけで中身が分かるよう、Studioで配置せずここで組み立てる。
-- SprintHud は ResetOnSpawn = false にしておく（リスポーンのたびに作り直されないように）

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local CombatConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatConfig"))
local sprintEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SprintInput")

local player = Players.LocalPlayer
local screenGui = script.Parent
local buttonConfig = CombatConfig.Sprint.Button

-- スマホ・タブレットの走るボタン。走っている間は色を変える
local button = Instance.new("TextButton")
button.Name = "RunButton" -- このスクリプト（SprintButton）と同じ名前にすると、探すときに取り違える
button.AnchorPoint = Vector2.new(1, 0.5)
button.BackgroundColor3 = buttonConfig.IdleColor
button.BackgroundTransparency = 0.3
button.AutoButtonColor = false
button.Font = Enum.Font.FredokaOne
button.Text = "RUN"
button.TextColor3 = Color3.new(1, 1, 1)
button.TextScaled = true
button.Visible = false
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.5, 0) -- 丸くする
corner.Parent = button
local border = Instance.new("UIStroke")
border.Color = Color3.new(1, 1, 1)
border.Transparency = 0.4
border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
border.Parent = button
local padding = Instance.new("UIPadding") -- 文字を丸の内側に収める
padding.PaddingTop = UDim.new(0.3, 0)
padding.PaddingBottom = UDim.new(0.3, 0)
padding.PaddingLeft = UDim.new(0.15, 0)
padding.PaddingRight = UDim.new(0.15, 0)
padding.Parent = button
button.Parent = screenGui

local isSprinting = false

local function canSprint()
	return player:GetAttribute("CanSprint") == true
end

local function setSprinting(value)
	if value == isSprinting then return end
	isSprinting = value
	button.BackgroundColor3 = if value then buttonConfig.ActiveColor else buttonConfig.IdleColor
	sprintEvent:FireServer(value)
end

-- リスポーンすると、サーバー側では歩きに戻っている（走っているかは古いキャラクターの属性だったため）。こちらも合わせる
player.CharacterAdded:Connect(function()
	isSprinting = false
	button.BackgroundColor3 = buttonConfig.IdleColor
end)

ContextActionService:BindAction("Sprint", function(_, inputState, input)
	if not canSprint() then return Enum.ContextActionResult.Pass end
	if input.KeyCode == Enum.KeyCode.LeftControl then
		-- 押している間だけ走る。離したとき（End）や、ウィンドウの切り替えなどで押した状態が取り消されたとき（Cancel）は歩きに戻す
		setSprinting(inputState == Enum.UserInputState.Begin)
	elseif inputState == Enum.UserInputState.Begin then
		setSprinting(not isSprinting)
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonL3)

button.Activated:Connect(function()
	if canSprint() then
		setSprinting(not isSprinting)
	end
end)

-- 右下のジャンプボタンの左隣に、上下の真ん中をそろえて置く
-- （ジャンプボタンの位置は Roblox 標準の配置に合わせた値。CriticalButton と同じ）
local function layout()
	local viewport = workspace.CurrentCamera.ViewportSize -- ScreenGui の大きさは、出たばかりだとまだ0のことがある
	local isSmallScreen = math.min(viewport.X, viewport.Y) <= 500
	local jumpSize = if isSmallScreen then 70 else 120
	local rightInset = if isSmallScreen then 25 else 50 -- ジャンプボタンの右端の、画面の右端からの距離
	local jumpTop = if isSmallScreen then 90 else 210 -- ジャンプボタンの上端の、画面の下端からの距離
	local size = math.round(jumpSize * buttonConfig.TouchScale)
	button.Size = UDim2.fromOffset(size, size)
	button.Position = UDim2.new(1, -(rightInset + jumpSize + buttonConfig.TouchGap), 1, -(jumpTop - jumpSize / 2))
end

-- ボタンは、スマホ・タブレットで遊んでいて、走れるときだけ出す
local usingTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function refreshVisible()
	button.Visible = usingTouch and canSprint()
	if button.Visible then
		layout()
	end
end

UserInputService.LastInputTypeChanged:Connect(function(inputType)
	-- マウスを動かしただけでは切り替えない（CriticalButton と同じ理由）
	if inputType == Enum.UserInputType.Touch then
		usingTouch = true
	elseif inputType.Name:match("^Gamepad") or inputType == Enum.UserInputType.Keyboard or inputType.Name:match("^MouseButton") then
		usingTouch = false
	else
		return
	end
	refreshVisible()
end)
player:GetAttributeChangedSignal("CanSprint"):Connect(refreshVisible)
refreshVisible()

-- Studio配置: ReplicatedStorage > Shared > FinishCinematic（ModuleScript）
-- 役割: 虹で当てたときの決めの一瞬。当たってから飛ぶまで画面を暗くしてカメラを寄せ、集中線を出し、飛ぶ瞬間に白く光らせて元に戻す。
--       プレイヤー側でだけ使う（叩いた本人は Bat の LocalScript、叩かれた本人は HitEffectReceiver から呼ぶ）。
--       物理演算は遅くできないので、引っかかりを長くした時間（TimingGauge.HitFeedback.Rainbow）を、この演出でスローに見せる

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))

local FinishCinematic = {}

-- 演出中の状態はカメラの属性に持たせる（モジュールには状態を持たせない）。
-- 演出中にもう一度虹が出たとき、寄った視野ではなく演出前の視野に戻すため
local BASE_FOV_ATTRIBUTE = "CinematicBaseFieldOfView"
local COUNT_ATTRIBUTE = "CinematicCount"
local CORRECTION_NAME = "FinishCinematicCorrection"
local FOCUS_LINES_NAME = "FinishFocusLines"

local function tween(instance, duration, style, properties)
	local tweenObject = TweenService:Create(instance, TweenInfo.new(duration, style, Enum.EasingDirection.Out), properties)
	tweenObject:Play()
	return tweenObject
end

-- 飛ぶ瞬間の白い光。画面全体を白い板で覆い、透明にしながら消す
local function flash()
	local cinematic = CombatConfig.FinishCinematic
	local gui = Instance.new("ScreenGui")
	gui.Name = "FinishFlash"
	gui.IgnoreGuiInset = true -- 画面上部のバーの下まで覆う
	gui.DisplayOrder = 100    -- 飛距離の表示などより手前に出す
	gui.ResetOnSpawn = false

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = cinematic.FlashTransparency
	frame.BorderSizePixel = 0
	frame.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	tween(frame, cinematic.FlashTime, Enum.EasingStyle.Quad, { BackgroundTransparency = 1 }).Completed:Connect(function()
		gui:Destroy()
	end)
end

-- 画面の端から中心へ向かう集中線を duration 秒出す。数フレームごとに並べ直してチラつかせ、漫画の効果線のように見せる
local function showFocusLines(duration)
	local config = CombatConfig.FinishCinematic.FocusLines
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local previous = playerGui:FindFirstChild(FOCUS_LINES_NAME)
	if previous then
		previous:Destroy() -- 続けて虹が出たら、新しい集中線に置き換える
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = FOCUS_LINES_NAME
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 90 -- 白い光（100）より奥
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local lines = {}
	for _ = 1, config.Count do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BorderSizePixel = 0
		line.BackgroundColor3 = config.Color
		line.BackgroundTransparency = config.Transparency
		-- 線の左の端（回すと画面の中心側）を透明にして、中心へ向かって消えていく線にする
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new(1, 0)
		gradient.Parent = line
		line.Parent = gui
		table.insert(lines, line)
	end

	-- 線を1本ずつ、ランダムな向きに画面の端の外から内側の端まで置き直す。
	-- 大きさはピクセルで決めるので、画面の大きさ（スマホ・タブレットでも）に合わせて毎回計算する
	local function arrange()
		local viewport = gui.AbsoluteSize
		local halfDiagonal = viewport.Magnitude / 2
		for _, line in ipairs(lines) do
			local angle = math.random() * 2 * math.pi
			local inner = halfDiagonal * (config.InnerRadius[1] + math.random() * (config.InnerRadius[2] - config.InnerRadius[1]))
			local outer = halfDiagonal * 1.05 -- 画面の角まで届かせる
			local middle = (inner + outer) / 2
			local width = viewport.Y * (config.Width[1] + math.random() * (config.Width[2] - config.Width[1]))
			line.Position = UDim2.new(0.5, math.cos(angle) * middle, 0.5, math.sin(angle) * middle)
			line.Size = UDim2.fromOffset(outer - inner, width)
			line.Rotation = math.deg(angle) -- 線の右の端（不透明な側）が外を向く
		end
	end

	local startTime = os.clock()
	local lastArranged = -math.huge
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed >= duration or not gui.Parent then
			connection:Disconnect()
			gui:Destroy()
			return
		end
		if elapsed - lastArranged >= config.RefreshTime then
			lastArranged = elapsed
			arrange()
		end
	end)
end

-- launchDelay: 当たってから相手が飛ぶまでの秒数（ChargeStages.getLaunchDelay）
function FinishCinematic.play(launchDelay)
	local cinematic = CombatConfig.FinishCinematic
	local camera = workspace.CurrentCamera
	local baseFieldOfView = camera:GetAttribute(BASE_FOV_ATTRIBUTE) or camera.FieldOfView
	camera:SetAttribute(BASE_FOV_ATTRIBUTE, baseFieldOfView)
	local count = (camera:GetAttribute(COUNT_ATTRIBUTE) or 0) + 1
	camera:SetAttribute(COUNT_ATTRIBUTE, count)

	-- 色の補正は Camera の下に置くと、この画面にだけ効く
	local correction = camera:FindFirstChild(CORRECTION_NAME) or Instance.new("ColorCorrectionEffect")
	correction.Name = CORRECTION_NAME
	correction.Parent = camera
	tween(correction, cinematic.FadeInTime, Enum.EasingStyle.Quad, {
		Saturation = cinematic.Saturation,
		Brightness = cinematic.Brightness,
		Contrast = cinematic.Contrast,
		TintColor = cinematic.TintColor,
	})
	-- 当たった瞬間に大きく寄り、飛ぶまでじわじわ寄り続ける（最初が速く、だんだん遅くなる動き）
	tween(camera, launchDelay, Enum.EasingStyle.Quart, { FieldOfView = baseFieldOfView * cinematic.ZoomRatio })
	-- 集中線は飛ぶ瞬間（白く光る瞬間）に消す
	showFocusLines(launchDelay)

	task.delay(launchDelay, function()
		if camera:GetAttribute(COUNT_ATTRIBUTE) ~= count then return end -- 後から始まった決めの一瞬に任せる
		flash()
		-- 同じ値への新しい Tween は前の Tween を止めて置き換わるので、寄っている途中でもそこから戻る
		tween(correction, cinematic.RecoverTime, Enum.EasingStyle.Quad, {
			Saturation = 0,
			Brightness = 0,
			Contrast = 0,
			TintColor = Color3.new(1, 1, 1),
		})
		tween(camera, cinematic.RecoverTime, Enum.EasingStyle.Quad, { FieldOfView = baseFieldOfView })
		task.delay(cinematic.RecoverTime, function()
			if camera:GetAttribute(COUNT_ATTRIBUTE) ~= count then return end
			correction:Destroy()
			camera:SetAttribute(BASE_FOV_ATTRIBUTE, nil)
		end)
	end)
end

return FinishCinematic

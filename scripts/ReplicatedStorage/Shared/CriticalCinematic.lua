-- Studio配置: ReplicatedStorage > Shared > CriticalCinematic（ModuleScript）
-- 役割: 虹で当てたときの決めの一瞬。当たってから飛ぶまで画面を暗くしてカメラを寄せ、飛ぶ瞬間に白く光らせて元に戻す。
--       プレイヤー側でだけ使う（叩いた本人は Bat の LocalScript、叩かれた本人は HitEffectReceiver から呼ぶ）。
--       物理演算は遅くできないので、引っかかりを長くした時間（TimingGauge.HitFeedback.Rainbow）を、この演出でスローに見せる

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))

local CriticalCinematic = {}

-- 演出中の状態はカメラの属性に持たせる（モジュールには状態を持たせない）。
-- 演出中にもう一度虹が出たとき、寄った視野ではなく演出前の視野に戻すため
local BASE_FOV_ATTRIBUTE = "CinematicBaseFieldOfView"
local COUNT_ATTRIBUTE = "CinematicCount"
local CORRECTION_NAME = "CriticalCinematicCorrection"

local function tween(instance, duration, style, properties)
	local tweenObject = TweenService:Create(instance, TweenInfo.new(duration, style, Enum.EasingDirection.Out), properties)
	tweenObject:Play()
	return tweenObject
end

-- 飛ぶ瞬間の白い光。画面全体を白い板で覆い、透明にしながら消す
local function flash()
	local cinematic = CombatConfig.CriticalCinematic
	local gui = Instance.new("ScreenGui")
	gui.Name = "CriticalFlash"
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

-- launchDelay: 当たってから相手が飛ぶまでの秒数（ChargeStages.getLaunchDelay）
function CriticalCinematic.play(launchDelay)
	local cinematic = CombatConfig.CriticalCinematic
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

return CriticalCinematic

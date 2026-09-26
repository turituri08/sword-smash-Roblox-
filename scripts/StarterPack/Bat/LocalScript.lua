-- Studio配置: StarterPack > Bat (Tool) > LocalScript（プレイヤー側で実行される）
-- 役割: 溜めの構えと振りのアニメーション再生と、溜めの段階が上がったときのコントローラーの振動。
--       ボタンへの反応を遅らせないよう、サーバーを経由せずここで再生する
--       （自分のキャラクターのアニメーションは、プレイヤー側で再生しても他のプレイヤーに同期される）。
--       溜めの秒数や段階の判定はサーバー側のScriptが行い、ここでは見た目と手触りだけを扱う。

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HapticService = game:GetService("HapticService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))

local tool = script.Parent

local slashAnimation = Instance.new("Animation")
slashAnimation.AnimationId = CombatConfig.Swing.AnimationId

local chargeAnimation = Instance.new("Animation")
chargeAnimation.AnimationId = CombatConfig.Charge.AnimationId

local slashTrack = nil
local chargeTrack = nil
local stageConnection = nil

-- サーバー側と同じ条件（振り終わり＋クールダウン中は溜め始められない）を真似て、
-- 当たり判定の出ない空振りアニメーションが再生されないようにする
local isCharging = false
local nextChargeAllowedAt = 0

local function vibrate(strength)
	local gamepad, motor = Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large
	if not HapticService:IsMotorSupported(gamepad, motor) then return end
	HapticService:SetMotor(gamepad, motor, strength)
	task.delay(CombatConfig.ChargeEffects.VibrationDuration, function()
		HapticService:SetMotor(gamepad, motor, 0)
	end)
end

-- 装備するたびに読み込み直す（リスポーンでキャラクターが替わると、古いトラックは使えなくなるため）
tool.Equipped:Connect(function()
	local character = tool.Parent
	local animator = character:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")
	slashTrack = animator:LoadAnimation(slashAnimation)
	chargeTrack = animator:LoadAnimation(chargeAnimation)
	-- ツールを持つ腕の姿勢（標準の待機アニメーション）より優先して再生させる
	slashTrack.Priority = Enum.AnimationPriority.Action
	chargeTrack.Priority = Enum.AnimationPriority.Action

	-- サーバーが書く段階（ChargeStage属性）が上がったら振動させる。下がったとき（溜め終わり）は何もしない
	local previousStage = 0
	stageConnection = character:GetAttributeChangedSignal("ChargeStage"):Connect(function()
		local stage = character:GetAttribute("ChargeStage") or 0
		if stage > previousStage then
			local stageEffects = CombatConfig.ChargeEffects.Stages
			vibrate(stageEffects[math.min(stage, #stageEffects)].Vibration)
		end
		previousStage = stage
	end)
end)

tool.Unequipped:Connect(function()
	isCharging = false
	if chargeTrack then
		chargeTrack:Stop()
	end
	if stageConnection then
		stageConnection:Disconnect()
		stageConnection = nil
	end
end)

tool.Activated:Connect(function()
	if os.clock() < nextChargeAllowedAt then return end
	isCharging = true
	if chargeTrack then
		chargeTrack:Play(CombatConfig.Charge.AnimationFadeTime)
	end
end)

tool.Deactivated:Connect(function()
	if not isCharging or not slashTrack then return end
	isCharging = false
	nextChargeAllowedAt = os.clock() + CombatConfig.Swing.HitWindow + CombatConfig.Swing.Cooldown
	-- 構えを消す時間を振りのフェードインと同じにして、振りかぶりから振り下ろしへなめらかに切り替える
	local fadeTime = CombatConfig.Swing.FadeTime
	chargeTrack:Stop(fadeTime)
	slashTrack:Play(fadeTime, 1, CombatConfig.Swing.AnimationSpeed)
end)

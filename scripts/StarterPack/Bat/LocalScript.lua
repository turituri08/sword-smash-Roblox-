-- Studio配置: StarterPack > Bat (Tool) > LocalScript（プレイヤー側で実行される）
-- 役割: 溜めの構えと振りのアニメーション再生と、溜めの段階が上がったときのコントローラーの振動。
--       溜め切った後のタイミングゲージを出し、離したら経過秒数を付けてサーバーへ知らせる（Remotes.ChargeRelease）。
--       当たったときに振りをゆっくりにして、相手に引っかかる重さを出す。当たった瞬間のカメラの揺れと振動、当たった場所の星・衝撃波・火花、相手の震えもここで出す。
--       虹で当てたときは、決めの一瞬（CriticalCinematic）も出す。
--       ボタンへの反応を遅らせないよう、サーバーを経由せずここで再生する
--       （自分のキャラクターのアニメーションは、プレイヤー側で再生しても他のプレイヤーに同期される）。
--       溜めの秒数や段階、当たり・吹き飛ばしの判定はサーバー側のScriptが行い、ここでは見た目と手触りだけを扱う。

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HapticService = game:GetService("HapticService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local ChargeStages = require(Shared:WaitForChild("ChargeStages"))
local Knockback = require(Shared:WaitForChild("Knockback"))
local HitEffects = require(Shared:WaitForChild("HitEffects"))
local TargetShake = require(Shared:WaitForChild("TargetShake"))
local TimingGauge = require(Shared:WaitForChild("TimingGauge"))
local TimingGaugeDisplay = require(Shared:WaitForChild("TimingGaugeDisplay"))
local CriticalCinematic = require(Shared:WaitForChild("CriticalCinematic"))

local tool = script.Parent
local hitbox = tool:WaitForChild("Hitbox")
local chargeReleaseEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ChargeRelease")

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

-- タイミングゲージ。押した時刻からプレイヤー側で計る（サーバーから段階の知らせを待つと、通信の遅れのぶんゲージが遅れる）
local chargeStartedAt = 0
local gaugeBillboard = nil
local gaugeConnection = nil
-- 画面に最後に映したゲージの経過秒数。離したときはこの値で判定する。
-- 離した合図を受け取る時刻はその画面より1〜2フレーム遅く、幅の狭い虹ではそのぶんで外れてしまうため、見えていた位置で判定する
local displayedGaugeElapsed = nil

-- ゲージが出てからの秒数。まだ出ていない（最大段階に届いていない）ならnil
local function getGaugeElapsed()
	local elapsed = os.clock() - chargeStartedAt - TimingGauge.getStartTime()
	return if elapsed >= 0 then elapsed else nil
end

local function stopGauge()
	if gaugeConnection then
		gaugeConnection:Disconnect()
		gaugeConnection = nil
	end
	if gaugeBillboard then
		gaugeBillboard:Destroy()
		gaugeBillboard = nil
	end
end

-- 溜めている間、毎フレームゲージを動かす。最大段階に届いた時点でゲージを出す
local function startGauge()
	-- R2 をゆっくり押し込んだり連打したりすると、離した合図（Deactivated）が届かないまま、押した合図（Activated）が
	-- 続けて来ることがある。前のゲージを片付けずに始めると、前の毎フレームの処理が残り、離してもゲージが消えなくなる
	stopGauge()
	displayedGaugeElapsed = nil
	gaugeConnection = RunService.RenderStepped:Connect(function()
		-- 念のため、溜めていないのに動いていたら止める（ゲージが残り続けないようにする）
		if not isCharging then
			stopGauge()
			return
		end
		local elapsed = getGaugeElapsed()
		if not elapsed then return end
		if not gaugeBillboard then
			local rootPart = tool.Parent:FindFirstChild("HumanoidRootPart")
			if not rootPart then return end
			gaugeBillboard = TimingGaugeDisplay.create(rootPart, Players.LocalPlayer.PlayerGui)
		end
		TimingGaugeDisplay.setPosition(gaugeBillboard, TimingGauge.getPosition(elapsed))
		displayedGaugeElapsed = elapsed
	end)
end

-- 離した位置でゲージを少しの間止め、ポンと大きくして結果の色を見せてから消す（2K のシュートメーターのように、
-- どこで止めたか分かるようにして「もう少し早く」を伝える）。elapsed は判定に使った秒数（ゲージが出る前に離したならnil）。
-- 止めている間に次の溜めを始めたら、startGauge の stopGauge で片付く
local function freezeGauge(elapsed)
	if not elapsed or not gaugeBillboard then
		stopGauge()
		return
	end
	if gaugeConnection then
		gaugeConnection:Disconnect()
	end
	local billboard = gaugeBillboard
	local position = TimingGauge.getPosition(elapsed)
	local startedAt = os.clock()
	TimingGaugeDisplay.popResult(billboard)
	gaugeConnection = RunService.RenderStepped:Connect(function()
		if os.clock() - startedAt >= CombatConfig.TimingGauge.Display.ResultHoldTime then
			stopGauge()
			return
		end
		TimingGaugeDisplay.setPosition(billboard, position) -- 虹は止めている間も色を流す
	end)
end

-- 振動を止める予約が、後から始めた振動まで止めないように、何回目の振動かを数える
local vibrationCount = 0

local function vibrate(strength, duration)
	local gamepad, motor = Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large
	if not HapticService:IsMotorSupported(gamepad, motor) then return end
	vibrationCount += 1
	local thisVibration = vibrationCount
	HapticService:SetMotor(gamepad, motor, strength)
	task.delay(duration, function()
		if vibrationCount ~= thisVibration then return end
		HapticService:SetMotor(gamepad, motor, 0)
	end)
end

-- 揺れの強さ（1が最大）。decayTime 秒かけて0まで弱める。急に止まって見えないよう2乗で弱める
local function decay(elapsed, decayTime)
	if elapsed < 0 or elapsed >= decayTime then return 0 end
	local remaining = 1 - elapsed / decayTime
	return remaining * remaining
end

-- 叩いた人のカメラを揺らす。当たった瞬間に強く揺れ、引っかかりの間は弱く震え続け（押し込んでいる感じ）、
-- 相手が飛ぶ瞬間にもう一度揺れる（虹では大きく揺らす）。feedback は当たったときの手応えの値（ChargeStages.getHitFeedback）
local SHAKE_BINDING = "HitShake"
local function shakeCamera(feedback)
	local shake = CombatConfig.HitFeedback.Shake
	local angle = feedback.ShakeAngle
	local catchDuration = feedback.ImpactDuration
	local launchTime = ChargeStages.getLaunchDelay(feedback)
	local launchPulseRatio = feedback.LaunchPulseRatio or shake.LaunchPulseRatio
	local endTime = math.max(catchDuration, launchTime + shake.DecayTime)
	local startedAt = os.clock()

	RunService:UnbindFromRenderStep(SHAKE_BINDING) -- 前の揺れが残っていれば、新しい揺れに置き換える
	-- 標準のカメラ処理（Camera の優先度）が毎フレームカメラを置き直した直後に傾けるので、傾きが積み重ならない
	RunService:BindToRenderStep(SHAKE_BINDING, Enum.RenderPriority.Camera.Value + 1, function()
		local elapsed = os.clock() - startedAt
		if elapsed >= endTime then
			RunService:UnbindFromRenderStep(SHAKE_BINDING)
			return
		end
		local strength = decay(elapsed, shake.DecayTime)
		if elapsed < catchDuration then
			strength = math.max(strength, shake.TrembleRatio)
		end
		strength += launchPulseRatio * decay(elapsed - launchTime, shake.DecayTime)
		-- 振り下ろしに合わせて主に上下に揺らす。横は周期をずらして少しだけ揺らし、単調な往復に見えないようにする
		local phase = elapsed * shake.Frequency * 2 * math.pi
		local pitch = angle * strength * math.sin(phase)
		local yaw = angle * strength * shake.SideRatio * math.sin(phase * 1.3 + 1)
		local camera = workspace.CurrentCamera
		camera.CFrame *= CFrame.Angles(math.rad(pitch), math.rad(yaw), 0)
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
			vibrate(stageEffects[math.min(stage, #stageEffects)].Vibration, CombatConfig.ChargeEffects.VibrationDuration)
		end
		previousStage = stage
	end)
end)

tool.Unequipped:Connect(function()
	isCharging = false
	stopGauge()
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
	chargeStartedAt = os.clock()
	startGauge()
	if chargeTrack then
		chargeTrack:Play(CombatConfig.Charge.AnimationFadeTime)
	end
end)

-- 振ってから当たり判定が終わるまでの状態（サーバー側の当たり判定と同じ時間だけ有効）
local swingStage = 0
local swingGaugeResult = nil -- 自分で判定したタイミングゲージの結果（ゲージが出る前に離したならnil）
local canPredictHit = false
local hasPredictedHit = false

-- 当たった瞬間から duration 秒、振りをほぼ止まる速さにして引っかかりを作り、その後は振り抜く。
-- 止まりかけ→振り抜きの差で、相手の重さに引っかかってから打ち抜いた手応えを出す
local function catchSwing(duration)
	if duration <= 0 then return end -- 引っかかりのない段階（溜めなし）は減速しない
	slashTrack:AdjustSpeed(CombatConfig.Swing.CatchSpeed)
	task.delay(duration, function()
		slashTrack:AdjustSpeed(CombatConfig.Swing.FollowThroughSpeed)
	end)
end

-- サーバーの判定を待たず、プレイヤー側でも当たりを判定して振りを減速させる（通信の遅れで減速が遅れないように）。
-- 変わるのは自分の振りの見た目だけで、相手を飛ばすかどうかはサーバーが決める
local function predictHit(hitPart)
	if not canPredictHit or hasPredictedHit then return end
	local character = tool.Parent
	local target = hitPart.Parent
	if not target or target == character or not target:FindFirstChildOfClass("Humanoid") then return end
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	hasPredictedHit = true
	local feedback = ChargeStages.getHitFeedback(swingStage, swingGaugeResult)
	local duration = feedback.ImpactDuration
	local launchDelay = ChargeStages.getLaunchDelay(feedback)
	catchSwing(duration)
	-- 溜めなしの軽い当たりには、揺れ・振動・当たった場所の演出を出さない（溜めた一撃との差を出す）
	if swingStage > 0 then
		shakeCamera(feedback)
		local direction = Knockback.getDirection(character.HumanoidRootPart, targetRoot)
		HitEffects.play(HitEffects.getContactPoint(hitPart, hitbox.Position), direction, swingStage, swingGaugeResult)
		TargetShake.play(target, direction, swingStage, swingGaugeResult)
		-- 引っかかりの間ずっと振動させ、振り抜きと同時に止めて、重さが抜ける感じを出す
		vibrate(feedback.Vibration, duration)
	end
	if swingGaugeResult == "Rainbow" then
		CriticalCinematic.play(launchDelay)
	end
	-- サーバー側と同じく、押し込み中（相手が飛ぶまで）は次の溜めを始められない
	nextChargeAllowedAt = math.max(nextChargeAllowedAt, os.clock() + launchDelay + CombatConfig.Swing.Cooldown)
end

hitbox.Touched:Connect(predictHit)

tool.Deactivated:Connect(function()
	-- サーバーに振らせる。ゲージが出ていれば、画面に最後に映した時点の経過秒数を付ける（サーバーは溜めていなければ無視する）
	local gaugeElapsed = if isCharging then displayedGaugeElapsed else nil
	chargeReleaseEvent:FireServer(gaugeElapsed)
	freezeGauge(gaugeElapsed)

	if not isCharging or not slashTrack then return end
	isCharging = false
	-- 段階はサーバーが書く属性から読む（離した直後はまだ離した時点の段階が入っている）
	swingStage = tool.Parent:GetAttribute("ChargeStage") or 0
	-- 当たりの演出に使う結果。サーバーも同じ秒数で判定するので、ふつうは同じ結果になる
	-- （通信がとても遅いと、サーバーが秒数を補正して結果が変わり、見た目だけずれることがある）
	swingGaugeResult = if swingStage == ChargeStages.getMaxStage() and gaugeElapsed then TimingGauge.getResult(gaugeElapsed) else nil
	local hitStart, hitEnd = ChargeStages.getHitWindow(swingStage)
	nextChargeAllowedAt = os.clock() + hitEnd + CombatConfig.Swing.Cooldown

	-- 構えを消す時間を振りのフェードインと同じにして、振りかぶりから振り下ろしへなめらかに切り替える
	local fadeTime = CombatConfig.Swing.FadeTime
	chargeTrack:Stop(fadeTime)
	slashTrack:Play(fadeTime, 1, ChargeStages.getSwingSpeed(swingStage))

	-- サーバー側と同じく、振り下ろしが進んでから当たり判定を始め、その時点で既に重なっている相手も当たりにする
	hasPredictedHit = false
	task.delay(hitStart, function()
		canPredictHit = true
		for _, part in ipairs(workspace:GetPartsInPart(hitbox)) do
			predictHit(part)
		end
	end)
	task.delay(hitEnd, function()
		canPredictHit = false
		-- 溜めた振りが空振りした場合も、振り下ろした後は速く振り抜く
		if not hasPredictedHit and swingStage > 0 and slashTrack.IsPlaying then
			slashTrack:AdjustSpeed(CombatConfig.Swing.FollowThroughSpeed)
		end
	end)
end)

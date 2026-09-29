-- Studio配置: StarterPack > Bat (Tool) > Script（通常のScript。サーバー側で実行される）
-- 役割: バットのエントリポイント。R2を押す（溜め開始）・離す（振る）・当たりを受けて各モジュールを呼び、
--       溜め中などのプレイヤーごとの状態を持つ。仕様書の SwordService に相当する処理が
--       将来的にここから ServerScriptService/SwordService へ移行する想定。
-- 溜めた秒数はサーバーがここで測る（プレイヤー側から秒数を受け取らないことでチートを防ぐ）。
-- ただし溜め切った後のタイミングゲージだけは、画面の見た目と判定を揃えるため、プレイヤー側で計った秒数を
-- 上限付きで信用する（TimingGauge.resolveElapsed）。そのため離した合図は tool.Deactivated ではなく、
-- 秒数を付けられる Remotes.ChargeRelease で受け取る

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local ChargeStages = require(ReplicatedStorage.Shared.ChargeStages)
local Knockback = require(ReplicatedStorage.Shared.Knockback)
local HitEffects = require(ReplicatedStorage.Shared.HitEffects)
local TimingGauge = require(ReplicatedStorage.Shared.TimingGauge)
local CharacterLauncher = require(ServerScriptService.CharacterLauncher)
local ChargeEffects = require(ServerScriptService.ChargeEffects)

local tool = script.Parent
local hitbox = tool:WaitForChild("Hitbox")
local distanceResultEvent = ReplicatedStorage.Remotes.DistanceResult
local hitEffectEvent = ReplicatedStorage.Remotes.HitEffect
local chargeReleaseEvent = ReplicatedStorage.Remotes.ChargeRelease

-- サーバーは、振っているプレイヤーから届いたアニメーションで Hitbox の位置を計算する。
-- アニメーションを初めて再生するときは読み込みが終わるまでバットが動かず、最初の一振りだけ当たり判定が遅れるため、
-- 先に読み込んでおく
task.spawn(function()
	local animations = {}
	for _, animationId in ipairs({ CombatConfig.Swing.AnimationId, CombatConfig.Charge.AnimationId }) do
		local animation = Instance.new("Animation")
		animation.AnimationId = animationId
		table.insert(animations, animation)
	end
	ContentProvider:PreloadAsync(animations)
end)

-- 溜めの状態
local chargingCharacter = nil -- 溜め中のキャラクター（溜めていなければnil）
local chargeStartTime = 0
local chargeStage = 0
local originalWalkSpeed = 16

-- 振りの状態
local isSwinging = false      -- 振ってからクールダウンが終わるまでtrue。この間は溜め始められない
local canHit = false          -- 当たり判定が有効な間だけtrue
local hasHitThisSwing = false -- 1回の振りにつき1体だけ吹き飛ばす
local swingStage = 0          -- 今の振りの溜め段階
local swingGaugeResult = nil  -- 今の振りのタイミングゲージの結果（ゲージが出る前に離したならnil）
local pushEndTime = 0         -- 押し込みが終わって相手が飛ぶ時刻。クールダウンはこれより後から数える

-- 段階はキャラクターの属性にも書いておき、プレイヤー側（コントローラーの振動）から読めるようにする
local function setChargeStage(character, stage)
	chargeStage = stage
	character:SetAttribute("ChargeStage", stage)
	ChargeEffects.setStage(character, stage)
end

local function startCharge(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	chargingCharacter = character
	chargeStartTime = os.clock()
	originalWalkSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = originalWalkSpeed * CombatConfig.Charge.WalkSpeedMultiplier

	-- 押している間、経過秒数を見て段階を上げる。最大段階に達したらそのまま保つ
	task.spawn(function()
		while chargingCharacter == character do
			local stage = ChargeStages.getStage(os.clock() - chargeStartTime)
			if stage ~= chargeStage then
				setChargeStage(character, stage)
			end
			if stage == ChargeStages.getMaxStage() then break end
			task.wait()
		end
	end)
end

-- 溜めを終えて演出と歩く速さを元に戻し、離した時点の段階と、溜め始めてからの秒数を返す
local function stopCharge()
	local character = chargingCharacter
	chargingCharacter = nil -- 段階を上げるループもこれで止まる

	-- ループの更新を待たず、離した瞬間の秒数で段階を確定させる
	local elapsed = os.clock() - chargeStartTime
	local stage = ChargeStages.getStage(elapsed)

	setChargeStage(character, 0)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = originalWalkSpeed
	end
	return stage, elapsed
end

-- 飛距離を叩いたプレイヤーに知らせ、ベスト記録を更新する。
-- 飛ばした対象と向きも送り、プレイヤー側の小画面がそれを追いかける。
-- ベストはプレイヤーの属性に持たせる（プレイヤー側へ自動で同期され、画面表示はこれを読む）。
-- DataStoreに保存するようになったら PlayerData.recordDistance に置き換える
local function reportDistance(attacker, target, direction, distance, flightTime)
	local player = Players:GetPlayerFromCharacter(attacker)
	if not player then return end

	local isNewBest = distance > (player:GetAttribute("BestDistance") or 0)
	if isNewBest then
		player:SetAttribute("BestDistance", distance)
	end
	distanceResultEvent:FireClient(player, distance, flightTime, isNewBest, target, direction)
end

-- Hitboxに触れたパーツを判定し、Humanoidを持つキャラクターなら吹き飛ばす
local function tryHit(hitPart)
	if not canHit or hasHitThisSwing then return end

	local attacker = tool.Parent
	local target = hitPart.Parent
	if not target or target == attacker then return end -- 自分自身を吹き飛ばさない

	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not target:FindFirstChildOfClass("Humanoid") or not targetRoot then return end

	hasHitThisSwing = true

	local direction = Knockback.getDirection(attacker.HumanoidRootPart, targetRoot)

	-- 当たった場所の星・衝撃波・火花と相手の震えを、叩いた本人以外の画面に出させる（本人は自分の当たりの予測から先に出している）。
	-- 溜めなしの軽い当たりには演出を出さない
	if swingStage > 0 then
		local contactPoint = HitEffects.getContactPoint(hitPart, hitbox.Position)
		local attackerPlayer = Players:GetPlayerFromCharacter(attacker)
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= attackerPlayer then
				hitEffectEvent:FireClient(player, contactPoint, direction, swingStage, target, swingGaugeResult)
			end
		end
	end

	local feedback = ChargeStages.getHitFeedback(swingStage, swingGaugeResult)
	local power, angle = Knockback.resolve(ChargeStages.getMultiplier(swingStage), TimingGauge.getMultiplier(swingGaugeResult))
	local function launchTarget()
		if not target.Parent then return end -- 押し込んでいる間に対象が消えた（リスポーンなど）
		CharacterLauncher.launch(target, Knockback.getVelocity(direction, power, angle), feedback.Spins, feedback.DownTime)
		-- 飛距離の表示は吹き飛んでから始める（数字と小画面が実際の飛び出しと揃う）
		reportDistance(attacker, target, direction, Knockback.getDistance(power, angle), Knockback.getFlightTime(power, angle))
	end

	-- 押し込み: 当たった瞬間の引っかかり（ImpactDuration 秒）の間に、相手を叩かれた向きへ押し込み、
	-- 上体を後ろへ傾けてから吹き飛ばす。引っかかりが終わる少し手前、LaunchAt の割合の時点で飛ばす。
	-- 叩いた人の振りは、プレイヤー側が自分で当たりを判定して同じ時間だけゆっくり再生する
	-- （サーバーからの通知を待つと、通信の遅れのぶん減速が遅れるため）
	if feedback.ImpactDuration <= 0 then
		launchTarget()
		return
	end

	local tiltAxis = Vector3.yAxis:Cross(direction) -- この軸で回すと、頭が叩かれた向きへ倒れる
	local pushedCFrame = CFrame.new(targetRoot.Position + direction * feedback.PushDistance)
		* CFrame.fromAxisAngle(tiltAxis, math.rad(CombatConfig.HitFeedback.PushTilt))
		* targetRoot.CFrame.Rotation
	-- 固定した HumanoidRootPart を動かすと、関節でつながった体全体がついてくる。
	-- 一定の速さ（Linear）で押し込み、押している間ずっと相手が動いて見えるようにする（途中で止まると固まって見える）
	local pushTime = feedback.ImpactDuration * CombatConfig.HitFeedback.LaunchAt
	pushEndTime = os.clock() + pushTime
	targetRoot.Anchored = true
	TweenService:Create(targetRoot, TweenInfo.new(pushTime, Enum.EasingStyle.Linear), {
		CFrame = pushedCFrame,
	}):Play()

	task.delay(pushTime, function()
		targetRoot.Anchored = false
		launchTarget()
	end)
end

local function swing(stage, gaugeResult)
	isSwinging = true
	swingStage = stage
	swingGaugeResult = gaugeResult
	hasHitThisSwing = false
	pushEndTime = 0

	-- 振り下ろしが進んでから当たり判定を始める
	local hitStart, hitEnd = ChargeStages.getHitWindow(stage)
	task.wait(hitStart)
	canHit = true
	-- 判定を始めた時点で既にHitboxが相手に重なっていることが多い。
	-- Touchedは「新しく触れた瞬間」しか発火しないため、その時点の重なりも直接調べる
	for _, part in ipairs(workspace:GetPartsInPart(hitbox)) do
		tryHit(part)
	end

	task.wait(hitEnd - hitStart)
	canHit = false
	-- 押し込み中なら相手が飛ぶまで待ってから、クールダウンを数える（押し込み中に次の溜めを始めさせない）
	local remainingPush = pushEndTime - os.clock()
	if remainingPush > 0 then
		task.wait(remainingPush)
	end
	task.wait(CombatConfig.Swing.Cooldown)
	isSwinging = false
end

-- R2を押した（マウスなら左ボタンを押した）瞬間：溜め開始
tool.Activated:Connect(function()
	if chargingCharacter or isSwinging then return end
	startCharge(tool.Parent)
end)

-- R2を離した瞬間：溜めた段階で振る。clientGaugeElapsed はプレイヤー側で計った、ゲージが出てからの秒数
-- （ゲージが出る前に離したならnil）。他のプレイヤーのバットへの合図も届くので、持ち主からの合図だけを受ける
chargeReleaseEvent.OnServerEvent:Connect(function(player, clientGaugeElapsed)
	if not chargingCharacter or Players:GetPlayerFromCharacter(tool.Parent) ~= player then return end
	local stage, elapsed = stopCharge()

	-- 最大段階まで溜めていたら、ゲージの結果を判定する。サーバーで計った秒数を基準に、プレイヤー側の秒数を範囲内で信用する
	local gaugeResult = nil
	if stage == ChargeStages.getMaxStage() then
		local serverGaugeElapsed = elapsed - TimingGauge.getStartTime()
		gaugeResult = TimingGauge.getResult(TimingGauge.resolveElapsed(clientGaugeElapsed, serverGaugeElapsed))
	end
	swing(stage, gaugeResult)
end)

-- 溜め中にバットをしまったら、振らずに溜めを取り消す
tool.Unequipped:Connect(function()
	if chargingCharacter then
		stopCharge()
	end
end)

-- 振っている最中に相手に新しく接触した場合の判定
hitbox.Touched:Connect(tryHit)

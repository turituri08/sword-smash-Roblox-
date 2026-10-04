-- Studio配置: ReplicatedStorage > Shared > ChargeStages（ModuleScript）
-- 役割: 溜めた秒数から段階を求め、段階から倍率・振りの速さ・手応えの値を求める。計算だけを行い、状態は持たない。

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))

local ChargeStages = {}

-- 溜めた秒数から段階を求める。1段階目に届いていなければ0
function ChargeStages.getStage(elapsed)
	local stage = 0
	for index, stageConfig in ipairs(CombatConfig.Charge.Stages) do
		if elapsed < stageConfig.Time then break end
		stage = index
	end
	return stage
end

-- 段階に対応する吹っ飛ばしの倍率。溜めなし（0段階）は1倍
function ChargeStages.getMultiplier(stage)
	if stage == 0 then return 1 end
	return CombatConfig.Charge.Stages[stage].Multiplier
end

-- 段階に対応する、当たった瞬間の手応えの値（CombatConfig.HitFeedback.Stages の1行）。
-- タイミングゲージの結果（gaugeResult）があれば、その結果の値（TimingGauge.HitFeedback）で一部を差し替える
function ChargeStages.getHitFeedback(stage, gaugeResult)
	local stages = CombatConfig.HitFeedback.Stages
	local feedback = stages[math.min(stage, #stages)]
	local override = gaugeResult and CombatConfig.TimingGauge.HitFeedback[gaugeResult]
	if not override then return feedback end
	-- 設定の表を書き換えないよう、写しに差し替える
	local merged = table.clone(feedback)
	for key, value in pairs(override) do
		merged[key] = value
	end
	return merged
end

-- 当たってから相手を飛ばすまでの秒数。引っかかり（ImpactDuration）のうち LaunchAt の割合の時点。
-- 虹のように、手応えの値で LaunchAt を差し替えている場合はその値を使う
function ChargeStages.getLaunchDelay(feedback)
	return feedback.ImpactDuration * (feedback.LaunchAt or CombatConfig.HitFeedback.LaunchAt)
end

-- 段階に対応する振りの再生速度。溜めた振りは当たるまで遅く振り下ろして重さを出す
function ChargeStages.getSwingSpeed(stage)
	local swing = CombatConfig.Swing
	return if stage > 0 then swing.ChargedSwingSpeed else swing.AnimationSpeed
end

-- 離してから当たり判定が有効な時間帯（開始と終了の秒数）。
-- 振り下ろしの途中（HitStartTime）から一番下（ImpactTime）まで。振りの速さで変わる
function ChargeStages.getHitWindow(stage)
	local swing = CombatConfig.Swing
	local speed = ChargeStages.getSwingSpeed(stage)
	return swing.HitStartTime / speed, swing.ImpactTime / speed + swing.HitWindowMargin
end

function ChargeStages.getMaxStage()
	return #CombatConfig.Charge.Stages
end

return ChargeStages

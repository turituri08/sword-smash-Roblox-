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

-- 設定の表を書き換えないよう、写しに override の値を上書きする
local function mergeFeedback(feedback, override)
	local merged = table.clone(feedback)
	for key, value in pairs(override) do
		merged[key] = value
	end
	return merged
end

-- 段階に対応する、当たった瞬間の手応えの値（CombatConfig.HitFeedback.Stages の1行）。
-- タイミングゲージの結果（gaugeResult）があれば、その結果の値（TimingGauge.HitFeedback）で一部を差し替える。
-- 会心（isCritical）なら、さらに会心の値（Critical.HitFeedback）で金色にして大きくする（決めの一瞬は虹のときだけで、会心では出さない）
function ChargeStages.getHitFeedback(stage, gaugeResult, isCritical)
	local stages = CombatConfig.HitFeedback.Stages
	local feedback = stages[math.min(stage, #stages)]
	local override = gaugeResult and CombatConfig.TimingGauge.HitFeedback[gaugeResult]
	if override then
		feedback = mergeFeedback(feedback, override)
	end
	if not isCritical then return feedback end

	local critical = CombatConfig.Critical
	if stage == 0 then
		-- 溜めない振りの段階0には演出の値がないので、段階1の演出を元にする。引っかかりは段階0のまま（すぐ飛ばす）
		feedback = mergeFeedback(stages[1], { ImpactDuration = feedback.ImpactDuration, PushDistance = feedback.PushDistance })
	else
		feedback = table.clone(feedback)
	end
	-- 名前が Scale で終わる値は元の値に掛け、それ以外はそのまま差し替える。虹のときは虹色のままにする
	for key, value in pairs(critical.HitFeedback) do
		local target = string.match(key, "^(.+)Scale$")
		if target then
			feedback[target] = (feedback[target] or 0) * value
		elseif not (key == "Color" and feedback.Rainbow) then
			feedback[key] = value
		end
	end
	feedback.SparkCount = math.round(feedback.SparkCount)
	return feedback
end

-- 当たった場所の演出（星・衝撃波の輪・火花・相手の震え・カメラの揺れ）を出すか。
-- 溜めない軽い当たりには出さない（溜めた一撃との差を出す）。ただし会心は溜めなくても出す
function ChargeStages.hasHitEffects(stage, isCritical)
	return stage > 0 or isCritical == true
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

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

-- 段階に対応する、当たった瞬間の手応えの値（CombatConfig.HitFeedback.Stages の1行）
function ChargeStages.getHitFeedback(stage)
	local stages = CombatConfig.HitFeedback.Stages
	return stages[math.min(stage, #stages)]
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

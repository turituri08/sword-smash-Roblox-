-- Studio配置: ReplicatedStorage > Shared > ChargeStages（ModuleScript）
-- 役割: 溜めた秒数から段階と倍率を求める。計算だけを行い、状態は持たない。

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

function ChargeStages.getMaxStage()
	return #CombatConfig.Charge.Stages
end

return ChargeStages

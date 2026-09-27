-- Studio配置: ReplicatedStorage > Shared > Knockback（ModuleScript）
-- 役割: 打撃の強さ（power）と打ち出し角度から、吹っ飛ばす速度・飛距離・滞空時間を求める。
--       計算だけを行い、状態は持たない。シングルでも対戦でも同じ関数を通す。
-- 飛距離は着地を観測せず、平らな地面に落ちる放物線の式で確定させる。
-- 物理演算による実際の飛び方は見た目用で、記録にはこの計算値を使う。

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))

local Knockback = {}

-- 打撃の強さと角度を決める。スキル補正や蓄積ダメージは今後ここに足していく
function Knockback.resolve(chargeMultiplier)
	local launch = CombatConfig.Launch
	local power = math.min(launch.BasePower * chargeMultiplier, launch.MaxPower)
	return power, launch.Angle
end

-- direction は水平方向の単位ベクトル。高さの成分が混ざると計算値と飛び方がずれる
function Knockback.getVelocity(direction, power, angle)
	local radians = math.rad(angle)
	return direction * (power * math.cos(radians)) + Vector3.new(0, power * math.sin(radians), 0)
end

function Knockback.getDistance(power, angle)
	return power ^ 2 * math.sin(2 * math.rad(angle)) / workspace.Gravity
end

-- 打ち上げてから同じ高さに戻るまでの秒数
function Knockback.getFlightTime(power, angle)
	return 2 * power * math.sin(math.rad(angle)) / workspace.Gravity
end

return Knockback

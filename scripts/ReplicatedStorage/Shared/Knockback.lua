-- Studio配置: ReplicatedStorage > Shared > Knockback（ModuleScript）
-- 役割: 打撃の強さ（power）と打ち出し角度から、吹っ飛ばす速度・飛距離・滞空時間を求める。
--       計算だけを行い、状態は持たない。シングルでも対戦でも同じ関数を通す。
-- 飛距離は着地を観測せず、平らな地面に落ちる放物線の式で確定させる。
-- 物理演算による実際の飛び方は見た目用で、記録にはこの計算値を使う。

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))

local Knockback = {}

-- 打撃の強さと角度を決める。weapon は CombatConfig.Weapons の1行（Weapons.fromTool）。timingMultiplier はタイミングゲージの倍率（TimingGauge.getMultiplier）、
-- criticalMultiplier は会心の倍率（Knockback.getCriticalMultiplier）。スキル補正や蓄積ダメージは今後ここに足していく
function Knockback.resolve(weapon, chargeMultiplier, timingMultiplier, criticalMultiplier)
	local power = math.min(weapon.BasePower * chargeMultiplier * timingMultiplier * criticalMultiplier, CombatConfig.Launch.MaxPower)
	return power, weapon.Angle
end

-- 会心の倍率。会心でなければ1倍。溜めた振り（段階1以上）の会心は、さらに ChargedMultiplier を掛ける
function Knockback.getCriticalMultiplier(isCritical, stage)
	if not isCritical then return 1 end
	local critical = CombatConfig.Critical
	return critical.Multiplier * (if stage > 0 then critical.ChargedMultiplier else 1)
end

-- 叩く向き（水平方向の単位ベクトル）。高さの差が混ざると、飛距離の計算値と実際の飛び方がずれるため水平だけにする。
-- 真上や真下に重なっていて向きが決まらないときは、叩いた人の正面を使う
function Knockback.getDirection(attackerRoot, targetRoot)
	local offset = targetRoot.Position - attackerRoot.Position
	local direction = Vector3.new(offset.X, 0, offset.Z)
	return if direction.Magnitude > 0 then direction.Unit else attackerRoot.CFrame.LookVector
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

-- Studio配置: ReplicatedStorage > Shared > TimingGauge（ModuleScript）
-- 役割: 溜め切った後のタイミングゲージの計算。ゲージが出てからの秒数から、位置と結果（緑・普通・赤）と倍率を求める。
--       計算だけを行い、状態は持たない。サーバーの判定とプレイヤー側の表示が同じ関数を通すので、見た目と判定が揃う。

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))

local TimingGauge = {}

-- 押してからゲージが出るまでの秒数（最大段階に達する秒数）
function TimingGauge.getStartTime()
	local stages = CombatConfig.Charge.Stages
	return stages[#stages].Time
end

-- ゲージが出てから elapsed 秒後の位置（0が下の端、1が上の端）。一定の速さで上下に往復する
function TimingGauge.getPosition(elapsed)
	local gauge = CombatConfig.TimingGauge
	-- 下の端から上の端へ行って戻るまでを 0〜2 で表し、1を超えた分は折り返す
	local travelled = (gauge.StartPosition + elapsed / gauge.TravelTime) % 2
	return if travelled <= 1 then travelled else 2 - travelled
end

-- ゲージ上の位置（0〜1）がどの帯か: "Rainbow"（虹。極大のさらに上）・"Green"（極大）・"Normal"（普通）・"Miss"（ミス）。
-- 虹は緑の中のさらに端なので、緑より先に調べる
function TimingGauge.getZone(position)
	local gauge = CombatConfig.TimingGauge
	if position >= 1 - gauge.RainbowZone then
		return "Rainbow"
	elseif position >= 1 - gauge.GreenZone then
		return "Green"
	elseif position <= gauge.MissZone then
		return "Miss"
	end
	return "Normal"
end

-- ゲージが出てから elapsed 秒後に離したときの結果
function TimingGauge.getResult(elapsed)
	return TimingGauge.getZone(TimingGauge.getPosition(elapsed))
end

-- 結果に対応する吹っ飛ばしの倍率。ゲージが出る前に離した（result が nil）なら1倍
function TimingGauge.getMultiplier(result)
	if not result then return 1 end
	return CombatConfig.TimingGauge.Multipliers[result]
end

-- サーバーが判定に使う経過秒数を決める。プレイヤー側から届いた値を、サーバーで計った値の前後 MaxClientDrift 秒の範囲に収める。
-- プレイヤー側の値を使うのは、画面で虹・緑に見えたときにその結果にするため。サーバーの値は通信の遅れのばらつき（数十ミリ秒）でずれ、
-- 約0.05秒しかない虹では外れてしまう。タイミングの腕前は自動で離す道具を使われるとサーバーでも防げないので、明らかにおかしい値だけ弾く
function TimingGauge.resolveElapsed(clientElapsed, serverElapsed)
	if type(clientElapsed) ~= "number" or clientElapsed ~= clientElapsed then -- 数でない値や NaN はサーバーの値を使う
		return serverElapsed
	end
	local drift = CombatConfig.TimingGauge.MaxClientDrift
	return math.clamp(clientElapsed, math.max(serverElapsed - drift, 0), serverElapsed + drift)
end

return TimingGauge

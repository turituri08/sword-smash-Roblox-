-- Studio配置: ReplicatedStorage > Shared > ChestLoot（ModuleScript）
-- 役割: 宝箱の数と格を飛距離から決め、宝箱から出る武器を引く。計算だけで、状態は持たない。
--       値はすべて CombatConfig.Chests・Weapons・Rarities から読むので、武器や格を足すときはそちらに書き足すだけでよい。
--       引くのはサーバー（TreasureChests）。確率をプレイヤーに見せるときにも使えるよう Shared に置く

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))

local ChestLoot = {}

-- 飛距離で新しく超えた線（50、100…）を小さい順に返す。この数だけ宝箱が出る。
-- reachedLine はその人が前に宝箱をもらった一番遠い線（まだなら0）。同じ線では1回しか出さないので、それより先の線だけ返す
function ChestLoot.getNewLines(distance, reachedLine)
	local step = CombatConfig.Chests.DistanceStep
	local lines = {}
	for line = step, distance, step do
		if line > reachedLine then
			table.insert(lines, line)
		end
	end
	return lines
end

-- 線に当てはまる格の番号（CombatConfig.Chests.Tiers の何行目か）。MinDistance 以上の行のうち一番下の行
function ChestLoot.getTierIndex(line)
	local chosen = nil
	for index, tier in ipairs(CombatConfig.Chests.Tiers) do
		if line >= tier.MinDistance then
			chosen = index
		end
	end
	return chosen
end

-- 宝箱から出る武器（最初から持っている武器を除く）を、レア度ごとに分ける
local function getDroppableByRarity()
	local byRarity = {}
	for _, weapon in ipairs(CombatConfig.Weapons) do
		if not weapon.Starter then
			byRarity[weapon.Rarity] = byRarity[weapon.Rarity] or {}
			table.insert(byRarity[weapon.Rarity], weapon)
		end
	end
	return byRarity
end

-- 格の確率（Odds の重み）でレア度を選び、そのレア度の武器から1つを同じ確率で選ぶ。
-- 出る武器がないレア度は飛ばして、残りの重みで割り直す。どれも出せないなら nil
function ChestLoot.roll(tier)
	local byRarity = getDroppableByRarity()

	-- 重みは CombatConfig.Rarities の並び順に足し合わせる（pairs の順番は決まっていないため）
	local candidates = {}
	local total = 0
	for _, rarity in ipairs(CombatConfig.Rarities) do
		local weight = tier.Odds[rarity.Id]
		if weight and weight > 0 and byRarity[rarity.Id] then
			total += weight
			table.insert(candidates, { weight = weight, weapons = byRarity[rarity.Id] })
		end
	end
	if total <= 0 then return nil end

	local pick = math.random() * total
	for _, candidate in ipairs(candidates) do
		pick -= candidate.weight
		if pick < 0 then
			return candidate.weapons[math.random(#candidate.weapons)]
		end
	end
	-- 小数の誤差で抜けた場合は最後のレア度にする
	local last = candidates[#candidates].weapons
	return last[math.random(#last)]
end

return ChestLoot

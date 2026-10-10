-- Studio配置: ReplicatedStorage > Shared > Weapons（ModuleScript）
-- 役割: 武器の定義（CombatConfig.Weapons）を引く。値を持たず、引くだけ。
--       武器の道具（Tool）には、サーバー（WeaponService）が作るときに属性 WeaponId を付けてある。
--       サーバーとプレイヤー側の両方から、持っている道具がどの武器かを調べるのに使う

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))

local Weapons = {}

-- 並び順のまま（持ち物欄に並べる順）
function Weapons.getAll()
	return CombatConfig.Weapons
end

function Weapons.get(id)
	for _, weapon in ipairs(CombatConfig.Weapons) do
		if weapon.Id == id then
			return weapon
		end
	end
	return nil
end

function Weapons.fromTool(tool)
	return Weapons.get(tool:GetAttribute("WeaponId"))
end

return Weapons

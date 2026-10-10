-- Studio配置: ServerScriptService > WeaponInventory（ModuleScript）
-- 役割: プレイヤーが持っている武器を調べ・増やし、武器の道具（Tool）を作って持ち物（Backpack）に入れる。
--       持っている武器はプレイヤーの属性（Owns_<武器の Id> = true）に持たせる。リスポーンしても残り、ゲームを抜けると消える。
--       PlayerData（DataStore）を作ったら、そこから読み書きする。
--       道具は ServerStorage > WeaponTemplates のひな形（スクリプト入り）を複製し、武器ごとの名前・見た目と、
--       どの武器かを示す属性 WeaponId を付ける。強さと角度は、振ったときにバットのスクリプトが WeaponId から引く

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Weapons = require(ReplicatedStorage.Shared.Weapons)

local templates = ServerStorage.WeaponTemplates

local OWNS_PREFIX = "Owns_"

local WeaponInventory = {}

function WeaponInventory.owns(player, weaponId)
	return player:GetAttribute(OWNS_PREFIX .. weaponId) == true
end

local function createTool(weapon)
	local tool = templates[weapon.Template]:Clone()
	tool.Name = weapon.Name
	-- 持ち物欄に絵ではなく名前を出す（どれも同じバットの絵だと見分けられないため）
	tool.TextureId = ""
	-- 中のスクリプトは道具が持ち物に入った時点で動き出すので、その前に付けておく
	tool:SetAttribute("WeaponId", weapon.Id)

	local appearance = weapon.Appearance
	if appearance then
		local handle = tool.Handle
		handle.Mesh.TextureId = "" -- 木目を外すと、部品の色と素材で見える
		handle.Color = appearance.Color
		handle.Material = appearance.Material
	end
	return tool
end

-- 最初から持っている武器（Starter）を持たせる。ゲームに入ったときに1回呼ぶ
function WeaponInventory.giveStarters(player)
	for _, weapon in ipairs(Weapons.getAll()) do
		if weapon.Starter then
			player:SetAttribute(OWNS_PREFIX .. weapon.Id, true)
		end
	end
end

-- 持っている武器の道具を、CombatConfig.Weapons の並び順で持ち物に入れる。
-- 持ち物はリスポーンのたびに空になるので、キャラクターが出るたびに呼ぶ
function WeaponInventory.fillBackpack(player)
	local backpack = player:WaitForChild("Backpack")
	for _, weapon in ipairs(Weapons.getAll()) do
		if WeaponInventory.owns(player, weapon.Id) then
			createTool(weapon).Parent = backpack
		end
	end
end

-- 武器を1つ増やし、すぐ持ち物にも入れる（持ち物欄の一番後ろに並ぶ。並び順はリスポーンで直る）。
-- 初めて手に入れたなら true、もう持っていたなら何もせず false
function WeaponInventory.grant(player, weaponId)
	if WeaponInventory.owns(player, weaponId) then return false end
	player:SetAttribute(OWNS_PREFIX .. weaponId, true)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		createTool(Weapons.get(weaponId)).Parent = backpack
	end
	return true
end

return WeaponInventory

-- Studio配置: ServerScriptService > WeaponService（Script）
-- 役割: キャラクターが出るたびに、持っている武器の道具（Tool）を作って持ち物（Backpack）に入れる。
--       道具は ServerStorage > WeaponTemplates のひな形（スクリプト入り）を複製し、武器ごとの名前・見た目と、
--       どの武器かを示す属性 WeaponId を付ける。強さと角度は、振ったときにバットのスクリプトが WeaponId から引く。
--       スクリプトの元をひな形1つにまとめるため、武器ごとの道具を Studio に並べて置かない。
--       持ち替えは Roblox 標準の持ち物欄（ホットバー）で行う（キーボードは数字キー、コントローラーは L1・R1、スマホ・タブレットはタップ）
-- 宝箱ができるまでは、全員が全部の武器を持つ（仮。ユーザーの判断）。持っている武器は PlayerData を作るまでは保存しない

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Weapons = require(ReplicatedStorage.Shared.Weapons)

local templates = ServerStorage.WeaponTemplates

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

-- 持ち物はリスポーンのたびに空になるので、キャラクターが出るたびに入れ直す
local function giveWeapons(player)
	local backpack = player:WaitForChild("Backpack")
	for _, weapon in ipairs(Weapons.getAll()) do
		createTool(weapon).Parent = backpack
	end
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		giveWeapons(player)
	end)
	if player.Character then
		giveWeapons(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
-- このスクリプトが動く前に入ったプレイヤー（Studio のテストなど）にも配る
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

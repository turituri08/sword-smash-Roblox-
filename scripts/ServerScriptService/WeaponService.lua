-- Studio配置: ServerScriptService > WeaponService（Script）
-- 役割: ゲームに入ったプレイヤーに最初の武器を持たせ、キャラクターが出るたびに持っている武器の道具を持ち物に入れる（WeaponInventory）。
--       持ち替えは Roblox 標準の持ち物欄（ホットバー）で行う（キーボードは数字キー、コントローラーは L1・R1、スマホ・タブレットはタップ）。
--       ほかの武器は宝箱から手に入る（TreasureChests）

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local WeaponInventory = require(ServerScriptService.WeaponInventory)

local function onPlayerAdded(player)
	WeaponInventory.giveStarters(player)
	player.CharacterAdded:Connect(function()
		WeaponInventory.fillBackpack(player)
	end)
	if player.Character then
		WeaponInventory.fillBackpack(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
-- このスクリプトが動く前に入ったプレイヤー（Studio のテストなど）にも配る
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

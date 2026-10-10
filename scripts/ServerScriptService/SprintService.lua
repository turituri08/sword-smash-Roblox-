-- Studio配置: ServerScriptService > SprintService（Script）
-- 役割: 走れるプレイヤーに印（プレイヤーの属性 CanSprint）を付け、走る合図（Remotes.SprintInput）を受けて歩く速さを変える。
--       走れるのはシングルプレイだけ（対戦で走れると相手に当てにくいため）。今はシングルプレイしかないので全員に付けている。
--       対戦を作るときは、試合中だけ CanSprint を false にする（走っている途中でも歩きに戻る）。
--       走っているかはキャラクターの属性 Sprinting に持たせる（リスポーンすると歩きに戻る）

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MovementSpeed = require(ServerScriptService.MovementSpeed)

local function setSprinting(player, isSprinting)
	local character = player.Character
	if not character then return end
	character:SetAttribute("Sprinting", isSprinting)
	MovementSpeed.update(character)
end

ReplicatedStorage.Remotes.SprintInput.OnServerEvent:Connect(function(player, isSprinting)
	if type(isSprinting) ~= "boolean" then return end -- プレイヤー側から届く値は型から確かめる
	if isSprinting and not player:GetAttribute("CanSprint") then return end
	setSprinting(player, isSprinting)
end)

local function onPlayerAdded(player)
	player:SetAttribute("CanSprint", true)
	player:GetAttributeChangedSignal("CanSprint"):Connect(function()
		if not player:GetAttribute("CanSprint") then
			setSprinting(player, false)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
-- このスクリプトが動く前に入ったプレイヤー（Studio のテストなど）にも付ける
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

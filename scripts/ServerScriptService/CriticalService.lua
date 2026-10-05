-- Studio配置: ServerScriptService > CriticalService（Script）
-- 役割: 会心の一撃の発動の合図（Remotes.CriticalActivate）を受けて CriticalMeter に渡す。
--       発動中にリスポーンしたら、新しいキャラクターに気を付け直す（発動中かどうかはプレイヤーの属性なので、リスポーンしても残る）

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CriticalMeter = require(ServerScriptService.CriticalMeter)
local CriticalAura = require(ServerScriptService.CriticalAura)

ReplicatedStorage.Remotes.CriticalActivate.OnServerEvent:Connect(function(player)
	CriticalMeter.activate(player)
end)

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		if CriticalMeter.isActive(player) then
			character:WaitForChild("HumanoidRootPart")
			CriticalAura.enable(character)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
-- このスクリプトが動く前に入ったプレイヤー（Studio のテストなど）にも付ける
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

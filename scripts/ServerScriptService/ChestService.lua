-- Studio配置: ServerScriptService > ChestService（Script）
-- 役割: 宝箱を置くフォルダ（Workspace > TreasureChests）を用意し、開ける合図（宝箱の ProximityPrompt）を受けて TreasureChests.open を呼ぶ。
--       ゲームを抜けたプレイヤーの宝箱を片付ける。宝箱を落とすのはバットの Script（飛距離が出たとき）

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ServerScriptService = game:GetService("ServerScriptService")

local TreasureChests = require(ServerScriptService.TreasureChests)

-- プレイヤー側（ChestReward）がこのフォルダを待つので、最初から作っておく
local folder = Instance.new("Folder")
folder.Name = "TreasureChests"
folder.Parent = workspace

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if prompt.Name ~= TreasureChests.PROMPT_NAME then return end
	local chest = prompt:FindFirstAncestor("TreasureChest")
	if chest then
		TreasureChests.open(player, chest)
	end
end)

Players.PlayerRemoving:Connect(TreasureChests.removeOwnedBy)

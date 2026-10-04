-- Studio配置: StarterPlayer > StarterPlayerScripts > HitEffectReceiver（LocalScript）
-- 役割: 他のプレイヤーが叩いたとき、サーバーからの知らせを受けて当たった場所のトゲの星・衝撃波の輪・火花を出し、叩かれた相手を震わせる。
--       虹で叩かれたのが自分なら、決めの一瞬（CriticalCinematic）も出す。関係ない人の画面は止めない。
--       叩いた本人は Bat の LocalScript が自分の当たりの予測から先に出すので、サーバーは本人には送らない

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChargeStages = require(Shared:WaitForChild("ChargeStages"))
local HitEffects = require(Shared:WaitForChild("HitEffects"))
local TargetShake = require(Shared:WaitForChild("TargetShake"))
local CriticalCinematic = require(Shared:WaitForChild("CriticalCinematic"))

ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("HitEffect").OnClientEvent:Connect(function(position, direction, stage, target, gaugeResult)
	HitEffects.play(position, direction, stage, gaugeResult)
	TargetShake.play(target, direction, stage, gaugeResult)
	if gaugeResult == "Rainbow" and target == Players.LocalPlayer.Character then
		CriticalCinematic.play(ChargeStages.getLaunchDelay(ChargeStages.getHitFeedback(stage, gaugeResult)))
	end
end)

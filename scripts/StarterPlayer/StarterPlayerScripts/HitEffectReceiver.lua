-- Studio配置: StarterPlayer > StarterPlayerScripts > HitEffectReceiver（LocalScript）
-- 役割: 他のプレイヤーが叩いたとき、サーバーからの知らせを受けて当たった場所のトゲの星・衝撃波の輪・火花を出し、叩かれた相手を震わせる。
--       叩かれたのが自分なら、ゲージの結果の文字（HitText）と、虹のときは決めの一瞬（FinishCinematic）も出す。
--       関係ない人の画面には、文字も決めの一瞬も出さない。
--       叩いた本人は Bat の LocalScript が自分の当たりの予測から先に出すので、サーバーは本人には送らない

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChargeStages = require(Shared:WaitForChild("ChargeStages"))
local HitEffects = require(Shared:WaitForChild("HitEffects"))
local TargetShake = require(Shared:WaitForChild("TargetShake"))
local FinishCinematic = require(Shared:WaitForChild("FinishCinematic"))
local HitText = require(Shared:WaitForChild("HitText"))

ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("HitEffect").OnClientEvent:Connect(function(position, direction, stage, target, gaugeResult)
	HitEffects.play(position, direction, stage, gaugeResult)
	TargetShake.play(target, direction, stage, gaugeResult)
	if target ~= Players.LocalPlayer.Character then return end
	local launchDelay = ChargeStages.getLaunchDelay(ChargeStages.getHitFeedback(stage, gaugeResult))
	HitText.play(target, gaugeResult, launchDelay)
	if gaugeResult == "Rainbow" then
		FinishCinematic.play(launchDelay)
	end
end)

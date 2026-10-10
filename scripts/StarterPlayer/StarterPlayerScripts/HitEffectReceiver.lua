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

-- isCritical は会心の一撃か。launchAngle は叩いた武器の打ち出す角度（火花と衝撃波の向きに使う）
ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("HitEffect").OnClientEvent:Connect(function(position, direction, stage, target, gaugeResult, isCritical, launchAngle)
	HitEffects.play(position, direction, stage, gaugeResult, isCritical, launchAngle)
	TargetShake.play(target, direction, stage, gaugeResult, isCritical)
	if target ~= Players.LocalPlayer.Character then return end
	local feedback = ChargeStages.getHitFeedback(stage, gaugeResult, isCritical)
	local launchDelay = ChargeStages.getLaunchDelay(feedback)
	HitText.play(target, gaugeResult, launchDelay)
	if feedback.Cinematic then
		FinishCinematic.play(launchDelay)
	end
end)

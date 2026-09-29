-- Studio配置: StarterPlayer > StarterPlayerScripts > HitEffectReceiver（LocalScript）
-- 役割: 他のプレイヤーが叩いたとき、サーバーからの知らせを受けて当たった場所のトゲの星・衝撃波の輪・火花を出し、叩かれた相手を震わせる。
--       叩いた本人は Bat の LocalScript が自分の当たりの予測から先に出すので、サーバーは本人には送らない

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local HitEffects = require(Shared:WaitForChild("HitEffects"))
local TargetShake = require(Shared:WaitForChild("TargetShake"))

ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("HitEffect").OnClientEvent:Connect(function(position, direction, stage, target)
	HitEffects.play(position, direction, stage)
	TargetShake.play(target, direction, stage)
end)

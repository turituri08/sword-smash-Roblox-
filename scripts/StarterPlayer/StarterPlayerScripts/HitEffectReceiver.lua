-- Studio配置: StarterPlayer > StarterPlayerScripts > HitEffectReceiver（LocalScript）
-- 役割: 他のプレイヤーが叩いたとき、サーバーからの知らせを受けて当たった場所の閃光・衝撃波の輪・火花を出す。
--       叩いた本人は Bat の LocalScript が自分の当たりの予測から先に出すので、サーバーは本人には送らない

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HitEffects = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HitEffects"))

ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("HitEffect").OnClientEvent:Connect(HitEffects.play)

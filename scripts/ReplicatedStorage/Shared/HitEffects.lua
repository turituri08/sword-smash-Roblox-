-- Studio配置: ReplicatedStorage > Shared > HitEffects（ModuleScript）
-- 役割: 当たった場所に、溜めの段階色の閃光・衝撃波の輪・火花を出す。演出はプレイヤー側で作る（粒の動きが各自の画面でなめらかになる）。
--       叩いた本人は自分の当たりの予測から、他のプレイヤーはサーバーからの知らせ（Remotes.HitEffect）を受けて呼ぶ。
--       当たった場所の計算はサーバーも使うので、ここに置く

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))
local ChargeStages = require(script.Parent:WaitForChild("ChargeStages"))

local HitEffects = {}

-- どれも Roblox に標準で入っている画像
local FLASH_TEXTURE = "rbxasset://textures/particles/forcefield_glow_main.dds" -- ぼんやり光る丸
local RING_TEXTURE = "rbxasset://textures/particles/explosion01_shockwave_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/fire_sparks_main.dds"

-- 叩かれた部位の表面のうち、fromPosition（Hitbox の中心）に一番近い点。
-- 部位の中心に出すと体に埋もれて見えにくいため、表面に出す
function HitEffects.getContactPoint(hitPart, fromPosition)
	local localPoint = hitPart.CFrame:PointToObjectSpace(fromPosition)
	local half = hitPart.Size / 2
	return hitPart.CFrame:PointToWorldSpace(Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		math.clamp(localPoint.Y, -half.Y, half.Y),
		math.clamp(localPoint.Z, -half.Z, half.Z)
	))
end

-- 溜めの段階色（ChargeEffects.Stages と同じ色）
local function getColor(stage)
	local stages = CombatConfig.ChargeEffects.Stages
	return stages[math.min(stage, #stages)].Color
end

-- 一度に放出するだけの粒の出し口。常に出し続けないよう Enabled はオフにして、Emit で出す
local function createEmitter(parent, texture, color)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Parent = parent
	return emitter
end

-- stage は1以上（溜めなしの当たりには演出を出さないので、呼ぶ側で除く）
function HitEffects.play(position, direction, stage)
	local feedback = ChargeStages.getHitFeedback(stage)
	local effect = CombatConfig.HitFeedback.Effect
	local color = getColor(stage)

	-- 部品を作らずに位置だけ置けるよう、Terrain に Attachment を付ける（当たり判定や影に影響しない）。
	-- 粒は Attachment の前方（Front）へ放出されるので、前方を相手が飛ぶ向き（打ち出す角度で斜め上）に合わせる
	local launchAngle = math.rad(CombatConfig.Launch.Angle)
	local launchDirection = direction * math.cos(launchAngle) + Vector3.yAxis * math.sin(launchAngle)
	local attachment = Instance.new("Attachment")
	attachment.Parent = workspace.Terrain
	attachment.WorldCFrame = CFrame.lookAt(position, position + launchDirection)

	-- 閃光: 大きな粒を1つ、その場で広がりながら消えさせる
	local flash = createEmitter(attachment, FLASH_TEXTURE, color)
	flash.Speed = NumberRange.new(0)
	flash.Lifetime = NumberRange.new(effect.FlashTime)
	flash.Size = NumberSequence.new(feedback.FlashSize * 0.3, feedback.FlashSize)
	flash.Transparency = NumberSequence.new(0, 1)
	flash.ZOffset = 1 -- 体より手前に描いて、埋もれないようにする
	flash:Emit(1)

	-- 衝撃波の輪: 相手が飛ぶ向きに垂直な面で広がる。
	-- VelocityPerpendicular は粒を進む向きに垂直な面で描くので、ごくわずかな速さで飛ぶ向きへ進ませて面の向きを決める
	local ring = createEmitter(attachment, RING_TEXTURE, color)
	ring.Speed = NumberRange.new(0.01)
	ring.SpreadAngle = Vector2.zero
	ring.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	ring.Lifetime = NumberRange.new(effect.RingTime)
	ring.Size = NumberSequence.new(feedback.RingSize * 0.2, feedback.RingSize)
	ring.Transparency = NumberSequence.new(0.2, 1)
	ring:Emit(1)

	-- 火花: 相手が飛ぶ向きへ円錐状に飛び散り、落ちながら消える
	local sparks = createEmitter(attachment, SPARK_TEXTURE, color)
	sparks.SpreadAngle = Vector2.new(effect.SparkSpread, effect.SparkSpread)
	sparks.Speed = NumberRange.new(effect.SparkSpeedMin, effect.SparkSpeedMax)
	sparks.Lifetime = NumberRange.new(effect.SparkLifetime * 0.6, effect.SparkLifetime)
	sparks.Acceleration = Vector3.new(0, -effect.SparkGravity, 0)
	sparks.Drag = 3
	sparks.Orientation = Enum.ParticleOrientation.VelocityParallel -- 飛ぶ向きに沿わせて線状に見せる
	sparks.Size = NumberSequence.new(effect.SparkSize, 0)
	sparks:Emit(feedback.SparkCount)

	-- 周りを一瞬照らす
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = effect.LightBrightness
	light.Range = effect.LightRange
	light.Shadows = false
	light.Parent = attachment
	TweenService:Create(light, TweenInfo.new(effect.FlashTime), { Brightness = 0 }):Play()

	-- 粒が消え切ってから片付ける（先に Destroy すると、飛んでいる途中の粒も消えるため）
	Debris:AddItem(attachment, math.max(effect.FlashTime, effect.RingTime, effect.SparkLifetime) + 0.1)
end

return HitEffects

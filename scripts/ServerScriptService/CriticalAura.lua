-- Studio配置: ServerScriptService > CriticalAura（ModuleScript）
-- 役割: 会心の一撃を発動している間、キャラクターの体から金色の気（スーパーサイヤ人風）を立ちのぼらせる。
--       体そのものも金色に光らせる。サーバー側で付けるので、他のプレイヤーからも見える（対戦で相手が会心を持っているのが分かる）。
--       モジュールは全プレイヤーで共有されるため状態は持たず、演出の部品はキャラクターの中から名前で探す

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)

local CriticalAura = {}

local AURA_NAME = "CriticalAura"
local BURST_NAME = "CriticalBurst"
local LIGHT_NAME = "CriticalLight"
local HIGHLIGHT_NAME = "CriticalHighlight"

-- 炎の形の粒（Roblox に入っているテクスチャ）。光を足し合わせて明るく見せる
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"

local function createEmitter(name, setup)
	local aura = CombatConfig.Critical.Aura
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Texture = FIRE_TEXTURE
	emitter.Color = ColorSequence.new(aura.Color)
	emitter.Brightness = aura.Brightness
	emitter.LightEmission = aura.LightEmission
	emitter.Lifetime = NumberRange.new(aura.Lifetime[1], aura.Lifetime[2])
	-- 出た瞬間から少し大きくなって炎のようにふくらみ、小さくなりながら消える
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, aura.StartSize),
		NumberSequenceKeypoint.new(0.4, aura.PeakSize),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.6, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.RotSpeed = NumberRange.new(-90, 90)
	-- HumanoidRootPart（胴体と同じ大きさの見えない箱）の中から出し、体全体から湧き上がって見せる
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	setup(emitter)
	return emitter
end

function CriticalAura.enable(character)
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or rootPart:FindFirstChild(AURA_NAME) then return end
	local aura = CombatConfig.Critical.Aura

	-- 体に纏って立ちのぼり続ける気
	createEmitter(AURA_NAME, function(emitter)
		emitter.Rate = aura.Rate
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Speed = NumberRange.new(aura.RiseSpeed[1], aura.RiseSpeed[2])
		emitter.Acceleration = Vector3.new(0, aura.RiseAcceleration, 0)
		emitter.SpreadAngle = Vector2.new(aura.SpreadAngle, aura.SpreadAngle)
		emitter.LockedToPart = true -- 出た粒も体と一緒に動かし、歩いても置いていかれないようにする（身に纏って見せる）
	end).Parent = rootPart

	-- 発動した瞬間に全方向へ弾ける粒
	local burst = createEmitter(BURST_NAME, function(emitter)
		emitter.Enabled = false
		emitter.Speed = NumberRange.new(10, 16)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Drag = 4
	end)
	burst.Parent = rootPart
	burst:Emit(aura.ActivateBurst)

	local light = Instance.new("PointLight")
	light.Name = LIGHT_NAME
	light.Color = aura.Color
	light.Brightness = aura.LightBrightness
	light.Range = aura.LightRange
	light.Shadows = false
	light.Parent = rootPart

	local highlight = Instance.new("Highlight")
	highlight.Name = HIGHLIGHT_NAME
	highlight.FillColor = aura.Color
	highlight.FillTransparency = aura.FillTransparency
	highlight.OutlineColor = aura.OutlineColor
	highlight.OutlineTransparency = 0
	-- 既定の AlwaysOnTop だと壁越しにも見えてしまうため、遮られたら隠れるようにする
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = character
end

function CriticalAura.disable(character)
	if not character then return end
	local highlight = character:FindFirstChild(HIGHLIGHT_NAME)
	if highlight then highlight:Destroy() end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	for _, name in ipairs({ AURA_NAME, BURST_NAME, LIGHT_NAME }) do
		local instance = rootPart:FindFirstChild(name)
		if instance then instance:Destroy() end
	end
end

return CriticalAura

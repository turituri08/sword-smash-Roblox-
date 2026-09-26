-- Studio配置: ServerScriptService > ChargeEffects（ModuleScript）
-- 役割: 溜めの段階に応じて、キャラクターの光と粒の演出を付け外しする。
--       サーバー側で付けるので、他のプレイヤーからも見える。
--       モジュールは全プレイヤーで共有されるため状態は持たず、演出の部品はキャラクターの中から名前で探す。

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)

local ChargeEffects = {}

local HIGHLIGHT_NAME = "ChargeHighlight"
local LIGHT_NAME = "ChargeLight"
local BURST_NAME = "ChargeBurst"

local function getOrCreate(parent, className, name, setup)
	local existing = parent:FindFirstChild(name)
	if existing then return existing end
	local instance = Instance.new(className)
	instance.Name = name
	setup(instance)
	instance.Parent = parent
	return instance
end

-- 体全体に色を重ねて光らせる
local function getHighlight(character)
	return getOrCreate(character, "Highlight", HIGHLIGHT_NAME, function(highlight)
		-- 既定のAlwaysOnTopだと壁越しにも見えてしまうため、遮られたら隠れるようにする
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.OutlineTransparency = 0
	end)
end

-- 体の周りの地面を照らす
local function getLight(rootPart)
	return getOrCreate(rootPart, "PointLight", LIGHT_NAME, function(light)
		light.Shadows = false
	end)
end

-- 段階が上がった瞬間に体から弾ける粒。常に出し続けず、Emitで一度に放出する
local function getBurst(rootPart)
	return getOrCreate(rootPart, "ParticleEmitter", BURST_NAME, function(emitter)
		emitter.Enabled = false
		emitter.LightEmission = 1
		emitter.Lifetime = NumberRange.new(0.3, 0.5)
		emitter.Speed = NumberRange.new(8, 12)
		emitter.SpreadAngle = Vector2.new(180, 180) -- 全方向に飛ばす
		emitter.Size = NumberSequence.new(0.4, 0)   -- 小さくなりながら消える
		emitter.Drag = 5
	end)
end

function ChargeEffects.clear(character)
	local highlight = character:FindFirstChild(HIGHLIGHT_NAME)
	if highlight then highlight:Destroy() end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	for _, name in ipairs({ LIGHT_NAME, BURST_NAME }) do
		local instance = rootPart:FindFirstChild(name)
		if instance then instance:Destroy() end
	end
end

-- 段階の演出に切り替える。0なら演出を消す
function ChargeEffects.setStage(character, stage)
	if stage == 0 then
		ChargeEffects.clear(character)
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- 演出の設定より段階が多い場合は、設定の最後の段階の見た目を使う
	local stageEffects = CombatConfig.ChargeEffects.Stages
	local effect = stageEffects[math.min(stage, #stageEffects)]

	local highlight = getHighlight(character)
	highlight.FillColor = effect.Color
	highlight.OutlineColor = effect.Color
	highlight.FillTransparency = effect.FillTransparency

	local light = getLight(rootPart)
	light.Color = effect.Color
	light.Brightness = effect.LightBrightness
	light.Range = effect.LightRange

	local burst = getBurst(rootPart)
	burst.Color = ColorSequence.new(effect.Color)
	burst:Emit(effect.BurstCount)
end

return ChargeEffects

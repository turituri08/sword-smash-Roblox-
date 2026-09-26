-- Studio配置: StarterPack > Bat (Tool) > Script（通常のScript。サーバー側で実行される）
-- 役割: バットの当たり判定とノックバックを管理する。仕様書の SwordService に相当する
--       処理が将来的にここから ServerScriptService/SwordService へ移行する想定。

local tool = script.Parent
local hitbox = tool:WaitForChild("Hitbox")

local LANDING_CHECK_DISTANCE = 4 -- HumanoidRootPartの下、この距離以内に地面があれば着地直前とみなす
local MAX_AIR_TIME = 10          -- 奈落に落ちた場合などに備えた解除の上限秒数

local canHit = false          -- スイング中(true)の間だけ当たり判定を有効にする
local debounce = false        -- 連打による多重発動（スイングの二重起動）を防ぐ
local hasHitThisSwing = false -- 1回のスイングにつき1体だけ吹き飛ばす

-- 落下中かつ足元に地面が近づいたら戻る（上昇中は地面が近くても解除しない）
-- Humanoidの着地判定はPlatformStand中に当てにならないため、自前のレイキャストで調べる
local function waitUntilLanding(character, rootPart)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character } -- 自分の体にレイが当たらないよう除外

	local elapsed = 0
	while elapsed < MAX_AIR_TIME do
		local isFalling = rootPart.AssemblyLinearVelocity.Y <= 0
		local ground = workspace:Raycast(rootPart.Position, Vector3.new(0, -LANDING_CHECK_DISTANCE, 0), params)
		if isFalling and ground then return end
		elapsed += task.wait()
	end
end

-- ヒットしたキャラクターを吹き飛ばす
local function launchCharacter(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end

	local playerCharacter = tool.Parent
	if character == playerCharacter then return end -- 自分自身を吹き飛ばさない

	hasHitThisSwing = true

	local direction = (rootPart.Position - playerCharacter.HumanoidRootPart.Position).Unit
	local launchVelocity = direction * 50 + Vector3.new(0, 40, 0)

	-- Humanoidは標準でバランスを取ろうとして外部から与えた速度を打ち消すため、
	-- PlatformStandで一時的に自動制御を切ってから速度を与える
	humanoid.PlatformStand = true
	rootPart.AssemblyLinearVelocity = launchVelocity

	-- PlatformStand中は体を浮かせる支えの力も止まり、着地すると脚が地面に沈む。
	-- 着地の直前に制御を戻して、Humanoidに立たせ直させる
	task.spawn(function()
		waitUntilLanding(character, rootPart)
		humanoid.PlatformStand = false
	end)
end

-- Hitboxに触れたパーツを判定し、Humanoidを持つキャラクターなら吹き飛ばす
local function tryHit(hitPart)
	if not canHit or hasHitThisSwing then return end
	local character = hitPart.Parent
	if not character then return end
	launchCharacter(character)
end

-- 装備者がツールを使用（コントローラーのR2/マウスクリック）した瞬間の処理
tool.Activated:Connect(function()
	if debounce then return end
	debounce = true
	canHit = true
	hasHitThisSwing = false

	-- 相手に密着して振ると、振り始めの時点で既にHitboxが重なっていることがある。
	-- Touchedは「新しく触れた瞬間」しか発火しないため、押した瞬間の重なりも直接チェックする
	for _, part in ipairs(hitbox:GetTouchingParts()) do
		tryHit(part)
	end

	task.wait(0.3) -- 判定が有効な時間（スイングの当たり判定ウィンドウ）
	canHit = false
	task.wait(0.4) -- 次のスイングまでのクールダウン
	debounce = false
end)

-- プレイヤーが動いて新しく接触した場合の判定
hitbox.Touched:Connect(tryHit)

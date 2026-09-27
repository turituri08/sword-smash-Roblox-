-- Studio配置: ServerScriptService > CharacterLauncher（ModuleScript）
-- 役割: キャラクターを指定の速度で吹き飛ばしてラグドールにし、着地して少し倒れた後に起き上がらせる。
--       どの速度で飛ばすかは呼び出し側が決める。

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local Ragdoll = require(script.Parent.Ragdoll)

local CharacterLauncher = {}

-- 落下中かつ足元に地面が近づいたら戻る（上昇中は地面が近くても解除しない）
-- Humanoidの着地判定はPlatformStand中に当てにならないため、自前のレイキャストで調べる
local function waitUntilLanding(character, rootPart)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character } -- 自分の体にレイが当たらないよう除外

	local checkVector = Vector3.new(0, -CombatConfig.Launch.LandingCheckDistance, 0)
	local elapsed = 0
	while elapsed < CombatConfig.Launch.MaxAirTime do
		local isFalling = rootPart.AssemblyLinearVelocity.Y <= 0
		local ground = workspace:Raycast(rootPart.Position, checkVector, params)
		if isFalling and ground then return end
		elapsed += task.wait()
	end
end

-- 後ろ宙返りの向きの回転と、少しだけランダムなひねり。滞空中に spins 回転する速さにする
local function getSpin(velocity, spins)
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	if horizontal.Magnitude < 0.01 or velocity.Y <= 0 then return Vector3.zero end
	-- この軸で回すと頭が飛ぶ向きへ倒れる（押し込みでのけぞった向きのまま回り続ける）
	local flipAxis = Vector3.yAxis:Cross(horizontal.Unit)
	local flightTime = 2 * velocity.Y / workspace.Gravity
	local twist = (math.random() * 2 - 1) * CombatConfig.Ragdoll.MaxTwistSpeed
	return flipAxis * (spins * 2 * math.pi / flightTime) + Vector3.yAxis * twist
end

function CharacterLauncher.launch(character, velocity, spins)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end

	-- Humanoidは標準でバランスを取ろうとして外部から与えた速度を打ち消すため、
	-- PlatformStandで一時的に自動制御を切ってから速度を与える
	humanoid.PlatformStand = true
	Ragdoll.enable(character)
	-- 関節を切ると部位ごとに別々の塊になるので、速度と回転は全部の部位に与える。
	-- 体全体が1つの塊として回るよう、胴体の中心からの位置に応じて、回転による速度も足す
	-- （足さないと、部位同士が関節で引っ張り合って回転が打ち消される）
	local angularVelocity = getSpin(velocity, spins)
	local center = rootPart.Position
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.AssemblyLinearVelocity = velocity + angularVelocity:Cross(part.Position - center)
			part.AssemblyAngularVelocity = angularVelocity
		end
	end

	-- 叩かれるたびに数を増やし、前の吹き飛ばしの起き上がりが、新しい吹き飛ばしの途中で動かないようにする
	local launchCount = (character:GetAttribute("LaunchCount") or 0) + 1
	character:SetAttribute("LaunchCount", launchCount)

	task.spawn(function()
		waitUntilLanding(character, rootPart)
		task.wait(CombatConfig.Ragdoll.LieTime)
		if not character.Parent or character:GetAttribute("LaunchCount") ~= launchCount then return end
		Ragdoll.disable(character)
		humanoid.PlatformStand = false
	end)
end

return CharacterLauncher

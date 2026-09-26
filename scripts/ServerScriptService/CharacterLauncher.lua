-- Studio配置: ServerScriptService > CharacterLauncher（ModuleScript）
-- 役割: キャラクターを指定の速度で吹き飛ばし、着地したら立たせ直す。
--       どの速度で飛ばすかは呼び出し側が決める。

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)

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

function CharacterLauncher.launch(character, velocity)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end

	-- Humanoidは標準でバランスを取ろうとして外部から与えた速度を打ち消すため、
	-- PlatformStandで一時的に自動制御を切ってから速度を与える
	humanoid.PlatformStand = true
	rootPart.AssemblyLinearVelocity = velocity

	-- PlatformStand中は体を浮かせる支えの力も止まり、着地すると脚が地面に沈む。
	-- 着地の直前に制御を戻して、Humanoidに立たせ直させる
	task.spawn(function()
		waitUntilLanding(character, rootPart)
		humanoid.PlatformStand = false
	end)
end

return CharacterLauncher

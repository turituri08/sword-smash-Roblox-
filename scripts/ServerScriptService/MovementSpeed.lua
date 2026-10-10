-- Studio配置: ServerScriptService > MovementSpeed（ModuleScript）
-- 役割: キャラクターの歩く速さを、溜め中か・走っているかから決める。
--       歩く速さを変えるのはここだけにする（溜めと走るがそれぞれ速さを変えると、お互いの値を上書きしてしまうため）。
--       状態はキャラクターの属性に持たせ（Charging はバットの Script、Sprinting は SprintService が書く）、ここは読むだけ

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)

local MovementSpeed = {}

-- 属性を書き換えたら呼ぶ
function MovementSpeed.update(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local speed = StarterPlayer.CharacterWalkSpeed
	-- 走っていても、溜め中は溜めの速さにする（走りながら溜めて一気に詰め寄れないように）
	if character:GetAttribute("Charging") then
		speed *= CombatConfig.Charge.WalkSpeedMultiplier
	elseif character:GetAttribute("Sprinting") then
		speed *= CombatConfig.Sprint.SpeedMultiplier
	end
	humanoid.WalkSpeed = speed
end

return MovementSpeed

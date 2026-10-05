-- Studio配置: ServerScriptService > CriticalMeter（ModuleScript）
-- 役割: 会心の一撃のゲージの決まりごと。当たりを数え、満タンなら発動し、会心の当たりで消費する。
--       ゲージの数（CriticalCharge）と発動中かどうか（CriticalActive）はプレイヤーの属性に持たせる
--       （モジュールは全プレイヤーで共有されるので状態を持たない。属性はプレイヤー側へ自動で同期され、ボタンの表示が読む）。
--       数えるのも発動を決めるのもサーバーだけで、プレイヤー側からは「発動したい」という合図しか受け取らない。
--       PlayerData ができるまでは、ゲームを抜けると0に戻る

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local CriticalAura = require(ServerScriptService.CriticalAura)

local CriticalMeter = {}

local CHARGE_ATTRIBUTE = "CriticalCharge"
local ACTIVE_ATTRIBUTE = "CriticalActive"

function CriticalMeter.isActive(player)
	return player:GetAttribute(ACTIVE_ATTRIBUTE) == true
end

-- 会心でない当たりを1つ数える。発動中は数えない（会心を使い切ってから次を溜める）
function CriticalMeter.addHit(player)
	if CriticalMeter.isActive(player) then return end
	local charge = player:GetAttribute(CHARGE_ATTRIBUTE) or 0
	player:SetAttribute(CHARGE_ATTRIBUTE, math.min(charge + 1, CombatConfig.Critical.MaxCharge))
end

-- 満タンなら発動する。満タンでない・発動中なら何もしない（プレイヤー側の合図は信用せず、ここで確かめる）
function CriticalMeter.activate(player)
	if CriticalMeter.isActive(player) then return end
	if (player:GetAttribute(CHARGE_ATTRIBUTE) or 0) < CombatConfig.Critical.MaxCharge then return end
	player:SetAttribute(CHARGE_ATTRIBUTE, 0)
	player:SetAttribute(ACTIVE_ATTRIBUTE, true)
	CriticalAura.enable(player.Character)
end

-- 会心の当たりで使い切る
function CriticalMeter.consume(player)
	player:SetAttribute(ACTIVE_ATTRIBUTE, false)
	CriticalAura.disable(player.Character)
end

return CriticalMeter

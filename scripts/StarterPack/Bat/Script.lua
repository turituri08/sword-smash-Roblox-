-- Studio配置: StarterPack > Bat (Tool) > Script（通常のScript。サーバー側で実行される）
-- 役割: バットのエントリポイント。R2を押す（溜め開始）・離す（振る）・当たりを受けて各モジュールを呼び、
--       溜め中などのプレイヤーごとの状態を持つ。仕様書の SwordService に相当する処理が
--       将来的にここから ServerScriptService/SwordService へ移行する想定。
-- 溜めた秒数はサーバーがここで測る（プレイヤー側から秒数を受け取らないことでチートを防ぐ）。

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local ChargeStages = require(ReplicatedStorage.Shared.ChargeStages)
local Knockback = require(ReplicatedStorage.Shared.Knockback)
local CharacterLauncher = require(ServerScriptService.CharacterLauncher)
local ChargeEffects = require(ServerScriptService.ChargeEffects)

local tool = script.Parent
local hitbox = tool:WaitForChild("Hitbox")
local distanceResultEvent = ReplicatedStorage.Remotes.DistanceResult

-- 溜めの状態
local chargingCharacter = nil -- 溜め中のキャラクター（溜めていなければnil）
local chargeStartTime = 0
local chargeStage = 0
local originalWalkSpeed = 16

-- 振りの状態
local isSwinging = false      -- 振ってからクールダウンが終わるまでtrue。この間は溜め始められない
local canHit = false          -- 当たり判定が有効な間だけtrue
local hasHitThisSwing = false -- 1回の振りにつき1体だけ吹き飛ばす
local swingMultiplier = 1     -- 今の振りにかかる溜め倍率

-- 段階はキャラクターの属性にも書いておき、プレイヤー側（コントローラーの振動）から読めるようにする
local function setChargeStage(character, stage)
	chargeStage = stage
	character:SetAttribute("ChargeStage", stage)
	ChargeEffects.setStage(character, stage)
end

local function startCharge(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	chargingCharacter = character
	chargeStartTime = os.clock()
	originalWalkSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = originalWalkSpeed * CombatConfig.Charge.WalkSpeedMultiplier

	-- 押している間、経過秒数を見て段階を上げる。最大段階に達したらそのまま保つ
	task.spawn(function()
		while chargingCharacter == character do
			local stage = ChargeStages.getStage(os.clock() - chargeStartTime)
			if stage ~= chargeStage then
				setChargeStage(character, stage)
			end
			if stage == ChargeStages.getMaxStage() then break end
			task.wait()
		end
	end)
end

-- 溜めを終えて演出と歩く速さを元に戻し、離した時点の段階を返す
local function stopCharge()
	local character = chargingCharacter
	chargingCharacter = nil -- 段階を上げるループもこれで止まる

	-- ループの更新を待たず、離した瞬間の秒数で段階を確定させる
	local stage = ChargeStages.getStage(os.clock() - chargeStartTime)

	setChargeStage(character, 0)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = originalWalkSpeed
	end
	return stage
end

-- 飛距離を叩いたプレイヤーに知らせ、ベスト記録を更新する。
-- ベストはプレイヤーの属性に持たせる（プレイヤー側へ自動で同期され、画面表示はこれを読む）。
-- DataStoreに保存するようになったら PlayerData.recordDistance に置き換える
local function reportDistance(attacker, distance, flightTime)
	local player = Players:GetPlayerFromCharacter(attacker)
	if not player then return end

	local isNewBest = distance > (player:GetAttribute("BestDistance") or 0)
	if isNewBest then
		player:SetAttribute("BestDistance", distance)
	end
	distanceResultEvent:FireClient(player, distance, flightTime, isNewBest)
end

-- Hitboxに触れたパーツを判定し、Humanoidを持つキャラクターなら吹き飛ばす
local function tryHit(hitPart)
	if not canHit or hasHitThisSwing then return end

	local attacker = tool.Parent
	local target = hitPart.Parent
	if not target or target == attacker then return end -- 自分自身を吹き飛ばさない

	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not target:FindFirstChildOfClass("Humanoid") or not targetRoot then return end

	hasHitThisSwing = true

	-- 向きは水平成分だけにする。相手との高さの差が混ざると、飛距離の計算値と実際の飛び方がずれる
	local offset = targetRoot.Position - attacker.HumanoidRootPart.Position
	local direction = Vector3.new(offset.X, 0, offset.Z)
	direction = if direction.Magnitude > 0 then direction.Unit else attacker.HumanoidRootPart.CFrame.LookVector

	local power, angle = Knockback.resolve(swingMultiplier)
	CharacterLauncher.launch(target, Knockback.getVelocity(direction, power, angle))
	reportDistance(attacker, Knockback.getDistance(power, angle), Knockback.getFlightTime(power, angle))
end

local function swing(stage)
	isSwinging = true
	swingMultiplier = ChargeStages.getMultiplier(stage)
	canHit = true
	hasHitThisSwing = false

	-- 相手に密着して振ると、振り始めの時点で既にHitboxが重なっていることがある。
	-- Touchedは「新しく触れた瞬間」しか発火しないため、振った瞬間の重なりも直接チェックする
	for _, part in ipairs(hitbox:GetTouchingParts()) do
		tryHit(part)
	end

	task.wait(CombatConfig.Swing.HitWindow)
	canHit = false
	task.wait(CombatConfig.Swing.Cooldown)
	isSwinging = false
end

-- R2を押した（マウスなら左ボタンを押した）瞬間：溜め開始
tool.Activated:Connect(function()
	if chargingCharacter or isSwinging then return end
	startCharge(tool.Parent)
end)

-- R2を離した瞬間：溜めた段階で振る
tool.Deactivated:Connect(function()
	if not chargingCharacter then return end
	swing(stopCharge())
end)

-- 溜め中にバットをしまったら、振らずに溜めを取り消す
tool.Unequipped:Connect(function()
	if chargingCharacter then
		stopCharge()
	end
end)

-- 振っている最中に相手に新しく接触した場合の判定
hitbox.Touched:Connect(tryHit)

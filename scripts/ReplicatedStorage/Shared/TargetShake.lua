-- Studio配置: ReplicatedStorage > Shared > TargetShake（ModuleScript）
-- 役割: 当たってから飛ぶまで（押し込みの間）、叩かれた相手の体を小刻みに震わせる。
--       叩いた本人は自分の当たりの予測から、他のプレイヤーはサーバーからの知らせ（Remotes.HitEffect）を受けて呼ぶ。
--       サーバーで揺らすと他のプレイヤーには通信の間隔でカクついて見えるので、各自の画面で揺らす

local RunService = game:GetService("RunService")

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))
local ChargeStages = require(script.Parent:WaitForChild("ChargeStages"))

local TargetShake = {}

-- 揺らしている間の元の C0 と、何回目の揺れか。関節に属性として持たせる（プレイヤー側で付けた属性はサーバーに送られない）
local BASE_C0_ATTRIBUTE = "ShakeBaseC0"
local COUNT_ATTRIBUTE = "ShakeCount"

-- direction は叩く向き（水平）。演出を出す当たりだけ呼ぶ（ChargeStages.hasHitEffects）。
-- gaugeResult はタイミングゲージの結果（ゲージが出る前に離したなら nil）、isCritical は会心の一撃か
function TargetShake.play(target, direction, stage, gaugeResult, isCritical)
	local rootPart = target and target:FindFirstChild("HumanoidRootPart")
	local rootJoint = rootPart and rootPart:FindFirstChild("RootJoint")
	if not rootJoint then return end

	local feedback = ChargeStages.getHitFeedback(stage, gaugeResult, isCritical)
	local duration = ChargeStages.getLaunchDelay(feedback) -- 相手が飛ぶまで
	local frequency = CombatConfig.HitFeedback.TargetShake.Frequency
	-- 叩く向きに垂直な横方向へ揺らす（叩く向きに揺らすと、押し込みの動きに紛れて見えにくい）
	local sideAxis = Vector3.yAxis:Cross(direction)

	-- 揺れている最中にもう一度当たったときは、ずれた C0 ではなく揺れる前の C0 を基準にする
	local baseC0 = rootJoint:GetAttribute(BASE_C0_ATTRIBUTE) or rootJoint.C0
	rootJoint:SetAttribute(BASE_C0_ATTRIBUTE, baseC0)
	local count = (rootJoint:GetAttribute(COUNT_ATTRIBUTE) or 0) + 1
	rootJoint:SetAttribute(COUNT_ATTRIBUTE, count)

	-- 胴体を HumanoidRootPart につなぐ関節の位置をずらすと、体の見た目だけが動く。
	-- HumanoidRootPart は動かないので、当たり判定や飛距離には影響しない（サーバーはこの関節を変えないので、上書きもされない）
	local startTime = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if rootJoint:GetAttribute(COUNT_ATTRIBUTE) ~= count then
			connection:Disconnect() -- 後から始まった揺れに任せる
			return
		end
		local elapsed = os.clock() - startTime
		if elapsed >= duration or not rootJoint.Parent then
			connection:Disconnect()
			rootJoint.C0 = baseC0
			rootJoint:SetAttribute(BASE_C0_ATTRIBUTE, nil)
			return
		end
		-- 左右へ交互にパッと振る（なめらかに揺らすより、ガタガタした震えに見える）。だんだん弱める
		local sign = if math.floor(elapsed * frequency * 2) % 2 == 0 then 1 else -1
		local offset = sideAxis * (feedback.TargetShake * sign * (1 - elapsed / duration))
		-- C0 は HumanoidRootPart から見た値なので、ずらす向きもそこから見た向きに直す
		rootJoint.C0 = CFrame.new(rootPart.CFrame:VectorToObjectSpace(offset)) * baseC0
	end)
end

return TargetShake

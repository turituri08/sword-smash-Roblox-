-- Studio配置: ServerScriptService > Ragdoll（ModuleScript）
-- 役割: キャラクターをラグドール（関節がぶらぶらの人形）にし、また元に戻して起き上がらせる。
--       胴体以外の関節（Motor6D）を止め、同じ位置を可動域つきの関節（BallSocketConstraint）でつなぐ。
--       モジュールは全キャラクターで共有されるため状態は持たず、作った部品はキャラクターの中から名前で探す。

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)

local Ragdoll = {}

local SOCKET_NAME = "RagdollSocket"
local ATTACHMENT_NAME = "RagdollAttachment"
local COLLIDE_ATTRIBUTE = "RagdollMadeCollidable" -- ラグドールの間だけ地面とぶつかるようにした部位の印
local FRICTION_ATTRIBUTE = "RagdollChangedFriction" -- ラグドールの間だけ摩擦を変えた部位の印

-- ラグドールにする関節。HumanoidRootPart と胴体をつなぐ関節（RootJoint）は残し、HumanoidRootPart を胴体についてこさせる
local function getLimbMotors(character)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local motors = {}
	for _, motor in ipairs(character:GetDescendants()) do
		if motor:IsA("Motor6D") and motor.Part0 and motor.Part1 and motor.Part0 ~= rootPart then
			table.insert(motors, motor)
		end
	end
	return motors
end

function Ragdoll.isEnabled(character)
	return character:FindFirstChild(SOCKET_NAME, true) ~= nil
end

-- motor の位置に可動域つきの関節を作る。
-- BallSocketConstraint は Attachment の X 軸を中心に円錐の範囲（UpperAngle）で振れ、X 軸まわりに TwistLower〜TwistUpper だけねじれる。
-- X 軸を手足（頭）の伸びる向きに合わせ、立ち姿勢で2つの Attachment が重なるように置く（立ち姿勢が可動域の中心になる）
local function createSocket(motor)
	local limits = CombatConfig.Ragdoll.Joints[motor.Name] or CombatConfig.Ragdoll.DefaultJoint

	-- 関節が部位の上端にあれば下向き（腕・脚）、下端にあれば上向き（頭）が伸びる向き
	local limbAxis = if motor.C1.Position.Y < 0 then Vector3.yAxis else -Vector3.yAxis
	local attachment1 = Instance.new("Attachment")
	attachment1.Name = ATTACHMENT_NAME
	attachment1.CFrame = CFrame.fromMatrix(motor.C1.Position, limbAxis, Vector3.xAxis)
	attachment1.Parent = motor.Part1

	-- 立ち姿勢では Part1 = Part0 * C0 * C1:Inverse() なので、同じ位置・向きを Part0 から見た値に直す
	local attachment0 = Instance.new("Attachment")
	attachment0.Name = ATTACHMENT_NAME
	attachment0.CFrame = motor.C0 * motor.C1:Inverse() * attachment1.CFrame
	attachment0.Parent = motor.Part0

	local socket = Instance.new("BallSocketConstraint")
	socket.Name = SOCKET_NAME
	socket.Attachment0 = attachment0
	socket.Attachment1 = attachment1
	socket.LimitsEnabled = true
	socket.UpperAngle = limits.UpperAngle
	socket.TwistLimitsEnabled = true
	socket.TwistLowerAngle = limits.TwistLowerAngle
	socket.TwistUpperAngle = limits.TwistUpperAngle
	socket.Parent = motor -- 戻すときに motor から探せるよう、motor の中に置く
end

function Ragdoll.enable(character)
	if Ragdoll.isEnabled(character) then return end -- 倒れている間にもう一度叩かれた
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	-- 首の関節を止めると、Humanoid は首が取れたとみなして倒してしまうため、ラグドールの間だけその判定を切る
	humanoid.RequiresNeck = false
	for _, motor in ipairs(getLimbMotors(character)) do
		createSocket(motor)
		motor.Enabled = false
		-- 普段は地面とぶつからない部位（R6 の腕と脚）も、ラグドールの間はぶつかるようにする（そのままだと地面にめり込む）
		if not motor.Part1.CanCollide then
			motor.Part1.CanCollide = true
			motor.Part1:SetAttribute(COLLIDE_ATTRIBUTE, true)
		end
	end

	-- 関節を切った体は Humanoid の踏ん張りが効かず、素材の摩擦だけでは着地後に氷の上のように滑るため、摩擦を上げる。
	-- 相手（地面）の摩擦より優先させるため、FrictionWeight を大きくする。独自の物理設定を持つ部位には手を付けない
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and not part.CustomPhysicalProperties then
			local density = part.CurrentPhysicalProperties.Density -- 重さは元の素材のまま
			part.CustomPhysicalProperties = PhysicalProperties.new(density, CombatConfig.Ragdoll.Friction, 0, 100, 1)
			part:SetAttribute(FRICTION_ATTRIBUTE, true)
		end
	end
end

-- 立ったときの、HumanoidRootPart の中心の地面からの高さ
local function getStandingHeight(character, humanoid, rootPart)
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		local leg = character:FindFirstChild("Left Leg")
		return rootPart.Size.Y / 2 + (if leg then leg.Size.Y else 2)
	end
	return rootPart.Size.Y / 2 + humanoid.HipHeight
end

-- 倒れていたときの向きを水平にした、起き上がった後に向く方角。
-- 仰向け・うつ伏せで体の正面が真上・真下を向いているときは、頭の向きを使う
local function getFacing(rootPart)
	for _, vector in ipairs({ rootPart.CFrame.LookVector, rootPart.CFrame.UpVector }) do
		local flat = Vector3.new(vector.X, 0, vector.Z)
		if flat.Magnitude > 0.3 then return flat.Unit end
	end
	return Vector3.zAxis
end

-- ラグドールを解き、GetUpTime 秒かけて起き上がらせる。起き上がり終わるまで待ってから戻る
function Ragdoll.disable(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local tweenInfo = TweenInfo.new(CombatConfig.Ragdoll.GetUpTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	-- 手足: 関節を「今の崩れた角度」から戻し始め、元の角度へなめらかに戻す（そのまま戻すと、手足が1フレームで立ち姿勢へ飛ぶ）
	for _, motor in ipairs(getLimbMotors(character)) do
		local socket = motor:FindFirstChild(SOCKET_NAME)
		if socket then
			local originalC0 = motor.C0
			-- Part1 = Part0 * C0 * C1:Inverse() を C0 について解くと、今の位置関係を保つ C0 になる
			motor.C0 = motor.Part0.CFrame:ToObjectSpace(motor.Part1.CFrame) * motor.C1
			motor.Enabled = true
			TweenService:Create(motor, tweenInfo, { C0 = originalC0 }):Play()
			socket.Attachment0:Destroy()
			socket.Attachment1:Destroy()
			socket:Destroy()
		end
		if motor.Part1:GetAttribute(COLLIDE_ATTRIBUTE) then
			motor.Part1.CanCollide = false
			motor.Part1:SetAttribute(COLLIDE_ATTRIBUTE, nil)
		end
	end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute(FRICTION_ATTRIBUTE) then
			part.CustomPhysicalProperties = nil
			part:SetAttribute(FRICTION_ATTRIBUTE, nil)
		end
	end
	humanoid.RequiresNeck = true

	-- 体: 今の倒れた向きから、地面に立った向きへ回す。
	-- 固定した HumanoidRootPart を動かすと、関節でつながった体全体がついてくる
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local ground = workspace:Raycast(rootPart.Position, Vector3.new(0, -10, 0), params)
	local groundY = if ground then ground.Position.Y else rootPart.Position.Y
	local standPosition = Vector3.new(rootPart.Position.X, groundY + getStandingHeight(character, humanoid, rootPart), rootPart.Position.Z)

	rootPart.Anchored = true
	local tween = TweenService:Create(rootPart, tweenInfo, {
		CFrame = CFrame.lookAt(standPosition, standPosition + getFacing(rootPart)),
	})
	tween:Play()
	tween.Completed:Wait()
	rootPart.Anchored = false
end

return Ragdoll

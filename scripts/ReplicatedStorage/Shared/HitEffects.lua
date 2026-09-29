-- Studio配置: ReplicatedStorage > Shared > HitEffects（ModuleScript）
-- 役割: 当たった場所に、相手から弾けるトゲの星・衝撃波の輪・火花を、溜めの段階色（タイミングゲージが緑・赤ならその色）で出す。どれも光る部品で作り、はっきりした形に見せる。
--       演出はプレイヤー側で作り、毎フレーム動かす（サーバーで動かすと、他のプレイヤーには通信の間隔でカクついて見える）。
--       叩いた本人は自分の当たりの予測から、他のプレイヤーはサーバーからの知らせ（Remotes.HitEffect）を受けて呼ぶ。
--       当たった場所の計算はサーバーも使うので、ここに置く

local RunService = game:GetService("RunService")

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))
local ChargeStages = require(script.Parent:WaitForChild("ChargeStages"))

local HitEffects = {}

local WHITE = Color3.new(1, 1, 1)

-- 叩かれた部位の表面のうち、fromPosition（Hitbox の中心）に一番近い点。
-- 部位の中心に出すと体に埋もれて見えにくいため、表面に出す
function HitEffects.getContactPoint(hitPart, fromPosition)
	local localPoint = hitPart.CFrame:PointToObjectSpace(fromPosition)
	local half = hitPart.Size / 2
	return hitPart.CFrame:PointToWorldSpace(Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		math.clamp(localPoint.Y, -half.Y, half.Y),
		math.clamp(localPoint.Z, -half.Z, half.Z)
	))
end

-- 溜めの段階色（ChargeEffects.Stages と同じ色）
local function getColor(stage)
	local stages = CombatConfig.ChargeEffects.Stages
	return stages[math.min(stage, #stages)].Color
end

-- 星・衝撃波・火花を作る光る部品。見た目だけなので、当たり判定・影・レイキャストの対象から外す
local function createEffectPart(className, color)
	local part = Instance.new(className)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	-- プレイヤー側で作った部品は他の人には見えない。Camera の下に置いて、ゲームの部品と混ざらないようにする
	part.Parent = workspace.CurrentCamera
	return part
end

-- duration 秒のあいだ毎フレーム update(経過秒数) を呼んで部品を動かし、終わったら parts を片付ける
local function animateParts(parts, duration, update)
	local startTime = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed >= duration then
			connection:Disconnect()
			for _, part in ipairs(parts) do
				part:Destroy()
			end
			return
		end
		update(elapsed)
	end)
end

-- トゲ1本の片側。くさび形（WedgePart）は、底の辺の前端（LookVector の側）がとがった直角三角形の柱なので、
-- 底の辺をトゲの軸に、とがった端をトゲの先に合わせる。軸の両側に1つずつ置くと、二等辺三角形のトゲになる
local function placeSpikeHalf(wedge, center, axis, side, length, halfWidth, thickness)
	local back = -axis -- くさび形の +Z（奥）は、とがった端の反対側
	wedge.Size = Vector3.new(thickness, halfWidth, length)
	wedge.CFrame = CFrame.fromMatrix(center + axis * (length / 2) + side * (halfWidth / 2), side:Cross(back), side, back)
end

-- トゲの星を1つ出す。星の面は毎フレーム見ている人のカメラに向けるので、どの角度から見ても星形に見える。
-- 白い芯のトゲの後ろに、ひと回り大きい段階色のトゲを重ねて、縁取りのようにくっきり見せる
local function playBurst(position, radius, color)
	local burst = CombatConfig.HitFeedback.Burst
	local camera = workspace.CurrentCamera
	local startAngle = math.random() * 2 * math.pi -- 毎回向きを変えて、同じ形が続かないようにする

	local layers = {
		{ color = color, scale = burst.OutlineScale, depth = -0.05 }, -- 縁は少し奥に置いて、白い芯を手前に描く
		{ color = WHITE, scale = 1, depth = 0 },
	}
	local parts = {}
	local spikes = {}
	for _, layer in ipairs(layers) do
		for index = 1, burst.SpikeCount do
			local halves = { createEffectPart("WedgePart", layer.color), createEffectPart("WedgePart", layer.color) }
			table.insert(parts, halves[1])
			table.insert(parts, halves[2])
			table.insert(spikes, {
				layer = layer,
				angle = startAngle + (index - 1) * 2 * math.pi / burst.SpikeCount,
				length = radius * layer.scale * (if index % 2 == 0 then burst.ShortRatio else 1),
				halves = halves,
			})
		end
	end
	local core = createEffectPart("Part", WHITE)
	core.Shape = Enum.PartType.Ball
	table.insert(parts, core)

	animateParts(parts, burst.OpenTime + burst.HoldTime + burst.FadeTime, function(elapsed)
		-- 開く: 一気に伸びて（最初が速い）、少し止まり、細くなりながら少しだけ伸びて消える
		local lengthScale, widthScale
		if elapsed < burst.OpenTime then
			local t = elapsed / burst.OpenTime
			lengthScale, widthScale = 1 - (1 - t) ^ 3, 1
		else
			local t = math.max(elapsed - burst.OpenTime - burst.HoldTime, 0) / burst.FadeTime
			lengthScale, widthScale = 1 + 0.15 * t, 1 - t
		end

		-- 星の面をカメラに向けるための軸。toCamera が面の向き、right と up が面の中の向き
		local toCamera = camera.CFrame.Position - position
		toCamera = if toCamera.Magnitude > 0 then toCamera.Unit else Vector3.zAxis
		local right = toCamera:Cross(Vector3.yAxis)
		right = if right.Magnitude > 0.01 then right.Unit else Vector3.xAxis
		local up = right:Cross(toCamera)
		local center = position + toCamera * burst.CameraOffset

		for _, spike in ipairs(spikes) do
			local axis = right * math.cos(spike.angle) + up * math.sin(spike.angle)
			local side = toCamera:Cross(axis)
			local length = math.max(spike.length * lengthScale, 0.01)
			local halfWidth = math.max(spike.length * burst.SpikeWidth / 2 * widthScale, 0.01)
			local spikeCenter = center + toCamera * spike.layer.depth
			placeSpikeHalf(spike.halves[1], spikeCenter, axis, side, length, halfWidth, 0.05)
			placeSpikeHalf(spike.halves[2], spikeCenter, axis, -side, length, halfWidth, 0.05)
		end
		local coreDiameter = math.max(radius * burst.CoreSize * (if elapsed < burst.OpenTime then lengthScale else widthScale), 0.01)
		core.Size = Vector3.one * coreDiameter
		core.Position = center + toCamera * 0.05
	end)
end

-- 衝撃波の輪を1つ出す。光る板を円に並べ、normal（相手が飛ぶ向き）に垂直な面で広げる。
-- 画面に向けず立体的に傾けて、空気を押し広げるように見せる。
-- 白い輪の外側に段階色の輪を並べて、星と同じく縁取りのようにくっきり見せる（同じ面で重ならないので、ちらつかない）
local function playShockwave(position, normal, radius, color)
	local shockwave = CombatConfig.HitFeedback.Shockwave
	local segmentCount = shockwave.SegmentCount

	-- 輪の面の中の2つの向き
	local u = normal:Cross(Vector3.yAxis)
	u = if u.Magnitude > 0.01 then u.Unit else Vector3.xAxis
	local v = normal:Cross(u)

	local parts = {}
	local segments = {}
	for index = 1, segmentCount do
		local angle = (index - 1) * 2 * math.pi / segmentCount
		local segment = {
			radial = u * math.cos(angle) + v * math.sin(angle),
			white = createEffectPart("Part", WHITE),
			outline = createEffectPart("Part", color),
		}
		table.insert(parts, segment.white)
		table.insert(parts, segment.outline)
		table.insert(segments, segment)
	end

	-- 板を輪の半径方向に innerRadius〜outerRadius の帯として置く
	local function placeBand(part, radial, innerRadius, outerRadius)
		local width = math.max(outerRadius - innerRadius, 0.01)
		-- 外周で隙間ができないよう、外側の半径で円に外接する多角形の辺の長さにする
		local length = 2 * outerRadius * math.tan(math.pi / segmentCount)
		part.Size = Vector3.new(length, width, 0.05)
		part.CFrame = CFrame.fromMatrix(position + radial * ((innerRadius + outerRadius) / 2), normal:Cross(radial), radial)
	end

	animateParts(parts, shockwave.Time, function(elapsed)
		-- 小さな輪から一気に広がり（最初が速い）、広がりながら細くなって消える
		local t = elapsed / shockwave.Time
		local ringRadius = radius * (shockwave.StartRatio + (1 - shockwave.StartRatio) * (1 - (1 - t) ^ 3))
		local whiteWidth = radius * shockwave.Thickness * (1 - t)
		local outlineWidth = whiteWidth * shockwave.OutlineRatio
		for _, segment in ipairs(segments) do
			placeBand(segment.white, segment.radial, ringRadius - whiteWidth, ringRadius)
			placeBand(segment.outline, segment.radial, ringRadius, ringRadius + outlineWidth)
		end
	end)
end

-- 火花を出す。光る細い棒を、direction（相手が飛ぶ向き）を中心にした円錐へ飛び散らせる。
-- 棒は毎フレーム飛ぶ向きにそろえ、長さを速さに比例させて、流れる線に見せる（断面が正方形なので、どの角度からも線に見える）
local function playSparks(position, direction, count, color)
	local sparks = CombatConfig.HitFeedback.Sparks
	local base = CFrame.lookAt(Vector3.zero, direction)
	local gravity = Vector3.new(0, -sparks.Gravity, 0)

	local parts = {}
	local list = {}
	for _ = 1, count do
		-- 円錐の中の向き: 中心から最大 Spread 度まで傾け、傾ける向きはランダム。
		-- 傾きを平方根でならすと、円錐の中心に偏らず均等に散らばる
		local tilt = math.rad(sparks.Spread) * math.sqrt(math.random())
		local roll = math.random() * 2 * math.pi
		local sparkDirection = (base * CFrame.Angles(0, 0, roll) * CFrame.Angles(tilt, 0, 0)).LookVector
		local part = createEffectPart("Part", if math.random() < sparks.WhiteRatio then WHITE else color)
		table.insert(parts, part)
		table.insert(list, {
			part = part,
			position = position,
			velocity = sparkDirection * (sparks.SpeedMin + math.random() * (sparks.SpeedMax - sparks.SpeedMin)),
			lifetime = sparks.Lifetime * (0.6 + 0.4 * math.random()), -- 消えるタイミングをばらして、一斉に消えないようにする
		})
	end

	local previous = 0
	animateParts(parts, sparks.Lifetime, function(elapsed)
		local dt = elapsed - previous
		previous = elapsed
		for _, spark in ipairs(list) do
			if elapsed >= spark.lifetime then
				spark.part.Transparency = 1
				continue
			end
			-- 空気で減速しながら（Drag）、重力で落ちる
			spark.velocity = spark.velocity * math.exp(-sparks.Drag * dt) + gravity * dt
			spark.position += spark.velocity * dt
			local speed = spark.velocity.Magnitude
			if speed < 0.01 then continue end
			local width = sparks.Width * (1 - elapsed / spark.lifetime) -- 細くなりながら消える
			local length = math.max(speed * sparks.StreakTime, width)
			local heading = spark.velocity / speed
			-- 先端が今の位置、尾が飛んできた側に伸びる
			local center = spark.position - heading * (length / 2)
			spark.part.Size = Vector3.new(width, width, length)
			spark.part.CFrame = CFrame.lookAt(center, center + heading)
		end
	end)
end

-- stage は1以上（溜めなしの当たりには演出を出さないので、呼ぶ側で除く）。
-- gaugeResult はタイミングゲージの結果（ゲージが出る前に離したなら nil）。緑・赤なら大きさと色が変わる
function HitEffects.play(position, direction, stage, gaugeResult)
	local feedback = ChargeStages.getHitFeedback(stage, gaugeResult)
	local color = feedback.Color or getColor(stage)

	-- 相手が飛ぶ向き（打ち出す角度で斜め上）。衝撃波の輪の面の向きと、火花の飛ぶ向きに使う
	local launchAngle = math.rad(CombatConfig.Launch.Angle)
	local launchDirection = direction * math.cos(launchAngle) + Vector3.yAxis * math.sin(launchAngle)

	-- 相手から弾けるトゲの星。当たった瞬間（バチ）と、押し込まれた相手が飛ぶ瞬間（コーン）の二拍子で出す
	playBurst(position, feedback.BurstSize, color)
	task.delay(feedback.ImpactDuration * CombatConfig.HitFeedback.LaunchAt, function()
		local launchPosition = position + direction * feedback.PushDistance -- 押し込まれたぶんずらす
		playBurst(launchPosition, feedback.BurstSize * CombatConfig.HitFeedback.Burst.LaunchRatio, color)
	end)

	-- 衝撃波の輪: 当たった瞬間に星と同時に出し、星より外まで広げる（ミスのときは出さない）
	if feedback.ShockwaveSize > 0 then
		playShockwave(position, launchDirection, feedback.ShockwaveSize, color)
	end

	-- 火花: 相手が飛ぶ向きへ円錐状に飛び散り、落ちながら消える（ミスのときは出さない）
	if feedback.SparkCount > 0 then
		playSparks(position, launchDirection, feedback.SparkCount, color)
	end
end

return HitEffects

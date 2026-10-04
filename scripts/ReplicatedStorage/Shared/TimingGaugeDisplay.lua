-- Studio配置: ReplicatedStorage > Shared > TimingGaugeDisplay（ModuleScript）
-- 役割: タイミングゲージの見た目（キャラクターの横に出る三日月形の弧）を作り、下の端から今の位置までを塗りつぶす。
--       作った BillboardGui を返すだけで、状態は持たない（持ち主は Bat の LocalScript）。
--       プレイヤー側で作るので、叩く本人にだけ見える

local TweenService = game:GetService("TweenService")

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))
local TimingGauge = require(script.Parent:WaitForChild("TimingGauge"))

local TimingGaugeDisplay = {}

local SEGMENTS_NAME = "Segments"

-- GUI には曲線を描く部品がないので、小さな四角を弧に沿って並べ、それぞれを弧の向きに回して曲がった帯に見せる。
-- ゲージは正方形の中に作り、位置も大きさも正方形の一辺に対する割合で決める（縦横の割合が同じなので、回しても形が崩れない）
local function createArc(billboard)
	local display = CombatConfig.TimingGauge.Display
	local count = display.SegmentCount
	local halfAngle = math.rad(display.ArcAngle) / 2
	local radius = display.Radius
	-- 弧の中心を左に置き、右へふくらむ弧が正方形の左右の真ん中に来るようにする
	local centerX = 0.5 - radius * (1 + math.cos(halfAngle)) / 2
	-- 隙間が見えないよう、部品を少し長くして隣と重ねる
	local length = radius * math.rad(display.ArcAngle) / count * 1.15

	local segments = Instance.new("Folder")
	segments.Name = SEGMENTS_NAME
	segments.Parent = billboard

	for index = 1, count do
		local middle = (index - 0.5) / count -- この部品が受け持つゲージ上の位置（0が下の端、1が上の端）
		local angle = -halfAngle + middle * 2 * halfAngle -- 真右を0とし、上へ向かって増える角度
		-- GUI の縦位置は上から数えるので、上向きの角度を下向きの位置に直す
		local position = UDim2.fromScale(centerX + radius * math.cos(angle), 0.5 - radius * math.sin(angle))
		-- 弧の接線の向きに回す。GUI の Rotation は時計回りなので、反時計回りの角度にマイナスを付ける
		local rotation = -math.deg(angle) - 90
		-- 真ん中を太く、両端を細くして三日月形にする
		local thickness = display.MinThickness + (display.MaxThickness - display.MinThickness) * math.sin(math.pi * middle)

		local function createPart(extra, zIndex)
			local part = Instance.new("Frame")
			part.BorderSizePixel = 0
			part.AnchorPoint = Vector2.new(0.5, 0.5)
			part.Position = position
			part.Rotation = rotation
			part.Size = UDim2.fromScale(length + extra, thickness + extra)
			part.ZIndex = zIndex
			return part
		end

		-- 後ろにひと回り大きい黒い部品を重ねて、縁取りのようにくっきり見せる
		local outline = createPart(display.OutlineThickness * 2, 1)
		outline.BackgroundColor3 = display.OutlineColor
		outline.Parent = billboard

		local segment = createPart(0, 2)
		segment.Name = tostring(index)
		segment:SetAttribute("Middle", middle)
		segment:SetAttribute("Zone", TimingGauge.getZone(middle))
		segment.Parent = segments
	end
end

-- rootPart の横にゲージを出し、BillboardGui を返す。parent は PlayerGui（自分の画面にだけ出す）
function TimingGaugeDisplay.create(rootPart, parent)
	local display = CombatConfig.TimingGauge.Display

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TimingGauge"
	billboard.Adornee = rootPart
	billboard.Size = UDim2.fromScale(display.Size, display.Size) -- BillboardGui の Scale は stud 単位
	-- StudsOffset はカメラから見た向きでずらすので、どこから見てもキャラクターの画面上の右横に出る
	billboard.StudsOffset = display.Offset
	billboard.AlwaysOnTop = true -- 体や相手に隠れないようにする
	billboard.ResetOnSpawn = false

	createArc(billboard)
	billboard.Parent = parent
	TimingGaugeDisplay.setPosition(billboard, 0)
	return billboard
end

-- ゲージ上の位置 middle の部品の虹色。時間とともに色相をずらして、虹が流れるように見せる
local function getRainbowColor(middle, value)
	local gauge = CombatConfig.TimingGauge
	local display = gauge.Display
	local hue = (middle * display.RainbowSpread - os.clock() / display.RainbowCycleTime) % 1
	return Color3.fromHSV(hue, gauge.RainbowSaturation, value)
end

-- 下の端から position（0が下の端、1が上の端）までを塗りつぶす。塗りの色は、塗りの先がある帯の色にする。
-- 虹は時間で色が流れるので、毎フレーム呼ぶ（塗りの先が動いていなくても色を更新する）
function TimingGaugeDisplay.setPosition(billboard, position)
	local display = CombatConfig.TimingGauge.Display
	local fillZone = TimingGauge.getZone(position)
	for _, segment in ipairs(billboard[SEGMENTS_NAME]:GetChildren()) do
		local middle = segment:GetAttribute("Middle")
		local zone = segment:GetAttribute("Zone")
		if middle <= position then
			segment.BackgroundColor3 = if fillZone == "Rainbow" then getRainbowColor(middle, 1) else display.FillColors[fillZone]
		elseif zone == "Rainbow" then
			segment.BackgroundColor3 = getRainbowColor(middle, display.RainbowEmptyValue)
		else
			segment.BackgroundColor3 = display.EmptyColors[zone]
		end
	end
end

-- 離した位置で止めたゲージを、一瞬大きくしてから元の大きさへ弾むように戻し、結果を目立たせる
function TimingGaugeDisplay.popResult(billboard)
	local display = CombatConfig.TimingGauge.Display
	local popSize = display.Size * display.ResultPopScale
	billboard.Size = UDim2.fromScale(popSize, popSize)
	TweenService:Create(billboard, TweenInfo.new(display.ResultPopTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(display.Size, display.Size),
	}):Play()
end

return TimingGaugeDisplay

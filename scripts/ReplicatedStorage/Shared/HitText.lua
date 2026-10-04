-- Studio配置: ReplicatedStorage > Shared > HitText（ModuleScript）
-- 役割: 当たったときのアメコミ風の文字（weak... / NICE! / GREAT!! / SMAAAASH!!!）を、タイミングゲージの結果に合わせて出す。
--       当たった瞬間の相手の頭の右上に固定し（飛んでいく体は追わない）、言葉全体を右下がりに傾けてその場にパッと出す。
--       プレイヤー側でだけ使い、叩いた本人（Bat の LocalScript）と叩かれた本人（HitEffectReceiver）の画面にだけ出す。
--       文字は BillboardGui の部品で作る（画像のアップロードは不要）

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))

local HitText = {}

local BLACK = Color3.new(0, 0, 0)
-- 文字はこの大きさ（ピクセル）で作り、UIScale で拡大縮小する。
-- TextSize は100が上限で、大きな画面で近くから見ると足りないため。縁の太さも一緒に拡大縮小される
local BASE_TEXT_SIZE = 100

-- 0〜1 を、最初が速く最後がゆっくりになる形にする
local function easeOut(t)
	return 1 - (1 - t) ^ 3
end

-- 文字ごとの幅（高さに対する割合）。Bangers は文字ごとに幅が違う（M は広く ! は狭い）ので、実際の大きさを測って並べる
local function getWidthRatio(character, font)
	local size = TextService:GetTextSize(character, BASE_TEXT_SIZE, font, Vector2.new(1000, 1000))
	return size.X / size.Y
end

-- 一瞬大きくなって戻る、ポンと弾む大きさ（1 → peak → 1）。0 から大きくすると、傾けた並びのせいで文字が降ってくるように見えるので、1 から弾ませる
local function popScale(t, peak)
	local overshootPart = 0.6 -- 時間のこの割合で peak まで大きくし、残りで1に戻す
	if t < overshootPart then
		return 1 + (peak - 1) * easeOut(t / overshootPart)
	end
	return peak - (peak - 1) * easeOut((t - overshootPart) / (1 - overshootPart))
end

-- 文字を1つ作る。後ろの文字に結果の色の太い縁、前の文字に黒い縁を付けて、黒の外側に色の縁がある二重の縁にする
-- （UIStroke は1つの文字に1本しか効かないため、同じ文字を2枚重ねる）。
-- 縁の太さは BASE_TEXT_SIZE に対する値で一度だけ決め、大きさは返す UIScale で変える
-- zIndex が大きい文字ほど手前に描く（縁ごと重なる）
local function createLetter(parent, character, font, widthRatio, zIndex)
	local config = CombatConfig.HitText
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5) -- UIScale は AnchorPoint を中心に拡大縮小する
	holder.Size = UDim2.fromOffset(BASE_TEXT_SIZE * widthRatio, BASE_TEXT_SIZE)
	holder.BackgroundTransparency = 1
	holder.ZIndex = zIndex
	holder.Parent = parent
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = holder

	local labels = {}
	for index, name in ipairs({ "Outer", "Front" }) do
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = font
		label.Text = character
		label.TextSize = BASE_TEXT_SIZE
		label.ZIndex = index -- 色の縁の文字を奥、黒い縁の文字を手前に描く
		local stroke = Instance.new("UIStroke")
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Thickness = BASE_TEXT_SIZE * (if name == "Front" then config.StrokeRatio else config.StrokeRatio + config.OuterStrokeRatio)
		stroke.Parent = label
		label.Parent = holder
		labels[name] = { label = label, stroke = stroke }
	end
	return holder, uiScale, labels.Outer, labels.Front
end

-- 文字を出す。target は叩かれた相手のキャラクター、gaugeResult はタイミングゲージの結果（nil なら出さない）。
-- launchDelay は当たってから相手が飛ぶまでの秒数。虹のときは、その間に1文字ずつ溜めて、飛ぶ瞬間に弾けさせる
function HitText.play(target, gaugeResult, launchDelay)
	local config = CombatConfig.HitText
	local style = gaugeResult and config.Styles[gaugeResult]
	if not style then return end
	local head = target and (target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart"))
	if not head then return end

	-- 当たった瞬間の頭の位置に、見えない固定の部品を置いて文字を付ける（飛んでいく体は追わない）
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.1
	anchor.Position = head.Position
	anchor.Parent = workspace.CurrentCamera

	-- 文字の並びを決める。大きさ（stud）は文字ごとに少しずつ変え、Grow があれば先頭から最後の文字までその倍率へ少しずつ変える
	local characters = {}
	for _, codepoint in utf8.codes(style.Text) do
		table.insert(characters, utf8.char(codepoint))
	end
	local letters = {}
	local textWidth = 0
	for index, character in ipairs(characters) do
		local progress = if #characters > 1 then (index - 1) / (#characters - 1) else 0
		local height = style.LetterHeight
			* (1 + ((style.Grow or 1) - 1) * progress)
			* (1 - config.SizeJitter + 2 * config.SizeJitter * math.random())
		local widthRatio = getWidthRatio(character, config.Font)
		-- 並べる幅には、文字の両側に付く縁の太さも入れる（入れないと縁どうしが重なって読めなくなる）
		local strokeWidth = 2 * (config.StrokeRatio + config.OuterStrokeRatio)
		table.insert(letters, {
			character = character,
			height = height,
			width = height * (widthRatio + strokeWidth),
			widthRatio = widthRatio,
			rotation = (math.random() * 2 - 1) * config.MaxRotation,
			raise = (math.random() * 2 - 1) * config.RaiseJitter * height, -- 上下にも少しずらして、跳ねた並びにする
		})
		textWidth += height * (widthRatio + strokeWidth) * config.LetterSpacing
	end
	local maxHeight = 0
	for _, letter in ipairs(letters) do
		maxHeight = math.max(maxHeight, letter.height)
	end

	-- 言葉全体の傾き。右下がりに並べるので、時計回りに回す（GUI の Rotation は時計回りが正）
	local tilt = math.rad(config.Tilt)
	local cosTilt, sinTilt = math.cos(tilt), math.sin(tilt)

	-- 弧（Arc があるときだけ）。言葉の端から端までで Arc 度曲がる円の上に並べ、真ん中を高く両端を下げる（∩ の形）。
	-- 横一列のときの位置 x を円周上の長さとみなし、中心角 x / radius の位置に置く
	local arcRadius = if style.Arc then textWidth / math.rad(style.Arc) else nil
	local arcSag = if arcRadius then arcRadius * (1 - math.cos(math.rad(style.Arc) / 2)) else 0 -- 両端が下がる量

	-- 文字が弾んで大きくなったり、傾いたりしても収まる広さにする。Size の Scale は stud なので、離れるほど小さく見える
	local billboardSize = Vector2.new(textWidth + maxHeight, maxHeight * 2.5 + textWidth * sinTilt + arcSag) * config.ScaleRoom
	local gui = Instance.new("BillboardGui")
	gui.Name = "HitText"
	gui.Adornee = anchor
	gui.Size = UDim2.fromScale(billboardSize.X, billboardSize.Y)
	gui.StudsOffset = style.Offset or config.Offset -- カメラから見た向きでずらすので、どこから見ても頭の右上に出る
	gui.AlwaysOnTop = true -- 相手の体や地面に隠れないようにする
	gui.LightInfluence = 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- 重なり順を、同じ親の中の ZIndex で決める
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- 左から並べる位置と、文字ごとに出る時刻
	local x = -textWidth / 2
	for index, letter in ipairs(letters) do
		letter.x = x + letter.width * config.LetterSpacing / 2
		x += letter.width * config.LetterSpacing
		-- 弧の上の位置と、弧に沿わせる傾き（右側の文字ほど時計回りに傾く）。弧の高さの真ん中が言葉の中心に来るよう、下がる量の半分だけ上げる
		letter.lineX, letter.lineY, letter.lineRotation = letter.x, 0, 0
		if arcRadius then
			local angle = letter.x / arcRadius
			letter.lineX = arcRadius * math.sin(angle)
			letter.lineY = arcRadius * (math.cos(angle) - 1) + arcSag / 2
			letter.lineRotation = math.deg(angle)
		end
		-- 隣の文字と重なったときは、1文字目から順に手前に来るようにする
		letter.holder, letter.uiScale, letter.outer, letter.front = createLetter(gui, letter.character, config.Font, letter.widthRatio, #letters - index + 1)
		-- 当たった瞬間に全部の文字をパッと出す。虹だけは、飛ぶまでの間に1文字ずつ溜める
		letter.appearAt = if style.BuildUp then launchDelay * style.BuildUp * (index - 1) / #letters else 0
	end

	-- 消え始める時刻。虹は飛ぶ瞬間から数える
	local fadeAt = (if style.BuildUp then launchDelay else 0) + style.HoldTime
	local endAt = fadeAt + config.FadeTime

	local startTime = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed >= endAt then
			connection:Disconnect()
			gui:Destroy()
			anchor:Destroy()
			return
		end
		-- 文字の大きさはピクセルで決まるので、今の見え方（1 stud が何ピクセルか）から毎フレーム計算する
		local pixelsPerStud = gui.AbsoluteSize.Y / billboardSize.Y

		-- 消える間: 大きくなりながら（weak... は下へ垂れて縮みながら）薄くなる
		local fade = math.clamp((elapsed - fadeAt) / config.FadeTime, 0, 1)
		local transparency = fade * fade
		local fadeScale = 1 + (style.FadeScale - 1) * easeOut(fade)
		local fadeDrop = style.FadeDrop * easeOut(fade)

		for index, letter in ipairs(letters) do
			local t = elapsed - letter.appearAt
			if t < 0 then
				letter.holder.Visible = false
				continue
			end
			letter.holder.Visible = true

			local scale = 1
			if style.BuildUp then
				-- 虹: 飛ぶまでは少し小さめで溜め、飛ぶ瞬間にポンと大きく弾けさせる
				local sinceLaunch = elapsed - launchDelay
				if sinceLaunch < 0 then
					scale = style.BuildUpScale
				else
					scale = popScale(math.min(sinceLaunch / config.PopTime, 1), style.BurstPeak)
				end
			end
			scale *= fadeScale

			-- 出た後は少し震わせる（虹は溜めている間、強く震わせる）
			local jitter = config.Jitter * letter.height
			if style.BuildUp and elapsed < launchDelay then
				jitter *= style.BuildUpJitter
			end
			local jitterX = (math.random() * 2 - 1) * jitter
			local jitterY = (math.random() * 2 - 1) * jitter

			-- 並べた位置（横一列、または弧の上）を、言葉の中心を軸に右下がりへ回してから、stud の位置を BillboardGui の中の割合に直す（中心が 0, 0）
			local alongX, alongY = letter.lineX + jitterX, letter.lineY + letter.raise + jitterY
			local x = alongX * cosTilt + alongY * sinTilt
			local y = -alongX * sinTilt + alongY * cosTilt - fadeDrop
			letter.holder.Position = UDim2.fromScale(0.5 + x / billboardSize.X, 0.5 - y / billboardSize.Y)
			letter.uiScale.Scale = letter.height * scale * pixelsPerStud / BASE_TEXT_SIZE
			letter.holder.Rotation = config.Tilt + letter.lineRotation + letter.rotation

			-- 色: 虹は1文字ずつ違う色で流す
			local fillColor, outerColor = style.FillColor, style.OuterColor
			if style.Rainbow then
				local hue = (index / #letters + elapsed / config.RainbowCycleTime) % 1
				fillColor = Color3.fromHSV(hue, CombatConfig.TimingGauge.RainbowSaturation, 1)
			end
			letter.front.label.TextColor3 = fillColor
			letter.front.stroke.Color = BLACK
			letter.outer.label.TextColor3 = outerColor
			letter.outer.stroke.Color = outerColor
			for _, part in ipairs({ letter.front, letter.outer }) do
				part.label.TextTransparency = transparency
				part.stroke.Transparency = transparency
			end
		end
	end)
end

return HitText

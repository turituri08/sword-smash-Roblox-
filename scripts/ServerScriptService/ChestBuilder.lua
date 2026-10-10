-- Studio配置: ServerScriptService > ChestBuilder（ModuleScript）
-- 役割: 宝箱の見た目を部品で組み立てる（木の箱に、格の色の縁取りと錠前）。ふたの開き具合も変える。状態は持たない。
--       UIの部品と同じく、gitの写しだけで中身が分かるよう、Studioで模型を置かずにここで組み立てる。
--       部品はすべて固定（Anchored）にして、動かすときは PivotTo で置き直す（物理演算で転がらないように）。
-- 宝箱の正面は -Z（LookVector の向き）。ふたは背面の上の辺を軸に開く

local ChestBuilder = {}

local BODY_SIZE = Vector3.new(3.2, 1.8, 2.2)
local LID_HEIGHT = 0.9
local BAND_WIDTH = 0.35
local BAND_MARGIN = 0.08 -- 縁取りを箱より少し大きくして、箱の面と重なってちらつかないようにする
local WOOD_COLOR = Color3.fromRGB(120, 72, 38)

-- 宝箱の底から、真ん中（Body の中心）までの高さ。地面に置くときに使う
ChestBuilder.HALF_HEIGHT = BODY_SIZE.Y / 2

local function createPart(name, size, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- tier は CombatConfig.Chests.Tiers の1行。原点に組み立てたモデルを返す（呼んだ側が PivotTo で置く）
function ChestBuilder.build(tier)
	local model = Instance.new("Model")
	model.Name = "TreasureChest"

	-- 縁取りの色。TrimColors があれば順に塗る（虹色の箱）
	local trimIndex = 0
	local function nextTrimColor()
		trimIndex += 1
		if tier.TrimColors then
			return tier.TrimColors[(trimIndex - 1) % #tier.TrimColors + 1]
		end
		return tier.Color
	end

	local body = createPart("Body", BODY_SIZE, WOOD_COLOR, Enum.Material.WoodPlanks, model)
	body.CFrame = CFrame.new()
	model.PrimaryPart = body

	-- 箱の左右寄りを縦に巻く縁取り
	for _, x in ipairs({ -1.05, 1.05 }) do
		local band = createPart("Band", Vector3.new(BAND_WIDTH, BODY_SIZE.Y + BAND_MARGIN, BODY_SIZE.Z + BAND_MARGIN), nextTrimColor(), Enum.Material.Metal, model)
		band.CanCollide = false
		band.CFrame = CFrame.new(x, 0, 0)
	end

	-- ふた。中の部品をまとめて動かせるよう、別のモデルにする
	local lidModel = Instance.new("Model")
	lidModel.Name = "Lid"
	lidModel.Parent = model
	local lidCenter = CFrame.new(0, BODY_SIZE.Y / 2 + LID_HEIGHT / 2, 0)
	local lid = createPart("LidBody", Vector3.new(BODY_SIZE.X, LID_HEIGHT, BODY_SIZE.Z), WOOD_COLOR, Enum.Material.WoodPlanks, lidModel)
	lid.CFrame = lidCenter
	lidModel.PrimaryPart = lid
	for _, x in ipairs({ -1.05, 1.05 }) do
		local band = createPart("Band", Vector3.new(BAND_WIDTH, LID_HEIGHT + BAND_MARGIN, BODY_SIZE.Z + BAND_MARGIN), nextTrimColor(), Enum.Material.Metal, lidModel)
		band.CanCollide = false
		band.CFrame = lidCenter * CFrame.new(x, 0, 0)
	end

	-- 正面の錠前。光らせて格の色を目立たせる
	local lock = createPart("Lock", Vector3.new(0.6, 0.7, 0.2), nextTrimColor(), Enum.Material.Neon, model)
	lock.CanCollide = false
	lock.CFrame = CFrame.new(0, BODY_SIZE.Y / 2, -BODY_SIZE.Z / 2 - 0.1)
	local light = Instance.new("PointLight")
	light.Color = tier.Color
	light.Brightness = 2
	light.Range = 8
	light.Parent = lock

	return model
end

-- ふたを開く角度（度、0で閉じる）。背面の上の辺を軸に、正面側を持ち上げる
function ChestBuilder.setLidAngle(chest, degrees)
	local bodyCFrame = chest.PrimaryPart.CFrame
	local hinge = bodyCFrame * CFrame.new(0, BODY_SIZE.Y / 2, BODY_SIZE.Z / 2)
	local closedLid = bodyCFrame * CFrame.new(0, BODY_SIZE.Y / 2 + LID_HEIGHT / 2, 0)
	-- X軸まわりに正の向きへ回すと、軸より前（-Z）にある正面が上がる
	chest.Lid:PivotTo(hinge * CFrame.Angles(math.rad(degrees), 0, 0) * hinge:Inverse() * closedLid)
end

return ChestBuilder

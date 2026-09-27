-- Studio配置: ReplicatedStorage > Shared > CombatConfig（ModuleScript）
-- 役割: 戦闘まわりの調整値をまとめる。値だけを持ち、処理は書かない。
--       サーバーとプレイヤー側の両方から読むため ReplicatedStorage に置く。

local CombatConfig = {}

-- 振り（R2を離した後の動き）
CombatConfig.Swing = {
	AnimationId = "rbxassetid://522635514", -- Roblox標準の振り下ろし。Roblox所有なので自分で公開しなくても再生できる
	AnimationSpeed = 1.5, -- 再生速度の倍率（1で標準の0.5秒、1.5で約0.33秒）
	FadeTime = 0.1,       -- 構えから振りへ切り替える秒数
	HitWindow = 0.3,      -- 離してから当たり判定が有効な秒数
	Cooldown = 0.4,       -- 当たり判定が終わってから、次に溜め始められるまでの秒数
}

-- 吹っ飛ばし。溜めの倍率は BasePower にかかる（飛距離は power の2乗に比例する）
CombatConfig.Launch = {
	BasePower = 64,           -- 打ち出す速さ（stud/秒）。溜めなしで約20 stud飛ぶ
	Angle = 38.7,             -- 打ち出す角度（度、水平が0）。45で最も遠くへ飛ぶ
	MaxPower = 1000,          -- power の上限。大きくしておけば実質無効
	LandingCheckDistance = 4, -- HumanoidRootPartの下、この距離以内に地面があれば着地直前とみなす
	MaxAirTime = 10,          -- 奈落に落ちた場合などに備えた、着地待ちの上限秒数
}

-- 飛距離の表示（叩いたプレイヤーの画面にだけ出す）
CombatConfig.DistanceDisplay = {
	Unit = "m",           -- 1 stud を 1 として表示する
	ResultHoldTime = 2.5, -- 数字が止まってから消えるまでの秒数
}

-- 溜め
CombatConfig.Charge = {
	-- 押し続けた秒数がTimeに達するとその段階になる。Timeの小さい順に並べること。
	-- 段階を増やすときは行を足すだけでよい（ChargeEffects.Stages にも同じ数だけ足す）
	Stages = {
		{ Time = 0.5, Multiplier = 1.2 },
		{ Time = 1.0, Multiplier = 1.3 },
		{ Time = 1.5, Multiplier = 1.5 },
	},
	WalkSpeedMultiplier = 0.5, -- 溜め中の歩く速さ（0.5で半分）
	AnimationId = "rbxassetid://121924975433552", -- 溜め中の構え（振りかぶり）。自分のアカウントで公開したもの
	AnimationFadeTime = 0.2, -- 構えの姿勢へ移るまでの秒数（なめらかに振りかぶる）
}

-- 溜めの演出。Stages の各行は Charge.Stages の同じ段階に対応する
CombatConfig.ChargeEffects = {
	Stages = {
		{
			Color = Color3.fromRGB(255, 255, 255),
			FillTransparency = 0.8, -- 体に重ねる色の透明度（小さいほど濃く光る）
			LightBrightness = 1,
			LightRange = 8,
			BurstCount = 10,        -- 段階が上がった瞬間に弾ける粒の数
			Vibration = 0.3,        -- コントローラーの振動の強さ（0〜1）
		},
		{
			Color = Color3.fromRGB(255, 220, 80),
			FillTransparency = 0.6,
			LightBrightness = 2,
			LightRange = 10,
			BurstCount = 20,
			Vibration = 0.6,
		},
		{
			Color = Color3.fromRGB(255, 120, 40),
			FillTransparency = 0.4,
			LightBrightness = 4,
			LightRange = 12,
			BurstCount = 35,
			Vibration = 1,
		},
	},
	VibrationDuration = 0.15, -- 1回の振動の長さ（秒）
}

return CombatConfig

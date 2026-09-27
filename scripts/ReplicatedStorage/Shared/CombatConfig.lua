-- Studio配置: ReplicatedStorage > Shared > CombatConfig（ModuleScript）
-- 役割: 戦闘まわりの調整値をまとめる。値だけを持ち、処理は書かない。
--       サーバーとプレイヤー側の両方から読むため ReplicatedStorage に置く。

local CombatConfig = {}

-- 振り（R2を離した後の動き）
CombatConfig.Swing = {
	AnimationId = "rbxassetid://522635514", -- Roblox標準の振り下ろし。Roblox所有なので自分で公開しなくても再生できる
	AnimationSpeed = 1.5,     -- 溜めない振りの再生速度の倍率（1で標準の0.5秒、1.5で約0.33秒）
	ChargedSwingSpeed = 0.6,  -- 溜めた振りの、当たるまでの再生速度。遅く振り下ろして重さを出す
	CatchSpeed = 0.025,        -- 溜めた振りが当たった瞬間の引っかかりの間の再生速度。ほぼ止まるほど遅くして重さを出す
	FollowThroughSpeed = 1.5, -- 溜めた振りの、引っかかった後（空振りなら振り下ろした後）の振り抜きの再生速度
	-- 振り下ろしが一番下に届く、アニメーション上の時点（秒、再生速度1のとき）。当たり判定はここで終わる。
	-- 振りのアニメーションを差し替えたら測り直す（再生しながら RightHand の高さを記録し、最も低い時点を探す）
	ImpactTime = 0.25,
	FadeTime = 0.1,       -- 構えから振りへ切り替える秒数
	-- 当たり判定を始める、アニメーション上の時点（秒、再生速度1のとき）。
	-- 振り始めはバットが頭上にあっても相手の頭に触れてしまうため、振り下ろしが進んでから判定する。
	-- 0.09はバットの先がちょうど相手の頭のてっぺんに届く時点（3 stud離れて振った場合）
	HitStartTime = 0.09,
	HitWindowMargin = 0.05, -- 当たり判定は振り下ろしが一番下に届くまで有効（戻りの動きでは当てない）。その後の余裕の秒数
	Cooldown = 0.4,       -- 当たり判定が終わってから（押し込み中なら相手が飛んでから）、次に溜め始められるまでの秒数
}

-- 当たった瞬間の手応え。溜めの段階ごと（0 = 溜めなし）に決める。
-- 演出の設定より段階が多い場合は、最後の段階の値を使う
CombatConfig.HitFeedback = {
	Stages = {
		-- ImpactDuration: 当たった瞬間の引っかかりの秒数。この間、振りはほぼ止まり（CatchSpeed）、相手はじわじわ押し込まれる。
		--                 0なら引っかからずにすぐ飛ばす（溜めない軽い振りは素早く打ち抜く）
		-- PushDistance: その間に相手を叩かれた向きへ押し込む距離（stud）
		[0] = { ImpactDuration = 0, PushDistance = 0 },
		[1] = { ImpactDuration = 0.3, PushDistance = 1.0 },
		[2] = { ImpactDuration = 0.45, PushDistance = 1.8 },
		[3] = { ImpactDuration = 0.6, PushDistance = 2.8 },
	},
	PushTilt = 15, -- 押し込む間に相手の上体を後ろへ傾ける角度（度）
	-- 引っかかりの時間のうち、この割合の時点で相手を飛ばす（振り抜き始める少し手前）。
	-- 公開環境では相手が飛ぶのが通信の往復ぶん遅れて見えるため、早めに飛ばしてその遅れを隠す
	LaunchAt = 0.25,
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

	-- 左下の小画面（飛ばした対象を後ろの右斜め上から追いかける）。数字と同じ間だけ表示する。
	-- カメラの位置は飛ぶ向きを基準に、対象から後ろ・右・上へずらして決める
	TargetCamera = {
		WidthScale = 0.25,  -- 画面幅に対する小画面の幅（高さは16:9で決まる）
		BackDistance = 7,   -- 対象より後ろ（叩いた人の側）へずらす量（stud）
		SideDistance = 5,   -- 飛ぶ向きに対して右へずらす量（stud）
		Height = 6,         -- 対象より上へずらす量（stud）。見下ろして飛んでいく先の地面を映す
		FieldOfView = 50,
	},
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

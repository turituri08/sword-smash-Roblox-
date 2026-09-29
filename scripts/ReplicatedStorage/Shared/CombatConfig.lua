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
		-- ShakeAngle: 叩いた人のカメラを揺らす最大の角度（度）
		-- Vibration: 当たってから引っかかりが終わるまでの、コントローラーの振動の強さ（0〜1）
		-- ShockwaveSize: 当たった場所から広がる衝撃波の輪が、広がり切ったときの半径（stud）
		-- SparkCount: 当たった場所から飛び散る火花の数
		-- Spins: 飛ばされた相手（ラグドール）が、滞空中に後ろへ回る回数
		-- BurstSize: 当たった相手から弾けるトゲの星の半径（長いトゲの長さ、stud）
		-- TargetShake: 当たってから飛ぶまで、相手の体が震える揺れ幅（stud）
		-- DownTime: 飛ばされた相手が着地して止まってから、倒れたままでいる秒数（Ragdoll.MaxDownTime を超えない）
		-- 溜めなし（0）の当たりには揺れ・振動・当たった場所の演出を出さないので、その値は持たない
		[0] = { ImpactDuration = 0, PushDistance = 0, Spins = 0.5, DownTime = 0.5 },
		[1] = { ImpactDuration = 0.3, PushDistance = 1.0, ShakeAngle = 0.8, Vibration = 0.5, ShockwaveSize = 4.5, SparkCount = 10, Spins = 0.75, BurstSize = 3, TargetShake = 0.25, DownTime = 0.65 },
		[2] = { ImpactDuration = 0.45, PushDistance = 1.8, ShakeAngle = 1.2, Vibration = 0.75, ShockwaveSize = 5.5, SparkCount = 14, Spins = 1, BurstSize = 4, TargetShake = 0.35, DownTime = 0.8 },
		[3] = { ImpactDuration = 0.6, PushDistance = 2.8, ShakeAngle = 1.8, Vibration = 1, ShockwaveSize = 6.5, SparkCount = 20, Spins = 1.5, BurstSize = 5.5, TargetShake = 0.5, DownTime = 1 },
	},
	PushTilt = 15, -- 押し込む間に相手の上体を後ろへ傾ける角度（度）
	-- 引っかかりの時間のうち、この割合の時点で相手を飛ばす（振り抜き始める手前）。飛ぶまでの間、相手は押し込まれながら震える。
	-- 公開環境では相手が飛ぶのが通信の往復ぶん遅れて見えるため、振り抜きより早めに飛ばしてその遅れを隠す（0.5 なら往復0.15秒まで隠せる）
	LaunchAt = 0.5,
	-- カメラの揺れ方（全段階で共通）
	Shake = {
		Frequency = 25,         -- 1秒に揺れる回数
		DecayTime = 0.15,       -- 当たった瞬間の揺れが収まるまでの秒数
		TrembleRatio = 0.25,    -- 引っかかりの間に続く震えの強さ（ShakeAngle に対する割合）
		LaunchPulseRatio = 0.5, -- 相手が飛ぶ瞬間の揺れの強さ（ShakeAngle に対する割合）
		SideRatio = 0.3,        -- 横の揺れの強さ（縦の揺れに対する割合）
	},
	-- 当たった場所から飛び散る火花（全段階で共通）。光る細い棒を、段階色と白を混ぜて飛ばす。数は Stages の SparkCount
	Sparks = {
		SpeedMin = 40,      -- 飛び出す速さ（stud/秒）。星と衝撃波の輪に隠れないよう、外まで勢いよく飛ばす
		SpeedMax = 80,
		Lifetime = 0.45,    -- 消えるまでの秒数（1本ずつ、この6〜10割でばらす）
		Spread = 75,        -- 広がる角度（度）。相手が飛ぶ向きを中心にした円錐。
		                    -- 叩いた人からは飛ぶ向きが画面の奥になるので、広げて横にも散らさないと放射状に見えない
		Width = 0.2,        -- 出た瞬間の太さ（stud）。細くなりながら消える
		StreakTime = 0.04,  -- 線の長さ（速さに掛ける秒数）。速いほど長い線に見える
		Gravity = 60,       -- 下へ引く強さ
		Drag = 2,           -- 空気で減速する強さ
		WhiteRatio = 0.4,   -- 白い火花の割合（残りは段階色）
	},
	-- 当たった相手から弾けるトゲの星（全段階で共通）。白い芯のトゲの後ろに段階色の縁のトゲを重ねて、くっきり見せる。
	-- 大きさは Stages の BurstSize
	Burst = {
		SpikeCount = 8,      -- トゲの本数。長いトゲと短いトゲを交互に並べる
		ShortRatio = 0.55,   -- 短いトゲの長さ（長いトゲに対する割合）
		SpikeWidth = 0.3,    -- トゲの根元の幅（長さに対する割合）
		OutlineScale = 1.3,  -- 段階色の縁のトゲの大きさ（白い芯のトゲに対する割合）
		CoreSize = 0.6,      -- 中心の白い丸の直径（星の半径に対する割合）
		OpenTime = 0.04,     -- 開き切るまでの秒数
		HoldTime = 0.05,     -- 開いたまま止まる秒数
		FadeTime = 0.12,     -- 細くなりながら消えるまでの秒数
		CameraOffset = 1.5,  -- 当たった場所からカメラ寄りに出す距離（stud）。体に埋もれず、相手の手前で弾けて見える
		LaunchRatio = 0.6,   -- 相手が飛ぶ瞬間に出す二発目の星の大きさ（一発目に対する割合）
	},
	-- 当たった場所から広がる衝撃波の輪（全段階で共通）。白い輪の外側に段階色の輪を並べて、くっきり見せる。
	-- 大きさは Stages の ShockwaveSize
	Shockwave = {
		SegmentCount = 24,  -- 輪を作る板の枚数（多いほど丸く見える）
		StartRatio = 0.3,   -- 出た瞬間の輪の大きさ（広がり切ったときに対する割合）
		Time = 0.25,        -- 広がって消えるまでの秒数
		Thickness = 0.15,   -- 出た瞬間の白い輪の太さ（半径に対する割合）。広がりながら細くなる
		OutlineRatio = 0.6, -- 段階色の輪の太さ（白い輪に対する割合）
	},
	-- 当たってから飛ぶまで、相手の体を小刻みに震わせる（全段階で共通）。揺れ幅は Stages の TargetShake
	TargetShake = {
		Frequency = 30, -- 1秒に左右を往復する回数
	},
}

-- 吹っ飛ばし。溜めの倍率は BasePower にかかる（飛距離は power の2乗に比例する）
CombatConfig.Launch = {
	BasePower = 64,           -- 打ち出す速さ（stud/秒）。溜めなしで約20 stud飛ぶ
	Angle = 38.7,             -- 打ち出す角度（度、水平が0）。45で最も遠くへ飛ぶ
	MaxPower = 1000,          -- power の上限。大きくしておけば実質無効
	LandingCheckDistance = 4, -- HumanoidRootPartの下、この距離以内に地面があれば着地直前とみなす
	MaxAirTime = 10,          -- 奈落に落ちた場合などに備えた、着地待ちの上限秒数
}

-- 吹き飛ばされる側のラグドール（関節がぶらぶらの人形になる）
CombatConfig.Ragdoll = {
	-- 関節ごとの可動域（度）。UpperAngle: 立ち姿勢から振れる角度、TwistLowerAngle〜TwistUpperAngle: 手足の軸まわりのねじれ
	Joints = {
		Neck = { UpperAngle = 30, TwistLowerAngle = -45, TwistUpperAngle = 45 },
		["Left Shoulder"] = { UpperAngle = 110, TwistLowerAngle = -70, TwistUpperAngle = 70 },
		["Right Shoulder"] = { UpperAngle = 110, TwistLowerAngle = -70, TwistUpperAngle = 70 },
		["Left Hip"] = { UpperAngle = 70, TwistLowerAngle = -30, TwistUpperAngle = 30 },
		["Right Hip"] = { UpperAngle = 70, TwistLowerAngle = -30, TwistUpperAngle = 30 },
	},
	-- 上にない関節（プレイヤーの R15 アバターの肘・膝など）
	DefaultJoint = { UpperAngle = 45, TwistLowerAngle = -30, TwistUpperAngle = 30 },
	MaxTwistSpeed = 3, -- 回転に加える、ランダムなひねりの最大の速さ（ラジアン/秒）
	Friction = 1.5,    -- ラグドールの間の体の摩擦（素材のプラスチックは0.3）。小さいと着地後に長く滑る
	-- 着地した体が転がり終わって止まったとみなす速さ（stud/秒）。倒れている時間（DownTime）は止まってから数える
	SettleSpeed = 3,
	MaxSettleTime = 1, -- 止まるのを待つ秒数の上限（転がり続けて止まらない場合に備える）
	-- 止まってから倒れたままでいる秒数の上限。秒数は溜めの段階ごと（HitFeedback.Stages の DownTime）。
	-- 強い溜めほど長く倒れるが、長すぎるとなかなか起き上がれず鬱陶しいので、どれだけ強くてもこれを超えない
	MaxDownTime = 1,
	GetUpTime = 0.3,   -- 起き上がりにかける秒数
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

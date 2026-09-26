-- Studio配置: StarterPack > Bat (Tool) > LocalScript（プレイヤー側で実行される）
-- 役割: 振りのアニメーションを再生する。ボタンへの反応を遅らせないよう、サーバーを経由せずここで再生する
--       （自分のキャラクターのアニメーションは、プレイヤー側で再生しても他のプレイヤーに同期される）

local tool = script.Parent

-- Roblox標準のAnimateスクリプトが使う振り下ろしと同じもの。Roblox所有なので自分で公開しなくても再生できる
local SLASH_ANIMATION_ID = "rbxassetid://522635514"
local SWING_SPEED = 1.5    -- 再生速度の倍率（1で標準の0.5秒、1.5で約0.33秒）
local SWING_INTERVAL = 0.7 -- サーバー側Scriptの「判定0.3秒＋クールダウン0.4秒」と揃える。
                           -- ずれると、当たり判定の出ない空振りアニメーションが再生されてしまう

local slashAnimation = Instance.new("Animation")
slashAnimation.AnimationId = SLASH_ANIMATION_ID

local slashTrack = nil
local lastSwingTime = -math.huge

-- 装備するたびに読み込み直す（リスポーンでキャラクターが替わると、古いトラックは使えなくなるため）
tool.Equipped:Connect(function()
	local humanoid = tool.Parent:FindFirstChildOfClass("Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator")
	slashTrack = animator:LoadAnimation(slashAnimation)
	-- ツールを持つ腕の姿勢（標準の待機アニメーション）より優先して再生させる
	slashTrack.Priority = Enum.AnimationPriority.Action
end)

tool.Activated:Connect(function()
	if not slashTrack then return end
	if os.clock() - lastSwingTime < SWING_INTERVAL then return end
	lastSwingTime = os.clock()
	slashTrack:Play(0.1, 1, SWING_SPEED)
end)

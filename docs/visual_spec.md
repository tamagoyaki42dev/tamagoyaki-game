# 視覚・演出仕様

## グラフィック方針

作業順：下地 → 演出土台 → 敵流用 → 背景は最後（手戻り防止）

- 下地 = 地面＋影＋ライト＋背景色（5分で仮置き）
- アセットは全部Kenneyの同じファミリーで統一（敵・背景も）
- 人型モーション = Mixamo / 非人型 = Godotアニメ
- 味方はKenney Mini Characters配置済み。次は敵→背景

## 戦闘演出

### 土台（共通BattleUnitスクリプト・Tweenで制御）
- 攻撃：予備動作0.05m後退 → 0.3m前進0.12s → 戻り0.18s
- 被弾：対象MeshのみShader uniform赤flash 0.08s ＋ 揺れ±0.05m ＋ 軽ノックバック  
  ※実装前にKenneyキャラのマテリアル構造を確認すること
- 撃破：scale=0＋傾き0.4s / squash&stretch / 着弾点にGPUParticles3D
- 全数値 `@export`。全画面演出・カメラ操作・他ユニットへの影響は禁止

### ローテーション演出（実装済み）

| 演出 | タイミング | 実装 |
|--|--|--|
| 移動 Tween | 一斉移動 | `TRANS_SINE EASE_IN_OUT` `rotate_duration`=0.55s |
| 着地スカッシュ | 着地直後 | Y縮小・XZ拡大 → 元スケールに戻す（`landing_squash_*`） |
| 到着フラッシュ | スカッシュと同時 | 全員青白くフラッシュ（`arrive_flash_*`） |
| 完了時列フラッシュ | スカッシュ完了＋0.15s後 | 前列のみゴールドフラッシュ（`front_row_flash_*`） |

### 化粧4つ（土台完成後に1個ずつ）

| 演出 | 実装 |
|--|--|
| ✅ヒットストップ | `Engine.time_scale=0.05` → `timer(ignore_time_scale)` → 1.0戻し |
| ✅カメラシェイク | `Camera3D h_offset/v_offset` を `FastNoiseLite` で（transform触らない） |
| ✅グロー/ブルーム | `WorldEnvironment glow_enabled` |
| ★ダメージ数字 | `Label3D(billboard)` 上へpos Tween＋alphaフェード＋出現scaleパンチ |

+α：HPバー追従（2枚重ね・背面遅延）/ Tween easing=`TRANS_BACK` / 背弾`OmniLight3D` / 軌跡=`GPUParticles trail_enabled`  
火花：`one_shot` ＋ `explosiveness` ＋ `color_ramp`

原則：対象・技法・数値・順序・禁止（全画面）・`@export`

# バックログ（未実装タスク）

セッション開始時に自動表示される。完了したら該当行を削除すること。完了項目の経緯は devlog を参照。

---

## プロト2（継承育成）着手中

継承育成ループの設計定義は完了（2026-07-05）。詳細は `docs/proto2_design.md`「継承育成ループの機構定義」＋`game_concept.md`「ゲームループの全体像」。以下は着手可能タスク。

### 開発ツール/デバッグ基盤（設計のみ・2026-07-13）＝着手は個別承認後

アセット化ワークフロー（体リカラー/表情プリセット/敵ツール/背景）＋スライス別デバッグ画面（戦闘直行/継承のみ/イベントシーン）の設計。詳細は `docs/dev_tooling_design.md`。推奨着手順：①体リカラー ②表情プリセット ③敵ツール ④デバッグ画面。全ツール共通方針＝**画面UIで全調整完結（エディタ往復ゼロ）**・共通ヘルパー `scripts/tools/dev_controls.gd`（数値→スライダー/bool→チェック/選択→ドロップダウン）をA2以降でも使い回す。

**【フェーズ方針・2026-07-14 ユーザー合意】次のキャラ作業（Rogueに髪+顔）の前にツールを揃える。** 次キャラは顔追従問題でブロック中／ツール群は着手可能なので先にツールを片付ける。**今やるのは A3 敵ツール・A4 背景アセット化・B1 戦闘ダイレクト**（いずれも土台あり）。**B3 イベントシーンはイベント/会話システムが未存在＝ツールでなく本体機能なので proto2 本編と一緒にやる（今は外す）。B2 継承のみは既存 `meta_loop_debug` があるので継承ループ育成時に同時**。次着手＝A3から設計案。

- [x] ~~**A1 体リカラー**~~ **実装完了（2026-07-14）**：`BodyRecolor`(.tres)＝`scripts/data/body_recolor.gd`／専用ツール`scenes/body_recolor_tool.tscn`(+`scripts/tools/body_recolor_tool.gd`)をF6起動。素体GLB共有・色差分のみ.tres。starter=`assets/kaykit/characters/recolors/rogue_recolor.tres`（服=Body#1,#2→あずき／マント=Cape#0→赤紫）。沈み自動接地＋手動高さ＋全アニメ搭載。GUT新規11テスト・フルラン301全通過。**残：目視で色味を詰める（ツールでcape/bodyのColorPicker調整）／緑は腕(ArmL/R #2,#3)・マスクにも回っており全身を揃えるならバンド追加**
- [ ] **A1後続：実ゲーム消費（P3）**：`battle_scene.gd`に`_JOB_RECOLORS`（job→.tresパス）を足し、spawn時に`recolor_part`を該当メッシュへ適用。`_JOB_TINTS`（全身乗算）は無改変で残し上乗せレイヤーにする。着手時に「detect/recolorのstaticを中立util`scripts/util/recolor.gd`へ移すか（推奨）／char_customizer参照のままか」を決める。まずツールで rogue_recolor を目視確定させてから
- [x] ~~**A2 表情プリセット**~~ **実装完了（2026-07-14）**：`FaceExpression`(.tres)＝`scripts/data/face_expression.gd`（目/まつ毛/眉/口の全パラメータ）。既存`tools/face_editor.gd`を`@tool`廃止・A1と同じ画面UI完結（`dev_controls.gd`流用）へ全面移行、保存/読込もLineEdit+Button+OptionButtonに刷新。`dev_controls.gd`に`add_color`ヘルパー追加。GUT新規6テスト・フルラン302全通過。**残：実際に「ジト目/怒/悲/笑」4プリセットをF6でツールを開いて人が調整・保存する（数値はここでは決め打ちしていない）**
- [ ] **face_editor.gd：キャラの向きが逆**（2026-07-14 ユーザーF6実機確認で発見）。旧`@tool`時代はGodotエディタの自由カメラで見ていたため気づかなかったが、今回F6実行が必須になったことで、ツール自前のCamera3D（`_build_env_and_cam()`・`cam_side`/`cam_height`/`cam_distance`固定位置）から見ると顔でなく後頭部側が見えている可能性が高い。`view_yaw_deg`のデフォルト(23.0)か、カメラの固定位置いずれかの調整で直る見込み
- [ ] A3 敵ツール（dev_controls.gd 流用）

### 【新規・2026-07-14 実測判明】自作キャラGLBの品質問題（顔/髪がアニメで動かない）

体リカラーツールでWitchを見た際に発覚。`Witch_final_reference.glb` は自作書き出しが不完全＝(1)`CustomHead`/`HairMesh`が**skin=false（Skinバインド無し）で骨に追従しない**＝歩行/攻撃で顔・髪がその場に残る (2)共有アニメ再生時にリグrest不整合で**約1.5m沈む**（ツール側は自動接地で回避済みだが**実ゲームでも沈む疑い＝要確認**）。

- [ ] **顔/髪をアニメ追従させる方針決め**（設計案先）：候補 (a)`BoneAttachment3D`で頭ボーンに剛体追従（Godot標準・再書き出し不要・推奨） (b)Blenderでアーマチュアにスキンバインド（変形追従・手作業） (c)自作顔をやめKayKit純正頭(Rogue_Head)＋髪だけ。**「Rogueにピンク髪+顔を乗せて色調整」はこれの解決が前提**（同じ作り方だと同じ壁）
- [ ] 実ゲームのWitchも沈んでいないか確認（`battle_scene`で目視。沈んでいれば同じ接地補正 or アセット修正）

### 【新規・2026-07-14 ユーザー要望】全職ちびキャラ化

Witchのちびプロポーションを全KayKit職へ拡大したい。現状 `_KAYKIT_CHIBI_JOBS=[WITCH]` のみ。`_apply_kaykit_chibi_head`＋`kaykit_chibi_body_mult` を全職に広げ、各モデルが頭スケールで破綻しないか要確認（設計/目視）。

### 継承の中身（個体値→継承式）

- **【設計論点・未反映】個体値＝「全盛期の天井」**：`roll_individual_stats()`の値は全盛期の上限で、現年齢が何%を発揮するかの**年齢カーブ関数が別途必要**（未設計）。子の継承式の前に整理する
- [ ] `from_job()`を`roll_individual_stats()`に差し替え（proto2の拠点/生成画面ができるとき）
- [ ] 子の継承式（親2人の個体値の重み付き合成）＝年齢カーブ整理の後
- [ ] 継承ループ簡易シム(v0)のテンポ確認：`scenes/meta_loop_debug.tscn`をF6→放置/防衛の仮値（放置限界150日/復活100日/引退200日）が体感と合うか（まだ一度も触っていない）

### KayKit職の見た目・表情の残り

- [ ] **表情差分プリセット**（怒り/悲しみ/笑い/ジト目）＝`face_editor`の眉/目パラメータで出せる。dev-tooling A2で切り出す
- [ ] 塗り髪は帽子キャラのハゲ感解消の保険として維持（3Dメッシュの被覆が甘い箇所を下地の髪色で隠す）
- [ ] 弓職のSE分割：引く/離す/着弾で別SE（`audio_manager.gd`）
- [ ] 巫女の赤紫チント濃度：濃すぎ/薄すぎなら`_JOB_TINTS`調整、服だけにするなら`rogue_texture.png`編集
- [ ] 顔の不満への対処：(a)別キャラHead差し替え (b)Quaternius頭をBoneAttachment (c)Blender形状編集。方針決め要
- [ ] 【設計判断・未確定】Gunner（銃手）：CombatRangedに銃モーション有り。新職追加/入替は未決（他職の削除/改名も波及しうる）。CC0銃 or クロスボウ流用要。カスタマイザーで見た目を組めてから判断
- [ ] （余裕があれば）魔術師の詠唱時に「待機中の微妙な揺れ」が見えているか再確認
- [ ] 平坦化コード(`_flatten_head_face`)・プリミティブ球(`_replace_with_primitive_head`)は`face_preview_view.gd`に残置、整理時に削除可

### クリップ選定・生命感（見た目確定後）

- [ ] **クリップ選定**：`scenes/anim_browser.tscn`で場面別に選び`_KAYKIT_CLIPS`へ反映。確定済み割当：被弾=`General/Hit_B`（dmg0は非再生）／メレー&ローテにジャンプ（滞空プロファイルをヘッドレス実測して選定）／騎士・冒険者の防御補助を物理化（前列の前へジャンプ→`Melee_Block`→戻る・設計案先）／剣闘士を2H武器化（`Melee_2H_Attack_Chop`・xform再実測）
- [ ] **動きの誇張レイヤー**：既存クリップの上に手続きで「タメ/ヒット時のスケール潰し/振りの緩急/待機の微動/被弾のけぞり」。await/Signal連鎖に触る＝GUT＋目視必須・1個ずつ

### 戦闘の見た目・音の底上げ（一次満足軸 memory `combat_presentation_north_star`）

**診断**：コード側ジュース（flash/shake/hitstop/knockback/glow/火花）は出し切り済み。不足は"音（迫力SE）と派手さ（リッチVFX）"＝アセットの格。**理想＝初代スマブラ64のヒット音・エフェクト**（地味な動きの上にspectacleを被せる）。

- [x] ~~**背景を刷新（ダンジョン/B3）**~~ **実装完了・ユーザー確認OK（2026-07-14）**。`KayKit_DungeonRemastered`から床/壁/コーナー/小道具をキュレーションし`assets/kaykit/environment/dungeon/`へ配置、新規`bg_dungeon_kaykit.gd`（既存`bg_dungeon.gd`は無改変）＋`battle_scene.gd`の`dungeon_bg_use_kaykit`トグルで切替。CLAUDE.md方針を「背景・敵はパック不問」に変更。小道具は5→10種・18→28個に増量済み。詳細devlog/2026-07-14参照。GUT新規6テスト・全286中285 PASS
- [ ] **ダンジョン背景（B3）をいずれ見直す**：ユーザー最終確認「とりあえずOK、また見直す」＝確定ではなく暫定採用。小道具の密度/種類選定/配置の再検討候補（次回着手時はF5でB3を通して見て気になる点があるか確認するところから）
- [ ] **背景を刷新（草原B1/B2・アリーナ新規ステージ）**：ダンジョンと同じ手順（KayKit_Forest_Nature_Pack／Medieval_Hexagon_Pack）で継続。既存bg_grass.gdは無改変のまま新規ファイル＋トグル方式を踏襲
- [ ] **敵グラを刷新**（派手に動いて攻撃＝満たすアセット探索 or モーション作成。現状の敵はQuaternius/Kenneyで攻撃クリップ無し＝Tween突進で代用中）
- [ ] **回復発動者にモーション**（列/自己回復とも「誰が発動か分からない」。仮＝アイテム使用モーション。await/Signal触る＝設計案先）
- [ ] **SE刷新**（Kennyは軽い＝斬撃の"ドッ"に力不足。リッチCC0を探す）
- [ ] Tier2：被弾を位置ノックバック→実クリップ(KayKit Hit_A/RecieveHit)へ格上げ／ジャンプ接近をKayKit jumpクリップ同期へ格上げ（クリップ有無要確認）

### アート画面効果

- [ ] **味方グリッドが見づらい（2026-07-14）**：頂点ボイル等の画面効果を足した影響でグリッド線が視認しづらい。`grid_cell_color`（`battle_scene.gd`・現在`Color(0.35,0.55,1.0,0.12)`）を濃く/はっきりに調整
- [ ] **②紙/粘土グレイン＋ポスタライズ**：仮採用中（`clay_paper_enabled`/`clay_grain_strength`0.10/`clay_posterize_levels`9）。本採用か差し戻しか次回判断
- [ ] **画面効果2案（未定）**：DOF（被写界深度でジオラマ風ぼかし・WorldEnvironment標準機能）／②をハーフトーン網点へ格上げ（②判断後）

## リリース（プロト1・itch）残り

- [ ] ゲーム固有アイコンの判断（現行=「たまごやきGAMES」スタジオロゴ・当面ロゴで通すか）
- [ ] itchページ確認（ユーザー作業）：新ビルドDL/起動・Draft/Public・価格説明スクショ最新か／Web版「ブラウザで遊ぶ」埋め込み有効化
- [ ] **ゲーム内クレジット画面＝リリース前必須**：Booth「Cute short pinky」(felisshoppe)が表記義務。台帳は`CREDITS.md`（唯一の真実）

## 戦闘演出化粧

- [ ] 戦闘テンポ調整の目視確認：`unit_action_show_duration`0.9/`rotate_show_duration`0.6で間延び感が出ていないか
- [ ] （リリース後）勝利・敗北演出をもう少し長く派手に
- [ ] （リリース後）戦闘速度トグル1x/2x（`Engine.time_scale`・`@export`倍率＋UI切替）

## サウンド

- [ ] （任意）`SE_ENEMY_HIT`/`SE_ENEMY_ROW`/`SE_SHIELD`は定数定義済み・未接続。敵被弾音・シールド音を鳴らすなら接続

## ロジック

- [ ] 手動プレイテストで体感勝率確認（ユーザー作業）→「もっと強く/弱く」指示。現行B1-R86%@9.9T・B2-S100%@6T・B3-A100%@6Tが基準

## SNS/広報

- [ ] YouTube/TikTokショート第2弾以降のネタ出し（devlogの`## noteネタ`に未使用ストック：敵デカすぎ/打ってない発言が勝手に送信/半年越し無断実装発覚/SVG背景が2歳児の絵/こっそりステ0/気力ないほど開発進む 等）

## プロト2以降の検討

→ `docs/proto2_design.md` へ移行済み（個体値＋偏差/手続き生成2原則/敵行動乱数/状態トグル/KayKit基盤）。プロト2着手時にそこから backlog へタスク切り出し

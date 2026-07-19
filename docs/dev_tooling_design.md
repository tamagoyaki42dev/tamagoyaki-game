# 開発ツール & デバッグ基盤 設計（2026-07-13）

※これは設計メモ。着手は各項目ごとに設計相談→承認→実装（CLAUDE.mdの新システム導入ルール）。今日は設計のみ。

## 動機

1. **アセット化ワークフロー**：背景・キャラ・パーツ・敵を「すぐ使える再利用可能な形」に整え、量産できるようにする。素体は1つ、差分はデータで持つ。
2. **スライス別デバッグ画面**：トグルシステム（proto2・必殺/切替）が入ると戦闘の組み合わせが星の数になる。生成・戦闘・イベントなど**ゲームの断片を個別に回せる画面**を先に充実させておく（組合せ検証の土台）。
3. **最終的には画面化**：アセットツール/デバッグ画面のうち運用に乗るものは拠点/継承の実画面へ昇格させる。main起動時のフロー（実ゲーム）は維持。

## 全体構造：2系統

- **A. アセット化ツール**＝再利用可能な「データ」を産む編集ツール。
- **B. スライス別デバッグ画面**＝ゲームの断片を隔離してF6単体起動する画面。

共通の作り方（既存の `tools/face_editor.gd`・`scenes/proportion_preview.tscn`・`scripts/ui/meta_loop_debug.gd` と同じ流儀）：`@tool`または独立シーン、調整は全部 `@export`、出力は Resource(.tres) か焼きファイル。main（実ゲーム）には影響させない。

**全ツール共通方針＝画面UIで全調整完結（エディタ往復ゼロ・2026-07-14 ユーザー要望）**：`@export`は「初期値の置き場」として残しつつ、起動時にその値を画面のコントロールへ写し、操作したら即プロパティへ書き戻す（＝Godotエディタのインspектор不要）。共通ヘルパー `scripts/tools/dev_controls.gd`（`class_name DevControls`）が **数値→ラベル付きHSlider／bool→CheckBox／選択肢→OptionButton／色→ColorPicker** を生成する。A2表情プリセット・A3敵ツール以降も同ヘルパーを使い回す。※B1のON/OFFトグルは「効果の有無」なのでチェックボックスのまま（連続値のみスライダー）。

## A. アセット化ツール

| # | ツール | 何を作る | 土台/データ | 初回ユースケース |
|---|---|---|---|---|
| A1 | **体リカラー**〔実装済 2026-07-14〕 | KayKit体のバンド色（服/マント等）をカラーピッカーで変更 | `scripts/tools/char_customizer.gd` の `detect_uv_color_bands`/`recolor_part`（static）を流用。データ=`BodyRecolor`(.tres)=`scripts/data/body_recolor.gd`。ツール=`scenes/body_recolor_tool.tscn` | ローグ：服=あずき濃色／マント=明るい赤紫 → starter `assets/kaykit/characters/recolors/rogue_recolor.tres` |
| A2 | **表情プリセット** | face_editorの目/まつ毛/眉/口パラメータsetを名前付き保存 | `tools/face_editor.gd`（各要素は既に`@export`）。データ=`FaceExpression`(.tres) | ジト目(現状)＋怒/悲/笑＝4種。名前で切替（イベント/戦闘反応） |
| A3 | **敵ツール** | 敵の見た目（モデル＋リカラー）と攻撃パターンを編集/プレビュー/保存 | `docs/enemy_spec.md`・`EnemyData`(.tres)・enemy_generator。リカラーはA1流用 | 敵バリエ量産 |
| A4 | **背景アセット化** | ステージ変種を再利用可能に | `visual_spec.md`「背景は最後」と整合。詳細は着手時 | 戦場の見栄え刷新 |

**設計の肝（A1・A2共通）**：**素体（glb / face_editorの生成ロジック）は1つ共有し、キャラごとの差分は小さな Resource(.tres) で持つ。** ユーザーの言う「色変えたやつは別ファイル、baseみたいな使い方」＝この.tres変種ファイル。glbを焼き直して増やすより**データ駆動が本筋**（ファイル爆発を防ぐ・CLAUDE.md「視覚＝データの関数」）。焼き版が要る場面（テクスチャベイク）だけ別途。

## B. スライス別デバッグ画面

いずれも `meta_loop_debug.tscn` と同じく **F6単体起動の独立シーン**。main（`battle_scene.tscn` 起動想定）はそのまま。

| # | 画面 | 隔離して回すもの | 備考 |
|---|---|---|---|
| B1 | **戦闘ダイレクト** | 任意の編成/敵/トグル状態で戦闘に直行（継承ループを飛ばす） | トグル組合せ検証の本命。星の数の戦闘を素早く固める |
| B2 | **継承のみ** | 戦闘を抜いた継承育成ループ→敵味方の生成を見る→「戦闘へ」ボタン | 既存 `meta_loop_debug` の発展形 |
| B3 | **イベントシーン** | 戦闘と同じ構図（キャラ＋敵配置）＋会話ウインドウ | ストーリー/イベント用の新シーン型。構図は戦闘画面流用 |

**B1の画面効果ON/OFFパネル（2026-07-14 追加・ユーザー要望）**：戦闘デバッグ画面に、大量に入れた画面効果を**各効果チェックボックス1個で個別にオン・オフ**するパネルを持たせる。対象＝粘土シェーダー／頂点ボイル／紙グレイン／ポスタライズ／輪郭線／DOF／LUT／トーンマッピング等。**数値スライダーは付けない**（ユーザー明言「ようわからん」＝ブール切替だけで十分）。実装は軽い：効果の多くは既に`battle_scene.gd`の`@export`フラグ（`clay_paper_enabled`・`lut_enabled`等）で持っているのでチェックボックスをそれに束ねるだけ、enableフラグが無い効果（頂点ボイル等）だけ`*_enabled` boolを1個ずつ足す。**用途＝各効果を単独で見て「本採用/差し戻し」を即断**（backlogの②グレイン仮採用・DOF未定・グリッド見づらい等の決着に直結）。

将来的には各デバッグ画面から中央の「開発ハブ」で全ツール/全スライスに飛べる形にすると回転が上がる（main起動＝実ゲームは不変）。

## B1＋A4統合：戦闘画面構築ツール（2026-07-15 ユーザー合意）

ユーザー要望「背景切替ツールと画面効果切替ツールを組み合わせて戦闘画面構築ツールにしたい／小物・タイルも選んで配置したい」を受け、**B1（戦闘ダイレクト＋効果ON/OFF）とA4（背景アセット化＝ステージ変種を再利用可能に）を1画面 `scenes/stage_composer.tscn` に統合**する。土台は実 `battle.tscn` を子として起動し、上に `CanvasLayer`（`PROCESS_MODE_ALWAYS`）で構築パネルを重ねる＝既存資産を最大流用。段階：

- **P1〔実装済 2026-07-15〕**：実 battle_scene への生コントロールのみ。背景切替（草原/ダンジョンKenney/ダンジョンKayKit）・画面効果ON/OFF（輪郭線/紙グレイン/頂点ボイル/霧/LUTはライブ、粘土ベースはリスタート反映）・戦闘の開始停止（`SceneTree.paused`）/リスタート。battle_scene に公開API（`rebuild_background` / `set_*_enabled` / `background_variant_override` / `preview_mode`）を追加。**StageLayout・配置はまだ無い。** 残＝目視で各効果と背景切替が実機で正しく反映されるか確認。
- **P2**：小物/タイルのクリック配置。データ `StageLayout`(.tres)＝`background_base`＋`Array[StagePlacement]`（`asset_path`/`pos`/`rot_deg`/`scale`/`kind`）。現状の `bg_dungeon_kaykit.gd` の const 配列（`_TILE_PATTERN`/`_PROPS`/`_WALLS`）を初期 StageLayout へ移行。パレット選択→3D地面へレイキャストで設置（タイルは4.0グリッドにスナップ）・回転45°刻み/スケール段階ボタン（スライダー禁止方針）・保存/読込（LineEdit+Button）。CLAUDE.md「座標のコード直書き禁止／視覚＝データの関数」に一致。
- **P3**：配置済みプロップの選択・移動（当たり判定pick）＋ `bg_*.gd` を「const配列から組む」→「StageLayout .tres を読んで組む」に小改修（constは既定フォールバックで残す＝いつでも戻せる・A1と同流儀）。ここで初めて「ツールで作った絵が本番に出る」＝道具の完了条件。

**画面効果の"見た目"はGUTで守れない**（ヘッドレスに描画なし）。stage_composer は await/シェーダ再構築/レイキャストに触るため、実装のたびに「プロパティ値のGUT」＋「実機F6での目視手順」をセットにする（CLAUDE.md助言義務）。

## アーキ原則（CLAUDE.md準拠）

- **データ→Resource(.tres)**：`BodyRecolor` / `FaceExpression` / `EnemyData`。
- **ツール→`tools/`配下の@toolシーン**、**デバッグ画面→独立シーン(F6起動・main非依存)**。
- **既存流用**：バンドリカラー(`scripts/tools/char_customizer.gd` の static)、顔生成(`face_editor`)、髪(`assets/kaykit/_source/HAIR_PIPELINE.md`)、継承デバッグ(`meta_loop_debug`)。
- **画面コントロール生成**：`scripts/tools/dev_controls.gd`（A1で新設・全ツール共通）。
- 調整値は全部 `@export`。

## 着手順（推奨・今日は未着手）

1. **A1 体リカラー**（char_customizer土台・即効・ローグ用途が具体的にある）
2. **A2 表情プリセット**（face_editor土台・即効・backlog既存項目の具体化）
3. **A3 敵ツール**
4. **B1→B2→B3 デバッグ画面**（トグルシステム/継承の実装と歩調を合わせる）

各着手時に個別設計→承認→実装。演出/await/Signal絡みは **GUT（プロパティ値検証）＋目視手順** をセットで用意（CLAUDE.md助言義務）。

---

## A/B画風プリセット（stage_composer拡張・2026-07-16 ユーザー合意）＝Sonnet実装ハンドオフ

**フェーズ1〔実装済 2026-07-16〕**：新規効果8種（ソフトシャドウ/glow/tilt-shift/接地ブロブ影/MSAA/トーンマップ選択/LUT彩度ブースト/クレイ材質ライブsetter＋輪郭ソフト化）＋画風プリセット（A/B/現状ドロップダウン＋「初期値に戻す」ボタン）＋stage_composerの個別チェック/スライダーをすべて実装。プリセット定義は`BattleScene._STYLE_PRESET_TABLE`（Dictionary）を唯一の真実の源にし、プリセット適用も「初期値に戻す」も同じ`apply_style_preset()`経路（実装順2の要求どおり）。`background_variant_override=-1`/`preview_mode=false`既定は不変＝実ゲーム回帰なし。GUTフルラン342/342緑（新規テスト4ファイル追加：`test_battle_scene_style_new_effects.gd`/`test_battle_scene_contact_shadow.gd`/`test_battle_scene_style_preset.gd`＋`test_battle_scene_lut.gd`にLUT負値テスト追加）。**残＝下記「目視確認手順」が未実施（ヘッドレスでは見た目を守れないため必須）。** フェーズ2（B後者＝Kuwahara）は引き続きスコープ外。

### 目的と決定事項（なぜ）

戦闘画面を **「立体感は保ったまま1枚の絵のように見せる」**。目標は方向の違う2つで、**混ぜず切り替えて見比べる**：

- **A＝なめらか**（スーパーマリオRPGリメイク方向・おもちゃ/ミニチュア質感）
- **B＝絵具**（ヨッシーストーリー方向・絵本/手描き質感）

**現状はA/Bのハイブリッド＝濁り**（トゥーン下地に、ハッチ/ポスタライズ/紙グレイン/輪郭/ボイルという絵具寄り要素が乗っている）。A/Bを分けて振り切るのがこの作業の主眼。stage_composer に「画風プリセット」ドロップダウン（A / B / 現状）を足し、選ぶと3層すべてに値が流し込まれる。選んだ後は個別スライダー/チェックで微調整可（プリセットは初期値バンドラ）。

**確定した設計判断（レンダラ制約の帰結）：**
- レンダラは **GL Compatibility 維持**（Web体験版＝WebGL2＝Compatibility必須。Forward+にしない）。よって **SSAO / DOF（真）/ CompositorEffect / TAA は不使用**。
- **DOF代替＝tilt-shift**（上下グラデぼかし・深度不要）。ミニチュア感はこちらの方が素直。
- **SSAO代替＝接地ソフト影ブロブ**（キャラ足元の丸い平面影。Decalノードは非Compatibilityなので使わず、床に寝かせた無光沢の放射状半透明QuadMesh）。
- **AGXトーンマップは不採用**（2026-07-12にオレンジ被りの主因と特定しReinhardtへ戻した経緯を踏襲）。Aは **Filmic**、Bは **Reinhardt**。
- **Bは段階実装。今回はB前者（絵本イラスト＝輪郭/紙/ポスタライズ/鮮やか暖色）のみ。** B後者（Kuwahara筆致＋アセットに絵具テクスチャ注入）は別フェーズ（後述・backlog別項）。理由＝Kuwaharaはフラット塗りには効かず、アセット側のディテール投入が前提だから。
- **参照画像＝`docs/image/`**（marioRPG1/2＝A方向・Yoshi1/2/3＝B方向・2026-07-16ユーザー提供）。**両参照とも高彩度・鮮やか**＝グレードは「**柔らかいのは光だけ、色と形はくっきり鮮やか**」。当初依頼の「低コントラスト」「くすませ暖色」は参照と逆＝**不採用**（A/Bとも彩度を落とさない）。
- **2D度の分岐はF6実機で決める（未確定）**：参照の中でマリオRPG(A)が**最も2Dでない**（立体を保った3Dおもちゃの写真的質感）＝「1枚の絵」に効くのは主にB。**A既定＝輪郭/ポスタライズOFFのクリーン開始**とし、2Dへ寄せたければF6でスライダーを足す（クリーン開始→加算は安全・ハイブリッド開始→減算は濁る）。Aに常時2D寄せを焼き込むかは目視後に判断。

### 3層モデル（各効果がどこに触るか）

効果は既存3層に乗る。プリセット切替はこの3層すべてへ届かせること（ポストだけ切り替えても濁りは取れない）。

- **① per-meshクレイ材質**（`_CLAY_CODE`・キャラ表面ShaderMaterial・`_for_each_clay_material`で走査）：`light_threshold` / トゥーン境界の柔らかさ / `hatch_strength`（斜線影）/ `rim_strength` / `shadow_tint` / `boil_enabled`（コマ送りジッタ）
- **② 全画面ポスト**（`_POST_CODE`・ColorRect・canvas_item）：`outline_enabled`/`thickness`/`threshold`/`line_color` / `paper_enabled`/`grain_strength`/`posterize_levels` ＋**新規** tilt-shift
- **③ Environment＋ライト**（`Environment` / `DirectionalLight3D` / SubViewport）：`fog` / `tonemap_mode` / LUTカラコレ ＋**新規** glow・ソフトシャドウ・MSAA

### 新規に足す効果（①②③のどこか・具体実装方針）

| 効果 | 層 | 実装方針（行単位でなく方針） |
|---|---|---|
| tilt-shift | ② | `_POST_CODE`にuniform追加：`tilt_enabled`(bool) / `tilt_center`(0..1) / `tilt_sharp_band`(画面高に対する鮮明帯の割合) / `tilt_blur`(px)。中央帯は鮮明、上下ほど数タップのガウスぼかし。深度不要 |
| 接地ブロブ影 | 新ノード | キャラroot直下に子`MeshInstance3D`（`QuadMesh`・X-90°で床に寝かす・y=0.01）。無光沢・放射状グラデ半透明シェーダ（中心濃→縁透明）。**root直下の固定ローカル位置なので追従は自動＝`_process`/await不要**。ON/OFFは可視＋プリセットで生成。`contact_radius`/`contact_opacity`/`contact_color` |
| glow（弱ブルーム） | ③ | `env.glow_enabled` + `glow_intensity`。Compatibilityで動く |
| ソフトシャドウ | ③ | `DirectionalLight3D.shadow_enabled` + `Light3D.shadow_blur`（＝柔らかさ）。PCSSはCompatibilityで限定的なのでblurで寄せる |
| MSAA | ③ | 戦場SubViewportの`msaa_3d = MSAA_4X`（TAAは使わない） |
| トーンマップ選択 | ③ | `env.tonemap_mode` を A=Filmic / B=Reinhardt で切替 |
| LUT彩度ブースト | ③ | `_lut_grade` の `desaturate` を**負値許容**（負＝彩度上げ・lumaから外挿）。Aは微増、Bはくすませ（正値） |
| 輪郭線ソフト化 | ② | `_POST_CODE`の`step(threshold,edge)`→`smoothstep`帯へ。`outline_softness`追加（Bの太く柔らかい線用） |
| クレイ材質のライブ更新 | ① | 現状ランタイム更新は`boil`のみ。プリセット切替を再起動なしにするため `hatch_strength` / 境界の柔らかさ / `rim_strength` にも`_for_each_clay_material`経由のライブsetterを足す |

### プリセット初期値（実装後は各`@export`がソース。ここは意図の記録）

**A＝なめらか**：① `hatch_strength=0` / boil OFF / 境界柔らか（softness≈0.2）/ `rim_strength≈0.15` / `shadow_tint`明るめ ② outline OFF / paper OFF / **tilt ON**（sharp_band≈0.18, blur≈2.5）③ **Filmic** / glow ON（intensity≈0.25）/ fog薄め（density≈0.015）/ LUT（desaturate≈-0.18＝**彩度up・鮮やか**・暖色は控えめ・**コントラストは残す**＝参照docs/imageは鮮やか）/ ソフトシャドウ（blur≈2.0）/ **MSAA 4x** / 接地影 ON（radius≈0.6, opacity≈0.4）

**B前者＝絵本イラスト**：① `light_threshold≈0.45` / 境界くっきり（softness≈0.06）/ `hatch_strength≈0.3` / boil OFF / `shadow_tint`暖色くすみ ② **outline ON**（thickness≈2.0, softness少し, 暗い暖色）/ **paper ON**（grain≈0.08, posterize≈7）/ tilt OFF ③ **Reinhardt** / glow OFF / fog（density≈0.02）/ LUT（desaturate≈-0.05〜0＝**鮮やか維持**・やや暖色＝参照Yoshiは高彩度。当初「くすませ」指示は参照と逆のため不採用）/ シャドウ通常寄り / MSAA 4x / 接地影 OFF

**現状**：battle_sceneの現`@export`既定そのまま（ハッチON/boil ON/outline ON/paper ON/tilt無し/glow無し/接地影無し）。A/Bの比較基準線。

### スライダー範囲（微調整用・プリセット適用後に触る）

`clay_light_softness`0.04–0.25 / `clay_hatch_strength`0–1 / `clay_rim_strength`0–1 / `tilt_sharp_band`0.05–0.45 / `tilt_blur`0–6 / `glow_intensity`0–1 / `shadow_blur`0–3 / `contact_opacity`0–1 / `contact_radius`0.3–1.5 / `outline_thickness`0.5–4 / `outline_softness`0–0.3 / `posterize_levels`2–32 / `grain_strength`0–0.3 / `lut_desaturate`-0.3–1.0 / `fog_density`0–0.06。boolはチェックボックス（tilt/glow/接地影/ソフト影/MSAA＋既存）。

### 実装順（CLAUDE.md「演出は1個ずつ」を守る）

1. **新効果を1個ずつ追加**（各々 チェック/スライダー＋GUT＋目視）：(a)ソフトシャドウ (b)glow (c)tilt-shift (d)接地ブロブ影 (e)MSAA (f)トーンマップ選択 (g)LUT彩度ブースト (h)クレイ材質ライブsetter＋輪郭ソフト化。各効果は battle_scene に既存P1と同じ公開API（`set_*_enabled` / パラメータsetter）で足し、`background_variant_override=-1`/`preview_mode=false`既定を守って実ゲーム回帰ゼロを維持。
2. 揃ったら **stage_composer に「画風プリセット」ドロップダウン(A/B/現状)** を足し、3層へ値を束ねて流す。既存の個別コントロールは微調整用に残し、プリセットがそれらを設定する。
   - **プリセット定義は1箇所（Dictionary/定数テーブル）を真実の源にする**（A/B/現状の全パラメータ値をそこに持つ）。プリセット適用も「初期値に戻す」も、このテーブルから読んで流す同じ経路にする。
   - **「初期値に戻す」ボタンを必須で置く**（ユーザーがスライダーをいじって元値を忘れる前提）。押下＝**現在選択中のプリセットの定義値を全コントロール＋3層へ再適用**し、スライダー/チェックの表示も定義値へ戻す。`OptionButton`は同一項目の再選択で`item_selected`が発火しない場合があるため、ドロップダウン任せにせず専用ボタンにする。
3. GUTフルラン緑＋下記の目視を通す。

### GUTで検証すること（プロパティ値・ヘッドレスで可）

- `画風=A`適用後：`clay_hatch_strength==0` / `clay_boil_enabled==false` / post `outline_enabled==false`＆`paper_enabled==false` / `tilt_enabled==true` / `env.glow_enabled==true` / `env.tonemap_mode==TONE_MAPPER_FILMIC` / 接地影ノードが各キャラに存在 / SubViewport `msaa_3d==MSAA_4X`。
- `画風=B`適用後：`outline_enabled==true`＆`thickness>=2.0` / `paper_enabled==true` / `posterize_levels`≈7 / `clay_hatch_strength>0` / `tilt_enabled==false` / `env.tonemap_mode==TONE_MAPPER_REINHARDT` / LUT `desaturate>0`。
- `画風=現状`適用後：battle_sceneの`@export`既定に一致（ハッチON/boil ON/outline ON/tilt無し/glow無し/接地影無し）。
- 新setter単体：`set_tilt_enabled(true)`→post材質のuniform`tilt_enabled`がtrue／`set_contact_shadow_enabled(true)`後に各キャラへブロブ子が付き`false`で消える／glow・shadow setterがenv・lightのプロパティへ反映。
- `_lut_grade`に負の`desaturate`を渡すと出力の彩度が入力より上がる（テスト色でクロマ増を確認）。
- **「初期値に戻す」**：スライダー/チェックを定義値から変えた状態で reset を呼ぶと、全パラメータが現在プリセットの定義テーブルの値に一致へ戻る（1つ以上を変更→reset→定義値と全一致、をassert）。

### 目視確認手順（ヘッドレスGUTでは守れない・実機F6必須）

1. F6で `scenes/stage_composer.tscn` 起動。
2. 画風=**A**：線/ハッチ/グレインが消え滑らか、上下がぼける(tilt-shift)、影が柔らかい、足元に丸い接地影、暖色・低コントラスト。
3. 画風=**B**：太く柔らかい輪郭、紙グレイン、平坦な暖色くすみ、tiltぼけ無し。
4. 画風=**現状**：今日のビルドと同じ（ハッチ＋ボイル＋線＋グレイン）。
5. **停止(pause)して A⇄B を同一フレームで切替比較**（動かすと別フレーム比較で誤判断する）。
6. 各スライダー（tilt band, glow, contact opacity, outline thickness, posterize）を動かし反映を確認。
7. 破綻チェック：tilt最大 / posterize=2 / outline最大 で崩れないか。
8. スライダーを数個いじった後「初期値に戻す」を押し、そのプリセットを選んだ直後の見た目・値へ戻ることを確認。

### await/シェーダ再構築の注意（テストで守れない）

- **この変更は見た目部分をGUTで守れない**（ヘッドレスに描画なし）。上記目視を必ず実施。
- `_POST_CODE`へtilt-shift用uniformを追加＝シェーダ再コンパイルは初回のみ。プリセット切替時のパラメータ更新はライブ（材質の再生成不要）。
- 接地ブロブ影は**キャラroot直下の子（固定ローカル位置・`_process`/await/Signal不使用）**。追従は親子関係で自動。ただし床が非平坦だと浮くので目視。
- クレイ材質のライブ更新は既存`_for_each_clay_material`パターン踏襲（`set_boil_enabled`と同じ流儀）。

### Bの2D方向：絵具（採用・2026-07-16）／セル画（保留・将来の振り替え候補）

「3Dを2Dに見せる（1枚の絵）」には2系統ある。ユーザーは**絵具（絵本）方向を採用**（2026-07-16）。もう一方は消さず、将来Bを振り替える候補として記録：

- **絵具・絵本〔採用〕**＝ヨッシーストーリー方向。塗りのムラ・手描きテクスチャ・柔らかく太い輪郭・フラットだが有機的。B前者＝この方向のポスト側（輪郭/紙/ポスタライズ/鮮やか暖色）、B後者＝Kuwahara＋アセット絵具テクスチャ。
  - **【2026-07-16 精緻化・ユーザー実機所見】**：Kuwaharaの絵具塗りに**輪郭をくっきり**乗せると『**絵本×漫画の中間＝スマブラ4(3DS版)**』へ寄る。機序＝Kuwaharaが柔らげた面を硬い線が締め直す（"ボケ"が"絵"になる／塗りと線は役割分担）。輪郭は**低ポリの形を定義して可読性を上げる**（Smash 3DSが小画面可読性であえて輪郭を足したのと同じ理屈＝うちの低ポリに合う）。**Bの狙いは「Yoshiソフト」から「絵具fill＋定義された輪郭」へ寄せる方向**。保留の"セル画"とは別（絵具塗りは残したまま線を締める）。参照追加候補＝スマブラ4(3DS)スクショを `docs/image/` へ。
- **セル/アニメ塗り〔保留〕**＝原神・ニノ国・ギルティギアXrd方向。**くっきり均一な線＋フラットな色面（トゥーンの段を硬く・境界シャープ）＋テクスチャ最小＋弱いスペキュラ/ハイライト**。実装的には既存①クレイ材質を「境界softness最小・hatch/paperなし」＋②アウトラインを「均一太さ・高threshold」へ振るとこちら寄りになる。**ツールは全層を露出しているのでBプリセットの値替えだけで後から移行可能（構造変更不要）**。不採用の理由＝今回は絵具方向と決めたため。惹かれたらF6でBの値をこちらへ振って比較できる。

### 輪郭の完全化＝inverted-hull outline（2026-07-16 着手GO）＝Sonnet実装ハンドオフ

**問題**：現`_POST_CODE`の輪郭は**luma(明るさ)差のスクリーンエッジ検出**＝物体と背景の明るさが近いと色が違っても線が出ない（魔女の帽子×暗背景＝カバー漏れ）。Kuwaharaの平滑化で漏れが増える。太さ/黒さでは直らない（検出漏れは太くできない）。ユーザー所見「太さ/黒さでなく、線で覆えてない輪郭が多い」＝コレ。

**方針＝inverted-hull（本命・完全カバー）**：スクリーン検出でなく**ジオメトリ方式**。クレイ材質(`_CLAY_CODE`のShaderMaterial)に`next_pass`を足し、そのパスで：
- `render_mode cull_front, unshaded`（裏面のみ描画）
- `vertex()` で `VERTEX += NORMAL * hull_outline_width`（法線方向へ微膨張）
- `ALBEDO = hull_outline_color`（線色）

→ 元メッシュの外側に線色の"殻"がシルエット分はみ出す＝**色/背景に非依存で全シルエットに必ず線**。GL Compatibilityで動く（純ジオメトリ・深度不要）。スマブラ/ギルティ系の完全輪郭＝ユーザーの「線で覆う」狙いに直結。

**パラメータ**：`hull_outline_enabled`(bool) / `hull_outline_width`(m・0.0〜0.05程度) / `hull_outline_color`(Color)。stage_composerにチェック＋スライダー露出＋`_STYLE_PRESET_TABLE`のBに既定（enabled・width控えめ）。A/現状はOFF。

**既存スクリーン輪郭とは共存**：inverted-hull＝**外シルエット**担当／既存luma輪郭＝**モデル内部のディテール線**（折り目・色境界）担当＝役割が違う。両方トグルで残しF6でバランスを取る。

**低ポリの罠（要目視）**：ハードエッジ（分割法線）のモデルは、法線方向の膨張で**継ぎ目に隙間/割れ**が出ることがある。KayKitで割れたら対策＝(1)膨張を"平均化した滑らか法線"で行う（頂点に平滑法線を焼く/近傍平均）(2)widthを控えめに。**まずそのまま実装しF6で割れの有無を見る**（割れたら平滑法線対策を追加）。

**GUT**：`hull_outline_*`が材質(next_pass)へ渡る値検証・`hull_outline_enabled`でnext_passの有無。**目視**：F6でB→hull輪郭ON→魔女の帽子等のシルエットに線が乗るか／継ぎ目割れの有無／width可変の差。**await/描画順の注意なし**＝next_passは材質に足すだけでKuwaharaのような多パス中継(BackBufferCopy)は不要。実ゲーム回帰は`hull_outline_enabled=false`既定で担保。

（**軽い代替(a)**＝既存スクリーン輪郭のエッジ検出をluma差→色(RGB)差へ拡張＝色コントラストのエッジも拾う小改修。部分改善どまり＝同色隣接はまだ漏れる。(b)で割れ等の問題が出た場合の当座しのぎとして温存。）

**〔実装済 2026-07-17〕**：`_CLAY_CODE`のShaderMaterialに`next_pass`＝新規`_HULL_OUTLINE_CODE`（`render_mode cull_front, unshaded`・`vertex()`で`VERTEX += NORMAL * hull_outline_width`・`ALBEDO = hull_outline_color`）を`_apply_clay_shader()`から付与。`hull_outline_enabled`はシェーダ内uniformでなく**next_passの有無そのもの**で表現（無効時はnext_pass自体を作らない＝実ゲーム回帰ゼロ）。`set_hull_outline_enabled/width/color`は`_for_each_clay_material`パターンで既存マテリアルのnext_passを付け外し/更新。`hull_outline_enabled/width`をstage_composerにチェック＋スライダー追加（colorはpresetのみで個別UIは無し＝他のColor系パラメータと同じ扱い）、`_STYLE_PRESET_TABLE`のBに既定(enabled=true, width=0.015)追加、A/現状はOFF。低ポリの継ぎ目割れ対策（平滑法線）は**今回未着手**＝doc記載どおりまず素の実装でF6確認してから判断。GUT新規`test_battle_scene_hull_outline.gd`（next_passの有無・paramの反映を新規/既存マテリアル両方で検証）＋`test_battle_scene_style_preset.gd`拡張。フルラン緑。**残＝目視**：F6で画風B→hull輪郭ON→魔女の帽子等のシルエットに線が乗るか／継ぎ目割れの有無／width可変の差。

### B後者＝塗り極め（フェーズ2・2026-07-16 ユーザーGO）＝Sonnet実装ハンドオフ

**背景**：フェーズ1のグレード層を実機で確認したところ「A＝なめらか／B＝ちょい絵本」と**別物には見えるが劇的ではない**＝**ポスト単独の天井**（フラット塗りが原因）を目視で確定。Bの本命の伸びしろ＝**塗り（アセット表面のテクスチャ）**。ユーザー実機所見：Bは**輪郭を細く**（太い縁取りはセル寄り・不採用の裏付け）＋陰境界くっきり＋鮮やか、が好み＝絵具方向で確定。

**方針（重要）**：テクスチャ作業は**ユーザーに手を動かさせない**。手続き生成／既製CC0／Claude側でのベイクで吸収する（memory `feedback_asset_craft_not_manual`）。ユーザーはF6でスライダー判定のみ。段階：

- **2-1 アルベドに絵具/紙テクスチャを注入〔最優先・まずこれだけ〕**：`_CLAY_CODE`のfragmentで `base`（=albedo_tex×albedo_color）に**紙/絵具テクスチャを乗算/オーバーレイ合成**。**手続きノイズ（fbm）＋CC0タイリング紙テクスチャの2系統**を用意（まず手続き＝アセット不要で即プレビュー、"デジタルっぽい"なら本物の紙テクスチャへ格上げ）。`paint_tex_enabled`(bool)／`paint_tex_strength`(0..1)／`paint_tex_scale` を **stage_composer のスライダー＋チェックで露出**（フェーズ1と同流儀・`_STYLE_PRESET_TABLE`のBにも既定を追加）。まず人型キャラに適用、良ければ背景へ拡張。**GUT**＝paramがShaderMaterialへ渡る値検証。**目視**＝F6でBに乗せ「塗りが乗ったか／絵本に近づいたか」＋strength 0↔最大の差。
- **2-2 Kuwahara〔着手GO・2026-07-16。2-1をF6確認しムラ視認OK＝材料は敷けた〕**＝Sonnet実装ハンドオフ：
  - **新規パス**：Kuwahara用の全画面ColorRect（canvas_itemシェーダ・`hint_screen_texture`読み・CompositorEffectは非Compatibilityなので不使用）を、既存 `_POST_CODE` ポストrect**より前（下）に描画**。描画順＝3Dシーン→**Kuwahara**→（全画面`BackBufferCopy`）→既存ポスト（outline/posterize/tilt）。**2パス目（既存ポスト）が1パス目の結果を読むため、Kuwahara rect と既存post rect の間に全画面 `BackBufferCopy` を挟む**（canvas_itemのscreen textureは直前のbackbufferを読むため）。順序の意図＝Kuwaharaが先に色を筆致化→その上に輪郭が乗る。
  - **アルゴリズム（古典4象限）**：各ピクセルで半径rの4象限（左上/右上/左下/右下の重なり窓）の平均・分散を算出→**分散最小の象限の平均色**を出力。平らな面は絵具パッチにまとまり、境目はこすらず残る＝筆致。分散は輝度で評価、出力色は象限平均。
  - **パラメータ**：`kuwahara_enabled`(bool) / `kuwahara_radius`(px・1〜6)。radius＝筆の大きさ。stage_composerにチェック＋スライダー追加。`_STYLE_PRESET_TABLE`のBに既定（enabled=true・radius≈3）、A/CURRENTはOFF。
  - **性能注意（重要）**：Kuwaharaは4象限×(r+1)²サンプル＝重い（r=4で約100読み/px）。**GL Compatibility＋Web書き出しで重くなりうる**ので既定radiusは控えめ・上限を欲張らない。F6でフレームレートも確認。
  - **GUT**：`kuwahara_enabled`/`kuwahara_radius`がShaderMaterialへ渡る値検証・enabledでパスON（rect可視/BackBufferCopy有効）。
  - **目視**：F6でB→Kuwahara ON/OFF・radius可変で筆致パッチが出るか／2-1の塗りムラと合わさって"絵"に見えるか／輪郭が上に残るか／フレームレート低下が許容内か。

**判定ポイント**：2-1＋2-2を一緒に見て「絵（筆致）になった」かをF6で確認。ここが絵具方向の本番。物足りなければ次の escalation＝手続きノイズ→本物のCC0紙テクスチャへ格上げ（2-1側）。

**2-1〔実装済 2026-07-16〕**：`_CLAY_CODE`に`paint_tex_enabled`/`paint_tex_strength`/`paint_tex_scale`の3uniformを追加。UV空間で手続きノイズ2系統（`_paint_fbm`＝3オクターブのvalue-noise合成＝広い筆致むら／`_paint_value_noise`単体の高周波サンプル＝紙の繊維目）を`mix(wash, grain, 0.4)`で合成し、`base`のALBEDOへ明暗0.82〜1.18倍で乗算。CC0タイリング紙テクスチャへの格上げ（本物の画像アセット）は今回未着手＝「まず手続き」の段のみで止めている（F6で"デジタルっぽい"と判断されたら次段で着手）。`stage_composer`にチェック＋強さ/粒度スライダーを追加、`_STYLE_PRESET_TABLE`のBに`paint_tex_enabled=true, strength=0.35, scale=6.0`を既定追加（A/現状はfalseのまま＝クリーン）。GUT新規`test_battle_scene_paint_texture.gd`（paramがShaderMaterialへ渡ることを`_characters`手動差し替えで直接検証）＋`test_battle_scene_style_preset.gd`にB/A/現状の`paint_tex_enabled`アサート追加。フルラン349/349緑。**残＝目視**：F6で`stage_composer.tscn`起動→画風=B→「絵具/紙テクスチャ」チェックON→キャラ表面に塗りムラが乗るか／strength 0↔1で差が分かるか／scaleを動かして粒度が変わるか／"デジタルっぽい"かどうかの判定（→次段の要否）。

**2-2〔実装済 2026-07-16〕**：新規`_KUWAHARA_CODE`（canvas_item）を追加。古典4象限（各象限(radius+1)×(radius+1)を中心画素共有で重ねて取り、輝度分散が最小の象限の平均色を採用）。`_setup_post_effects()`の描画順を`[Kuwahara矩形 → BackBufferCopy(COPY_MODE_VIEWPORT) → 既存_POST_CODE矩形 → ...UI]`に再構成＝Kuwaharaが筆致化した絵をBackBufferCopyでバックバッファへ焼き込み、既存の輪郭/紙/tiltポストがその筆致化後の色を読む。`kuwahara_enabled=false`のときは両ノードとも生成せず＝従来どおりpost_rectのみ（回帰なし）。`kuwahara_enabled`/`kuwahara_radius`（既定3・range 1〜6）を`stage_composer`にチェック＋スライダーで追加、`_STYLE_PRESET_TABLE`のBに`enabled=true, radius=3.0`を既定追加（A/現状はfalse）。**実装中にshader_type canvas_itemの`fragment()`内で`return;`が使えない（Godotのシェーダバリデーションエラー）に遭遇→if/else構造へ書き換えて解消**（この不具合はGUTの構造テスト＝`_canvas`を手動注入して`_setup_post_effects()`を直接呼びShaderMaterial生成を検証するテストが検知した）。GUT新規`test_battle_scene_kuwahara.gd`（ノード生成順・BackBufferCopy.copy_mode・paramのマテリアル反映を検証）＋`test_battle_scene_style_preset.gd`拡張。フルラン357/357緑。**残＝目視**：F6で画風=B（2-1の塗りテクスチャON状態）→Kuwahara ON→筆致に見えるか／radiusを動かした見た目差／**フレームレート**（重いシェーダのため要確認。Web書き出し時は特に）。

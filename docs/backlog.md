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
  - [ ] **【2026-07-18検証】非人型モンスターの手続き生成が実用線と判明**：CC0/CC-BY/有償マーケットの非人型ローポリ選択肢が実際に薄い（itch.io/Sketchfab探索済み・Quaterniusは今後選択肢から除外）と判明したのを受け、ヘッドレスBlender（d:/dev/blender・Blender 5.1.2）でプリミティブ組み立て→Cycles一発レンダーの一次検証を実施。結果＝シルエットは「非人型モンスター」として成立、色替えバリエーションも機能（詳細・レンダー画像はArtifact化済み）。課題＝腹パッチの浮き（溶接/ブーリアン無し）、角/耳の頭部密集、脚の単純さ、構造面の組み合わせ（脚数/角有無等）は未検証、リギング/アニメは未着手。**次の判断＝この方向をA3敵ツールとして本格化するか、ここで検証止まりにするか要相談**

- [x] ~~**dungeon_masonドラゴンにアニメを付ける**~~ **解決（2026-07-19）**：4体すべてアニメ再生・目視OK。経緯と原因の全容は devlog/2026-07-19.md 参照。要点＝**FBX元来のスキンは最初から正しく、一様に1/100スケールなだけだった**（`.import` の `root_scale=0.01` がスケルトンのrest側にだけ乗りスキンのバインド姿勢には乗らないため）。スキンを作り直すと形が壊れる（形の破綻辺 1.3%→17.1%）ので触らず、`_DRAGON_SKIN_SCALE_FIX=100.0` でノードスケールを戻す。副作用としてローカル座標系が1/100になり固定振幅の頂点ボイルが相対100倍＝毛糸化するため、`boil_amp_div` メタで同倍率を割り戻している。検証ハーネス＝`tools/diag_harness_control.gd`（KayKit対照群）・`tools/diag_dragon_origbind.gd`（バインド条件の比較）
- [ ] **画風プリセットBでドラゴンが膨れ上がる（2026-07-19 ユーザー確認）**：現状/Aでは正常だが、B（絵本）にするとドラゴンが膨張する。Bで有効になる効果のうち **inverted-hull輪郭が最有力容疑**（法線方向へ頂点を押し出す＝`hull_outline_width` がローカル空間固定なら、ドラゴンはローカル座標系が1/100なので相対100倍に効く＝ボイル毛糸化と同じ構造）。次点でKuwahara/ポスタライズ。切り分け＝Bにした状態でinverted-hull輪郭だけOFFにする。直し方もボイルと同じで、`boil_amp_div` と同じ倍率を `hull_outline_width` にも割り戻せばよい見込み
- [ ] **ドラゴン3体の例外ボーン（優先度低）**：`soul_eater/TailEnd`・`usurper/WingThumb01_L/R` の計3本だけ二重に0.01倍が乗っている（`tests/test_battle_scene_dragon_anim.gd` が5%未満として許容中）。目視で該当部位が歪んでいなければ放置してよい
- [ ] **敵モデル差し替え候補13種の是正**（2026-07-19 stage_composerで全数目視・ユーザー所見）。ドラゴン4種はアニメ合流とスケールを対処済みなので**残りの候補が対象**。症状は「接地」「サイズ」「アニメ未接続」の3系統に整理できる。採用候補を絞ってから直す（全部直すのは無駄）
  - 接地ズレ（沈む/倒れる）：Mimic Chest（沈む）／Minataur Low Poly（沈む＋倒れている＝軸違いの疑い）／Venus Pie Trap（沈む）
  - 画面に映らない：Shark／Unicorn／Little Ghost（スケール極小か原点外れ）
  - サイズ：Griffin（小さい）／Wolfboss（大きすぎる）／Devil Bulldog（サイズはOK）
  - アニメが動かない：Eblan・Griffin（ほぼ動かない）／Devil Bulldog・Wolfboss（全く動かない）＝ドラゴンと同じ「本体GLBにクリップ無し」型かどうかの切り分けから
  - 立体感：Eblan「3Dに見えない」＝下記の画面効果側の課題と同根の可能性

#### 戦闘画面構築ツール（B1＋A4統合・2026-07-15 ユーザー合意）＝着手中

背景切替＋画面効果ON/OFF＋（将来）小物/タイル配置を1画面 `scenes/stage_composer.tscn` に統合。設計詳細＝`docs/dev_tooling_design.md`「B1＋A4統合」。

- [x] ~~**P1 生コントロール**~~ **実装完了（2026-07-15）**：`scripts/ui/stage_composer.gd`＋`scenes/stage_composer.tscn`（F6起動）。背景切替（草原/ダンジョンKenney/ダンジョンKayKit）・効果ON/OFF（輪郭線/紙/ボイル/霧/LUTはライブ、粘土はリスタート反映）・戦闘 開始停止(`SceneTree.paused`)/リスタート。`battle_scene.gd`に公開API（`rebuild_background`/`set_*_enabled`/`background_variant_override=-1`既定/`preview_mode=false`既定）を追加＝実ゲーム回帰なし。GUT新規7テスト（`tests/test_stage_composer.gd`）。**残：目視＝F6で `stage_composer.tscn` を起動し、①背景3種の切替 ②各効果ON/OFFの反映 ③戦闘 停止/再開/リスタート ④粘土OFF→リスタートで反映、を実機確認（ヘッドレスGUTは見た目を守れない）**
- [ ] **P2 配置**：`StageLayout`(.tres)＋`StagePlacement`を新設し、小物/タイルをパレット選択→3D地面クリックで配置（タイルは4.0グリッドスナップ）・回転45°/スケール段階ボタン・保存/読込。現状 `bg_dungeon_kaykit.gd` のconst配列を初期StageLayoutへ移行
- [ ] **P3 実ゲーム反映**：配置済みプロップの選択・移動＋ `bg_*.gd` を StageLayout .tres 読みに小改修（constは既定フォールバックで残す）。ここで道具の完了条件（ツールで作った絵が本番に出る）
- [ ] **P1ツール調整（随時・受け皿）**：F6で `stage_composer.tscn` を使いながら出た調整をここに追記していく。**まず上記P1の目視4項目**（①背景3種切替 ②各効果ON/OFF反映 ③停止/再開/リスタート ④粘土OFF→リスタート反映）を確認し、崩れがあれば個別行に切り出す。想定される調整候補＝パネルの見やすさ/位置・幅、背景に草原/Ken"を選んだ時の空色や敵/床の噛み合わせ、効果の組み合わせで破綻しないか、粘土リスタートのUX（一瞬の再生成が気になるか）、初期背景/初期battle_indexの既定値。**具体issueが出たらこの行の下に列挙**

#### A/B画風プリセット（stage_composer拡張・2026-07-16 ユーザー合意）＝Sonnet実装ハンドオフ

戦闘画面を「立体感を保ったまま1枚の絵に」する。**A＝なめらか（マリオRPG方向）／B＝絵具（ヨッシー方向）を混ぜず切り替えて見比べる**プリセットを stage_composer に追加。**GL Compatibility維持**（Web体験版必須）ゆえ SSAO/DOF/CompositorEffect/TAA不使用＝DOF→tilt-shift・SSAO→接地ブロブ影・AGX不採用(A=Filmic/B=Reinhardt)で代替。**完全な実装仕様（3層モデル・新効果の方針・プリセット初期値・スライダー範囲・実装順・GUT検証項目・目視手順・await注意）は `docs/dev_tooling_design.md`「A/B画風プリセット」節にある。Sonnetはそれを単独で実装できる。**

- [x] ~~**フェーズ1＝Aプリセット＋A/B/現状トグル**~~ **実装完了（2026-07-16）**：battle_scene に新効果8種の公開API追加（ソフト影/glow/tilt-shift/接地ブロブ影/MSAA/トーンマップ選択/LUT彩度ブースト/クレイ材質ライブsetter＋輪郭ソフト化）＋stage_composerに「画風プリセット」ドロップダウン(A/B/現状)＋「初期値に戻す」ボタン。プリセット定義は`BattleScene._STYLE_PRESET_TABLE`を唯一の真実の源に。`background_variant_override=-1`/`preview_mode=false`既定は維持＝実ゲーム回帰なし。GUT新規4ファイル・フルラン342/342全通過。**残：目視＝F6で`stage_composer.tscn`を起動し `docs/dev_tooling_design.md`「A/B画風プリセット」節の目視確認手順1〜8（A/B/現状の切替比較・各スライダー反映・初期値に戻すボタン・破綻チェック）を実施**
- [x] ~~**フェーズ1に含むB前者（絵本イラスト）**~~ **実装完了（2026-07-16）**：輪郭太・紙グレイン・ポスタライズ。当初の「暖色くすみLUT」は参照画像（`docs/image/`のYoshi系）と逆方向と判明し彩度維持へ変更。Kuwaharaは含まない
- [x] ~~**フェーズ2の2-1＝アルベドへ絵具/紙テクスチャ注入**~~ **実装完了（2026-07-16）**：`_CLAY_CODE`に`paint_tex_enabled/strength/scale`を追加、手続きノイズ2系統（fbm＝広い筆致むら／value_noise高周波＝紙の繊維目）をalbedoへ乗算合成。CC0タイリング紙テクスチャへの格上げは今回未着手（「まず手続き」段のみ。F6で"デジタルっぽい"なら次段）。stage_composerにチェック＋スライダー2種追加、`_STYLE_PRESET_TABLE`のBに既定追加（A/現状はOFFのまま）。GUT新規1ファイル＋既存拡張・フルラン349/349全通過。**残：目視＝F6で画風=B→「絵具/紙テクスチャ」ON→塗りムラ・strength/scaleの反映・"デジタルっぽいか"の判定（詳細手順は`docs/dev_tooling_design.md`「B後者＝塗り極め」節末尾）**
- [x] ~~**2-2 Kuwahara**~~ **実装完了（2026-07-16）**：新規`_KUWAHARA_CODE`（canvas_item・古典4象限＝分散最小象限の平均色）を追加。`_setup_post_effects()`の描画順を`[Kuwahara矩形→BackBufferCopy(COPY_MODE_VIEWPORT)→既存_POST_CODE矩形→UI]`に再構成（既存ポストが筆致化後の色を読む）。`kuwahara_enabled=false`時は両ノードとも生成せず回帰なし。`kuwahara_enabled`/`kuwahara_radius`(既定3)をstage_composerに追加、`_STYLE_PRESET_TABLE`のBに既定(enabled,radius=3.0)。**実装中に`fragment()`内`return;`不可のシェーダエラーに遭遇→if/elseへ修正**（GUTの構造テストが検知）。GUT新規`test_battle_scene_kuwahara.gd`＋既存拡張・フルラン357/357全通過。**残：目視＝F6で画風=B（2-1のON状態）→Kuwahara ON→筆致に見えるか／radius可変の差／フレームレート確認（詳細手順は`docs/dev_tooling_design.md`「B後者＝塗り極め」節末尾）**
- [ ] **（調整候補）Aに紙グレインだけ乗せる**：ユーザー所見「A＋グレインが一番良いかも」（2026-07-16）。現状`paper_enabled`は**グレイン＋ポスタライズの抱き合わせ**＝Aの滑らかさとポスタライズが喧嘩する。F6での暫定確認法＝紙グレインON＋ポスタライズ段数32(最大)＋グレイン強さ0.05。良ければ**グレインをポスタライズから分離**して独立トグル化（`_POST_CODE`で`grain_enabled`を`paper/posterize`から切り出す小改修）。**アセット刷新後のスタイル最終詰めと一緒に判断**（今は磨き込みすぎない方針）
- [ ] **（調整候補）頂点ボイルのB採用可否＝"くっきり"vs"生きてる感"のトレードオフ**（2026-07-16 ユーザー所見）：ボイル無し＝くっきり／有り＝手作り粘土の生命感（"生きてる感"）。全部最大化する完璧な組合せは無い＝軸の選択問題。**Perrantは愛着が芯＝生命感側を取る判断はアリ**（"くっきり"では負けても"魂"で元を取る）。アセット刷新後のB最終詰めで決定（今は暫定でどちらでも可・磨き込みすぎない方針）
- [x] ~~**輪郭線の"カバー漏れ"を減らす＝inverted-hull（着手GO・2026-07-16・Sonnetハンドオフ）**~~ **実装完了（2026-07-17）**（ユーザーF6所見・魔女の帽子等）：問題＝**太さ/黒さでなくカバー漏れ**（検出できてない線は太くできない）。原因＝現`_POST_CODE`の輪郭は**luma差のエッジ検出**＝明るさが近いと色違いでも拾えない＋Kuwaharaの平滑化で漏れ増。**採用＝(b)inverted-hull**（クレイ材質に`next_pass`＝cull_front/unshaded・法線方向へ微膨張・線色。全シルエットに必ず線・GL Compatibilityで動く・多パス中継不要）。パラメータ`hull_outline_enabled/width/color`をstage_composer露出＋`_STYLE_PRESET_TABLE`のBに既定。既存スクリーン輪郭は内部ディテール線担当で共存。**低ポリの継ぎ目割れは要目視**（割れたら平滑法線対策）。完全仕様＝`docs/dev_tooling_design.md`「輪郭の完全化＝inverted-hull outline」節。※(a)色差エッジ拡張は割れ時の当座しのぎとして温存。**実装＝`_HULL_OUTLINE_CODE`をクレイ材質のnext_passに追加。hull_outline_enabledの有無＝next_passの有無（無効時は生成自体しない＝回帰なし）。GUT新規`test_battle_scene_hull_outline.gd`・フルラン緑。残：目視＝F6で画風B→hull輪郭ON→魔女の帽子等に線が乗るか／継ぎ目割れの有無／width可変の差**
- [x] ~~**影がマイクラ状にカクつく＝シャドウマップ解像度（診断確定・2026-07-16／Kuwahara切っても残る事で切り分け済み）**~~ **実装完了（2026-07-17）**：落ち影が影用テクスチャの低解像度でテクセル単位にカクつく＝マイクラ影の典型（「ぼやけ」でなくアリアス）。**固定アイソメ＋狭いアリーナ**なので最有効かつ**無料の手＝`DirectionalLight3D.directional_shadow_max_distance`を縮める**（同解像度を近くに集中させてキリッとさせる）。足りなければ`rendering/lights_and_shadows/directional_shadow/size`を上げる（影マップ拡大＝Web perfにやや響く）。shadow_blur増(ごまかし)やPSSM splitもあるが本命は距離短縮→解像度up。**実ゲームの影も綺麗になる**小改修。実装＝プロジェクト/ライト既定を良値へ＋必要ならstage_composerに「影の距離/解像度」露出。着手は輪郭(inverted-hull)の後でOK（ユーザー「後でもいい」）。**実装＝`shadow_distance`(既定20.0)を`_setup_world()`で`_light.directional_shadow_max_distance`へ常時反映（shadow_soft_enabledのON/OFFに関わらず＝実ゲームにも効く）。stage_composerに「影の距離」スライダー追加、`_STYLE_PRESET_TABLE`全プリセットに同値で追加。**追記（2026-07-17・距離短縮だけでは不十分と判明→解像度も投入）**：`project.godot`の`[rendering]`に`lights_and_shadows/directional_shadow/size=4096`＋`size.mobile=4096`（Web書き出しも揃える）を追加。GUT新規`test_battle_scene_shadow_distance.gd`（`_light`手動差し替えでdirectional_shadow_max_distanceが届くこと・project設定値の2テスト）・フルラン緑。残：目視＝F6で影の四角さが消えるか／距離スライダーの効き／**フレームレート（解像度up分の負荷を確認・特にWeb書き出し）**／実戦闘(F5)でも確認**
- [ ] **追加できる効果の棚（任意・未着手・2026-07-16「載せようと思えば」）**＝候補メニュー。**線**＝色つき輪郭／線幅の強弱（inverted-hullは上の別項）。**絵具・漫画（"絵本×漫画中間"に直結）**＝ハーフトーン網点（`アート画面効果`の②格上げ案と同一）／水彩のにじみ・縁の顔料溜まり／クロスハッチ影（既存ハッチを影限定で強める）。**仕上げ・空気感（A/B両方）**＝ビネット／奥の霞み(空気遠近＝ジオラマ感・可読性up)／光芒(God rays・やや重い)。**この方向に不向き＝色収差・ディザ（off-brand）**。効き所の推し＝ハーフトーン＋クロスハッチ（漫画側）。全てClaude/Sonnet作業・ユーザーは判定のみ・アセット刷新後の最終詰めで取捨。
- [ ] **画面効果の目視確認（まとめ・保留）**：フェーズ1＋2-1＋2-2は全実装・GUT緑だが、各実装の「残＝目視」（画風A/B/現状の切替比較・各スライダー反映・初期値に戻す・Kuwaharaの筆致とフレームレート・2-1のデジタル感判定）は未消化。**アセット刷新後にA/B最終判定と一緒にまとめて実施**（プレースホルダーの上での磨き込みは避ける方針・devlog 2026-07-16「暫定評価」参照）

### 【新規・2026-07-14 実測判明】自作キャラGLBの品質問題（顔/髪がアニメで動かない）

体リカラーツールでWitchを見た際に発覚。`Witch_final_reference.glb` は自作書き出しが不完全＝(1)`CustomHead`/`HairMesh`が**skin=false（Skinバインド無し）で骨に追従しない**＝歩行/攻撃で顔・髪がその場に残る (2)共有アニメ再生時にリグrest不整合で**約1.5m沈む**（ツール側は自動接地で回避済みだが**実ゲームでも沈む疑い＝要確認**）。

- [x] ~~**顔/髪をアニメ追従させる方針決め**~~ **実装完了（2026-07-15）**：調査の結果、候補(a)`BoneAttachment3D`は既にWITCHのちび頭拡大機能（`_apply_kaykit_chibi_head`）が副産物として実装済みと判明（headボーンへ載せ替え・skin除去）。chibi専用の縛りを外し`_apply_kaykit_head_assembly(ch, is_chibi)`へ汎用化＝CustomHead/HairMeshの剛体追従は全KayKit職で常時有効、ネイティブ頭/帽子/兜の巻き込みと拡大倍率はchibiのときだけ追加適用。該当パーツもchibiでもない職は早期returnで無変化。GUT新規テスト＋WITCH目視回帰確認済み。**Rogueへの髪+顔追加のブロッカーは解消**
- [ ] 実ゲームのWitchも沈んでいないか確認（`battle_scene`で目視。沈んでいれば同じ接地補正 or アセット修正）＝上記とは別問題（骨格ルート自体のズレ）
- [ ] **【優先度低・深追いしない】切り抜き部品（帽子/髪）にinverted-hull輪郭を成立させる（頭・帽子は据え置き）**（2026-07-17 ユーザー確定：**自作頭＝のっぺらぼう頭＋切り抜いた帽子を乗せた構造。頭も帽子も絶対変えない＋全キャラこの方式にする予定**）。**⚠スコープ＝ブロッカーではない**：最悪は輪郭OFF or 画風A（輪郭なし）で回避可＝必須ではなく nice-to-have。**詰めすぎない方針**（2026-07-17 ユーザー）。着手はやると決めた時だけ。以下は解決したい場合の設計メモ：
  - **構造**＝ユーザー製の のっぺらぼう頭（単純形状・法線は多分マシ）＋**既存モデルから切り抜いた帽子**（`_HEAD_ASSEMBLY_SUFFIXES`の`_Hat`等 or `CustomHead/HairMesh`）を乗せた合成。
  - **問題**＝hull輪郭は頂点法線方向に膨張＝**切り抜き部品は法線が反転/バラつきがち**（切り抜き時・乗せる時の負スケール/ミラーで反転）→殻が内側に膨らみ**帽子に線が出ない**（ネイティブ全身キャラは線が乗る＝差をF6確認済み）。全キャラこの方式＝**必須要件**。
  - **合格ライン＝"帽子に綺麗な線が乗る"**（＝のっぺら頭だけ線が付いても解決にならない、とユーザー明言。線ゼロもダメ）。
  - **なぜhull維持でスクリーン輪郭に逃げないか**＝帽子が線を失う根本は「暗い帽子×暗い背景」＝**コントラスト無し**。スクリーン方式（luma差/色差）はコントラスト前提で暗×暗を拾えない。hull（ジオメトリ＝色非依存）だけが暗×暗でも線を引ける＝ここはhullが唯一解。
  - **解決＝頭も帽子も一切いじらず、ロード時に部品の法線を再計算/内向き補正して輪郭の膨張方向に使う**（display法線は据え置き＝見た目不変）。**リスク＝帽子が厚みゼロのペラペラ殻だと法線補正だけでは不足→帽子に薄い厚みを持たせる等の追加一手**（その場合も全キャラ自動処理・ユーザーは触らない）。
  - 全てClaude/Sonnet作業。**波及注意＝全キャラ自作頭化で、skin無し追従/約1.5m沈み等の自作GLB課題も全キャラに拡大**（上の項と同根）

### 【新規・2026-07-14 ユーザー要望】全職ちびキャラ化

Witchのちびプロポーションを全KayKit職へ拡大したい。現状 `_KAYKIT_CHIBI_JOBS=[WITCH]` のみ。`_apply_kaykit_head_assembly`（2026-07-15にchibi専用から汎用化）＋`kaykit_chibi_body_mult` を全職に広げ、各モデルが頭スケールで破綻しないか要確認（設計/目視）。

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
  - [x] ~~**B3ドラゴン差し替え決定（2026-07-18）**~~ **素材抽出完了（2026-07-18）**：Dungeon Mason「Dragon for Boss Monster: PBR」に決定・無料・標準Unity EULA＝Godot組み込み可。**Unity Editor経由のインポートは版差（パッケージ原本2018.4.21→手元Editor6.5）でシェーダー自動アップグレードが実質ハングし失敗**（Package Managerで進行が完全停止・Assetsに1ファイルも生成されず）。**代わりにUnity Asset Storeのローカルキャッシュ`.unitypackage`（`%APPDATA%\Unity\Asset Store-5.x\<発行者>\<パック名>.unitypackage`＝gzip+tar形式）を直接`tar`展開し、`pathname`ファイルでGUIDフォルダから本来のパスへ再構築**する手法でEditorを一切経由せず抽出（今後の有償Unityアセット取得はこの手法が本命・Editorの安定性に依存しない）。`assets/dungeon-mason-dragons/`へ配置済み（4体×4色・アニメ17種×4体＝1クリップ1FBX形式・計150ファイル約459MB・**未コミット**）。**残**：①4体×4色から実際に使う1体1色へ絞り込み（残りは容量削減のためコミット前に削除）②Godotへ実際にFBXインポートしメッシュ/スケルトン/テクスチャが崩れず入るか確認③アニメーションは1クリップ1FBXなのでKayKitの外部アニメ合流方式（`_build_kaykit_anim_player`と同じ手法）で1つのAnimationPlayerへ合流する実装④`battle_scene.gd`へ新規ファイル+トグルで組み込み。既存Quaternius `Dragon_Evolved` は差し替え完了までのフォールバックとして無改変で残す
  - [ ] **B3本採用の判断待ち（2026-07-18追加）**：上記Dungeon Masonと並行して、Blender MCP経由の手打ちドラゴン自作を試行（`tools/_dragon_gen/dragon_workshop.blend`）。プリミティブ+Skinモディファイア+リング分岐トポロジーで胴体・角・口の技術的課題は解決できたが、目の眼窩・角と頭の色境界・翼膜テクスチャ等の細部で技法的な限界に達し、自作は打ち切り。代わりにSketchfabの無料CC-BYモデル「Stylized Red/Black dragon」(BBangzip作, UID:5aba72274f2f4036b9e322f59492ac22)をBlenderにインポート済み（ワイバーン型・脚2本+翼2枚、Dungeon Masonとは骨格構成が異なる）。**Dungeon Mason（既に素材抽出済み）とSketchfab版のどちらを本採用するかは未決定**。決めたら片方の残作業（Godotインポート→アニメ合流→battle_scene.gd組み込み）に進む
  - [ ] **敵グラ刷新：非人型モンスター候補7体を採用決定（2026-07-18）**：Pathfinderモンスター一覧を基にSketchfabを画風基準（BBangzip系の鮮やかなベタ塗りトゥーン調、写実的な彫刻調は除外）で探索・目視確認した結果、以下7体を採用候補として確定。CC Attribution（クレジット表記要）・ダウンロード可能。**残：実際にBlenderへダウンロード→サイズ調整→Godotへインポートしてメッシュ/アニメが崩れず入るか確認→使う敵種を決めてenemy_generator.gd等へ組み込み**
    - Mimic Chest（異形代替）— UID: 25f5d411a6bc4c1f86d4b5b6e93ad49b／作者Dylan.Sakiri／アニメ不明
    - Minataur Low Poly（人型怪物）— UID: cf453c95639e49d58e4cd1637df85aee／作者bagatir／アニメ不明
    - Eblan（人造・ゴーレム）— UID: a1e604f5e099427f853300c54c9578be／作者PolyTigr／アニメ不明
    - Venus Pie Trap（植物）— UID: 1021aa85a7f94fb3a8038e20cccba651／作者LizzyKoopa／アニメ不明
    - Shark – Animated Low Poly（水棲）— UID: e5d8d8b011f548de98bc0796680ed7cd／作者WildPoly3D／アニメ有
    - Unicorn – Animated Low Poly（魔獣）— UID: 2a58f78afbfa4311ad6258ccf54fc866／作者WildPoly3D／アニメ有
    - Griffin (Animated)（魔獣）— UID: a8852f113416426bb06e6bba49a525a9／作者VitSh／アニメ有
  - [ ] **オリジナル敵の自作パイロット「ビッグマウス（仮）」＝三面図のユーザーOK/NG待ち（2026-07-19着手）**：参考画像（茶色一つ目・巻き角・巨大口）をクレイ風ローポリへ翻訳する。方式＝のっぺらぼう頭+借り物髪の公式の敵版（体=単純形状のみ自作／表面の味=既存クレイシェーダー任せ／目・歯・角=別メッシュのハードサーフェス）。**下顎は開閉対応の別パーツ**（ヒンジ=口角の高さ）。三面図=`assets/enemy_candidates/custom/bigmouth/design_sheet.svg`(+.png)＝v10（ユーザー指摘で①歯は隙間なく密着した幅広ブロック・上歯はやや短く②腕は体の側面から③目と角を拡大・角は肉厚も④顔を小さく体を大きい洋梨シルエット⑤側面の口は前に突出させず内側へのクサビ⑥足を拡大⑦**側面視で腕の付け根が胴の奥行きをほぼ全部覆う**＝口のクサビ直後から背面まで／それに伴い腕を太く（肩幅4.85u）、を反映済み）。2026-07-18の自作打ち切り（顔と着色が壁）との違い＝顔は単純パーツへ分解・着色はフラット塗りでシェーダーに委譲。**次＝OKならヘッドレスBlender（d:/dev/blender）でSkinモディファイアのブロックアウト→多方向レンダ⇄三面図比較の自動反復→着色→GLB出力→Godot確認**
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

- [ ] **ショート動画ネタ台帳＝`docs/sns_video_backlog.md`**（#2以降を時系列で12本＋予備。#1「仕様書を読め」制作済）。フォーマット固定＝15秒＋ゆっくり実況＋字幕。**週末にまとめ撮り10本タメ予定**。選んだら台本化はClaudeが担当（過去回1本を渡せば形を合わせる）

## プロト2以降の検討

→ `docs/proto2_design.md` へ移行済み（個体値＋偏差/手続き生成2原則/敵行動乱数/状態トグル/KayKit基盤）。プロト2着手時にそこから backlog へタスク切り出し

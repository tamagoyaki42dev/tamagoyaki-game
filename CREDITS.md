# クレジット・素材ライセンス台帳

ゲームに使用した外部素材の**帰属表記（クレジット）義務と利用条件**を一元管理する台帳。
**ゲーム内クレジット画面／README の謝辞は、このファイルを元ネタとして生成する**（ここが唯一の真実）。

素材を1点でも追加したら、その瞬間にこの表へ1行足す（コミットまで溜めない）。
判定：**表記義務があるか／商用可か／改変可か／再配布可か** を必ず埋める。不明なら「要確認」と書き、埋まるまで製品ビルドに載せない。

---

## 表記が必須の素材（ゲーム内クレジット画面に必ず載せる）

| 素材名 | 作者/ショップ | 入手元 | 用途 | 商用 | 改変 | 再配布 | 表記文（案） |
|---|---|---|---|---|---|---|---|
| Cute short pinky | felisshoppe | https://booth.pm/ja/items/3566053 | 女性キャラの3D髪（同梱 `FelizHair.zip` の髪メッシュを Blender で切り出し・tint改変して使用） | ✅ 可 | ✅ 可 | ❌ 禁止（単体再配布・転売） | felisshoppe |
| 【無料/Free】ふわおさげ -FuwaOsage- | B.B. Blue star | https://booth.pm/ja/items/6205494 | 女性キャラの3D髪（採用決定・2026-07-12。実装はこれから） | ✅ 可（MMD・2次創作・放送で明記） | ✅ 可 | ❌ 禁止（モデル単体のpublicアップロード禁止・ゲーム焼き込みはOK） | 不要（クレジット表記なくてよい規約だが、任意でB.B. Blue starと記載してもよい） |

**Cute short pinky ライセンス全文（商品説明文＝これが利用条件の全て。ページ下部「特定商取引法に基づく表記」は販売者法情報でライセンスではない）：**
> Intended as a VRChat asset, but can be used for anything. / Please do not resell / Please credit me / Have fun!

- **商用・改変**：明示的禁止なし＋「can be used for **anything**」＝商用ゲームへの組み込み・体/顔削り・tint はいずれも可（2026-07-12 確認）。
- **「do not resell」の解釈**：素材を**単体で（再）販売・再配布する**ことの禁止。作品（ゲーム）に組み込んで作品ごと売るのは resell に当たらない（VRChat素材文化の標準解釈）。
  - **実務上の唯一の注意**：髪の生ファイル（.glb）を**単体で取り出せる形で配布しない**こと。Godotビルド（.pck焼き込み）なら問題なし。素材フォルダをそのままリポジトリ公開する場合は注意。
- 同梱物：`FelizHair.zip`（髪メッシュ・使用）／`VroidPresetPinky.zip`（VRoidプリセット・未使用）。

**FuwaOsage 詳細**：クレジット表記は規約上不要だが、二次配布は「モデル単体のpublicアップロード禁止」のみ（ゲームへの焼き込みは明示的に問題なし）。候補選定の経緯・全文引用は [docs/hair_asset_candidates.md](docs/hair_asset_candidates.md) 参照。

---

## 表記不要の素材（CC0／記録のみ・クレジット画面には出さなくてよい）

CC0（パブリックドメイン相当）は帰属表記義務なし。ただし何を使っているかの記録として残す。各アセットフォルダの `License.txt` が原本。

| 素材群 | 作者 | ライセンス | 用途 |
|---|---|---|---|
| KayKit（Adventurers / Skeletons / Dungeon 他） | Kay Lousberg | CC0 | プレイヤーキャラ本体・アニメ（Rig_Medium系）・ダンジョン |
| Kenney（mini-characters / dungeon / hexagon / nature / platformer / survival kit） | Kenney | CC0 | 旧プレイヤーキャラ・背景・地形 |
| Quaternius（Ultimate Animated Characters / Ultimate Monsters） | Quaternius | CC0 | 敵モンスター・保管用キャラ |

---

## 運用メモ

- **表記義務のある素材を増やすときは慎重に。** クレジット画面のメンテコストが素材ごとに増える。CC0（Kenney/Quaternius/KayKit）で代替できるならそちらを優先する。
- Booth素材は**1点ずつ利用規約が異なる**（作者ごとに商用可否・改変可否・表記義務がバラバラ）。「無料だから自由」ではない。導入前に必ずこの表を埋めること。
- 表記文（案）列は、ゲーム内クレジット画面に載せる実際の文言。作者の指定フォーマット（「〇〇 by △△」等）があればそれに従う。

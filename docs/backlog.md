# バックログ（未実装タスク）

セッション開始時に自動表示される。完了したら該当行を削除すること。

---

## 演出化粧（演出土台完成後）

- [ ] グロー/ブルーム（WorldEnvironment glow_enabled）※後回し・要再判断

## アート

- [ ] 武器表示の不具合調査・調整
  - 武器が出ないキャラがいる（原因未調査）
  - `weapon_offset` / `weapon_scale` の目視調整が必要かもしれない
  - キャラモデル変更後の見た目確認（職業→モデル対応が正しいか）

## UI（戦場⇔パネル紐付け）

Phase 1（色アクセントリング＋番号バッジ＋パネル左帯で色対応）完了。残り：

- [ ] Phase 2：右パネルを要点再構成（職・位置・HP数値）＋ SubViewport 正面画像（`UPDATE_ONCE`）
- [ ] Phase 3：ホバー パネル→戦場（行ホバーで対応ユニットのリングを強調）
- [ ] Phase 4：ホバー 戦場→パネル（3Dマウスピッキング導入。SubViewport `physics_object_picking`）

## ゲームシステム

- [ ] 複数敵対応
- [ ] 敵の作成：`docs/proto1_3battle_design.md` に基づき EnemyData 3体を確定値で構築
- [ ] 3戦ゲームループ（編成画面→戦闘×3→終了。設計：`docs/proto1_3battle_design.md`。拠点画面・世代継承はプロト1対象外）

## プロト2以降の検討

- [ ] キャラ基盤を KayKit Adventurers（Kay Lousberg / CC0・$0ティアあり）へ乗せ換え検討。ファンタジーRPG native（Mage/Knight/Barbarian/Rogue/Ranger＋武器・帽子・杖同梱）でジャンル適合が高い。modular でパーツ着せ替え可。グラデアトラスで色替えも Blender 不要
  - **乗り換え可否の最大の関門：アニメ名が現行コード依存（`idle` / `attack-melee-right` / `attack-melee-left` / `die`）と一致するか。不一致ならアニメ呼び出しコードの差し替えが必要**
  - 進め方：Free版を落として Mage 1体スパイク → アニメ名・見栄え・色替えを確認してから全替え判断
  - Kenney mini と混在禁止（やるなら全部 KayKit に寄せる）
  - プロト1はこのまま Kenney mini で完走する（今は寄り道しない）

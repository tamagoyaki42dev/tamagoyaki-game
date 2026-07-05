extends GutTest

# _build_kaykit_anim_player が生成する AnimationPlayer に find_child("AnimationPlayer") で
# 再アクセスできることを検証する回帰テスト。
#
# 過去に発生した実バグ：add_child() を name 未設定のまま呼ぶと Godot が
# 「@AnimationPlayer@123」のような内部名を自動付与し、find_child("AnimationPlayer") が
# 見つけられなくなる（_spawn_char 内部の直接参照は動くため idle だけは再生され、
# 攻撃/死亡アニメだけが無音で失敗する＝気づきにくい）。実機で発覚し1行で修正済み。

func test_kaykit_anim_player_is_findable_by_name() -> void:
	var char_scene: PackedScene = load("res://assets/kaykit/characters/Barbarian.glb")
	var ch: Node3D = char_scene.instantiate()
	add_child(ch)

	var built: AnimationPlayer = BattleScene._build_kaykit_anim_player(ch)
	assert_not_null(built, "AnimationPlayer が生成される")

	var found: AnimationPlayer = ch.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_not_null(found, "find_child(\"AnimationPlayer\") で再アクセスできる（内部名化の再発防止）")
	assert_eq(found, built, "find_child で見つかるのは _build_kaykit_anim_player の戻り値と同一インスタンス")

	assert_true(built.has_animation("general/Idle_A"), "general ライブラリが合流している")
	assert_true(built.has_animation("melee/Melee_1H_Attack_Chop"), "melee ライブラリが合流している")
	assert_true(built.has_animation("ranged/Ranged_Magic_Spellcasting"), "ranged ライブラリが合流している")

	ch.queue_free()

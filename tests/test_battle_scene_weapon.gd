extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す
# → _ready() は実行されないため @export デフォルト値のみを検証する

func test_weapon_scale_default() -> void:
	var scene := BattleScene.new()
	assert_almost_eq(scene.weapon_scale, 0.3, 0.001,
		"weapon_scale のデフォルト値が 0.3 である")
	scene.free()

# _attach_weapon が武器を右手（arm-right）ボーンに付ける検証
# 攻撃アニメ attack-melee-right（右腕）と振る手を一致させるため
func test_weapon_attaches_to_arm_right() -> void:
	var scene := BattleScene.new()

	# arm-right ボーンを持つ最小スケルトンを用意
	var ch := Node3D.new()
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	skeleton.add_bone("arm-right")
	ch.add_child(skeleton)

	# 武器パスを持つ職業（WARRIOR）でユニットを構築
	var cd := CharacterData.new()
	cd.job = CharacterJob.Type.WARRIOR
	var unit := BattleUnit.new()
	unit.source_data = cd

	scene._attach_weapon(ch, unit)

	var attachments := skeleton.find_children("", "BoneAttachment3D", true, false)
	assert_eq(attachments.size(), 1,
		"_attach_weapon が BoneAttachment3D を1個生成する")
	if attachments.size() > 0:
		var attachment := attachments[0] as BoneAttachment3D
		assert_eq(attachment.bone_name, "arm-right",
			"武器のアタッチ先ボーンが arm-right である")

	ch.free()
	scene.free()

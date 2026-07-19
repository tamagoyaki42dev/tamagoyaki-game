extends GutTest

# BattleScene をシーンツリーに追加せず .new() のみ呼び出す（test_battle_scene_weapon.gd と同じ流儀）

# CustomHead/HairMesh も無くchibiでもない職＝ネイティブ頭はスキンで正しく追従するため無変化
func test_no_custom_parts_and_not_chibi_is_noop() -> void:
	var scene := BattleScene.new()
	var ch := Node3D.new()
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	skeleton.add_bone("head")
	ch.add_child(skeleton)
	add_child_autofree(ch)

	scene._apply_kaykit_head_assembly(ch, false)

	var attachments := skeleton.find_children("", "BoneAttachment3D", true, false)
	assert_eq(attachments.size(), 0,
		"CustomHead/HairMeshも無くchibiでもなければBoneAttachment3Dを作らない")

	scene.free()

# CustomHead（自作パーツ）はchibiでなくても常にheadボーンへ剛体追従させる
func test_custom_head_reattaches_to_head_bone_even_when_not_chibi() -> void:
	var scene := BattleScene.new()
	var ch := Node3D.new()
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	skeleton.add_bone("head")
	ch.add_child(skeleton)

	var custom_head := MeshInstance3D.new()
	custom_head.name = "CustomHead"
	custom_head.skin = Skin.new()
	custom_head.skeleton = NodePath("../Skeleton3D")
	ch.add_child(custom_head)
	add_child_autofree(ch)

	scene._apply_kaykit_head_assembly(ch, false)

	var attachments := skeleton.find_children("", "BoneAttachment3D", true, false)
	assert_eq(attachments.size(), 1,
		"CustomHead があれば非chibiでもBoneAttachment3Dを1個生成する")
	if attachments.size() > 0:
		var attachment := attachments[0] as BoneAttachment3D
		assert_eq(attachment.bone_name, "head", "アタッチ先がheadボーンである")
		var holder := attachment.get_node_or_null("HeadAssembly")
		assert_not_null(holder, "HeadAssembly holderが作られる")
		if holder:
			assert_eq((holder as Node3D).scale, Vector3.ONE,
				"非chibiでは拡大しない(等倍)")
			assert_true(holder.get_children().has(custom_head),
				"CustomHeadがholder配下へ移動している")
	assert_eq(custom_head.skin, null, "剛体追従に切り替えるためskinを外す")
	assert_eq(custom_head.skeleton, NodePath(), "剛体追従に切り替えるためskeleton参照を外す")

	scene.free()

# chibi職はネイティブの頭メッシュ(_Head)も一緒に巻き込み、kaykit_chibi_head_boost倍で拡縮する
func test_chibi_pulls_in_native_head_mesh_and_applies_boost() -> void:
	var scene := BattleScene.new()
	var ch := Node3D.new()
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	skeleton.add_bone("head")
	ch.add_child(skeleton)

	var native_head := MeshInstance3D.new()
	native_head.name = "Witch_Head"
	skeleton.add_child(native_head)
	add_child_autofree(ch)

	scene._apply_kaykit_head_assembly(ch, true)

	var attachments := skeleton.find_children("", "BoneAttachment3D", true, false)
	assert_eq(attachments.size(), 1, "chibiは該当パーツが無くてもBoneAttachment3Dを作る")
	if attachments.size() > 0:
		var holder := attachments[0].get_node_or_null("HeadAssembly")
		assert_not_null(holder, "HeadAssembly holderが作られる")
		if holder:
			assert_eq((holder as Node3D).scale, Vector3.ONE * scene.kaykit_chibi_head_boost,
				"chibiはkaykit_chibi_head_boost倍に拡大する")
			assert_true(holder.get_children().has(native_head),
				"ネイティブの頭メッシュ(_Head)もholder配下へ移動している")

	scene.free()

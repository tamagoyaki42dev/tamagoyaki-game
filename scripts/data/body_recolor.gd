class_name BodyRecolor
extends Resource
## キャラ体（KayKitモデル）のバンド色差分を持つ再利用可能データ。
## 素体GLBは1つ共有し、「服＝あずき／マント＝赤紫」のような色変えだけをこの.tresで持つ
## （CLAUDE.md「視覚＝データの関数」／dev_tooling_design.md A1）。
##
## 4本の平行配列で1件の上書きを表す（i番目が1つの塗り替え指示）：
##   slots[i]            … 対象メッシュスロット名（"Body" / "Cape" 等・char_customizer._slot_of準拠）
##   band_indices[i]     … そのスロットで detect_uv_color_bands が返す何番目のバンドか
##   override_colors[i]  … 置き換える色
##   reference_colors[i] … 作成時のバンド色（モデル差し替えでバンド番号がズレたときのドリフト検出用）
##
## recolor_part() が食う {band_idx:Color} は band_tint_for(slot) で組む。
## 検出・塗り替えの実処理は char_customizer の static（detect_uv_color_bands / recolor_part）を使う。

## この差分を作ったときの素体GLBパス（メタ情報・ドリフト診断の手掛かり）
@export var source_model: String = ""

@export var slots: PackedStringArray = []
@export var band_indices: PackedInt32Array = []
@export var override_colors: PackedColorArray = []
@export var reference_colors: PackedColorArray = []

## ドリフト判定に使う色距離（|dr|+|dg|+|db|）のしきい値。detect側 merge_threshold と同オーダー。
const DRIFT_THRESHOLD := 0.2

func is_empty() -> bool:
	return slots.is_empty()

## 指定スロットの {band_idx(int): 上書きColor} を返す（recolor_part の band_tint 引数用）。
func band_tint_for(slot: String) -> Dictionary:
	var out: Dictionary = {}
	for i in slots.size():
		if slots[i] == slot:
			out[band_indices[i]] = override_colors[i]
	return out

## 上書きを持つスロット名の一覧（重複なし）。
func slots_with_overrides() -> PackedStringArray:
	var out: PackedStringArray = []
	for s in slots:
		if not out.has(s):
			out.append(s)
	return out

## 現モデルから検出し直したバンドと作成時の参照色を突き合わせ、ズレたエントリの警告文を返す。
## detected = { slot: Array[ {color:Color, count:int} ] }（detect_uv_color_bands の戻り値をスロット別に）。
func drift_warnings(detected: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for i in slots.size():
		var slot: String = slots[i]
		var idx: int = band_indices[i]
		var ref: Color = reference_colors[i]
		var bands: Array = detected.get(slot, [])
		if idx < 0 or idx >= bands.size():
			out.append("%s: バンド#%d が消えた（検出%d件）" % [slot, idx, bands.size()])
			continue
		var now: Color = (bands[idx] as Dictionary)["color"]
		var d := absf(now.r - ref.r) + absf(now.g - ref.g) + absf(now.b - ref.b)
		if d > DRIFT_THRESHOLD:
			out.append("%s: バンド#%d の色がズレた（%s→%s）" % [slot, idx, ref.to_html(false), now.to_html(false)])
	return out

## ツールの内部状態（スロット別の上書き辞書＋検出バンド）から BodyRecolor を組む。
## per_slot_tint = { slot: {band_idx:Color} }, per_slot_bands = { slot: Array[{color,count}] }。
static func from_tool_state(model: String, per_slot_tint: Dictionary, per_slot_bands: Dictionary) -> BodyRecolor:
	var r := BodyRecolor.new()
	r.source_model = model
	for slot: String in per_slot_tint:
		var tint: Dictionary = per_slot_tint[slot]
		var bands: Array = per_slot_bands.get(slot, [])
		for band_idx: int in tint:
			r.slots.append(slot)
			r.band_indices.append(band_idx)
			r.override_colors.append(tint[band_idx] as Color)
			var ref := Color.MAGENTA
			if band_idx >= 0 and band_idx < bands.size():
				ref = (bands[band_idx] as Dictionary)["color"]
			r.reference_colors.append(ref)
	return r

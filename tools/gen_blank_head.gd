extends SceneTree

# 頭メッシュ専用に「顔を色で消した」アトラスを作る実験ツール。
# 頭が参照するUV範囲を肌色で塗り潰す→目・眉・口が肌色に沈む（ジオメトリの陰影のみ残る）。
# 本番アトラスは触らず、頭メッシュのmaterial_overrideに使う別ファイルを出力する。
# 実行：GODOT --headless --path . --script res://tools/gen_blank_head.gd

const SRC: String = "res://assets/kaykit/characters/Knight_knight_texture.png"
const OUT: String = "res://tools/_knight_head_blank.png"

# Knight_Head のUV bbox（head_uv_probe実測：u[0.0341..0.3285] v[0.0182..0.2139]）＋マージン
# 注意：この矩形はキャラごとにテクスチャのUV配置が異なるため使い回せない
# （Rogue用に作った_rogue_head_blank.pngをKnightに流用したところ別領域の色が漏れて出た＝2026-07-11に実際に踏んだ罠）。
# キャラを変えるたびに head_uv_probe.gd で実測し直してこの4定数とSRC/OUTを更新すること。
const U_MIN: float = 0.020
const U_MAX: float = 0.345
const V_MIN: float = 0.010
const V_MAX: float = 0.230

# 肌色をサンプルする位置（col1 スキン見本の中）
const SKIN_UV: Vector2 = Vector2(0.05, 0.10)

func _initialize() -> void:
	var img: Image = Image.load_from_file(SRC)   # 圧縮済みインポートを避け生PNGを直接読む
	if img == null:
		push_error("failed to load: " + SRC)
		quit()
		return
	img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var skin: Color = img.get_pixel(int(SKIN_UV.x * w), int(SKIN_UV.y * h))
	var x0: int = int(U_MIN * w)
	var x1: int = int(U_MAX * w)
	var y0: int = int(V_MIN * h)
	var y1: int = int(V_MAX * h)
	for y in range(y0, y1):
		for x in range(x0, x1):
			img.set_pixel(x, y, skin)
	img.save_png(OUT)
	print("saved: ", OUT, "  skin=", skin, "  rect=(", x0, ",", y0, ")-(", x1, ",", y1, ")")
	quit()

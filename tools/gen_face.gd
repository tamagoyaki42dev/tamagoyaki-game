extends SceneTree

# pokke風の「かわいい顔」をパラメータから手続き生成する実験ツール（絵を描かずに顔を作る）。
# 目・口・チークを図形で合成する。数値を変えれば目鼻口の大きさ・形・位置が変わる。
# 実行：GODOT --headless --path . --script res://tools/gen_face.gd
# 出力：res://tools/_face_preview.png

const W: int = 512
const H: int = 512
const OUT: String = "res://tools/_face_preview.png"

# ---- 調整パラメータ（ここをいじると顔が変わる）----
# パワプロ的デフォルメ狙い：グラデ・ぼかしをやめてベタ塗り2色構成にする。
# KayKitはリアルタイム陰影のフラット面なので、顔側も「陰影を持たないベタ塗り」に寄せると衝突しにくい。
const EYE_CX_OFFSET: float = 96.0   # 中心から左右目までの距離（大=離れ目）
const EYE_CY: float        = 296.0  # 目の縦位置（大=下がる）
const EYE_RX: float        = 54.0   # 目の横半径（大=横広）
const EYE_RY: float        = 58.0   # 目の縦半径（参考画像に寄せてやや縦長に戻した）
const EYE_COLOR: Color     = Color(0.14, 0.10, 0.16)   # 目の色（ほぼ黒。虹彩とのコントラストをはっきり）
const IRIS_COLOR: Color    = Color(0.40, 0.26, 0.52)   # 瞳の地色（上側・暗め）
const IRIS_RIM_COLOR: Color = Color(0.62, 0.50, 0.78)  # 瞳下側の明るいリムライト（2色構成で奥行きを出す。参考画像の瞳の輝き対策）
const IRIS_RATIO: float    = 0.62   # 瞳の大きさ（目に対する比率。大きいほど瞳が占める割合UP）
const HL_RX: float         = 15.0   # ハイライト横半径（小さめの点状に）
const HL_RY: float         = 15.0
const HL_DX: float         = -17.0  # ハイライトのズレ
const HL_DY: float         = -20.0

const MOUTH_CY: float      = 336.0  # 目のすぐ下まで引き上げ（以前402=離れすぎて孤立して見えた）
const MOUTH_RX: float      = 14.0
const MOUTH_RY: float      = 6.0    # 潰して「への字/一文字」寄りの単純形に
const MOUTH_COLOR: Color   = Color(0.55, 0.22, 0.28)   # 濃いめのベタ色（薄いピンクだと肌に埋もれる）

const BLUSH_DX: float      = 130.0   # 目に寄せる（以前176=離れすぎて泥に見えた）
const BLUSH_CY: float      = 316.0   # 目とほぼ同じ高さに寄せる
const BLUSH_RX: float      = 26.0    # 一回り小さく
const BLUSH_RY: float      = 14.0
const BLUSH_COLOR: Color   = Color(1.0, 0.55, 0.55, 0.55)   # 不透明度を上げてベタ寄りに（薄すぎると濁って見える）

const BROW_CY: float       = 232.0   # 目に少し寄せる（以前220=離れて浮いていた）
const BROW_RX: float       = 34.0    # 参考画像は眉山がしっかり主張する太さ
const BROW_RY: float       = 8.0
const BROW_COLOR: Color    = Color(0.30, 0.20, 0.15, 1.0)   # ベタで濃く（以前0.85透過で薄かった）
const BROW_ROT_DEG: float  = 18.0    # 眉の傾き（水平の棒→「く」の字寄りの角度付き眉に。外側が上がる向き

func _initialize() -> void:
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = float(W) * 0.5
	# blush first (behind eyes so it never muddies them)
	for side in [-1.0, 1.0]:
		_ellipse(img, cx + side * BLUSH_DX, BLUSH_CY, BLUSH_RX, BLUSH_RY, BLUSH_COLOR)
	for side in [-1.0, 1.0]:
		var ex: float = cx + side * EYE_CX_OFFSET
		# eyebrow（外側が上がる「く」の字角度。左右で傾きを鏡映させる）
		_ellipse(img, ex, BROW_CY, BROW_RX, BROW_RY, BROW_COLOR, -side * BROW_ROT_DEG)
		# eye base（ベタ塗りの黒目地）
		_ellipse(img, ex, EYE_CY, EYE_RX, EYE_RY, EYE_COLOR)
		# iris（上=暗め、下=明るいリムライトの2色構成。単色ベタだと平板に見えたための対策）
		_ellipse(img, ex, EYE_CY, EYE_RX * IRIS_RATIO, EYE_RY * IRIS_RATIO, IRIS_COLOR)
		_ellipse(img, ex, EYE_CY + EYE_RY * IRIS_RATIO * 0.32, EYE_RX * IRIS_RATIO * 0.82, EYE_RY * IRIS_RATIO * 0.55, IRIS_RIM_COLOR)
		# highlight（小さい点状ハイライト1つのみ）
		_ellipse(img, ex + HL_DX, EYE_CY + HL_DY, HL_RX, HL_RY, Color.WHITE)
	# mouth (small)
	_ellipse(img, cx, MOUTH_CY, MOUTH_RX, MOUTH_RY, MOUTH_COLOR)
	img.save_png(OUT)
	print("saved: ", OUT)
	quit()

func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color, rot_deg: float = 0.0) -> void:
	var rot: float = deg_to_rad(rot_deg)
	var cr: float = cos(rot)
	var sr: float = sin(rot)
	var r: float = max(rx, ry)   # 回転しても収まる安全なバウンディングボックス半径
	var x0: int = int(max(0.0, floor(cx - r)))
	var x1: int = int(min(float(W - 1), ceil(cx + r)))
	var y0: int = int(max(0.0, floor(cy - r)))
	var y1: int = int(min(float(H - 1), ceil(cy + r)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx: float = float(x) - cx
			var dy: float = float(y) - cy
			# 楕円のローカル座標系へ逆回転してから判定（=見た目には楕円がrot_deg傾いた形になる）
			var lx: float = dx * cr + dy * sr
			var ly: float = -dx * sr + dy * cr
			var nx: float = lx / rx
			var ny: float = ly / ry
			if nx * nx + ny * ny <= 1.0:
				var dst: Color = img.get_pixel(x, y)
				# simple alpha-over
				var a: float = col.a
				var out: Color = Color(
					col.r * a + dst.r * (1.0 - a),
					col.g * a + dst.g * (1.0 - a),
					col.b * a + dst.b * (1.0 - a),
					a + dst.a * (1.0 - a))
				img.set_pixel(x, y, out)

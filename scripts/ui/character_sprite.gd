class_name CharacterSprite
extends Control

var job: int = -1
var tint: Color = Color(0.35, 0.52, 0.82)

func setup(p_job: int, p_tint: Color) -> void:
	job = p_job
	tint = p_tint
	queue_redraw()

func _draw() -> void:
	var cx     := size.x * 0.5
	var h      := size.y
	var w      := size.x
	var skin   := Color(0.94, 0.80, 0.68)
	var cloth  := tint
	var dark   := tint.darkened(0.30)

	var head_r   := w * 0.21
	var head_cy  := h * 0.15
	var body_w   := w * 0.44
	var body_top := head_cy + head_r + 3.0
	var body_h   := h * 0.26
	var arm_w    := w * 0.14
	var arm_h    := h * 0.20
	var leg_w    := w * 0.17
	var leg_h    := h * 0.21
	var leg_top  := body_top + body_h
	var la_x     := cx - body_w * 0.5 - arm_w
	var ra_x     := cx + body_w * 0.5

	# 後ろの腕（左）
	draw_rect(Rect2(la_x, body_top + 4, arm_w, arm_h), cloth)
	# 足
	draw_rect(Rect2(cx - leg_w - 1, leg_top,           leg_w, leg_h), dark)
	draw_rect(Rect2(cx + 1,         leg_top,           leg_w, leg_h), dark)
	# 胴体
	draw_rect(Rect2(cx - body_w * 0.5, body_top, body_w, body_h), cloth)
	# 前の腕（右）
	draw_rect(Rect2(ra_x, body_top + 4, arm_w, arm_h), cloth)
	# 頭
	draw_circle(Vector2(cx, head_cy), head_r, skin)
	# 目
	draw_circle(Vector2(cx - head_r * 0.36, head_cy + head_r * 0.10), 1.5, Color(0.15, 0.10, 0.10))
	draw_circle(Vector2(cx + head_r * 0.36, head_cy + head_r * 0.10), 1.5, Color(0.15, 0.10, 0.10))

	_draw_motif(cx, w, h, body_top, body_w, body_h, head_cy, head_r, ra_x, la_x, arm_w)

func _draw_motif(cx: float, w: float, h: float,
		body_top: float, body_w: float, body_h: float,
		head_cy: float, head_r: float,
		ra_x: float, la_x: float, arm_w: float) -> void:
	match job:
		CharacterJob.Type.WARRIOR, CharacterJob.Type.GLADIATOR, CharacterJob.Type.ADVENTURER:
			# 縦剣（右手）
			var sx := ra_x + arm_w * 0.5
			draw_rect(Rect2(sx - 2, body_top - h * 0.20, 4, h * 0.33), Color(0.78, 0.82, 0.92))
			draw_rect(Rect2(sx - 8, body_top - h * 0.04, 16, 3), Color(0.78, 0.68, 0.18))

		CharacterJob.Type.KNIGHT, CharacterJob.Type.DARK_KNIGHT:
			# 剣（右）
			var sx := ra_x + arm_w * 0.5
			draw_rect(Rect2(sx - 2, body_top - h * 0.15, 3, h * 0.27), Color(0.78, 0.82, 0.92))
			draw_rect(Rect2(sx - 7, body_top - h * 0.02, 14, 3), Color(0.75, 0.65, 0.18))
			# 盾（左）
			var shx := la_x + arm_w * 0.5
			var shy := body_top + 2
			draw_colored_polygon(PackedVector2Array([
				Vector2(shx - 9, shy),
				Vector2(shx + 9, shy),
				Vector2(shx + 9, shy + h * 0.16),
				Vector2(shx,     shy + h * 0.22),
				Vector2(shx - 9, shy + h * 0.16),
			]), Color(0.65, 0.68, 0.78))
			draw_line(Vector2(shx, shy + 2), Vector2(shx, shy + h * 0.18), Color(0.45, 0.48, 0.58), 1.5)

		CharacterJob.Type.HOLY_KNIGHT, CharacterJob.Type.VALKYRIE:
			# 翼（背中）
			var wc := Color(1.0, 0.95, 0.85, 0.92)
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - body_w * 0.5 - 1,      body_top + 5),
				Vector2(cx - body_w * 0.5 - w * 0.42, body_top - h * 0.10),
				Vector2(cx - body_w * 0.5 - w * 0.36, body_top + h * 0.15),
				Vector2(cx - body_w * 0.5 - w * 0.28, body_top + h * 0.07),
				Vector2(cx - body_w * 0.5 - 1,      body_top + h * 0.22),
			]), wc)
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx + body_w * 0.5 + 1,      body_top + 5),
				Vector2(cx + body_w * 0.5 + w * 0.42, body_top - h * 0.10),
				Vector2(cx + body_w * 0.5 + w * 0.36, body_top + h * 0.15),
				Vector2(cx + body_w * 0.5 + w * 0.28, body_top + h * 0.07),
				Vector2(cx + body_w * 0.5 + 1,      body_top + h * 0.22),
			]), wc)
			# 剣（右）
			var sx2 := ra_x + arm_w * 0.5
			draw_rect(Rect2(sx2 - 2, body_top - h * 0.15, 3, h * 0.27), Color(0.88, 0.90, 0.98))
			draw_rect(Rect2(sx2 - 7, body_top - h * 0.02, 14, 3), Color(1.0, 0.85, 0.30))

		CharacterJob.Type.MAGE:
			# 三角帽 + 杖（右）
			var hby := head_cy - head_r + 2
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx,         hby - h * 0.24),
				Vector2(cx - w * 0.35, hby + 2),
				Vector2(cx + w * 0.35, hby + 2),
			]), Color(0.22, 0.08, 0.42))
			draw_rect(Rect2(cx - w * 0.39, hby, w * 0.78, 5), Color(0.32, 0.12, 0.52))
			var sx3 := ra_x + arm_w * 0.5
			draw_rect(Rect2(sx3 - 2, body_top - h * 0.10, 3, h * 0.30), Color(0.52, 0.36, 0.18))
			draw_circle(Vector2(sx3, body_top - h * 0.12), 5, Color(0.70, 0.30, 0.95))

		CharacterJob.Type.WITCH:
			# 魔女帽（斜め）+ 羽飾り + 杖（右）
			var hby2 := head_cy - head_r + 2
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx + w * 0.08,  hby2 - h * 0.28),
				Vector2(cx - w * 0.24,  hby2 + 2),
				Vector2(cx + w * 0.24,  hby2 + 2),
			]), Color(0.08, 0.04, 0.12))
			draw_rect(Rect2(cx - w * 0.44, hby2, w * 0.88, 6), Color(0.15, 0.06, 0.22))
			draw_line(Vector2(cx + w * 0.24, hby2 + 3),
				Vector2(cx + w * 0.40, hby2 - h * 0.12), Color(0.95, 0.35, 0.45), 2)
			var sx4 := ra_x + arm_w * 0.5
			draw_rect(Rect2(sx4 - 2, body_top - h * 0.10, 3, h * 0.30), Color(0.52, 0.36, 0.18))
			draw_circle(Vector2(sx4, body_top - h * 0.12), 4, Color(0.95, 0.65, 0.20))

		CharacterJob.Type.ILLUSIONIST:
			# 3つのオーブ + ローブすそ
			var orb_cols := [Color(0.90, 0.30, 0.85), Color(0.30, 0.72, 0.96), Color(0.96, 0.76, 0.20)]
			var orb_angs := [0.0, TAU / 3.0, TAU * 2.0 / 3.0]
			for i in 3:
				var ox := cx + cos(orb_angs[i]) * w * 0.42
				var oy := body_top + body_h * 0.5 + sin(orb_angs[i]) * h * 0.09
				draw_circle(Vector2(ox, oy), 4, orb_cols[i])
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - body_w * 0.5 - 3, body_top),
				Vector2(cx + body_w * 0.5 + 3, body_top),
				Vector2(cx + body_w * 0.5 + 7, body_top + body_h * 1.5),
				Vector2(cx - body_w * 0.5 - 7, body_top + body_h * 1.5),
			]), tint.darkened(0.10))

		CharacterJob.Type.ARCHER:
			# バンダナ + 弓（右）
			draw_rect(Rect2(cx - head_r - 1, head_cy - 4, (head_r + 1) * 2, 7), Color(0.28, 0.52, 0.28, 0.9))
			var bx := ra_x + w * 0.10
			var pts: PackedVector2Array
			pts.resize(9)
			for i in 9:
				var t := float(i) / 8.0
				var ang: float = lerp(-0.80, 0.80, t)
				pts[i] = Vector2(bx - cos(ang) * w * 0.22, body_top + h * 0.12 + sin(ang) * h * 0.17)
			for i in 8:
				draw_line(pts[i], pts[i + 1], Color(0.52, 0.36, 0.16), 2.5)
			draw_line(pts[0], pts[8], Color(0.92, 0.88, 0.68), 1.0)

		CharacterJob.Type.MONK:
			# 帯 + 両拳グロー
			draw_rect(Rect2(cx - body_w * 0.5, body_top + body_h * 0.46, body_w, 5), Color(0.88, 0.72, 0.22))
			draw_circle(Vector2(ra_x + arm_w * 0.5, body_top + h * 0.19), 6, Color(1.0, 0.65, 0.20, 0.65))
			draw_circle(Vector2(la_x + arm_w * 0.5, body_top + h * 0.19), 6, Color(1.0, 0.65, 0.20, 0.65))

		CharacterJob.Type.CLERIC:
			# 後光 + 十字スタッフ（右）
			draw_arc(Vector2(cx, head_cy - head_r * 0.4), head_r * 1.25, 0.0, TAU, 28,
				Color(1.0, 0.90, 0.30, 0.90), 2.5)
			var sx5 := ra_x + arm_w * 0.5
			draw_rect(Rect2(sx5 - 2, body_top - h * 0.20, 3, h * 0.34), Color(0.82, 0.75, 0.50))
			draw_rect(Rect2(sx5 - 8, body_top - h * 0.13, 17, 3), Color(0.82, 0.75, 0.50))

		CharacterJob.Type.SHAMAN:
			# 羽飾り（頭）+ 杖（左）+ 緑オーブ
			draw_line(Vector2(cx + head_r * 0.35, head_cy - head_r),
				Vector2(cx + head_r * 0.65, head_cy - head_r * 2.4), Color(0.90, 0.35, 0.10), 3)
			draw_line(Vector2(cx + head_r * 0.50, head_cy - head_r * 0.7),
				Vector2(cx + head_r * 0.85, head_cy - head_r * 1.9), Color(0.95, 0.70, 0.20), 2)
			var sx6 := la_x + arm_w * 0.5
			draw_rect(Rect2(sx6 - 2, body_top - h * 0.15, 3, h * 0.33), Color(0.55, 0.38, 0.18))
			draw_circle(Vector2(sx6, body_top - h * 0.17), 5, Color(0.45, 0.90, 0.45, 0.88))

		CharacterJob.Type.SHRINE_MAIDEN:
			# 袖（赤）上書き + 帯
			var sc := Color(1.0, 0.30, 0.35, 0.92)
			draw_colored_polygon(PackedVector2Array([
				Vector2(la_x - 3,          body_top + 2),
				Vector2(cx - body_w * 0.5, body_top),
				Vector2(cx - body_w * 0.5, body_top + body_h * 0.85),
				Vector2(la_x - 3,          body_top + body_h * 0.65),
			]), sc)
			draw_colored_polygon(PackedVector2Array([
				Vector2(ra_x + arm_w + 3,  body_top + 2),
				Vector2(cx + body_w * 0.5, body_top),
				Vector2(cx + body_w * 0.5, body_top + body_h * 0.85),
				Vector2(ra_x + arm_w + 3,  body_top + body_h * 0.65),
			]), sc)
			draw_rect(Rect2(cx - body_w * 0.5 - 2, body_top + body_h * 0.55,
				body_w + 4, 6), Color(0.85, 0.15, 0.20))

		CharacterJob.Type.SAMURAI:
			# 斜め刀（右）+ 胸甲ハイライト
			var k0 := Vector2(ra_x + 2, body_top + 6)
			var k1 := Vector2(ra_x + w * 0.40, body_top - h * 0.22)
			draw_line(k0, k1, Color(0.82, 0.86, 0.95), 3)
			draw_circle(k0 + (k1 - k0) * 0.28, 4, Color(0.70, 0.60, 0.15))
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - body_w * 0.5 + 1, body_top + 2),
				Vector2(cx + body_w * 0.5 - 1, body_top + 2),
				Vector2(cx + body_w * 0.5 - 3, body_top + body_h * 0.55),
				Vector2(cx - body_w * 0.5 + 3, body_top + body_h * 0.55),
			]), tint.lightened(0.22))

		CharacterJob.Type.NINJA:
			# 頭巾で頭を上書き
			draw_circle(Vector2(cx, head_cy), head_r, Color(0.10, 0.10, 0.15))
			draw_circle(Vector2(cx - head_r * 0.36, head_cy + head_r * 0.10), 1.5, Color(0.80, 0.80, 0.88))
			draw_circle(Vector2(cx + head_r * 0.36, head_cy + head_r * 0.10), 1.5, Color(0.80, 0.80, 0.88))
			# 手裏剣（右手）
			var shx := ra_x + arm_w * 0.5
			var shy := body_top + h * 0.06
			for i in 4:
				var ang := float(i) * PI * 0.5 + PI * 0.25
				draw_line(
					Vector2(shx + cos(ang) * 7, shy + sin(ang) * 7),
					Vector2(shx + cos(ang + PI * 0.5) * 3, shy + sin(ang + PI * 0.5) * 3),
					Color(0.75, 0.80, 0.88), 2)

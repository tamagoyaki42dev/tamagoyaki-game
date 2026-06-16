class_name ArenaBg
extends Control

func _draw() -> void:
	var W  := size.x
	var H  := size.y
	var cx := W * 0.5
	var rng := RandomNumberGenerator.new()

	var stone      := Color(0.72, 0.60, 0.44)
	var stone_dark := Color(0.26, 0.20, 0.13)

	# ── 夜空 ─────────────────────────────────────────────
	draw_rect(Rect2(0, 0, W, H * 0.18), Color(0.03, 0.02, 0.04))
	rng.seed = 111
	for _i in 20:
		var x: float = rng.randf() * W
		var y: float = rng.randf() * H * 0.11
		var r: float = rng.randf_range(1.2, 3.0)
		draw_circle(Vector2(x, y), r, Color(0.92, 0.80, 0.48, rng.randf_range(0.4, 0.85)))

	# ── 奥の石壁 ─────────────────────────────────────────
	var wall_top: float = H * 0.14
	var wall_bot: float = H * 0.58
	draw_rect(Rect2(0, wall_top, W, wall_bot - wall_top), stone)

	# 壁の陰影（端と下部を暗く）
	for i in 8:
		var t: float = float(i) / 7.0
		var m: float = t * W * 0.14
		draw_rect(Rect2(0, wall_top, m, wall_bot - wall_top),
			Color(0.0, 0.0, 0.0, 0.048 - t * 0.006))
		draw_rect(Rect2(W - m, wall_top, m, wall_bot - wall_top),
			Color(0.0, 0.0, 0.0, 0.048 - t * 0.006))
	for i in 8:
		var t: float = float(i) / 7.0
		var y: float = wall_top + (wall_bot - wall_top) * t
		draw_rect(Rect2(0, y, W, (wall_bot - wall_top) * 0.13),
			Color(0.06, 0.04, 0.02, t * 0.28))

	# ── クレネレーション（凸凹城壁） ─────────────────────
	var c_count := 14
	var c_w: float = W / float(c_count)
	var merlon_h: float = H * 0.055
	for i in c_count:
		if i % 2 == 0:
			draw_rect(Rect2(float(i) * c_w + 1, wall_top - merlon_h, c_w - 2, merlon_h + 2), stone)
		else:
			draw_rect(Rect2(float(i) * c_w + 1, wall_top - merlon_h, c_w - 2, merlon_h),
				Color(0.03, 0.02, 0.04))

	# ── アーチ開口部（5つ） ───────────────────────────────
	var arch_n     := 5
	var arch_w: float  = W / float(arch_n)
	var arch_half: float = arch_w * 0.28
	var arch_base: float = wall_top + (wall_bot - wall_top) * 0.88
	var arch_top: float  = wall_top + (wall_bot - wall_top) * 0.10
	for i in arch_n:
		var ax: float = (float(i) + 0.5) * arch_w
		draw_colored_polygon(_arch(ax, arch_top, arch_base, arch_half), Color(0.05, 0.04, 0.03))
		# 縁取り柱
		var col_top: float = arch_top + (arch_base - arch_top) * 0.30
		draw_rect(Rect2(ax - arch_half - 5, col_top, 5, arch_base - col_top), stone_dark)
		draw_rect(Rect2(ax + arch_half,     col_top, 5, arch_base - col_top), stone_dark)

	# ── 手前の仕切り壁 ───────────────────────────────────
	var ledge_y: float = H * 0.56
	draw_rect(Rect2(0, ledge_y, W, H * 0.08), Color(0.50, 0.40, 0.28))
	draw_rect(Rect2(0, ledge_y, W, 3), Color(0.68, 0.58, 0.44))
	for i in 5:
		var t: float = float(i) / 4.0
		draw_rect(Rect2(0, ledge_y + H * 0.08 * (0.5 + t * 0.5), W, H * 0.012),
			Color(0.04, 0.03, 0.02, 0.10 + t * 0.10))

	# ── アリーナ床（砂地） ───────────────────────────────
	var floor_y: float = ledge_y + H * 0.055
	draw_rect(Rect2(0, floor_y, W, H - floor_y), Color(0.54, 0.43, 0.28))
	for i in 6:
		var t: float = float(i) / 5.0
		draw_rect(Rect2(0, floor_y, W, (H - floor_y) * (1.0 - t)),
			Color(0.64, 0.54, 0.38, 0.038))

	# 月光スポット（楕円の光）
	var sp_cx: float = cx * 0.92
	var sp_cy: float = floor_y + (H - floor_y) * 0.44
	var sp_rx: float = W * 0.21
	var sp_ry: float = (H - floor_y) * 0.27
	for i in 10:
		var t: float = float(i) / 9.0
		var rx: float = sp_rx * (1.0 - t * 0.90)
		var ry: float = sp_ry * (1.0 - t * 0.90)
		draw_colored_polygon(_ellipse(sp_cx, sp_cy, rx, ry, 32),
			Color(0.84, 0.76, 0.58, 0.075 - t * 0.070))

	# 三日月の影
	draw_colored_polygon(
		_ellipse(sp_cx + sp_rx * 0.52, sp_cy - sp_ry * 0.28, sp_rx * 0.70, sp_ry * 0.52, 32),
		Color(0.28, 0.20, 0.11, 0.28))

	# ── ビネット ─────────────────────────────────────────
	for i in 6:
		var t: float = float(i) / 5.0
		var m: float = t * W * 0.14
		draw_rect(Rect2(0,     0, m, H), Color(0, 0, 0, 0.05 - t * 0.008))
		draw_rect(Rect2(W - m, 0, m, H), Color(0, 0, 0, 0.05 - t * 0.008))


# アーチ形ポリゴン（底辺2点 + 上半円）
func _arch(cx: float, top_y: float, base_y: float, hw: float) -> PackedVector2Array:
	var mid_y: float = top_y + (base_y - top_y) * 0.35
	var ry: float    = mid_y - top_y
	var n := 18
	var pts: PackedVector2Array
	pts.resize(n + 2)
	pts[0] = Vector2(cx - hw, base_y)
	pts[1] = Vector2(cx + hw, base_y)
	for i in n:
		var a: float = float(i) / float(n - 1) * PI
		pts[i + 2] = Vector2(cx + cos(a) * hw, mid_y - sin(a) * ry)
	return pts


func _ellipse(cx: float, cy: float, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts: PackedVector2Array
	pts.resize(n)
	for i in n:
		var a: float = float(i) * TAU / float(n)
		pts[i] = Vector2(cx + cos(a) * rx, cy + sin(a) * ry)
	return pts

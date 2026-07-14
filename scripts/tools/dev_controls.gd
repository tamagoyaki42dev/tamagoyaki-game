class_name DevControls
extends RefCounted
## 開発ツール用の「画面完結」コントロール生成ヘルパー（エディタのInspector不要）。
## @export の初期値を画面のUIへ写し、動かしたら target のプロパティへ即書き戻す。
##   数値   → ラベル付きHSlider＋値表示
##   bool   → CheckBox
##   選択肢 → OptionButton
## on_change には「生きているノードへ反映する処理」を渡す（カメラ再配置等）。
## A2表情プリセット・A3敵ツール以降でも使い回す（dev_tooling_design.md「エディタ往復ゼロ」）。

const _LABEL_W := 150
const _VALUE_W := 64

## ラベル付きスライダー行を parent に足す。target.get(prop) を初期値に読み、
## 変更で target.set(prop, v) してから on_change.call(v) を呼ぶ。作った HSlider を返す。
static func add_slider(parent: Container, label: String, target: Object, prop: String,
		min_v: float, max_v: float, step: float, on_change: Callable = Callable()) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lb := Label.new()
	lb.text = label
	lb.custom_minimum_size = Vector2(_LABEL_W, 0)
	row.add_child(lb)

	var sld := HSlider.new()
	sld.min_value = min_v
	sld.max_value = max_v
	sld.step = step
	sld.custom_minimum_size = Vector2(180, 0)
	sld.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var init_v := float(target.get(prop))
	sld.value = init_v
	row.add_child(sld)

	var val_lb := Label.new()
	val_lb.custom_minimum_size = Vector2(_VALUE_W, 0)
	val_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lb.text = _fmt(init_v, step)
	row.add_child(val_lb)

	sld.value_changed.connect(func(v: float) -> void:
		target.set(prop, v)
		val_lb.text = _fmt(v, step)
		if on_change.is_valid():
			on_change.call(v))
	parent.add_child(row)
	return sld

## bool 用チェックボックス行。target.get(prop) を初期状態に読み、切替で書き戻す。
static func add_checkbox(parent: Container, label: String, target: Object, prop: String,
		on_change: Callable = Callable()) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = label
	cb.button_pressed = bool(target.get(prop))
	cb.toggled.connect(func(pressed: bool) -> void:
		target.set(prop, pressed)
		if on_change.is_valid():
			on_change.call(pressed))
	parent.add_child(cb)
	return cb

## 色用ColorPickerButton行。target.get(prop) を初期色に読み、変更で書き戻す。
static func add_color(parent: Container, label: String, target: Object, prop: String,
		on_change: Callable = Callable()) -> ColorPickerButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lb := Label.new()
	lb.text = label
	lb.custom_minimum_size = Vector2(_LABEL_W, 0)
	row.add_child(lb)
	var btn := ColorPickerButton.new()
	btn.custom_minimum_size = Vector2(60, 24)
	btn.color = target.get(prop)
	btn.color_changed.connect(func(c: Color) -> void:
		target.set(prop, c)
		if on_change.is_valid():
			on_change.call(c))
	row.add_child(btn)
	parent.add_child(row)
	return btn

## 選択肢ドロップダウン行。選択で on_selected.call(index) を呼ぶ。作った OptionButton を返す。
static func add_dropdown(parent: Container, label: String, options: PackedStringArray,
		selected_idx: int, on_selected: Callable) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lb := Label.new()
	lb.text = label
	lb.custom_minimum_size = Vector2(_LABEL_W, 0)
	row.add_child(lb)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for o: String in options:
		opt.add_item(o)
	if selected_idx >= 0 and selected_idx < options.size():
		opt.selected = selected_idx
	opt.item_selected.connect(on_selected)
	row.add_child(opt)
	parent.add_child(row)
	return opt

## 見出しラベルを parent に足す。
static func add_header(parent: Container, text: String) -> Label:
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", 16)
	lb.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	parent.add_child(lb)
	return lb

## ステップに応じて小数桁を変えて数値を整形する。
static func _fmt(v: float, step: float) -> String:
	if step >= 1.0:
		return str(int(round(v)))
	elif step >= 0.1:
		return "%.1f" % v
	return "%.2f" % v

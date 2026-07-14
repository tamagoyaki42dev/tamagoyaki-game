class_name FaceExpression
extends Resource

# tools/face_editor.gd の「目/まつ毛/眉/口」パラメータを名前付きで保存・再利用するためのデータ。
# 髪・頭形状・カメラ等（表情に無関係な項目）は含めない。デフォルト値はface_editor.gdの現行値（＝ジト目）と一致。

@export var eye_offset: float = 96.0
@export var eye_cy: float = 284.0
@export var eye_rx: float = 22.0
@export var eye_ry: float = 70.0
@export var eye_squareness: float = 2.3
@export var eye_color: Color = Color(0.20, 0.18, 0.30)
@export var eye_rim_enabled: bool = true
@export var eye_rim_color: Color = Color(0.36, 0.32, 0.50)
@export var eye_rim_ratio: float = 0.67
@export var eye_rim_drop: float = 0.49

@export var lash_enabled: bool = true
@export var lash_color: Color = Color(0.07, 0.06, 0.09)
@export var lash_rx_ratio: float = 1.5
@export var lash_ry: float = 8.0
@export var lash_drop: float = 6.0
@export var lash_rot_deg: float = 8.0

@export var brow_enabled: bool = true
@export var brow_color: Color = Color(0.34, 0.24, 0.19)
@export var brow_inner_dx: float = 37.0
@export var brow_outer_dx: float = 74.0
@export var brow_gap: float = 28.0
@export var brow_tilt: float = 10.0
@export var brow_arch: float = 25.0
@export var brow_thick: float = 5.0

@export var mouth_enabled: bool = false
@export var mouth_color: Color = Color(0.42, 0.24, 0.26)
@export var mouth_cy: float = 361.0
@export var mouth_rx: float = 50.0
@export var mouth_ry: float = 2.0
@export var mouth_smile: float = 8.0

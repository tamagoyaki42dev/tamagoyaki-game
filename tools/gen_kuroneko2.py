#!/usr/bin/env python3
"""
gen_kuroneko2.py  -  黒猫帽子キャラ v2（デフォルメ弱め・奥行き増し）
Output: assets/characters/vox/kuroneko2.vox
Canvas: SX=16, SY=8, SZ=36
Z layout (bottom -> top):
  0- 3  足元
  2-18  身体・ドレス（腕含む）
  4-24  紫髪（両サイド、帽子下からも流れる）
 16-25  顔（帽子の下、スキン色）
 24-33  黒猫帽子（白四角穴 × 2）
 31-35  ネコ耳（三角）
"""
import struct, os

PAL = [(0, 0, 0, 0)] * 256
def pal(idx, r, g, b): PAL[idx - 1] = (r, g, b, 255)

pal(1, 0x12, 0x12, 0x16)  # 1=HAT    帽子・ドレス黒
pal(2, 0x88, 0x35, 0xD8)  # 2=PUR    髪メイン紫
pal(3, 0xF0, 0xBC, 0x88)  # 3=SKIN   顔スキン
pal(4, 0x4E, 0x18, 0x8E)  # 4=DPUR   髪影・リストバンド
pal(5, 0xF0, 0xF0, 0xF2)  # 5=WHT    帽子穴・白目
pal(6, 0x62, 0x28, 0xA0)  # 6=EYE    虹彩
pal(7, 0xAA, 0x66, 0xFF)  # 7=LPUR   髪ハイライト

HAT=1; PUR=2; SKIN=3; DPUR=4; WHT=5; EYE=6; LPUR=7

SX, SY, SZ = 16, 8, 36
cx = 7

vox: dict = {}

def v(x, y, z, c):
    if 0 <= x < SX and 0 <= y < SY and 0 <= z < SZ:
        vox[(x, y, z)] = c

def box(x0, x1, y0, y1, z0, z1, c):
    for x in range(x0, x1+1):
        for y in range(y0, y1+1):
            for z in range(z0, z1+1):
                v(x, y, z, c)

# ─── 1. 紫髪（先に描く）──────────────────────────────────────────────────
# 左右の髪カーテン（幅4・奥行き8でしっかり厚み）
box(0, 3,  0, 7, 4, 26, PUR)
box(12, 15, 0, 7, 4, 26, PUR)
# 後ろ側に影
box(0, 3,  5, 7, 4, 26, DPUR)
box(12, 15, 5, 7, 4, 26, DPUR)
# 前側ハイライト1列
for z in range(4, 27):
    v(1, 0, z, LPUR)
    v(14, 0, z, LPUR)

# ─── 2. 身体・ドレス ──────────────────────────────────────────────────────
# 胴体（立体感のある形）
box(4, 11, 1, 6, 2, 18, HAT)
# スカート裾（下に行くほど広がる）
box(3, 12, 1, 6, 2, 7,  HAT)
box(2, 13, 1, 5, 2, 4,  HAT)

# ─── 3. 腕 ─────────────────────────────────────────────────────────────────
# 左腕（身体の左側に沿わせる）
box(1, 3, 2, 5, 9, 17, HAT)
# 右腕
box(12, 14, 2, 5, 9, 17, HAT)
# 紫リストバンド（手首部分）
box(1, 3, 2, 5, 9, 10, DPUR)
box(12, 14, 2, 5, 9, 10, DPUR)

# ─── 4. 顔（帽子の下から見える部分）─────────────────────────────────────
# 顔の前半分（y=0-3）はスキン色
box(4, 11, 0, 3, 16, 25, SKIN)
# 後ろ半分（y=4-7）は紫髪
box(4, 11, 4, 7, 16, 25, PUR)
# 顔の両サイドは髪
box(0, 3,  0, 7, 16, 25, PUR)
box(12, 15, 0, 7, 16, 25, PUR)

# 目（z=20-22）顔の中段あたり
# 左目
box(4, 5, 0, 1, 20, 22, WHT)
v(4, 0, 21, EYE); v(5, 0, 21, EYE)
# 右目
box(10, 11, 0, 1, 20, 22, WHT)
v(10, 0, 21, EYE); v(11, 0, 21, EYE)

# ─── 5. 黒猫帽子（帽子本体は顔の上半分と重なる）────────────────────────
# 帽子は左右の髪の間（x=3-12）に収める → 髪が帽子サイドから見える
box(3, 12, 0, 7, 24, 33, HAT)

# 白い四角穴（帽子の前面 y=0 のみ）
box(4, 6,  0, 0, 26, 30, WHT)  # 左穴（縦長）
box(9, 11, 0, 0, 26, 30, WHT)  # 右穴（縦長）

# ─── 6. ネコ耳（帽子上部の三角形）────────────────────────────────────────
# 左耳（帽子の左端から生える）
box(3, 6, 0, 5, 31, 32, HAT)   # 根元（幅4）
box(3, 5, 0, 4, 33, 33, HAT)   # 中間
box(3, 4, 0, 3, 34, 34, HAT)   # 先端手前
v(3, 0, 35, HAT); v(3, 1, 35, HAT); v(3, 2, 35, HAT)  # 最先端

# 右耳（帽子の右端から生える）
box(9, 12, 0, 5, 31, 32, HAT)
box(10, 12, 0, 4, 33, 33, HAT)
box(11, 12, 0, 3, 34, 34, HAT)
v(12, 0, 35, HAT); v(12, 1, 35, HAT); v(12, 2, 35, HAT)

# ─── Write .vox ───────────────────────────────────────────────────────────────
def write_vox(path, sx, sy, sz, vox_data, palette):
    def chunk(cid, content, children=b''):
        return cid + struct.pack('<II', len(content), len(children)) + content + children
    xyzi = struct.pack('<I', len(vox_data))
    for (x, y, z), c in vox_data.items():
        xyzi += struct.pack('BBBB', x, y, z, c)
    rgba = b''.join(struct.pack('BBBB', *palette[i]) for i in range(256))
    children = (chunk(b'SIZE', struct.pack('<III', sx, sy, sz))
              + chunk(b'XYZI', xyzi)
              + chunk(b'RGBA', rgba))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(b'VOX '); f.write(struct.pack('<I', 150))
        f.write(chunk(b'MAIN', b'', children))
    print(f"OK  {len(vox_data)} voxels  ->  {path}")

write_vox('assets/characters/vox/kuroneko2.vox', SX, SY, SZ, vox, PAL)

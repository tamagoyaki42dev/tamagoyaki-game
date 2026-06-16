#!/usr/bin/env python3
"""
gen_kuroneko.py  -  黒猫帽子キャラのボクセルモデル（チビデフォルメ）
Output: assets/characters/vox/kuroneko.vox
Canvas: SX=12, SY=4, SZ=24
Z layout (bottom→top):
  0-1   : 足元
  1-10  : 身体・ドレス
  2-19  : 紫髪（両サイド流れる）
  10-14 : 顔（スキン・目）
  14-21 : 黒猫帽子（白四角穴あり）
  20-23 : ネコ耳（三角）
"""
import struct, os

# ── Palette ──────────────────────────────────────────────────────────────────
PAL = [(0, 0, 0, 0)] * 256
def pal(idx, r, g, b): PAL[idx - 1] = (r, g, b, 255)

pal(1, 0x14, 0x14, 0x18)  # 1=HAT    帽子・ドレスの黒
pal(2, 0x88, 0x35, 0xD8)  # 2=PUR    髪メイン紫
pal(3, 0xF0, 0xBC, 0x88)  # 3=SKIN   顔スキン色
pal(4, 0x50, 0x1A, 0x90)  # 4=DPUR   髪影・リストバンド紫
pal(5, 0xF0, 0xF0, 0xF0)  # 5=WHT    帽子の穴・目の白目
pal(6, 0x60, 0x28, 0xA0)  # 6=EYE    目の虹彩

HAT  = 1
PUR  = 2
SKIN = 3
DPUR = 4
WHT  = 5
EYE  = 6

# ── Canvas ────────────────────────────────────────────────────────────────────
SX, SY, SZ = 12, 4, 24
cx = 5  # center x

vox: dict = {}

def v(x, y, z, c):
    if 0 <= x < SX and 0 <= y < SY and 0 <= z < SZ:
        vox[(x, y, z)] = c

def box(x0, x1, y0, y1, z0, z1, c):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            for z in range(z0, z1 + 1):
                v(x, y, z, c)

# ─── 1. 紫髪（先に描いて他のパーツに上書きさせる）────────────────────────
# 両サイドに垂れ下がる
box(0, 2,  0, 3, 2, 19, PUR)   # 左髪
box(9, 11, 0, 3, 2, 19, PUR)   # 右髪
# 奥側に影色
for z in range(2, 20):
    v(0, 3, z, DPUR)
    v(11, 3, z, DPUR)

# ─── 2. 身体・ドレス ──────────────────────────────────────────────────────
box(3, 8, 0, 3, 1, 10, HAT)    # 胴体メイン
box(2, 9, 0, 3, 1, 4, HAT)     # スカート裾（少し広がる）

# ─── 3. 顔（帽子の下から見える部分）─────────────────────────────────────
box(3, 8, 0, 2, 10, 14, SKIN)  # スキン色の顔
# 紫髪が顔の両脇にも
box(0, 2, 0, 3, 10, 14, PUR)
box(9, 11, 0, 3, 10, 14, PUR)

# 目（z=12 付近・左右対称）
box(3, 4, 0, 1, 12, 13, WHT)   # 左目・白目
v(3, 0, 12, EYE); v(4, 0, 12, EYE)  # 左虹彩
box(7, 8, 0, 1, 12, 13, WHT)   # 右目・白目
v(7, 0, 12, EYE); v(8, 0, 12, EYE)  # 右虹彩

# ─── 4. 黒猫帽子（ブリム）────────────────────────────────────────────────
box(0, 11, 0, 3, 14, 20, HAT)  # 帽子本体（横いっぱい）

# 帽子の白い四角穴（前面 y=0 のみ）
box(1, 3, 0, 0, 16, 18, WHT)   # 左の穴
box(8, 10, 0, 0, 16, 18, WHT)  # 右の穴

# ─── 5. ネコ耳（三角形）──────────────────────────────────────────────────
# 左耳
box(1, 3, 0, 2, 20, 21, HAT)   # 耳の根元（幅3）
box(1, 2, 0, 2, 22, 22, HAT)   # 少し細く
v(1, 0, 23, HAT); v(1, 1, 23, HAT)  # 先端

# 右耳
box(8, 10, 0, 2, 20, 21, HAT)  # 耳の根元（幅3）
box(9, 10, 0, 2, 22, 22, HAT)  # 少し細く
v(10, 0, 23, HAT); v(10, 1, 23, HAT)  # 先端

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

write_vox('assets/characters/vox/kuroneko.vox', SX, SY, SZ, vox, PAL)

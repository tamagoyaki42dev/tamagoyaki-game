#!/usr/bin/env python3
"""
gen_kuroneko3.py - 黒猫帽子キャラ v3（リファレンス再現・奥行き強化）
Output: assets/characters/vox/kuroneko3.vox
Canvas: SX=18, SY=12, SZ=36
Z layout:
  0- 7  足元・クロー
  2-17  身体・ドレス
  4-25  紫髪（両サイド、奥行きフル）
 16-24  顔（帽子下から見える）
 22-31  黒猫帽子（大型ブリム・白四角穴）
 30-35  ネコ耳（三角）
"""
import struct, os

PAL = [(0, 0, 0, 0)] * 256
def pal(idx, r, g, b): PAL[idx - 1] = (r, g, b, 255)

pal(1, 0x10, 0x10, 0x14)  # 1=HAT   黒
pal(2, 0x88, 0x38, 0xD8)  # 2=PUR   紫髪
pal(3, 0xF0, 0xBC, 0x88)  # 3=SKIN  顔スキン
pal(4, 0x50, 0x18, 0x90)  # 4=DPUR  髪影・リストバンド
pal(5, 0xF0, 0xF0, 0xF2)  # 5=WHT   帽子穴・白目
pal(6, 0x14, 0x14, 0x1C)  # 6=EYE   黒瞳（白目の中の黒）
pal(7, 0xAA, 0x60, 0xFF)  # 7=LPUR  髪ハイライト

HAT=1; PUR=2; SKIN=3; DPUR=4; WHT=5; EYE=6; LPUR=7

SX, SY, SZ = 18, 12, 36
cx = 8

vox: dict = {}
def v(x, y, z, c):
    if 0 <= x < SX and 0 <= y < SY and 0 <= z < SZ:
        vox[(x, y, z)] = c

def box(x0, x1, y0, y1, z0, z1, c):
    for x in range(x0, x1+1):
        for y in range(y0, y1+1):
            for z in range(z0, z1+1):
                v(x, y, z, c)

# ─── 1. 紫髪（奥行きフル12で厚みたっぷり）───────────────────────────
box(0, 3,  0, 11, 4, 25, PUR)   # 左髪
box(14, 17, 0, 11, 4, 25, PUR)  # 右髪
# 後ろ影（奥4層を暗く）
box(0, 3,  8, 11, 4, 25, DPUR)
box(14, 17, 8, 11, 4, 25, DPUR)
# 前面ハイライト
for z in range(4, 26):
    v(1, 0, z, LPUR)
    v(16, 0, z, LPUR)

# ─── 2. 身体・ドレス（奥行き10）──────────────────────────────────────
box(4, 13, 1, 10, 2, 17, HAT)   # 胴体コア
box(3, 14, 1, 9,  2, 7,  HAT)   # 裾広がり
box(2, 15, 1, 8,  2, 4,  HAT)   # 裾最下部

# ─── 3. 腕（奥行き6）──────────────────────────────────────────────────
box(1, 3,  3, 8, 8, 16, HAT)    # 左腕
box(14, 16, 3, 8, 8, 16, HAT)   # 右腕
# リストバンド（紫）
box(1, 3,  3, 8, 8, 10, DPUR)
box(14, 16, 3, 8, 8, 10, DPUR)

# ─── 4. クロー（腕の先端から外側へ斜めに伸びる）─────────────────────
# 左クロー（x=0方向・下方向に段階的に）
for y in range(3, 9):
    v(1, y, 7, HAT)
    v(0, y, 6, HAT)
    v(0, y, 5, HAT)
    v(0, y, 4, HAT)
    v(0, y, 3, HAT)
# 右クロー
for y in range(3, 9):
    v(16, y, 7, HAT)
    v(17, y, 6, HAT)
    v(17, y, 5, HAT)
    v(17, y, 4, HAT)
    v(17, y, 3, HAT)

# ─── 5. 顔（帽子の下から見える・前6層スキン・後ろは紫）──────────────
box(4, 13, 0, 5,  16, 24, SKIN)  # 前半スキン
box(4, 13, 6, 11, 16, 24, PUR)   # 後半紫（後頭部）
box(0, 3,  0, 11, 16, 24, PUR)   # 左サイドは髪
box(14, 17, 0, 11, 16, 24, PUR)  # 右サイドは髪

# 左目（白目3×4・中央に黒瞳2×2）
box(5, 7,  0, 1, 19, 22, WHT)
box(5, 6,  0, 0, 20, 21, EYE)
# 右目
box(10, 12, 0, 1, 19, 22, WHT)
box(11, 12, 0, 0, 20, 21, EYE)

# ─── 6. 黒猫帽子ブリム（大型・フル幅）───────────────────────────────
box(0, 17, 0, 11, 22, 31, HAT)

# 白い四角穴（前面 y=0 のみ）
box(2, 6,  0, 0, 24, 29, WHT)    # 左穴（幅5×高さ6）
box(11, 15, 0, 0, 24, 29, WHT)   # 右穴（幅5×高さ6）
# 穴の中央に黒四角（目の質感）
box(3, 5,  0, 0, 25, 28, EYE)
box(12, 14, 0, 0, 25, 28, EYE)

# ─── 7. ネコ耳（三角形・帽子上部）──────────────────────────────────
# 左耳
box(2, 6,  0, 8, 30, 31, HAT)   # 根元（幅5・奥行き9）
box(2, 5,  0, 7, 32, 32, HAT)
box(2, 4,  0, 5, 33, 33, HAT)
box(2, 3,  0, 4, 34, 34, HAT)
v(2, 0, 35, HAT); v(2, 1, 35, HAT); v(2, 2, 35, HAT)

# 右耳
box(11, 15, 0, 8, 30, 31, HAT)
box(12, 15, 0, 7, 32, 32, HAT)
box(13, 15, 0, 5, 33, 33, HAT)
box(14, 15, 0, 4, 34, 34, HAT)
v(15, 0, 35, HAT); v(15, 1, 35, HAT); v(15, 2, 35, HAT)

# ─── Write .vox ──────────────────────────────────────────────────────────
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

write_vox('assets/characters/vox/kuroneko3.vox', SX, SY, SZ, vox, PAL)

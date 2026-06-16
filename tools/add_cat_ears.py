#!/usr/bin/env python3
"""
add_cat_ears.py
usertest.vox を読んで猫耳を追加 → usertest_ears.vox に書き出す
"""
import struct
from collections import Counter

def read_vox(path):
    with open(path, 'rb') as f:
        data = f.read()
    assert data[:4] == b'VOX ', "Not a .vox file"

    pos = 8  # "VOX " + version(4)
    assert data[pos:pos+4] == b'MAIN'
    content_len  = struct.unpack('<I', data[pos+4:pos+8])[0]
    children_len = struct.unpack('<I', data[pos+8:pos+12])[0]
    pos += 12 + content_len

    sx, sy, sz = 0, 0, 0
    voxels  = {}
    palette = [(0,0,0,0)] * 256

    end = pos + children_len
    while pos < end:
        cid   = data[pos:pos+4]
        c_len = struct.unpack('<I', data[pos+4:pos+8])[0]
        ch_len = struct.unpack('<I', data[pos+8:pos+12])[0]
        cs = pos + 12
        if cid == b'SIZE':
            sx, sy, sz = struct.unpack('<III', data[cs:cs+12])
        elif cid == b'XYZI':
            n = struct.unpack('<I', data[cs:cs+4])[0]
            for i in range(n):
                x, y, z, c = struct.unpack('BBBB', data[cs+4+i*4:cs+8+i*4])
                voxels[(x, y, z)] = c
        elif cid == b'RGBA':
            for i in range(256):
                palette[i] = struct.unpack('BBBB', data[cs+i*4:cs+4+i*4])
        pos = cs + c_len + ch_len

    return sx, sy, sz, voxels, palette

def write_vox(path, sx, sy, sz, voxels, palette):
    def chunk(cid, body, children=b''):
        return cid + struct.pack('<II', len(body), len(children)) + body + children
    xyzi = struct.pack('<I', len(voxels))
    for (x, y, z), c in voxels.items():
        xyzi += struct.pack('BBBB', x, y, z, c)
    rgba = b''.join(struct.pack('BBBB', *palette[i]) for i in range(256))
    kids = chunk(b'SIZE', struct.pack('<III', sx, sy, sz)) + chunk(b'XYZI', xyzi) + chunk(b'RGBA', rgba)
    with open(path, 'wb') as f:
        f.write(b'VOX '); f.write(struct.pack('<I', 150))
        f.write(chunk(b'MAIN', b'', kids))
    print(f"OK  {len(voxels)} voxels -> {path}")

# ── 読み込み ─────────────────────────────────────────────────
sx, sy, sz, voxels, palette = read_vox('assets/characters/vox/usertest.vox')
print(f"Size: {sx}x{sy}x{sz},  Voxels: {len(voxels)}")

max_z = max(z for (x,y,z) in voxels)
print(f"Top Z: {max_z}")

# 上部5行で最多の色インデックス = 帽子の色
top5 = [voxels[p] for p in voxels if p[2] >= max_z - 4]
hat_c = Counter(top5).most_common(1)[0][0]
print(f"Hat color index: {hat_c}  RGBA={palette[hat_c-1]}")

# 帽子上面のX/Y範囲
top_pos = [(x,y,z) for (x,y,z) in voxels if z >= max_z - 1]
min_x = min(x for x,y,z in top_pos)
max_x = max(x for x,y,z in top_pos)
min_y = min(y for x,y,z in top_pos)
max_y = max(y for x,y,z in top_pos)
print(f"Hat top: x={min_x}..{max_x}, y={min_y}..{max_y}")

# ── 耳を追加 ─────────────────────────────────────────────────
EAR_H  = 4      # 耳の高さ（ボクセル数）
new_sz = sz + EAR_H + 2
new_vox = dict(voxels)

def v(x, y, z, c):
    if 0 <= x < sx and 0 <= y < sy and 0 <= z < new_sz:
        new_vox[(x, y, z)] = c

def cat_ear(cx_ear, base_z, c):
    """先端に向かって細くなる三角耳"""
    ey0, ey1 = min_y, max_y          # Y は帽子と同じ奥行き
    widths = [2, 2, 1, 1]            # 下→上の幅
    for i, half_w in enumerate(widths):
        for dx in range(-half_w + 1, half_w + 1):
            for y in range(ey0, ey1 + 1):
                v(cx_ear + dx, y, base_z + i, c)

# 左耳・右耳の中心X（帽子幅の1/4・3/4あたり）
hat_w   = max_x - min_x
ear_l_x = min_x + hat_w // 4
ear_r_x = max_x - hat_w // 4
base_z  = max_z + 1

cat_ear(ear_l_x, base_z, hat_c)
cat_ear(ear_r_x, base_z, hat_c)
print(f"Left ear x={ear_l_x}, Right ear x={ear_r_x}, base z={base_z}")

# ── 書き出し ─────────────────────────────────────────────────
write_vox('assets/characters/vox/usertest_ears.vox', sx, sy, new_sz, new_vox, palette)

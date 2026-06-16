#!/usr/bin/env python3
"""
gen_vox_char01.py
Output: assets/characters/vox/char_01.vox

Based on: anime illustration + pixel art
Character structure (top to bottom):
  [Cat hat: large wide brim + dome + pointy ears + 2 white square holes]
  [Face: skin/orange with purple eye dots, clearly visible below brim]
  [Black sleeveless dress body]
  [Black fingerless gloves + purple wrist bands]
  [Purple flared skirt]
  [Black legs + checker tail (left side)]
  [Long purple hair cascading from under hat brim]
"""
import struct, os, math

PAL = [(0, 0, 0, 0)] * 256
PAL[0] = (0x18, 0x18, 0x18, 0xff)  # 1 BLACK
PAL[1] = (0xf0, 0xf0, 0xf0, 0xff)  # 2 WHITE
PAL[2] = (0x77, 0x28, 0xc8, 0xff)  # 3 PURPLE
PAL[3] = (0xe0, 0x78, 0x30, 0xff)  # 4 SKIN (orange)
PAL[4] = (0x3a, 0x10, 0x60, 0xff)  # 5 DARK_PURPLE
PAL[5] = (0xb0, 0x60, 0xf0, 0xff)  # 6 LIGHT_PURPLE
PAL[6] = (0x44, 0x28, 0x78, 0xff)  # 7 EYE_PURPLE (deep purple eyes)
B, W, P, S, D, L, E = 1, 2, 3, 4, 5, 6, 7

SX, SY, SZ = 22, 12, 32
vox = {}
cx = 10  # x-center of SX=22

def v(x, y, z, c):
    if 0 <= x < SX and 0 <= y < SY and 0 <= z < SZ:
        vox[(x, y, z)] = c

def box(x0, x1, y0, y1, z0, z1, c):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            for z in range(z0, z1 + 1):
                v(x, y, z, c)

def oval_col(ocx, ocy, rx, ry, z0, z1, c):
    for z in range(z0, z1 + 1):
        for dx in range(-int(rx) - 1, int(rx) + 2):
            fx = dx / rx if rx > 0 else 99.
            for dy in range(-int(ry) - 1, int(ry) + 2):
                fy = dy / ry if ry > 0 else 99.
                if fx * fx + fy * fy <= 1.0:
                    v(ocx + dx, ocy + dy, z, c)

def sphere(scx, scy, scz, rx, ry, rz, c):
    for dz in range(-int(rz) - 1, int(rz) + 2):
        fz = dz / rz
        if fz * fz >= 1.0:
            continue
        sc = math.sqrt(1 - fz * fz)
        for dx in range(-int(rx * sc) - 1, int(rx * sc) + 2):
            fx = dx / (rx * sc) if sc > 0 else 99.
            for dy in range(-int(ry * sc) - 1, int(ry * sc) + 2):
                fy = dy / (ry * sc) if sc > 0 else 99.
                if fx * fx + fy * fy <= 1.0:
                    v(scx + dx, scy + dy, scz + dz, c)

# ═══════════════════════════════════════════════════════════════════
# HEIGHTS (Z axis, 0=floor, 31=top):
#   0- 1  legs
#   1- 5  tail (left)
#   2-10  skirt (purple, flared)
#  10-18  body + arms
#  18-21  face (skin, 4 voxels tall)
#  22-23  hat BRIM (very wide, 2 voxels tall)
#  24-31  hat DOME (sphere: center z=28)
#  27-31  cat ears (above dome)
#
# DRAW ORDER: later = overwrites earlier
#  1. Hair (background: sides + behind body)
#  2. Legs + tail
#  3. Skirt
#  4. Body + arms
#  5. Face  (overwrites hair at front center)
#  6. Hat brim (overwrites hair, very wide)
#  7. Hat dome sphere
#  8. White square hat markings
#  9. Cat ears
# 10. Eyes (last, on face)
# ═══════════════════════════════════════════════════════════════════

# ── 1. Purple hair (background layer) ──────────────────────────────
# Wide strips on left and right — hair cascades visibly on both sides
# z=6-24 covers from above skirt to just below hat brim
# Width: shoulder-level wide (cx±7) narrowing near hat level (cx±5 sides)
box(cx - 7, cx + 7, 0, SY - 1, 6, 15, P)     # wide shoulder-level hair
box(cx - 6, cx + 6, 0, SY - 1, 15, 21, P)    # narrower near face level
# Side strips that peek past the hat brim (beyond brim x=cx±8)
box(0, cx - 8,  0, SY - 1, 6, 24, P)         # far left side hair
box(cx + 8, SX - 1, 0, SY - 1, 6, 24, P)     # far right side hair
# Back hair behind hat dome area
box(cx - 5, cx + 5, 4, SY - 1, 22, 28, P)
# Front-edge hair highlights
for z in range(6, 25):
    v(0, 0, z, L)
    v(SX - 1, 0, z, L)

# ── 2. Legs ─────────────────────────────────────────────────────────
box(cx - 3, cx - 2, 1, 5, 0, 1, B)
box(cx + 2, cx + 3, 1, 5, 0, 1, B)

# ── 3. Tail (left side, checker) ────────────────────────────────────
box(0, 2, 0, 3, 1, 5, B)
v(0, 0, 4, D); v(1, 0, 4, P)
v(0, 0, 3, P); v(1, 0, 3, D)
v(0, 0, 2, D); v(1, 0, 2, P)

# ── 4. Skirt (purple oval, flared at bottom) ─────────────────────────
for z in range(2, 10):
    spread = 4.0 + (9 - z) * 0.45
    oval_col(cx, 4, spread, int(spread * 0.75), z, z, P)
box(cx - 5, cx + 5, 0, SY - 1, 6, 6, D)   # checker stripe
box(cx - 5, cx + 5, 0, SY - 1, 3, 3, D)   # checker stripe

# ── 5. Black body/dress ──────────────────────────────────────────────
# 3D oval column: center y=3, extends y=0-6 naturally
oval_col(cx, 3, 3.5, 3.5, 9, 18, B)
box(cx - 3, cx + 3, 0, 1, 9, 18, B)   # explicit front face

# ── 6. Arms (black gloves, connected to body) ────────────────────────
# Left arm: x=cx-7 to cx-3 (connects at cx-3 which is body front edge)
box(cx - 7, cx - 3, 1, 4, 10, 17, B)
# Right arm
box(cx + 3, cx + 7, 1, 4, 10, 17, B)
# Purple wrist bands (accent like fingerless gloves)
box(cx - 7, cx - 3, 0, 3, 12, 13, P)
box(cx + 3, cx + 7, 0, 3, 12, 13, P)

# ── 7. Skin face (4 voxels tall: z=18-21) ───────────────────────────
# Clearly visible below hat brim (z=22)
# Slight 3D depth with oval, reinforced by front-face box
oval_col(cx, 1, 3.0, 2.0, 18, 22, S)
box(cx - 3, cx + 3, 0, 1, 18, 22, S)

# ── 8. Hat BRIM (very wide flat disc, 2 voxels tall) ─────────────────
# Width cx±8 = x=2..18 (17 voxels) — much wider than the face (cx±3)
# This is the dominant visual element of the hat from front view
box(cx - 8, cx + 8, 0, SY - 1, 22, 23, B)

# ── 9. Hat DOME sphere ───────────────────────────────────────────────
# Center (cx, y=3, z=28): y=3 gives good 3D depth, z=28 sits above brim
# ry=6: large y-radius so dome covers y=0 from z=24 upward (no gap with brim)
sphere(cx, 3, 28, 5, 6, 5, B)

# ── 10. White square "eye holes" on hat (cat face design) ────────────
# Two large white squares — the signature feature of this hat
# Positioned in the lower-center of the dome face (z=25-27)
box(cx - 4, cx - 2, 0, 1, 25, 27, W)   # left white square  (3 wide × 3 tall)
box(cx + 2, cx + 4, 0, 1, 25, 27, W)   # right white square

# ── 11. Cat hat ears (large pointy triangles above dome) ─────────────
# Left ear: x=3..6 (cx-7..cx-4), widens from tip down
box(cx - 7, cx - 4, 0, 5, 27, 30, B)   # left ear base (4 wide)
box(cx - 7, cx - 5, 0, 4, 29, 30, B)   # taper (3 wide)
box(cx - 7, cx - 6, 0, 3, 31, 31, B)   # tip   (2 wide)
# Right ear: x=14..17 (cx+4..cx+7)
box(cx + 4, cx + 7, 0, 5, 27, 30, B)
box(cx + 5, cx + 7, 0, 4, 29, 30, B)
box(cx + 6, cx + 7, 0, 3, 31, 31, B)   # tip
box(cx + 7, cx + 8, 0, 3, 28, 29, B)   # right ear outer bump (asymmetric)

# ── 12. Character's eyes (deep purple dots on skin face) ─────────────
# NOT on hat — these are the character's actual eyes on the orange face
v(cx - 2, 0, 20, E); v(cx - 1, 0, 20, E)   # left eye
v(cx + 1, 0, 20, E); v(cx + 2, 0, 20, E)   # right eye

# ═══════════════════════════════════════════════════════════════════
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
    print(f"OK  {len(vox_data)} voxels -> {path}")
    print(f"  face    (cx,0,19)   = {vox_data.get((cx,0,19),'EMPTY')}  expect 4=SKIN")
    print(f"  eye     (cx-2,0,20) = {vox_data.get((cx-2,0,20),'EMPTY')}  expect 7=EYE_PURPLE")
    print(f"  brim    (cx-7,0,22) = {vox_data.get((cx-7,0,22),'EMPTY')}  expect 1=BLACK")
    print(f"  dome    (cx,0,28)   = {vox_data.get((cx,0,28),'EMPTY')}  expect 1=BLACK")
    print(f"  white_L (cx-3,0,26) = {vox_data.get((cx-3,0,26),'EMPTY')}  expect 2=WHITE")
    print(f"  white_R (cx+3,0,26) = {vox_data.get((cx+3,0,26),'EMPTY')}  expect 2=WHITE")
    print(f"  ear_L   (cx-6,0,31) = {vox_data.get((cx-6,0,31),'EMPTY')}  expect 1=BLACK")
    print(f"  hair    (1,0,12)    = {vox_data.get((1,0,12),'EMPTY')}   expect 3=PURPLE")
    print(f"  body    (cx,0,13)   = {vox_data.get((cx,0,13),'EMPTY')}  expect 1=BLACK")

write_vox('assets/characters/vox/char_01.vox', SX, SY, SZ, vox, PAL)

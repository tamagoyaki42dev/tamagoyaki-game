#!/usr/bin/env python3
"""
gen_vox.py -- black cat-hat character for MagicaVoxel

Correct character structure (top -> bottom):
  [Cat hat: black rounded hat with pointy ears + white square markings]
  [Face: skin/orange with two tiny black eye dots]
  [Black dress body]
  [Purple flared skirt with checker stripes]
  [Two black legs, tail on left side]
  [Purple hair visible at sides, behind hat]
"""
import struct, os, math

PAL = [(0,0,0,0)] * 256
PAL[0] = (0x18, 0x18, 0x18, 0xff)  # 1 = BLACK
PAL[1] = (0xf0, 0xf0, 0xf0, 0xff)  # 2 = WHITE
PAL[2] = (0x77, 0x28, 0xc8, 0xff)  # 3 = PURPLE
PAL[3] = (0xe0, 0x78, 0x30, 0xff)  # 4 = SKIN (orange)
PAL[4] = (0x3a, 0x10, 0x60, 0xff)  # 5 = DARK_PURPLE
PAL[5] = (0xb0, 0x60, 0xf0, 0xff)  # 6 = LIGHT_PURPLE
B, W, P, S, D, L = 1, 2, 3, 4, 5, 6

SX, SY, SZ = 20, 12, 28
vox = {}
cx = 9  # x-center

def v(x, y, z, c):
    if 0 <= x < SX and 0 <= y < SY and 0 <= z < SZ:
        vox[(x, y, z)] = c

def box(x0, x1, y0, y1, z0, z1, c):
    for x in range(x0, x1+1):
        for y in range(y0, y1+1):
            for z in range(z0, z1+1):
                v(x, y, z, c)

def oval_col(ocx, ocy, rx, ry, z0, z1, c):
    """Filled oval column (constant cross-section at every Z)."""
    for z in range(z0, z1+1):
        for dx in range(-int(rx)-1, int(rx)+2):
            fx = dx/rx if rx > 0 else 99.
            for dy in range(-int(ry)-1, int(ry)+2):
                fy = dy/ry if ry > 0 else 99.
                if fx*fx + fy*fy <= 1.0:
                    v(ocx+dx, ocy+dy, z, c)

def sphere(scx, scy, scz, rx, ry, rz, c):
    """Filled ellipsoid."""
    for dz in range(-int(rz)-1, int(rz)+2):
        fz = dz/rz
        if fz*fz >= 1.0: continue
        sc = math.sqrt(1-fz*fz)
        for dx in range(-int(rx*sc)-1, int(rx*sc)+2):
            fx = dx/(rx*sc) if sc > 0 else 99.
            for dy in range(-int(ry*sc)-1, int(ry*sc)+2):
                fy = dy/(ry*sc) if sc > 0 else 99.
                if fx*fx + fy*fy <= 1.0:
                    v(scx+dx, scy+dy, scz+dz, c)

# ============================================================
# DRAW ORDER:  later calls overwrite earlier ones.
#
# 1. Purple hair (side strips + back) -- background layer
# 2. Legs + tail + skirt
# 3. Black body + arms
# 4. Skin face (overwrites hair at front/center)
# 5. Hat brim + hat sphere (overwrites hair, sits on TOP)
# 6. White hat markings
# 7. Cat hat ears (topmost)
# 8. Eye dots (drawn last, on face)
# ============================================================

# ── 1. Purple hair ──────────────────────────────────────────
# Hair flows down the sides (x = 0-3 left, x = 15-19 right)
# and behind the character (y = 4-11 at center x).
# The front-center (where face/body/hat are) is NOT filled.

box(0, cx-6, 0, SY-1, 4, 24, P)          # left side hair
box(cx+6, SX-1, 0, SY-1, 4, 24, P)       # right side hair
box(cx-5, cx+5, 4, SY-1, 4, 20, P)       # back hair (behind body)
# Front-edge highlight of side hair
for z in range(4, 25):
    v(0, 0, z, L)
    v(SX-1, 0, z, L)

# ── 2. Legs ─────────────────────────────────────────────────
box(cx-3, cx-2, 1, 5, 0, 1, B)
box(cx+2, cx+3, 1, 5, 0, 1, B)

# ── 3. Tail (left side, small checker) ──────────────────────
box(1, 3, 0, 3, 1, 4, B)
v(1, 0, 3, D); v(2, 0, 3, P)
v(1, 0, 2, P); v(2, 0, 2, D)

# ── 4. Skirt (purple flared oval + checker) ─────────────────
for z in range(2, 9):
    spread = 4.5 + (8-z)*0.4
    oval_col(cx, 4, spread, int(spread*0.75), z, z, P)
# Checker stripes (dark purple)
box(cx-5, cx+5, 0, SY-1, 5, 5, D)
box(cx-5, cx+5, 0, SY-1, 3, 3, D)

# ── 5. Black body/dress ──────────────────────────────────────
# 3D oval column: center y=3, ry=3.5 => extends y=0 to y=6
oval_col(cx, 3, 3.5, 3.5, 8, 14, B)
# Explicit front face (oval at cy=3 has partial coverage at y=0)
box(cx-3, cx+3, 0, 1, 8, 14, B)

# ── 6. Arms ─────────────────────────────────────────────────
box(cx-7, cx-4, 1, 4, 9, 13, B)
box(cx+4, cx+7, 1, 4, 9, 13, B)

# ── 7. Skin face ─────────────────────────────────────────────
# Face = narrow orange band between body top (z=14) and hat brim (z=17)
# z=14-16, centered at front
box(cx-3, cx+3, 0, 2, 14, 16, S)
box(cx-4, cx+4, 0, 1, 15, 15, S)  # slightly wider at mid-face

# ── 8. Hat brim (wide black band at hat base) ─────────────────
box(cx-6, cx+6, 0, SY-1, 17, 18, B)

# ── 9. Cat hat sphere (BLACK rounded body of the hat) ─────────
# Center: (cx, y=3, z=21) -- y=3 gives the hat depth into scene
# ry=5 => hat extends y=0(front) to y=8(back): visible in isometric
sphere(cx, 3, 21, 5, 5, 4, B)

# ── 10. White square markings on the hat ──────────────────────
# These are the CAT FACE decorations ON THE HAT (not character's eyes)
box(cx-3, cx-2, 0, 1, 20, 21, W)
box(cx+2, cx+3, 0, 1, 20, 21, W)

# ── 11. Cat hat ears (above hat sphere top z~25) ──────────────
# Left ear (simple pointed shape)
box(cx-6, cx-4, 0, 4, 23, 26, B)
box(cx-5, cx-4, 0, 3, 25, 26, B)   # taper left ear tip
# Right ear (asymmetric: extra bump on the outer side)
box(cx+4, cx+6, 0, 4, 23, 26, B)
box(cx+6, cx+7, 0, 3, 24, 25, B)   # right ear outer bump

# ── 12. Character eyes (tiny BLACK dots on the skin face) ─────
# These are the actual eyes of the CHARACTER (on skin area, not hat)
v(cx-2, 0, 15, B); v(cx-1, 0, 15, B)   # left eye
v(cx+1, 0, 15, B); v(cx+2, 0, 15, B)   # right eye

# ============================================================
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
    # Sanity checks
    print(f"  face (cx,0,15) = {vox_data.get((cx,0,15),'EMPTY')}  expect 4=SKIN")
    print(f"  eye  (cx-2,0,15) = {vox_data.get((cx-2,0,15),'EMPTY')}  expect 1=BLACK")
    print(f"  hat  (cx,0,21) = {vox_data.get((cx,0,21),'EMPTY')}  expect 1=BLACK")
    print(f"  body (cx,0,11) = {vox_data.get((cx,0,11),'EMPTY')}  expect 1=BLACK")
    print(f"  hair (2,0,12) = {vox_data.get((2,0,12),'EMPTY')}   expect 3=PURPLE")

write_vox('assets/characters/vox/test_char.vox', SX, SY, SZ, vox, PAL)

#!/usr/bin/env python3
"""Build assets/{dagger,spear,battle_axe,crossbow,bow}.glb (own work, CC0), in the style of gen_projectiles.py.

Every model is +Y along the weapon with the origin at the grip, built from lofts and sweeps with no padding: a ring count is
what the curve needs. Textures are ambientCG CC0 materials (Wood049, Wood077, Metal009, Metal038) cut to 1024 px, with a
procedural leather, horn and bone (own work). The bow keeps the rig of the glb it replaces (tools/bow_rig.json: nodes, joints,
inverse bind matrices) because the art table's limb joints and string tips are measured against it.

  python3 tools/gen_weapons.py <ambientcg_dir> <assets_dir> [dagger spear battle_axe crossbow bow]
"""
import json, math, os, struct, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_projectiles import Mesh, jpg

TEX = 1024
X, Y, Z = np.array([1, 0, 0.]), np.array([0, 1, 0.]), np.array([0, 0, 1.])


# ---------------------------------------------------------------- geometry
def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def super_ring(a, b, n, p=2.0, rot=0.0):
    """n points of a superellipse with half extents a, b (p = 2 ellipse, larger = boxier)."""
    t = np.arange(n) * 2 * math.pi / n + rot
    c, s = np.cos(t), np.sin(t)
    return np.stack([a * np.sign(c) * np.abs(c) ** (2 / p), b * np.sign(s) * np.abs(s) ** (2 / p)], 1)


def loft(mesh, rings, uv_scale=1 / 0.35, hard=False, caps=(True, True), swap_uv=False):
    """Skin rings (k, n, 3) together. Smooth shading shares vertices around a ring; hard gives every quad its own, for blade bevels.
    uv is metres along the length and around the ring times uv_scale, so texel density is the same on every part."""
    R = [np.asarray(r, np.float32) for r in rings]
    k, n = len(R), len(R[0])
    cen = [r.mean(0) for r in R]
    along = np.concatenate([[0], np.cumsum([np.linalg.norm(cen[i + 1] - cen[i]) for i in range(k - 1)])])
    perim = np.cumsum(np.concatenate([[0], np.linalg.norm(np.roll(R[0], -1, 0) - R[0], axis=1)]))
    per_ring = [np.concatenate([[0], np.cumsum(np.linalg.norm(np.roll(r, -1, 0) - r, axis=1))]) for r in R]
    pos, uv, tris = [], [], []

    def U(i, j):
        u, v = along[i] * uv_scale, per_ring[i][j] * uv_scale
        return (v, u) if swap_uv else (u, v)

    if hard:
        for i in range(k - 1):
            for j in range(n):
                j2 = (j + 1) % n
                b = len(pos)
                pos += [R[i][j], R[i][j2], R[i + 1][j], R[i + 1][j2]]
                uv += [U(i, j), U(i, j + 1), U(i + 1, j), U(i + 1, j + 1)]
                tris += [(b, b + 1, b + 2), (b + 1, b + 3, b + 2)]
    else:
        for i in range(k):
            for j in range(n + 1):
                pos.append(R[i][j % n]); uv.append(U(i, j))
        for i in range(k - 1):
            for j in range(n):
                a = i * (n + 1) + j; b = a + 1; c = a + n + 1; d = c + 1
                tris += [(a, b, c), (b, d, c)]
    pos = np.array(pos, np.float32)
    # outward = away from the ring centre; flip the winding when the first quad faces inward
    t0 = tris[len(tris) // 2]
    f = np.cross(pos[t0[1]] - pos[t0[0]], pos[t0[2]] - pos[t0[0]])
    mid = len(R) // 2
    if np.dot(f, pos[t0[0]] - cen[min(mid, k - 1)]) < 0:
        tris = [(a, c, b) for a, b, c in tris]
    mesh.add(pos, uv, tris)
    for end, cap in enumerate(caps):
        if not cap:
            continue
        r = R[0] if end == 0 else R[-1]
        c = r.mean(0)
        cp = np.vstack([c[None], r]); cu = np.vstack([[0.5, 0.5], 0.5 + (r[:, [0, 1]] - c[[0, 1]]) * uv_scale * 0.5])
        ct = [(0, 1 + j, 1 + (j + 1) % n) for j in range(n)]
        nrm = np.cross(r[1] - r[0], r[2] - r[0]).astype(np.float64)
        out = (c - cen[1 if end == 0 else -2]) if k > 1 else nrm
        if np.dot(nrm, out) < 0:
            ct = [(a, c2, b) for a, b, c2 in ct]
        m = Mesh(); m.add(cp, cu, ct)
        mesh.p += m.p; mesh.n += m.n; mesh.uv += m.uv
        mesh.i.append(m.i[0] + (sum(len(x) for x in mesh.p) - len(cp)))


def revolve(mesh, prof, sides=14, uv_scale=1 / 0.35, caps=(True, True), axis='y', c=(0, 0, 0)):
    """prof = [(distance along the axis, radius)]; axis y, or x for the crossbow nut."""
    rings = []
    for d, r in prof:
        r = max(r, 1e-4)
        ring = np.stack([np.cos(np.arange(sides) * 2 * math.pi / sides) * r, np.sin(np.arange(sides) * 2 * math.pi / sides) * r], 1)
        if axis == 'y':
            rings.append(np.stack([ring[:, 0], np.full(sides, d), ring[:, 1]], 1) + np.array(c))
        else:
            rings.append(np.stack([np.full(sides, d), ring[:, 0], ring[:, 1]], 1) + np.array(c))
    loft(mesh, rings, uv_scale, caps=caps)


def sweep(mesh, path, a, b, n=12, p=2.0, uv_scale=1 / 0.35, caps=(True, True), hard=False):
    """A section of half extents a (in the path plane, across the path) and b (along Z) swept along a path in the XY plane."""
    path = np.asarray(path, np.float64)
    T = np.gradient(path, axis=0)
    T /= np.linalg.norm(T, axis=1, keepdims=True)
    B = np.stack([-T[:, 1], T[:, 0], np.zeros(len(T))], 1)
    rings = []
    for i, c in enumerate(path):
        sec = super_ring(a[i] if hasattr(a, '__len__') else a, b[i] if hasattr(b, '__len__') else b, n, p)
        rings.append(c + sec[:, 0:1] * B[i] + sec[:, 1:2] * Z)
    loft(mesh, rings, uv_scale, caps=caps, hard=hard)


def box(mesh, c, h, uv_scale=1 / 0.2):
    c, h = np.array(c, float), np.array(h, float)
    sx = np.array([[1, 1], [-1, 1], [-1, -1], [1, -1]])
    rings = [c + np.array([sx[j][0] * h[0], y * h[1], sx[j][1] * h[2]]) for y in (-1, 1) for j in range(1)]
    r0 = np.array([c + np.array([s[0] * h[0], -h[1], s[1] * h[2]]) for s in sx])
    r1 = np.array([c + np.array([s[0] * h[0], h[1], s[1] * h[2]]) for s in sx])
    loft(mesh, [r0, r1], uv_scale, hard=True)


def catmull(pts, per=8):
    P = np.asarray(pts, float)
    P = np.vstack([2 * P[0] - P[1], P, 2 * P[-1] - P[-2]])
    out = []
    for i in range(1, len(P) - 2):
        for t in np.linspace(0, 1, per, endpoint=False):
            out.append(0.5 * ((2 * P[i]) + (-P[i - 1] + P[i + 1]) * t + (2 * P[i - 1] - 5 * P[i] + 4 * P[i + 1] - P[i + 2]) * t * t
                              + (-P[i - 1] + 3 * P[i] - 3 * P[i + 1] + P[i + 2]) * t ** 3))
    out.append(P[-2])
    return np.array(out)


def blade_section(w, t, fuller=0.55):
    """A flat blade's 10-point lens with a central ridge/fuller: points (x across, z thickness)."""
    return np.array([(w, 0), (0.5 * w, t), (0.13 * w, t * fuller), (-0.13 * w, t * fuller), (-0.5 * w, t),
                     (-w, 0), (-0.5 * w, -t), (-0.13 * w, -t * fuller), (0.13 * w, -t * fuller), (0.5 * w, -t)])


def blade_rings(y0, y1, wfn, tfn, steps, fuller=0.55):
    out = []
    for s in np.linspace(0, 1, steps):
        sec = blade_section(max(wfn(s), 2e-4), max(tfn(s), 1e-4), fuller)
        out.append(np.stack([sec[:, 0], np.full(10, y0 + (y1 - y0) * s), sec[:, 1]], 1))
    return out


# ---------------------------------------------------------------- the weapons
def dagger():
    steel, iron, leather = Mesh(), Mesh(), Mesh()
    revolve(iron, [(-0.082, 0.002), (-0.078, 0.009), (-0.070, 0.0155), (-0.062, 0.0165), (-0.054, 0.013), (-0.050, 0.0105)], 14, 1 / 0.2, caps=(True, False))
    ys = np.linspace(-0.052, 0.036, 16)
    revolve(leather, [(y, 0.0098 + 0.0016 * math.sin((y + 0.052) / 0.088 * math.pi) + 0.0007 * math.sin(y * 480)) for y in ys], 12, 1 / 0.08, caps=(False, False))
    for y in (-0.048, 0.034):
        revolve(iron, [(y - 0.003, 0.0105), (y, 0.0122), (y + 0.003, 0.0105)], 12, 1 / 0.1, caps=(False, False))
    xs = np.linspace(-0.052, 0.052, 17)
    rings = []
    for x in xs:
        u = abs(x) / 0.052
        sec = super_ring(0.0075 * (1 - 0.55 * u * u) + 0.0012, 0.0088 * (1 - 0.6 * u ** 3) + 0.001, 10, 2.3)
        cy = 0.0455 + 0.011 * u * u
        rings.append(np.stack([np.full(10, x), cy + sec[:, 0], sec[:, 1]], 1))
    loft(iron, rings, 1 / 0.2)
    y0, y1 = 0.052, 0.304
    loft(steel, blade_rings(y0, y1, lambda s: 0.0168 * (1 - s ** 2.4) ** 0.9 * (0.6 + 0.4 * smooth(0, 0.08, s)),
                            lambda s: 0.0042 * (1 - 0.65 * s), 16), 1 / 0.4, hard=True, caps=(True, True))
    return {'Steel': steel, 'Iron': iron, 'Leather': leather}


def spear():
    wood, iron, steel, leather = Mesh(), Mesh(), Mesh(), Mesh()
    ys = np.linspace(-0.70, 0.82, 22)
    revolve(wood, [(y, 0.0132 - 0.0016 * (y + 0.7) / 1.52 + 0.0004 * math.sin(y * 17)) for y in ys], 14, 1 / 0.45, caps=(False, False))
    revolve(iron, [(-0.80, 0.0012), (-0.785, 0.007), (-0.755, 0.0125), (-0.72, 0.0155), (-0.69, 0.0160), (-0.66, 0.0150), (-0.64, 0.0132)], 14, 1 / 0.2, caps=(True, False))
    for y in (-0.655, -0.700):
        revolve(iron, [(y - 0.004, 0.0152), (y, 0.0172), (y + 0.004, 0.0152)], 14, 1 / 0.2, caps=(False, False))
    revolve(steel, [(0.60, 0.0140), (0.62, 0.0166), (0.66, 0.0170), (0.72, 0.0160), (0.80, 0.0152), (0.84, 0.0195), (0.865, 0.0200), (0.885, 0.0120), (0.905, 0.0085)], 14, 1 / 0.2, caps=(False, False))
    for sg in (-1, 1):
        box(steel, (sg * 0.0165, 0.545, 0), (0.0022, 0.075, 0.0065), 1 / 0.15)
        box(steel, (0, 0.545, sg * 0.0165), (0.0065, 0.075, 0.0022), 1 / 0.15)
    leather_ys = np.linspace(0.42, 0.60, 19)
    revolve(leather, [(y, 0.0146 + 0.0013 * abs(math.sin((y - 0.42) * 160))) for y in leather_ys], 14, 1 / 0.06, caps=(True, True))
    y0, y1 = 0.90, 1.265
    loft(steel, blade_rings(y0, y1, lambda s: 0.044 * math.sin(math.pi * s ** 0.62) ** 0.85 + 0.0085 * (1 - s),
                            lambda s: 0.0058 * (1 - 0.45 * s), 24, 1.0), 1 / 0.4, hard=True)
    return {'Steel': steel, 'Wood': wood, 'Iron': iron, 'Leather': leather}


def battle_axe():
    wood, iron, steel, leather = Mesh(), Mesh(), Mesh(), Mesh()
    ys = np.linspace(-0.26, 0.66, 26)
    rings = []
    for y in ys:
        r = 0.0158 * (1 + 0.13 * math.exp(-((y + 0.19) / 0.05) ** 2) - 0.05 * smooth(0, 0.6, y))
        sec = super_ring(r, r * 1.3, 14, 2.4)
        rings.append(np.stack([sec[:, 0], np.full(14, y), sec[:, 1]], 1))
    loft(wood, rings, 1 / 0.4, caps=(False, False))
    leather_ys = np.linspace(-0.12, 0.12, 25)
    rings = []
    for y in leather_ys:
        sec = super_ring(0.0172 + 0.0012 * abs(math.sin(y * 150)), 0.0225 + 0.0012 * abs(math.sin(y * 150)), 14, 2.4)
        rings.append(np.stack([sec[:, 0], np.full(14, y), sec[:, 1]], 1))
    loft(leather, rings, 1 / 0.06)
    revolve(iron, [(-0.295, 0.004), (-0.285, 0.0150), (-0.268, 0.0210), (-0.232, 0.0225), (-0.215, 0.0190)], 14, 1 / 0.2, caps=(True, False))
    for sg in (-1, 1):
        box(iron, (0, 0.46, sg * 0.0222), (0.0075, 0.13, 0.0036), 1 / 0.15)
    s_, y0, y1 = np.linspace(0, 1, 22), 0.45, 0.78
    rings = []
    for s in s_:
        zf = 0.050 + 0.105 * math.sin(math.pi * s) ** 0.8 * (1.1 - 0.35 * s) + 0.015 * (1 - s) ** 2
        zb = 0.026 + 0.005 * math.sin(math.pi * s)
        pts = [(0, -zf), (0.0022, -zf * 0.86), (0.0048, -zf * 0.5), (0.0165, -0.020), (0.0165, zb), (-0.0165, zb), (-0.0165, -0.020), (-0.0048, -zf * 0.5), (-0.0022, -zf * 0.86)]
        rings.append(np.array([(x, y0 + (y1 - y0) * s, z) for x, z in pts]))
    loft(steel, rings, 1 / 0.4, hard=True)
    rings = []
    for u in np.linspace(0, 1, 8):
        z = 0.024 + 0.09 * u
        sec = super_ring(0.0175 * (1 - u) + 0.0015, 0.027 * (1 - u ** 1.5) + 0.0015, 8, 2.6)
        rings.append(np.stack([sec[:, 0], 0.595 + 0.012 * u * u + sec[:, 1], np.full(8, z)], 1))
    loft(steel, rings, 1 / 0.2, hard=True)
    revolve(steel, [(0.775, 0.0155), (0.80, 0.0140), (0.84, 0.0085), (0.885, 0.0014)], 8, 1 / 0.2, caps=(False, True))
    return {'Steel': steel, 'Wood': wood, 'Iron': iron, 'Leather': leather}


def crossbow():
    wood, steel, iron, leather, bone = Mesh(), Mesh(), Mesh(), Mesh(), Mesh()
    ky = [-0.19, -0.12, -0.03, 0.03, 0.10, 0.20, 0.32, 0.40]
    hw = [0.024, 0.027, 0.020, 0.018, 0.020, 0.022, 0.018, 0.012]
    zt = [0.05, 0.04, 0.025, 0.017, 0.017, 0.017, 0.017, 0.017]
    zb = [-0.07, -0.075, -0.085, -0.06, -0.045, -0.04, -0.035, -0.03]
    rings = []
    for y in np.linspace(-0.19, 0.40, 26):
        h, t, b = np.interp(y, ky, hw), np.interp(y, ky, zt), np.interp(y, ky, zb)
        sec = super_ring(h, (t - b) / 2, 14, 3.0)
        rings.append(np.stack([sec[:, 0], np.full(14, y), (t + b) / 2 + sec[:, 1]], 1))
    loft(wood, rings, 1 / 0.4)
    xs = np.linspace(-0.437, 0.437, 25)
    u = np.abs(xs) / 0.437
    path = np.stack([xs, 0.285 - 0.035 * (np.abs(xs) / 0.43) ** 2, np.full(len(xs), -0.032)], 1)
    sweep(steel, path, 0.0075 * (1 - 0.5 * u ** 2) + 0.0015, 0.017 * (1 - 0.55 * u ** 1.5) + 0.002, 10, 2.8, 1 / 0.4, caps=(False, False))
    for sg in (-1, 1):
        rings = []
        for d, rr in ((0.392, 0.0090), (0.404, 0.0108), (0.426, 0.0108), (0.440, 0.0075), (0.447, 0.0020)):
            sec = super_ring(rr, rr, 10)
            rings.append(np.stack([np.full(10, sg * d), 0.2508 + sec[:, 0], -0.032 + sec[:, 1]], 1))
        loft(iron, rings, 1 / 0.1, caps=(False, True))
        # lashing of the prod to the stock
        rings = []
        for x in np.linspace(0.028, 0.062, 12):
            xx = sg * x
            uu = abs(xx) / 0.437
            cy = 0.285 - 0.035 * (abs(xx) / 0.43) ** 2
            sec = super_ring(0.0075 * (1 - 0.5 * uu ** 2) + 0.0015 + 0.0030 + 0.0010 * abs(math.sin(x * 360)), 0.017 * (1 - 0.55 * uu ** 1.5) + 0.0045, 10, 2.8)
            rings.append(np.stack([np.full(10, xx), cy + sec[:, 0], -0.032 + sec[:, 1]], 1))
        loft(leather, rings, 1 / 0.06)
    ph = np.linspace(0, math.pi, 21)
    path = np.stack([0.028 * np.cos(ph), 0.30 + 0.204 * np.sin(ph) ** 0.8, np.full(21, -0.03)], 1)
    sweep(iron, path, 0.0045, 0.0045, 8, 2.0, 1 / 0.15, caps=(True, True))
    revolve(bone, [(-0.0085, 0.0105), (-0.0075, 0.0112), (0.0075, 0.0112), (0.0085, 0.0105)], 14, 1 / 0.06, axis='x', c=(0, 0.12, 0.0105), caps=(True, True))
    for sg in (-1, 1):
        box(iron, (sg * 0.0145, 0.12, -0.005), (0.0028, 0.016, 0.019), 1 / 0.1)
    rings = []
    for y in np.linspace(-0.03, 0.115, 10):
        zc = -0.045 - 0.050 * ((0.115 - y) / 0.145) ** 2
        sec = super_ring(0.0036, 0.0030, 6, 2.5)
        rings.append(np.stack([sec[:, 0], y + sec[:, 1] * 0, zc + sec[:, 1]], 1))
    loft(iron, rings, 1 / 0.1)
    box(iron, (0, -0.1925, -0.01), (0.0265, 0.0045, 0.062), 1 / 0.2)
    return {'Wood': wood, 'Steel': steel, 'Iron': iron, 'Leather': leather, 'Bone': bone}


# the bow's centreline at full draw (x toward the archer), through the rig's joints (0.039,0.09) (0.1174,0.29) (0.2154,0.49)
BOW_PATH = [(0.0204, 0), (0.039, 0.09), (0.0775, 0.19), (0.1174, 0.29), (0.165, 0.39), (0.2154, 0.49), (0.36, 0.60), (0.503, 0.655), (0.562, 0.695)]
JOINT_Y = [0.09, 0.29, 0.49]
BOW_Z = -0.02


def bow():
    """Returns {name: (Mesh, joints (n,4), weights (n,4))} per material; rig joint order is grip, top 0..2, bottom 0..2."""
    pts = catmull(BOW_PATH, 6)
    k = np.exp(-0.5 * (np.arange(-6, 7) / 2.5) ** 2); k /= k.sum()        # the rig's joints are not on a fair curve: fair it, ends fixed
    pad = np.vstack([2 * pts[0] - pts[6:0:-1], pts, 2 * pts[-1] - pts[-2:-8:-1]])
    pts = np.stack([np.convolve(pad[:, i], k, 'valid') for i in range(2)], 1)
    y = pts[:, 1]
    # limb section: D-shaped, wide in Z, deep in X, thinning to the tips
    u = np.clip(y / 0.7, 0, 1)
    wood = Mesh()
    rings, wt = [], []
    for sg in (1, -1):
        path = np.stack([pts[:, 0], pts[:, 1] * sg, np.full(len(pts), BOW_Z)], 1)
        sel = (np.abs(pts[:, 1]) >= 0.0) & (u < 0.9)
        pa = path[sel][::1]
        uu = u[sel]
        a = 0.0165 * (1 - 0.55 * uu ** 1.5) + 0.0030
        b = 0.0245 * (1 - 0.60 * uu ** 1.2) + 0.0050
        sweep(wood, pa if sg == 1 else pa[::-1], a if sg == 1 else a[::-1], b if sg == 1 else b[::-1], 12, 2.6, 1 / 0.35, caps=(False, sg == 1 or True))
    horn = Mesh()
    sel = u >= 0.88
    for sg in (1, -1):
        path = np.stack([pts[sel][:, 0], pts[sel][:, 1] * sg, np.full(sel.sum(), BOW_Z)], 1)
        uu = u[sel]
        sweep(horn, path if sg == 1 else path[::-1], (0.0072 * (1 - 0.45 * (uu - 0.88) / 0.12) + 0.0012) * (1 if sg == 1 else 1), (0.0125 * (1 - 0.5 * (uu - 0.88) / 0.12) + 0.0012) * 1,
              10, 2.2, 1 / 0.1, caps=(True, True)) if False else None
    # horn nocks: a tapered cap over the last stretch of each limb, with a ridge where the string sits
    for sg in (1, -1):
        seg = pts[u >= 0.885]
        pa = np.stack([seg[:, 0], seg[:, 1] * sg, np.full(len(seg), BOW_Z)], 1)
        t = np.linspace(0, 1, len(seg))
        a = 0.0066 * (1 - 0.5 * t) + 0.0016 + 0.0016 * np.exp(-((t - 0.78) / 0.07) ** 2)
        b = 0.0105 * (1 - 0.55 * t) + 0.0016
        sweep(horn, pa if sg == 1 else pa[::-1], a if sg == 1 else a[::-1], b if sg == 1 else b[::-1], 10, 2.2, 1 / 0.1, caps=(sg == 1, sg == 1)) if False else \
            sweep(horn, pa, a, b, 10, 2.2, 1 / 0.1, caps=(True, True))
    # grip: a leather wrap with a shelf cut for the arrow
    leather = Mesh()
    ys = np.linspace(-0.092, 0.092, 19)
    rings = []
    for yy in ys:
        r = 0.0215 + 0.0012 * abs(math.sin(yy * 135)) + 0.0022 * math.sin((yy + 0.092) / 0.184 * math.pi)
        sec = super_ring(r, 0.0235 + 0.0010 * abs(math.sin(yy * 135)) + 0.002 * math.sin((yy + 0.092) / 0.184 * math.pi), 14, 2.4)
        cx = 0.0204 + 0.0002
        rings.append(np.stack([cx + sec[:, 0], np.full(14, yy), BOW_Z + sec[:, 1]], 1))
    loft(leather, rings, 1 / 0.06)
    return {'Wood': wood, 'Leather': leather, 'Horn': horn}


def bow_skin(m, kind):
    """Joints (n,4 uint8) and weights (n,4 float) for a bow mesh: grip 0, top limb joints 1..3, bottom 4..6."""
    pos = np.concatenate(m.p)
    J = np.zeros((len(pos), 4), np.uint8)
    W = np.zeros((len(pos), 4), np.float32)
    for i, p in enumerate(pos):
        ay = abs(p[1])
        base = 1 if p[1] >= 0 else 4
        if kind == 'Leather':
            J[i, 0], W[i, 0] = 0, 1.0
            continue
        if kind == 'Horn':
            J[i, 0], W[i, 0] = base + 2, 1.0
            continue
        s = [smooth(j - 0.045, j + 0.045, ay) for j in JOINT_Y]      # how far past each joint
        w = [1 - s[0], s[0] - s[1], s[1] - s[2], s[2]]               # grip, bone0, bone1, bone2
        J[i] = [0, base, base + 1, base + 2]
        W[i] = w
    return J, W


# ---------------------------------------------------------------- textures
_cache = {}


def ambient(root, name):
    if name in _cache:
        return _cache[name]
    d = '%s/%s/%s_2K-JPG_' % (root, name, name)
    rs = lambda f, mode: Image.open(d + f + '.jpg').convert(mode).resize((TEX, TEX), Image.LANCZOS)
    alb, nrm, rough = rs('Color', 'RGB'), rs('NormalGL', 'RGB'), rs('Roughness', 'L')
    metal = rs('Metalness', 'L') if os.path.exists(d + 'Metalness.jpg') else Image.new('L', (TEX, TEX), 0)
    ao = Image.new('L', (TEX, TEX), 255)
    _cache[name] = (alb, nrm, Image.merge('RGB', (ao, rough, metal)))
    return _cache[name]


def fbm(seed, octaves=5, size=TEX):
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size), np.float32)
    amp, tot = 1.0, 0
    for o in range(octaves):
        n = 4 << o
        out += amp * np.array(Image.fromarray(rng.integers(0, 255, (n, n), dtype=np.uint8)).resize((size, size), Image.BICUBIC), np.float32) / 255
        tot += amp; amp *= 0.55
    return out / tot


def normal_from_height(h, strength):
    gx = np.roll(h, -1, 1) - np.roll(h, 1, 1)
    gy = np.roll(h, -1, 0) - np.roll(h, 1, 0)
    n = np.stack([-gx * strength, -gy * strength, np.ones_like(h)], 2)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8))


def procedural(kind, seed):
    h = fbm(seed)
    if kind == 'leather':
        rng = np.random.default_rng(seed)
        cells = np.array(Image.fromarray(rng.integers(0, 255, (96, 96), dtype=np.uint8)).resize((TEX, TEX), Image.NEAREST).filter(__import__('PIL.ImageFilter', fromlist=['x']).GaussianBlur(3)), np.float32) / 255
        hh = 0.55 * cells + 0.45 * h
        col = np.array([0.30, 0.17, 0.09]) * (0.55 + 0.9 * hh[..., None])
        rough = 0.62 + 0.25 * hh
        nrm = normal_from_height(hh, 6.0)
    elif kind == 'horn':
        streak = np.array(Image.fromarray((fbm(seed + 1, 4, 64)[:, :32] * 255).astype(np.uint8)).resize((TEX, TEX), Image.BICUBIC), np.float32) / 255
        hh = 0.7 * streak + 0.3 * h
        col = np.array([0.22, 0.14, 0.07])[None, None] * (0.5 + 1.3 * hh[..., None]) + 0.05
        rough = 0.35 + 0.2 * hh
        nrm = normal_from_height(hh, 2.5)
    else:  # bone
        hh = 0.5 * h + 0.5 * fbm(seed + 2, 6)
        col = np.array([0.86, 0.80, 0.66]) * (0.8 + 0.3 * hh[..., None])
        rough = 0.45 + 0.2 * hh
        nrm = normal_from_height(hh, 2.0)
    alb = Image.fromarray((col.clip(0, 1) * 255).astype(np.uint8))
    r8 = (rough.clip(0, 1) * 255).astype(np.uint8)
    return alb, nrm, Image.merge('RGB', (Image.new('L', (TEX, TEX), 255), Image.fromarray(r8), Image.new('L', (TEX, TEX), 0)))


def material_sets(root):
    return {
        'Steel': ambient(root, 'Metal009'), 'Iron': ambient(root, 'Metal038'), 'Wood': ambient(root, 'Wood049'),
        'DarkWood': ambient(root, 'Wood077'), 'Leather': procedural('leather', 11), 'Horn': procedural('horn', 21), 'Bone': procedural('bone', 31),
    }


# ---------------------------------------------------------------- glb
def write_glb(path, name, parts, sets, rig=None, skins=None):
    """parts = [(material name, texture set name, Mesh)]; sets[...] = (albedo, normal, orm) images, written once each."""
    bin_ = bytearray(); views = []; acc = []; prims = []; materials = []; images = []; textures = []; imgidx = {}

    def view(data, target=None):
        while len(bin_) % 4: bin_.append(0)
        views.append({'buffer': 0, 'byteOffset': len(bin_), 'byteLength': len(data), **({'target': target} if target else {})})
        bin_.extend(data); return len(views) - 1

    def tex(setname, k):
        key = (setname, k)
        if key not in imgidx:
            images.append({'bufferView': view(jpg(sets[setname][k], 90)), 'mimeType': 'image/jpeg'})
            textures.append({'source': len(images) - 1, 'sampler': 0})
            imgidx[key] = len(textures) - 1
        return imgidx[key]

    for mname, sname, m in parts:
        pos = np.concatenate(m.p); nrm = np.concatenate(m.n); uv = np.concatenate(m.uv); idx = np.concatenate(m.i).ravel()
        a0 = len(acc)
        acc.append({'bufferView': view(pos.astype('<f4').tobytes(), 34962), 'componentType': 5126, 'count': len(pos), 'type': 'VEC3', 'min': pos.min(0).tolist(), 'max': pos.max(0).tolist()})
        acc.append({'bufferView': view(nrm.astype('<f4').tobytes(), 34962), 'componentType': 5126, 'count': len(pos), 'type': 'VEC3'})
        acc.append({'bufferView': view(uv.astype('<f4').tobytes(), 34962), 'componentType': 5126, 'count': len(pos), 'type': 'VEC2'})
        acc.append({'bufferView': view(idx.astype('<u4').tobytes(), 34963), 'componentType': 5125, 'count': len(idx), 'type': 'SCALAR'})
        attrs = {'POSITION': a0, 'NORMAL': a0 + 1, 'TEXCOORD_0': a0 + 2}
        if skins and mname in skins:
            J, W = skins[mname]
            attrs['JOINTS_0'] = len(acc); acc.append({'bufferView': view(J.astype(np.uint8).tobytes(), 34962), 'componentType': 5121, 'count': len(pos), 'type': 'VEC4'})
            attrs['WEIGHTS_0'] = len(acc); acc.append({'bufferView': view(W.astype('<f4').tobytes(), 34962), 'componentType': 5126, 'count': len(pos), 'type': 'VEC4'})
        materials.append({'name': mname, 'doubleSided': True, 'normalTexture': {'index': tex(sname, 1), 'scale': 1.0},
                          'pbrMetallicRoughness': {'baseColorTexture': {'index': tex(sname, 0)}, 'metallicFactor': 1.0, 'roughnessFactor': 1.0,
                                                   'metallicRoughnessTexture': {'index': tex(sname, 2)}}})
        prims.append({'attributes': attrs, 'indices': a0 + 3, 'material': len(materials) - 1})
    if rig:
        ib = np.array(rig['ibm'], '<f4').tobytes()
        acc.append({'bufferView': view(ib), 'componentType': 5126, 'count': len(rig['ibm']), 'type': 'MAT4'})
        nodes = rig['nodes']
        j = {'nodes': nodes, 'scene': rig['scene'], 'scenes': rig['scenes'], 'skins': [{'inverseBindMatrices': len(acc) - 1, 'joints': rig['skin']['joints'], 'name': 'bow_rig'}]}
    else:
        j = {'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': [{'mesh': 0, 'name': 'weapon'}]}
    while len(bin_) % 4: bin_.append(0)
    j.update({'asset': {'version': '2.0', 'generator': 'zz-medieval-weapons tools/gen_weapons.py'}, 'meshes': [{'name': name, 'primitives': prims}],
              'materials': materials, 'textures': textures, 'images': images,
              'samplers': [{'magFilter': 9729, 'minFilter': 9987, 'wrapS': 10497, 'wrapT': 10497}],
              'accessors': acc, 'bufferViews': views, 'buffers': [{'byteLength': len(bin_)}]})
    js = json.dumps(j, separators=(',', ':')).encode()
    while len(js) % 4: js += b' '
    open(path, 'wb').write(struct.pack('<III', 0x46546C67, 2, 28 + len(js) + len(bin_)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(bin_), 0x004E4942) + bytes(bin_))


if __name__ == '__main__':
    root, out = sys.argv[1], sys.argv[2]
    want = sys.argv[3:] or ['dagger', 'spear', 'battle_axe', 'crossbow', 'bow']
    sets = material_sets(root)
    sets['Wood'] = ambient(root, 'Wood049')
    plans = {'dagger': dagger, 'spear': spear, 'battle_axe': battle_axe, 'crossbow': crossbow}
    texmap = {'Steel': 'Steel', 'Iron': 'Iron', 'Wood': 'Wood', 'Leather': 'Leather', 'Bone': 'Bone', 'Horn': 'Horn'}
    for n in want:
        if n == 'bow':
            meshes = bow()
            here = os.path.dirname(os.path.abspath(__file__))
            rig = json.load(open(here + '/bow_rig.json'))
            skins = {k: bow_skin(m, k) for k, m in meshes.items()}
            parts = [(k, k if k != 'Wood' else 'Wood', m) for k, m in meshes.items()]
            write_glb('%s/bow.glb' % out, 'bow', parts, sets, rig, skins)
        else:
            meshes = plans[n]()
            m2 = {'Wood': 'DarkWood'} if n == 'crossbow' else {}
            parts = [(k, m2.get(k, texmap[k]), m) for k, m in meshes.items()]
            write_glb('%s/%s.glb' % (out, n), n, parts, sets)
        print(n, sum(m.count() for m in meshes.values()), 'tris', {k: m.count() for k, m in meshes.items()})

#!/usr/bin/env python3
"""Build assets/arrow.glb and assets/bolt.glb (own work, CC0): round shaft, bodkin head, horn nock, whipping, curved vanes.

Axis Z, tip toward -Z, where the pack always had them (arrow z -0.45..0.45, bolt -0.2..0.2).
Textures: shaft wood from ambientCG Wood049 (CC0, 1k set), feathers procedural, all 1024 px.

  python3 tools/gen_projectiles.py <wood049_1k_dir> <assets_dir>
"""
import io, json, math, struct, sys
import numpy as np
from PIL import Image

SIDES = 16


class Mesh:
    def __init__(self):
        self.p, self.n, self.uv, self.i = [], [], [], []

    def add(self, pos, uv, tris):
        pos = np.asarray(pos, np.float32)
        base = sum(len(x) for x in self.p)
        t = np.asarray(tris)
        nrm = np.zeros_like(pos)
        for a, b, c in t:
            f = np.cross(pos[b] - pos[a], pos[c] - pos[a])
            nrm[a] += f; nrm[b] += f; nrm[c] += f
        ln = np.linalg.norm(nrm, axis=1, keepdims=True)
        nrm = np.where(ln > 1e-12, nrm / np.maximum(ln, 1e-12), [0, 0, 1])
        self.p.append(pos); self.n.append(nrm.astype(np.float32)); self.uv.append(np.asarray(uv, np.float32))
        self.i.append((t + base).astype(np.uint32))

    def tube(self, radii, zs, u_scale=1.0, rot=0.0, caps=(False, False)):
        """u along the length (wood grain runs along u), v around."""
        s = SIDES
        pos, uv = [], []
        for k, (z, r) in enumerate(zip(zs, radii)):
            for j in range(s + 1):
                a = j * 2 * math.pi / s + rot
                pos.append((math.cos(a) * r, math.sin(a) * r, z))
                uv.append((k / max(len(zs) - 1, 1) * u_scale, j / s))
        tris = []
        for k in range(len(zs) - 1):
            for j in range(s):
                a = k * (s + 1) + j; b = a + 1; c = a + s + 1; d = c + 1
                tris += [(a, b, c), (b, d, c)]
        for end, cap in enumerate(caps):
            if not cap:
                continue
            k = 0 if end == 0 else len(zs) - 1
            ci = len(pos); pos.append((0, 0, zs[k])); uv.append((0.5, 0.5))
            for j in range(s):
                a = k * (s + 1) + j; b = a + 1
                tris.append((ci, a, b) if end == 0 else (ci, b, a))
        self.add(pos, uv, tris)

    def count(self):
        return sum(len(t) for t in self.i)


def vane(z0, z1, base_r, height, ang, twist, segs=16, rows=4):
    """curved strip standing on the shaft, helical twist along the length, profile rising then trimmed."""
    pos, uv = [], []
    for k in range(segs + 1):
        t = k / segs
        z = z0 + (z1 - z0) * t
        prof = math.sin(min(t * 1.25, 1.0) * math.pi / 2) * (1 - 0.35 * max(0.0, t - 0.8) / 0.2)
        h = height * (0.15 + 0.85 * prof)
        a = ang + twist * t
        for j in range(rows + 1):
            f = j / rows
            r = base_r + h * f
            aa = a + 0.18 * f * f
            pos.append((math.cos(aa) * r, math.sin(aa) * r, z))
            uv.append((j / rows, 1 - t))
    tris = []
    for k in range(segs):
        for j in range(rows):
            a = k * (rows + 1) + j; b = a + 1; c = a + rows + 1; d = c + 1
            tris += [(a, c, b), (b, c, d)]
    return pos, uv, tris


def feather_tex(seed, tint, size=1024, contrast=1.0):
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    rach = np.exp(-((x - 0.5) / 0.012) ** 2)
    barbs = 0.5 + 0.5 * np.sin((y * 90 + np.abs(x - 0.5) * 110) * 2 * math.pi / 3)
    fine = rng.normal(0, 1, (size, size)).astype(np.float32)
    patch = np.array(Image.fromarray(rng.integers(0, 255, (16, 16), dtype=np.uint8)).resize((size, size), Image.BICUBIC), np.float32) / 255
    base = 0.62 + 0.20 * barbs + 0.02 * fine + 0.18 * (patch - 0.5)
    base = base * (1 - 0.35 * rach) + 0.15 * rach
    base = base * (1 - 0.15 * np.clip((np.abs(x - 0.5) * 2) ** 3, 0, 1))
    base = 0.55 + (base - 0.55) * contrast
    rgb = np.stack([base * tint[0], base * tint[1], base * tint[2]], 2)
    return Image.fromarray((rgb * 255).clip(0, 255).astype(np.uint8))


def jpg(img, q=92):
    o = io.BytesIO(); img.convert('RGB').save(o, 'JPEG', quality=q, subsampling=0); return o.getvalue()


def build(L, tip, nock, r, head_r, head_len, vane_h, vane_len, vane_gap):
    mats = {}
    shaft = Mesh()
    zs = np.linspace(tip, nock, 28)
    t = (zs - tip) / (nock - tip)
    radii = r * (0.94 + 0.06 * np.sin(t * math.pi)) * np.where(t > 0.97, 0.9, 1.0)
    shaft.tube(radii, zs, u_scale=max(1.0, L / 0.45), caps=(False, True))
    mats['Shaft'] = shaft
    steel = Mesh()
    hz = [tip, tip - head_len * 0.18, tip - head_len * 0.28, tip - head_len * 0.55, tip - head_len * 0.8, tip - head_len]
    hr = [head_r * 0.85, head_r, head_r, head_r * 0.7, head_r * 0.3, 0.0003]
    steel.tube(hr, hz, caps=(True, False))
    mats['Steel'] = steel
    thread = Mesh()
    for z0, z1 in ((nock - vane_gap - vane_len - 0.02, nock - vane_gap - vane_len + 0.004), (nock - vane_gap - 0.004, nock - vane_gap + 0.016)):
        n = 7
        zz = np.linspace(z0, z1, n)
        rr = r * 1.18 * (1 + 0.04 * np.sin(np.arange(n) * 2.1))
        thread.tube(rr, zz, u_scale=4, rot=0.2, caps=(True, True))
    mats['Thread'] = thread
    nk = Mesh()
    nk.tube([r * 1.15, r * 1.3, r * 1.2, r * 0.95], [nock, nock + 0.004, nock + 0.010, nock + 0.016], caps=(False, True))
    mats['Nock'] = nk
    for k in range(3):
        v = Mesh()
        v.add(*vane(nock - vane_gap - vane_len, nock - vane_gap, r, vane_h, k * 2 * math.pi / 3 + math.pi / 2, 0.38))
        mats['Vane%d' % k] = v
    return mats


def write_glb(path, name, mats, imgs):
    bin_ = bytearray(); views = []; acc = []; prims = []; materials = []

    def view(data, target=None):
        while len(bin_) % 4: bin_.append(0)
        views.append({'buffer': 0, 'byteOffset': len(bin_), 'byteLength': len(data), **({'target': target} if target else {})})
        bin_.extend(data); return len(views) - 1

    images = [{'bufferView': view(jpg(im)), 'mimeType': 'image/jpeg'} for im in imgs]
    textures = [{'source': i, 'sampler': 0} for i in range(len(imgs))]
    plain = lambda n, c, rgh, met=0.0: {'name': n, 'doubleSided': True, 'pbrMetallicRoughness': {'baseColorFactor': c + [1], 'metallicFactor': met, 'roughnessFactor': rgh}}
    mdefs = {
        'Shaft': {'name': 'Shaft', 'doubleSided': True, 'normalTexture': {'index': 1, 'scale': 0.8},
                  'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}, 'metallicFactor': 1.0, 'roughnessFactor': 1.0, 'metallicRoughnessTexture': {'index': 2}}},
        'Steel': plain('Steel', [0.42, 0.42, 0.44], 0.38, 1.0),
        'Thread': plain('Thread', [0.36, 0.06, 0.04], 0.85),
        'Nock': plain('Nock', [0.07, 0.055, 0.045], 0.45),
    }
    for k in range(3):
        mdefs['Vane%d' % k] = {'name': 'Feather%d' % k, 'doubleSided': True, 'pbrMetallicRoughness': {'baseColorTexture': {'index': min(3 + k % 2, len(imgs) - 1)}, 'metallicFactor': 0.0, 'roughnessFactor': 0.8}}
    for mn, m in mats.items():
        pos = np.concatenate(m.p); nrm = np.concatenate(m.n); uv = np.concatenate(m.uv); idx = np.concatenate(m.i).ravel()
        a0 = len(acc)
        acc.append({'bufferView': view(pos.astype('<f4').tobytes(), 34962), 'componentType': 5126, 'count': len(pos), 'type': 'VEC3', 'min': pos.min(0).tolist(), 'max': pos.max(0).tolist()})
        acc.append({'bufferView': view(nrm.astype('<f4').tobytes(), 34962), 'componentType': 5126, 'count': len(pos), 'type': 'VEC3'})
        acc.append({'bufferView': view(uv.astype('<f4').tobytes(), 34962), 'componentType': 5126, 'count': len(pos), 'type': 'VEC2'})
        acc.append({'bufferView': view(idx.astype('<u4').tobytes(), 34963), 'componentType': 5125, 'count': len(idx), 'type': 'SCALAR'})
        materials.append(mdefs[mn])
        prims.append({'attributes': {'POSITION': a0, 'NORMAL': a0 + 1, 'TEXCOORD_0': a0 + 2}, 'indices': a0 + 3, 'material': len(materials) - 1})
    while len(bin_) % 4: bin_.append(0)
    j = {'asset': {'version': '2.0', 'generator': 'zz-medieval-weapons tools/gen_projectiles.py'}, 'scene': 0, 'scenes': [{'nodes': [0]}],
         'nodes': [{'mesh': 0, 'name': name}], 'meshes': [{'name': name, 'primitives': prims}], 'materials': materials, 'textures': textures, 'images': images,
         'samplers': [{'magFilter': 9729, 'minFilter': 9987, 'wrapS': 10497, 'wrapT': 10497}],
         'accessors': acc, 'bufferViews': views, 'buffers': [{'byteLength': len(bin_)}]}
    js = json.dumps(j, separators=(',', ':')).encode()
    while len(js) % 4: js += b' '
    open(path, 'wb').write(struct.pack('<III', 0x46546C67, 2, 28 + len(js) + len(bin_)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(bin_), 0x004E4942) + bytes(bin_))


if __name__ == '__main__':
    wood_dir, out = sys.argv[1], sys.argv[2]
    wood = Image.open(wood_dir + '/albedo.webp').convert('RGB')
    wnorm = Image.open(wood_dir + '/normal.webp').convert('RGB')
    rough = Image.open(wood_dir + '/roughness.webp').convert('L')
    orm = Image.merge('RGB', (Image.new('L', rough.size, 255), rough, Image.new('L', rough.size, 0)))
    for name, seed, args in (('arrow', 100, (0.9, -0.375, 0.434, 0.0055, 0.0062, 0.075, 0.016, 0.12, 0.012)),
                             ('bolt', 200, (0.4, -0.145, 0.184, 0.0075, 0.0106, 0.055, 0.013, 0.065, 0.006))):
        feathers = [feather_tex(seed + 1, (1.0, 1.0, 0.96)), feather_tex(seed + 2, (0.80, 0.78, 0.74))]
        if name == 'bolt':
            feathers = [feather_tex(seed + 1, (0.82, 0.66, 0.46), contrast=2.4)]
        mats = build(*args)
        write_glb('%s/%s.glb' % (out, name), name, mats, [wood, wnorm, orm] + feathers)
        print(name, sum(m.count() for m in mats.values()), 'tris')

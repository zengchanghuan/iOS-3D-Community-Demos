#!/usr/bin/env python3
"""Deterministic original assets: cube + floor, checker PNG and HDR studio environment."""
import json, math, pathlib, struct, zlib
root = pathlib.Path(__file__).resolve().parents[1] / 'App/Resources'
root.mkdir(parents=True, exist_ok=True)
def png(width, height, pixels):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    rows = b''.join(b'\0' + pixels[y*width*4:(y+1)*width*4] for y in range(height))
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>2I5B', width, height, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b'')
size = 1024
pixels = bytes(c for y in range(size) for x in range(size) for c in ((220, 150, 45, 255) if (x//128+y//128)%2 else (35, 90, 160, 255)))
image = png(size, size, pixels)
(root/'Checker.png').write_bytes(image)
positions=[]; normals=[]; uvs=[]; indices=[]
faces=[((0,0,1),[(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]),((0,0,-1),[(1,-1,-1),(-1,-1,-1),(-1,1,-1),(1,1,-1)]),((1,0,0),[(1,-1,1),(1,-1,-1),(1,1,-1),(1,1,1)]),((-1,0,0),[(-1,-1,-1),(-1,-1,1),(-1,1,1),(-1,1,-1)]),((0,1,0),[(-1,1,1),(1,1,1),(1,1,-1),(-1,1,-1)]),((0,-1,0),[(-1,-1,-1),(1,-1,-1),(1,-1,1),(-1,-1,1)])]
# Include a ground plane so directional-light shadows have a receiver.
faces.append(((0,1,0),[(-4,-1.05,4),(4,-1.05,4),(4,-1.05,-4),(-4,-1.05,-4)]))
for n, vertices in faces:
    base=len(positions)//3
    positions.extend(v for p in vertices for v in p); normals.extend(n*4)
    uvs.extend([0,0,1,0,1,1,0,1]); indices.extend([base,base+1,base+2,base,base+2,base+3])
def glb(texture):
    binary=bytearray(); views=[]
    def add(data):
        while len(binary)%4: binary.append(0)
        views.append({'buffer':0,'byteOffset':len(binary),'byteLength':len(data)})
        binary.extend(data); return len(views)-1
    for values,fmt in [(positions,'f'),(normals,'f'),(uvs,'f'),(indices,'H')]: add(struct.pack('<'+str(len(values))+fmt,*values))
    image_view=add(texture)
    obj={'asset':{'version':'2.0','generator':'Community3D original controlled fixture'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'mesh':0}], 'meshes':[{'primitives':[{'attributes':{'POSITION':0,'NORMAL':1,'TEXCOORD_0':2},'indices':3,'material':0}]}], 'materials':[{'pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicFactor':0.7,'roughnessFactor':0.25}}], 'textures':[{'source':0,'sampler':0}], 'samplers':[{'magFilter':9729,'minFilter':9729}], 'images':[{'bufferView':image_view,'mimeType':'image/png'}], 'buffers':[{'byteLength':len(binary)}], 'bufferViews':views,'accessors':[{'bufferView':0,'componentType':5126,'count':len(positions)//3,'type':'VEC3','min':[-4,-1.05,-4],'max':[4,1,4]},{'bufferView':1,'componentType':5126,'count':len(normals)//3,'type':'VEC3'},{'bufferView':2,'componentType':5126,'count':len(uvs)//2,'type':'VEC2'},{'bufferView':3,'componentType':5123,'count':len(indices),'type':'SCALAR'}]}
    js=json.dumps(obj,separators=(',',':')).encode(); js+=b' '*((-len(js))%4); binary+=b'\0'*((-len(binary))%4)
    return struct.pack('<3I',0x46546c67,2,28+len(js)+len(binary))+struct.pack('<2I',len(js),0x4e4f534a)+js+struct.pack('<2I',len(binary),0x004e4942)+binary
(root/'Checker-PNG.glb').write_bytes(glb(image))
# Standard glTF placeholder is replaced by the native ASTC sidecar at runtime.
(root/'Checker-ASTC.glb').write_bytes(glb(png(1,1,bytes([255]*4))))
# Uncompressed Radiance RGBE, an original studio panorama for cmgen.
w,h=256,128
hdr=bytearray(b'#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n-Y 128 +X 256\n')
for y in range(h):
    for x in range(w):
        light=12.0 if (40<x<70 and 20<y<65) or (175<x<205 and 35<y<55) else 0.15+0.3*(1-y/h)
        rgb=(light,light*0.9,light*0.75); mantissa, exponent=math.frexp(max(rgb)); scale=mantissa*256/max(rgb)
        hdr.extend([*(int(v*scale) for v in rgb),exponent+128])
(root/'Studio.hdr').write_bytes(hdr)
print('Generated original fixtures')

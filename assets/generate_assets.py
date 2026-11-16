#!/usr/bin/env python3
"""Original pixel-art sprites + sounds for Lynxos RPG (Godot 4.6 starter).
All art drawn programmatically with PIL, no downloads / no copyrighted art."""
import math, os, random, wave, struct
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(OUT, "sprites")
SND = os.path.join(OUT, "sounds")
os.makedirs(SPR, exist_ok=True); os.makedirs(SND, exist_ok=True)

OUTLINE = (0x1a,0x1a,0x2e)
GOLD = (0xe8,0xb8,0x4b)
SKIN = (0xf2,0xc8,0x9b)
SKIN_D = (0xd9,0xa0,0x6e)

def canvas(w,h):
    img = Image.new("RGBA",(w,h),(0,0,0,0))
    return img

def px(img,x,y,c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x,y), c+(255,) if len(c)==3 else c)

def rect(img,x,y,w,h,c):
    for yy in range(y,y+h):
        for xx in range(x,x+w):
            px(img,xx,yy,c)

def save_upscale(img, name, scale):
    big = img.resize((img.width*scale, img.height*scale), Image.NEAREST)
    p = os.path.join(SPR, name)
    big.save(p, "PNG")
    print(p, big.size)
    return p

# ---------- shared character helpers (12x16 low-res) ----------
def base_head(img, hair, hair_rows=3):
    # hair top
    rect(img,3,0,6,2,hair)
    rect(img,3,0,2,3,hair); rect(img,7,0,2,3,hair)
    # face
    rect(img,4,2,4,4,SKIN)
    # eyes
    px(img,4,4,OUTLINE); px(img,7,4,OUTLINE)
    # mouth
    px(img,5,5,(0x8a,0x4a,0x3a)); px(img,6,5,(0x8a,0x4a,0x3a))
    # neck
    rect(img,5,6,2,1,SKIN_D)

def legs_boots(img, pants, boots=(0x6b,0x44,0x23)):
    rect(img,4,11,2,3,pants); rect(img,6,11,2,3,pants)
    rect(img,3,14,3,2,boots); rect(img,6,14,3,2,boots)
    # boot outline bottom
    rect(img,3,15,3,1,OUTLINE); rect(img,6,15,3,1,OUTLINE)

# 1. HERO 12x16 scale4
img = canvas(12,16)
base_head(img,(0x2b,0x2b,0x3a))
# sword on back, sticking up behind right shoulder (diagonal silver)
px(img,9,0,(0xd8,0xd8,0xe0)); px(img,9,1,(0xd8,0xd8,0xe0)); px(img,8,2,(0xd8,0xd8,0xe0)); px(img,8,3,GOLD)
px(img,9,2,OUTLINE)
# arms / tunic dark blue
TUNIC=(0x2e,0x4a,0x7a)
rect(img,2,7,2,4,TUNIC); rect(img,8,7,2,4,TUNIC)
rect(img,2,10,2,1,SKIN); rect(img,8,10,2,1,SKIN)
# torso tunic + gold chest armor
rect(img,3,7,6,4,TUNIC)
rect(img,4,7,4,3,GOLD)
rect(img,5,7,2,3,(0xc9,0x96,0x2e))  # gold shading centre
px(img,5,8,(0x8a,0x6a,0x1a)); px(img,6,8,(0x8a,0x6a,0x1a))
# belt
rect(img,3,11,6,1,(0x4a,0x2e,0x1a)); px(img,5,11,GOLD); px(img,6,11,GOLD)
legs_boots(img,TUNIC)
save_upscale(img,"hero.png",4)

# 2. LYRA 12x16
img = canvas(12,16)
# long dark hair sides
rect(img,3,0,6,2,(0x2e,0x1a,0x3a))
rect(img,2,1,2,8,(0x2e,0x1a,0x3a)); rect(img,8,1,2,8,(0x2e,0x1a,0x3a))
rect(img,4,2,4,4,SKIN)
px(img,4,4,OUTLINE); px(img,7,4,OUTLINE)
px(img,5,5,(0x8a,0x4a,0x3a)); px(img,6,5,(0x8a,0x4a,0x3a))
# purple robe with gold trim
ROBE=(0x6a,0x3f,0xa0)
rect(img,3,7,6,8,ROBE)
rect(img,4,7,4,1,GOLD); rect(img,3,14,6,1,GOLD)  # collar + hem trim
rect(img,5,8,2,5,(0x52,0x2e,0x82))  # robe shading
px(img,5,9,GOLD); px(img,6,9,GOLD)
# staff on right: brown shaft, glowing orange orb
rect(img,10,5,1,9,(0x6b,0x44,0x23))
rect(img,9,3,3,3,(0xff,0x8c,0x2e)); px(img,10,4,(0xff,0xd6,0x6a)); px(img,10,3,(0xff,0xe8,0x9a))
rect(img,10,2,1,1,GOLD)
# left arm
rect(img,2,7,1,4,ROBE)
save_upscale(img,"lyra.png",4)

# 3. MIRA 12x16
img = canvas(12,16)
# blonde hair
rect(img,3,0,6,2,(0xf2,0xd0,0x6b))
rect(img,3,1,1,5,(0xf2,0xd0,0x6b)); rect(img,8,1,1,5,(0xf2,0xd0,0x6b))
rect(img,4,2,4,4,SKIN)
px(img,4,4,(0x3a,0x5a,0x8a)); px(img,7,4,(0x3a,0x5a,0x8a))  # blue eyes
px(img,5,5,(0xc9,0x6a,0x6a)); px(img,6,5,(0xc9,0x6a,0x6a))
# white robe gold trim
ROBE=(0xf5,0xf0,0xe6)
rect(img,3,7,6,8,ROBE)
rect(img,4,7,4,1,GOLD); rect(img,3,14,6,1,GOLD); rect(img,5,7,2,1,(0xd8,0xa8,0x3a))
rect(img,5,9,2,4,(0xe0,0xd8,0xc8))
# small gold cross / pendant
px(img,5,10,GOLD); px(img,6,10,GOLD); px(img,5,11,GOLD)
# staff on left: shaft + glowing white/gold orb
rect(img,1,5,1,9,(0x8a,0x6a,0x2e))
rect(img,0,3,3,3,(0xff,0xf2,0xb0)); px(img,1,4,(0xff,0xff,0xff)); px(img,1,3,GOLD)
save_upscale(img,"mira.png",4)

# 4. DAX 12x16
img = canvas(12,16)
# dark green hood
HOOD=(0x2e,0x5a,0x3a)
rect(img,3,0,6,3,HOOD); rect(img,2,1,2,4,HOOD); rect(img,8,1,2,4,HOOD)
# shadowed face (darker skin, eyes glowing slightly)
rect(img,4,2,4,3,(0x8a,0x6a,0x4e))
px(img,4,3,(0xe8,0xb8,0x4b)); px(img,7,3,(0xe8,0xb8,0x4b))
# cloak
rect(img,3,6,6,9,HOOD)
rect(img,4,6,4,1,(0x1e,0x3e,0x26))  # hood shadow line
rect(img,5,7,2,6,(0x24,0x46,0x2e))
# belt + dagger at belt (silver blade pointing down-right)
rect(img,3,10,6,1,(0x3a,0x2a,0x1a)); px(img,5,10,GOLD)
px(img,7,11,(0xd8,0xd8,0xe0)); px(img,8,12,(0xd8,0xd8,0xe0)); px(img,7,10,(0x8a,0x6a,0x2e))
# boots
rect(img,3,14,3,2,(0x6b,0x44,0x23)); rect(img,6,14,3,2,(0x6b,0x44,0x23))
save_upscale(img,"dax.png",4)

# 5. EMBER WOLF 16x12 scale4 -> 64x48, side-facing (facing right)
img = canvas(16,12)
BODY=(0xe8,0x6a,0x2e); MANE=(0xa8,0x32,0x26); DARK=(0x7a,0x2a,0x1e)
# tail (left) with flame tuft
rect(img,0,4,3,2,BODY); rect(img,0,3,2,1,(0xff,0x8c,0x2e)); px(img,0,2,(0xff,0xd6,0x6a)); px(img,1,2,(0xff,0x8c,0x2e))
# body
rect(img,3,5,8,4,BODY)
# darker red mane along back
rect(img,4,4,7,1,MANE); rect(img,5,3,3,1,MANE)
# legs
rect(img,4,9,2,3,BODY); rect(img,7,9,2,3,BODY); rect(img,10,9,2,3,BODY)
rect(img,4,11,2,1,OUTLINE); rect(img,7,11,2,1,OUTLINE); rect(img,10,11,2,1,OUTLINE)
# head (right)
rect(img,11,3,4,4,BODY)
# ears
px(img,11,2,MANE); px(img,12,2,MANE); px(img,13,1,MANE); px(img,14,1,MANE)
# snout
rect(img,14,5,2,2,(0xd8,0x8a,0x5a)); px(img,15,6,OUTLINE)  # nose
# glowing amber eye
px(img,13,4,(0xff,0xc8,0x2e)); px(img,13,5,OUTLINE)
# chest lighter
rect(img,11,7,2,2,(0xf2,0xa8,0x6a))
save_upscale(img,"ember_wolf.png",4)

# 6. EMBER SLIME 12x12 scale4 -> 48x48
img = canvas(12,12)
BODY=(0xff,0x7a,0x2e)
# flame on top
px(img,5,0,(0xff,0xd6,0x6a)); px(img,6,0,(0xff,0x8c,0x2e)); rect(img,5,1,2,1,(0xff,0x8c,0x2e)); px(img,5,2,(0xff,0xd6,0x6a))
# round blob: rows widen then narrow
rect(img,4,3,4,1,BODY); rect(img,3,4,6,1,BODY); rect(img,2,5,8,4,BODY); rect(img,3,9,6,1,BODY); rect(img,4,10,4,1,BODY)
# outline top/bottom edges (dark)
rect(img,4,3,4,1,OUTLINE)  # will be overwritten partially below - redo body interior
rect(img,4,4,4,1,BODY); rect(img,3,4,1,1,OUTLINE); rect(img,8,4,1,1,OUTLINE)
rect(img,2,5,1,1,OUTLINE); rect(img,9,5,1,1,OUTLINE)
rect(img,2,8,1,1,OUTLINE); rect(img,9,8,1,1,OUTLINE)
rect(img,3,9,1,1,OUTLINE); rect(img,8,9,1,1,OUTLINE)
rect(img,4,10,4,1,OUTLINE)
# highlight
px(img,3,5,(0xff,0xb0,0x6a)); px(img,4,5,(0xff,0xb0,0x6a)); px(img,3,6,(0xff,0xb0,0x6a))
# worried eyes (white + black pupils looking up)
rect(img,4,6,2,2,(0xff,0xff,0xff)); rect(img,7,6,2,2,(0xff,0xff,0xff))
px(img,4,6,OUTLINE); px(img,8,6,OUTLINE)
# small worried mouth
px(img,5,9,(0x7a,0x2a,0x1e)); px(img,6,9,(0x7a,0x2a,0x1e))
save_upscale(img,"ember_slime.png",4)

# 7. TREE 16x24 scale4 -> 64x96
img = canvas(16,24)
TRUNK=(0x6b,0x44,0x23); LEAF=(0x3e,0x8a,0x3a); LEAF_L=(0x6a,0xbe,0x4a)
# trunk
rect(img,7,14,2,9,TRUNK); rect(img,6,21,4,2,TRUNK)
# canopy: layered round blobs
rect(img,5,2,6,2,LEAF); rect(img,3,4,10,3,LEAF); rect(img,2,7,12,4,LEAF); rect(img,3,11,10,3,LEAF); rect(img,5,14,6,1,LEAF)
# lighter highlights
rect(img,4,4,3,2,LEAF_L); px(img,10,5,LEAF_L); px(img,11,5,LEAF_L); rect(img,5,8,3,2,LEAF_L); px(img,11,9,LEAF_L)
# outline touches
px(img,5,2,OUTLINE); px(img,10,2,OUTLINE); px(img,3,4,OUTLINE); px(img,12,4,OUTLINE)
save_upscale(img,"tree.png",4)

# 8. HOUSE 32x32 scale4 -> 128x128
img = canvas(32,32)
WALL=(0xd8,0xc9,0xa8); ROOF=(0x8a,0x3b,0x2e); ROOF_D=(0x6a,0x2a,0x20)
# chimney
rect(img,22,4,3,7,(0x9a,0x9a,0x9a)); rect(img,22,4,3,1,OUTLINE)
# roof (pitched triangle)
for y in range(8,15):
    w = 2*(y-7)  # widen downward
    x0 = 16 - w//2
    rect(img,x0,y,w,1,ROOF)
rect(img,4,14,24,2,ROOF_D)  # eaves
# walls
rect(img,6,16,20,13,WALL)
# stone shading lines
rect(img,6,20,20,1,(0xc0,0xb0,0x8e)); rect(img,6,25,20,1,(0xc0,0xb0,0x8e))
# door gold-lit
rect(img,13,21,5,8,GOLD); rect(img,14,22,3,6,(0xff,0xd6,0x6a)); px(img,17,25,OUTLINE)
# window gold-lit
rect(img,20,19,4,4,GOLD); px(img,21,20,OUTLINE); px(img,22,21,OUTLINE)
rect(img,8,19,3,3,GOLD); px(img,9,20,OUTLINE)
# roof outline top
px(img,15,8,OUTLINE); px(img,16,8,OUTLINE)
save_upscale(img,"house.png",4)

# 9-12 tiles 8x8 scale4 -> 32x32
rng = random.Random(42)
# grass
img = canvas(8,8)
rect(img,0,0,8,8,(0x5a,0x9a,0x45))
for _ in range(10):
    px(img,rng.randrange(8),rng.randrange(8),(0x4a,0x7d,0x38))
for _ in range(8):
    px(img,rng.randrange(8),rng.randrange(8),(0x6f,0xb4,0x57))
save_upscale(img,"grass.png",4)

# path
img = canvas(8,8)
rect(img,0,0,8,8,(0xc9,0xa8,0x6a))
for _ in range(10):
    px(img,rng.randrange(8),rng.randrange(8),(0xa8,0x88,0x4e))
for _ in range(5):
    px(img,rng.randrange(8),rng.randrange(8),(0xdc,0xbc,0x82))
# darker border top/left
rect(img,0,0,8,1,(0xb0,0x8d,0x55)); rect(img,0,0,1,8,(0xb0,0x8d,0x55))
save_upscale(img,"path.png",4)

# flower (on grass base matching grass.png)
img = canvas(8,8)
rect(img,0,0,8,8,(0x5a,0x9a,0x45))
px(img,1,1,(0x4a,0x7d,0x38)); px(img,6,6,(0x6f,0xb4,0x57)); px(img,6,1,(0x4a,0x7d,0x38))
# stem
rect(img,4,5,1,2,(0x2e,0x6a,0x2e))
# gold flower: 5 petals around centre
px(img,3,2,GOLD); px(img,5,2,GOLD); px(img,2,3,GOLD); px(img,6,3,GOLD); px(img,3,4,GOLD); px(img,5,4,GOLD)
px(img,4,3,(0xff,0xd6,0x6a)); px(img,4,2,(0xff,0xe8,0x9a))
save_upscale(img,"flower.png",4)

# rock
img = canvas(8,8)
rect(img,0,0,8,8,(0,0,0,0))
rect(img,2,2,4,1,(0x8a,0x8a,0x8a)); rect(img,1,3,6,3,(0x8a,0x8a,0x8a)); rect(img,2,6,4,1,(0x8a,0x8a,0x8a))
rect(img,1,3,6,1,(0xb0,0xb0,0xb0))  # highlight top
px(img,2,5,(0x5a,0x5a,0x5a)); px(img,5,5,(0x5a,0x5a,0x5a)); rect(img,2,6,4,1,(0x5a,0x5a,0x5a))
px(img,2,2,OUTLINE); px(img,5,2,OUTLINE); px(img,1,3,OUTLINE); px(img,6,3,OUTLINE); px(img,1,5,OUTLINE); px(img,6,5,OUTLINE)
save_upscale(img,"rock.png",4)

print("sprites done")

# ---------- SOUNDS ----------
SR = 22050
def write_wav(name, samples):
    p = os.path.join(SND, name)
    with wave.open(p, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        frames = b"".join(struct.pack("<h", max(-32767, min(32767, int(s*32767)))) for s in samples)
        w.writeframes(frames)
    print(p, len(samples)/SR, "s")

def tone(freq, dur, vol=0.5, fade_out=True, freq_end=None):
    n = int(SR*dur); out=[]
    for i in range(n):
        t=i/SR
        f = freq if freq_end is None else freq + (freq_end-freq)*(i/n)
        # phase with varying freq: approximate by cumulative - use simple sin(2pi f t) is ok for short drop
        v = math.sin(2*math.pi*f*t) * vol
        # envelope: quick attack, fade at end
        env = min(1.0, i/(SR*0.005))
        if fade_out:
            env *= max(0.0, 1.0 - i/n) if dur>0.1 else max(0.0, 1.0 - (i/n)**0.5)
            # for very short, use linear fade
            if dur<=0.1: env = min(1.0, i/(SR*0.005)) * (1.0 - i/n)
        out.append(v*env)
    return out

def notes(note_list, note_dur, vol=0.5):
    out=[]
    for f in note_list:
        out.extend(tone(f, note_dur, vol=vol))
    return out

# 1 select 0.08s 880Hz
write_wav("select.wav", tone(880, 0.08, vol=0.5))
# 2 hit 0.15s pitch drop 300->120
write_wav("hit.wav", tone(300, 0.15, vol=0.6, freq_end=120))
# 3 heal 0.35s arpeggio 523,659,784 (each ~0.117s)
write_wav("heal.wav", notes([523,659,784], 0.35/3, vol=0.5))
# 4 victory 0.7s 523,659,784,1047
write_wav("victory.wav", notes([523,659,784,1047], 0.7/4, vol=0.5))
# 5 defeat 0.6s 392,330,262
write_wav("defeat.wav", notes([392,330,262], 0.6/3, vol=0.5))
print("sounds done")
